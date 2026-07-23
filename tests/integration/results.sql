begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;

select no_plan();

select has_view(
  'public', 'evaluation_progress',
  'evaluation progress is exposed to authorized staff'
);
select has_view(
  'public', 'administrative_ranking',
  'administrative ranking exists'
);
select has_table(
  'public', 'tie_decisions',
  'audited tie decisions exist'
);
select has_table(
  'public', 'published_results',
  'immutable publication snapshots exist'
);
select has_function(
  'public',
  'resolve_tie',
  array['uuid', 'team_category', 'numeric', 'uuid[]', 'text'],
  'tie resolution RPC exists'
);
select has_function(
  'public',
  'publish_category_results',
  array['uuid', 'team_category'],
  'category publication RPC exists'
);
select has_function(
  'public',
  'get_published_results',
  array['text'],
  'public slug-scoped result RPC exists'
);
select has_function(
  'public', 'get_evaluation_progress', array['uuid'],
  'Professor-only progress RPC exists'
);
select has_function(
  'public', 'get_administrative_ranking', array['uuid'],
  'Professor-only ranking RPC exists'
);
select has_function(
  'public', 'get_administrative_publications', array['uuid'],
  'Professor-only publication-state RPC exists'
);

select is(
  (
    select count(*)::integer
    from pg_class as class
    join pg_namespace as namespace on namespace.oid = class.relnamespace
    where namespace.nspname = 'public'
      and class.relname in ('evaluation_progress', 'administrative_ranking')
      and class.reloptions @> array['security_invoker=true']
  ),
  2,
  'private administrative views run with invoker permissions'
);

select is(
  (
    select count(*)::integer
    from pg_proc as function
    join pg_namespace as namespace on namespace.oid = function.pronamespace
    where namespace.nspname = 'public'
      and function.proname in (
        'resolve_tie', 'publish_category_results', 'get_published_results'
      )
      and function.proconfig @> array['search_path=""']
  ),
  3,
  'result RPCs use a fixed empty search path'
);

select ok(
  (
    select bool_and(class.relrowsecurity)
    from pg_class as class
    join pg_namespace as namespace on namespace.oid = class.relnamespace
    where namespace.nspname = 'public'
      and class.relname in ('tie_decisions', 'published_results')
  ),
  'result tables have RLS enabled'
);

