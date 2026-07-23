create table public.evaluation_criteria (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id),
  name text not null,
  description text not null default '',
  position integer not null,
  active boolean not null default true,
  constraint evaluation_criteria_id_event_key unique (id, event_id),
  constraint evaluation_criteria_event_name_key unique (event_id, name),
  constraint evaluation_criteria_event_position_key unique (
    event_id, position
  ),
  constraint evaluation_criteria_name_normalized check (
    name = btrim(name) and name <> ''
  ),
  constraint evaluation_criteria_description_normalized check (
    description = btrim(description)
  ),
  constraint evaluation_criteria_position_positive check (position > 0)
);

create index evaluation_criteria_event_active_idx
  on public.evaluation_criteria (event_id, position)
  where active;

create table public.criterion_weights (
  event_id uuid not null references public.events(id),
  criterion_id uuid not null,
  category public.team_category not null,
  weight numeric(8, 2) not null default 1,
  primary key (criterion_id, category),
  constraint criterion_weights_criterion_event_fkey
    foreign key (criterion_id, event_id)
    references public.evaluation_criteria(id, event_id)
    on delete cascade,
  constraint criterion_weights_nonnegative check (weight >= 0)
);

create index criterion_weights_event_category_idx
  on public.criterion_weights (event_id, category);

create table public.evaluator_assignments (
  event_id uuid not null references public.events(id),
  evaluator_id uuid not null references public.profiles(id),
  category public.team_category not null,
  assigned_by uuid not null default auth.uid()
    references public.profiles(id),
  assigned_at timestamptz not null default now(),
  primary key (event_id, evaluator_id, category)
);

create index evaluator_assignments_evaluator_idx
  on public.evaluator_assignments (evaluator_id, event_id);
create index evaluator_assignments_assigned_by_idx
  on public.evaluator_assignments (assigned_by);

create table public.presentation_slots (
  event_id uuid not null references public.events(id),
  category public.team_category not null,
  team_id uuid not null,
  position integer not null,
  presented_at timestamptz,
  primary key (event_id, category, team_id),
  constraint presentation_slots_team_event_fkey
    foreign key (team_id, event_id)
    references public.teams(id, event_id),
  constraint presentation_slots_event_category_position_key unique (
    event_id, category, position
  ),
  constraint presentation_slots_position_positive check (position > 0)
);

create index presentation_slots_team_idx
  on public.presentation_slots (team_id);

create table public.evaluations (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id),
  category public.team_category not null,
  team_id uuid not null,
  evaluator_id uuid not null references public.profiles(id),
  comment text,
  submitted_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint evaluations_team_event_fkey
    foreign key (team_id, event_id)
    references public.teams(id, event_id),
  constraint evaluations_assignment_fkey
    foreign key (event_id, evaluator_id, category)
    references public.evaluator_assignments(
      event_id, evaluator_id, category
    ),
  constraint evaluations_event_team_evaluator_key unique (
    event_id, team_id, evaluator_id
  ),
  constraint evaluations_comment_normalized check (
    comment is null
    or (
      comment = btrim(comment)
      and comment <> ''
      and char_length(comment) <= 4000
    )
  )
);

create index evaluations_team_idx on public.evaluations (team_id);
create index evaluations_evaluator_idx
  on public.evaluations (evaluator_id, event_id);
create index evaluations_progress_idx
  on public.evaluations (event_id, category, team_id, submitted_at);

create table public.evaluation_scores (
  evaluation_id uuid not null references public.evaluations(id)
    on delete cascade,
  criterion_id uuid not null references public.evaluation_criteria(id),
  score smallint not null,
  primary key (evaluation_id, criterion_id),
  constraint evaluation_scores_range check (score between 1 and 5)
);

create index evaluation_scores_criterion_idx
  on public.evaluation_scores (criterion_id);

