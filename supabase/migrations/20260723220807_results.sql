create view public.evaluation_progress
with (security_invoker = true)
as
with frozen_teams as (
  select
    frozen_config.event_id,
    frozen_config.category,
    (team ->> 'team_id')::uuid as team_id,
    team ->> 'name' as team_name,
    frozen_config.evaluator_snapshot
  from public.evaluation_freezes as frozen_config
  cross join lateral jsonb_array_elements(
    frozen_config.team_snapshot
  ) as team
),
frozen_evaluators as (
  select
    team.event_id,
    team.category,
    team.team_id,
    team.team_name,
    (evaluator ->> 'evaluator_id')::uuid as evaluator_id,
    evaluator ->> 'display_name' as evaluator_name
  from frozen_teams as team
  cross join lateral jsonb_array_elements(
    team.evaluator_snapshot
  ) as evaluator
)
select
  frozen.event_id,
  frozen.category,
  frozen.team_id,
  frozen.team_name,
  count(*)::integer as required_evaluator_count,
  count(evaluation.id)::integer as completed_evaluator_count,
  coalesce(
    jsonb_agg(
      jsonb_build_object(
        'evaluator_id', frozen.evaluator_id,
        'display_name', frozen.evaluator_name
      )
      order by frozen.evaluator_name, frozen.evaluator_id
    ) filter (where evaluation.id is null),
    '[]'::jsonb
  ) as missing_evaluators,
  count(evaluation.id) = count(*) as complete
from frozen_evaluators as frozen
left join public.evaluations as evaluation
  on evaluation.event_id = frozen.event_id
  and evaluation.category = frozen.category
  and evaluation.team_id = frozen.team_id
  and evaluation.evaluator_id = frozen.evaluator_id
  and evaluation.submitted_at is not null
group by
  frozen.event_id,
  frozen.category,
  frozen.team_id,
  frozen.team_name;

create view public.administrative_ranking
with (security_invoker = true)
as
with frozen_teams as (
  select
    frozen_config.event_id,
    frozen_config.category,
    (team ->> 'team_id')::uuid as team_id,
    team ->> 'name' as team_name
  from public.evaluation_freezes as frozen_config
  cross join lateral jsonb_array_elements(
    frozen_config.team_snapshot
  ) as team
),
frozen_evaluators as (
  select
    frozen_config.event_id,
    frozen_config.category,
    (evaluator ->> 'evaluator_id')::uuid as evaluator_id
  from public.evaluation_freezes as frozen_config
  cross join lateral jsonb_array_elements(
    frozen_config.evaluator_snapshot
  ) as evaluator
),
frozen_criteria as (
  select
    frozen_config.event_id,
    frozen_config.category,
    (criterion ->> 'criterion_id')::uuid as criterion_id,
    (criterion ->> 'weight')::numeric as weight
  from public.evaluation_freezes as frozen_config
  cross join lateral jsonb_array_elements(
    frozen_config.criteria_snapshot
  ) as criterion
),
evaluator_scores as (
  select
    evaluation.event_id,
    evaluation.category,
    evaluation.team_id,
    evaluation.evaluator_id,
    sum(score.score::numeric * criterion.weight)
      / nullif(sum(criterion.weight), 0::numeric)
      as evaluator_weighted_score
  from public.evaluations as evaluation
  join frozen_teams as team
    on team.event_id = evaluation.event_id
    and team.category = evaluation.category
    and team.team_id = evaluation.team_id
  join frozen_evaluators as evaluator
    on evaluator.event_id = evaluation.event_id
    and evaluator.category = evaluation.category
    and evaluator.evaluator_id = evaluation.evaluator_id
  join public.evaluation_scores as score
    on score.evaluation_id = evaluation.id
    and score.event_id = evaluation.event_id
  join frozen_criteria as criterion
    on criterion.event_id = score.event_id
    and criterion.category = evaluation.category
    and criterion.criterion_id = score.criterion_id
  where evaluation.submitted_at is not null
  group by
    evaluation.event_id,
    evaluation.category,
    evaluation.team_id,
    evaluation.evaluator_id
  having
    count(*) = (
      select count(*)
      from frozen_criteria as expected
      where expected.event_id = evaluation.event_id
        and expected.category = evaluation.category
    )
    and sum(criterion.weight) > 0
),
team_scores as (
  select
    team.event_id,
    team.category,
    team.team_id,
    team.team_name,
    avg(evaluator.evaluator_weighted_score)::numeric as exact_final_score
  from frozen_teams as team
  join public.evaluation_progress as progress
    on progress.event_id = team.event_id
    and progress.category = team.category
    and progress.team_id = team.team_id
    and progress.complete
  join evaluator_scores as evaluator
    on evaluator.event_id = team.event_id
    and evaluator.category = team.category
    and evaluator.team_id = team.team_id
  group by
    team.event_id,
    team.category,
    team.team_id,
    team.team_name
  having count(*) = (
    select count(*)
    from frozen_evaluators as expected
    where expected.event_id = team.event_id
      and expected.category = team.category
  )
),
displayed as (
  select
    score.*,
    round(score.exact_final_score, 2) as final_score
  from team_scores as score
)
select
  displayed.event_id,
  displayed.category,
  displayed.team_id,
  displayed.team_name,
  displayed.exact_final_score,
  displayed.final_score,
  dense_rank() over (
    partition by displayed.event_id, displayed.category
    order by displayed.final_score desc
  )::integer as score_rank
