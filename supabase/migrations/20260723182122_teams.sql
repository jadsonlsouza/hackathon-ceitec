create type public.team_category as enum ('junior', 'senior');
create type public.team_status as enum ('pending', 'approved', 'rejected');
create type public.member_status as enum (
  'invited',
  'join_requested',
  'active',
  'rejected',
  'removed'
);

revoke usage on type
  public.team_category,
  public.team_status,
  public.member_status
from public, anon, authenticated, service_role;

grant usage on type
  public.team_category,
  public.team_status,
  public.member_status
to authenticated;

create table public.teams (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id),
  name text not null,
  category public.team_category not null,
  leader_id uuid not null references public.profiles(id),
  status public.team_status not null default 'pending',
  decided_by uuid references public.profiles(id),
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  constraint teams_id_event_key unique (id, event_id),
  constraint teams_event_name_key unique (event_id, name),
  constraint teams_name_normalized check (
    name = btrim(name)
    and name <> ''
  ),
  constraint teams_decision_consistent check (
    (
      status = 'pending'
      and decided_by is null
      and decided_at is null
    )
    or (
      status in ('approved', 'rejected')
      and decided_by is not null
      and decided_at is not null
    )
  )
);

create index teams_leader_id_idx on public.teams (leader_id);
create index teams_decided_by_idx on public.teams (decided_by)
where decided_by is not null;

create table public.team_members (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id),
  team_id uuid not null,
  user_id uuid references public.profiles(id),
  name text not null,
  email text not null,
  enrollment text not null,
  status public.member_status not null default 'invited',
  approved_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  constraint team_members_team_event_fkey
    foreign key (team_id, event_id)
    references public.teams(id, event_id),
  constraint team_members_name_normalized check (
    name = btrim(name)
    and name <> ''
  ),
  constraint team_members_email_normalized check (
    email = lower(btrim(email))
    and email <> ''
  ),
  constraint team_members_enrollment_normalized check (
    enrollment = lower(btrim(enrollment))
    and enrollment <> ''
  ),
  constraint team_members_user_status_consistent check (
    (
      status = 'invited'
      and user_id is null
      and approved_by is null
    )
    or (
      status = 'join_requested'
      and user_id is not null
      and approved_by is null
    )
    or (
      status in ('active', 'rejected', 'removed')
      and user_id is not null
      and approved_by is not null
    )
  )
);

create unique index reserved_email_per_event
  on public.team_members (event_id, email)
  where status in ('invited', 'join_requested', 'active');
create unique index reserved_enrollment_per_event
  on public.team_members (event_id, enrollment)
  where status in ('invited', 'join_requested', 'active');
create unique index one_team_membership_per_user
  on public.team_members (event_id, user_id)
  where user_id is not null
    and status in ('join_requested', 'active');
create unique index one_member_row_per_team_user
  on public.team_members (team_id, user_id)
  where user_id is not null;
create index team_members_team_event_idx
  on public.team_members (team_id, event_id);
create index team_members_event_id_idx
  on public.team_members (event_id);
create index team_members_user_id_idx
  on public.team_members (user_id)
  where user_id is not null;
create index team_members_approved_by_idx
  on public.team_members (approved_by)
  where approved_by is not null;

create function private.protect_team_event_write()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target_event_id uuid;
  target_status public.event_status;
  reserved_seats integer;
begin
  if tg_op = 'DELETE' then
    if tg_table_name = 'teams' then
      raise exception using errcode = 'P0001', message = 'team_delete_forbidden';
    end if;

    raise exception using
      errcode = 'P0001',
      message = 'team_member_delete_forbidden';
  end if;

  if tg_op = 'UPDATE' and new.event_id is distinct from old.event_id then
    raise exception using
      errcode = 'P0001',
      message = 'cross_event_move_forbidden';
  end if;

  target_event_id := new.event_id;

  select event.status
  into target_status
  from public.events as event
  where event.id = target_event_id;

  if not found or target_status = 'archived' then
    raise exception using errcode = 'P0001', message = 'event_not_available';
  end if;

  if tg_table_name = 'team_members' then
    if new.status::text in ('invited', 'join_requested', 'active')
      and (
        tg_op = 'INSERT'
        or old.status::text not in ('invited', 'join_requested', 'active')
        or old.team_id is distinct from new.team_id
      )
    then
      perform 1
      from public.teams as team
      where team.id = new.team_id
        and team.event_id = new.event_id
      for update;

      if not found then
        raise exception using
          errcode = 'P0001',
          message = 'cross_event_reference';
      end if;

      select count(*)::integer
      into reserved_seats
      from public.team_members as member
      where member.team_id = new.team_id
        and member.event_id = new.event_id
        and member.status in ('invited', 'join_requested', 'active');

      if reserved_seats >= 6 then
        raise exception using
          errcode = 'P0001',
          message = 'team_size_out_of_range';
      end if;
    end if;
  end if;

  return new;
