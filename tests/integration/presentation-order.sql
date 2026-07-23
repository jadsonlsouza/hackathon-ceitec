begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;

select no_plan();

select has_function(
  'public',
  'shuffle_presentations',
  array['uuid', 'team_category'],
  'presentation shuffle RPC exists'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.shuffle_presentations(uuid,team_category)',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.shuffle_presentations(uuid,team_category)',
    'execute'
  ),
  'shuffle RPC follows least privilege'
);

select is(
  (
    select count(*)::integer
    from pg_proc as function
    join pg_namespace as namespace on namespace.oid = function.pronamespace
    where namespace.nspname = 'public'
      and function.proname = 'shuffle_presentations'
      and not function.prosecdef
      and function.proconfig @> array['search_path=""']
  ),
  1,
  'public shuffle RPC is a fixed-path invoker wrapper'
);

select is(
  (
    select count(*)::integer
    from pg_proc as function
    join pg_namespace as namespace on namespace.oid = function.pronamespace
    where namespace.nspname = 'private'
      and function.proname = 'shuffle_presentations_impl'
      and function.prosecdef
      and function.proconfig @> array['search_path=""']
      and not has_function_privilege('authenticated', function.oid, 'execute')
  ),
  1,
  'private shuffle implementation is an inaccessible fixed-path definer'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  (
    '00000000-0000-4000-8000-000000000401',
    'shuffle-professor@example.test',
    '{"full_name":"Shuffle Professor"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000402',
    'shuffle-other-professor@example.test',
    '{"full_name":"Other Professor"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000403',
    'shuffle-evaluator@example.test',
    '{"full_name":"Shuffle Evaluator"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000404',
    'shuffle-student-a@example.test',
    '{"full_name":"Student A"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000405',
    'shuffle-student-b@example.test',
    '{"full_name":"Student B"}'::jsonb
  ),
  (
    '00000000-0000-4000-8000-000000000406',
    'shuffle-student-c@example.test',
    '{"full_name":"Student C"}'::jsonb
  );

insert into public.events (
  id, name, slug, status, professor_id, created_by, archived_at
)
values
  (
    '10000000-0000-4000-8000-000000000401',
    'Shuffle Event', 'shuffle-event', 'evaluation',
    '00000000-0000-4000-8000-000000000401',
    '00000000-0000-4000-8000-000000000401', null
  ),
  (
    '10000000-0000-4000-8000-000000000402',
    'No Team Event', 'shuffle-no-team', 'evaluation',
    '00000000-0000-4000-8000-000000000401',
    '00000000-0000-4000-8000-000000000401', null
  ),
  (
    '10000000-0000-4000-8000-000000000403',
    'One Team Event', 'shuffle-one-team', 'evaluation',
    '00000000-0000-4000-8000-000000000401',
    '00000000-0000-4000-8000-000000000401', null
  ),
  (
    '10000000-0000-4000-8000-000000000404',
    'Other Event', 'shuffle-other-event', 'evaluation',
    '00000000-0000-4000-8000-000000000402',
    '00000000-0000-4000-8000-000000000402', null
  ),
  (
    '10000000-0000-4000-8000-000000000405',
    'Draft Event', 'shuffle-draft-event', 'draft',
    '00000000-0000-4000-8000-000000000401',
    '00000000-0000-4000-8000-000000000401', null
  ),
  (
    '10000000-0000-4000-8000-000000000406',
    'Archived Event', 'shuffle-archived-event', 'evaluation',
    '00000000-0000-4000-8000-000000000401',
    '00000000-0000-4000-8000-000000000401', null
  );

insert into public.event_roles (event_id, user_id, role, approved_by)
values (
  '10000000-0000-4000-8000-000000000401',
  '00000000-0000-4000-8000-000000000403',
  'evaluator',
  '00000000-0000-4000-8000-000000000401'
);

insert into public.teams (
  id, event_id, name, category, leader_id, status, decided_by, decided_at
)
values
  (
    '20000000-0000-4000-8000-000000000401',
    '10000000-0000-4000-8000-000000000401',
    'Junior A', 'junior',
    '00000000-0000-4000-8000-000000000404', 'approved',
    '00000000-0000-4000-8000-000000000401', now()
  ),
  (
    '20000000-0000-4000-8000-000000000402',
    '10000000-0000-4000-8000-000000000401',
    'Junior B', 'junior',
    '00000000-0000-4000-8000-000000000405', 'approved',
    '00000000-0000-4000-8000-000000000401', now()
  ),
  (
    '20000000-0000-4000-8000-000000000403',
    '10000000-0000-4000-8000-000000000401',
    'Junior C', 'junior',
    '00000000-0000-4000-8000-000000000406', 'approved',
    '00000000-0000-4000-8000-000000000401', now()
  ),
  (
    '20000000-0000-4000-8000-000000000404',
    '10000000-0000-4000-8000-000000000401',
    'Senior A', 'senior',
    '00000000-0000-4000-8000-000000000404', 'approved',
    '00000000-0000-4000-8000-000000000401', now()
  ),
  (
    '20000000-0000-4000-8000-000000000405',
    '10000000-0000-4000-8000-000000000401',
    'Pending Junior', 'junior',
    '00000000-0000-4000-8000-000000000404', 'pending',
    null, null
  ),
  (
    '20000000-0000-4000-8000-000000000406',
    '10000000-0000-4000-8000-000000000403',
    'Only Junior', 'junior',
    '00000000-0000-4000-8000-000000000404', 'approved',
    '00000000-0000-4000-8000-000000000401', now()
  ),
  (
    '20000000-0000-4000-8000-000000000407',
    '10000000-0000-4000-8000-000000000404',
    'Other Junior', 'junior',
    '00000000-0000-4000-8000-000000000405', 'approved',
    '00000000-0000-4000-8000-000000000402', now()
  ),
  (
    '20000000-0000-4000-8000-000000000408',
    '10000000-0000-4000-8000-000000000405',
    'Draft Junior', 'junior',
    '00000000-0000-4000-8000-000000000406', 'approved',
    '00000000-0000-4000-8000-000000000401', now()
  ),
  (
    '20000000-0000-4000-8000-000000000409',
    '10000000-0000-4000-8000-000000000406',
    'Archived Junior', 'junior',
    '00000000-0000-4000-8000-000000000406', 'approved',
    '00000000-0000-4000-8000-000000000401', now()
  );

alter table public.presentation_slots disable trigger protect_presentation_slot;

insert into public.presentation_slots (
  event_id, category, team_id, position
)
values
  (
    '10000000-0000-4000-8000-000000000401',
    'senior',
    '20000000-0000-4000-8000-000000000404',
    1
  ),
  (
    '10000000-0000-4000-8000-000000000404',
    'junior',
    '20000000-0000-4000-8000-000000000407',
    1
  );

alter table public.presentation_slots enable trigger protect_presentation_slot;

update public.events
set status = 'archived', archived_at = now()
where id = '10000000-0000-4000-8000-000000000406';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000401',
  true
);

