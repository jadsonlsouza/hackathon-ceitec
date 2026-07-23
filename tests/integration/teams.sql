begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;

select plan(67);

select has_table('public', 'teams', 'teams table exists');
select has_table('public', 'team_members', 'team members table exists');

select has_function(
  'public',
  'create_team',
  array['uuid', 'text', 'team_category', 'jsonb'],
  'team creation RPC exists'
);
select has_function(
  'public',
  'request_team_join',
  array['uuid'],
  'join request RPC exists'
);
select has_function(
  'public',
  'decide_team_join',
  array['uuid', 'boolean'],
  'join decision RPC exists'
);
select has_function(
  'public',
  'decide_team',
  array['uuid', 'team_status'],
  'team decision RPC exists'
);

select is(
  (
    select count(*)::integer
    from pg_proc as function
    join pg_namespace as namespace on namespace.oid = function.pronamespace
    where namespace.nspname = 'public'
      and function.proname in (
        'create_team',
        'request_team_join',
        'decide_team_join',
        'decide_team'
      )
      and not function.prosecdef
      and function.proconfig @> array['search_path=""']
  ),
  4,
  'all public team RPCs are invoker wrappers with empty search paths'
);

select is(
  (
    select count(*)::integer
    from pg_proc as function
    join pg_namespace as namespace on namespace.oid = function.pronamespace
    where namespace.nspname = 'private'
      and function.proname in (
        'create_team_impl',
        'request_team_join_impl',
        'decide_team_join_impl',
        'decide_team_impl'
      )
      and function.prosecdef
      and function.proconfig @> array['search_path=""']
  ),
  4,
  'all privileged implementations are private definers with empty search paths'
);

select is(
  (
    select count(*)::integer
    from pg_proc as function
    join pg_namespace as namespace on namespace.oid = function.pronamespace
    where namespace.nspname = 'private'
      and function.proname in (
        'create_team_impl',
        'request_team_join_impl',
        'decide_team_join_impl',
        'decide_team_impl'
      )
      and not has_function_privilege(
        'authenticated',
        function.oid,
        'execute'
      )
  ),
  4,
  'authenticated callers cannot execute private implementations directly'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.create_team(uuid,text,team_category,jsonb)',
    'execute'
  ),
  'anon cannot create teams'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.create_team(uuid,text,team_category,jsonb)',
    'execute'
  ),
  'authenticated callers can use the team creation wrapper'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.request_team_join(uuid)',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.decide_team_join(uuid,boolean)',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.decide_team(uuid,team_status)',
    'execute'
  ),
  'authenticated callers can use the remaining team wrappers'
);

select ok(
  not exists (
    select 1
    from pg_type as type
    cross join lateral aclexplode(
      coalesce(type.typacl, acldefault('T', type.typowner))
    ) as privilege
    where type.oid = 'public.team_category'::regtype
      and privilege.grantee = 0
      and privilege.privilege_type = 'USAGE'
  ),
  'PUBLIC has no usage on team_category'
);
select ok(
  not has_type_privilege('anon', 'public.team_category', 'USAGE'),
  'anon has no usage on team_category'
);
select ok(
  not has_type_privilege('service_role', 'public.team_category', 'USAGE'),
  'service_role has no usage on team_category'
);
select ok(
  has_type_privilege('authenticated', 'public.team_category', 'USAGE'),
  'authenticated can use team_category for create_team'
);
select ok(
  not exists (
    select 1
    from pg_type as type
    cross join lateral aclexplode(
      coalesce(type.typacl, acldefault('T', type.typowner))
    ) as privilege
    where type.oid = 'public.team_category'::regtype
      and privilege.grantee = (
        select role.oid
        from pg_roles as role
        where role.rolname = 'authenticated'
      )
      and privilege.privilege_type = 'USAGE'
      and privilege.is_grantable
  ),
  'authenticated cannot grant team_category usage'
);

