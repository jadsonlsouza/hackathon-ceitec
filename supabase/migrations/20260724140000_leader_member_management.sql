-- Allow team leaders to add/remove members from their own team.
-- Creates leader-specific RPCs that bypass the professor check.

-- 1. leader_add_team_member: team leader adds a new member
create or replace function public.leader_add_team_member(
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

  -- Only the team leader can call this
  if target_team.leader_id <> caller_id then
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
      where team_id = p_team_id and status = 'active') >= 6 then
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
    event_id, team_id, user_id, name, email, enrollment, status, approved_by
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

  return new_member;
end;
$$;

revoke all on function public.leader_add_team_member(uuid, text, text, text)
  from public, anon, authenticated, service_role;
grant execute on function public.leader_add_team_member(uuid, text, text, text)
  to authenticated;

-- 2. leader_remove_team_member: team leader removes a member
create or replace function public.leader_remove_team_member(
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
  target_team public.teams;
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

  select * into target_team
  from public.teams
  where id = target_member.team_id;

  -- Only the team leader can remove members
  if target_team.leader_id <> caller_id then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  -- Cannot remove yourself (leader)
  if target_member.user_id = caller_id then
    raise exception using errcode = 'P0001', message = 'cannot_remove_self';
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
end;
$$;

revoke all on function public.leader_remove_team_member(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.leader_remove_team_member(uuid)
  to authenticated;
