-- ============================================================
-- MULTI-PROFESSOR SUPPORT
-- ============================================================
-- 1. Update private.current_event_professor to NOT require professor_id match.
--    Any user with an 'professor' role in event_roles is a professor.
create or replace function private.current_event_professor(
  target_event uuid,
  caller_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    caller_id is not null
    and exists (
      select 1
      from public.event_roles as role_assignment
      where role_assignment.event_id = target_event
        and role_assignment.user_id = caller_id
        and role_assignment.role = 'professor'
    );
$$;

-- 2. Update is_event_professor view to read from event_roles (includes all professors, not just the single professor_id)
create or replace view private.current_event_professorships
with (security_barrier = true)
as
select
  er.event_id,
  (select auth.uid()) as user_id
from public.event_roles er
where (select auth.uid()) is not null
  and er.user_id = (select auth.uid())
  and er.role = 'professor';

-- 3. Update decide_role_request_impl so approving a new professor does NOT revoke other professors.
--    Also allow any existing professor to approve monitor/evaluator requests, not just the single professor_id.
create or replace function private.decide_role_request_impl(
  request_id uuid,
  decision public.request_status
)
returns public.role_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target public.role_requests;
  target_event public.events;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  if decision is null or decision not in ('approved', 'rejected') then
    raise exception using errcode = 'P0001', message = 'invalid_decision';
  end if;

  select request.*
  into target
  from public.role_requests as request
  where request.id = request_id
    and request.status = 'pending'
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'request_not_pending';
  end if;

  select event.*
  into target_event
  from public.events as event
  where event.id = target.event_id
  for update;

  if not found or target_event.status = 'archived' then
    raise exception using errcode = 'P0001', message = 'event_not_available';
  end if;

  -- Professor role requests can only be approved by global_admin
  if target.requested_role = 'professor' then
    if not exists (
      select 1
      from public.profiles as profile
      where profile.id = caller_id
        and profile.global_role = 'global_admin'
    ) then
      raise exception using errcode = 'P0001', message = 'forbidden';
    end if;
  -- Other roles (monitor, evaluator) can be approved by any event professor
  elsif not exists (
    select 1 from public.event_roles
    where event_id = target.event_id
      and user_id = caller_id
      and role = 'professor'
  ) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  update public.role_requests as request
  set
    status = decision,
    decided_by = caller_id,
    decided_at = now()
  where request.id = target.id
  returning * into target;

  if decision = 'approved' then
    -- NOTE: No longer revoke other professors when a new one is approved.
    -- Multiple professors are now allowed per event.

    insert into public.event_roles (
      event_id,
      user_id,
      role,
      approved_by
    )
    values (
      target.event_id,
      target.user_id,
      target.requested_role,
      caller_id
    )
    on conflict (event_id, user_id, role) do nothing;

    -- Keep professor_id pointing to one of the professors for legacy FK compatibility.
    -- Only update professor_id if it's currently null.
    if target.requested_role = 'professor' then
      update public.events as event
      set professor_id = target.user_id
      where event.id = target.event_id
        and event.professor_id is null;
    end if;
  end if;

  insert into public.audit_log (
    event_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    payload
  )
  values (
    target.event_id,
    caller_id,
    case
      when decision = 'approved' then 'role_request_approved'
      else 'role_request_rejected'
    end,
    'role_request',
    target.id::text,
    jsonb_build_object(
      'requested_role', target.requested_role,
      'user_id', target.user_id
    )
  );

  return target;
end;
$$;

-- 4. New function: add_event_professor
-- Allows a professor or global_admin to add another professor directly by email.
create or replace function public.add_event_professor(
  p_event_id uuid,
  p_email text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target_profile public.profiles;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  -- Check caller is a professor or global_admin of this event
  if not exists (
    select 1 from public.event_roles
    where event_id = p_event_id
      and user_id = caller_id
      and role = 'professor'
  ) and not exists (
    select 1 from public.profiles
    where id = caller_id and global_role = 'global_admin'
  ) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  -- Look up the user by email
  select profile.* into target_profile
  from public.profiles as profile
  where lower(btrim(profile.email)) = lower(btrim(p_email));

  if not found then
    raise exception using errcode = 'P0001', message = 'user_not_found';
  end if;

  if target_profile.id = caller_id then
    raise exception using errcode = 'P0001', message = 'cannot_add_self';
  end if;

  -- Insert role
  insert into public.event_roles (event_id, user_id, role, approved_by)
  values (p_event_id, target_profile.id, 'professor', caller_id)
  on conflict (event_id, user_id, role) do nothing;

  -- Log
  insert into public.audit_log (event_id, actor_id, action, entity_type, entity_id, payload)
  values (
    p_event_id,
    caller_id,
    'professor_added',
    'event_role',
    target_profile.id::text,
    jsonb_build_object('email', p_email)
  );
end;
$$;

revoke all on function public.add_event_professor(uuid, text) from public, anon, authenticated, service_role;
grant execute on function public.add_event_professor(uuid, text) to authenticated;

-- 5. New function: remove_event_professor
-- Allows a professor to remove another professor.
create or replace function public.remove_event_professor(
  p_event_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  professor_count int;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  if caller_id = p_user_id then
    raise exception using errcode = 'P0001', message = 'cannot_remove_self';
  end if;

  if not exists (
    select 1 from public.event_roles
    where event_id = p_event_id
      and user_id = caller_id
      and role = 'professor'
  ) and not exists (
    select 1 from public.profiles
    where id = caller_id and global_role = 'global_admin'
  ) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  select count(*) into professor_count
  from public.event_roles
  where event_id = p_event_id and role = 'professor';

  if professor_count <= 1 then
    raise exception using errcode = 'P0001', message = 'last_professor';
  end if;

  delete from public.event_roles
  where event_id = p_event_id
    and user_id = p_user_id
    and role = 'professor';

  -- If the removed professor was the "primary" professor_id, reassign to another professor.
  update public.events
  set professor_id = (
    select user_id from public.event_roles
    where event_id = p_event_id and role = 'professor'
    limit 1
  )
  where id = p_event_id
    and professor_id = p_user_id;

  insert into public.audit_log (event_id, actor_id, action, entity_type, entity_id, payload)
  values (
    p_event_id,
    caller_id,
    'professor_removed',
    'event_role',
    p_user_id::text,
    '{}'::jsonb
  );
end;
$$;

revoke all on function public.remove_event_professor(uuid, uuid) from public, anon, authenticated, service_role;
grant execute on function public.remove_event_professor(uuid, uuid) to authenticated;

-- 6. Allow professors to update decide_role_requests (previously only professor_id was checked)
-- This is already fixed by updated decide_role_request_impl above.

-- 7. Update the solicitacoes query policy so all professors of an event can approve monitor/evaluator requests
-- The existing RLS policy "requests visible to decision makers" already uses is_event_professor which now covers all.
-- No change needed.