select is(
  (
    select count(*)::integer
    from public.profiles
    where id = '00000000-0000-4000-8000-000000000403'
  ),
  1,
  'the current Professor can identify approved event evaluators'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000404',
  true
);

select is(
  (
    select count(*)::integer
    from public.profiles
    where id = '00000000-0000-4000-8000-000000000403'
  ),
  0,
  'students cannot read evaluator profiles'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000403',
  true
);

select throws_ok(
  $$
    select public.shuffle_presentations(
      '10000000-0000-4000-8000-000000000401',
      'junior'
    )
  $$,
  'P0001', 'forbidden',
  'an evaluator cannot shuffle presentations'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000401',
  true
);

select throws_ok(
  $$
    select public.shuffle_presentations(
      '10000000-0000-4000-8000-000000000405',
      'junior'
    )
  $$,
  'P0001', 'event_not_in_evaluation',
  'a wrong event phase rejects shuffle'
);

select throws_ok(
  $$
    select public.shuffle_presentations(
      '10000000-0000-4000-8000-000000000406',
      'junior'
    )
  $$,
  'P0001', 'event_not_available',
  'an archived event rejects shuffle'
);

select throws_ok(
  $$
    select public.shuffle_presentations(
      '10000000-0000-4000-8000-000000000404',
      'junior'
    )
  $$,
  'P0001', 'forbidden',
  'a Professor cannot shuffle another event'
);