select ok(
  not has_table_privilege('anon', 'public.tie_decisions', 'select')
  and not has_table_privilege('anon', 'public.evaluation_progress', 'select')
  and not has_table_privilege('anon', 'public.administrative_ranking', 'select')
  and not has_table_privilege('anon', 'public.published_results', 'select')
  and not has_table_privilege(
    'authenticated', 'public.evaluation_progress', 'select'
  )
  and not has_table_privilege(
    'authenticated', 'public.administrative_ranking', 'select'
  )
  and not has_table_privilege(
    'authenticated', 'public.published_results', 'select'
  ),
  'private and published tables have no direct client read grants'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  ('00000000-0000-4000-8000-000000000601',
    'results-professor@example.test', '{"full_name":"Professora"}'),
  ('00000000-0000-4000-8000-000000000602',
    'results-evaluator-a@example.test', '{"full_name":"Avaliador A"}'),
  ('00000000-0000-4000-8000-000000000603',
    'results-evaluator-b@example.test', '{"full_name":"Avaliadora B"}'),
  ('00000000-0000-4000-8000-000000000604',
    'results-student-a@example.test', '{"full_name":"Aluno A"}'),
  ('00000000-0000-4000-8000-000000000605',
    'results-student-b@example.test', '{"full_name":"Aluno B"}'),
  ('00000000-0000-4000-8000-000000000606',
    'results-student-c@example.test', '{"full_name":"Aluno C"}'),
  ('00000000-0000-4000-8000-000000000607',
    'results-student-s@example.test', '{"full_name":"Aluno S"}'),
  ('00000000-0000-4000-8000-000000000608',
    'results-monitor@example.test', '{"full_name":"Monitor"}');

insert into public.events (
  id, name, slug, status, professor_id, created_by, archived_at
)
values
  ('10000000-0000-4000-8000-000000000601',
    'Resultados CEITEC', 'resultados-ceitec', 'evaluation',
    '00000000-0000-4000-8000-000000000601',
    '00000000-0000-4000-8000-000000000601', null),
  ('10000000-0000-4000-8000-000000000602',
    'Resultados fora de fase', 'resultados-fora-de-fase', 'in_progress',
    '00000000-0000-4000-8000-000000000601',
    '00000000-0000-4000-8000-000000000601', null),
  ('10000000-0000-4000-8000-000000000603',
    'Resultados arquivados', 'resultados-arquivados', 'archived',
    '00000000-0000-4000-8000-000000000601',
    '00000000-0000-4000-8000-000000000601', now());

insert into public.event_roles (event_id, user_id, role, approved_by)
values
  ('10000000-0000-4000-8000-000000000601',
    '00000000-0000-4000-8000-000000000601', 'professor',
    '00000000-0000-4000-8000-000000000601'),
  ('10000000-0000-4000-8000-000000000601',
    '00000000-0000-4000-8000-000000000602', 'evaluator',
    '00000000-0000-4000-8000-000000000601'),
  ('10000000-0000-4000-8000-000000000601',
    '00000000-0000-4000-8000-000000000603', 'evaluator',
    '00000000-0000-4000-8000-000000000601'),
  ('10000000-0000-4000-8000-000000000602',
    '00000000-0000-4000-8000-000000000601', 'professor',
    '00000000-0000-4000-8000-000000000601'),
  ('10000000-0000-4000-8000-000000000601',
    '00000000-0000-4000-8000-000000000608', 'monitor',
    '00000000-0000-4000-8000-000000000601');

insert into public.teams (
  id, event_id, name, category, leader_id, status, decided_by, decided_at
)
values
  ('20000000-0000-4000-8000-000000000601',
    '10000000-0000-4000-8000-000000000601',
    'Equipe Alpha', 'junior',
    '00000000-0000-4000-8000-000000000604', 'approved',
    '00000000-0000-4000-8000-000000000601', now()),
  ('20000000-0000-4000-8000-000000000602',
    '10000000-0000-4000-8000-000000000601',
    'Equipe Beta', 'junior',
    '00000000-0000-4000-8000-000000000605', 'approved',
    '00000000-0000-4000-8000-000000000601', now()),
  ('20000000-0000-4000-8000-000000000603',
    '10000000-0000-4000-8000-000000000601',
    'Equipe Gama', 'junior',
    '00000000-0000-4000-8000-000000000606', 'approved',
    '00000000-0000-4000-8000-000000000601', now()),
  ('20000000-0000-4000-8000-000000000604',
    '10000000-0000-4000-8000-000000000601',
    'Equipe Sênior', 'senior',
    '00000000-0000-4000-8000-000000000607', 'approved',
    '00000000-0000-4000-8000-000000000601', now());

insert into public.evaluator_assignments (
  event_id, evaluator_id, category, assigned_by
)
values
  ('10000000-0000-4000-8000-000000000601',
    '00000000-0000-4000-8000-000000000602', 'junior',
    '00000000-0000-4000-8000-000000000601'),
  ('10000000-0000-4000-8000-000000000601',
    '00000000-0000-4000-8000-000000000603', 'junior',
    '00000000-0000-4000-8000-000000000601'),
  ('10000000-0000-4000-8000-000000000601',
    '00000000-0000-4000-8000-000000000602', 'senior',
    '00000000-0000-4000-8000-000000000601');

insert into public.evaluation_freezes (
  event_id,
  category,
  frozen_by,
  criteria_snapshot,
  evaluator_snapshot,
  team_snapshot
)
select
  '10000000-0000-4000-8000-000000000601',
  'junior',
  '00000000-0000-4000-8000-000000000601',
  (
    select jsonb_agg(
      jsonb_build_object(
        'criterion_id', criterion.id,
        'name', criterion.name,
        'position', criterion.position,
        'weight', case when criterion.name = 'Time' then 2 else 1 end
      )
      order by criterion.position
    )
    from public.evaluation_criteria as criterion
    where criterion.event_id = '10000000-0000-4000-8000-000000000601'
      and criterion.name in ('Time', 'Solução')
  ),
  jsonb_build_array(
    jsonb_build_object(
      'evaluator_id', '00000000-0000-4000-8000-000000000602',
      'display_name', 'Avaliador A'
    ),
    jsonb_build_object(
      'evaluator_id', '00000000-0000-4000-8000-000000000603',
      'display_name', 'Avaliadora B'
    )
  ),
  jsonb_build_array(
    jsonb_build_object(
      'team_id', '20000000-0000-4000-8000-000000000601',
      'name', 'Equipe Alpha', 'category', 'junior'
    ),
    jsonb_build_object(
      'team_id', '20000000-0000-4000-8000-000000000602',
      'name', 'Equipe Beta', 'category', 'junior'
    ),
    jsonb_build_object(
      'team_id', '20000000-0000-4000-8000-000000000603',
      'name', 'Equipe Gama', 'category', 'junior'
    )
  );

insert into public.evaluation_freezes (
  event_id,
  category,
  frozen_by,
  criteria_snapshot,
  evaluator_snapshot,
  team_snapshot
)
select
  '10000000-0000-4000-8000-000000000601',
  'senior',
  '00000000-0000-4000-8000-000000000601',
  jsonb_build_array(jsonb_build_object(
    'criterion_id', criterion.id,
    'name', criterion.name,
    'position', criterion.position,
    'weight', 1
  )),
  jsonb_build_array(jsonb_build_object(
    'evaluator_id', '00000000-0000-4000-8000-000000000602',
    'display_name', 'Avaliador A'
  )),
  jsonb_build_array(jsonb_build_object(
    'team_id', '20000000-0000-4000-8000-000000000604',
    'name', 'Equipe Sênior', 'category', 'senior'
  ))
from public.evaluation_criteria as criterion
where criterion.event_id = '10000000-0000-4000-8000-000000000601'
  and criterion.name = 'Time';

insert into public.evaluations (
  id, event_id, category, team_id, evaluator_id
)
values
  ('60000000-0000-4000-8000-000000000601',
    '10000000-0000-4000-8000-000000000601', 'junior',
    '20000000-0000-4000-8000-000000000601',
    '00000000-0000-4000-8000-000000000602'),
  ('60000000-0000-4000-8000-000000000602',
    '10000000-0000-4000-8000-000000000601', 'junior',
    '20000000-0000-4000-8000-000000000601',
    '00000000-0000-4000-8000-000000000603'),
  ('60000000-0000-4000-8000-000000000603',
    '10000000-0000-4000-8000-000000000601', 'junior',
    '20000000-0000-4000-8000-000000000602',
    '00000000-0000-4000-8000-000000000602'),
  ('60000000-0000-4000-8000-000000000604',
    '10000000-0000-4000-8000-000000000601', 'junior',
    '20000000-0000-4000-8000-000000000602',
    '00000000-0000-4000-8000-000000000603'),
  ('60000000-0000-4000-8000-000000000605',
    '10000000-0000-4000-8000-000000000601', 'junior',
    '20000000-0000-4000-8000-000000000603',
    '00000000-0000-4000-8000-000000000602'),
  ('60000000-0000-4000-8000-000000000607',
    '10000000-0000-4000-8000-000000000601', 'senior',
    '20000000-0000-4000-8000-000000000604',
    '00000000-0000-4000-8000-000000000602');

insert into public.evaluation_scores (
  evaluation_id, event_id, criterion_id, score
)
select
  evaluation.id,
  evaluation.event_id,
  criterion.id,
  scores.score
from (
  values
    ('60000000-0000-4000-8000-000000000601'::uuid, 'Time', 5::smallint),
    ('60000000-0000-4000-8000-000000000601'::uuid, 'Solução', 3::smallint),
    ('60000000-0000-4000-8000-000000000602'::uuid, 'Time', 4::smallint),
    ('60000000-0000-4000-8000-000000000602'::uuid, 'Solução', 5::smallint),
    ('60000000-0000-4000-8000-000000000603'::uuid, 'Time', 4::smallint),
    ('60000000-0000-4000-8000-000000000603'::uuid, 'Solução', 5::smallint),
    ('60000000-0000-4000-8000-000000000604'::uuid, 'Time', 4::smallint),
    ('60000000-0000-4000-8000-000000000604'::uuid, 'Solução', 5::smallint),
    ('60000000-0000-4000-8000-000000000605'::uuid, 'Time', 4::smallint),
    ('60000000-0000-4000-8000-000000000605'::uuid, 'Solução', 5::smallint),
    ('60000000-0000-4000-8000-000000000607'::uuid, 'Time', 4::smallint)
) as scores(evaluation_id, criterion_name, score)
join public.evaluations as evaluation on evaluation.id = scores.evaluation_id
join public.evaluation_criteria as criterion
  on criterion.event_id = evaluation.event_id
  and criterion.name = scores.criterion_name;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000601', true
);