end;
$$;

create trigger protect_team_event_write
before insert or update or delete on public.teams
for each row execute function private.protect_team_event_write();

create trigger protect_team_member_event_write
before insert or update or delete on public.team_members
for each row execute function private.protect_team_event_write();

create function private.assert_team_leader_membership()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target_team_id uuid;
begin
  if tg_table_name = 'teams' then
    if tg_op = 'DELETE' then
      target_team_id := old.id;
    else
      target_team_id := new.id;
    end if;
  elsif tg_op = 'DELETE' then
    target_team_id := old.team_id;
  else
    target_team_id := new.team_id;
  end if;

  if exists (
    select 1
    from public.teams as team
    where team.id = target_team_id
  ) and not exists (
    select 1
    from public.teams as team
    join public.team_members as member
      on member.team_id = team.id
      and member.event_id = team.event_id
      and member.user_id = team.leader_id
      and member.status = 'active'
    where team.id = target_team_id
  ) then
    raise exception using
      errcode = '23514',
      message = 'team_leader_must_be_active_member';
  end if;

  return null;
end;
$$;

create constraint trigger teams_require_active_leader
after insert or update on public.teams
deferrable initially deferred
for each row execute function private.assert_team_leader_membership();

create constraint trigger team_members_preserve_active_leader
after insert or update or delete on public.team_members
deferrable initially deferred
for each row execute function private.assert_team_leader_membership();

create view private.current_team_access
with (security_barrier = true)
as
select distinct
  member.event_id,
  member.team_id,
  (select auth.uid()) as user_id
from public.team_members as member
where (select auth.uid()) is not null
  and member.status in ('invited', 'join_requested', 'active')
  and (
    member.user_id = (select auth.uid())
    or (
      member.email = lower(btrim(coalesce(auth.jwt() ->> 'email', '')))
      and member.email <> ''
    )
  );

revoke all on table private.current_team_access
from public, anon, authenticated, service_role;
grant select on table private.current_team_access to authenticated;

alter table public.teams enable row level security;
alter table public.team_members enable row level security;

create policy "teams visible to scoped participants"
on public.teams
for select
to authenticated
using (
  exists (
    select 1
    from private.current_team_access as access
    where access.team_id = teams.id
      and access.event_id = teams.event_id
      and access.user_id = (select auth.uid())
  )
  or (select public.is_event_professor(event_id))
);

create policy "members visible to scoped participants"
on public.team_members
for select
to authenticated
using (
  exists (
    select 1
    from private.current_team_access as access
    where access.team_id = team_members.team_id
      and access.event_id = team_members.event_id
      and access.user_id = (select auth.uid())
  )
  or (select public.is_event_professor(event_id))
);

revoke all on table public.teams, public.team_members
from public, anon, authenticated, service_role;
grant select on table public.teams, public.team_members to authenticated;

