-- Expose a minimal public view of the featured (active) event.
-- This function is accessible to unauthenticated (anon) callers via PostgREST
-- so that the onboarding page can display the event name and pass the event_id
-- to the role-request flow without requiring server-side admin credentials.

create or replace function public.get_featured_event()
returns table (
  id uuid,
  name text,
  slug text,
  status text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    e.id,
    e.name,
    e.slug,
    e.status::text
  from public.events as e
  where e.is_featured = true
    and e.status <> 'archived'
  limit 1;
$$;

revoke all on function public.get_featured_event() from public, authenticated, service_role;
grant execute on function public.get_featured_event() to anon, authenticated;
