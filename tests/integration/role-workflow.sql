begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;

select plan(35);

select has_function(
  'public',
  'request_role',
  array['event_role', 'uuid'],
  'role request RPC exists'
);

select has_function(
  'public',
  'decide_role_request',
  array['uuid', 'request_status'],
  'decision RPC exists'
);

select col_is_pk(
  'public',
  'event_roles',
  array['event_id', 'user_id', 'role'],
  'event role key is stable'
);

select is(
  (
    select count(*)::integer
    from pg_proc as function
    join pg_namespace as namespace on namespace.oid = function.pronamespace
    where namespace.nspname = 'public'
      and function.proname in ('request_role', 'decide_role_request')
      and not function.prosecdef
  ),
  2,
  'public RPC wrappers are security invoker functions'
);

select is(
  (
    select count(*)::integer
    from pg_proc as function
    join pg_namespace as namespace on namespace.oid = function.pronamespace
    where namespace.nspname = 'private'
      and function.proname in ('request_role_impl', 'decide_role_request_impl')
      and function.prosecdef
      and function.proconfig @> array['search_path=""']
  ),
  2,
  'privileged implementations are private with an empty search path'
);

select ok(
  not has_function_privilege(
    'anon',
    'private.request_role_impl(event_role,uuid)',
    'execute'
  ),
  'anon cannot execute the private role-request implementation'
);

select ok(
  not has_function_privilege(
    'anon',
    'private.decide_role_request_impl(uuid,request_status)',
    'execute'
  ),
  'anon cannot execute the private decision implementation'
);

select ok(
  has_function_privilege(
    'authenticated',
    'private.request_role_impl(event_role,uuid)',
    'execute'
  ),
  'authenticated may reach the request implementation through its wrapper'
);

select ok(
  has_function_privilege(
    'authenticated',
    'private.decide_role_request_impl(uuid,request_status)',
    'execute'
  ),
  'authenticated may reach the decision implementation through its wrapper'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.request_role(event_role,uuid)',
    'execute'
  ),
  'anon cannot call the public role-request RPC'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.request_role(event_role,uuid)',
    'execute'
  ),
  'authenticated can call the public role-request RPC'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.decide_role_request(uuid,request_status)',
    'execute'
  ),
  'authenticated can call the public decision RPC'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '00000000-0000-4000-8000-000000000001',
    'admin@example.test',
    '{"full_name":"Global Admin"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000002',
    'professor@example.test',
    '{"full_name":"Event Professor"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000003',
    'monitor@example.test',
    '{"full_name":"Monitor Applicant"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000004',
    'professor-applicant@example.test',
    '{"full_name":"Professor Applicant"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000005',
    'outsider@example.test',
    '{"full_name":"Outsider"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000006',
    'evaluator@example.test',
    '{"full_name":"Evaluator Applicant"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000007',
    'rejected@example.test',
    '{"full_name":"Rejected Applicant"}'::jsonb
  );

update public.profiles
set global_role = 'global_admin'
where id = '00000000-0000-4000-8000-000000000001';

insert into public.events (
  id,
  name,
  slug,
  professor_id,
  created_by
)
values
  (
    '10000000-0000-4000-8000-000000000001',
    'Active Event',
    'active-event',
    '00000000-0000-4000-8000-000000000002',
    '00000000-0000-4000-8000-000000000001'
  ),
  (
    '10000000-0000-4000-8000-000000000002',
    'Second Event',
    'second-event',
    '00000000-0000-4000-8000-000000000002',
    '00000000-0000-4000-8000-000000000001'
  );

insert into public.events (
  id,
  name,
  slug,
  status,
  archived_at,
  created_by
)
values (
  '10000000-0000-4000-8000-000000000003',
  'Archived Event',
  'archived-event',
  'archived',
  now(),
  '00000000-0000-4000-8000-000000000001'
);

insert into public.role_requests (
  id,
  user_id,
  event_id,
  requested_role
)
values (
  '20000000-0000-4000-8000-000000000003',
  '00000000-0000-4000-8000-000000000006',
  '10000000-0000-4000-8000-000000000003',
  'professor'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000003',
  true
);

select is(
  (
    select (public.request_role(
      'monitor',
      '10000000-0000-4000-8000-000000000001'
    )).status::text
  ),
  'pending',
  'an authenticated user can create a pending request'
);

select is(
  (
    select count(*)::integer
    from public.role_requests
    where user_id = '00000000-0000-4000-8000-000000000003'
      and requested_role = 'monitor'
  ),
  1,
  'the request RPC binds the request to the caller'
);

select throws_ok(
  $$select public.request_role('monitor', null)$$,
  'P0001',
  'event_required',
  'a role request requires an event'
);

select throws_ok(
  $$
    select public.request_role(
      'monitor',
      '10000000-0000-4000-8000-000000000003'
    )
  $$,
  'P0001',
  'event_not_available',
  'an archived event rejects new role requests'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000004',
  true
);

select is(
  (
    select (public.request_role(
      'professor',
      '10000000-0000-4000-8000-000000000001'
    )).status::text
  ),
  'pending',
  'a professor request starts pending'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000006',
  true
);

