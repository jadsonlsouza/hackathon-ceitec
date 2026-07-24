-- 0. Update check constraint to allow active members without user_id
alter table public.team_members drop constraint if exists team_members_user_status_consistent;

alter table public.team_members add constraint team_members_user_status_consistent check (
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
      and approved_by is not null
    )
);

-- 1. Drop and recreate workshop_enrollments to use member_id
drop table if exists public.workshop_enrollments cascade;

create table public.workshop_enrollments (
  workshop_id uuid not null references public.workshops(id) on delete cascade,
  member_id uuid not null references public.team_members(id) on delete cascade,
  team_id uuid not null references public.teams(id) on delete cascade,
  enrolled_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  primary key (workshop_id, member_id)
);

create index workshop_enrollments_team_id_idx on public.workshop_enrollments (team_id);
create index workshop_enrollments_member_id_idx on public.workshop_enrollments (member_id);

alter table public.workshop_enrollments enable row level security;

create policy "Professor reads all enrollments"
on public.workshop_enrollments for select to authenticated
using (
  exists (
    select 1 from public.workshops w
    where w.id = workshop_id and public.is_event_professor(w.event_id)
  )
);

create policy "Users read team enrollments"
on public.workshop_enrollments for select to authenticated
using (
  exists (
    select 1 from public.team_members as member
    where member.team_id = workshop_enrollments.team_id
      and member.user_id = (select auth.uid())
      and member.status = 'active'
  )
);

grant select, insert, update, delete on public.workshop_enrollments to authenticated;

-- 2. Update enroll RPC
drop function if exists public.enroll_in_workshop(uuid, uuid);

create or replace function public.enroll_in_workshop(
  p_workshop_id uuid,
  p_member_id uuid
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target_event_id uuid;
  target_team_id uuid;
  target_member_user_id uuid;
  current_enrollment_count integer;
  max_capacity integer;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  select event_id, capacity into target_event_id, max_capacity
  from public.workshops
  where id = p_workshop_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'workshop_not_found';
  end if;

  select team_id, user_id into target_team_id, target_member_user_id
  from public.team_members
  where id = p_member_id
    and event_id = target_event_id
    and status = 'active';

  if target_team_id is null then
    raise exception using errcode = 'P0001', message = 'member_not_in_event';
  end if;

  if caller_id <> coalesce(target_member_user_id, '00000000-0000-0000-0000-000000000000'::uuid) then
    if not exists (
      select 1 from public.teams
      where id = target_team_id
        and leader_id = caller_id
    ) then
      raise exception using errcode = 'P0001', message = 'enrollment_forbidden';
    end if;
  end if;

  select count(*) into current_enrollment_count
  from public.workshop_enrollments
  where workshop_id = p_workshop_id;

  if current_enrollment_count >= max_capacity then
    raise exception using errcode = 'P0001', message = 'workshop_full';
  end if;

  begin
    insert into public.workshop_enrollments (
      workshop_id, member_id, team_id, enrolled_by
    ) values (
      p_workshop_id, p_member_id, target_team_id, caller_id
    );
  exception
    when unique_violation then
      return;
  end;
end;
$$;

-- 3. Update unenroll RPC
drop function if exists public.unenroll_from_workshop(uuid, uuid);

create or replace function public.unenroll_from_workshop(
  p_workshop_id uuid,
  p_member_id uuid
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target_team_id uuid;
  target_member_user_id uuid;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  select team_id, user_id into target_team_id, target_member_user_id
  from public.team_members
  where id = p_member_id;

  if not found then
    return;
  end if;

  if caller_id <> coalesce(target_member_user_id, '00000000-0000-0000-0000-000000000000'::uuid) then
    if not exists (
      select 1 from public.teams
      where id = target_team_id
        and leader_id = caller_id
    ) then
      raise exception using errcode = 'P0001', message = 'unenrollment_forbidden';
    end if;
  end if;

  delete from public.workshop_enrollments
  where workshop_id = p_workshop_id
    and member_id = p_member_id;
end;
$$;

-- 4. Update create_team_impl to insert everyone as 'active'
create or replace function private.create_team_impl(
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
      'active'::public.member_status,
      caller_id
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

-- 5. Update handle_new_user to link existing active team members by email
create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  requested_role_text text := new.raw_user_meta_data ->> 'requested_role';
  requested_event_text text := new.raw_user_meta_data ->> 'event_id';
begin
  if caller_id is not null and caller_id <> new.id then
    raise exception 'signup_identity_mismatch';
  end if;

  insert into public.profiles (id, email, display_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', '')
  );

  update public.team_members
  set user_id = new.id
  where lower(btrim(email)) = lower(btrim(new.email))
    and user_id is null;

  if requested_role_text in ('professor', 'monitor', 'evaluator')
    and requested_event_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  then
    insert into public.role_requests (
      user_id,
      event_id,
      requested_role,
      status
    )
    select
      new.id,
      event.id,
      requested_role_text::public.event_role,
      'pending'::public.request_status
    from public.events as event
    where event.id = requested_event_text::uuid
      and event.status <> 'archived'
    on conflict (user_id, event_id, requested_role)
      where status = 'pending'
      do nothing;
  end if;

  return new;
end;
$$;

-- 6. Update existing 'invited' members to 'active'
update public.team_members
set status = 'active', approved_by = (select leader_id from public.teams where id = public.team_members.team_id)
where status = 'invited';
