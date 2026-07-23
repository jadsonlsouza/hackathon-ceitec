begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;

select no_plan();

select has_table('public', 'evaluation_criteria', 'evaluation criteria exist');
select has_table('public', 'criterion_weights', 'category weights exist');
select has_table('public', 'evaluator_assignments', 'evaluator assignments exist');
select has_table('public', 'presentation_slots', 'presentation slots exist');
select has_table('public', 'evaluations', 'evaluations exist');
select has_table('public', 'evaluation_scores', 'evaluation scores exist');
select has_table('public', 'evaluation_freezes', 'category freezes exist');

select has_function(
  'public', 'freeze_evaluation', array['uuid', 'team_category'],
  'freeze RPC exists'
);
select has_function(
  'public', 'submit_evaluation', array['uuid', 'jsonb', 'text'],
  'submission RPC exists'
);

select is(
  (
    select count(*)::integer
    from pg_proc as function
    join pg_namespace as namespace on namespace.oid = function.pronamespace
    where namespace.nspname = 'public'
      and function.proname in ('freeze_evaluation', 'submit_evaluation')
      and not function.prosecdef
      and function.proconfig @> array['search_path=""']
  ),
  2,
  'public evaluation RPCs are fixed-path invoker wrappers'
);

select is(
  (
    select count(*)::integer
    from pg_proc as function
    join pg_namespace as namespace on namespace.oid = function.pronamespace
    where namespace.nspname = 'private'
      and function.proname in (
        'freeze_evaluation_impl', 'submit_evaluation_impl'
      )
      and function.prosecdef
      and function.proconfig @> array['search_path=""']
      and not has_function_privilege('authenticated', function.oid, 'execute')
  ),
  2,
  'private implementations are inaccessible fixed-path definers'
);

select ok(
  (
    select bool_and(class.relrowsecurity)
    from pg_class as class
    join pg_namespace as namespace on namespace.oid = class.relnamespace
    where namespace.nspname = 'public'
      and class.relname in (
        'evaluation_criteria', 'criterion_weights',
        'evaluator_assignments', 'presentation_slots', 'evaluations',
        'evaluation_scores', 'evaluation_freezes'
      )
  ),
  'RLS is enabled for every evaluation table'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.freeze_evaluation(uuid,team_category)',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.submit_evaluation(uuid,jsonb,text)',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.submit_evaluation(uuid,jsonb,text)',
    'execute'
  ),
  'RPC grants follow least privilege'
);

