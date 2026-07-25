create or replace function public.admin_update_team(
  team_id     uuid,
  new_name    text,
  new_category public.team_category,
  members     jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target_team public.teams;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  select * into target_team
  from public.teams
  where id = team_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'team_not_found';
  end if;

  if not (select public.is_global_admin() or public.is_event_professor(target_team.event_id)) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  if new_name is null or btrim(new_name) = '' then
    raise exception using errcode = 'P0001', message = 'team_name_required';
  end if;

  if new_category is null then
    raise exception using errcode = 'P0001', message = 'category_required';
  end if;

  update public.teams
  set
    name     = btrim(new_name),
    category = new_category
  where id = team_id;

  if members is not null and jsonb_typeof(members) = 'array' then
    declare
      item jsonb;
      member_id uuid;
    begin
      for item in select * from jsonb_array_elements(members) loop
        member_id := (item->>'id')::uuid;

        if member_id is null then continue; end if;

        update public.team_members
        set
          name       = btrim(coalesce(item->>'name', name)),
          email      = lower(btrim(coalesce(item->>'email', email))),
          enrollment = lower(btrim(coalesce(item->>'enrollment', enrollment)))
        where id = member_id
          and team_id = team_id
          and event_id = target_team.event_id;
      end loop;
    end;
  end if;
end;
$$;

create or replace function public.admin_add_team_member(
  p_team_id    uuid,
  p_name       text,
  p_email      text,
  p_enrollment text
)
returns public.team_members
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target_team public.teams;
  new_member public.team_members;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  select * into target_team
  from public.teams
  where id = p_team_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'team_not_found';
  end if;

  if not (select public.is_global_admin() or public.is_event_professor(target_team.event_id)) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  if p_name is null or btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'name_required';
  end if;
  if p_email is null or btrim(p_email) = '' then
    raise exception using errcode = 'P0001', message = 'email_required';
  end if;
  if p_enrollment is null or btrim(p_enrollment) = '' then
    raise exception using errcode = 'P0001', message = 'enrollment_required';
  end if;

  if (select count(*) from public.team_members
      where team_id = p_team_id and status <> 'removed') >= 6 then
    raise exception using errcode = 'P0001', message = 'team_size_out_of_range';
  end if;

  if exists (
    select 1 from public.team_members
    where event_id = target_team.event_id
      and status in ('invited', 'join_requested', 'active')
      and (
        lower(btrim(email)) = lower(btrim(p_email))
        or lower(btrim(enrollment)) = lower(btrim(p_enrollment))
      )
  ) then
    raise exception using errcode = 'P0001', message = 'member_already_reserved';
  end if;

  insert into public.team_members (
    event_id,
    team_id,
    user_id,
    name,
    email,
    enrollment,
    status,
    approved_by
  )
  values (
    target_team.event_id,
    p_team_id,
    (select id from public.profiles where lower(btrim(email)) = lower(btrim(p_email)) limit 1),
    btrim(p_name),
    lower(btrim(p_email)),
    lower(btrim(p_enrollment)),
    'active',
    caller_id
  )
  returning * into new_member;

  insert into public.audit_log (event_id, actor_id, action, entity_type, entity_id, payload)
  values (
    target_team.event_id,
    caller_id,
    'member_added_by_admin',
    'team_member',
    new_member.id::text,
    jsonb_build_object('team_id', p_team_id, 'email', lower(btrim(p_email)))
  );

  return new_member;
end;
$$;

create or replace function public.admin_remove_team_member(
  p_member_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target_member public.team_members;
  active_count int;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  select * into target_member
  from public.team_members
  where id = p_member_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'member_not_found';
  end if;

  if not (select public.is_global_admin() or public.is_event_professor(target_member.event_id)) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  select count(*) into active_count
  from public.team_members
  where team_id = target_member.team_id
    and status = 'active'
    and id <> p_member_id;

  if active_count = 0 then
    raise exception using errcode = 'P0001', message = 'last_member';
  end if;

  delete from public.team_members where id = p_member_id;

  insert into public.audit_log (event_id, actor_id, action, entity_type, entity_id, payload)
  values (
    target_member.event_id,
    caller_id,
    'member_removed_by_admin',
    'team_member',
    p_member_id::text,
    jsonb_build_object('team_id', target_member.team_id, 'email', target_member.email)
  );
end;
$$;