create function private.create_team_impl(
  target_event uuid,
  target_name text,
  target_category public.team_category,
  target_members jsonb
)
returns public.teams
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  caller_profile public.profiles;
  target_event_row public.events;
  created_team public.teams;
  member_count integer;
  leader_member_count integer;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  if target_event is null then
    raise exception using errcode = 'P0001', message = 'event_required';
  end if;

  if target_category is null then
    raise exception using errcode = 'P0001', message = 'category_required';
  end if;

  if target_name is null or btrim(target_name) = '' then
    raise exception using errcode = 'P0001', message = 'team_name_required';
  end if;

  if target_members is null or jsonb_typeof(target_members) <> 'array' then
    raise exception using errcode = 'P0001', message = 'members_array_required';
  end if;

  member_count := jsonb_array_length(target_members);

  if member_count < 1 or member_count > 6 then
    raise exception using errcode = 'P0001', message = 'team_size_out_of_range';
  end if;

  select event.*
  into target_event_row
  from public.events as event
  where event.id = target_event
  for update;

  if not found or target_event_row.status = 'archived' then
    raise exception using errcode = 'P0001', message = 'event_not_available';
  end if;

  select profile.*
  into caller_profile
  from public.profiles as profile
  where profile.id = caller_id;

  if not found then
    raise exception using errcode = 'P0001', message = 'profile_required';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(target_members) as item(value)
    where jsonb_typeof(item.value) <> 'object'
      or coalesce(btrim(item.value ->> 'name'), '') = ''
      or coalesce(btrim(item.value ->> 'email'), '') = ''
      or coalesce(btrim(item.value ->> 'enrollment'), '') = ''
  ) then
    raise exception using errcode = 'P0001', message = 'invalid_member';
  end if;

  select count(*)::integer
  into leader_member_count
  from jsonb_array_elements(target_members) as item(value)
  where lower(btrim(item.value ->> 'email'))
    = lower(btrim(caller_profile.email));

  if leader_member_count <> 1 then
    raise exception using errcode = 'P0001', message = 'leader_member_required';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(target_members) as item(value)
    group by lower(btrim(item.value ->> 'email'))
    having count(*) > 1
  ) or exists (
    select 1
    from jsonb_array_elements(target_members) as item(value)
    group by lower(btrim(item.value ->> 'enrollment'))
    having count(*) > 1
  ) then
    raise exception using errcode = 'P0001', message = 'member_already_reserved';
  end if;

  if exists (
    select 1
    from public.team_members as existing
    where existing.event_id = target_event
      and existing.status in ('invited', 'join_requested', 'active')
      and (
        existing.email in (
          select lower(btrim(item.value ->> 'email'))
          from jsonb_array_elements(target_members) as item(value)
        )
        or existing.enrollment in (
          select lower(btrim(item.value ->> 'enrollment'))
          from jsonb_array_elements(target_members) as item(value)
        )
      )
  ) then
    raise exception using errcode = 'P0001', message = 'member_already_reserved';
  end if;

  insert into public.teams (
    event_id,
    name,
    category,
    leader_id
  )
  values (
    target_event,
    btrim(target_name),
    target_category,
    caller_id
  )
  returning * into created_team;

  begin
    insert into public.team_members (
      event_id,
      team_id,
      user_id,
      name,
      email,
      enrollment,
      status,
      approved_by
    )
    select
      target_event,
      created_team.id,
      case
        when lower(btrim(item.value ->> 'email'))
          = lower(btrim(caller_profile.email))
          then caller_id
        else null
      end,
      btrim(item.value ->> 'name'),
      lower(btrim(item.value ->> 'email')),
      lower(btrim(item.value ->> 'enrollment')),
      case
        when lower(btrim(item.value ->> 'email'))
          = lower(btrim(caller_profile.email))
          then 'active'::public.member_status
        else 'invited'::public.member_status
      end,
      case
        when lower(btrim(item.value ->> 'email'))
          = lower(btrim(caller_profile.email))
          then caller_id
        else null
      end
    from jsonb_array_elements(target_members) as item(value);
  exception
    when unique_violation then
      raise exception using
        errcode = 'P0001',
        message = 'member_already_reserved';
  end;

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
    'team_created',
    'team',
    created_team.id::text,
    jsonb_build_object(
      'category',
      target_category,
      'reserved_seats',
      member_count
    )
  );

  return created_team;
end;
$$;

create function private.request_team_join_impl(target_member uuid)
returns public.team_members
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  caller_email text := lower(btrim(coalesce(auth.jwt() ->> 'email', '')));
  target_event_id uuid;
  target_team_id uuid;
  target_event public.events;
  target_team public.teams;
  target public.team_members;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  if target_member is null then
    raise exception using errcode = 'P0001', message = 'member_required';
  end if;

  select member.event_id, member.team_id
  into target_event_id, target_team_id
  from public.team_members as member
  where member.id = target_member;

  if not found then
    raise exception using errcode = 'P0001', message = 'member_not_found';
  end if;

  select event.*
  into target_event
  from public.events as event
  where event.id = target_event_id
  for update;

  if not found or target_event.status = 'archived' then
    raise exception using errcode = 'P0001', message = 'event_not_available';
  end if;

  select team.*
  into target_team
  from public.teams as team
  where team.id = target_team_id
    and team.event_id = target_event_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'cross_event_reference';
  end if;

  select member.*
  into target
  from public.team_members as member
  where member.id = target_member
    and member.team_id = target_team.id
    and member.event_id = target_event.id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'cross_event_reference';
  end if;

  if target.status <> 'invited' then
    raise exception using errcode = 'P0001', message = 'member_not_invited';
  end if;

  if caller_email = '' or target.email <> caller_email then
    raise exception using errcode = 'P0001', message = 'reserved_email_mismatch';
  end if;

  update public.team_members as member
  set
    user_id = caller_id,
    status = 'join_requested'
  where member.id = target.id
  returning * into target;

  insert into public.audit_log (
    event_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    payload
  )
  values (
    target.event_id,
    caller_id,
    'team_join_requested',
    'team_member',
    target.id::text,
    jsonb_build_object('team_id', target.team_id)
  );

  return target;
