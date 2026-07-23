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
    if target.requested_role = 'professor' then
      with revoked as (
        delete from public.event_roles as role_assignment
        where role_assignment.event_id = target.event_id
          and role_assignment.role = 'professor'
          and role_assignment.user_id <> target.user_id
        returning role_assignment.user_id
      )
      insert into public.audit_log (
        event_id,
        actor_id,
        action,
        entity_type,
        entity_id,
        payload
      )
      select
        target.event_id,
        caller_id,
        'event_professor_replaced',
        'event_role',
        revoked.user_id::text,
        jsonb_build_object(
          'replacement_user_id',
          target.user_id,
          'role',
          'professor'
        )
      from revoked;
    end if;

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

create view private.role_workflow_dispatch
with (security_invoker = true)
as
select
  null::text as operation,
  null::public.event_role as target_role,
  null::uuid as target_event,
  null::uuid as request_id,
  null::public.request_status as decision,
  null::public.role_requests as result
where false;

create function private.dispatch_role_workflow()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.operation = 'request' then
    new.result := private.request_role_impl(
      new.target_role,
      new.target_event
    );
  elsif new.operation = 'decide' then
    new.result := private.decide_role_request_impl(
      new.request_id,
      new.decision
    );
  else
    raise exception using errcode = 'P0001', message = 'invalid_operation';
  end if;

  return new;
end;
$$;

create trigger dispatch_role_workflow
instead of insert on private.role_workflow_dispatch
for each row execute function private.dispatch_role_workflow();

create function public.request_role(
  target_role public.event_role,
  target_event uuid default null
)
returns public.role_requests
language plpgsql
security invoker
set search_path = ''
as $$
declare
  created public.role_requests;
begin
  insert into private.role_workflow_dispatch (
    operation,
    target_role,
    target_event
  )
  values (
    'request',
    target_role,
    target_event
  )
  returning (result).* into created;

  return created;
end;
$$;

create function public.decide_role_request(
  request_id uuid,
  decision public.request_status
)
returns public.role_requests
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target public.role_requests;
begin
  insert into private.role_workflow_dispatch (
    operation,
    request_id,
    decision
  )
  values (
    'decide',
    request_id,
    decision
  )
  returning (result).* into target;

  return target;
end;
$$;

revoke all on function
  private.request_role_impl(public.event_role, uuid),
  private.decide_role_request_impl(uuid, public.request_status),
  private.dispatch_role_workflow()
from public, anon, authenticated, service_role;

revoke all on table private.role_workflow_dispatch
from public, anon, authenticated, service_role;

grant insert (
  operation,
  target_role,
  target_event,
  request_id,
  decision
) on private.role_workflow_dispatch to authenticated;

grant select (result) on private.role_workflow_dispatch to authenticated;

revoke all on function
  public.request_role(public.event_role, uuid),
  public.decide_role_request(uuid, public.request_status)
from public, anon, authenticated, service_role;

grant execute on function
  public.request_role(public.event_role, uuid),
  public.decide_role_request(uuid, public.request_status)
to authenticated;

drop policy "requests visible to decision makers" on public.role_requests;

create policy "requests visible to scoped participants"
on public.role_requests
for select
to authenticated
using (
  user_id = (select auth.uid())
  or (
    requested_role = 'professor'
    and (select public.is_global_admin())
  )
  or (
    requested_role in ('monitor', 'evaluator')
    and (select public.is_event_professor(event_id))
  )
);

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

comment on view private.role_workflow_dispatch is
  'Non-exposed invoker bridge. Its trigger invokes private workflow implementations without granting callers function execution.';
