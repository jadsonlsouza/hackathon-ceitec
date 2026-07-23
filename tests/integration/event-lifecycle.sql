begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;

select plan(37);

select has_function(
  'public',
  'archive_and_create_event',
  array['uuid', 'text', 'uuid'],
  'server archive RPC exists'
);

select has_function(
  'private',
  'archive_and_create_event_impl',
  array['uuid', 'text', 'uuid'],
  'privileged archive implementation is private'
);

select is(
  (
    select function.prosecdef
    from pg_proc as function
    join pg_namespace as namespace on namespace.oid = function.pronamespace
    where namespace.nspname = 'public'
      and function.proname = 'archive_and_create_event'
  ),
  false,
  'the public wrapper is security invoker'
);

select is(
  (
    select function.prosecdef
      and function.proconfig @> array['search_path=""']
    from pg_proc as function
    join pg_namespace as namespace on namespace.oid = function.pronamespace
    where namespace.nspname = 'private'
      and function.proname = 'archive_and_create_event_impl'
  ),
  true,
  'the private implementation is security definer with an empty search path'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.archive_and_create_event(uuid,text,uuid)',
    'execute'
  ),
  'anon cannot execute the server archive RPC'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.archive_and_create_event(uuid,text,uuid)',
    'execute'
  ),
  'authenticated cannot execute the server archive RPC'
);

select ok(
  has_function_privilege(
    'service_role',
    'public.archive_and_create_event(uuid,text,uuid)',
    'execute'
  ),
  'only the server service role can execute the public archive RPC'
);

select ok(
  not has_function_privilege(
    'anon',
    'private.archive_and_create_event_impl(uuid,text,uuid)',
    'execute'
  ),
  'anon cannot execute the private archive implementation'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'private.archive_and_create_event_impl(uuid,text,uuid)',
    'execute'
  ),
  'authenticated cannot execute the private archive implementation'
);

select ok(
  not has_function_privilege(
    'service_role',
    'private.archive_and_create_event_impl(uuid,text,uuid)',
    'execute'
  ),
  'service_role must use the public wrapper instead of the private implementation'
);

select ok(
  not has_table_privilege('authenticated', 'public.events', 'delete'),
  'authenticated has no event delete privilege'
);

select col_has_check(
  'public',
  'events',
  'name',
  'event names have a database check constraint'
);

select ok(
  has_column_privilege('service_role', 'public.profiles', 'id', 'select'),
  'service_role can filter the server authorization lookup by profile id'
);

select ok(
  has_column_privilege(
    'service_role',
    'public.profiles',
    'global_role',
    'select'
  ),
  'service_role can read only the role needed by the endpoint'
);

select ok(
  not has_column_privilege(
    'service_role',
    'public.profiles',
    'email',
    'select'
  ),
  'server authorization lookup cannot read profile e-mail'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '00000000-0000-4000-8000-000000000001',
    'admin-lifecycle@example.test',
    '{"full_name":"Lifecycle Admin"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000002',
    'student-lifecycle@example.test',
    '{"full_name":"Lifecycle Student"}'::jsonb
  );

update public.profiles
set global_role = 'global_admin'
where id = '00000000-0000-4000-8000-000000000001';

select throws_ok(
  $$
    insert into public.events (name, slug, created_by)
    values (
      '   ',
      'whitespace-event-name',
      '00000000-0000-4000-8000-000000000001'
    )
  $$,
  '23514',
  null,
  'the database rejects whitespace-only event names'
);

set local role service_role;
select is(
  (
    select global_role::text
    from public.profiles
    where id = '00000000-0000-4000-8000-000000000001'
  ),
  'global_admin',
  'the endpoint authorization query works with real service-role privileges'
);
reset role;

insert into public.events (
  id,
  name,
  slug,
  is_featured,
  created_by
)
values
  (
    '10000000-0000-4000-8000-000000000001',
    'Featured Lifecycle Event',
    'featured-lifecycle-event',
    true,
    '00000000-0000-4000-8000-000000000001'
  ),
  (
    '10000000-0000-4000-8000-000000000002',
    'Rollback Lifecycle Event',
    'rollback-lifecycle-event',
    false,
    '00000000-0000-4000-8000-000000000001'
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000001',
  true
);
select throws_ok(
  $$
    update public.events
    set
      status = 'archived',
      archived_at = now(),
      is_featured = false
    where id = '10000000-0000-4000-8000-000000000001'
  $$,
  '42501',
  'new row violates row-level security policy for table "events"',
  'an authenticated global admin cannot archive an event directly'
);
reset role;