select is(
  (
    select count(*)::integer
    from public.get_evaluation_progress(
      '10000000-0000-4000-8000-000000000601'
    )
  ),
  4,
  'Professor reads only the requested event progress through the RPC'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000602', true
);
select throws_ok(
  $$
    select * from public.get_evaluation_progress(
      '10000000-0000-4000-8000-000000000601'
    )
  $$,
  'P0001', 'forbidden',
  'evaluator cannot read private evaluation progress'
);
select throws_ok(
  $$
    select * from public.get_administrative_ranking(
      '10000000-0000-4000-8000-000000000601'
    )
  $$,
  'P0001', 'forbidden',
  'evaluator cannot read private ranking'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000608', true
);
select throws_ok(
  $$
    select * from public.get_evaluation_progress(
      '10000000-0000-4000-8000-000000000601'
    )
  $$,
  'P0001', 'forbidden',
  'monitor cannot read private evaluation progress'
);
select throws_ok(
  $$
    select * from public.get_administrative_ranking(
      '10000000-0000-4000-8000-000000000601'
    )
  $$,
  'P0001', 'forbidden',
  'monitor cannot read private ranking'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000604', true
);
select throws_ok(
  $$
    select * from public.get_administrative_ranking(
      '10000000-0000-4000-8000-000000000601'
    )
  $$,
  'P0001', 'forbidden',
  'student cannot read private ranking'
);
select throws_ok(
  $$
    select * from public.get_evaluation_progress(
      '10000000-0000-4000-8000-000000000601'
    )
  $$,
  'P0001', 'forbidden',
  'student cannot read private evaluation progress'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000601', true
);

