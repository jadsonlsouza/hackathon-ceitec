-- Keep archived event history immutable even for the controlled team-delete
-- workflow.  The notification migration restored privileged deletes so it
-- must check the parent event before its delete-specific early returns.
create or replace function private.protect_team_event_write()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target_event_id uuid;
  target_status public.event_status;
  reserved_seats integer;
begin
  if tg_op = 'DELETE' then
    target_event_id := old.event_id;
    select event.status into target_status
    from public.events as event
    where event.id = target_event_id
    for update;
    if not found or target_status = 'archived' then
      raise exception using errcode = 'P0001', message = 'event_not_available';
    end if;

    if tg_table_name = 'teams' then
      if current_setting('app.admin_delete_team', true) = 'true'
        and (
          (select public.is_event_professor(old.event_id))
          or (select public.is_global_admin())
        )
      then
        return old;
      end if;
      raise exception using errcode = 'P0001', message = 'team_delete_forbidden';
    end if;

    if (select public.is_event_professor(old.event_id))
      or (select public.is_global_admin())
    then
      return old;
    end if;
    raise exception using errcode = 'P0001', message = 'team_member_delete_forbidden';
  end if;

  if tg_op = 'UPDATE' and new.event_id is distinct from old.event_id then
    raise exception using errcode = 'P0001', message = 'cross_event_move_forbidden';
  end if;

  target_event_id := new.event_id;
  select event.status into target_status
  from public.events as event where event.id = target_event_id;
  if not found or target_status = 'archived' then
    raise exception using errcode = 'P0001', message = 'event_not_available';
  end if;

  if tg_table_name = 'team_members' then
    if new.status::text in ('invited', 'join_requested', 'active')
      and (
        tg_op = 'INSERT'
        or old.status::text not in ('invited', 'join_requested', 'active')
        or old.team_id is distinct from new.team_id
      )
    then
      perform 1 from public.teams as team
      where team.id = new.team_id and team.event_id = new.event_id for update;
      if not found then raise exception using errcode = 'P0001', message = 'cross_event_reference'; end if;

      select count(*)::integer into reserved_seats
      from public.team_members as member
      where member.team_id = new.team_id
        and member.event_id = new.event_id
        and member.status in ('invited', 'join_requested', 'active');
      if reserved_seats >= 6 then raise exception using errcode = 'P0001', message = 'team_size_out_of_range'; end if;
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.admin_delete_team(p_team_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event_id uuid;
  v_event_status public.event_status;
  caller_id uuid := (select auth.uid());
begin
  if caller_id is null then raise exception using errcode = 'P0001', message = 'authentication_required'; end if;

  select team.event_id, event.status
  into v_event_id, v_event_status
  from public.teams as team
  join public.events as event on event.id = team.event_id
  where team.id = p_team_id
  for update of team, event;
  if not found then raise exception using errcode = 'P0001', message = 'team_not_found'; end if;
  if v_event_status = 'archived' then
    raise exception using errcode = 'P0001', message = 'event_not_available';
  end if;

  if not private.current_event_professor(v_event_id, caller_id)
    and not exists (
      select 1 from public.profiles as profile
      where profile.id = caller_id and profile.global_role = 'global_admin'
    )
  then raise exception using errcode = 'P0001', message = 'forbidden'; end if;

  perform set_config('app.admin_delete_team', 'true', true);
  delete from public.presentation_slots where team_id = p_team_id;
  delete from public.evaluation_scores where evaluation_id in (select id from public.evaluations where team_id = p_team_id);
  delete from public.evaluations where team_id = p_team_id;
  delete from public.submissions where team_id = p_team_id;
  delete from public.team_members where team_id = p_team_id;
  delete from public.workshop_enrollments where team_id = p_team_id;
  delete from public.teams where id = p_team_id;
end;
$$;

-- A template trigger seeds the target activity before this RPC can copy the
-- source blocks.  The public RPC is deliberately SECURITY INVOKER and clients
-- do not receive DELETE on blocks, so move the seeded rows to unique temporary
-- keys/positions and then overwrite them in a deterministic order.  A source
-- activity tied to a copied template has the same block cardinality as its
-- seeded target; template-less activities start with no seeded rows.
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
      update public.canvas_blocks as target
      set key = 'copy-' || target.id::text,
          position = target.position + 1000000
      where target.activity_id = new_activity_id;
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

-- Global administrators may resolve monitor/evaluator requests while using a
-- Professor view, without first creating an artificial event-role assignment.
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
  if caller_id is null then raise exception using errcode = 'P0001', message = 'authentication_required'; end if;
  if decision is null or decision not in ('approved', 'rejected') then raise exception using errcode = 'P0001', message = 'invalid_decision'; end if;

  select request.* into target from public.role_requests as request
  where request.id = request_id and request.status = 'pending' for update;
  if not found then raise exception using errcode = 'P0001', message = 'request_not_pending'; end if;

  select event.* into target_event from public.events as event where event.id = target.event_id for update;
  if not found or target_event.status = 'archived' then raise exception using errcode = 'P0001', message = 'event_not_available'; end if;

  if target.requested_role = 'professor' then
    if not exists (select 1 from public.profiles as profile where profile.id = caller_id and profile.global_role = 'global_admin') then
      raise exception using errcode = 'P0001', message = 'forbidden';
    end if;
  elsif not exists (select 1 from public.profiles as profile where profile.id = caller_id and profile.global_role = 'global_admin')
    and not exists (select 1 from public.event_roles where event_id = target.event_id and user_id = caller_id and role = 'professor')
  then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  update public.role_requests as request
  set status = decision, decided_by = caller_id, decided_at = now()
  where request.id = target.id returning * into target;

  if decision = 'approved' then
    insert into public.event_roles (event_id, user_id, role, approved_by)
    values (target.event_id, target.user_id, target.requested_role, caller_id)
    on conflict (event_id, user_id, role) do nothing;
    if target.requested_role = 'professor' then
      update public.events as event set professor_id = target.user_id
      where event.id = target.event_id and event.professor_id is null;
    end if;
  end if;

  insert into public.audit_log (event_id, actor_id, action, entity_type, entity_id, payload)
  values (
    target.event_id, caller_id,
    case when decision = 'approved' then 'role_request_approved' else 'role_request_rejected' end,
    'role_request', target.id::text,
    jsonb_build_object('requested_role', target.requested_role, 'user_id', target.user_id)
  );
  return target;
end;
$$;
