-- Replace archive_and_create_event with a version that optionally copies
-- evaluation criteria, criterion weights, and canvas templates to the new event.

-- Drop the current public wrapper (service_role only) and dispatch path.
drop function if exists public.archive_and_create_event(uuid, text, uuid);
drop function if exists private.dispatch_event_lifecycle() cascade;
drop function if exists private.archive_and_create_event_impl(uuid, text, uuid);
drop view  if exists private.event_lifecycle_dispatch;

-- New implementation with copy_config flag.
create function private.archive_and_create_event_impl(
  target_event uuid,
  confirmed_name text,
  actor uuid,
  copy_config boolean default false
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
  created_id    uuid;
  old_crit_id   uuid;
  new_crit_id   uuid;
  old_tmpl_id   uuid;
  new_tmpl_id   uuid;
begin
  -- Authorization: caller must be a global admin.
  if actor is null or not exists (
    select 1
    from public.profiles as profile
    where profile.id = actor
      and profile.global_role = 'global_admin'
  ) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  -- Lock and validate the target event.
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

  -- Archive the current event.
  update public.events as event
  set
    status      = 'archived',
    archived_at = now(),
    is_featured = false
  where event.id = target_event;

  -- Create the replacement event in draft state.
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

  -- Optionally copy reusable configuration to the new event.
  if copy_config then

    -- 1. Public event content (tagline, presentation, objectives, venue, schedule).
    insert into public.event_public_content (
      event_id, tagline, presentation, objectives, venue, date_label, registration_open
    )
    select
      created_id,
      src.tagline,
      src.presentation,
      src.objectives,
      src.venue,
      src.date_label,
      false   -- registration stays closed until the Professor reopens it
    from public.event_public_content as src
    where src.event_id = target_event
    on conflict do nothing;

    insert into public.event_schedule_items (
      id, event_id, day_number, starts_at, activity, position
    )
    select
      gen_random_uuid(),
      created_id,
      src.day_number,
      src.starts_at,
      src.activity,
      src.position
    from public.event_schedule_items as src
    where src.event_id = target_event;

    -- 2. Evaluation criteria (and per-category weights).
    for old_crit_id, new_crit_id in
      insert into public.evaluation_criteria (
        event_id, name, description, position, active
      )
      select
        created_id,
        src.name,
        src.description,
        src.position,
        src.active
      from public.evaluation_criteria as src
      where src.event_id = target_event
      returning
        (
          select old_crit.id
          from public.evaluation_criteria as old_crit
          where old_crit.event_id = target_event
            and old_crit.name     = evaluation_criteria.name
          limit 1
        ),
        id
    loop
      insert into public.criterion_weights (criterion_id, category, weight)
      select new_crit_id, src.category, src.weight
      from public.criterion_weights as src
      where src.criterion_id = old_crit_id
      on conflict do nothing;
    end loop;

    -- 3. Canvas templates (and their blocks).
    for old_tmpl_id, new_tmpl_id in
      insert into public.canvas_templates (
        event_id, name, instructions, created_by
      )
      select
        created_id,
        src.name,
        src.instructions,
        actor
      from public.canvas_templates as src
      where src.event_id = target_event
      returning
        (
          select old_tmpl.id
          from public.canvas_templates as old_tmpl
          where old_tmpl.event_id = target_event
            and old_tmpl.name     = canvas_templates.name
          limit 1
        ),
        id
    loop
      insert into public.canvas_template_blocks (
        template_id, key, title, prompt, position, max_items
      )
      select
        new_tmpl_id,
        src.key,
        src.title,
        src.prompt,
        src.position,
        src.max_items
      from public.canvas_template_blocks as src
      where src.template_id = old_tmpl_id;
    end loop;

  end if;

  -- Audit the archive action.
  insert into public.audit_log (
    event_id, actor_id, action, entity_type, entity_id, payload
  )
  values (
    target_event,
    actor,
    'event_archived',
    'event',
    target_event::text,
    jsonb_build_object(
      'new_event_id', created_id,
      'copy_config',  copy_config
    )
  );

  return query select target_event, created_id;
end;
$$;

-- Recreate the invoker bridge view.
create view private.event_lifecycle_dispatch
with (security_invoker = true)
as
select
  null::uuid    as target_event,
  null::text    as confirmed_name,
  null::uuid    as actor,
  null::boolean as copy_config,
  null::uuid    as archived_event_id,
  null::uuid    as new_event_id
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
    new.actor,
    coalesce(new.copy_config, false)
  ) as result;

  return new;
end;
$$;

create trigger dispatch_event_lifecycle
instead of insert on private.event_lifecycle_dispatch
for each row execute function private.dispatch_event_lifecycle();

-- Public wrapper accessible only by service_role.
create function public.archive_and_create_event(
  target_event   uuid,
  confirmed_name text,
  actor          uuid,
  copy_config    boolean default false
)
returns table (
  archived_event_id uuid,
  new_event_id      uuid
)
language plpgsql
security invoker
set search_path = ''
as $$
begin
  insert into private.event_lifecycle_dispatch (
    target_event,
    confirmed_name,
    actor,
    copy_config
  )
  values (
    target_event,
    confirmed_name,
    actor,
    copy_config
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

-- Permissions.
revoke all on function
  private.archive_and_create_event_impl(uuid, text, uuid, boolean),
  private.dispatch_event_lifecycle()
from public, anon, authenticated, service_role;

revoke all on table private.event_lifecycle_dispatch
from public, anon, authenticated, service_role;

revoke all on function
  public.archive_and_create_event(uuid, text, uuid, boolean)
from public, anon, authenticated, service_role;

grant insert (
  target_event,
  confirmed_name,
  actor,
  copy_config
) on private.event_lifecycle_dispatch to service_role;

grant select (
  archived_event_id,
  new_event_id
) on private.event_lifecycle_dispatch to service_role;

grant execute on function
  public.archive_and_create_event(uuid, text, uuid, boolean) to service_role;

comment on function private.archive_and_create_event_impl(uuid, text, uuid, boolean) is
  'Atomic privileged event archive, replacement creation, optional config copy, and audit.';

comment on function public.archive_and_create_event(uuid, text, uuid, boolean) is
  'Server-only invoker wrapper. Execute is granted only to service_role.';