create table public.evaluation_freezes (
  event_id uuid not null references public.events(id),
  category public.team_category not null,
  frozen_at timestamptz not null default now(),
  frozen_by uuid not null references public.profiles(id),
  criteria_snapshot jsonb not null,
  evaluator_snapshot jsonb not null,
  team_snapshot jsonb not null,
  primary key (event_id, category),
  constraint evaluation_freezes_criteria_array check (
    jsonb_typeof(criteria_snapshot) = 'array'
    and jsonb_array_length(criteria_snapshot) > 0
  ),
  constraint evaluation_freezes_evaluator_array check (
    jsonb_typeof(evaluator_snapshot) = 'array'
    and jsonb_array_length(evaluator_snapshot) > 0
  ),
  constraint evaluation_freezes_team_array check (
    jsonb_typeof(team_snapshot) = 'array'
    and jsonb_array_length(team_snapshot) > 0
  )
);

create index evaluation_freezes_frozen_by_idx
  on public.evaluation_freezes (frozen_by);

create function private.seed_event_evaluation_defaults(target_event uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if target_event is null or not exists (
    select 1 from public.events as event where event.id = target_event
  ) then
    raise exception using errcode = 'P0001', message = 'event_not_found';
  end if;

  insert into public.evaluation_criteria (
    event_id, name, description, position
  )
  values
    (target_event, 'Time', '', 1),
    (target_event, 'Solução', '', 2),
    (
      target_event,
      'Pensamento Computacional e Viabilidade',
      '',
      3
    ),
    (target_event, 'Apresentação', '', 4),
    (target_event, 'Mercado', '', 5)
  on conflict (event_id, name) do nothing;

  insert into public.criterion_weights (
    event_id, criterion_id, category, weight
  )
  select
    criterion.event_id,
    criterion.id,
    category.value,
    1
  from public.evaluation_criteria as criterion
  cross join (
    values
      ('junior'::public.team_category),
      ('senior'::public.team_category)
  ) as category(value)
  where criterion.event_id = target_event
  on conflict (criterion_id, category) do nothing;
end;
$$;

revoke all on function private.seed_event_evaluation_defaults(uuid)
from public, anon, authenticated, service_role;

create function private.seed_new_event_evaluation_defaults()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.seed_event_evaluation_defaults(new.id);
  return new;
end;
$$;

revoke all on function private.seed_new_event_evaluation_defaults()
from public, anon, authenticated, service_role;

create trigger seed_new_event_evaluation_defaults
after insert on public.events
for each row execute function private.seed_new_event_evaluation_defaults();

select private.seed_event_evaluation_defaults(event.id)
from public.events as event;

create function private.seed_new_criterion_weights()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.criterion_weights (
    event_id, criterion_id, category, weight
  )
  values
    (new.event_id, new.id, 'junior', 1),
    (new.event_id, new.id, 'senior', 1)
  on conflict (criterion_id, category) do nothing;
  return new;
end;
$$;

revoke all on function private.seed_new_criterion_weights()
from public, anon, authenticated, service_role;

create trigger seed_new_criterion_weights
after insert on public.evaluation_criteria
for each row execute function private.seed_new_criterion_weights();

create function private.protect_evaluation_configuration()
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
    raise exception using
      errcode = 'P0001',
      message = 'evaluation_config_frozen';
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

revoke all on function private.protect_evaluation_configuration()
from public, anon, authenticated, service_role;

create trigger protect_evaluation_criteria_configuration
before insert or update or delete on public.evaluation_criteria
for each row execute function private.protect_evaluation_configuration();

create trigger protect_criterion_weight_configuration
before insert or update or delete on public.criterion_weights
for each row execute function private.protect_evaluation_configuration();

create trigger protect_evaluator_assignment_configuration
before insert or update or delete on public.evaluator_assignments
for each row execute function private.protect_evaluation_configuration();

create function private.audit_weight_configuration()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
begin
  if caller_id is not null and new.weight is distinct from old.weight then
    insert into public.audit_log (
      event_id, actor_id, action, entity_type, entity_id, payload
    )
    values (
      new.event_id,
      caller_id,
      'evaluation_weight_updated',
      'criterion_weight',
      new.criterion_id::text || ':' || new.category::text,
      jsonb_build_object(
        'category', new.category,
        'previous_weight', old.weight,
        'weight', new.weight
      )
    );
  end if;
  return new;
end;
$$;

revoke all on function private.audit_weight_configuration()
from public, anon, authenticated, service_role;

create trigger audit_weight_configuration
after update of weight on public.criterion_weights
for each row execute function private.audit_weight_configuration();

create function private.protect_presentation_slot()
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

  if tg_op <> 'DELETE' and not exists (
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

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function private.protect_presentation_slot()
from public, anon, authenticated, service_role;

create trigger protect_presentation_slot
before insert or update or delete on public.presentation_slots
for each row execute function private.protect_presentation_slot();

create function private.protect_evaluation_freeze()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  raise exception using
    errcode = 'P0001',
    message = 'evaluation_freeze_immutable';
end;
$$;

revoke all on function private.protect_evaluation_freeze()
from public, anon, authenticated, service_role;

create trigger protect_evaluation_freeze
before update or delete on public.evaluation_freezes
for each row execute function private.protect_evaluation_freeze();

alter table public.evaluation_criteria enable row level security;
alter table public.criterion_weights enable row level security;
alter table public.evaluator_assignments enable row level security;
alter table public.presentation_slots enable row level security;
alter table public.evaluations enable row level security;
alter table public.evaluation_scores enable row level security;
alter table public.evaluation_freezes enable row level security;

create policy "criteria visible to evaluation staff"
on public.evaluation_criteria for select to authenticated
using (
  (select public.is_event_professor(event_id))
  or exists (
    select 1
    from public.evaluator_assignments as assignment
    join public.events as event on event.id = assignment.event_id
    where assignment.event_id = evaluation_criteria.event_id
      and assignment.evaluator_id = (select auth.uid())
      and event.status <> 'archived'
  )
);

create policy "Professors create evaluation criteria"
on public.evaluation_criteria for insert to authenticated
with check (
  (select public.is_event_professor(event_id))
  and exists (
    select 1 from public.events as event
    where event.id = evaluation_criteria.event_id
      and event.status <> 'archived'
  )
);

create policy "Professors update evaluation criteria"
on public.evaluation_criteria for update to authenticated
using ((select public.is_event_professor(event_id)))
with check (
  (select public.is_event_professor(event_id))
  and exists (
    select 1 from public.events as event
    where event.id = evaluation_criteria.event_id
      and event.status <> 'archived'
  )
);

create policy "Professors delete evaluation criteria"
on public.evaluation_criteria for delete to authenticated
using ((select public.is_event_professor(event_id)));

create policy "weights visible to evaluation staff"
on public.criterion_weights for select to authenticated
using (
  (select public.is_event_professor(event_id))
  or exists (
    select 1
    from public.evaluator_assignments as assignment
    join public.events as event on event.id = assignment.event_id
    where assignment.event_id = criterion_weights.event_id
      and assignment.category = criterion_weights.category
      and assignment.evaluator_id = (select auth.uid())
      and event.status <> 'archived'
  )
);

create policy "Professors create criterion weights"
on public.criterion_weights for insert to authenticated
with check (
  (select public.is_event_professor(event_id))
  and exists (
    select 1 from public.events as event
    where event.id = criterion_weights.event_id
      and event.status <> 'archived'
  )
);

create policy "Professors update criterion weights"
on public.criterion_weights for update to authenticated
using ((select public.is_event_professor(event_id)))
with check (
  (select public.is_event_professor(event_id))
  and exists (
    select 1 from public.events as event
    where event.id = criterion_weights.event_id
      and event.status <> 'archived'
  )
);

create policy "Professors delete criterion weights"
on public.criterion_weights for delete to authenticated
using ((select public.is_event_professor(event_id)));

create policy "assignments visible to Professor and owner"
on public.evaluator_assignments for select to authenticated
using (
  (select public.is_event_professor(event_id))
  or (
    evaluator_id = (select auth.uid())
    and exists (
      select 1 from public.events as event
      where event.id = evaluator_assignments.event_id
        and event.status <> 'archived'
    )
  )
);

create policy "Professors create evaluator assignments"
on public.evaluator_assignments for insert to authenticated
with check (
  assigned_by = (select auth.uid())
  and (select public.is_event_professor(event_id))
  and exists (
    select 1 from public.events as event
    where event.id = evaluator_assignments.event_id
      and event.status <> 'archived'
  )
);

create policy "Professors delete evaluator assignments"
on public.evaluator_assignments for delete to authenticated
using ((select public.is_event_professor(event_id)));

create policy "presentation slots visible to assigned staff"
on public.presentation_slots for select to authenticated
using (
  (select public.is_event_professor(event_id))
  or exists (
    select 1
    from public.evaluator_assignments as assignment
    join public.events as event on event.id = assignment.event_id
    where assignment.event_id = presentation_slots.event_id
      and assignment.category = presentation_slots.category
      and assignment.evaluator_id = (select auth.uid())
      and event.status <> 'archived'
  )
);

create policy "Professors create presentation slots"
on public.presentation_slots for insert to authenticated
with check ((select public.is_event_professor(event_id)));

create policy "Professors update presentation slots"
on public.presentation_slots for update to authenticated
using ((select public.is_event_professor(event_id)))
with check ((select public.is_event_professor(event_id)));

create policy "Professors delete presentation slots"
on public.presentation_slots for delete to authenticated
using ((select public.is_event_professor(event_id)));

create policy "evaluations visible to Professor and evaluator"
on public.evaluations for select to authenticated
using (
  (select public.is_event_professor(event_id))
  or (
    evaluator_id = (select auth.uid())
    and exists (
      select 1 from public.events as event
      where event.id = evaluations.event_id
        and event.status <> 'archived'
    )
  )
);

create policy "scores visible with private evaluation"
on public.evaluation_scores for select to authenticated
using (
  exists (
    select 1
    from public.evaluations as evaluation
    where evaluation.id = evaluation_scores.evaluation_id
  )
);

create policy "freezes visible to assigned staff"
on public.evaluation_freezes for select to authenticated
using (
  (select public.is_event_professor(event_id))
  or exists (
    select 1
    from public.evaluator_assignments as assignment
    join public.events as event on event.id = assignment.event_id
    where assignment.event_id = evaluation_freezes.event_id
      and assignment.category = evaluation_freezes.category
      and assignment.evaluator_id = (select auth.uid())
      and event.status <> 'archived'
  )
);

revoke all on table
  public.evaluation_criteria,
  public.criterion_weights,
  public.evaluator_assignments,
  public.presentation_slots,
  public.evaluations,
  public.evaluation_scores,
  public.evaluation_freezes
from public, anon, authenticated, service_role;

grant select on table
  public.evaluation_criteria,
  public.criterion_weights,
  public.evaluator_assignments,
  public.presentation_slots,
  public.evaluations,
  public.evaluation_scores,
  public.evaluation_freezes
to authenticated;

grant insert (event_id, name, description, position, active),
  update (name, description, position, active),
  delete
on public.evaluation_criteria to authenticated;

grant insert (event_id, criterion_id, category, weight),
  update (weight),
  delete
on public.criterion_weights to authenticated;

grant insert (event_id, evaluator_id, category),
  delete
on public.evaluator_assignments to authenticated;

grant insert (event_id, category, team_id, position, presented_at),
  update (position, presented_at),
  delete
on public.presentation_slots to authenticated;

create function private.freeze_evaluation_impl(
  target_event uuid,
  target_category public.team_category
)
returns public.evaluation_freezes
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  event_state public.event_status;
  criteria jsonb;
  evaluators jsonb;
  teams jsonb;
  frozen public.evaluation_freezes;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;
  if target_event is null or target_category is null then
    raise exception using
      errcode = 'P0001',
      message = 'evaluation_scope_required';
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
    raise exception using errcode = 'P0001', message = 'event_not_available';
  end if;
  if not exists (
    select 1 from public.events as event
    where event.id = target_event and event.professor_id = caller_id
  ) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;
  if exists (
    select 1 from public.evaluation_freezes as frozen_config
    where frozen_config.event_id = target_event
      and frozen_config.category = target_category
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'evaluation_already_frozen';
  end if;

  select jsonb_agg(
    jsonb_build_object(
      'criterion_id', criterion.id,
      'name', criterion.name,
      'description', criterion.description,
      'position', criterion.position,
      'weight', weight.weight
    )
    order by criterion.position
  )
  into criteria
  from public.evaluation_criteria as criterion
  join public.criterion_weights as weight
    on weight.criterion_id = criterion.id
    and weight.event_id = criterion.event_id
    and weight.category = target_category
  where criterion.event_id = target_event
    and criterion.active;

  if criteria is null then
    raise exception using errcode = 'P0001', message = 'criterion_required';
  end if;
  if not exists (
    select 1
    from public.evaluation_criteria as criterion
    join public.criterion_weights as weight
      on weight.criterion_id = criterion.id
      and weight.event_id = criterion.event_id
      and weight.category = target_category
    where criterion.event_id = target_event
      and criterion.active
    having sum(weight.weight) > 0
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'positive_weight_required';
  end if;

  select jsonb_agg(
    jsonb_build_object(
      'team_id', team.id,
      'name', team.name,
      'category', team.category,
      'canvas_summary', (
        select revision.snapshot
        from public.canvas_activities as activity
        join public.submissions as submission
          on submission.activity_id = activity.id
          and submission.event_id = activity.event_id
          and submission.team_id = team.id
          and submission.status = 'approved'
        join public.submission_revisions as revision
          on revision.submission_id = submission.id
        where activity.event_id = team.event_id
          and activity.is_primary
          and team.category = any(activity.categories)
        order by revision.revision desc
        limit 1
      )
    )
    order by team.name, team.id
  )
  into teams
  from public.teams as team
  where team.event_id = target_event
    and team.category = target_category
    and team.status = 'approved';

  if teams is null then
    raise exception using
      errcode = 'P0001',
      message = 'approved_team_required';
  end if;

  if not exists (
    select 1
    from public.evaluator_assignments as assignment
    where assignment.event_id = target_event
      and assignment.category = target_category
  ) then
    raise exception using errcode = 'P0001', message = 'evaluator_required';
  end if;

  if exists (
    select 1
    from public.evaluator_assignments as assignment
    where assignment.event_id = target_event
      and assignment.category = target_category
      and not exists (
        select 1
        from public.event_roles as role_assignment
        where role_assignment.event_id = assignment.event_id
          and role_assignment.user_id = assignment.evaluator_id
          and role_assignment.role = 'evaluator'
      )
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'evaluator_role_required';
  end if;

  if exists (
    select 1
    from public.evaluator_assignments as assignment
    join public.team_members as member
      on member.event_id = assignment.event_id
      and member.user_id = assignment.evaluator_id
      and member.status = 'active'
    join public.teams as team
      on team.id = member.team_id
      and team.event_id = member.event_id
      and team.category = assignment.category
    where assignment.event_id = target_event
      and assignment.category = target_category
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'evaluator_participant_conflict';
  end if;

  select jsonb_agg(
    jsonb_build_object(
      'evaluator_id', assignment.evaluator_id,
      'display_name', profile.display_name
    )
    order by profile.display_name, assignment.evaluator_id
  )
  into evaluators
  from public.evaluator_assignments as assignment
  join public.profiles as profile on profile.id = assignment.evaluator_id
  where assignment.event_id = target_event
    and assignment.category = target_category;

  insert into public.evaluation_freezes (
    event_id,
    category,
    frozen_by,
    criteria_snapshot,
    evaluator_snapshot,
    team_snapshot
  )
  values (
    target_event,
    target_category,
    caller_id,
    criteria,
    evaluators,
    teams
  )
  returning * into frozen;

  insert into public.audit_log (
    event_id, actor_id, action, entity_type, entity_id, payload
  )
  values (
    target_event,
    caller_id,
    'evaluation_frozen',
    'evaluation_category',
    target_category::text,
    jsonb_build_object(
      'category', target_category,
      'criterion_count', jsonb_array_length(criteria),
      'evaluator_count', jsonb_array_length(evaluators),
      'team_count', jsonb_array_length(teams)
    )
  );

  return frozen;
end;
$$;

create function private.submit_evaluation_impl(
  target_team uuid,
  target_scores jsonb,
  target_comment text
)
returns public.evaluations
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target public.teams;
  event_state public.event_status;
  frozen public.evaluation_freezes;
  normalized_comment text := nullif(btrim(target_comment), '');
  expected_count integer;
  stored_evaluation_id uuid;
  existed boolean := false;
  stored public.evaluations;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;
  if target_team is null then
    raise exception using errcode = 'P0001', message = 'team_required';
  end if;
  if normalized_comment is not null
    and char_length(normalized_comment) > 4000
  then
    raise exception using errcode = 'P0001', message = 'comment_too_long';
  end if;

  select team.*
  into target
  from public.teams as team
  where team.id = target_team;

  if not found then
    raise exception using errcode = 'P0001', message = 'team_not_found';
  end if;

  select event.status
  into event_state
  from public.events as event
  where event.id = target.event_id
  for update;

  if not found or event_state = 'archived' then
    raise exception using errcode = 'P0001', message = 'event_not_available';
  end if;

  select team.*
  into target
  from public.teams as team
  where team.id = target_team
    and team.event_id = target.event_id
  for update;

  select frozen_config.*
  into frozen
  from public.evaluation_freezes as frozen_config
  where frozen_config.event_id = target.event_id
    and frozen_config.category = target.category
  for share;

  if not found then
    raise exception using errcode = 'P0001', message = 'evaluation_not_frozen';
  end if;

  if not exists (
    select 1
    from jsonb_array_elements(frozen.evaluator_snapshot) as evaluator
    where evaluator ->> 'evaluator_id' = caller_id::text
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'not_assigned_to_category';
  end if;

  if not exists (
    select 1
    from public.event_roles as role_assignment
    where role_assignment.event_id = target.event_id
      and role_assignment.user_id = caller_id
      and role_assignment.role = 'evaluator'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'evaluator_role_required';
  end if;

  if not exists (
    select 1
    from jsonb_array_elements(frozen.team_snapshot) as team
    where team ->> 'team_id' = target.id::text
  ) then
    raise exception using errcode = 'P0001', message = 'team_not_eligible';
  end if;

  if exists (
    select 1
    from public.team_members as member
    join public.teams as member_team
      on member_team.id = member.team_id
      and member_team.event_id = member.event_id
    where member.event_id = target.event_id
      and member.user_id = caller_id
      and member.status = 'active'
      and member_team.category = target.category
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'evaluator_participant_conflict';
  end if;

  if target_scores is null or jsonb_typeof(target_scores) <> 'array' then
    raise exception using errcode = 'P0001', message = 'invalid_scores';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(target_scores) as score
    where jsonb_typeof(score) <> 'object'
      or jsonb_typeof(score -> 'criterion_id') <> 'string'
      or not (
        score ->> 'criterion_id'
        ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      )
  ) then
    raise exception using errcode = 'P0001', message = 'invalid_scores';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(target_scores) as score
    where jsonb_typeof(score -> 'score') <> 'number'
      or score ->> 'score' !~ '^[1-5]$'
  ) then
    raise exception using errcode = 'P0001', message = 'invalid_score';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(target_scores) as score
    group by score ->> 'criterion_id'
    having count(*) > 1
  ) then
    raise exception using errcode = 'P0001', message = 'duplicate_scores';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(target_scores) as score
    where not exists (
      select 1
      from jsonb_array_elements(frozen.criteria_snapshot) as criterion
      where criterion ->> 'criterion_id' = score ->> 'criterion_id'
    )
  ) then
    raise exception using errcode = 'P0001', message = 'extra_scores';
  end if;

  expected_count := jsonb_array_length(frozen.criteria_snapshot);
  if jsonb_array_length(target_scores) <> expected_count
    or exists (
      select 1
      from jsonb_array_elements(frozen.criteria_snapshot) as criterion
      where not exists (
        select 1
        from jsonb_array_elements(target_scores) as score
        where score ->> 'criterion_id' = criterion ->> 'criterion_id'
      )
    )
  then
    raise exception using errcode = 'P0001', message = 'incomplete_scores';
  end if;

  select evaluation.id
  into stored_evaluation_id
  from public.evaluations as evaluation
  where evaluation.event_id = target.event_id
    and evaluation.team_id = target.id
    and evaluation.evaluator_id = caller_id
  for update;

  if found then
    existed := true;
    update public.evaluations as evaluation
    set
      comment = normalized_comment,
      submitted_at = now(),
      updated_at = now()
    where evaluation.id = stored_evaluation_id
    returning * into stored;

    delete from public.evaluation_scores as score
    where score.evaluation_id = stored_evaluation_id;
  else
    insert into public.evaluations (
      event_id, category, team_id, evaluator_id, comment
    )
    values (
      target.event_id,
      target.category,
      target.id,
      caller_id,
      normalized_comment
    )
    returning * into stored;
    stored_evaluation_id := stored.id;
  end if;

  insert into public.evaluation_scores (
    evaluation_id, criterion_id, score
  )
  select
    stored_evaluation_id,
    (score ->> 'criterion_id')::uuid,
    (score ->> 'score')::smallint
  from jsonb_array_elements(target_scores) as score;

  insert into public.audit_log (
    event_id, actor_id, action, entity_type, entity_id, payload
  )
  values (
    target.event_id,
    caller_id,
    case
      when existed then 'evaluation_updated'
      else 'evaluation_submitted'
    end,
    'evaluation',
    stored_evaluation_id::text,
    jsonb_build_object(
      'team_id', target.id,
      'category', target.category
    )
  );

  return stored;
end;
$$;

create view private.evaluation_workflow_dispatch
with (security_invoker = true)
as
select
  null::text as operation,
  null::uuid as event_id,
  null::public.team_category as category,
  null::uuid as team_id,
  null::jsonb as scores,
  null::text as comment,
  null::public.evaluation_freezes as freeze_result,
  null::public.evaluations as evaluation_result
where false;

create function private.dispatch_evaluation_workflow()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.operation = 'freeze_evaluation' then
    new.freeze_result := private.freeze_evaluation_impl(
      new.event_id,
      new.category
    );
  elsif new.operation = 'submit_evaluation' then
    new.evaluation_result := private.submit_evaluation_impl(
      new.team_id,
      new.scores,
      new.comment
    );
  else
    raise exception using errcode = 'P0001', message = 'invalid_operation';
  end if;
  return new;
end;
$$;

create trigger dispatch_evaluation_workflow
instead of insert on private.evaluation_workflow_dispatch
for each row execute function private.dispatch_evaluation_workflow();

create function public.freeze_evaluation(
  event_id uuid,
  category public.team_category
)
returns public.evaluation_freezes
language plpgsql
security invoker
set search_path = ''
as $$
declare
  frozen public.evaluation_freezes;
begin
  insert into private.evaluation_workflow_dispatch (
    operation, event_id, category
  )
  values ('freeze_evaluation', $1, $2)
  returning (freeze_result).* into frozen;
  return frozen;
end;
$$;

create function public.submit_evaluation(
  team_id uuid,
  scores jsonb,
  comment text default null
)
returns public.evaluations
language plpgsql
security invoker
set search_path = ''
as $$
declare
  stored public.evaluations;
begin
  insert into private.evaluation_workflow_dispatch (
    operation, team_id, scores, comment
  )
  values ('submit_evaluation', $1, $2, $3)
  returning (evaluation_result).* into stored;
  return stored;
end;
$$;

revoke all on function
  private.freeze_evaluation_impl(uuid, public.team_category),
  private.submit_evaluation_impl(uuid, jsonb, text),
  private.dispatch_evaluation_workflow()
from public, anon, authenticated, service_role;

revoke all on table private.evaluation_workflow_dispatch
from public, anon, authenticated, service_role;

grant insert (
  operation, event_id, category, team_id, scores, comment
) on private.evaluation_workflow_dispatch to authenticated;

grant select (
  freeze_result, evaluation_result
) on private.evaluation_workflow_dispatch to authenticated;

revoke all on function
  public.freeze_evaluation(uuid, public.team_category),
  public.submit_evaluation(uuid, jsonb, text)
from public, anon, authenticated, service_role;

grant execute on function
  public.freeze_evaluation(uuid, public.team_category),
  public.submit_evaluation(uuid, jsonb, text)
to authenticated;

comment on function private.freeze_evaluation_impl(
  uuid, public.team_category
) is
  'Privileged, event-locked immutable category snapshot implementation.';
comment on function private.submit_evaluation_impl(uuid, jsonb, text) is
  'Privileged atomic evaluation replacement validated against a freeze.';
comment on view private.evaluation_workflow_dispatch is
  'Non-exposed invoker bridge to privileged evaluation workflow triggers.';