select ok(
  not exists (
    select 1
    from pg_type as type
    cross join lateral aclexplode(
      coalesce(type.typacl, acldefault('T', type.typowner))
    ) as privilege
    where type.oid = 'public.team_status'::regtype
      and privilege.grantee = 0
      and privilege.privilege_type = 'USAGE'
  ),
  'PUBLIC has no usage on team_status'
);
select ok(
  not has_type_privilege('anon', 'public.team_status', 'USAGE'),
  'anon has no usage on team_status'
);
select ok(
  not has_type_privilege('service_role', 'public.team_status', 'USAGE'),
  'service_role has no usage on team_status'
);
select ok(
  has_type_privilege('authenticated', 'public.team_status', 'USAGE'),
  'authenticated can use team_status for decide_team'
);
select ok(
  not exists (
    select 1
    from pg_type as type
    cross join lateral aclexplode(
      coalesce(type.typacl, acldefault('T', type.typowner))
    ) as privilege
    where type.oid = 'public.team_status'::regtype
      and privilege.grantee = (
        select role.oid
        from pg_roles as role
        where role.rolname = 'authenticated'
      )
      and privilege.privilege_type = 'USAGE'
      and privilege.is_grantable
  ),
  'authenticated cannot grant team_status usage'
);

select ok(
  not exists (
    select 1
    from pg_type as type
    cross join lateral aclexplode(
      coalesce(type.typacl, acldefault('T', type.typowner))
    ) as privilege
    where type.oid = 'public.member_status'::regtype
      and privilege.grantee = 0
      and privilege.privilege_type = 'USAGE'
  ),
  'PUBLIC has no usage on member_status'
);
select ok(
  not has_type_privilege('anon', 'public.member_status', 'USAGE'),
  'anon has no usage on member_status'
);
select ok(
  not has_type_privilege('service_role', 'public.member_status', 'USAGE'),
  'service_role has no usage on member_status'
);
select ok(
  has_type_privilege('authenticated', 'public.member_status', 'USAGE'),
  'authenticated can read member_status RPC results'
);
select ok(
  not exists (
    select 1
    from pg_type as type
    cross join lateral aclexplode(
      coalesce(type.typacl, acldefault('T', type.typowner))
    ) as privilege
    where type.oid = 'public.member_status'::regtype
      and privilege.grantee = (
        select role.oid
        from pg_roles as role
        where role.rolname = 'authenticated'
      )
      and privilege.privilege_type = 'USAGE'
      and privilege.is_grantable
  ),
  'authenticated cannot grant member_status usage'
);

select ok(
  (
    select bool_and(class.relrowsecurity)
    from pg_class as class
    join pg_namespace as namespace on namespace.oid = class.relnamespace
    where namespace.nspname = 'public'
      and class.relname in ('teams', 'team_members')
  ),
  'RLS is enabled on both team tables'
);

select ok(
  has_table_privilege('authenticated', 'public.teams', 'select')
  and not has_table_privilege('authenticated', 'public.teams', 'insert')
  and not has_table_privilege('authenticated', 'public.teams', 'update')
  and not has_table_privilege('authenticated', 'public.teams', 'delete'),
  'authenticated team table access is read-only'
);
select ok(
  has_table_privilege('authenticated', 'public.team_members', 'select')
  and not has_table_privilege('authenticated', 'public.team_members', 'insert')
  and not has_table_privilege('authenticated', 'public.team_members', 'update')
  and not has_table_privilege('authenticated', 'public.team_members', 'delete'),
  'authenticated team member table access is read-only'
);
select ok(
  not has_table_privilege('anon', 'public.teams', 'select')
  and not has_table_privilege('anon', 'public.team_members', 'select'),
  'anonymous callers cannot read team data'
);

