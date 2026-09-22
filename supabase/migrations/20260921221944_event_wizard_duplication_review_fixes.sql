-- Preserve archive immutability while allowing global administrators to
-- configure non-archived events and copy configuration from archived sources.

drop policy "global admins create canvas templates" on public.canvas_templates;
create policy "global admins create canvas templates"
on public.canvas_templates for insert to authenticated
with check (
  (select public.is_global_admin())
  and exists (
    select 1 from public.events as event
    where event.id = canvas_templates.event_id
      and event.status <> 'archived'
  )
);

drop policy "global admins create canvas template blocks" on public.canvas_template_blocks;
create policy "global admins create canvas template blocks"
on public.canvas_template_blocks for insert to authenticated
with check (
  (select public.is_global_admin())
  and exists (
    select 1
    from public.canvas_templates as template
    join public.events as event on event.id = template.event_id
    where template.id = canvas_template_blocks.template_id
      and event.status <> 'archived'
  )
);

drop policy "global admins create canvas activities" on public.canvas_activities;
create policy "global admins create canvas activities"
on public.canvas_activities for insert to authenticated
with check (
  (select public.is_global_admin())
  and exists (
    select 1 from public.events as event
    where event.id = canvas_activities.event_id
      and event.status <> 'archived'
  )
);

drop policy "global admins delete canvas activities" on public.canvas_activities;
create policy "global admins delete canvas activities"
on public.canvas_activities for delete to authenticated
using (
  (select public.is_global_admin())
  and exists (
    select 1 from public.events as event
    where event.id = canvas_activities.event_id
      and event.status <> 'archived'
  )
);

drop policy "global admins update canvas activities" on public.canvas_activities;
create policy "global admins update canvas activities"
on public.canvas_activities for update to authenticated
using (
  (select public.is_global_admin())
  and exists (
    select 1 from public.events as event
    where event.id = canvas_activities.event_id
      and event.status <> 'archived'
  )
)
with check (
  (select public.is_global_admin())
  and exists (
    select 1 from public.events as event
    where event.id = canvas_activities.event_id
      and event.status <> 'archived'
  )
);

drop policy "global admins manage canvas blocks" on public.canvas_blocks;
create policy "global admins manage canvas blocks"
on public.canvas_blocks for all to authenticated
using (
  (select public.is_global_admin())
  and exists (
    select 1
    from public.canvas_activities as activity
    join public.events as event on event.id = activity.event_id
    where activity.id = canvas_blocks.activity_id
      and event.status <> 'archived'
  )
)
with check (
  (select public.is_global_admin())
  and exists (
    select 1
    from public.canvas_activities as activity
    join public.events as event on event.id = activity.event_id
    where activity.id = canvas_blocks.activity_id
      and event.status <> 'archived'
  )
);

create function private.lock_event_configuration_source(source_event_id uuid)
returns public.events
language plpgsql
security definer
set search_path = ''
as $$
declare
  source public.events;
begin
  if (select auth.uid()) is null or not exists (
    select 1 from public.profiles as profile
    where profile.id = (select auth.uid())
      and profile.global_role = 'global_admin'
  ) then
    raise exception using errcode = '42501', message = 'forbidden';
  end if;

  select event.* into source
  from public.events as event
  where event.id = source_event_id
  for update;
  if not found then
    raise exception using errcode = '22023', message = 'source_event_not_found';
  end if;

  return source;
end;
$$;

revoke all on function private.lock_event_configuration_source(uuid)
from public, anon, authenticated, service_role;
grant execute on function private.lock_event_configuration_source(uuid)
to authenticated;

create or replace function public.duplicate_event_configuration(
  source_event_id uuid,
  draft jsonb,
  copy_options jsonb
)
returns table (event_id uuid)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  source public.events;
  validated record;
  actor_id uuid := (select auth.uid());
  option_key text;
  source_template public.canvas_templates;
  source_activity public.canvas_activities;
  target_event_id uuid;
  new_template_id uuid;
  new_activity_id uuid;
  template_id_map jsonb := '{}'::jsonb;
