create or replace function private.protect_evaluation_configuration()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target_event uuid;
  target_category public.team_category;
  event_state public.event_status;
begin
  if tg_op = 'INSERT' and (
    pg_trigger_depth() > 1
    or (
      (select auth.uid()) is null
      and session_user = 'postgres'
    )
  )
  then
    return new;
  end if;

  if tg_table_name = 'evaluation_criteria' then
    target_event := case when tg_op = 'DELETE' then old.event_id else new.event_id end;
    if tg_op = 'UPDATE' and new.event_id is distinct from old.event_id then
      raise exception using errcode = 'P0001', message = 'cross_event_move_forbidden';
    end if;
  elsif tg_table_name = 'criterion_weights' then
    target_event := case when tg_op = 'DELETE' then old.event_id else new.event_id end;
    target_category := case
      when tg_op = 'DELETE' then old.category
      else new.category
    end;
    if tg_op = 'UPDATE' and (
      new.event_id is distinct from old.event_id
      or new.criterion_id is distinct from old.criterion_id
      or new.category is distinct from old.category
    ) then
      raise exception using errcode = 'P0001', message = 'weight_scope_immutable';
    end if;
  else
    target_event := case when tg_op = 'DELETE' then old.event_id else new.event_id end;
    target_category := case
      when tg_op = 'DELETE' then old.category
      else new.category
    end;
    if tg_op = 'UPDATE' and (
      new.event_id is distinct from old.event_id
      or new.evaluator_id is distinct from old.evaluator_id
      or new.category is distinct from old.category
    ) then
      raise exception using
        errcode = 'P0001',
        message = 'assignment_scope_immutable';
    end if;
  end if;

  select event.status
  into event_state
  from public.events as event
  where event.id = target_event
  for update;

  if not found or event_state = 'archived' then
    raise exception using errcode = 'P0001', message = 'event_not_available';
  end if;

  if caller_id is null or not exists (
    select 1
    from public.events as event
    where event.id = target_event
      and event.professor_id = caller_id
  ) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  if tg_table_name = 'evaluation_criteria' then
    if exists (
      select 1
      from public.evaluation_freezes as frozen_config
      where frozen_config.event_id = target_event
    ) then
      raise exception using
        errcode = 'P0001',
        message = 'evaluation_config_frozen';
    end if;
  elsif exists (
    select 1
    from public.evaluation_freezes as frozen_config
    where frozen_config.event_id = target_event
      and frozen_config.category = target_category
  ) then
    if not (tg_table_name = 'evaluator_assignments' and tg_op = 'DELETE') then
      raise exception using
        errcode = 'P0001',
        message = 'evaluation_config_frozen';
    end if;
  end if;

  if tg_table_name = 'evaluator_assignments' and tg_op <> 'DELETE' then
    if not exists (
      select 1
      from public.event_roles as role_assignment
      where role_assignment.event_id = target_event
        and role_assignment.user_id = new.evaluator_id
        and role_assignment.role = 'evaluator'
    ) then
      raise exception using
        errcode = 'P0001',
        message = 'evaluator_role_required';
    end if;
    new.assigned_by := caller_id;
    if tg_op = 'UPDATE' then
      new.assigned_at := old.assigned_at;
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create or replace function private.sync_evaluator_snapshot_on_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.evaluation_freezes
  set evaluator_snapshot = coalesce(
    (
      select jsonb_agg(elem)
      from jsonb_array_elements(evaluator_snapshot) as elem
      where (elem->>'evaluator_id')::uuid <> old.evaluator_id
    ),
    '[]'::jsonb
  )
  where event_id = old.event_id
    and category = old.category;

  return old;
end;
$$;

revoke all on function private.sync_evaluator_snapshot_on_delete()
from public, anon, authenticated, service_role;

create trigger sync_evaluator_snapshot
after delete on public.evaluator_assignments
for each row execute function private.sync_evaluator_snapshot_on_delete();