select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'team_members'
      and indexname = 'reserved_email_per_event'
      and indexdef ilike '%unique%'
      and indexdef ilike '%where%'
      and indexdef ilike '%invited%'
      and indexdef ilike '%join_requested%'
      and indexdef ilike '%active%'
  ),
  'reserved e-mail uniqueness uses a partial unique index'
);
select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'team_members'
      and indexname = 'reserved_enrollment_per_event'
      and indexdef ilike '%unique%'
      and indexdef ilike '%where%'
      and indexdef ilike '%invited%'
      and indexdef ilike '%join_requested%'
      and indexdef ilike '%active%'
  ),
  'reserved enrollment uniqueness uses a partial unique index'
);
select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'team_members'
      and indexname = 'one_team_membership_per_user'
      and indexdef ilike '%unique%'
      and indexdef ilike '%where%'
  ),
  'active user membership uses a partial unique index'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '00000000-0000-4000-8000-000000000011',
    'leader@example.test',
    '{"full_name":"Team Leader"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000012',
    'member@example.test',
    '{"full_name":"Invited Member"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000013',
    'outsider@example.test',
    '{"full_name":"Outsider"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000014',
    'professor-one@example.test',
    '{"full_name":"Professor One"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000015',
    'professor-two@example.test',
    '{"full_name":"Professor Two"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000016',
    'leader-two@example.test',
    '{"full_name":"Second Leader"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000017',
    'archive-leader@example.test',
    '{"full_name":"Archive Leader"}'::jsonb
  );

insert into public.events (
  id,
  name,
  slug,
  status,
  professor_id,
  archived_at,
  created_by
)
values
  (
    '10000000-0000-4000-8000-000000000011',
    'Team Event One',
    'team-event-one',
    'registration_open',
    '00000000-0000-4000-8000-000000000014',
    null,
    '00000000-0000-4000-8000-000000000014'
  ),
  (
    '10000000-0000-4000-8000-000000000012',
    'Team Event Two',
    'team-event-two',
    'registration_open',
    '00000000-0000-4000-8000-000000000015',
    null,
    '00000000-0000-4000-8000-000000000015'
  ),
  (
    '10000000-0000-4000-8000-000000000013',
    'Archived Team Event',
    'archived-team-event',
    'archived',
    null,
    now(),
    '00000000-0000-4000-8000-000000000014'
  ),
  (
    '10000000-0000-4000-8000-000000000014',
    'Event To Archive',
    'event-to-archive',
    'registration_open',
    '00000000-0000-4000-8000-000000000014',
    null,
    '00000000-0000-4000-8000-000000000014'
  );

insert into public.event_roles (event_id, user_id, role, approved_by)
values
  (
    '10000000-0000-4000-8000-000000000011',
    '00000000-0000-4000-8000-000000000014',
    'professor',
    '00000000-0000-4000-8000-000000000014'
  ),
  (
    '10000000-0000-4000-8000-000000000012',
    '00000000-0000-4000-8000-000000000015',
    'professor',
    '00000000-0000-4000-8000-000000000015'
  ),
  (
    '10000000-0000-4000-8000-000000000014',
    '00000000-0000-4000-8000-000000000014',
    'professor',
    '00000000-0000-4000-8000-000000000014'
  );

create temporary table team_test_ids (
  label text primary key,
  id uuid not null
) on commit drop;
grant select, insert on team_test_ids to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000011',
  true
);
select set_config(
  'request.jwt.claim.email',
  'leader@example.test',
  true
);

insert into team_test_ids
select
  'main',
  (
    public.create_team(
      '10000000-0000-4000-8000-000000000011',
      'Six Seats',
      'junior',
      '[
        {"name":"Team Leader","email":" LEADER@EXAMPLE.TEST ","enrollment":" LEAD-001 "},
        {"name":"Invited Member","email":"Member@Example.Test","enrollment":"MEM-002"},
        {"name":"Member Three","email":"three@example.test","enrollment":"MEM-003"},
        {"name":"Member Four","email":"four@example.test","enrollment":"MEM-004"},
        {"name":"Member Five","email":"five@example.test","enrollment":"MEM-005"},
        {"name":"Member Six","email":"six@example.test","enrollment":"MEM-006"}
      ]'::jsonb
    )
  ).id;

reset role;

insert into team_test_ids
select 'main_invite', member.id
from public.team_members as member
where member.team_id = (select id from team_test_ids where label = 'main')
  and member.email = 'member@example.test';

