
-- Global administrators can create event drafts and copy only reusable
-- configuration. Operational records (teams, people, submissions, reviews,
-- evaluations, rankings, results, audit data, attendance, and notifications)
-- are deliberately outside this migration's read and write scope.

create policy "global admins create event roles"
on public.event_roles for insert to authenticated
with check ((select public.is_global_admin()));

grant insert (event_id, user_id, role, categories, approved_by)
on public.event_roles to authenticated;

create policy "global admins read public event content"
on public.event_public_content for select to authenticated
using ((select public.is_global_admin()));
create policy "global admins create public event content"
on public.event_public_content for insert to authenticated
with check ((select public.is_global_admin()));
create policy "global admins read event schedules"
on public.event_schedule_items for select to authenticated
using ((select public.is_global_admin()));
create policy "global admins create event schedules"
on public.event_schedule_items for insert to authenticated
with check ((select public.is_global_admin()));
grant select, insert on public.event_public_content, public.event_schedule_items
to authenticated;

create policy "global admins read evaluation criteria"
on public.evaluation_criteria for select to authenticated
using ((select public.is_global_admin()));
create policy "global admins manage evaluation criteria"
on public.evaluation_criteria for all to authenticated
using ((select public.is_global_admin()))
with check ((select public.is_global_admin()));
create policy "global admins read criterion weights"
on public.criterion_weights for select to authenticated
using ((select public.is_global_admin()));
create policy "global admins manage criterion weights"
on public.criterion_weights for all to authenticated
using ((select public.is_global_admin()))
with check ((select public.is_global_admin()));
grant select, insert, delete on public.evaluation_criteria, public.criterion_weights
to authenticated;

create policy "global admins read canvas templates"
on public.canvas_templates for select to authenticated
using ((select public.is_global_admin()));
create policy "global admins create canvas templates"
on public.canvas_templates for insert to authenticated
with check ((select public.is_global_admin()));
create policy "global admins read canvas template blocks"
on public.canvas_template_blocks for select to authenticated
using ((select public.is_global_admin()));
create policy "global admins create canvas template blocks"
on public.canvas_template_blocks for insert to authenticated
with check ((select public.is_global_admin()));
create policy "global admins read canvas activities"
on public.canvas_activities for select to authenticated
using ((select public.is_global_admin()));
create policy "global admins create canvas activities"
on public.canvas_activities for insert to authenticated
with check ((select public.is_global_admin()));
create policy "global admins delete canvas activities"
on public.canvas_activities for delete to authenticated
using ((select public.is_global_admin()));
create policy "global admins update canvas activities"
on public.canvas_activities for update to authenticated
using ((select public.is_global_admin()))
with check ((select public.is_global_admin()));
create policy "global admins read canvas blocks"
on public.canvas_blocks for select to authenticated
using ((select public.is_global_admin()));
create policy "global admins manage canvas blocks"
on public.canvas_blocks for all to authenticated
using ((select public.is_global_admin()))
with check ((select public.is_global_admin()));
grant insert (event_id, name, instructions, created_by) on public.canvas_templates to authenticated;
grant insert (event_id, template_id, title, instructions, categories, opens_at, due_at, published, is_primary, allow_resubmission, created_by) on public.canvas_activities to authenticated;
grant delete on public.canvas_activities to authenticated;
grant insert (activity_id, key, title, prompt, position, max_items), update (key, title, prompt, position, max_items) on public.canvas_blocks to authenticated;

create policy "global admins read workshops"
on public.workshops for select to authenticated
using ((select public.is_global_admin()));
create policy "global admins create workshops"
on public.workshops for insert to authenticated
with check ((select public.is_global_admin()));
grant insert (event_id, title, description, starts_at, ends_at, capacity, created_by)
on public.workshops to authenticated;

create function private.validate_event_draft(draft jsonb)
returns table (name text, slug text, professor_id uuid)
language plpgsql
immutable
security invoker
set search_path = ''
as $$
declare
  key text;
