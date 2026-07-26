-- 1. Replace administrative_ranking view to include teams with incomplete evaluations and assign 0 score
drop view if exists public.administrative_ranking cascade;
create or replace view public.administrative_ranking as
WITH target_teams AS (
  SELECT t.event_id, t.category, t.id as team_id, t.name as team_name
  FROM public.teams t
  WHERE t.status = 'approved'
), target_evaluators AS (
  SELECT ea.event_id, ea.category, ea.evaluator_id
  FROM public.evaluator_assignments ea
  JOIN public.event_roles er ON er.event_id = ea.event_id AND er.user_id = ea.evaluator_id AND er.role = 'evaluator'
), target_criteria AS (
  SELECT cw.event_id, cw.category, cw.criterion_id, cw.weight
  FROM public.criterion_weights cw
  JOIN public.evaluation_criteria ec ON ec.id = cw.criterion_id AND ec.active = true
), evaluator_scores AS (
  SELECT ev.event_id,
         ev.category,
         ev.team_id,
         ev.evaluator_id,
         sum(score.score::numeric * c.weight) / NULLIF(sum(c.weight), 0::numeric) AS evaluator_weighted_score
  FROM public.evaluations ev
  JOIN target_teams t ON t.event_id = ev.event_id AND t.category = ev.category AND t.team_id = ev.team_id
  JOIN target_evaluators e ON e.event_id = ev.event_id AND e.category = ev.category AND e.evaluator_id = ev.evaluator_id
  JOIN public.evaluation_scores score ON score.evaluation_id = ev.id AND score.event_id = ev.event_id
  JOIN target_criteria c ON c.event_id = score.event_id AND c.category = ev.category AND c.criterion_id = score.criterion_id
  WHERE ev.submitted_at IS NOT NULL
  GROUP BY ev.event_id, ev.category, ev.team_id, ev.evaluator_id
  HAVING count(*) = (SELECT count(*) FROM target_criteria expected WHERE expected.event_id = ev.event_id AND expected.category = ev.category)
     AND sum(c.weight) > 0::numeric
), team_scores AS (
  SELECT t.event_id,
         t.category,
         t.team_id,
         t.team_name,
         CASE 
           WHEN count(es.evaluator_id) = (SELECT count(*) FROM target_evaluators expected WHERE expected.event_id = t.event_id AND expected.category = t.category)
           THEN COALESCE(avg(es.evaluator_weighted_score), 0)
           ELSE 0
         END AS exact_final_score
  FROM target_teams t
  LEFT JOIN evaluator_scores es ON es.event_id = t.event_id AND es.category = t.category AND es.team_id = t.team_id
  GROUP BY t.event_id, t.category, t.team_id, t.team_name
), displayed AS (
  SELECT score.event_id,
         score.category,
         score.team_id,
         score.team_name,
         score.exact_final_score,
         round(score.exact_final_score, 2) AS final_score
  FROM team_scores score
)
SELECT event_id,
       category,
       team_id,
       team_name,
       exact_final_score,
       final_score
FROM displayed;