select is(
  (
    select count(*)::integer
    from public.team_members
    where team_id = (select id from team_test_ids where label = 'main')
      and status in ('invited', 'join_requested', 'active')
  ),
  6,
  'a team can reserve exactly six seats including invitations'
);
select is(
  (
    select count(*)::integer
    from public.team_members
    where team_id = (select id from team_test_ids where label = 'main')
      and user_id = '00000000-0000-4000-8000-000000000011'
      and status = 'active'
  ),
  1,
  'the authenticated leader is represented by one active member row'
);
select is(
  (
    select email || '|' || enrollment
    from public.team_members
    where team_id = (select id from team_test_ids where label = 'main')
      and user_id = '00000000-0000-4000-8000-000000000011'
  ),
  'leader@example.test|lead-001',
  'member e-mail and enrollment are normalized before storage'
);
select throws_ok(
  $$
    insert into public.team_members (
      event_id,
      team_id,
      name,
      email,
      enrollment
    )
    values (
      '10000000-0000-4000-8000-000000000011',
      (select id from team_test_ids where label = 'main'),
      'Seventh Member',
      'seventh-direct@example.test',
      'seventh-direct'
    )
  $$,
  'P0001',
  'team_size_out_of_range',
  'the schema rejects a seventh reserved seat outside the RPC too'
);
select is(
  (
    select count(*)::integer
    from public.audit_log
    where event_id = '10000000-0000-4000-8000-000000000011'
      and action = 'team_created'
      and entity_id = (
        select id::text from team_test_ids where label = 'main'
      )
  ),
  1,
  'team creation records an event-bound audit'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000016',
  true
);
select set_config(
  'request.jwt.claim.email',
  'leader-two@example.test',
  true
);

select throws_ok(
  $$
    select public.create_team(
      '10000000-0000-4000-8000-000000000011',
      'Seven Seats',
      'senior',
      '[
        {"name":"Leader Two","email":"leader-two@example.test","enrollment":"S-001"},
        {"name":"S2","email":"s2@example.test","enrollment":"S-002"},
        {"name":"S3","email":"s3@example.test","enrollment":"S-003"},
        {"name":"S4","email":"s4@example.test","enrollment":"S-004"},
        {"name":"S5","email":"s5@example.test","enrollment":"S-005"},
        {"name":"S6","email":"s6@example.test","enrollment":"S-006"},
        {"name":"S7","email":"s7@example.test","enrollment":"S-007"}
      ]'::jsonb
    )
  $$,
  'P0001',
  'team_size_out_of_range',
  'a seventh reserved seat is rejected'
);
select throws_ok(
  $$
    select public.create_team(
      '10000000-0000-4000-8000-000000000011',
      'Duplicate E-mail',
      'senior',
      '[
        {"name":"Leader Two","email":"leader-two@example.test","enrollment":"D-001"},
        {"name":"Taken","email":" MEMBER@example.test ","enrollment":"D-002"}
      ]'::jsonb
    )
  $$,
  'P0001',
  'member_already_reserved',
  'normalized e-mail cannot be reserved by another team in one event'
);
select throws_ok(
  $$
    select public.create_team(
      '10000000-0000-4000-8000-000000000011',
      'Duplicate Enrollment',
      'senior',
      '[
        {"name":"Leader Two","email":"leader-two@example.test","enrollment":"D-003"},
        {"name":"Taken","email":"available@example.test","enrollment":" MEM-003 "}
      ]'::jsonb
    )
  $$,
  'P0001',
  'member_already_reserved',
  'normalized enrollment cannot be reserved by another team in one event'
);
select throws_ok(
  $$
    select public.create_team(
      '10000000-0000-4000-8000-000000000011',
      'Leader Missing',
      'senior',
      '[{"name":"Someone Else","email":"else@example.test","enrollment":"E-001"}]'::jsonb
    )
  $$,
  'P0001',
  'leader_member_required',
  'team creation requires the leader in the reserved member set'
);
select throws_ok(
  $$
    select public.create_team(
      '10000000-0000-4000-8000-000000000013',
      'Archived Team',
      'senior',
      '[{"name":"Leader Two","email":"leader-two@example.test","enrollment":"A-001"}]'::jsonb
    )
  $$,
  'P0001',
  'event_not_available',
  'archived events reject team creation'
);

