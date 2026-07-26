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
         round(score.exact_final_score, 2) AS final_score,
         rank() OVER (PARTITION BY score.event_id, score.category ORDER BY score.exact_final_score DESC, score.team_name) AS score_rank
  FROM team_scores score
)
SELECT event_id,
       category,
       team_id,
       team_name,
       exact_final_score,
       final_score,
       score_rank
FROM displayed;