exception
  when unique_violation then
    raise exception using
      errcode = 'P0001',
      message = 'member_already_reserved';
end;
$$;

create function private.decide_team_join_impl(
  target_member uuid,
  approve_join boolean
)
returns public.team_members
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target_event_id uuid;
  target_team_id uuid;
  target_event public.events;
  target_team public.teams;
  target public.team_members;
  resulting_status public.member_status;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  if approve_join is null then
    raise exception using errcode = 'P0001', message = 'invalid_decision';
  end if;

  select member.event_id, member.team_id
  into target_event_id, target_team_id
  from public.team_members as member
  where member.id = target_member;

  if not found then
    raise exception using errcode = 'P0001', message = 'member_not_found';
  end if;

  select event.*
  into target_event
  from public.events as event
  where event.id = target_event_id
  for update;

  if not found or target_event.status = 'archived' then
    raise exception using errcode = 'P0001', message = 'event_not_available';
  end if;

  select team.*
  into target_team
  from public.teams as team
  where team.id = target_team_id
    and team.event_id = target_event_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'cross_event_reference';
  end if;

  if target_team.leader_id <> caller_id then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  select member.*
  into target
  from public.team_members as member
  where member.id = target_member
    and member.team_id = target_team.id
    and member.event_id = target_event.id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'cross_event_reference';
  end if;

  if target.status <> 'join_requested' then
    raise exception using errcode = 'P0001', message = 'join_not_pending';
  end if;

  resulting_status := case
    when approve_join then 'active'::public.member_status
    else 'rejected'::public.member_status
  end;

  update public.team_members as member
  set
    status = resulting_status,
    approved_by = caller_id
  where member.id = target.id
  returning * into target;

  insert into public.audit_log (
    event_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    payload
  )
  values (
    target.event_id,
    caller_id,
    case
      when approve_join then 'team_join_approved'
      else 'team_join_rejected'
    end,
    'team_member',
    target.id::text,
    jsonb_build_object('team_id', target.team_id)
  );

  return target;
end;
$$;

create function private.decide_team_impl(
  target_team_id uuid,
  target_decision public.team_status
)
returns public.teams
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target_event_id uuid;
  target_event public.events;
  target public.teams;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  if target_decision is null
    or target_decision not in ('approved', 'rejected')
  then
    raise exception using errcode = 'P0001', message = 'invalid_decision';
  end if;

  select team.event_id
  into target_event_id
  from public.teams as team
  where team.id = target_team_id;

  if not found then
    raise exception using errcode = 'P0001', message = 'team_not_found';
  end if;

  select event.*
  into target_event
  from public.events as event
  where event.id = target_event_id
  for update;

  if not found or target_event.status = 'archived' then
    raise exception using errcode = 'P0001', message = 'event_not_available';
  end if;

  select team.*
  into target
  from public.teams as team
  where team.id = target_team_id
    and team.event_id = target_event.id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'cross_event_reference';
  end if;

  if target_event.professor_id is distinct from caller_id
    or not public.is_event_professor(target.event_id)
  then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  if target.status <> 'pending' then
    raise exception using errcode = 'P0001', message = 'team_not_pending';
  end if;

  update public.teams as team
  set
    status = target_decision,
    decided_by = caller_id,
    decided_at = now()
  where team.id = target.id
  returning * into target;

  insert into public.audit_log (
    event_id,
    actor_id,
    action,
    entity_type,
    entity_id
  )
  values (
    target.event_id,
    caller_id,
    'team_' || target_decision::text,
    'team',
    target.id::text
  );

  return target;
end;
$$;