from displayed;

revoke all on table
  public.evaluation_progress,
  public.administrative_ranking
from public, anon, authenticated, service_role;
grant select on table
  public.evaluation_progress,
  public.administrative_ranking
to authenticated;

create table public.tie_decisions (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id),
  category public.team_category not null,
  displayed_score numeric(4, 2) not null,
  ordered_team_ids uuid[] not null,
  justification text not null,
  ranking_fingerprint text not null,
  decided_by uuid not null references public.profiles(id),
  decided_at timestamptz not null default now(),
  constraint tie_decisions_event_category_score_key unique (
    event_id, category, displayed_score
  ),
  constraint tie_decisions_score_finite check (
    displayed_score <> 'NaN'::numeric
    and displayed_score <> 'Infinity'::numeric
    and displayed_score <> '-Infinity'::numeric
  ),
  constraint tie_decisions_order_nonempty check (
    cardinality(ordered_team_ids) >= 2
  ),
  constraint tie_decisions_justification_normalized check (
    justification = btrim(justification)
    and justification <> ''
    and char_length(justification) <= 4000
  ),
  constraint tie_decisions_fingerprint_nonblank check (
    ranking_fingerprint = btrim(ranking_fingerprint)
    and ranking_fingerprint <> ''
  )
);

create index tie_decisions_decided_by_idx
  on public.tie_decisions (decided_by);

create table public.published_results (
  event_id uuid not null references public.events(id),
  category public.team_category not null,
  ranking jsonb not null,
  published_by uuid not null references public.profiles(id),
  published_at timestamptz not null default now(),
  primary key (event_id, category),
  constraint published_results_ranking_array check (
    jsonb_typeof(ranking) = 'array'
    and jsonb_array_length(ranking) > 0
  )
);

create index published_results_published_at_idx
  on public.published_results (published_at desc);
create index published_results_published_by_idx
  on public.published_results (published_by);

alter table public.tie_decisions enable row level security;
alter table public.published_results enable row level security;

create policy "Professor reads tie decisions"
on public.tie_decisions for select to authenticated
using ((select public.is_event_professor(event_id)));

create policy "published snapshots are public"
on public.published_results for select to anon, authenticated
using (true);

revoke all on table
  public.tie_decisions,
  public.published_results
from public, anon, authenticated, service_role;
grant select on table public.tie_decisions to authenticated;
grant select on table public.published_results to anon, authenticated;

