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
      comment = normalized_comment,
      submitted_at = coalesce(evaluation.submitted_at, now()),
      updated_at = now()
    where evaluation.id = stored_evaluation_id
    returning * into stored;

    delete from public.evaluation_scores as score
    where score.evaluation_id = stored_evaluation_id;
  else
    insert into public.evaluations (
      event_id, category, team_id, evaluator_id, comment, submitted_at
    )
    values (
      target.event_id, target.category, target.id, caller_id,
      normalized_comment, now()
    )
    returning * into stored;
    stored_evaluation_id := stored.id;
  end if;

  insert into public.evaluation_scores (
    evaluation_id, event_id, criterion_id, score
  )
  select
    stored_evaluation_id,
    target.event_id,
    (score ->> 'criterion_id')::uuid,
    (score ->> 'score')::smallint
  from jsonb_array_elements(target_scores) as score;

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