set local role anon;
select throws_ok(
  $$
    select public.archive_and_create_event(
      '10000000-0000-4000-8000-000000000001',
      'Featured Lifecycle Event',
      '00000000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'permission denied for function archive_and_create_event',
  'anon direct RPC execution is denied'
);

reset role;
set local role authenticated;
select throws_ok(
  $$
    select public.archive_and_create_event(
      '10000000-0000-4000-8000-000000000001',
      'Featured Lifecycle Event',
      '00000000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'permission denied for function archive_and_create_event',
  'authenticated direct RPC execution is denied'
);

reset role;
set local role service_role;
select throws_ok(
  $$
    select public.archive_and_create_event(
      '10000000-0000-4000-8000-000000000001',
      'Featured Lifecycle Event',
      '00000000-0000-4000-8000-000000000002'
    )
  $$,
  'P0001',
  'forbidden',
  'the transaction rejects a non-admin actor'
);

select throws_ok(
  $$
    select public.archive_and_create_event(
      '10000000-0000-4000-8000-000000000001',
      'Wrong exact name',
      '00000000-0000-4000-8000-000000000001'
    )
  $$,
  'P0001',
  'event_name_mismatch',
  'the transaction requires the exact event name'
);

reset role;
select is(
  (
    select status::text
    from public.events
    where id = '10000000-0000-4000-8000-000000000001'
  ),
  'draft',
  'failed authorization and name checks leave the event active'
);

set local role service_role;
select throws_ok(
  $$
    select public.archive_and_create_event(
      '10000000-0000-4000-8000-000000000002',
      'Rollback Lifecycle Event',
      '00000000-0000-4000-8000-000000000001'
    )
  $$,
  'P0001',
  'event_not_featured',
  'only the current featured event can be archived'
);

reset role;
select is(
  (
    select status::text
    from public.events
    where id = '10000000-0000-4000-8000-000000000002'
  ),
  'draft',
  'a rejected non-featured event remains active'
);

select is(
  (
    select count(*)::integer
    from public.audit_log
    where event_id = '10000000-0000-4000-8000-000000000002'
      and action = 'event_archived'
  ),
  0,
  'a rejected non-featured event writes no audit record'
);

create function pg_temp.reject_archive_audit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using errcode = 'P0001', message = 'forced_audit_failure';
end;
$$;

create trigger reject_archive_audit
before insert on public.audit_log
for each row
when (new.action = 'event_archived')
execute function pg_temp.reject_archive_audit();

set local role service_role;
select throws_ok(
  $$
    select public.archive_and_create_event(
      '10000000-0000-4000-8000-000000000001',
      'Featured Lifecycle Event',
      '00000000-0000-4000-8000-000000000001'
    )
  $$,
  'P0001',
  'forced_audit_failure',
  'a failure after both event mutations aborts the whole transaction'
);

reset role;
select is(
  (
    select status::text
    from public.events
    where id = '10000000-0000-4000-8000-000000000001'
  ),
  'draft',
  'the archive update rolls back when audit insertion fails'
);

select is(
  (select count(*)::integer from public.events),
  2,
  'the replacement event creation also rolls back on audit failure'
);

select is(
  (
    select count(*)::integer
    from public.audit_log
    where event_id = '10000000-0000-4000-8000-000000000001'
      and action = 'event_archived'
  ),
  0,
  'the failed archive leaves no partial audit record'
);

drop trigger reject_archive_audit on public.audit_log;

set local role service_role;
create temporary table lifecycle_result (
  archived_event_id uuid,
  new_event_id uuid
) on commit drop;

insert into lifecycle_result
select *
from public.archive_and_create_event(
  '10000000-0000-4000-8000-000000000001',
  'Featured Lifecycle Event',
  '00000000-0000-4000-8000-000000000001'
);

reset role;
select is(
  (select archived_event_id from lifecycle_result),
  '10000000-0000-4000-8000-000000000001'::uuid,
  'success returns the archived event id'
);

select is(
  (
    select status::text
    from public.events
    where id = '10000000-0000-4000-8000-000000000001'
  ),
  'archived',
  'success archives the selected event'
);

select ok(
  (
    select archived_at is not null and not is_featured
    from public.events
    where id = '10000000-0000-4000-8000-000000000001'
  ),
  'the archived event is timestamped and no longer featured'
);

select ok(
  (
    select event.status = 'draft'
      and event.is_featured
      and event.created_by = '00000000-0000-4000-8000-000000000001'
    from public.events as event
    join lifecycle_result as result on result.new_event_id = event.id
  ),
  'success atomically creates a new featured draft owned by the actor'
);

select is(
  (
    select count(*)::integer
    from public.audit_log
    where event_id = '10000000-0000-4000-8000-000000000001'
      and action = 'event_archived'
      and actor_id = '00000000-0000-4000-8000-000000000001'
  ),
  1,
  'success records one archive audit entry'
);

select throws_ok(
  $$
    update public.events
    set name = 'Mutated archived event'
    where id = '10000000-0000-4000-8000-000000000001'
  $$,
  'P0001',
  'event_archived_immutable',
  'archived events remain immutable even to privileged database callers'
);

select throws_ok(
  $$
    delete from public.events
    where id = '10000000-0000-4000-8000-000000000001'
  $$,
  'P0001',
  'event_delete_forbidden',
  'events cannot be deleted'
);

select * from finish();
rollback;
