-- Fix private.resolve_tie_impl to not depend on evaluation_freezes
CREATE OR REPLACE FUNCTION private.resolve_tie_impl(target_event uuid, target_category team_category, target_score numeric, target_order uuid[], target_justification text)
 RETURNS tie_decisions
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  caller_id uuid := (select auth.uid());
  event_state public.event_status;
  normalized_justification text := btrim(target_justification);
  expected_order uuid[];
  normalized_order uuid[];
  fingerprint text;
  team_count integer;
  existing public.tie_decisions;
  stored public.tie_decisions;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;
  if target_event is null or target_category is null or target_score is null then
    raise exception using errcode = 'P0001', message = 'tie_scope_required';
  end if;
  if target_score in (
    'NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric
  ) then
    raise exception using errcode = 'P0001', message = 'invalid_displayed_score';
  end if;
  if normalized_justification is null or normalized_justification = '' then
    raise exception using errcode = 'P0001', message = 'justification_required';
  end if;
  if char_length(normalized_justification) > 4000 then
    raise exception using errcode = 'P0001', message = 'justification_too_long';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(target_event::text || ':' || target_category::text, 0)
  );

  select event.status
  into event_state
  from public.events as event
  where event.id = target_event
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'event_not_found';
  end if;
  if event_state = 'archived' then
    raise exception using errcode = 'P0001', message = 'event_not_available';
  end if;
  
  if not private.current_event_professor(target_event, caller_id) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;
  if exists (
    select 1
    from public.published_results as publication
    where publication.event_id = target_event
      and publication.category = target_category
  ) then
    raise exception using errcode = 'P0001', message = 'category_already_published';
  end if;

  select count(*)::integer
  into team_count
  from public.teams as team
  where team.event_id = target_event
    and team.category = target_category
    and team.status = 'approved';

  if exists (
    select 1
    from public.evaluation_progress as progress
    where progress.event_id = target_event
      and progress.category = target_category
      and not progress.complete
  ) or (
    select count(*)
    from public.evaluation_progress as progress
    where progress.event_id = target_event
      and progress.category = target_category
  ) <> coalesce(team_count, 0) then
    raise exception using errcode = 'P0001', message = 'evaluations_incomplete';
  end if;

  select array_agg(ranking.team_id order by ranking.team_id)
  into expected_order
  from public.administrative_ranking as ranking
  where ranking.event_id = target_event
    and ranking.category = target_category
    and ranking.final_score = round(target_score, 2);

  if coalesce(cardinality(expected_order), 0) < 2 then
    raise exception using errcode = 'P0001', message = 'tie_group_not_found';
  end if;
  if target_order is null
    or cardinality(target_order) <> cardinality(expected_order)
    or cardinality(target_order) <> (
      select count(distinct team_id)
      from unnest(target_order) as ordered(team_id)
    )
  then
    raise exception using errcode = 'P0001', message = 'invalid_tie_order';
  end if;

  select array_agg(team_id order by team_id)
  into normalized_order
  from unnest(target_order) as ordered(team_id);

  if normalized_order is distinct from expected_order then
    raise exception using errcode = 'P0001', message = 'invalid_tie_order';
  end if;

  fingerprint := private.tie_fingerprint(
    target_event, target_category, round(target_score, 2)
  );

  select decision.*
  into existing
  from public.tie_decisions as decision
  where decision.event_id = target_event
    and decision.category = target_category
    and decision.displayed_score = round(target_score, 2)
  for share;

  if found then
    if existing.ordered_team_ids = target_order
      and existing.justification = normalized_justification
      and existing.ranking_fingerprint = fingerprint
    then
      return existing;
    end if;
    raise exception using errcode = 'P0001', message = 'tie_already_resolved';
  end if;

  insert into public.tie_decisions (
    event_id,
    category,
    displayed_score,
    ordered_team_ids,
    justification,
    ranking_fingerprint,
    decided_by
  )
  values (
    target_event,
    target_category,
    round(target_score, 2),
    target_order,
    normalized_justification,
    fingerprint,
    caller_id
  )
  returning * into stored;

  insert into public.audit_log (
    event_id, actor_id, action, entity_type, entity_id, payload
  )
  values (
    target_event,
    caller_id,
    'evaluation_tie_resolved',
    'tie_decision',
    stored.id::text,
    jsonb_build_object(
      'category', target_category,
      'displayed_score', stored.displayed_score,
      'ordered_team_ids', stored.ordered_team_ids,
      'justification', stored.justification,
      'ranking_fingerprint', stored.ranking_fingerprint
    )
  );

  return stored;
end;
$function$;
