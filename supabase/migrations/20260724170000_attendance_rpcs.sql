-- 1. Revert attendance_sessions policy to protect secret_word
drop policy if exists "Anyone can read attendance sessions for their events" on public.attendance_sessions;
create policy "Professors can read attendance sessions"
  on public.attendance_sessions for select
  using (public.is_event_professor(event_id));

-- 2. Create RPC for admin to get sessions with count
create or replace function public.admin_get_sessions(p_event_id uuid)
returns table (
  id uuid,
  session_date date,
  secret_word text,
  created_at timestamptz,
  records_count bigint
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_event_professor(p_event_id) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  return query
  select 
    s.id,
    s.session_date,
    s.secret_word,
    s.created_at,
    (select count(*) from public.attendance_records r where r.session_id = s.id) as records_count
  from public.attendance_sessions s
  where s.event_id = p_event_id
  order by s.session_date desc;
end;
$$;

revoke all on function public.admin_get_sessions(uuid) from public, anon, authenticated, service_role;
grant execute on function public.admin_get_sessions(uuid) to authenticated;

-- 3. Create RPC for student to get sessions
create or replace function public.student_get_sessions(p_event_id uuid)
returns table (
  id uuid,
  session_date date,
  checked_in_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  caller_member_id uuid;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  select tm.id into caller_member_id
  from public.team_members tm
  where tm.event_id = p_event_id
    and tm.user_id = caller_id
    and tm.status = 'active'
  limit 1;

  if not found then
    raise exception using errcode = 'P0001', message = 'not_a_participant';
  end if;

  return query
  select 
    s.id,
    s.session_date,
    r.checked_in_at
  from public.attendance_sessions s
  left join public.attendance_records r on r.session_id = s.id and r.member_id = caller_member_id
  where s.event_id = p_event_id
  order by s.session_date desc;
end;
$$;

revoke all on function public.student_get_sessions(uuid) from public, anon, authenticated, service_role;
grant execute on function public.student_get_sessions(uuid) to authenticated;

-- 4. Update student_check_in to take p_session_id
create or replace function public.student_check_in(
  p_event_id uuid,
  p_session_id uuid,
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

  select * into target_session
  from public.attendance_sessions
  where id = p_session_id and event_id = p_event_id;

  if not found then
    raise exception using errcode = 'P0001', message = 'session_not_found';
  end if;

  if lower(btrim(target_session.secret_word)) <> lower(btrim(p_secret_word)) then
    raise exception using errcode = 'P0001', message = 'invalid_secret_word';
  end if;

  select tm.id into caller_member_id
  from public.team_members tm
  where tm.event_id = p_event_id
    and tm.user_id = caller_id
    and tm.status = 'active'
  limit 1;

  if not found then
    raise exception using errcode = 'P0001', message = 'not_a_participant';
  end if;

  if exists (
    select 1 from public.attendance_records
    where session_id = target_session.id
      and member_id = caller_member_id
  ) then
    raise exception using errcode = 'P0001', message = 'already_checked_in';
  end if;

  insert into public.attendance_records (session_id, member_id)
  values (target_session.id, caller_member_id)
  returning * into new_record;

  return new_record;
end;
$$;

revoke all on function public.student_check_in(uuid, uuid, text) from public, anon, authenticated, service_role;
grant execute on function public.student_check_in(uuid, uuid, text) to authenticated;
