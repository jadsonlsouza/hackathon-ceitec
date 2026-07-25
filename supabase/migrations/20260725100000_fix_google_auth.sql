create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested_role_text text := coalesce(new.raw_user_meta_data ->> 'requested_role', '');
  requested_event_text text := coalesce(new.raw_user_meta_data ->> 'event_id', '');
begin
  -- 1. Safely insert profile
  insert into public.profiles (id, email, display_name)
  values (
    new.id,
    coalesce(new.email, new.id::text || '@no-email.invalid'),
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', '')
  )
  on conflict (id) do update set
    email = excluded.email,
    display_name = excluded.display_name;

  -- 2. Link existing team members safely and satisfy constraint
  if new.email is not null then
    update public.team_members
    set 
      user_id = new.id,
      status = case when status = 'invited' then 'active'::public.member_status else status end,
      approved_by = case when status = 'invited' then (select leader_id from public.teams where id = team_members.team_id) else approved_by end
    where lower(btrim(email)) = lower(btrim(new.email))
      and user_id is null;
  end if;

  -- 3. Handle role requests
  if requested_role_text in ('professor', 'monitor', 'evaluator')
    and requested_event_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  then
    begin
      insert into public.role_requests (
        user_id,
        event_id,
        requested_role,
        status
      )
      select
        new.id,
        event.id,
        requested_role_text::public.event_role,
        'pending'::public.request_status
      from public.events as event
      where event.id = requested_event_text::uuid
        and event.status <> 'archived'
      on conflict (user_id, event_id, requested_role)
        where status = 'pending'
        do nothing;
    exception when others then
      -- ignore errors in role requests to prevent blocking signup
      null;
    end;
  end if;

  return new;
end;
$$;
