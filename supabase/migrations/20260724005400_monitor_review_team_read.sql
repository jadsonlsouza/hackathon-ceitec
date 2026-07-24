drop policy "teams visible to scoped participants" on public.teams;

create policy "teams visible to scoped participants and event monitors"
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
  or exists (
    select 1
    from public.event_roles as assignment
    where assignment.event_id = teams.event_id
      and assignment.user_id = (select auth.uid())
      and assignment.role = 'monitor'
  )
);

comment on policy "teams visible to scoped participants and event monitors"
on public.teams is
  'Lets assigned Monitors identify teams in their submission review queue without granting team writes or cross-event access.';
