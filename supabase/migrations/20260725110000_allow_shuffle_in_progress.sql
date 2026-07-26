create or replace function private.shuffle_presentations_impl(
  target_event uuid,
  target_category public.team_category
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  event_state public.event_status;
  approved_team_count integer;
  eligible_team_ids uuid[];
begin
  if caller_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'authentication_required';
  end if;

  if target_event is null or target_category is null then
    raise exception using
      errcode = 'P0001',
      message = 'presentation_scope_required';
  end if;

  select event.status
  into event_state
  from public.events as event
  where event.id = target_event
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'event_not_found';
  end if;

  if event_state = 'archived' then
    raise exception using
      errcode = 'P0001',
      message = 'event_not_available';
  end if;

  if event_state not in ('in_progress', 'evaluation') then
    raise exception using
      errcode = 'P0001',
      message = 'event_not_ready_for_shuffle';
  end if;

  if not exists (
    select 1
    from public.events as event
    where event.id = target_event
      and event.professor_id = caller_id
  ) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  if exists (
    select 1
    from public.evaluations as evaluation
    where evaluation.event_id = target_event
      and evaluation.category = target_category
      and evaluation.submitted_at is not null
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'evaluation_already_started';
  end if;

  select array_agg((frozen_team ->> 'team_id')::uuid)
  into eligible_team_ids
  from public.evaluation_freezes as frozen_config
  cross join lateral jsonb_array_elements(
    frozen_config.team_snapshot
  ) as frozen_team
  where frozen_config.event_id = target_event
    and frozen_config.category = target_category;

  if eligible_team_ids is null then
    select array_agg(team.id order by team.id)
    into eligible_team_ids
    from public.teams as team
    where team.event_id = target_event
      and team.category = target_category
      and team.status = 'approved';
  end if;

  approved_team_count := coalesce(cardinality(eligible_team_ids), 0);

  if approved_team_count = 0 then
    raise exception using
      errcode = 'P0001',
      message = 'approved_team_required';
  end if;

  delete from public.presentation_slots as slot
  where slot.event_id = target_event
    and slot.category = target_category;

  insert into public.presentation_slots (
    event_id,
    category,
    team_id,
    position
  )
  select
    target_event,
    target_category,
    shuffled.team_id,
    row_number() over (
      order by shuffled.random_key, shuffled.team_id
    )::integer
  from (
    select
      eligible_team.team_id,
      gen_random_uuid() as random_key
    from unnest(eligible_team_ids) as eligible_team(team_id)
  ) as shuffled;

  insert into public.audit_log (
    event_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    payload
  )
  values (
    target_event,
    caller_id,
    'presentation_order_shuffled',
    'presentation_order',
    target_category::text,
    jsonb_build_object(
      'category',
      target_category,
      'team_count',
      approved_team_count
    )
  );

  return approved_team_count;
end;
$$;
