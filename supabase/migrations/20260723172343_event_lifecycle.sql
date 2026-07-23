alter table public.events
add constraint events_name_not_blank
check (length(btrim(name)) > 0);

create function private.protect_event_lifecycle()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception using errcode = 'P0001', message = 'event_delete_forbidden';
  end if;

  if old.status = 'archived' and new is distinct from old then
    raise exception using errcode = 'P0001', message = 'event_archived_immutable';
  end if;

  return new;
end;
$$;

create trigger protect_event_lifecycle
before update or delete on public.events
for each row execute function private.protect_event_lifecycle();

create function private.archive_and_create_event_impl(
  target_event uuid,
  confirmed_name text,
  actor uuid
)
returns table (
  archived_event_id uuid,
  new_event_id uuid
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_event public.events;
  created_id uuid;
begin
  if actor is null or not exists (
    select 1
    from public.profiles as profile
    where profile.id = actor
      and profile.global_role = 'global_admin'
  ) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  select event.*
  into current_event
  from public.events as event
  where event.id = target_event
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'event_not_found';
  end if;

  if current_event.name is distinct from confirmed_name then
    raise exception using errcode = 'P0001', message = 'event_name_mismatch';
  end if;

  if current_event.status = 'archived' then
    raise exception using errcode = 'P0001', message = 'event_already_archived';
  end if;

  if not current_event.is_featured then
    raise exception using errcode = 'P0001', message = 'event_not_featured';
  end if;

  update public.events as event
  set
    status = 'archived',
    archived_at = now(),
    is_featured = false
  where event.id = target_event;

  insert into public.events (
    name,
    slug,
    status,
    is_featured,
    created_by
  )
  values (
    current_event.name || ' — novo',
    current_event.slug || '-' || gen_random_uuid()::text,
    'draft',
    true,
    actor
  )
  returning id into created_id;

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
    actor,
    'event_archived',
    'event',
    target_event::text,
    jsonb_build_object('new_event_id', created_id)
  );

  return query select target_event, created_id;
end;
$$;

create view private.event_lifecycle_dispatch
with (security_invoker = true)
as
select
  null::uuid as target_event,
  null::text as confirmed_name,
  null::uuid as actor,
  null::uuid as archived_event_id,
  null::uuid as new_event_id
where false;

create function private.dispatch_event_lifecycle()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  select
    result.archived_event_id,
    result.new_event_id
  into
    new.archived_event_id,
    new.new_event_id
  from private.archive_and_create_event_impl(
    new.target_event,
    new.confirmed_name,
    new.actor
  ) as result;

  return new;
end;
$$;

create trigger dispatch_event_lifecycle
instead of insert on private.event_lifecycle_dispatch
for each row execute function private.dispatch_event_lifecycle();

create function public.archive_and_create_event(
  target_event uuid,
  confirmed_name text,
  actor uuid
)
returns table (
  archived_event_id uuid,
  new_event_id uuid
)
language plpgsql
security invoker
set search_path = ''
as $$
begin
  insert into private.event_lifecycle_dispatch (
    target_event,
    confirmed_name,
    actor
  )
  values (
    target_event,
    confirmed_name,
    actor
  )
  returning
    event_lifecycle_dispatch.archived_event_id,
    event_lifecycle_dispatch.new_event_id
  into
    archived_event_id,
    new_event_id;

  return next;
end;
$$;

revoke all on function
  private.protect_event_lifecycle(),
  private.archive_and_create_event_impl(uuid, text, uuid),
  private.dispatch_event_lifecycle()
from public, anon, authenticated, service_role;

revoke all on table private.event_lifecycle_dispatch
from public, anon, authenticated, service_role;

revoke all on function
  public.archive_and_create_event(uuid, text, uuid)
from public, anon, authenticated, service_role;

grant usage on schema private to service_role;
grant insert (
  target_event,
  confirmed_name,
  actor
) on private.event_lifecycle_dispatch to service_role;
grant select (
  archived_event_id,
  new_event_id
) on private.event_lifecycle_dispatch to service_role;
grant execute on function
  public.archive_and_create_event(uuid, text, uuid) to service_role;
grant select (id, global_role) on public.profiles to service_role;

comment on function private.archive_and_create_event_impl(uuid, text, uuid) is
  'Atomic privileged event archive, replacement creation, and audit implementation.';

comment on function public.archive_and_create_event(uuid, text, uuid) is
  'Server-only invoker wrapper. Execute is granted only to service_role.';

comment on view private.event_lifecycle_dispatch is
  'Non-exposed invoker bridge to the privileged event lifecycle trigger.';
