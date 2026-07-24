create table public.workshops (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  title text not null,
  description text not null default '',
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  capacity integer not null,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  constraint workshops_title_normalized check (title = btrim(title) and title <> ''),
  constraint workshops_capacity_positive check (capacity > 0),
  constraint workshops_window_valid check (ends_at > starts_at)
);

create index workshops_event_id_idx on public.workshops (event_id);

create table public.workshop_enrollments (
  workshop_id uuid not null references public.workshops(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  team_id uuid not null references public.teams(id) on delete cascade,
  enrolled_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  primary key (workshop_id, user_id)
);

create index workshop_enrollments_team_id_idx on public.workshop_enrollments (team_id);
create index workshop_enrollments_user_id_idx on public.workshop_enrollments (user_id);

alter table public.workshops enable row level security;
alter table public.workshop_enrollments enable row level security;

-- Workshops visible to all authenticated users
create policy "workshops visible to authenticated users"
on public.workshops for select to authenticated
using (true);

-- Only professors can manage workshops
create policy "Professors create workshops"
on public.workshops for insert to authenticated
with check (
  created_by = (select auth.uid())
  and (select public.is_event_professor(event_id))
);

create policy "Professors update workshops"
on public.workshops for update to authenticated
using ((select public.is_event_professor(event_id)))
with check ((select public.is_event_professor(event_id)));

create policy "Professors delete workshops"
on public.workshops for delete to authenticated
using ((select public.is_event_professor(event_id)));

-- Enrollments visibility
-- Professors can read all enrollments
create policy "Professor reads all enrollments"
on public.workshop_enrollments for select to authenticated
using (
  exists (
    select 1 from public.workshops w
    where w.id = workshop_id and public.is_event_professor(w.event_id)
  )
);

-- Users can read enrollments of their team members (which includes their own)
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

-- Enroll RPC
create or replace function public.enroll_in_workshop(
  p_workshop_id uuid,
  p_user_id uuid
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target_event_id uuid;
  target_team_id uuid;
  current_enrollment_count integer;
  max_capacity integer;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  -- Verify workshop exists and get event_id
  select event_id, capacity into target_event_id, max_capacity
  from public.workshops
  where id = p_workshop_id
  for update; -- Lock the row to prevent concurrent capacity breaches

  if not found then
    raise exception using errcode = 'P0001', message = 'workshop_not_found';
  end if;

  -- Verify user is in an active team for this event
  select team_id into target_team_id
  from public.team_members
  where user_id = p_user_id
    and event_id = target_event_id
    and status = 'active';

  if target_team_id is null then
    raise exception using errcode = 'P0001', message = 'user_not_in_event';
  end if;

  -- Verify caller has permission (is the user themselves, or the team leader)
  if caller_id <> p_user_id then
    if not exists (
      select 1 from public.teams
      where id = target_team_id
        and leader_id = caller_id
    ) then
      raise exception using errcode = 'P0001', message = 'enrollment_forbidden';
    end if;
  end if;

  -- Check capacity
  select count(*) into current_enrollment_count
  from public.workshop_enrollments
  where workshop_id = p_workshop_id;

  if current_enrollment_count >= max_capacity then
    raise exception using errcode = 'P0001', message = 'workshop_full';
  end if;

  -- Insert enrollment
  begin
    insert into public.workshop_enrollments (
      workshop_id, user_id, team_id, enrolled_by
    ) values (
      p_workshop_id, p_user_id, target_team_id, caller_id
    );
  exception
    when unique_violation then
      -- Already enrolled, ignore
      return;
  end;
end;
$$;

-- Unenroll RPC
create or replace function public.unenroll_from_workshop(
  p_workshop_id uuid,
  p_user_id uuid
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target_team_id uuid;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  -- Verify user's team to check permissions
  select team_id into target_team_id
  from public.workshop_enrollments
  where workshop_id = p_workshop_id
    and user_id = p_user_id;

  if not found then
    return; -- Not enrolled, nothing to do
  end if;

  -- Verify caller has permission
  if caller_id <> p_user_id then
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
    and user_id = p_user_id;
end;
$$;
