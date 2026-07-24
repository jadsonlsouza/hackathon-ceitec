-- 1. Replace publish_category_results_impl removing the event_state = 'evaluation' restriction.
--    The professor should be able to publish results regardless of the current event phase,
--    as long as evaluations are complete and ties are resolved.

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

  -- Return existing publication idempotently
  select publication.*
  into existing
  from public.published_results as publication
  where publication.event_id = target_event
    and publication.category = target_category
  for share;
  if found then
    return existing;
  end if;

  -- ⚠ Removed: event_state <> 'evaluation' check — professor can publish at any phase.

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


-- 2. New function: unpublish_category_results
--    Allows the professor to retract a published result (e.g., to correct an error).
--    Deletes the published_results row and, if the event was marked results_published,
--    reverts it to 'evaluation'.

create function public.unpublish_category_results(
  event_id   uuid,
  category   public.team_category
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id  uuid := (select auth.uid());
  event_state public.event_status;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  select ev.status
  into event_state
  from public.events as ev
  where ev.id = $1
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'event_not_found';
  end if;
  if event_state = 'archived' then
    raise exception using errcode = 'P0001', message = 'event_not_available';
  end if;
  if not private.current_event_professor($1, caller_id) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  delete from public.published_results as pub
  where pub.event_id = $1
    and pub.category = $2;

  -- If we just unpublished and event was fully published, revert status
  if event_state = 'results_published' then
    update public.events as ev
    set status = 'evaluation'
    where ev.id = $1;
  end if;

  insert into public.audit_log (
    event_id, actor_id, action, entity_type, entity_id, payload
  )
  values (
    $1,
    caller_id,
    'category_results_unpublished',
    'published_results',
    $2::text,
    jsonb_build_object('category', $2)
  );
end;
$$;

grant execute on function public.unpublish_category_results(uuid, public.team_category)
  to authenticated;

comment on function public.unpublish_category_results(uuid, public.team_category) is
  'Allows the event professor to retract a published category result.';