select ok(
  not has_table_privilege('authenticated', 'public.evaluations', 'insert')
  and not has_table_privilege('authenticated', 'public.evaluations', 'update')
  and not has_table_privilege(
    'authenticated', 'public.evaluation_scores', 'insert'
  )
  and not has_table_privilege(
    'authenticated', 'public.evaluation_freezes', 'insert'
  ),
  'private evaluation and freeze rows cannot be written directly'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  ('00000000-0000-4000-8000-000000000301',
    'evaluation-professor@example.test',
    '{"full_name":"Evaluation Professor"}'::jsonb),
  ('00000000-0000-4000-8000-000000000302',
    'evaluation-other-professor@example.test',
    '{"full_name":"Other Professor"}'::jsonb),
  ('00000000-0000-4000-8000-000000000303',
    'evaluator-junior@example.test',
    '{"full_name":"Evaluator Junior"}'::jsonb),
  ('00000000-0000-4000-8000-000000000304',
    'evaluator-both@example.test',
    '{"full_name":"Evaluator Both"}'::jsonb),
  ('00000000-0000-4000-8000-000000000305',
    'evaluator-senior@example.test',
    '{"full_name":"Evaluator Senior"}'::jsonb),
  ('00000000-0000-4000-8000-000000000306',
    'evaluator-conflict@example.test',
    '{"full_name":"Evaluator Conflict"}'::jsonb),
  ('00000000-0000-4000-8000-000000000307',
    'evaluation-student-one@example.test',
    '{"full_name":"Student One"}'::jsonb),
  ('00000000-0000-4000-8000-000000000308',
    'evaluation-student-two@example.test',
    '{"full_name":"Student Two"}'::jsonb),
  ('00000000-0000-4000-8000-000000000309',
    'evaluation-revoked@example.test',
    '{"full_name":"Revoked Evaluator"}'::jsonb);

insert into public.events (
  id, name, slug, status, professor_id, created_by
)
values
  ('10000000-0000-4000-8000-000000000301',
    'Evaluation Event', 'evaluation-event', 'evaluation',
    '00000000-0000-4000-8000-000000000301',
    '00000000-0000-4000-8000-000000000301'),
  ('10000000-0000-4000-8000-000000000302',
    'Empty Evaluation Event', 'empty-evaluation-event', 'evaluation',
    '00000000-0000-4000-8000-000000000301',
    '00000000-0000-4000-8000-000000000301'),
  ('10000000-0000-4000-8000-000000000303',
    'Archived Evaluation Event', 'archived-evaluation-event', 'evaluation',
    '00000000-0000-4000-8000-000000000302',
    '00000000-0000-4000-8000-000000000302'),
  ('10000000-0000-4000-8000-000000000304',
    'Replacement Event', 'replacement-evaluation-event', 'evaluation',
    '00000000-0000-4000-8000-000000000301',
    '00000000-0000-4000-8000-000000000301');

select is(
  (
    select count(*)::integer
    from public.evaluation_criteria
    where event_id = '10000000-0000-4000-8000-000000000301'
  ),
  5,
  'future events receive the five initial criteria'
);

select results_eq(
  $$
    select name
    from public.evaluation_criteria
    where event_id = '10000000-0000-4000-8000-000000000301'
    order by position
  $$,
  $$
    values
      ('Time'::text),
      ('Solução'::text),
      ('Pensamento Computacional e Viabilidade'::text),
      ('Apresentação'::text),
      ('Mercado'::text)
  $$,
  'initial criteria preserve the specified order'
);

select is(
  (
    select count(*)::integer
    from public.criterion_weights as weight
    join public.evaluation_criteria as criterion
      on criterion.id = weight.criterion_id
      and criterion.event_id = weight.event_id
    where criterion.event_id = '10000000-0000-4000-8000-000000000301'
      and weight.weight = 1
  ),
  10,
  'both category rows start with weight one'
);

select lives_ok(
  $$
    select private.seed_event_evaluation_defaults(
      '10000000-0000-4000-8000-000000000301'
    )
  $$,
  'default seeding is idempotent'
);

select is(
  (
    select count(*)::integer
    from public.criterion_weights
    where event_id = '10000000-0000-4000-8000-000000000301'
  ),
  10,
  'idempotent seeding creates no duplicates'
);

insert into public.event_roles (event_id, user_id, role, approved_by)
values
  ('10000000-0000-4000-8000-000000000301',
    '00000000-0000-4000-8000-000000000303', 'evaluator',
    '00000000-0000-4000-8000-000000000301'),
  ('10000000-0000-4000-8000-000000000301',
    '00000000-0000-4000-8000-000000000304', 'evaluator',
    '00000000-0000-4000-8000-000000000301'),
  ('10000000-0000-4000-8000-000000000301',
    '00000000-0000-4000-8000-000000000305', 'evaluator',
    '00000000-0000-4000-8000-000000000301'),
  ('10000000-0000-4000-8000-000000000301',
    '00000000-0000-4000-8000-000000000306', 'evaluator',
    '00000000-0000-4000-8000-000000000301'),
  ('10000000-0000-4000-8000-000000000301',
    '00000000-0000-4000-8000-000000000309', 'evaluator',
    '00000000-0000-4000-8000-000000000301'),
  ('10000000-0000-4000-8000-000000000302',
    '00000000-0000-4000-8000-000000000303', 'evaluator',
    '00000000-0000-4000-8000-000000000301'),
  ('10000000-0000-4000-8000-000000000303',
    '00000000-0000-4000-8000-000000000305', 'evaluator',
    '00000000-0000-4000-8000-000000000302'),
  ('10000000-0000-4000-8000-000000000304',
    '00000000-0000-4000-8000-000000000303', 'evaluator',
    '00000000-0000-4000-8000-000000000301');

insert into public.teams (
  id, event_id, name, category, leader_id, status, decided_by, decided_at
)
values
  ('20000000-0000-4000-8000-000000000301',
    '10000000-0000-4000-8000-000000000301',
    'Junior Alpha', 'junior',
    '00000000-0000-4000-8000-000000000307', 'approved',
    '00000000-0000-4000-8000-000000000301', now()),
  ('20000000-0000-4000-8000-000000000302',
    '10000000-0000-4000-8000-000000000301',
    'Junior Beta', 'junior',
    '00000000-0000-4000-8000-000000000308', 'approved',
    '00000000-0000-4000-8000-000000000301', now()),
  ('20000000-0000-4000-8000-000000000303',
    '10000000-0000-4000-8000-000000000301',
    'Senior Alpha', 'senior',
    '00000000-0000-4000-8000-000000000307', 'approved',
    '00000000-0000-4000-8000-000000000301', now()),
  ('20000000-0000-4000-8000-000000000304',
    '10000000-0000-4000-8000-000000000303',
    'Archived Junior', 'junior',
    '00000000-0000-4000-8000-000000000308', 'approved',
    '00000000-0000-4000-8000-000000000302', now()),
  ('20000000-0000-4000-8000-000000000305',
    '10000000-0000-4000-8000-000000000304',
    'Replacement Junior', 'junior',
    '00000000-0000-4000-8000-000000000308', 'approved',
    '00000000-0000-4000-8000-000000000301', now());

insert into public.team_members (
  event_id, team_id, user_id, name, email, enrollment, status, approved_by
)
values
  ('10000000-0000-4000-8000-000000000301',
    '20000000-0000-4000-8000-000000000301',
    '00000000-0000-4000-8000-000000000307', 'Student One',
    'evaluation-student-one@example.test', 'evaluation-301', 'active',
    '00000000-0000-4000-8000-000000000307'),
  ('10000000-0000-4000-8000-000000000301',
    '20000000-0000-4000-8000-000000000302',
    '00000000-0000-4000-8000-000000000308', 'Student Two',
    'evaluation-student-two@example.test', 'evaluation-302', 'active',
    '00000000-0000-4000-8000-000000000308'),
  ('10000000-0000-4000-8000-000000000301',
    '20000000-0000-4000-8000-000000000302',
    '00000000-0000-4000-8000-000000000306', 'Evaluator Conflict',
    'evaluator-conflict@example.test', 'evaluation-303', 'active',
    '00000000-0000-4000-8000-000000000308');

insert into public.canvas_templates (
  id, event_id, name, instructions, created_by
)
values (
  '30000000-0000-4000-8000-000000000301',
  '10000000-0000-4000-8000-000000000301',
  'Evaluation Canvas', '',
  '00000000-0000-4000-8000-000000000301'
);

insert into public.canvas_template_blocks (
  id, template_id, key, title, prompt, position
)
values (
  '31000000-0000-4000-8000-000000000301',
  '30000000-0000-4000-8000-000000000301',
  'summary', 'Resumo', 'Resuma a solução.', 1
);

insert into public.canvas_activities (
  id, event_id, template_id, title, instructions, categories,
  opens_at, due_at, published, is_primary, created_by
)
values (
  '40000000-0000-4000-8000-000000000301',
  '10000000-0000-4000-8000-000000000301',
  '30000000-0000-4000-8000-000000000301',
  'Primary Evaluation Canvas', '',
  array['junior']::public.team_category[],
  now() - interval '2 hours', now() - interval '1 hour', true, true,
  '00000000-0000-4000-8000-000000000301'
);

insert into public.submissions (
  id, event_id, activity_id, team_id, status, submitted_at
)
values
  ('50000000-0000-4000-8000-000000000301',
    '10000000-0000-4000-8000-000000000301',
    '40000000-0000-4000-8000-000000000301',
    '20000000-0000-4000-8000-000000000301',
    'approved', now()),
  ('50000000-0000-4000-8000-000000000302',
    '10000000-0000-4000-8000-000000000301',
    '40000000-0000-4000-8000-000000000301',
    '20000000-0000-4000-8000-000000000302',
    'draft', null);

insert into public.submission_revisions (
  submission_id, revision, snapshot, created_by
)
values
  ('50000000-0000-4000-8000-000000000301', 1,
    '{"summary":{"items":["Approved public summary"]}}'::jsonb,
    '00000000-0000-4000-8000-000000000307'),
  ('50000000-0000-4000-8000-000000000302', 1,
    '{"summary":{"items":["Private draft summary"]}}'::jsonb,
    '00000000-0000-4000-8000-000000000308');

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000301', true
);

