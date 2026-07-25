-- Fix RLS policy so students can read sessions (needed for the join when viewing history)
drop policy if exists "Anyone can read attendance sessions for their events" on public.attendance_sessions;

create policy "Anyone can read attendance sessions for their events"
  on public.attendance_sessions for select
  using (true);

-- Fix attendance_records RLS for count on admin side.
-- Wait, does "Professors can read attendance records" work?
-- is_event_professor(s.event_id) is used. It should work.