begin
  if actor_id is null or not (select public.is_global_admin()) then
    raise exception using errcode = '42501', message = 'forbidden';
  end if;
  if jsonb_typeof(copy_options) <> 'object' then
    raise exception using errcode = '22023', message = 'invalid_copy_options';
  end if;
  for option_key in select jsonb_object_keys(copy_options)
  loop
    if option_key not in ('public_content', 'evaluation', 'canvas', 'workshops', 'general')
      or jsonb_typeof(copy_options -> option_key) <> 'boolean'
    then
      raise exception using errcode = '22023', message = 'invalid_copy_options';
    end if;
  end loop;

  select * into source
  from private.lock_event_configuration_source(source_event_id);
  select * into validated from private.validate_event_draft(draft);

  insert into public.events (
    name, slug, status, is_featured, starts_at, ends_at, professor_id, created_by
  ) values (
    validated.name, validated.slug, 'draft', false,
    case when coalesce((copy_options ->> 'general')::boolean, false) then source.starts_at end,
    case when coalesce((copy_options ->> 'general')::boolean, false) then source.ends_at end,
    validated.professor_id, actor_id
  ) returning id into target_event_id;

  insert into public.event_roles (event_id, user_id, role, approved_by)
  values (target_event_id, validated.professor_id, 'professor', actor_id);

  update public.canvas_activities as activity
  set published = false
  where activity.event_id = target_event_id;

  if coalesce((copy_options ->> 'public_content')::boolean, false) then
    insert into public.event_public_content (
      event_id, tagline, presentation, objectives, venue, date_label, registration_open, updated_by
    )
    select target_event_id, src.tagline, src.presentation, src.objectives,
      src.venue, src.date_label, false, actor_id
    from public.event_public_content as src
    where src.event_id = source_event_id;

    insert into public.event_schedule_items (event_id, day_number, starts_at, activity, position)
    select target_event_id, src.day_number, src.starts_at, src.activity, src.position
    from public.event_schedule_items as src
    where src.event_id = source_event_id;
  end if;

  if coalesce((copy_options ->> 'evaluation')::boolean, false) then
    update public.events set professor_id = actor_id where id = target_event_id;
    delete from public.evaluation_criteria as criterion where criterion.event_id = target_event_id;
    insert into public.evaluation_criteria (event_id, name, description, position, active)
    select target_event_id, src.name, src.description, src.position, src.active
    from public.evaluation_criteria as src
    where src.event_id = source_event_id;
    delete from public.criterion_weights as weight where weight.event_id = target_event_id;
    insert into public.criterion_weights (event_id, criterion_id, category, weight)
    select target_event_id, target.id, src_weight.category, src_weight.weight
    from public.criterion_weights as src_weight
    join public.evaluation_criteria as source_criterion
      on source_criterion.id = src_weight.criterion_id
    join public.evaluation_criteria as target
      on target.event_id = target_event_id and target.name = source_criterion.name
    where src_weight.event_id = source_event_id;
    update public.events set professor_id = validated.professor_id where id = target_event_id;
  end if;

  if coalesce((copy_options ->> 'canvas')::boolean, false) then
    delete from public.canvas_activities as activity where activity.event_id = target_event_id;
    for source_template in
      select * from public.canvas_templates as template
      where template.event_id = source_event_id
      order by template.created_at, template.id
    loop
      insert into public.canvas_templates (event_id, name, instructions, created_by)
      values (target_event_id, source_template.name, source_template.instructions, actor_id)
      returning id into new_template_id;
      template_id_map := template_id_map || jsonb_build_object(
        source_template.id::text, new_template_id::text
      );
      insert into public.canvas_template_blocks (template_id, key, title, prompt, position, max_items)
      select new_template_id, block.key, block.title, block.prompt, block.position, block.max_items
      from public.canvas_template_blocks as block
      where block.template_id = source_template.id;
    end loop;

    for source_activity in
      select * from public.canvas_activities as activity
      where activity.event_id = source_event_id
      order by activity.created_at, activity.id
    loop
      new_template_id := nullif(
        template_id_map ->> source_activity.template_id::text, ''
      )::uuid;
      insert into public.canvas_activities (
        event_id, template_id, title, instructions, categories, opens_at, due_at,
        published, is_primary, allow_resubmission, created_by
      ) values (
        target_event_id, new_template_id, source_activity.title, source_activity.instructions,
        source_activity.categories, source_activity.opens_at, source_activity.due_at,
        false, source_activity.is_primary, source_activity.allow_resubmission, actor_id
      ) returning id into new_activity_id;
      insert into public.canvas_blocks (activity_id, key, title, prompt, position, max_items)
      select new_activity_id, block.key, block.title, block.prompt, block.position, block.max_items
      from public.canvas_blocks as block
      where block.activity_id = source_activity.id
      on conflict (activity_id, key) do update
      set title = excluded.title,
          prompt = excluded.prompt,
          position = excluded.position,
          max_items = excluded.max_items;
    end loop;
  end if;

  if coalesce((copy_options ->> 'workshops')::boolean, false) then
    insert into public.workshops (event_id, title, description, starts_at, ends_at, capacity, created_by)
    select target_event_id, src.title, src.description, src.starts_at, src.ends_at,
      src.capacity, actor_id
    from public.workshops as src
    where src.event_id = source_event_id;
  end if;

  event_id := target_event_id;
  return next;