insert into public.evaluation_criteria (
  event_id, name, description, position
)
values (
  '10000000-0000-4000-8000-000000000301',
  'Impacto', '', 6
);

select is(
  (
    select count(*)::integer
    from public.criterion_weights as weight
    join public.evaluation_criteria as criterion
      on criterion.id = weight.criterion_id
    where criterion.event_id = '10000000-0000-4000-8000-000000000301'
      and criterion.name = 'Impacto'
      and weight.weight = 1
  ),
  2,
  'new criteria receive both default category weights'
);

delete from public.evaluation_criteria
where event_id = '10000000-0000-4000-8000-000000000301'
  and name = 'Impacto';

select lives_ok(
  $$
    update public.criterion_weights
    set weight = 2.5
    where event_id = '10000000-0000-4000-8000-000000000301'
      and category = 'junior'
      and criterion_id = (
        select id from public.evaluation_criteria
        where event_id = '10000000-0000-4000-8000-000000000301'
          and name = 'Time'
      )
  $$,
  'Professor edits a category weight before freeze'
);

insert into public.evaluator_assignments (event_id, evaluator_id, category)
values
  ('10000000-0000-4000-8000-000000000301',
    '00000000-0000-4000-8000-000000000303', 'junior'),
  ('10000000-0000-4000-8000-000000000301',
    '00000000-0000-4000-8000-000000000304', 'junior'),
  ('10000000-0000-4000-8000-000000000301',
    '00000000-0000-4000-8000-000000000306', 'junior'),
  ('10000000-0000-4000-8000-000000000302',
    '00000000-0000-4000-8000-000000000303', 'junior'),
  ('10000000-0000-4000-8000-000000000304',
    '00000000-0000-4000-8000-000000000303', 'junior');