select throws_ok(
  $$
    select public.resolve_tie(
      '10000000-0000-4000-8000-000000000602',
      'junior', 4.00,
      array[
        '20000000-0000-4000-8000-000000000601'::uuid,
        '20000000-0000-4000-8000-000000000602'::uuid
      ],
      'Fora de fase.'
    )
  $$,
  'P0001', 'event_not_in_evaluation',
  'tie decisions reject events outside the evaluation phase'
);
select throws_ok(
  $$
    select public.resolve_tie(
      '10000000-0000-4000-8000-000000000603',
      'junior', 4.00,
      array[
        '20000000-0000-4000-8000-000000000601'::uuid,
        '20000000-0000-4000-8000-000000000602'::uuid
      ],
      'Evento arquivado.'
    )
  $$,
  'P0001', 'event_not_available',
  'archived events reject tie decisions'
);

select is(
  (
    select completed_evaluator_count
    from public.get_evaluation_progress(
      '10000000-0000-4000-8000-000000000601'
    )
    where category = 'junior'
      and team_id = '20000000-0000-4000-8000-000000000603'
  ),
  1,
  'progress counts only submitted frozen evaluators'
);
select is(
  (
    select missing_evaluators -> 0 ->> 'display_name'
    from public.get_evaluation_progress(
      '10000000-0000-4000-8000-000000000601'
    )
    where category = 'junior'
      and team_id = '20000000-0000-4000-8000-000000000603'
  ),
  'Avaliadora B',
  'progress identifies each missing frozen evaluator'
);
select is(
  (
    select count(*)::integer
    from public.get_administrative_ranking(
      '10000000-0000-4000-8000-000000000601'
    )
    where category = 'junior'
  ),
  2,
  'incomplete frozen teams are excluded from private ranking'
);
select results_eq(
  $$
    select team_name, final_score
    from public.get_administrative_ranking(
      '10000000-0000-4000-8000-000000000601'
    )
    where category = 'junior'
    order by team_name
  $$,
  $$
    values
      ('Equipe Alpha'::text, 4.33::numeric),
      ('Equipe Beta'::text, 4.33::numeric)
  $$,
  'numeric evaluator averages produce a displayed two-decimal tie'
);
select is(
  (
    select weight
    from public.criterion_weights as weight
    join public.evaluation_criteria as criterion
      on criterion.id = weight.criterion_id
    where weight.event_id = '10000000-0000-4000-8000-000000000601'
      and weight.category = 'junior'
      and criterion.name = 'Time'
  ),
  1.00::numeric,
  'the editable current weight differs from the frozen weight used by ranking'
);
select is(
  (
    select round(exact_final_score, 4)
    from public.get_administrative_ranking(
      '10000000-0000-4000-8000-000000000601'
    )
    where category = 'junior'
      and team_id = '20000000-0000-4000-8000-000000000601'
  ),
  4.3333::numeric,
  'ranking preserves numeric precision from the frozen 2-to-1 weights'
);
select throws_ok(
  $$
    select public.publish_category_results(
      '10000000-0000-4000-8000-000000000601', 'junior'
    )
  $$,
  'P0001', 'evaluations_incomplete',
  'an incomplete frozen team blocks category publication'
);
select lives_ok(
  $$
    select public.publish_category_results(
      '10000000-0000-4000-8000-000000000601', 'senior'
    )
  $$,
  'Senior can publish independently while Junior remains incomplete'
);