select is(
  (
    select (public.request_role(
      'evaluator',
      '10000000-0000-4000-8000-000000000001'
    )).status::text
  ),
  'pending',
  'an evaluator request starts pending'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000007',
  true
);

select is(
  (
    select (public.request_role(
      'evaluator',
      '10000000-0000-4000-8000-000000000002'
    )).status::text
  ),
  'pending',
  'a request to be rejected starts pending'
);

reset role;

update public.role_requests
set id = '20000000-0000-4000-8000-000000000001'
where user_id = '00000000-0000-4000-8000-000000000003'
  and event_id = '10000000-0000-4000-8000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000005',
  true
);

select throws_ok(
  $$
    select public.decide_role_request(
      '20000000-0000-4000-8000-000000000001',
      'approved'
    )
  $$,
  'P0001',
  'forbidden',
  'an unrelated user cannot approve an event request'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000002',
  true
);

select is(
  (
    select count(*)::integer
    from public.profiles
    where id = '00000000-0000-4000-8000-000000000003'
  ),
  1,
  'an event professor can read the pending applicant profile'
);

select is(
  (
    select (public.decide_role_request(
      (
        select id
        from public.role_requests
        where user_id = '00000000-0000-4000-8000-000000000003'
      ),
      'approved'
    )).status::text
  ),
  'approved',
  'the event professor can approve a monitor request'
);

select is(
  (
    select count(*)::integer
    from public.event_roles
    where event_id = '10000000-0000-4000-8000-000000000001'
      and user_id = '00000000-0000-4000-8000-000000000003'
      and role = 'monitor'
  ),
  1,
  'approval grants the requested event role'
);

select is(
  (
    select count(*)::integer
    from public.audit_log
    where event_id = '10000000-0000-4000-8000-000000000001'
      and actor_id = '00000000-0000-4000-8000-000000000002'
      and action = 'role_request_approved'
  ),
  1,
  'approval writes an event-bound audit record'
);

select throws_ok(
  $$
    select public.decide_role_request(
      (
        select id
        from public.role_requests
        where user_id = '00000000-0000-4000-8000-000000000003'
      ),
      'approved'
    )
  $$,
  'P0001',
  'request_not_pending',
  'a decided request cannot be decided again'
);

select throws_ok(
  $$
    select public.decide_role_request(
      (
        select id
        from public.role_requests
        where user_id = '00000000-0000-4000-8000-000000000004'
      ),
      'approved'
    )
  $$,
  'P0001',
  'forbidden',
  'an event professor cannot approve another professor'
);

select throws_ok(
  $$
    select public.decide_role_request(
      (
        select id
        from public.role_requests
        where user_id = '00000000-0000-4000-8000-000000000006'
          and event_id = '10000000-0000-4000-8000-000000000001'
      ),
      'revoked'
    )
  $$,
  'P0001',
  'invalid_decision',
  'the decision RPC accepts only approval or rejection'
);

select is(
  (
    select (public.decide_role_request(
      (
        select id
        from public.role_requests
        where user_id = '00000000-0000-4000-8000-000000000007'
      ),
      'rejected'
    )).status::text
  ),
  'rejected',
  'the event professor can reject an event request'
);

select is(
  (
    select count(*)::integer
    from public.event_roles
    where event_id = '10000000-0000-4000-8000-000000000002'
      and user_id = '00000000-0000-4000-8000-000000000007'
  ),
  0,
  'rejection does not grant an event role'
);

select is(
  (
    select count(*)::integer
    from public.audit_log
    where event_id = '10000000-0000-4000-8000-000000000002'
      and action = 'role_request_rejected'
  ),
  1,
  'rejection writes an event-bound audit record'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000001',
  true
);

select is(
  (
    select (public.decide_role_request(
      (
        select id
        from public.role_requests
        where user_id = '00000000-0000-4000-8000-000000000004'
      ),
      'approved'
    )).status::text
  ),
  'approved',
  'a global admin can approve a professor request'
);

select is(
  (
    select professor_id::text
    from public.events
    where id = '10000000-0000-4000-8000-000000000001'
  ),
  '00000000-0000-4000-8000-000000000004',
  'professor approval assigns the event professor'
);

select is(
  (
    select count(*)::integer
    from public.event_roles
    where event_id = '10000000-0000-4000-8000-000000000001'
      and user_id = '00000000-0000-4000-8000-000000000004'
      and role = 'professor'
  ),
  1,
  'professor approval creates the professor event role'
);

select is(
  (
    select count(*)::integer
    from public.audit_log
    where event_id = '10000000-0000-4000-8000-000000000001'
      and actor_id = '00000000-0000-4000-8000-000000000001'
      and action = 'role_request_approved'
  ),
  1,
  'professor approval is recorded in the event audit'
);

select throws_ok(
  $$
    select public.decide_role_request(
      '20000000-0000-4000-8000-000000000003',
      'approved'
    )
  $$,
  'P0001',
  'event_not_available',
  'pending requests for archived events are immutable'
);

reset role;

select * from finish();
rollback;