insert into team_test_ids
select
  'cross_event',
  (
    public.create_team(
      '10000000-0000-4000-8000-000000000012',
      'Same Reservations Other Event',
      'senior',
      '[
        {"name":"Leader Two","email":"leader-two@example.test","enrollment":"D-003"},
        {"name":"Reusable","email":"member@example.test","enrollment":"MEM-002"}
      ]'::jsonb
    )
  ).id;

reset role;

select is(
  (
    select count(*)::integer
    from public.teams
    where id = (select id from team_test_ids where label = 'cross_event')
      and event_id = '10000000-0000-4000-8000-000000000012'
  ),
  1,
  'e-mail and enrollment reservations are isolated by event'
);

select throws_ok(
  $$
    insert into public.team_members (
      event_id,
      team_id,
      name,
      email,
      enrollment
    )
    values (
      '10000000-0000-4000-8000-000000000012',
      (select id from team_test_ids where label = 'main'),
      'Cross Event',
      'cross-event@example.test',
      'cross-event'
    )
  $$,
  'P0001',
  'cross_event_reference',
  'a member row cannot combine a team with another event'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000013',
  true
);
select set_config(
  'request.jwt.claim.email',
  'wrong@example.test',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000013","email":"wrong@example.test"}',
  true
);
select is(
  (
    select count(*)::integer
    from public.teams
    where id = (select id from team_test_ids where label = 'main')
  ),
  0,
  'an unrelated student cannot read another team'
);
select throws_ok(
  $$
    select public.request_team_join(
      (select id from team_test_ids where label = 'main_invite')
    )
  $$,
  'P0001',
  'reserved_email_mismatch',
  'a caller with the wrong e-mail cannot claim an invitation'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000012',
  true
);
select set_config(
  'request.jwt.claim.email',
  ' MEMBER@EXAMPLE.TEST ',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000012","email":" MEMBER@EXAMPLE.TEST "}',
  true
);

select is(
  (
    select count(*)::integer
    from public.teams
    where id = (select id from team_test_ids where label = 'main')
  ),
  1,
  'a matching reserved member can read the invited team'
);
select is(
  (
    select (public.request_team_join(
      (select id from team_test_ids where label = 'main_invite')
    )).status::text
  ),
  'join_requested',
  'matching normalized e-mail can request to join'
);
select is(
  (
    select user_id
    from public.team_members
    where team_id = (select id from team_test_ids where label = 'main')
      and email = 'member@example.test'
  ),
  '00000000-0000-4000-8000-000000000012'::uuid,
  'the join request binds the reservation to the authenticated caller'
);
reset role;
select is(
  (
    select count(*)::integer
    from public.audit_log
    where event_id = '10000000-0000-4000-8000-000000000011'
      and action = 'team_join_requested'
  ),
  1,
  'join requests are audited in the member event'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000013',
  true
);
select set_config(
  'request.jwt.claim.email',
  'outsider@example.test',
  true
);
select throws_ok(
  $$
    select public.decide_team_join(
      (select id from team_test_ids where label = 'main_invite'),
      true
    )
  $$,
  'P0001',
  'forbidden',
  'a non-leader cannot decide a join request'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000011',
  true
);
select set_config(
  'request.jwt.claim.email',
  'leader@example.test',
  true
);

