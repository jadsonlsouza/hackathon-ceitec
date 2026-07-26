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

  if exists (
    select 1
    from (
      select ranking.final_score
      from public.administrative_ranking as ranking
      where ranking.event_id = target_event
        and ranking.category = target_category
        and ranking.final_score > 0
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
      and decision.displayed_score > 0
      and (
        (
          select count(*)
          from public.administrative_ranking as ranking
          where ranking.event_id = decision.event_id
            and ranking.category = decision.category
            and ranking.final_score = decision.displayed_score
        ) < 2
        or (
          decision.ranking_fingerprint is distinct from private.tie_fingerprint(
            target_event, target_category, decision.displayed_score
          )
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
