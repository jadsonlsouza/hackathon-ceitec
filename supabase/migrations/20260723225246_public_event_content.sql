create table public.event_public_content (
  event_id uuid primary key
    references public.events(id) on delete restrict,
  tagline text not null
    check (char_length(btrim(tagline)) between 2 and 180),
  presentation text not null
    check (char_length(btrim(presentation)) between 2 and 4000),
  objectives jsonb not null
    check (
      jsonb_typeof(objectives) = 'array'
      and jsonb_array_length(objectives) > 0
    ),
  venue text not null
    check (char_length(btrim(venue)) between 2 and 240),
  date_label text not null
    check (char_length(btrim(date_label)) between 2 and 120),
  registration_open boolean not null default false,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id)
);

create index event_public_content_updated_by_idx
  on public.event_public_content (updated_by);

create table public.event_schedule_items (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null
    references public.events(id) on delete restrict,
  day_number smallint not null check (day_number in (1, 2)),
  starts_at time not null,
  activity text not null
    check (char_length(btrim(activity)) between 2 and 180),
  position integer not null check (position > 0),
  unique (event_id, day_number, position)
);

create index event_schedule_items_event_order_idx
  on public.event_schedule_items (event_id, day_number, position);

alter table public.event_public_content enable row level security;
alter table public.event_schedule_items enable row level security;

revoke all on table
  public.event_public_content,
  public.event_schedule_items
from public, anon, authenticated, service_role;

create function private.validate_public_content_payload(content jsonb)
returns void
language plpgsql
immutable
security definer
set search_path = ''
as $$
declare
  objective jsonb;
  item jsonb;
  objective_positions integer := 0;
  day_one_count integer := 0;
  day_two_count integer := 0;
  distinct_positions integer;