create view private.team_workflow_dispatch
with (security_invoker = true)
as
select
  null::text as operation,
  null::uuid as event_id,
  null::text as team_name,
  null::public.team_category as category,
  null::jsonb as members,
  null::uuid as member_id,
  null::boolean as approve,
  null::uuid as team_id,
  null::public.team_status as decision,
  null::public.teams as team_result,
  null::public.team_members as member_result
where false;

create function private.dispatch_team_workflow()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.operation = 'create_team' then
    new.team_result := private.create_team_impl(
      new.event_id,
      new.team_name,
      new.category,
      new.members
    );
  elsif new.operation = 'request_team_join' then
    new.member_result := private.request_team_join_impl(new.member_id);
  elsif new.operation = 'decide_team_join' then
    new.member_result := private.decide_team_join_impl(
      new.member_id,
      new.approve
    );
  elsif new.operation = 'decide_team' then
    new.team_result := private.decide_team_impl(
      new.team_id,
      new.decision
    );
  else
    raise exception using errcode = 'P0001', message = 'invalid_operation';
  end if;

  return new;
end;
$$;

create trigger dispatch_team_workflow
instead of insert on private.team_workflow_dispatch
for each row execute function private.dispatch_team_workflow();

create function public.create_team(
  event_id uuid,
  name text,
  category public.team_category,
  members jsonb
)
returns public.teams
language plpgsql
security invoker
set search_path = ''
as $$
declare
  created public.teams;
begin
  insert into private.team_workflow_dispatch (
    operation,
    event_id,
    team_name,
    category,
    members
  )
  values (
    'create_team',
    event_id,
    name,
    category,
    members
  )
  returning (team_result).* into created;

  return created;
end;
$$;

create function public.request_team_join(member_id uuid)
returns public.team_members
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target public.team_members;
begin
  insert into private.team_workflow_dispatch (
    operation,
    member_id
  )
  values (
    'request_team_join',
    member_id
  )
  returning (member_result).* into target;

  return target;
end;
$$;

create function public.decide_team_join(
  member_id uuid,
  approve boolean
)
returns public.team_members
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target public.team_members;
begin
  insert into private.team_workflow_dispatch (
    operation,
    member_id,
    approve
  )
  values (
    'decide_team_join',
    member_id,
    approve
  )
  returning (member_result).* into target;

  return target;
end;
$$;

create function public.decide_team(
  team_id uuid,
  decision public.team_status
)
returns public.teams
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target public.teams;
begin
  insert into private.team_workflow_dispatch (
    operation,
    team_id,
    decision
  )
  values (
    'decide_team',
    team_id,
    decision
  )
  returning (team_result).* into target;

  return target;
end;
$$;

revoke all on function
  private.protect_team_event_write(),
  private.assert_team_leader_membership(),
  private.create_team_impl(uuid, text, public.team_category, jsonb),
  private.request_team_join_impl(uuid),
  private.decide_team_join_impl(uuid, boolean),
  private.decide_team_impl(uuid, public.team_status),
  private.dispatch_team_workflow()
from public, anon, authenticated, service_role;

revoke all on table private.team_workflow_dispatch
from public, anon, authenticated, service_role;

grant insert (
  operation,
  event_id,
  team_name,
  category,
  members,
  member_id,
  approve,
  team_id,
  decision
) on private.team_workflow_dispatch to authenticated;

grant select (
  team_result,
  member_result
) on private.team_workflow_dispatch to authenticated;

revoke all on function
  public.create_team(uuid, text, public.team_category, jsonb),
  public.request_team_join(uuid),
  public.decide_team_join(uuid, boolean),
  public.decide_team(uuid, public.team_status)
from public, anon, authenticated, service_role;

grant execute on function
  public.create_team(uuid, text, public.team_category, jsonb),
  public.request_team_join(uuid),
  public.decide_team_join(uuid, boolean),
  public.decide_team(uuid, public.team_status)
to authenticated;

comment on function private.create_team_impl(
  uuid,
  text,
  public.team_category,
  jsonb
) is
  'Privileged, event-locked team reservation implementation.';
comment on function private.request_team_join_impl(uuid) is
  'Privileged matching-email join request implementation.';
comment on function private.decide_team_join_impl(uuid, boolean) is
  'Privileged leader-authorized join decision implementation.';
comment on function private.decide_team_impl(uuid, public.team_status) is
  'Privileged assigned-Professor team decision implementation.';
comment on view private.team_workflow_dispatch is
  'Non-exposed invoker bridge to privileged team workflow triggers.';