select throws_ok(
  $$
    select public.shuffle_presentations(
      '10000000-0000-4000-8000-000000000402',
      'junior'
    )
  $$,
  'P0001', 'approved_team_required',
  'an empty category reports that an approved team is required'
);

select is(
  public.shuffle_presentations(
    '10000000-0000-4000-8000-000000000403',
    'junior'
  ),
  1,
  'a one-team category creates one slot'
);

select is(
  public.shuffle_presentations(
    '10000000-0000-4000-8000-000000000401',
    'junior'
  ),
  3,
  'a many-team category creates every approved team slot'
);

reset role;

select is(
  (
    select count(*)::integer
    from public.presentation_slots
    where event_id = '10000000-0000-4000-8000-000000000401'
      and category = 'junior'
  ),
  3,
  'selected category contains every approved team exactly once'
);

select results_eq(
  $$
    select position
    from public.presentation_slots
    where event_id = '10000000-0000-4000-8000-000000000401'
      and category = 'junior'
    order by position
  $$,
  $$ values (1), (2), (3) $$,
  'presentation positions are unique and contiguous'
);

select is(
  (
    select count(*)::integer
    from public.presentation_slots
    where event_id = '10000000-0000-4000-8000-000000000401'
      and category = 'senior'
  ),
  1,
  'shuffle preserves the other category'
);

select is(
  (
    select count(*)::integer
    from public.presentation_slots
    where event_id = '10000000-0000-4000-8000-000000000404'
  ),
  1,
  'shuffle preserves every other event'
);

select is(
  (
    select count(*)::integer
    from public.presentation_slots
    where team_id = '20000000-0000-4000-8000-000000000405'
  ),
  0,
  'pending teams never enter presentation order'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000401',
  true
);

select is(
  public.shuffle_presentations(
    '10000000-0000-4000-8000-000000000401',
    'junior'
  ),
  3,
  'Professor may reshuffle before scoring'
);

reset role;

insert into public.evaluator_assignments (
  event_id, evaluator_id, category, assigned_by
)
values (
  '10000000-0000-4000-8000-000000000401',
  '00000000-0000-4000-8000-000000000403',
  'junior',
  '00000000-0000-4000-8000-000000000401'
);

insert into public.evaluations (
  event_id, category, team_id, evaluator_id, comment
)
values (
  '10000000-0000-4000-8000-000000000401',
  'junior',
  '20000000-0000-4000-8000-000000000401',
  '00000000-0000-4000-8000-000000000403',
  null
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000401',
  true
);

select throws_ok(
  $$
    select public.shuffle_presentations(
      '10000000-0000-4000-8000-000000000401',
      'junior'
    )
  $$,
  'P0001', 'evaluation_already_started',
  'submitted evaluation blocks later reshuffle'
);

reset role;

select is(
  (
    select count(*)::integer
    from public.audit_log
    where event_id = '10000000-0000-4000-8000-000000000401'
      and action = 'presentation_order_shuffled'
      and entity_id = 'junior'
  ),
  2,
  'every successful shuffle is audited'
);

select ok(
  (
    select bool_and(
      payload @> '{"category":"junior","team_count":3}'::jsonb
    )
    from public.audit_log
    where event_id = '10000000-0000-4000-8000-000000000401'
      and action = 'presentation_order_shuffled'
      and entity_id = 'junior'
  ),
  'shuffle audit records selected category and team count'
);

update public.events
set professor_id = '00000000-0000-4000-8000-000000000402'
where id = '10000000-0000-4000-8000-000000000403';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000401',
  true
);

select throws_ok(
  $$
    select public.shuffle_presentations(
      '10000000-0000-4000-8000-000000000403',
      'junior'
    )
  $$,
  'P0001', 'forbidden',
  'a replaced Professor immediately loses shuffle authority'
);

reset role;

select * from finish();
rollback;