select is(
  (
    select (public.decide_team_join(
      (select id from team_test_ids where label = 'main_invite'),
      true
    )).status::text
  ),
  'active',
  'the leader can approve a pending join request'
);
select is(
  (
    select approved_by
    from public.team_members
    where team_id = (select id from team_test_ids where label = 'main')
      and email = 'member@example.test'
  ),
  '00000000-0000-4000-8000-000000000011'::uuid,
  'the member decision records the leader'
);
reset role;
select is(
  (
    select count(*)::integer
    from public.audit_log
    where event_id = '10000000-0000-4000-8000-000000000011'
      and action = 'team_join_approved'
  ),
  1,
  'leader approval is audited'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000013',
  true
);
select set_config(
  'request.jwt.claim.email',
  'outsider@example.test',
  true
);
select throws_ok(
  $$
    select public.decide_team(
      (select id from team_test_ids where label = 'main'),
      'approved'
    )
  $$,
  'P0001',
  'forbidden',
  'a student cannot approve a team'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000015',
  true
);
select set_config(
  'request.jwt.claim.email',
  'professor-two@example.test',
  true
);
select throws_ok(
  $$
    select public.decide_team(
      (select id from team_test_ids where label = 'main'),
      'approved'
    )
  $$,
  'P0001',
  'forbidden',
  'a Professor assigned to another event cannot approve the team'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000014',
  true
);
select set_config(
  'request.jwt.claim.email',
  'professor-one@example.test',
  true
);
select throws_ok(
  $$
    select public.decide_team(
      (select id from team_test_ids where label = 'main'),
      'pending'
    )
  $$,
  'P0001',
  'invalid_decision',
  'team decisions accept only approval or rejection'
);
select is(
  (
    select (public.decide_team(
      (select id from team_test_ids where label = 'main'),
      'approved'
    )).status::text
  ),
  'approved',
  'the assigned event Professor can approve the team'
);
select is(
  (
    select count(*)::integer
    from public.audit_log
    where event_id = '10000000-0000-4000-8000-000000000011'
      and action = 'team_approved'
      and actor_id = '00000000-0000-4000-8000-000000000014'
  ),
  1,
  'Professor team approval is event-bound and audited'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000017',
  true
);
select set_config(
  'request.jwt.claim.email',
  'archive-leader@example.test',
  true
);
insert into team_test_ids
select
  'to_archive',
  (
    public.create_team(
      '10000000-0000-4000-8000-000000000014',
      'Archive Team',
      'junior',
      '[
        {"name":"Archive Leader","email":"archive-leader@example.test","enrollment":"ARC-001"},
        {"name":"Archive Invite","email":"archive-invite@example.test","enrollment":"ARC-002"}
      ]'::jsonb
    )
  ).id;

reset role;
insert into team_test_ids
select 'archive_invite', member.id
from public.team_members as member
where member.team_id = (
    select id from team_test_ids where label = 'to_archive'
  )
  and member.email = 'archive-invite@example.test';

update public.events
set status = 'archived', archived_at = now()
where id = '10000000-0000-4000-8000-000000000014';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000013',
  true
);
select set_config(
  'request.jwt.claim.email',
  'archive-invite@example.test',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000013","email":"archive-invite@example.test"}',
  true
);
select throws_ok(
  $$
    select public.request_team_join(
      (select id from team_test_ids where label = 'archive_invite')
    )
  $$,
  'P0001',
  'event_not_available',
  'archived events reject member workflow writes'
);

reset role;
select throws_ok(
  $$
    update public.teams
    set name = 'Archived Mutation'
    where id = (select id from team_test_ids where label = 'to_archive')
  $$,
  'P0001',
  'event_not_available',
  'archived events reject privileged direct team writes'
);
select throws_ok(
  $$
    update public.team_members
    set name = 'Archived Member Mutation'
    where team_id = (select id from team_test_ids where label = 'to_archive')
  $$,
  'P0001',
  'event_not_available',
  'archived events reject privileged direct member writes'
);

set constraints all immediate;
select lives_ok(
  $$select 1$$,
  'deferred leader membership invariant is satisfied by workflow-created teams'
);
select throws_ok(
  $$
    update public.team_members
    set status = 'removed'
    where team_id = (select id from team_test_ids where label = 'main')
      and user_id = '00000000-0000-4000-8000-000000000011'
  $$,
  '23514',
  'team_leader_must_be_active_member',
  'the database rejects removing the active leader membership'
);
select is(
  (
    select status::text
    from public.team_members
    where team_id = (select id from team_test_ids where label = 'main')
      and user_id = '00000000-0000-4000-8000-000000000011'
  ),
  'active',
  'a rejected leader mutation preserves the active member row'
);

select * from finish();
rollback;
