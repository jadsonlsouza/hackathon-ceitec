-- Fix the original unpublish_category_results to use $1 and $2 to avoid ALL ambiguity
-- This ensures that any cached JS payload sending { event_id, category } works flawlessly.

drop function if exists public.unpublish_category_results(uuid, public.team_category);

create function public.unpublish_category_results(
  event_id   uuid,
  category   public.team_category
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id  uuid := (select auth.uid());
  event_state public.event_status;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  select ev.status
  into event_state
  from public.events as ev
  where ev.id = $1
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'event_not_found';
  end if;
  if event_state = 'archived' then
    raise exception using errcode = 'P0001', message = 'event_not_available';
  end if;
  if not private.current_event_professor($1, caller_id) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  delete from public.published_results as pub
  where pub.event_id = $1
    and pub.category = $2;

  -- If we just unpublished and event was fully published, revert status
  if event_state = 'results_published' then
    update public.events as ev
    set status = 'evaluation'
    where ev.id = $1;
  end if;

  insert into public.audit_log (
    event_id, actor_id, action, entity_type, entity_id, payload
  )
  values (
    $1,
    caller_id,
    'category_results_unpublished',
    'published_results',
    $2::text,
    jsonb_build_object('category', $2)
  );
end;
$$;
