-- RPC: admin_add_team_member
-- Allows professors to add a new member to an existing team.
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

  if not (select public.is_event_professor(target_team.event_id)) then
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

  -- Check max team size (6 members)
  if (select count(*) from public.team_members
      where team_id = p_team_id and status <> 'removed') >= 6 then
    raise exception using errcode = 'P0001', message = 'team_size_out_of_range';
  end if;

  -- Check for email/enrollment conflicts in the event
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

revoke all on function public.admin_add_team_member(uuid, text, text, text)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_add_team_member(uuid, text, text, text)
  to authenticated;

-- RPC: admin_remove_team_member
-- Allows professors to remove a member from a team.
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

  if not (select public.is_event_professor(target_member.event_id)) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  -- Don't allow removing the last active member
  select count(*) into active_count
  from public.team_members
  where team_id = target_member.team_id
    and status = 'active'
    and id <> p_member_id;

  if active_count = 0 then
    raise exception using errcode = 'P0001', message = 'last_member';
  end if;

  -- Delete the member (hard delete is fine since this is admin action)
  delete from public.team_members where id = p_member_id;

  -- If removed member was the team leader's member entry, re-assign leader?
  -- We don't reassign automatically — professor can handle that.

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

revoke all on function public.admin_remove_team_member(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_remove_team_member(uuid)
  to authenticated;
