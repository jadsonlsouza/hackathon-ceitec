-- 1. Create tables
create table public.attendance_sessions (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.events(id) on delete cascade not null,
  session_date date not null,
  secret_word text not null,
  created_at timestamptz default now(),
  created_by uuid references auth.users(id) on delete set null,
  unique (event_id, secret_word)
);

create table public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  session_id uuid references public.attendance_sessions(id) on delete cascade not null,
  member_id uuid references public.team_members(id) on delete cascade not null,
  checked_in_at timestamptz default now(),
  unique (session_id, member_id)
);

-- 2. Enable RLS
alter table public.attendance_sessions enable row level security;
alter table public.attendance_records enable row level security;

-- 3. RLS Policies
-- attendance_sessions
create policy "Anyone can read attendance sessions for their events"
  on public.attendance_sessions for select
  using (
    -- Professors/admins can read their event sessions
    public.is_event_professor(event_id)
    -- Students could technically read them if needed, but the RPC will use security definer anyway.
    -- We allow reading by anyone to simplify frontend state for professors.
  );

create policy "Professors can insert attendance sessions"
  on public.attendance_sessions for insert
  with check (public.is_event_professor(event_id));

create policy "Professors can delete attendance sessions"
  on public.attendance_sessions for delete
  using (public.is_event_professor(event_id));

-- attendance_records
create policy "Professors can read attendance records"
  on public.attendance_records for select
  using (
    exists (
      select 1 from public.attendance_sessions s
      where s.id = attendance_records.session_id
      and public.is_event_professor(s.event_id)
    )
  );

create policy "Students can read their own attendance records"
  on public.attendance_records for select
  using (
    exists (
      select 1 from public.team_members tm
      where tm.id = attendance_records.member_id
      and tm.user_id = auth.uid()
    )
  );

-- 4. RPCs

-- RPC for admin to create an attendance session
create or replace function public.admin_create_attendance_session(
  p_event_id uuid,
  p_session_date date,
  p_secret_word text
)
returns public.attendance_sessions
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  new_session public.attendance_sessions;
begin
  if not public.is_event_professor(p_event_id) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  if p_secret_word is null or btrim(p_secret_word) = '' then
    raise exception using errcode = 'P0001', message = 'invalid_secret_word';
  end if;

  -- Ensure secret word is unique per event
  if exists (
    select 1 from public.attendance_sessions
    where event_id = p_event_id
      and lower(btrim(secret_word)) = lower(btrim(p_secret_word))
  ) then
    raise exception using errcode = 'P0001', message = 'secret_word_already_exists';
  end if;

  insert into public.attendance_sessions (
    event_id, session_date, secret_word, created_by
  )
  values (
    p_event_id, p_session_date, btrim(p_secret_word), caller_id
  )
  returning * into new_session;

  return new_session;
end;
$$;

revoke all on function public.admin_create_attendance_session(uuid, date, text)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_create_attendance_session(uuid, date, text)
  to authenticated;


-- RPC for student to check in
create or replace function public.student_check_in(
  p_event_id uuid,
  p_secret_word text
)
returns public.attendance_records
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target_session public.attendance_sessions;
  caller_member_id uuid;
  new_record public.attendance_records;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  -- 1. Find the session matching the event and secret word
  select * into target_session
  from public.attendance_sessions
  where event_id = p_event_id
    and lower(btrim(secret_word)) = lower(btrim(p_secret_word));

  if not found then
    raise exception using errcode = 'P0001', message = 'invalid_secret_word';
  end if;

  -- 2. Ensure the user is an active member in this event
  select id into caller_member_id
  from public.team_members
  where event_id = p_event_id
    and user_id = caller_id
    and status = 'active'
  limit 1;

  if not found then
    raise exception using errcode = 'P0001', message = 'not_a_participant';
  end if;

  -- 3. Check if already checked in
  if exists (
    select 1 from public.attendance_records
    where session_id = target_session.id
      and member_id = caller_member_id
  ) then
    raise exception using errcode = 'P0001', message = 'already_checked_in';
  end if;

  -- 4. Record attendance
  insert into public.attendance_records (
    session_id, member_id
  )
  values (
    target_session.id, caller_member_id
  )
  returning * into new_record;

  return new_record;
end;
$$;

revoke all on function public.student_check_in(uuid, text)
  from public, anon, authenticated, service_role;
grant execute on function public.student_check_in(uuid, text)
  to authenticated;