select throws_ok(
  $$
    select public.freeze_evaluation(
      '10000000-0000-4000-8000-000000000302', 'junior'
    )
  $$,
  'P0001', 'approved_team_required',
  'freeze requires an approved team'
);

select throws_ok(
  $$
    select public.freeze_evaluation(
      '10000000-0000-4000-8000-000000000301', 'senior'
    )
  $$,
  'P0001', 'evaluator_required',
  'freeze requires an evaluator in that category'
);

insert into public.evaluator_assignments (event_id, evaluator_id, category)
values (
  '10000000-0000-4000-8000-000000000301',
  '00000000-0000-4000-8000-000000000309', 'senior'
);

reset role;
delete from public.event_roles
where event_id = '10000000-0000-4000-8000-000000000301'
  and user_id = '00000000-0000-4000-8000-000000000309'
  and role = 'evaluator';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000301', true
);
select throws_ok(
  $$
    select public.freeze_evaluation(
      '10000000-0000-4000-8000-000000000301', 'senior'
    )
  $$,
  'P0001', 'evaluator_role_required',
  'a revoked evaluator blocks freeze'
);

delete from public.evaluator_assignments
where event_id = '10000000-0000-4000-8000-000000000301'
  and evaluator_id = '00000000-0000-4000-8000-000000000309'
  and category = 'senior';

