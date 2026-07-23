revoke insert, update, delete on public.presentation_slots
from authenticated;

drop policy "profile self and authorized applicant read"
on public.profiles;

create policy "profile self and authorized event read"
on public.profiles
for select
to authenticated
using (
  id = (select auth.uid())
  or (select public.is_global_admin())
  or exists (
    select 1
    from public.role_requests as request
    where request.user_id = profiles.id
      and request.status = 'pending'
      and request.requested_role in ('monitor', 'evaluator')
      and (select public.is_event_professor(request.event_id))
  )
  or exists (
    select 1
    from public.event_roles as role_assignment
    where role_assignment.user_id = profiles.id
      and role_assignment.role = 'evaluator'
      and (select public.is_event_professor(role_assignment.event_id))
  )
);

create or replace function private.protect_presentation_slot()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target_event uuid := case
    when tg_op = 'DELETE' then old.event_id else new.event_id
  end;
  event_state public.event_status;
  frozen_teams jsonb;
begin
  select event.status
  into event_state
  from public.events as event
  where event.id = target_event
  for update;

  if not found or event_state = 'archived' then
    raise exception using errcode = 'P0001', message = 'event_not_available';
  end if;
  if caller_id is null or not exists (
    select 1 from public.events as event
    where event.id = target_event and event.professor_id = caller_id
  ) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  if tg_op <> 'DELETE' then
    select frozen_config.team_snapshot
    into frozen_teams
    from public.evaluation_freezes as frozen_config
    where frozen_config.event_id = new.event_id
      and frozen_config.category = new.category;

    if frozen_teams is not null then
      if not exists (
        select 1
        from jsonb_array_elements(frozen_teams) as frozen_team
        where frozen_team ->> 'team_id' = new.team_id::text
      ) then
        raise exception using
          errcode = 'P0001',
          message = 'frozen_team_required';
      end if;
    elsif not exists (
      select 1 from public.teams as team
      where team.id = new.team_id
        and team.event_id = new.event_id
        and team.category = new.category
        and team.status = 'approved'
    ) then
      raise exception using
        errcode = 'P0001',
        message = 'approved_team_category_required';
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create function private.shuffle_presentations_impl(
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

  if event_state <> 'evaluation' then
    raise exception using
      errcode = 'P0001',
      message = 'event_not_in_evaluation';
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

revoke all on function private.shuffle_presentations_impl(
  uuid,
  public.team_category
) from public, anon, authenticated, service_role;

create view private.presentation_shuffle_dispatch
with (security_invoker = true)
as
select
  null::uuid as event_id,
  null::public.team_category as category,
  null::integer as shuffled_count
where false;

revoke all on table private.presentation_shuffle_dispatch
from public, anon, authenticated, service_role;

create function private.dispatch_presentation_shuffle()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.shuffled_count := private.shuffle_presentations_impl(
    new.event_id,
    new.category
  );
  return new;
end;
$$;

revoke all on function private.dispatch_presentation_shuffle()
from public, anon, authenticated, service_role;

create trigger dispatch_presentation_shuffle
instead of insert on private.presentation_shuffle_dispatch
for each row execute function private.dispatch_presentation_shuffle();

grant insert (event_id, category)
on private.presentation_shuffle_dispatch to authenticated;

grant select (shuffled_count)
on private.presentation_shuffle_dispatch to authenticated;

create function public.shuffle_presentations(
  event_id uuid,
  category public.team_category
)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  result integer;
begin
  insert into private.presentation_shuffle_dispatch (
    event_id,
    category
  )
  values ($1, $2)
  returning shuffled_count into result;

  return result;
end;
$$;

revoke all on function public.shuffle_presentations(
  uuid,
  public.team_category
) from public, anon, authenticated, service_role;

grant execute on function public.shuffle_presentations(
  uuid,
  public.team_category
) to authenticated;

comment on function private.shuffle_presentations_impl(
  uuid,
  public.team_category
) is
  'Event-locked random presentation order for one evaluation category.';

comment on function public.shuffle_presentations(
  uuid,
  public.team_category
) is
  'Shuffles approved presentations before category scoring starts.';
