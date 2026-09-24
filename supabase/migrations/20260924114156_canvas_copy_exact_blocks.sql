-- A copied template can grow after one of its activities was created. The
-- activity-insert trigger seeds the copied activity from that current template,
-- so the duplication RPC must discard seeded rows that have no source block.
-- This remains a controlled operation: clients keep no DELETE grant on Canvas
-- blocks and the RPC verifies the authenticated global administrator itself.
create or replace function public.duplicate_event_configuration(
  source_event_id uuid,
  draft jsonb,
  copy_options jsonb
)
returns table (event_id uuid)
language plpgsql
security definer
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
  source_block_count integer;
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

  select * into source from private.lock_event_configuration_source(source_event_id);
  select * into validated from private.validate_event_draft(draft);

  insert into public.events (name, slug, status, is_featured, starts_at, ends_at, professor_id, created_by)
  values (
    validated.name, validated.slug, 'draft', false,
    case when coalesce((copy_options ->> 'general')::boolean, false) then source.starts_at end,
    case when coalesce((copy_options ->> 'general')::boolean, false) then source.ends_at end,
    validated.professor_id, actor_id
  ) returning id into target_event_id;

  insert into public.event_roles (event_id, user_id, role, approved_by)
  values (target_event_id, validated.professor_id, 'professor', actor_id);
  update public.canvas_activities as activity set published = false where activity.event_id = target_event_id;

  if coalesce((copy_options ->> 'public_content')::boolean, false) then
    insert into public.event_public_content (event_id, tagline, presentation, objectives, venue, date_label, registration_open, updated_by)
    select target_event_id, src.tagline, src.presentation, src.objectives, src.venue, src.date_label, false, actor_id
    from public.event_public_content as src where src.event_id = source_event_id;
    insert into public.event_schedule_items (event_id, day_number, starts_at, activity, position)
    select target_event_id, src.day_number, src.starts_at, src.activity, src.position
    from public.event_schedule_items as src where src.event_id = source_event_id;
  end if;

  if coalesce((copy_options ->> 'evaluation')::boolean, false) then
    update public.events set professor_id = actor_id where id = target_event_id;
    delete from public.evaluation_criteria as criterion where criterion.event_id = target_event_id;
    insert into public.evaluation_criteria (event_id, name, description, position, active)
    select target_event_id, src.name, src.description, src.position, src.active
    from public.evaluation_criteria as src where src.event_id = source_event_id;
    delete from public.criterion_weights as weight where weight.event_id = target_event_id;
    insert into public.criterion_weights (event_id, criterion_id, category, weight)
    select target_event_id, target.id, src_weight.category, src_weight.weight
    from public.criterion_weights as src_weight
    join public.evaluation_criteria as source_criterion on source_criterion.id = src_weight.criterion_id
    join public.evaluation_criteria as target on target.event_id = target_event_id and target.name = source_criterion.name
    where src_weight.event_id = source_event_id;
    update public.events set professor_id = validated.professor_id where id = target_event_id;
  end if;

  if coalesce((copy_options ->> 'canvas')::boolean, false) then
    delete from public.canvas_activities as activity where activity.event_id = target_event_id;
    for source_template in
      select * from public.canvas_templates as template where template.event_id = source_event_id order by template.created_at, template.id
    loop
      insert into public.canvas_templates (event_id, name, instructions, created_by)
      values (target_event_id, source_template.name, source_template.instructions, actor_id)
      returning id into new_template_id;
      template_id_map := template_id_map || jsonb_build_object(source_template.id::text, new_template_id::text);
      insert into public.canvas_template_blocks (template_id, key, title, prompt, position, max_items)
      select new_template_id, block.key, block.title, block.prompt, block.position, block.max_items
      from public.canvas_template_blocks as block where block.template_id = source_template.id;
    end loop;

    for source_activity in
      select * from public.canvas_activities as activity where activity.event_id = source_event_id order by activity.created_at, activity.id
    loop
      new_template_id := nullif(template_id_map ->> source_activity.template_id::text, '')::uuid;
      insert into public.canvas_activities (event_id, template_id, title, instructions, categories, opens_at, due_at, published, is_primary, allow_resubmission, created_by)
      values (target_event_id, new_template_id, source_activity.title, source_activity.instructions, source_activity.categories, source_activity.opens_at, source_activity.due_at, false, source_activity.is_primary, source_activity.allow_resubmission, actor_id)
      returning id into new_activity_id;

      -- Release both unique dimensions before any source key/position is
      -- restored. This keeps source rename/reorder copies collision-free.
      update public.canvas_blocks as target
      set key = 'copy-' || target.id::text,
          position = target.position + 1000000
      where target.activity_id = new_activity_id;

      select count(*)::integer into source_block_count
      from public.canvas_blocks as block
      where block.activity_id = source_activity.id;

      -- A newer template may have seeded more rows than the source activity.
      -- Every target row still has its temporary key/position here, so deleting
      -- the surplus cannot collide with a source key or position.
      with seeded_target_blocks as (
        select block.id, row_number() over (order by block.position, block.id) as ordinal
        from public.canvas_blocks as block
        where block.activity_id = new_activity_id
      )
      delete from public.canvas_blocks as target
      using seeded_target_blocks as seeded
      where target.id = seeded.id
        and seeded.ordinal > source_block_count;

      with source_blocks as (
        select block.key, block.title, block.prompt, block.position, block.max_items,
          row_number() over (order by block.position, block.id) as ordinal
        from public.canvas_blocks as block
        where block.activity_id = source_activity.id
      ), target_blocks as (
        select block.id, row_number() over (order by block.position, block.id) as ordinal
        from public.canvas_blocks as block
        where block.activity_id = new_activity_id
      )
      update public.canvas_blocks as target
      set key = src_block.key,
          title = src_block.title,
          prompt = src_block.prompt,
          position = src_block.position,
          max_items = src_block.max_items
      from target_blocks as mapped
      join source_blocks as src_block on src_block.ordinal = mapped.ordinal
      where target.id = mapped.id;

      insert into public.canvas_blocks (activity_id, key, title, prompt, position, max_items)
      select new_activity_id, src_block.key, src_block.title, src_block.prompt, src_block.position, src_block.max_items
      from (
        select block.key, block.title, block.prompt, block.position, block.max_items,
          row_number() over (order by block.position, block.id) as ordinal
        from public.canvas_blocks as block
        where block.activity_id = source_activity.id
      ) as src_block
      where src_block.ordinal > (
        select count(*) from public.canvas_blocks as target
        where target.activity_id = new_activity_id
      );
    end loop;
  end if;

  if coalesce((copy_options ->> 'workshops')::boolean, false) then
    insert into public.workshops (event_id, title, description, starts_at, ends_at, capacity, created_by)
    select target_event_id, src.title, src.description, src.starts_at, src.ends_at, src.capacity, actor_id
    from public.workshops as src where src.event_id = source_event_id;
  end if;

  event_id := target_event_id;
  return next;
end;
$$;

revoke all on function public.duplicate_event_configuration(uuid, jsonb, jsonb)
from public, anon, authenticated, service_role;
grant execute on function public.duplicate_event_configuration(uuid, jsonb, jsonb)
to authenticated;