set local role anon;
select is(
  (
    select count(*)::integer
    from public.get_published_results('resultados-ceitec')
  ),
  0,
  'first category stays hidden publicly until the event is fully published'
);
select throws_ok(
  $$
    select * from public.published_results
  $$,
  '42501', null,
  'anonymous users cannot select publication rows directly'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000602', true
);
select throws_ok(
  $$
    select * from public.published_results
  $$,
  '42501', null,
  'authenticated clients cannot select publication rows directly'
);
select throws_ok(
  $$
    select public.submit_evaluation(
      '20000000-0000-4000-8000-000000000604',
      (
        select jsonb_agg(jsonb_build_object(
          'criterion_id', criterion ->> 'criterion_id',
          'score', 4
        ))
        from public.evaluation_freezes as frozen_config
        cross join lateral jsonb_array_elements(
          frozen_config.criteria_snapshot
        ) as criterion
        where frozen_config.event_id =
          '10000000-0000-4000-8000-000000000601'
          and frozen_config.category = 'senior'
      ),
      null
    )
  $$,
  'P0001', 'category_results_published',
  'submit_evaluation deterministically rejects a published category'
);
select lives_ok(
  $$
    select public.submit_evaluation(
      '20000000-0000-4000-8000-000000000603',
      (
        select jsonb_agg(jsonb_build_object(
          'criterion_id', criterion ->> 'criterion_id',
          'score', case
            when criterion ->> 'name' = 'Time' then 4
            else 5
          end
        ))
        from public.evaluation_freezes as frozen_config
        cross join lateral jsonb_array_elements(
          frozen_config.criteria_snapshot
        ) as criterion
        where frozen_config.event_id =
          '10000000-0000-4000-8000-000000000601'
          and frozen_config.category = 'junior'
      ),
      null
    )
  $$,
  'the unpublished Junior category remains editable'
);

