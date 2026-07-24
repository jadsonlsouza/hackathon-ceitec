create or replace function public.register_team(
  target_event uuid,
  target_category public.team_category,
  target_name text,
  target_members jsonb
)
returns public.teams
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  caller_profile public.profiles;
  leader_member_count integer;
  created_team public.teams;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  if not exists (
    select 1
    from public.events as event
    where event.id = target_event
      and event.status <> 'archived'
      and now() between event.starts_at and event.ends_at
  ) then
    raise exception using errcode = 'P0001', message = 'event_not_available';
  end if;

  select profile.*
  into caller_profile
  from public.profiles as profile
  where profile.id = caller_id;

  if not found then
    raise exception using errcode = 'P0001', message = 'profile_required';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(target_members) as item(value)
    where jsonb_typeof(item.value) <> 'object'
      or coalesce(btrim(item.value ->> 'name'), '') = ''
      or coalesce(btrim(item.value ->> 'email'), '') = ''
      or coalesce(btrim(item.value ->> 'enrollment'), '') = ''
  ) then
    raise exception using errcode = 'P0001', message = 'invalid_member';
  end if;

  select count(*)::integer
  into leader_member_count
  from jsonb_array_elements(target_members) as item(value)
  where lower(btrim(item.value ->> 'email'))
    = lower(btrim(caller_profile.email));

  if leader_member_count <> 1 then
    raise exception using errcode = 'P0001', message = 'leader_member_required';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(target_members) as item(value)
    group by lower(btrim(item.value ->> 'email'))
    having count(*) > 1
  ) or exists (
    select 1
    from jsonb_array_elements(target_members) as item(value)
    group by lower(btrim(item.value ->> 'enrollment'))
    having count(*) > 1
  ) then
    raise exception using errcode = 'P0001', message = 'member_already_reserved';
  end if;

  if exists (
    select 1
    from public.team_members as existing
    where existing.event_id = target_event
      and existing.status in ('invited', 'join_requested', 'active')
      and (
        existing.email in (
          select lower(btrim(item.value ->> 'email'))
          from jsonb_array_elements(target_members) as item(value)
        )
        or existing.enrollment in (
          select lower(btrim(item.value ->> 'enrollment'))
          from jsonb_array_elements(target_members) as item(value)
        )
      )
  ) then
    raise exception using errcode = 'P0001', message = 'member_already_reserved';
  end if;

  insert into public.teams (
    event_id,
    name,
    category,
    leader_id,
    status,
    decided_by,
    decided_at
  )
  values (
    target_event,
    btrim(target_name),
    target_category,
    caller_id,
    'approved',
    caller_id,
    now()
  )
  returning * into created_team;

  begin
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
    select
      target_event,
      created_team.id,
      case
        when lower(btrim(item.value ->> 'email'))
          = lower(btrim(caller_profile.email))
          then caller_id
        else null
      end,
      btrim(item.value ->> 'name'),
      lower(btrim(item.value ->> 'email')),
      lower(btrim(item.value ->> 'enrollment')),
      case
        when lower(btrim(item.value ->> 'email'))
          = lower(btrim(caller_profile.email))
          then 'active'::public.member_status
        else 'invited'::public.member_status
      end,
      case
        when lower(btrim(item.value ->> 'email'))
          = lower(btrim(caller_profile.email))
          then caller_id
        else null
      end
    from jsonb_array_elements(target_members) as item(value);
  exception
    when unique_violation then
      raise exception using
        errcode = 'P0001',
        message = 'member_already_reserved';
  end;

  insert into public.audit_log (
    event_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    payload
  )
  values (
    target_event,
    caller_id,
    'team_registered',
    'team',
    created_team.id::text,
    jsonb_build_object('category', target_category)
  );

  return created_team;
end;
$$;

update public.teams
set status = 'approved', decided_by = leader_id, decided_at = now()
where status = 'pending';