insert into public.evaluator_assignments (event_id, evaluator_id, category)
values (
  '10000000-0000-4000-8000-000000000301',
  '00000000-0000-4000-8000-000000000305', 'senior'
);

update public.criterion_weights
set weight = 0
where event_id = '10000000-0000-4000-8000-000000000301'
  and category = 'senior';

select throws_ok(
  $$
    select public.freeze_evaluation(
      '10000000-0000-4000-8000-000000000301', 'senior'
    )
  $$,
  'P0001', 'positive_weight_required',
  'freeze requires a positive total weight'
);

update public.criterion_weights
set weight = 1
where event_id = '10000000-0000-4000-8000-000000000301'
  and category = 'senior';

select throws_ok(
  $$
    select public.freeze_evaluation(
      '10000000-0000-4000-8000-000000000301', 'junior'
    )
  $$,
  'P0001', 'evaluator_participant_conflict',
  'active same-category team membership blocks freeze'
);

delete from public.evaluator_assignments
where event_id = '10000000-0000-4000-8000-000000000301'
  and evaluator_id = '00000000-0000-4000-8000-000000000306'
  and category = 'junior';

reset role;
update public.team_members
set status = 'removed'
where event_id = '10000000-0000-4000-8000-000000000301'
  and user_id = '00000000-0000-4000-8000-000000000306';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000301', true
);
select lives_ok(
  $$
    select public.freeze_evaluation(
      '10000000-0000-4000-8000-000000000301', 'junior'
    )
  $$,
  'Professor freezes one category independently'
);

reset role;

select is(
  (
    select jsonb_array_length(criteria_snapshot)
    from public.evaluation_freezes
    where event_id = '10000000-0000-4000-8000-000000000301'
      and category = 'junior'
  ),
  5,
  'freeze snapshots every active criterion and its category weight'
);

select is(
  (
    select jsonb_array_length(evaluator_snapshot)
    from public.evaluation_freezes
    where event_id = '10000000-0000-4000-8000-000000000301'
      and category = 'junior'
  ),
  2,
  'freeze snapshots all required evaluators'
);

select is(
  (
    select jsonb_array_length(team_snapshot)
    from public.evaluation_freezes
    where event_id = '10000000-0000-4000-8000-000000000301'
      and category = 'junior'
  ),
  2,
  'freeze snapshots all approved teams'
);

select is(
  (
    select team -> 'canvas_summary'
    from public.evaluation_freezes as frozen_config,
      jsonb_array_elements(frozen_config.team_snapshot) as team
    where frozen_config.event_id = '10000000-0000-4000-8000-000000000301'
      and frozen_config.category = 'junior'
      and team ->> 'team_id' = '20000000-0000-4000-8000-000000000301'
  ),
  '{"summary":{"items":["Approved public summary"]}}'::jsonb,
  'freeze exposes only the approved primary Canvas summary'
);

select is(
  (
    select team -> 'canvas_summary'
    from public.evaluation_freezes as frozen_config,
      jsonb_array_elements(frozen_config.team_snapshot) as team
    where frozen_config.event_id = '10000000-0000-4000-8000-000000000301'
      and frozen_config.category = 'junior'
      and team ->> 'team_id' = '20000000-0000-4000-8000-000000000302'
  ),
  'null'::jsonb,
  'draft Canvas content never enters the evaluation snapshot'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000301', true
);

select throws_ok(
  $$
    update public.criterion_weights
    set weight = 4
    where event_id = '10000000-0000-4000-8000-000000000301'
      and category = 'junior'
  $$,
  'P0001', 'evaluation_config_frozen',
  'frozen category weights cannot change'
);