create function private.protect_result_immutability()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  raise exception using
    errcode = 'P0001',
    message = case
      when tg_table_name = 'published_results'
        then 'published_result_immutable'
      else 'tie_decision_immutable'
    end;
end;
$$;

revoke all on function private.protect_result_immutability()
from public, anon, authenticated, service_role;

create trigger protect_tie_decision
before update or delete on public.tie_decisions
for each row execute function private.protect_result_immutability();

create trigger protect_published_result
before update or delete on public.published_results
for each row execute function private.protect_result_immutability();

create function private.protect_ranked_evaluation()
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

revoke all on function private.protect_ranked_evaluation()
from public, anon, authenticated, service_role;

create trigger protect_ranked_evaluation
before insert or update or delete on public.evaluations
for each row execute function private.protect_ranked_evaluation();

create trigger protect_ranked_evaluation_score
before insert or update or delete on public.evaluation_scores
for each row execute function private.protect_ranked_evaluation();

create function private.current_event_professor(
  target_event uuid,
  caller_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    caller_id is not null
    and exists (
      select 1
      from public.events as event
      join public.event_roles as role_assignment
        on role_assignment.event_id = event.id
        and role_assignment.user_id = caller_id
        and role_assignment.role = 'professor'
      where event.id = target_event
        and event.professor_id = caller_id
    );
$$;

revoke all on function private.current_event_professor(uuid, uuid)
from public, anon, authenticated, service_role;

create function private.tie_fingerprint(
  target_event uuid,
  target_category public.team_category,
  target_score numeric
)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select md5(
    coalesce(
      jsonb_agg(
        jsonb_build_array(
          ranking.team_id,
          ranking.exact_final_score,
          ranking.final_score
        )
        order by ranking.team_id
      )::text,
      '[]'
    )
  )
  from public.administrative_ranking as ranking
  where ranking.event_id = target_event
    and ranking.category = target_category
    and ranking.final_score = round(target_score, 2);
$$;

revoke all on function private.tie_fingerprint(
  uuid, public.team_category, numeric
) from public, anon, authenticated, service_role;

create function private.resolve_tie_impl(
  target_event uuid,
  target_category public.team_category,
  target_score numeric,
  target_order uuid[],
  target_justification text
)
returns public.tie_decisions
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  event_state public.event_status;
  normalized_justification text := btrim(target_justification);
  expected_order uuid[];
  normalized_order uuid[];
  fingerprint text;
  frozen_team_count integer;
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
  if event_state <> 'evaluation' then
    raise exception using errcode = 'P0001', message = 'event_not_in_evaluation';
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

  select jsonb_array_length(frozen_config.team_snapshot)
  into frozen_team_count
  from public.evaluation_freezes as frozen_config
  where frozen_config.event_id = target_event
    and frozen_config.category = target_category
  for share;

  if not found then
    raise exception using errcode = 'P0001', message = 'evaluation_not_frozen';
  end if;
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
  ) <> frozen_team_count then
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
$$;

create function private.publish_category_results_impl(
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
  frozen_team_count integer;
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

  select jsonb_array_length(frozen_config.team_snapshot)
  into frozen_team_count
  from public.evaluation_freezes as frozen_config
  where frozen_config.event_id = target_event
    and frozen_config.category = target_category
  for share;

  if not found then
    raise exception using errcode = 'P0001', message = 'evaluation_not_frozen';
  end if;
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
  ) <> frozen_team_count then
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

  if snapshot is null or jsonb_array_length(snapshot) <> frozen_team_count then
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

revoke all on function
  private.resolve_tie_impl(
    uuid, public.team_category, numeric, uuid[], text
  ),
  private.publish_category_results_impl(uuid, public.team_category)
from public, anon, authenticated, service_role;

create view private.result_workflow_dispatch
with (security_invoker = true)
as
select
  null::text as action,
  null::uuid as event_id,
  null::public.team_category as category,
  null::numeric as displayed_score,
  null::uuid[] as ordered_team_ids,
  null::text as justification,
  null::uuid as result_id,
  null::jsonb as result