begin
  if jsonb_typeof(content) <> 'object' then
    raise exception using errcode = 'P0001', message = 'invalid_content';
  end if;

  if jsonb_typeof(content -> 'registrationOpen') <> 'boolean' then
    raise exception using errcode = 'P0001', message = 'invalid_content';
  end if;

  if char_length(btrim(coalesce(content ->> 'tagline', ''))) not between 2 and 180
    or char_length(btrim(coalesce(content ->> 'presentation', ''))) not between 2 and 4000
    or char_length(btrim(coalesce(content ->> 'venue', ''))) not between 2 and 240
    or char_length(btrim(coalesce(content ->> 'dateLabel', ''))) not between 2 and 120
  then
    raise exception using errcode = 'P0001', message = 'invalid_content';
  end if;

  if jsonb_typeof(content -> 'objectives') <> 'array'
    or jsonb_array_length(content -> 'objectives') = 0
    or jsonb_array_length(content -> 'objectives') > 20
  then
    raise exception using errcode = 'P0001', message = 'invalid_objectives';
  end if;

  for objective in
    select value from jsonb_array_elements(content -> 'objectives')
  loop
    if jsonb_typeof(objective) <> 'string'
      or char_length(btrim(objective #>> '{}')) not between 2 and 240
    then
      raise exception using errcode = 'P0001', message = 'invalid_objectives';
    end if;
    objective_positions := objective_positions + 1;
  end loop;

  if jsonb_typeof(content -> 'schedule') <> 'array' then
    raise exception using errcode = 'P0001', message = 'invalid_schedule';
  end if;
  if jsonb_array_length(content -> 'schedule') > 100 then
    raise exception using errcode = 'P0001', message = 'invalid_schedule';
  end if;

  for item in
    select value from jsonb_array_elements(content -> 'schedule')
  loop
    if jsonb_typeof(item) <> 'object'
      or coalesce(item ->> 'dayNumber', '') not in ('1', '2')
      or coalesce(item ->> 'startsAt', '') !~ '^(?:[01][0-9]|2[0-3]):[0-5][0-9]$'
      or char_length(btrim(coalesce(item ->> 'activity', ''))) not between 2 and 180
      or coalesce(item ->> 'position', '') !~ '^[1-9][0-9]*$'
    then
      raise exception using errcode = 'P0001', message = 'invalid_schedule';
    end if;

    if (item ->> 'dayNumber')::integer = 1 then
      day_one_count := day_one_count + 1;
    else
      day_two_count := day_two_count + 1;
    end if;
  end loop;

  if day_one_count = 0 or day_two_count = 0 then
    raise exception using errcode = 'P0001', message = 'schedule_days_required';
  end if;

  select count(distinct (
    (value ->> 'dayNumber')::integer,
    (value ->> 'position')::integer
  ))
  into distinct_positions
  from jsonb_array_elements(content -> 'schedule');

  if distinct_positions <> day_one_count + day_two_count then
    raise exception using errcode = 'P0001', message = 'duplicate_schedule_position';
  end if;
end;
$$;

create function public.get_featured_event_content()
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
  where event.is_featured
    and event.status <> 'archived'
    and event.archived_at is null
  limit 1;
$$;

create function public.get_event_public_content_for_edit(target_event uuid)
returns table (
  tagline text,
  presentation text,
  objectives jsonb,
  venue text,
  date_label text,
  registration_open boolean,
  schedule jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.assert_current_professor($1);

  return query
  select
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
        where item.event_id = $1
      ),
      '[]'::jsonb
    )
  from public.event_public_content as content
  where content.event_id = $1;
end;
$$;

create function public.save_event_public_content(
  target_event uuid,
  content jsonb
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
begin
  perform private.assert_current_professor($1);
  perform private.validate_public_content_payload($2);

  insert into public.event_public_content (
    event_id,
    tagline,
    presentation,
    objectives,
    venue,
    date_label,
    registration_open,
    updated_at,
    updated_by
  )
  values (
    $1,
    btrim($2 ->> 'tagline'),
    btrim($2 ->> 'presentation'),
    (
      select jsonb_agg(to_jsonb(btrim(value #>> '{}')) order by ordinal)
      from jsonb_array_elements($2 -> 'objectives')
        with ordinality as objective(value, ordinal)
    ),
    btrim($2 ->> 'venue'),
    btrim($2 ->> 'dateLabel'),
    ($2 ->> 'registrationOpen')::boolean,
    now(),
    caller_id
  )
  on conflict (event_id) do update
  set
    tagline = excluded.tagline,
    presentation = excluded.presentation,
    objectives = excluded.objectives,
    venue = excluded.venue,
    date_label = excluded.date_label,
    registration_open = excluded.registration_open,
    updated_at = excluded.updated_at,
    updated_by = excluded.updated_by;

  delete from public.event_schedule_items as item
  where item.event_id = $1;

  insert into public.event_schedule_items (
    event_id,
    day_number,
    starts_at,
    activity,
    position
  )
  select
    $1,
    (item ->> 'dayNumber')::smallint,
    (item ->> 'startsAt')::time,
    btrim(item ->> 'activity'),
    (item ->> 'position')::integer
  from jsonb_array_elements($2 -> 'schedule') as schedule(item);

  insert into public.audit_log (
    event_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    payload
  )
  values (
    $1,
    caller_id,
    'event_public_content_saved',
    'event_public_content',
    $1::text,
    jsonb_build_object(
      'objective_count', jsonb_array_length($2 -> 'objectives'),
      'schedule_item_count', jsonb_array_length($2 -> 'schedule'),
      'registration_open', ($2 ->> 'registrationOpen')::boolean
    )
  );
end;
$$;

revoke all on function
  private.validate_public_content_payload(jsonb),
  public.get_featured_event_content(),
  public.get_event_public_content_for_edit(uuid),
  public.save_event_public_content(uuid, jsonb)
from public, anon, authenticated, service_role;

grant execute on function public.get_featured_event_content()
to anon, authenticated;

grant execute on function
  public.get_event_public_content_for_edit(uuid),
  public.save_event_public_content(uuid, jsonb)
to authenticated;

comment on function public.get_featured_event_content() is
  'Returns only intentionally featured non-archived public landing content.';
comment on function public.save_event_public_content(uuid, jsonb) is
  'Atomically validates, replaces, and audits one current Professor event landing.';