select lives_ok(
  $$
    update public.criterion_weights
    set weight = 2
    where event_id = '10000000-0000-4000-8000-000000000301'
      and category = 'senior'
  $$,
  'the other category remains configurable'
);

select throws_ok(
  $$
    update public.evaluation_criteria
    set name = 'Changed Time'
    where event_id = '10000000-0000-4000-8000-000000000301'
      and name = 'Time'
  $$,
  'P0001', 'evaluation_config_frozen',
  'shared criteria cannot change after either category freezes'
);

select throws_ok(
  $$
    delete from public.evaluator_assignments
    where event_id = '10000000-0000-4000-8000-000000000301'
      and evaluator_id = '00000000-0000-4000-8000-000000000303'
      and category = 'junior'
  $$,
  'P0001', 'evaluation_config_frozen',
  'frozen evaluator requirements are immutable'
);

select throws_ok(
  $$
    select public.freeze_evaluation(
      '10000000-0000-4000-8000-000000000301', 'junior'
    )
  $$,
  'P0001', 'evaluation_already_frozen',
  'a category cannot be frozen twice'
);

select lives_ok(
  $$
    select public.freeze_evaluation(
      '10000000-0000-4000-8000-000000000301', 'senior'
    )
  $$,
  'the second category freezes independently'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000305', true
);

select throws_ok(
  $$
    select public.submit_evaluation(
      '20000000-0000-4000-8000-000000000301',
      '[]'::jsonb, null
    )
  $$,
  'P0001', 'not_assigned_to_category',
  'wrong-category evaluator access is rejected'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000303', true
);

select throws_ok(
  $$
    select public.submit_evaluation(
      '20000000-0000-4000-8000-000000000301',
      '[]'::jsonb, null
    )
  $$,
  'P0001', 'incomplete_scores',
  'submission rejects missing frozen criteria'
);

select throws_ok(
  $$
    select public.submit_evaluation(
      '20000000-0000-4000-8000-000000000301',
      (
        select jsonb_agg(
          jsonb_build_object('criterion_id', id, 'score', 5)
        ) || jsonb_build_array(
          jsonb_build_object(
            'criterion_id', '99999999-9999-4999-8999-999999999999',
            'score', 5
          )
        )
        from public.evaluation_criteria
        where event_id = '10000000-0000-4000-8000-000000000301'
      ),
      null
    )
  $$,
  'P0001', 'extra_scores',
  'submission rejects criteria outside the frozen snapshot'
);

select throws_ok(
  $$
    select public.submit_evaluation(
      '20000000-0000-4000-8000-000000000301',
      (
        select jsonb_agg(
          jsonb_build_object('criterion_id', id, 'score', 5)
        ) || jsonb_build_array(
          jsonb_build_object(
            'criterion_id', (array_agg(id order by position))[1], 'score', 4
          )
        )
        from public.evaluation_criteria
        where event_id = '10000000-0000-4000-8000-000000000301'
      ),
      null
    )
  $$,
  'P0001', 'duplicate_scores',
  'submission rejects duplicate criteria'
);

select throws_ok(
  $$
    select public.submit_evaluation(
      '20000000-0000-4000-8000-000000000301',
      (
        select jsonb_agg(
          jsonb_build_object(
            'criterion_id', id,
            'score', case when position = 1 then 0 else 5 end
          )
        )
        from public.evaluation_criteria
        where event_id = '10000000-0000-4000-8000-000000000301'
      ),
      null
    )
  $$,
  'P0001', 'invalid_score',
  'submission rejects a score outside 1 through 5'
);

select throws_ok(
  $$
    select public.submit_evaluation(
      '20000000-0000-4000-8000-000000000301',
      (
        select jsonb_agg(
          jsonb_build_object(
            'criterion_id', id,
            'score', case when position = 1 then 4.5 else 5 end
          )
        )
        from public.evaluation_criteria
        where event_id = '10000000-0000-4000-8000-000000000301'
      ),
      null
    )
  $$,
  'P0001', 'invalid_score',
  'submission rejects non-integer scores'
);

