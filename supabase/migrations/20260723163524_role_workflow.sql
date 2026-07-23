create function private.request_role_impl(
  target_role public.event_role,
  target_event uuid
)
returns public.role_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target_event_row public.events;
  created public.role_requests;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  if target_event is null then
    raise exception using errcode = 'P0001', message = 'event_required';
  end if;

  if target_role is null then
    raise exception using errcode = 'P0001', message = 'role_required';
  end if;

  select event.*
  into target_event_row
  from public.events as event
  where event.id = target_event
  for update;

  if not found or target_event_row.status = 'archived' then
    raise exception using errcode = 'P0001', message = 'event_not_available';
  end if;

  insert into public.role_requests (
    user_id,
    event_id,
    requested_role
  )
  values (
    caller_id,
    target_event,
    target_role
  )
  returning * into created;

  return created;
end;
$$;

create function public.request_role(
  target_role public.event_role,
  target_event uuid default null
)
returns public.role_requests
language sql
security invoker
set search_path = ''
as $$
  select private.request_role_impl(target_role, target_event);
$$;

create function private.decide_role_request_impl(
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

  if decision not in ('approved', 'rejected') then
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

  if target.requested_role = 'professor' then
    if not exists (
      select 1
      from public.profiles as profile
      where profile.id = caller_id
        and profile.global_role = 'global_admin'
    ) then
      raise exception using errcode = 'P0001', message = 'forbidden';
    end if;
  elsif target_event.professor_id is distinct from caller_id then
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

    if target.requested_role = 'professor' then
      update public.events as event
      set professor_id = target.user_id
      where event.id = target.event_id;
    end if;
  end if;

  insert into public.audit_log (
    event_id,
    actor_id,
    action,
    entity_type,
    entity_id
  )
  values (
    target.event_id,
    caller_id,
    'role_request_' || decision::text,
    'role_request',
    target.id::text
  );

  return target;
end;
$$;

create function public.decide_role_request(
  request_id uuid,
  decision public.request_status
)
returns public.role_requests
language sql
security invoker
set search_path = ''
as $$
  select private.decide_role_request_impl(request_id, decision);
$$;

revoke all on function
  private.request_role_impl(public.event_role, uuid),
  private.decide_role_request_impl(uuid, public.request_status)
from public, anon, authenticated, service_role;

grant execute on function
  private.request_role_impl(public.event_role, uuid),
  private.decide_role_request_impl(uuid, public.request_status)
to authenticated;

revoke all on function
  public.request_role(public.event_role, uuid),
  public.decide_role_request(uuid, public.request_status)
from public, anon, authenticated, service_role;

grant execute on function
  public.request_role(public.event_role, uuid),
  public.decide_role_request(uuid, public.request_status)
to authenticated;

drop policy "profile self read" on public.profiles;

create policy "profile self and authorized applicant read"
on public.profiles
for select
to authenticated
using (
  id = (select auth.uid())
  or (select public.is_global_admin())
  or exists (
      select 1
      from public.role_requests as request
      where request.user_id = profiles.id
        and request.status = 'pending'
        and request.requested_role in ('monitor', 'evaluator')
        and (select public.is_event_professor(request.event_id))
  )
);

comment on function private.request_role_impl(public.event_role, uuid) is
  'Privileged role-request implementation. The private schema is not exposed through PostgREST.';

comment on function private.decide_role_request_impl(uuid, public.request_status) is
  'Privileged decision implementation. Call only through public.decide_role_request.';