begin
  if jsonb_typeof(draft) <> 'object' then
    raise exception using errcode = '22023', message = 'invalid_draft';
  end if;

  for key in select jsonb_object_keys(draft)
  loop
    if key not in ('name', 'slug', 'professor_id') then
      raise exception using errcode = '22023', message = 'invalid_draft';
    end if;
  end loop;

  name := btrim(coalesce(draft ->> 'name', ''));
  slug := btrim(coalesce(draft ->> 'slug', ''));
  if name = '' then
    raise exception using errcode = '22023', message = 'invalid_name';
  end if;
  if slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
    raise exception using errcode = '22023', message = 'invalid_slug';
  end if;
  if coalesce(draft ->> 'professor_id', '') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    raise exception using errcode = '22023', message = 'invalid_professor';
  end if;
  professor_id := (draft ->> 'professor_id')::uuid;
  if not exists (select 1 from public.profiles as profile where profile.id = professor_id) then
    raise exception using errcode = '22023', message = 'invalid_professor';
  end if;
  return next;
end;
$$;

revoke all on function private.validate_event_draft(jsonb)
from public, anon, authenticated, service_role;
grant execute on function private.validate_event_draft(jsonb) to authenticated;

create function public.create_event_draft(draft jsonb)
returns table (event_id uuid)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  validated record;
  actor_id uuid := (select auth.uid());
begin
  if actor_id is null or not (select public.is_global_admin()) then
    raise exception using errcode = '42501', message = 'forbidden';
  end if;

  select * into validated from private.validate_event_draft(draft);

  insert into public.events (name, slug, status, is_featured, professor_id, created_by)
  values (validated.name, validated.slug, 'draft', false, validated.professor_id, actor_id)
  returning id into event_id;

  insert into public.event_roles (event_id, user_id, role, approved_by)
  values (event_id, validated.professor_id, 'professor', actor_id);

  update public.canvas_activities as activity
  set published = false
  where activity.event_id = create_event_draft.event_id;

  return next;
end;
$$;

create function public.duplicate_event_configuration(
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

  select event.* into source
  from public.events as event
  where event.id = source_event_id
  for update;
  if not found then
    raise exception using errcode = '22023', message = 'source_event_not_found';
  end if;

  select * into validated from private.validate_event_draft(draft);
  insert into public.events (
    name, slug, status, is_featured, starts_at, ends_at, professor_id, created_by
  ) values (
    validated.name,
    validated.slug,
    'draft',
    false,
    case when coalesce((copy_options ->> 'general')::boolean, false) then source.starts_at end,
    case when coalesce((copy_options ->> 'general')::boolean, false) then source.ends_at end,
    validated.professor_id,
    actor_id
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
    select target_event_id, src.tagline, src.presentation, src.objectives, src.venue, src.date_label, false, actor_id
    from public.event_public_content as src
    where src.event_id = source_event_id;

    insert into public.event_schedule_items (event_id, day_number, starts_at, activity, position)
    select target_event_id, src.day_number, src.starts_at, src.activity, src.position
    from public.event_schedule_items as src
    where src.event_id = source_event_id;
  end if;

  if coalesce((copy_options ->> 'evaluation')::boolean, false) then
    -- The legacy configuration trigger requires the current event professor.
    -- This temporary value is transaction-local and restored before return.
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
    update public.events
    set professor_id = validated.professor_id
    where id = target_event_id;
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
        source_template.id::text,
        new_template_id::text
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
        template_id_map ->> source_activity.template_id::text,
        ''
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
    select target_event_id, src.title, src.description, src.starts_at, src.ends_at, src.capacity, actor_id
    from public.workshops as src
    where src.event_id = source_event_id;
  end if;

  event_id := target_event_id;
  return next;
end;
$$;

revoke all on function public.create_event_draft(jsonb)
from public, anon, service_role;
revoke all on function public.duplicate_event_configuration(uuid, jsonb, jsonb)
from public, anon, service_role;
grant execute on function public.create_event_draft(jsonb) to authenticated;
grant execute on function public.duplicate_event_configuration(uuid, jsonb, jsonb) to authenticated;
