create function public.get_public_event_catalog()
returns table (
  event_name text,
  event_slug text,
  tagline text,
  venue text,
  date_label text,
  registration_open boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    event.name,
    event.slug,
    content.tagline,
    content.venue,
    content.date_label,
    content.registration_open
  from public.events as event
  join public.event_public_content as content
    on content.event_id = event.id
  where event.status in (
    'registration_open'::public.event_status,
    'in_progress'::public.event_status,
    'evaluation'::public.event_status,
    'results_published'::public.event_status
  )
    and event.archived_at is null
  order by event.created_at desc, event.name;
$$;

create function public.get_public_event_content(requested_slug text)
returns table (
  event_name text,
  event_slug text,
  tagline text,
  presentation text,
  objectives jsonb,
  venue text,
  date_label text,
  registration_open boolean,
  schedule jsonb
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    event.name,
    event.slug,
    content.tagline,
    content.presentation,
    content.objectives,
    content.venue,
    content.date_label,
    content.registration_open,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'dayNumber', item.day_number,
            'startsAt', to_char(item.starts_at, 'HH24:MI'),
            'activity', item.activity,
            'position', item.position
          )
          order by item.day_number, item.position
        )
        from public.event_schedule_items as item
        where item.event_id = event.id
      ),
      '[]'::jsonb
    )
  from public.events as event
  join public.event_public_content as content
    on content.event_id = event.id
  where event.slug = requested_slug
    and event.status in (
      'registration_open'::public.event_status,
      'in_progress'::public.event_status,
      'evaluation'::public.event_status,
      'results_published'::public.event_status
    )
    and event.archived_at is null;
$$;

revoke all on function
  public.get_public_event_catalog(),
  public.get_public_event_content(text)
from public, anon, authenticated, service_role;

grant execute on function
  public.get_public_event_catalog(),
  public.get_public_event_content(text)
to anon, authenticated;

comment on function public.get_public_event_catalog() is
  'Returns only operational, non-archived events with explicitly saved public content.';

comment on function public.get_public_event_content(text) is
  'Returns one operational, non-archived event public page by slug without direct table grants.';
