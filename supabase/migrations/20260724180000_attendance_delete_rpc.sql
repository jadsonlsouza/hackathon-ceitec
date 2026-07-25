create or replace function public.admin_delete_attendance_session(p_session_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event_id uuid;
begin
  -- Get the event_id for this session to verify permissions
  select event_id into v_event_id
  from public.attendance_sessions
  where id = p_session_id;

  if not found then
    raise exception using errcode = 'P0001', message = 'session_not_found';
  end if;

  if not public.is_event_professor(v_event_id) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  delete from public.attendance_sessions
  where id = p_session_id;
end;
$$;

revoke all on function public.admin_delete_attendance_session(uuid) from public, anon, authenticated, service_role;
grant execute on function public.admin_delete_attendance_session(uuid) to authenticated;
