-- 1. Replace evaluation_progress view
drop view if exists public.evaluation_progress cascade;
create or replace view public.evaluation_progress as
WITH target_teams AS (
  SELECT t.event_id, t.category, t.id as team_id, t.name as team_name
  FROM public.teams t
  WHERE t.status = 'approved'
), target_evaluators AS (
  SELECT ea.event_id, ea.category, ea.evaluator_id, p.display_name as evaluator_name
  FROM public.evaluator_assignments ea
  JOIN public.event_roles er ON er.event_id = ea.event_id AND er.user_id = ea.evaluator_id AND er.role = 'evaluator'
  JOIN public.profiles p ON p.id = ea.evaluator_id
), team_evaluators AS (
  SELECT t.event_id, t.category, t.team_id, t.team_name, e.evaluator_id, e.evaluator_name
  FROM target_teams t
  JOIN target_evaluators e ON e.event_id = t.event_id AND e.category = t.category
)
SELECT te.event_id,
       te.category,
       te.team_id,
       te.team_name,
       count(*)::integer AS required_evaluator_count,
       count(ev.id)::integer AS completed_evaluator_count,
       COALESCE(jsonb_agg(jsonb_build_object('evaluator_id', te.evaluator_id, 'display_name', te.evaluator_name) ORDER BY te.evaluator_name, te.evaluator_id) FILTER (WHERE ev.id IS NULL), '[]'::jsonb) AS missing_evaluators,
       count(ev.id) = count(*) AS complete
FROM team_evaluators te
LEFT JOIN public.evaluations ev ON ev.event_id = te.event_id AND ev.category = te.category AND ev.team_id = te.team_id AND ev.evaluator_id = te.evaluator_id AND ev.submitted_at IS NOT NULL
GROUP BY te.event_id, te.category, te.team_id, te.team_name;


-- 2. Replace administrative_ranking view
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
         avg(es.evaluator_weighted_score) AS exact_final_score
  FROM target_teams t
  JOIN public.evaluation_progress progress ON progress.event_id = t.event_id AND progress.category = t.category AND progress.team_id = t.team_id AND progress.complete
  JOIN evaluator_scores es ON es.event_id = t.event_id AND es.category = t.category AND es.team_id = t.team_id
  GROUP BY t.event_id, t.category, t.team_id, t.team_name
  HAVING count(*) = (SELECT count(*) FROM target_evaluators expected WHERE expected.event_id = t.event_id AND expected.category = t.category)
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
       final_score,
       dense_rank() OVER (PARTITION BY event_id, category ORDER BY final_score DESC)::integer AS score_rank
FROM displayed;


-- 3. Replace public_ranking view
create or replace view public.public_ranking as
 WITH valid_publications AS (
         SELECT publication.event_id,
            publication.category,
            publication.ranking
           FROM public.published_results publication
        ), unnested AS (
         SELECT publication.event_id,
            publication.category,
            (ranking.value ->> 'position'::text)::integer AS position,
            (ranking.value ->> 'team_id'::text)::uuid AS team_id,
            ranking.value ->> 'team_name'::text AS team_name,
            (ranking.value ->> 'score'::text)::numeric AS final_score
           FROM valid_publications publication
             CROSS JOIN LATERAL jsonb_array_elements(publication.ranking) ranking(value)
        )
 SELECT event_id,
    category,
    position,
    team_id,
    team_name,
    final_score
   FROM unnested;


-- 4. Recreate publish_category_results_impl
create or replace function private.publish_category_results_impl(
  target_event uuid,
  target_category public.team_category
)
returns public.published_results
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  event_state public.event_status;
  team_count integer;
  snapshot jsonb;
  stored public.published_results;
  existing public.published_results;
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

  if event_state <> 'evaluation' then
    raise exception using errcode = 'P0001', message = 'event_not_in_evaluation';
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
$$;