end;
$$;

create or replace function private.assert_current_professor_or_global_admin(target_event uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;
  if target_event is null then
    raise exception using errcode = 'P0001', message = 'event_required';
  end if;
  if not exists (
    select 1
    from public.events as event
    where event.id = target_event
      and event.status <> 'archived'
      and (
        exists (
          select 1 from public.profiles as profile
          where profile.id = caller_id
            and profile.global_role = 'global_admin'
        )
        or (
          event.professor_id = caller_id
          and exists (
            select 1 from public.event_roles as role_assignment
            where role_assignment.event_id = event.id
              and role_assignment.user_id = caller_id
              and role_assignment.role = 'professor'
          )
        )
      )
  ) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;
end;
$$;

revoke all on function private.assert_current_professor_or_global_admin(uuid)
from public, anon, authenticated, service_role;

create or replace function public.get_event_public_content_for_edit(target_event uuid)
returns table (
  tagline text,
  presentation text,
  objectives jsonb,
  venue text,
  date_label text,
  registration_open boolean,
  schedule jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.assert_current_professor_or_global_admin($1);
  return query
  select
    content.tagline,
    content.presentation,
    content.objectives,
    content.venue,
    content.date_label,
    content.registration_open,
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'dayNumber', item.day_number,
        'startsAt', to_char(item.starts_at, 'HH24:MI'),
        'activity', item.activity,
        'position', item.position
      ) order by item.day_number, item.position)
      from public.event_schedule_items as item
      where item.event_id = $1
    ), '[]'::jsonb)
  from public.event_public_content as content
  where content.event_id = $1;
end;
$$;

create or replace function public.save_event_public_content(
  target_event uuid,
  content jsonb
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
begin
  perform private.assert_current_professor_or_global_admin($1);
  perform private.validate_public_content_payload($2);

  insert into public.event_public_content (
    event_id, tagline, presentation, objectives, venue, date_label,
    registration_open, updated_at, updated_by
  ) values (
    $1, btrim($2 ->> 'tagline'), btrim($2 ->> 'presentation'),
    (select jsonb_agg(to_jsonb(btrim(value #>> '{}')) order by ordinal)
      from jsonb_array_elements($2 -> 'objectives')
        with ordinality as objective(value, ordinal)),
    btrim($2 ->> 'venue'), btrim($2 ->> 'dateLabel'),
    ($2 ->> 'registrationOpen')::boolean, now(), caller_id
  ) on conflict (event_id) do update
  set tagline = excluded.tagline,
      presentation = excluded.presentation,
      objectives = excluded.objectives,
      venue = excluded.venue,
      date_label = excluded.date_label,
      registration_open = excluded.registration_open,
      updated_at = excluded.updated_at,
      updated_by = excluded.updated_by;

  delete from public.event_schedule_items as item where item.event_id = $1;
  insert into public.event_schedule_items (
    event_id, day_number, starts_at, activity, position
  )
  select $1, (item ->> 'dayNumber')::smallint, (item ->> 'startsAt')::time,
    btrim(item ->> 'activity'), (item ->> 'position')::integer
  from jsonb_array_elements($2 -> 'schedule') as schedule(item);

  insert into public.audit_log (
    event_id, actor_id, action, entity_type, entity_id, payload
  ) values (
    $1, caller_id, 'event_public_content_saved', 'event_public_content',
    $1::text, jsonb_build_object(
      'objective_count', jsonb_array_length($2 -> 'objectives'),
      'schedule_item_count', jsonb_array_length($2 -> 'schedule'),
      'registration_open', ($2 ->> 'registrationOpen')::boolean
    )
  );
end;
$$;