-- 2. Update private.publish_category_results_impl to remove evaluations_incomplete check
CREATE OR REPLACE FUNCTION private.publish_category_results_impl(target_event uuid, target_category team_category)
 RETURNS published_results
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  caller_id  uuid := (select auth.uid());
  event_state public.event_status;
  team_count  integer;
  snapshot    jsonb;
  stored      public.published_results;
  existing    public.published_results;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;
  if target_event is null or target_category is null then
    raise exception using errcode = 'P0001', message = 'publication_scope_required';
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

  select publication.*
  into existing
  from public.published_results as publication
  where publication.event_id = target_event
    and publication.category = target_category
  for share;
  if found then
    return existing;
  end if;

  select count(*)::integer
  into team_count
  from public.teams as team
  where team.event_id = target_event
    and team.category = target_category
    and team.status = 'approved';

  -- ⚠ Removed: evaluations_incomplete check

  if exists (
    select 1
    from (
      select ranking.final_score
      from public.administrative_ranking as ranking
      where ranking.event_id = target_event
        and ranking.category = target_category
      group by ranking.final_score
      having count(*) > 1
    ) as tie
    left join public.tie_decisions as decision
      on decision.event_id = target_event
      and decision.category = target_category
      and decision.displayed_score = tie.final_score
    where decision.id is null
  ) then
    raise exception using errcode = 'P0001', message = 'unresolved_ties';
  end if;

  if exists (
    select 1
    from public.tie_decisions as decision
    where decision.event_id = target_event
      and decision.category = target_category
      and (
        select count(*)
        from public.administrative_ranking as ranking
        where ranking.event_id = decision.event_id
          and ranking.category = decision.category
          and ranking.final_score = decision.displayed_score
      ) < 2
      or (
        decision.event_id = target_event
        and decision.category = target_category
        and decision.ranking_fingerprint is distinct from private.tie_fingerprint(
          target_event, target_category, decision.displayed_score
        )
      )
  ) then
    raise exception using errcode = 'P0001', message = 'stale_tie_decision';
  end if;

  select jsonb_agg(
    jsonb_build_object(
      'position', ordered.position,
      'team_id', ordered.team_id,
      'team_name', ordered.team_name,
      'category', target_category,
      'score', ordered.final_score
    )
    order by ordered.position
  )
  into snapshot
  from (
    select
      ranking.team_id,
      ranking.team_name,
      ranking.final_score,
      row_number() over (
        order by
          ranking.final_score desc,
          coalesce(
            array_position(decision.ordered_team_ids, ranking.team_id),
            1
          ),
          ranking.team_name,
          ranking.team_id
      )::integer as position
    from public.administrative_ranking as ranking
    left join public.tie_decisions as decision
      on decision.event_id = ranking.event_id
      and decision.category = ranking.category
      and decision.displayed_score = ranking.final_score
    where ranking.event_id = target_event
      and ranking.category = target_category
  ) as ordered;

  if snapshot is null or jsonb_array_length(snapshot) <> coalesce(team_count, 0) then
    raise exception using errcode = 'P0001', message = 'ranking_incomplete';
  end if;

  insert into public.published_results (
    event_id, category, ranking, published_by
  )
  values (target_event, target_category, snapshot, caller_id)
  returning * into stored;

  insert into public.audit_log (
    event_id, actor_id, action, entity_type, entity_id, payload
  )
  values (
    target_event,
    caller_id,
    'category_results_published',
    'published_results',
    target_category::text,
    jsonb_build_object(
      'category', target_category,
      'ranking', snapshot
    )
  );

  if (
    select count(distinct publication.category)
    from public.published_results as publication
    where publication.event_id = target_event
  ) = 2 then
    update public.events as event
    set status = 'results_published'
    where event.id = target_event;

    insert into public.audit_log (
      event_id, actor_id, action, entity_type, entity_id, payload
    )
    values (
      target_event,
      caller_id,
      'event_results_published',
      'event',
      target_event::text,
      jsonb_build_object('status', 'results_published')
    );
  end if;

  return stored;
end;
$function$;

-- 3. Update private.resolve_tie_impl to remove evaluations_incomplete check
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

  -- ⚠ Removed: evaluations_incomplete check

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

-- 4. Create admin_delete_team RPC
CREATE OR REPLACE FUNCTION public.admin_delete_team(p_team_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_event_id uuid;
  caller_id uuid := (select auth.uid());
BEGIN
  IF caller_id IS NULL THEN
    RAISE EXCEPTION using errcode = 'P0001', message = 'authentication_required';
  END IF;

  SELECT event_id INTO v_event_id FROM public.teams WHERE id = p_team_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION using errcode = 'P0001', message = 'team_not_found';
  END IF;

  IF NOT private.current_event_professor(v_event_id, caller_id) 
     AND NOT private.current_global_admin(caller_id) THEN
    RAISE EXCEPTION using errcode = 'P0001', message = 'forbidden';
  END IF;

  -- Delete dependencies first to respect foreign keys
  DELETE FROM public.presentation_slots WHERE team_id = p_team_id;
  DELETE FROM public.evaluation_scores WHERE evaluation_id IN (SELECT id FROM public.evaluations WHERE team_id = p_team_id);
  DELETE FROM public.evaluations WHERE team_id = p_team_id;
  DELETE FROM public.submissions WHERE team_id = p_team_id;
  DELETE FROM public.team_members WHERE team_id = p_team_id;
  DELETE FROM public.workshop_enrollments WHERE team_id = p_team_id;
  
  -- Delete the team
  DELETE FROM public.teams WHERE id = p_team_id;
END;
$function$;
