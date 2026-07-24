create policy "teams visible to evaluators"
on public.teams
for select
to authenticated
using (
  exists (
    select 1
    from public.evaluator_assignments as assignment
    where assignment.event_id = teams.event_id
      and assignment.category = teams.category
      and assignment.evaluator_id = (select auth.uid())
  )
);
