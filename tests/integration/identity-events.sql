begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;

select plan(27);

select is(
  (
    select count(*)::integer
    from pg_class as relation
    join pg_namespace as namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname in (
        'profiles',
        'events',
        'event_roles',
        'role_requests',
        'audit_log'
      )
      and relation.relrowsecurity
  ),
  5,
  'RLS is enabled on every public application table'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'private.handle_new_user()',
    'execute'
  ),
  'authenticated cannot execute the privileged signup trigger directly'
);

select ok(
  not has_function_privilege('anon', 'private.handle_new_user()', 'execute'),
  'anon cannot execute the privileged signup trigger directly'
);

select is(
  (
    select count(*)::integer
    from pg_proc as function
    join pg_namespace as namespace on namespace.oid = function.pronamespace
    where namespace.nspname = 'public'
      and function.proname in ('is_global_admin', 'is_event_professor')
      and not function.prosecdef
  ),
  2,
  'public authorization helpers are security invoker functions'
);

insert into auth.users (id, email, raw_user_meta_data)
values (
  '00000000-0000-4000-8000-000000000001',
  'admin@example.test',
  '{"full_name":"Global Admin"}'::jsonb
);

update public.profiles
set global_role = 'global_admin'
where id = '00000000-0000-4000-8000-000000000001';

insert into auth.users (id, email, raw_user_meta_data)
values (
  '00000000-0000-4000-8000-000000000002',
  'professor@example.test',
  '{"full_name":"Event Professor"}'::jsonb
);

insert into public.events (
  id,
  name,
  slug,
  professor_id,
  created_by
)
values (
  '10000000-0000-4000-8000-000000000001',
  'Primary Event',
  'primary-event',
  '00000000-0000-4000-8000-000000000002',
  '00000000-0000-4000-8000-000000000001'
);

insert into public.event_roles (
  event_id,
  user_id,
  role,
  approved_by
)
values (
  '10000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000002',
  'professor',
  '00000000-0000-4000-8000-000000000001'
);

insert into auth.users (id, email, raw_user_meta_data)
values (
  '00000000-0000-4000-8000-000000000003',
  'applicant@example.test',
  '{
    "full_name":"Pending Applicant",
    "requested_role":"monitor",
    "event_id":"10000000-0000-4000-8000-000000000001"
  }'::jsonb
);

insert into auth.users (id, email, raw_user_meta_data)
values (
  '00000000-0000-4000-8000-000000000004',
  'outsider@example.test',
  '{
    "full_name":"Untrusted Metadata",
    "requested_role":"professor",
    "event_id":"not-a-valid-uuid"
  }'::jsonb
);

insert into public.audit_log (
  event_id,
  actor_id,
  action,
  entity_type,
  entity_id
)
values (
  '10000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000001',
  'event_created',
  'event',
  '10000000-0000-4000-8000-000000000001'
);

select is(
  (
    select display_name
    from public.profiles
    where id = '00000000-0000-4000-8000-000000000003'
  ),
  'Pending Applicant',
  'signup creates the applicant profile'
);

select is(
  (
    select global_role::text
    from public.profiles
    where id = '00000000-0000-4000-8000-000000000003'
  ),
  'student',
  'signup metadata cannot grant a global role'
);

select is(
  (
    select count(*)::integer
    from public.role_requests
    where user_id = '00000000-0000-4000-8000-000000000003'
      and status = 'pending'
  ),
  1,
  'valid signup metadata creates one pending role request'
);

select is(
  (
    select count(*)::integer
    from public.event_roles
    where user_id = '00000000-0000-4000-8000-000000000003'
  ),
  0,
  'signup metadata never creates an authorized event role'
);

select is(
  (
    select count(*)::integer
    from public.role_requests
    where user_id = '00000000-0000-4000-8000-000000000004'
  ),
  0,
  'invalid signup metadata is ignored without granting access'
);

select ok(
  not has_table_privilege('anon', 'public.profiles', 'select'),
  'anon has no profile table access'
);

select ok(
  has_table_privilege('authenticated', 'public.role_requests', 'insert'),
  'authenticated can submit role requests'
);

select ok(
  not has_table_privilege('authenticated', 'public.role_requests', 'update'),
  'authenticated cannot update role request decisions directly'
);

select ok(
  not has_table_privilege('authenticated', 'public.event_roles', 'insert'),
  'authenticated cannot grant event roles directly'
);

select ok(
  has_table_privilege('authenticated', 'public.events', 'update'),
  'authenticated has policy-gated event update access'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000003',
  true
);

select is(
  (select count(*)::integer from public.profiles),
  1,
  'applicant can read only their own profile'
);

select is(
  (select count(*)::integer from public.role_requests),
  1,
  'applicant can read their own pending request'
);

select is(
  (select count(*)::integer from public.audit_log),
  0,
  'applicant cannot read event audit records'
);

select is(
  public.is_global_admin(),
  false,
  'applicant is not a global admin'
);

select is(
  public.is_event_professor('10000000-0000-4000-8000-000000000001'),
  false,
  'applicant is not the event professor'
);

select throws_ok(
  $$
    insert into public.role_requests (
      user_id,
      event_id,
      requested_role
    )
    values (
      '00000000-0000-4000-8000-000000000004',
      '10000000-0000-4000-8000-000000000001',
      'evaluator'
    )
  $$,
  '42501',
  'new row violates row-level security policy for table "role_requests"',
  'applicant cannot submit a request for another user'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000002',
  true
);

select is(
  public.is_event_professor('10000000-0000-4000-8000-000000000001'),
  true,
  'assigned professor is recognized for the event'
);

select is(
  (select count(*)::integer from public.role_requests),
  1,
  'event professor can read requests for their event'
);

select is(
  (select count(*)::integer from public.audit_log),
  1,
  'event professor can read audit records for their event'
);

select is(
  (select count(*)::integer from public.profiles),
  1,
  'event professor cannot read unrelated profiles'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000001',
  true
);

select is(
  public.is_global_admin(),
  true,
  'approved global admin is recognized'
);

select is(
  (select count(*)::integer from public.profiles),
  4,
  'global admin can read all profiles'
);

select lives_ok(
  $$
    insert into public.events (id, name, slug, created_by)
    values (
      '10000000-0000-4000-8000-000000000002',
      'Admin Event',
      'admin-event',
      '00000000-0000-4000-8000-000000000001'
    )
  $$,
  'global admin can create an event'
);

reset role;

select * from finish();
rollback;
