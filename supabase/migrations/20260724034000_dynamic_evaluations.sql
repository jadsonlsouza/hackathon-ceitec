-- 1. Simplify protect_presentation_slot to allow auto-inserts
create or replace function private.protect_presentation_slot()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_event uuid := case
    when tg_op = 'DELETE' then old.event_id else new.event_id
  end;
  event_state public.event_status;
begin
  select event.status
  into event_state
  from public.events as event
  where event.id = target_event
  for update;

  if not found or event_state = 'archived' then
    raise exception using errcode = 'P0001', message = 'event_not_available';
  end if;

  if tg_op <> 'DELETE' then
    if not exists (
      select 1 from public.teams as team
      where team.id = new.team_id
        and team.event_id = new.event_id
        and team.category = new.category
        and team.status = 'approved'
    ) then
      raise exception using
        errcode = 'P0001',
        message = 'approved_team_category_required';
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

-- 2. Trigger to auto insert into presentation_slots
create or replace function public.auto_insert_presentation_slot()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  next_position integer;
begin
  if new.status = 'approved' then
    select coalesce(max(position), 0) + 1
    into next_position
    from public.presentation_slots
    where event_id = new.event_id
      and category = new.category;

    insert into public.presentation_slots (
      event_id, category, team_id, position
    )
    values (
      new.event_id, new.category, new.id, next_position
    )
    on conflict do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists auto_insert_presentation_slot_trigger_insert on public.teams;
create trigger auto_insert_presentation_slot_trigger_insert
after insert on public.teams
for each row
when (new.status = 'approved')
execute function public.auto_insert_presentation_slot();

drop trigger if exists auto_insert_presentation_slot_trigger_update on public.teams;
create trigger auto_insert_presentation_slot_trigger_update
after update on public.teams
for each row
when (new.status = 'approved' and old.status <> 'approved')
execute function public.auto_insert_presentation_slot();

-- Seed slots for currently approved teams that don't have slots
insert into public.presentation_slots (event_id, category, team_id, position)
select 
  t.event_id, 
  t.category, 
  t.id,
  coalesce((select max(position) from public.presentation_slots where event_id = t.event_id and category = t.category), 0) + row_number() over (partition by t.event_id, t.category order by t.created_at)
from public.teams t
left join public.presentation_slots p on p.team_id = t.id
where t.status = 'approved' and p.team_id is null;

-- 3. Rewrite submit_evaluation_impl to NOT require evaluation_freezes
create or replace function private.submit_evaluation_impl(
  target_team uuid,
  target_scores jsonb,
  target_comment text
)
returns public.evaluations
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target public.teams;
  event_state public.event_status;
  normalized_comment text := nullif(btrim(target_comment), '');
  expected_count integer;
  stored_evaluation_id uuid;
  existed boolean := false;
  stored public.evaluations;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;
  if target_team is null then
    raise exception using errcode = 'P0001', message = 'team_required';
  end if;
  if normalized_comment is not null
    and char_length(normalized_comment) > 4000
  then
    raise exception using errcode = 'P0001', message = 'comment_too_long';
  end if;

  select team.*
  into target
  from public.teams as team
  where team.id = target_team;

  if not found then
    raise exception using errcode = 'P0001', message = 'team_not_found';
  end if;

  select event.status
  into event_state
  from public.events as event
  where event.id = target.event_id
  for update;

  if not found or event_state = 'archived' then
    raise exception using errcode = 'P0001', message = 'event_not_available';
  end if;

  if not exists (
    select 1
    from public.evaluator_assignments as assignment
    where assignment.event_id = target.event_id
      and assignment.category = target.category
      and assignment.evaluator_id = caller_id
  ) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  -- Bypassing freeze requirement: just validate scores against current weights
  select count(*)::integer
  into expected_count
  from public.criterion_weights as weight
  where weight.event_id = target.event_id
    and weight.category = target.category;

  if expected_count = 0 then
    raise exception using errcode = 'P0001', message = 'evaluation_not_frozen'; -- keeping error name for frontend compatibility
  end if;

  if expected_count <> coalesce(jsonb_array_length(target_scores), 0) then
    raise exception using errcode = 'P0001', message = 'invalid_score_count';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(target_scores) as score
    where jsonb_typeof(score) <> 'object'
      or not (score ? 'criterion_id')
      or not (score ? 'score')
      or not exists (
        select 1
        from public.criterion_weights as weight
        where weight.event_id = target.event_id
          and weight.category = target.category
          and weight.criterion_id = (score ->> 'criterion_id')::uuid
      )
      or (score ->> 'score')::integer not between 1 and 5
  ) then
    raise exception using errcode = 'P0001', message = 'invalid_score_format';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(target_scores) as score
    group by (score ->> 'criterion_id')
    having count(*) > 1
  ) then
    raise exception using errcode = 'P0001', message = 'duplicate_score_criterion';
  end if;

  select evaluation.id
  into stored_evaluation_id
  from public.evaluations as evaluation
  where evaluation.event_id = target.event_id
    and evaluation.category = target.category
    and evaluation.team_id = target.id
    and evaluation.evaluator_id = caller_id
  for update;

  if found then
    existed := true;
    update public.evaluations as evaluation
    set
      scores = target_scores,
      comment = normalized_comment,
      submitted_at = coalesce(evaluation.submitted_at, now()),
      updated_at = now()
    where evaluation.id = stored_evaluation_id
    returning * into stored;
  else
    insert into public.evaluations (
      event_id, category, team_id, evaluator_id, scores, comment, submitted_at
    )
    values (
      target.event_id, target.category, target.id, caller_id,
      target_scores, normalized_comment, now()
    )
    returning * into stored;
  end if;

  insert into public.audit_log (
    event_id, actor_id, action, entity_type, entity_id, payload
  )
  values (
    target.event_id,
    caller_id,
    case when existed then 'evaluation_updated' else 'evaluation_submitted' end,
    'evaluation',
    stored.id::text,
    jsonb_build_object(
      'category', target.category,
      'team_id', target.id
    )
  );

  return stored;
end;
$$;
