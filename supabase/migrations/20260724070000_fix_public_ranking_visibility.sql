-- 1. Fix get_published_results to show published categories even if the whole event
--    isn't marked as 'results_published' yet (e.g. if only one category is published).

create or replace function public.get_published_results(event_slug text)
returns table (
  event_name text,
  event_slug text,
  category public.team_category,
  ranking jsonb,
  published_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    ev.name as event_name,
    ev.slug as event_slug,
    pr.category,
    pr.ranking,
    pr.published_at
  from public.published_results as pr
  join public.events as ev
    on ev.id = pr.event_id
  where ev.slug = $1
  order by pr.category;
$$;


-- 2. Revert unpublish_category_results parameters to event_id and category
--    so that old frontend JS payloads (without hard refresh) still work,
--    and use function name prefix to avoid PL/pgSQL ambiguity.

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
  where ev.id = unpublish_category_results.event_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'event_not_found';
  end if;
  if event_state = 'archived' then
    raise exception using errcode = 'P0001', message = 'event_not_available';
  end if;
  if not private.current_event_professor(unpublish_category_results.event_id, caller_id) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  delete from public.published_results as pub
  where pub.event_id = unpublish_category_results.event_id
    and pub.category = unpublish_category_results.category;

  -- If we just unpublished and event was fully published, revert status
  if event_state = 'results_published' then
    update public.events as ev
    set status = 'evaluation'
    where ev.id = unpublish_category_results.event_id;
  end if;

  insert into public.audit_log (
    event_id, actor_id, action, entity_type, entity_id, payload
  )
  values (
    unpublish_category_results.event_id,
    caller_id,
    'category_results_unpublished',
    'published_results',
    unpublish_category_results.category::text,
    jsonb_build_object('category', unpublish_category_results.category)
  );
end;
$$;

grant execute on function public.unpublish_category_results(uuid, public.team_category)
  to authenticated;

comment on function public.unpublish_category_results(uuid, public.team_category) is
  'Allows the event professor to retract a published category result.';