select lives_ok(
  $$
    select public.submit_evaluation(
      '20000000-0000-4000-8000-000000000301',
      (
        select jsonb_agg(
          jsonb_build_object(
            'criterion_id', id,
            'score', case when position = 1 then 4 else 5 end
          ) order by position
        )
        from public.evaluation_criteria
        where event_id = '10000000-0000-4000-8000-000000000301'
      ),
      '  avaliação inicial  '
    )
  $$,
  'assigned evaluator submits all frozen criteria'
);

reset role;

select is(
  (
    select comment from public.evaluations
    where event_id = '10000000-0000-4000-8000-000000000301'
      and team_id = '20000000-0000-4000-8000-000000000301'
      and evaluator_id = '00000000-0000-4000-8000-000000000303'
  ),
  'avaliação inicial',
  'optional comment is normalized'
);

select is(
  (
    select count(*)::integer
    from public.evaluation_scores as score
    join public.evaluations as evaluation
      on evaluation.id = score.evaluation_id
    where evaluation.team_id = '20000000-0000-4000-8000-000000000301'
      and evaluation.evaluator_id = '00000000-0000-4000-8000-000000000303'
  ),
  5,
  'one score is stored for every frozen criterion'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000303', true
);

select lives_ok(
  $$
    select public.submit_evaluation(
      '20000000-0000-4000-8000-000000000301',
      (
        select jsonb_agg(
          jsonb_build_object('criterion_id', id, 'score', 3)
          order by position
        )
        from public.evaluation_criteria
        where event_id = '10000000-0000-4000-8000-000000000301'
      ),
      ''
    )
  $$,
  'repeat submission atomically replaces the prior evaluation'
);

reset role;

select is(
  (
    select count(*)::integer
    from public.evaluations
    where team_id = '20000000-0000-4000-8000-000000000301'
      and evaluator_id = '00000000-0000-4000-8000-000000000303'
  ),
  1,
  'one evaluator has one row per team'
);

select is(
  (
    select min(score)::integer
    from public.evaluation_scores as score
    join public.evaluations as evaluation
      on evaluation.id = score.evaluation_id
    where evaluation.team_id = '20000000-0000-4000-8000-000000000301'
      and evaluation.evaluator_id = '00000000-0000-4000-8000-000000000303'
  ),
  3,
  'repeat submission replaces all scores'
);

select is(
  (
    select comment from public.evaluations
    where team_id = '20000000-0000-4000-8000-000000000301'
      and evaluator_id = '00000000-0000-4000-8000-000000000303'
  ),
  null,
  'blank feedback is stored as absent'
);

delete from public.event_roles
where event_id = '10000000-0000-4000-8000-000000000301'
  and user_id = '00000000-0000-4000-8000-000000000303'
  and role = 'evaluator';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000303', true
);

select throws_ok(
  $$
    select public.submit_evaluation(
      '20000000-0000-4000-8000-000000000301',
      (
        select jsonb_agg(
          jsonb_build_object('criterion_id', id, 'score', 4)
        )
        from public.evaluation_criteria
        where event_id = '10000000-0000-4000-8000-000000000301'
      ),
      null
    )
  $$,
  'P0001', 'evaluator_role_required',
  'revoked evaluator cannot update a frozen evaluation'
);

reset role;
insert into public.event_roles (event_id, user_id, role, approved_by)
values (
  '10000000-0000-4000-8000-000000000301',
  '00000000-0000-4000-8000-000000000303', 'evaluator',
  '00000000-0000-4000-8000-000000000301'
);

insert into public.team_members (
  event_id, team_id, user_id, name, email, enrollment, status, approved_by
)
values (
  '10000000-0000-4000-8000-000000000301',
  '20000000-0000-4000-8000-000000000302',
  '00000000-0000-4000-8000-000000000303', 'Evaluator Junior',
  'evaluator-junior@example.test', 'evaluation-304', 'active',
  '00000000-0000-4000-8000-000000000308'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000303', true
);