reset role;
insert into public.evaluations (
  id, event_id, category, team_id, evaluator_id
)
values (
  '60000000-0000-4000-8000-000000000606',
  '10000000-0000-4000-8000-000000000601', 'junior',
  '20000000-0000-4000-8000-000000000603',
  '00000000-0000-4000-8000-000000000603'
);
insert into public.evaluation_scores (
  evaluation_id, event_id, criterion_id, score
)
select
  '60000000-0000-4000-8000-000000000606',
  '10000000-0000-4000-8000-000000000601',
  criterion.id,
  case when criterion.name = 'Time' then 4 else 5 end
from public.evaluation_criteria as criterion
where criterion.event_id = '10000000-0000-4000-8000-000000000601'
  and criterion.name in ('Time', 'Solução');

delete from public.event_roles
where event_id = '10000000-0000-4000-8000-000000000601'
  and user_id = '00000000-0000-4000-8000-000000000603'
  and role = 'evaluator';
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000601', true
);
select is(
  (
    select count(*)::integer
    from public.get_evaluation_progress(
      '10000000-0000-4000-8000-000000000601'
    )
    where category = 'junior' and complete
  ),
  3,
  'revoking an evaluator after submission does not erase frozen completeness'
);
reset role;
insert into public.event_roles (event_id, user_id, role, approved_by)
values (
  '10000000-0000-4000-8000-000000000601',
  '00000000-0000-4000-8000-000000000603',
  'evaluator',
  '00000000-0000-4000-8000-000000000601'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000601', true
);
select throws_ok(
  $$
    select public.resolve_tie(
      '10000000-0000-4000-8000-000000000601',
      'junior', 4.33,
      array[
        '20000000-0000-4000-8000-000000000601'::uuid,
        '20000000-0000-4000-8000-000000000601'::uuid,
        '20000000-0000-4000-8000-000000000603'::uuid
      ],
      'Ordem inválida.'
    )
  $$,
  'P0001', 'invalid_tie_order',
  'duplicate manual-order teams are rejected'
);
select throws_ok(
  $$
    select public.resolve_tie(
      '10000000-0000-4000-8000-000000000601',
      'junior', 4.33,
      array[
        '20000000-0000-4000-8000-000000000601'::uuid,
        '20000000-0000-4000-8000-000000000602'::uuid,
        '20000000-0000-4000-8000-000000000603'::uuid
      ],
      '   '
    )
  $$,
  'P0001', 'justification_required',
  'manual tie resolution requires a justification'
);
select throws_ok(
  $$
    select public.publish_category_results(
      '10000000-0000-4000-8000-000000000601', 'junior'
    )
  $$,
  'P0001', 'unresolved_ties',
  'every displayed-score tie blocks publication until resolved'
);
select lives_ok(
  $$
    select public.resolve_tie(
      '10000000-0000-4000-8000-000000000601',
      'junior', 4.33,
      array[
        '20000000-0000-4000-8000-000000000602'::uuid,
        '20000000-0000-4000-8000-000000000601'::uuid,
        '20000000-0000-4000-8000-000000000603'::uuid
      ],
      'Ordem acordada com todos os avaliadores.'
    )
  $$,
  'Professor records every team in a three-team tie'
);
select lives_ok(
  $$
    select public.resolve_tie(
      '10000000-0000-4000-8000-000000000601',
      'junior', 4.33,
      array[
        '20000000-0000-4000-8000-000000000602'::uuid,
        '20000000-0000-4000-8000-000000000601'::uuid,
        '20000000-0000-4000-8000-000000000603'::uuid
      ],
      'Ordem acordada com todos os avaliadores.'
    )
  $$,
  'an identical repeated resolution is idempotent'
);
select is(
  (
    select count(*)::integer
    from public.tie_decisions
    where event_id = '10000000-0000-4000-8000-000000000601'
      and category = 'junior'
  ),
  1,
  'idempotent resolution stores only one audited decision'
);
select is(
  (
    select sum(score)::integer
    from public.evaluation_scores
    where event_id = '10000000-0000-4000-8000-000000000601'
  ),
  57,
  'tie resolution never changes an original score'
);
reset role;
select throws_ok(
  $$
    update public.evaluation_scores
    set score = 4
    where evaluation_id = '60000000-0000-4000-8000-000000000601'
      and criterion_id = (
        select id
        from public.evaluation_criteria
        where event_id = '10000000-0000-4000-8000-000000000601'
          and name = 'Time'
      )
  $$,
  'P0001', 'ranking_locked_after_tie_decision',
  'submitted scores are locked after a category tie decision'
);
alter table public.evaluation_scores
  disable trigger protect_ranked_evaluation_score;
