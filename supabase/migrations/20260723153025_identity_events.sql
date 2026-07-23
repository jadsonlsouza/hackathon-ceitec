create type public.global_role as enum ('student', 'global_admin');
create type public.event_role as enum ('professor', 'monitor', 'evaluator');
create type public.request_status as enum ('pending', 'approved', 'rejected', 'revoked');
create type public.event_status as enum (
  'draft',
  'registration_open',
  'in_progress',
  'evaluation',
  'results_published',
  'archived'
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  display_name text not null default '',
  global_role public.global_role not null default 'student',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  status public.event_status not null default 'draft',
  is_featured boolean not null default false,
  starts_at timestamptz,
  ends_at timestamptz,
  professor_id uuid references public.profiles(id),
  archived_at timestamptz,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  check ((status = 'archived') = (archived_at is not null))
);

create unique index one_featured_event
  on public.events (is_featured)
  where is_featured;
create index events_professor_id_idx on public.events (professor_id);
create index events_created_by_idx on public.events (created_by);

create table public.event_roles (
  event_id uuid not null references public.events(id),
  user_id uuid not null references public.profiles(id),
  role public.event_role not null,
  categories text[] not null default '{}',
  approved_by uuid not null references public.profiles(id),
  approved_at timestamptz not null default now(),
  primary key (event_id, user_id, role)
);

create index event_roles_user_id_idx on public.event_roles (user_id);
create index event_roles_approved_by_idx on public.event_roles (approved_by);

create table public.role_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  event_id uuid not null references public.events(id),
  requested_role public.event_role not null,
  status public.request_status not null default 'pending',
  decided_by uuid references public.profiles(id),
  decided_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index one_open_role_request
  on public.role_requests (user_id, event_id, requested_role)
  where status = 'pending';
create index role_requests_user_id_idx on public.role_requests (user_id);
create index role_requests_event_id_idx on public.role_requests (event_id);
create index role_requests_decided_by_idx on public.role_requests (decided_by);

create table public.audit_log (
  id bigint generated always as identity primary key,
  event_id uuid not null references public.events(id),
  actor_id uuid references public.profiles(id),
  action text not null,
  entity_type text not null,
  entity_id text not null,
  payload jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create index audit_log_event_id_idx on public.audit_log (event_id);
create index audit_log_actor_id_idx on public.audit_log (actor_id);

create schema private;
revoke all on schema private from public, anon, authenticated, service_role;

create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  requested_role_text text := new.raw_user_meta_data ->> 'requested_role';
  requested_event_text text := new.raw_user_meta_data ->> 'event_id';
begin
  if caller_id is not null and caller_id <> new.id then
    raise exception 'signup_identity_mismatch';
  end if;

  insert into public.profiles (id, email, display_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', '')
  );

  -- Signup metadata is user-controlled. It can create only a pending request;
  -- authorization is derived from profiles and approved event roles.
  if requested_role_text in ('professor', 'monitor', 'evaluator')
    and requested_event_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  then
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
  end if;

  return new;
end;
$$;

revoke all on function private.handle_new_user() from public, anon, authenticated, service_role;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.handle_new_user();

create view private.current_global_access
with (security_barrier = true)
as
select
  (select auth.uid()) as user_id,
  exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and global_role = 'global_admin'
  ) as is_global_admin;

create view private.current_event_professorships
with (security_barrier = true)
as
select
  id as event_id,
  (select auth.uid()) as user_id
from public.events
where (select auth.uid()) is not null
  and professor_id = (select auth.uid());

revoke all on table
  private.current_global_access,
  private.current_event_professorships
from public, anon, authenticated, service_role;
grant usage on schema private to authenticated;
grant select on table
  private.current_global_access,
  private.current_event_professorships
to authenticated;

create function public.is_global_admin()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce(
    (
      select access.is_global_admin
      from private.current_global_access as access
      where access.user_id = (select auth.uid())
    ),
    false
  );
$$;

create function public.is_event_professor(target_event uuid)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from private.current_event_professorships as professorship
    where professorship.event_id = target_event
      and professorship.user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_global_admin() from public, anon, authenticated, service_role;
revoke all on function public.is_event_professor(uuid) from public, anon, authenticated, service_role;
grant execute on function public.is_global_admin() to authenticated;
grant execute on function public.is_event_professor(uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.events enable row level security;
alter table public.event_roles enable row level security;
alter table public.role_requests enable row level security;
alter table public.audit_log enable row level security;

create policy "profile self read"
on public.profiles
for select
to authenticated
using (
  id = (select auth.uid())
  or exists (
    select 1
    from private.current_global_access as access
    where access.user_id = (select auth.uid())
      and access.is_global_admin
  )
);

create policy "events visible to authenticated"
on public.events
for select
to authenticated
using (true);

create policy "global admins create events"
on public.events
for insert
to authenticated
with check (
  (select public.is_global_admin())
  and status <> 'archived'
);

create policy "global admins update events"
on public.events
for update
to authenticated
using (
  (select public.is_global_admin())
  and status <> 'archived'
)
with check (
  (select public.is_global_admin())
  and status <> 'archived'
);

create policy "roles visible to owner and admins"
on public.event_roles
for select
to authenticated
using (
  user_id = (select auth.uid())
  or (select public.is_global_admin())
  or (select public.is_event_professor(event_id))
);

create policy "requests created by owner"
on public.role_requests
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and status = 'pending'
  and decided_by is null
  and decided_at is null
  and exists (
    select 1
    from public.events as requested_event
    where requested_event.id = role_requests.event_id
      and requested_event.status <> 'archived'
  )
);

create policy "requests visible to decision makers"
on public.role_requests
for select
to authenticated
using (
  user_id = (select auth.uid())
  or (select public.is_global_admin())
  or (select public.is_event_professor(event_id))
);

create policy "audit visible to admins"
on public.audit_log
for select
to authenticated
using (
  (select public.is_global_admin())
  or (event_id is not null and (select public.is_event_professor(event_id)))
);

revoke all on table
  public.profiles,
  public.events,
  public.event_roles,
  public.role_requests,
  public.audit_log
from public, anon, authenticated, service_role;

grant select on table public.profiles to authenticated;
grant select, insert, update on table public.events to authenticated;
grant select on table public.event_roles to authenticated;
grant select, insert on table public.role_requests to authenticated;
grant select on table public.audit_log to authenticated;

revoke usage on type
  public.global_role,
  public.event_role,
  public.request_status,
  public.event_status
from public, anon, authenticated, service_role;

grant usage on type
  public.global_role,
  public.event_role,
  public.request_status,
  public.event_status
to authenticated;

alter default privileges for role postgres in schema public
  revoke select, insert, update, delete on tables from anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke usage, select on sequences from anon, authenticated, service_role;