select throws_ok(
  $$
    select public.submit_evaluation(
      '20000000-0000-4000-8000-000000000302',
      (
        select jsonb_agg(
          jsonb_build_object('criterion_id', id, 'score', 4)
        )
        from public.evaluation_criteria
        where event_id = '10000000-0000-4000-8000-000000000301'
      ),
      null
    )
  $$,
  'P0001', 'evaluator_participant_conflict',
  'same-category membership is rechecked at submission'
);

reset role;
update public.team_members
set status = 'removed'
where event_id = '10000000-0000-4000-8000-000000000301'
  and user_id = '00000000-0000-4000-8000-000000000303';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000304', true
);
select lives_ok(
  $$
    select public.submit_evaluation(
      '20000000-0000-4000-8000-000000000301',
      (
        select jsonb_agg(
          jsonb_build_object('criterion_id', id, 'score', 5)
        )
        from public.evaluation_criteria
        where event_id = '10000000-0000-4000-8000-000000000301'
      ),
      null
    )
  $$,
  'every frozen evaluator can evaluate every team in the category'
);

select is(
  (
    select count(*)::integer from public.evaluations
    where evaluator_id = '00000000-0000-4000-8000-000000000304'
  ),
  1,
  'evaluator reads only their own private evaluations'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000307', true
);
select is(
  (select count(*)::integer from public.evaluations),
  0,
  'students cannot read raw evaluations'
);
select is(
  (select count(*)::integer from public.evaluation_scores),
  0,
  'students cannot read raw scores'
);
select is(
  (select count(*)::integer from public.evaluation_freezes),
  0,
  'students cannot read frozen private evaluation inputs'
);
reset role;

update public.events
set professor_id = '00000000-0000-4000-8000-000000000302'
where id = '10000000-0000-4000-8000-000000000304';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000301', true
);
select throws_ok(
  $$
    select public.freeze_evaluation(
      '10000000-0000-4000-8000-000000000304', 'junior'
    )
  $$,
  'P0001', 'forbidden',
  'a replaced Professor immediately loses freeze authority'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000305', true
);
select throws_ok(
  $$
    select public.submit_evaluation(
      '20000000-0000-4000-8000-000000000301',
      '[]'::jsonb, null
    )
  $$,
  'P0001', 'not_assigned_to_category',
  'cross-category and cross-event identifiers cannot bypass assignment'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000302', true
);
insert into public.evaluator_assignments (event_id, evaluator_id, category)
values (
  '10000000-0000-4000-8000-000000000303',
  '00000000-0000-4000-8000-000000000305', 'junior'
);
select lives_ok(
  $$
    select public.freeze_evaluation(
      '10000000-0000-4000-8000-000000000303', 'junior'
    )
  $$,
  'archival fixture is frozen while active'
);
reset role;

update public.events
set status = 'archived', archived_at = now()
where id = '10000000-0000-4000-8000-000000000303';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000305', true
);
select throws_ok(
  $$
    select public.submit_evaluation(
      '20000000-0000-4000-8000-000000000304',
      (
        select jsonb_agg(
          jsonb_build_object('criterion_id', id, 'score', 5)
        )
        from public.evaluation_criteria
        where event_id = '10000000-0000-4000-8000-000000000303'
      ),
      null
    )
  $$,
  'P0001', 'event_not_available',
  'archived events reject evaluation writes'
);
reset role;

select is(
  (
    select count(*)::integer
    from public.audit_log
    where event_id = '10000000-0000-4000-8000-000000000301'
      and action = 'evaluation_frozen'
  ),
  2,
  'each category freeze is audited independently'
);

select ok(
  (
    select count(*) >= 2
    from public.audit_log
    where event_id = '10000000-0000-4000-8000-000000000301'
      and action in ('evaluation_submitted', 'evaluation_updated')
  ),
  'evaluation creation and replacement are audited'
);

select * from finish();
rollback;
