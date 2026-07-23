revoke select on table
  public.evaluation_progress,
  public.administrative_ranking
from authenticated;

revoke select on table public.published_results
from anon, authenticated;

create function private.assert_current_professor(target_event uuid)
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
    join public.event_roles as role_assignment
      on role_assignment.event_id = event.id
      and role_assignment.user_id = caller_id
      and role_assignment.role = 'professor'
    where event.id = target_event
      and event.professor_id = caller_id
      and event.status <> 'archived'
  ) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;
end;
$$;

revoke all on function private.assert_current_professor(uuid)
from public, anon, authenticated, service_role;

create function public.get_evaluation_progress(target_event uuid)
returns table (
  event_id uuid,
  category public.team_category,
  team_id uuid,
  team_name text,
  required_evaluator_count integer,
  completed_evaluator_count integer,
  missing_evaluators jsonb,
  complete boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.assert_current_professor($1);
  return query
  select
    progress.event_id,
    progress.category,
    progress.team_id,
    progress.team_name,
    progress.required_evaluator_count,
    progress.completed_evaluator_count,
    progress.missing_evaluators,
    progress.complete
  from public.evaluation_progress as progress
  where progress.event_id = $1
  order by progress.category, progress.team_name, progress.team_id;
end;
$$;

create function public.get_administrative_ranking(target_event uuid)
returns table (
  event_id uuid,
  category public.team_category,
  team_id uuid,
  team_name text,
  exact_final_score numeric,
  final_score numeric,
  score_rank integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.assert_current_professor($1);
  return query
  select
    ranking.event_id,
    ranking.category,
    ranking.team_id,
    ranking.team_name,
    ranking.exact_final_score,
    ranking.final_score,
    ranking.score_rank
  from public.administrative_ranking as ranking
  where ranking.event_id = $1
  order by ranking.category, ranking.final_score desc, ranking.team_id;
end;
$$;

create function public.get_administrative_publications(target_event uuid)
returns table (
  category public.team_category,
  published_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.assert_current_professor($1);
  return query
  select publication.category, publication.published_at
  from public.published_results as publication
  where publication.event_id = $1
  order by publication.category;
end;
$$;

revoke all on function
  public.get_evaluation_progress(uuid),
  public.get_administrative_ranking(uuid),
  public.get_administrative_publications(uuid)
from public, anon, authenticated, service_role;

grant execute on function
  public.get_evaluation_progress(uuid),
  public.get_administrative_ranking(uuid),
  public.get_administrative_publications(uuid)
to authenticated;

create or replace function private.protect_ranked_evaluation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_event uuid;
  target_category public.team_category;
begin
  if tg_table_name = 'evaluations' then
    target_event := case when tg_op = 'DELETE' then old.event_id else new.event_id end;
    target_category := case when tg_op = 'DELETE' then old.category else new.category end;
  else
    select evaluation.event_id, evaluation.category
    into target_event, target_category
    from public.evaluations as evaluation
    where evaluation.id = case
      when tg_op = 'DELETE' then old.evaluation_id
      else new.evaluation_id
    end;
  end if;

  if exists (
    select 1
    from public.published_results as publication
    where publication.event_id = target_event
      and publication.category = target_category
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'category_results_published';
  end if;

  if exists (
    select 1
    from public.tie_decisions as decision
    where decision.event_id = target_event
      and decision.category = target_category
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'ranking_locked_after_tie_decision';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

comment on function public.get_evaluation_progress(uuid) is
  'Professor-only event-scoped frozen evaluation progress.';
comment on function public.get_administrative_ranking(uuid) is
  'Professor-only event-scoped private ranking.';
comment on function public.get_administrative_publications(uuid) is
  'Professor-only event-scoped category publication state.';