update public.evaluation_scores
set score = 4
where evaluation_id = '60000000-0000-4000-8000-000000000601'
  and criterion_id = (
    select id
    from public.evaluation_criteria
    where event_id = '10000000-0000-4000-8000-000000000601'
      and name = 'Time'
  );
alter table public.evaluation_scores
  enable trigger protect_ranked_evaluation_score;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000601', true
);
select throws_ok(
  $$
    select public.publish_category_results(
      '10000000-0000-4000-8000-000000000601', 'junior'
    )
  $$,
  'P0001', 'stale_tie_decision',
  'an evaluation change invalidates an earlier manual tie decision'
);
reset role;
alter table public.evaluation_scores
  disable trigger protect_ranked_evaluation_score;
update public.evaluation_scores
set score = 5
where evaluation_id = '60000000-0000-4000-8000-000000000601'
  and criterion_id = (
    select id
    from public.evaluation_criteria
    where event_id = '10000000-0000-4000-8000-000000000601'
      and name = 'Time'
  );
alter table public.evaluation_scores
  enable trigger protect_ranked_evaluation_score;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000601', true
);
select lives_ok(
  $$
    select public.publish_category_results(
      '10000000-0000-4000-8000-000000000601', 'junior'
    )
  $$,
  'resolved complete junior ranking publishes'
);
select is(
  (
    select ranking -> 0 ->> 'team_name'
    from public.get_published_results('resultados-ceitec')
    where category = 'junior'
  ),
  'Equipe Beta',
  'publication applies the manual order without changing equal scores'
);
select is(
  (
    select status::text
    from public.events
    where id = '10000000-0000-4000-8000-000000000601'
  ),
  'results_published',
  'publishing Junior advances the event because Senior already exists'
);
select lives_ok(
  $$
    select public.publish_category_results(
      '10000000-0000-4000-8000-000000000601', 'senior'
    )
  $$,
  'repeating the earlier Senior publication is idempotent'
);
select is(
  (
    select status::text
    from public.events
    where id = '10000000-0000-4000-8000-000000000601'
  ),
  'results_published',
  'event advances only after both category snapshots exist'
);
select lives_ok(
  $$
    select public.publish_category_results(
      '10000000-0000-4000-8000-000000000601', 'junior'
    )
  $$,
  'an identical repeated publication returns the immutable snapshot'
);
reset role;
select throws_ok(
  $$
    update public.published_results
    set ranking = '[]'::jsonb
    where event_id = '10000000-0000-4000-8000-000000000601'
  $$,
  'P0001', 'published_result_immutable',
  'published snapshots cannot be changed'
);
delete from public.event_roles
where event_id = '10000000-0000-4000-8000-000000000601'
  and user_id = '00000000-0000-4000-8000-000000000601'
  and role = 'professor';
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000601', true
);
select throws_ok(
  $$
    select public.publish_category_results(
      '10000000-0000-4000-8000-000000000601', 'junior'
    )
  $$,
  'P0001', 'forbidden',
  'a revoked Professor role cannot reuse result administration RPCs'
);

set local role anon;
select is(
  (
    select count(*)::integer
    from public.get_published_results('resultados-ceitec')
  ),
  2,
  'anonymous slug lookup returns both published category snapshots'
);
select throws_ok(
  $$
    select * from public.tie_decisions
  $$,
  '42501', null,
  'anonymous users cannot read tie deliberations'
);
select throws_ok(
  $$
    select * from public.administrative_ranking
  $$,
  '42501', null,
  'anonymous users cannot read private ranking progress'
);

select * from finish();
rollback;