where false;

revoke all on table private.result_workflow_dispatch
from public, anon, authenticated, service_role;

create function private.dispatch_result_workflow()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  decision public.tie_decisions;
  publication public.published_results;
begin
  if new.action = 'resolve_tie' then
    decision := private.resolve_tie_impl(
      new.event_id,
      new.category,
      new.displayed_score,
      new.ordered_team_ids,
      new.justification
    );
    new.result_id := decision.id;
    new.result := to_jsonb(decision);
  elsif new.action = 'publish_category' then
    publication := private.publish_category_results_impl(
      new.event_id,
      new.category
    );
    new.result_id := publication.event_id;
    new.result := to_jsonb(publication);
  else
    raise exception using errcode = 'P0001', message = 'invalid_result_action';
  end if;
  return new;
end;
$$;

revoke all on function private.dispatch_result_workflow()
from public, anon, authenticated, service_role;

create trigger dispatch_result_workflow
instead of insert on private.result_workflow_dispatch
for each row execute function private.dispatch_result_workflow();

grant insert (
  action,
  event_id,
  category,
  displayed_score,
  ordered_team_ids,
  justification
) on private.result_workflow_dispatch to authenticated;
grant select (result_id, result)
on private.result_workflow_dispatch to authenticated;

create function public.resolve_tie(
  event_id uuid,
  category public.team_category,
  displayed_score numeric,
  ordered_team_ids uuid[],
  justification text
)
returns public.tie_decisions
language plpgsql
security invoker
set search_path = ''
as $$
declare
  result jsonb;
begin
  insert into private.result_workflow_dispatch (
    action,
    event_id,
    category,
    displayed_score,
    ordered_team_ids,
    justification
  )
  values (
    'resolve_tie',
    $1,
    $2,
    $3,
    $4,
    $5
  )
  returning result_workflow_dispatch.result into result;

  return jsonb_populate_record(null::public.tie_decisions, result);
end;
$$;

create function public.publish_category_results(
  event_id uuid,
  category public.team_category
)
returns public.published_results
language plpgsql
security invoker
set search_path = ''
as $$
declare
  result jsonb;
begin
  insert into private.result_workflow_dispatch (
    action,
    event_id,
    category
  )
  values ('publish_category', $1, $2)
  returning result_workflow_dispatch.result into result;

  return jsonb_populate_record(null::public.published_results, result);
end;
$$;

create function public.get_published_results(event_slug text)
returns table (
  event_name text,
  event_slug text,
  category public.team_category,
  ranking jsonb,
  published_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    event.name,
    event.slug,
    publication.category,
    publication.ranking,
    publication.published_at
  from public.events as event
  join public.published_results as publication
    on publication.event_id = event.id
  where event.slug = btrim(get_published_results.event_slug)
    and event.status = 'results_published'
  order by publication.category;
$$;

revoke all on function
  public.resolve_tie(
    uuid, public.team_category, numeric, uuid[], text
  ),
  public.publish_category_results(uuid, public.team_category),
  public.get_published_results(text)
from public, anon, authenticated, service_role;

grant execute on function
  public.resolve_tie(
    uuid, public.team_category, numeric, uuid[], text
  ),
  public.publish_category_results(uuid, public.team_category)
to authenticated;
grant execute on function public.get_published_results(text)
to anon, authenticated;

comment on view public.evaluation_progress is
  'Professor-only completeness from frozen teams and evaluators.';
comment on view public.administrative_ranking is
  'Professor-only numeric ranking calculated exclusively from frozen snapshots.';
comment on function public.resolve_tie(
  uuid, public.team_category, numeric, uuid[], text
) is
  'Records an audited manual order for one stable displayed-score tie.';
comment on function public.publish_category_results(
  uuid, public.team_category
) is
  'Publishes one immutable category ranking after completeness and tie checks.';
comment on function public.get_published_results(text) is
  'Returns only immutable published snapshots for an exact event slug.';
