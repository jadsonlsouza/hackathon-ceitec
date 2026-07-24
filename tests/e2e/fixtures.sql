-- TEST-ONLY deterministic fixture. Applied only after `supabase db reset`.
begin;

do $$
declare
  admin_id uuid := (select id from auth.users where email = 'admin.e2e@ceitec.test');
  professor_a_id uuid := (select id from auth.users where email = 'professor.a.e2e@ceitec.test');
  professor_b_id uuid := (select id from auth.users where email = 'professor.b.e2e@ceitec.test');
  monitor_id uuid := (select id from auth.users where email = 'monitor.e2e@ceitec.test');
  evaluator_junior_id uuid := (select id from auth.users where email = 'avaliador.junior.e2e@ceitec.test');
  evaluator_senior_id uuid := (select id from auth.users where email = 'avaliador.senior.e2e@ceitec.test');
  student_a_id uuid := (select id from auth.users where email = 'aluno.a.e2e@ceitec.test');
  student_b_id uuid := (select id from auth.users where email = 'aluno.b.e2e@ceitec.test');
  student_a2_id uuid := (select id from auth.users where email = 'aluno.a2.e2e@ceitec.test');
  student_senior_id uuid := (select id from auth.users where email = 'aluno.senior.e2e@ceitec.test');
  event_a constant uuid := '11111111-1111-4111-8111-111111111111';
  event_b constant uuid := '22222222-2222-4222-8222-222222222222';
  archived_event constant uuid := '33333333-3333-4333-8333-333333333333';
  team_a constant uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  team_a2 constant uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
  team_senior constant uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3';
  team_b constant uuid := 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1';
  activity_a constant uuid := 'ca000000-0000-4000-8000-000000000001';
  activity_b constant uuid := 'cb000000-0000-4000-8000-000000000001';
  block_a constant uuid := 'ba000000-0000-4000-8000-000000000001';
  block_b constant uuid := 'bb000000-0000-4000-8000-000000000001';
  submission_a constant uuid := 'da000000-0000-4000-8000-000000000001';
  submission_b constant uuid := 'db000000-0000-4000-8000-000000000001';
  evaluation_junior constant uuid := 'ea000000-0000-4000-8000-000000000001';
  evaluation_junior_2 constant uuid := 'ea000000-0000-4000-8000-000000000002';
  evaluation_senior constant uuid := 'ea000000-0000-4000-8000-000000000003';
begin
  if admin_id is null or professor_a_id is null or professor_b_id is null
    or monitor_id is null or evaluator_junior_id is null
    or evaluator_senior_id is null or student_a_id is null
    or student_b_id is null or student_a2_id is null
    or student_senior_id is null
  then
    raise exception 'e2e_auth_users_missing';
  end if;

  update public.profiles
  set global_role = 'global_admin'
  where id = admin_id;

  insert into public.events (
    id, name, slug, status, is_featured, starts_at, ends_at,
    professor_id, archived_at, created_by
  )
  values
    (
      event_a, 'Hackathon CEITEC E2E A', 'hackathon-e2e-a',
      'results_published', true, now() - interval '1 day',
      now() + interval '1 day', professor_a_id, null, admin_id
    ),
    (
      event_b, 'Hackathon CEITEC E2E B', 'hackathon-e2e-b',
      'evaluation', false, now() - interval '1 day',
      now() + interval '1 day', professor_b_id, null, admin_id
    ),
    (
      archived_event, 'Hackathon CEITEC E2E Arquivado',
      'hackathon-e2e-arquivado', 'archived', false,
      now() - interval '10 days', now() - interval '8 days',
      null, now() - interval '7 days', admin_id
    )
  on conflict (id) do nothing;

  insert into public.event_roles (
    event_id, user_id, role, categories, approved_by
  )
  values
    (event_a, professor_a_id, 'professor', '{}', admin_id),
    (event_b, professor_b_id, 'professor', '{}', admin_id),
    (event_a, monitor_id, 'monitor', '{junior,senior}', professor_a_id),
    (event_a, evaluator_junior_id, 'evaluator', '{junior}', professor_a_id),
    (event_a, evaluator_senior_id, 'evaluator', '{senior}', professor_a_id)
  on conflict do nothing;

  insert into public.teams (
    id, event_id, name, category, leader_id, status, decided_by, decided_at
  )
  values
    (team_a, event_a, 'Equipe Aurora', 'junior', student_a_id, 'approved', professor_a_id, now()),
    (team_a2, event_a, 'Equipe Horizonte', 'junior', student_a2_id, 'approved', professor_a_id, now()),
    (team_senior, event_a, 'Equipe Órbita', 'senior', student_senior_id, 'approved', professor_a_id, now()),
    (team_b, event_b, 'Equipe Boreal', 'junior', student_b_id, 'approved', professor_b_id, now())
  on conflict (id) do nothing;

  insert into public.team_members (
    id, event_id, team_id, user_id, name, email, enrollment,
    status, approved_by
  )
  values
    ('a1000000-0000-4000-8000-000000000001', event_a, team_a, student_a_id, 'Aluno A', 'aluno.a.e2e@ceitec.test', 'e2e-a', 'active', student_a_id),
    ('a1000000-0000-4000-8000-000000000002', event_a, team_a2, student_a2_id, 'Aluno A2', 'aluno.a2.e2e@ceitec.test', 'e2e-a2', 'active', student_a2_id),
    ('a1000000-0000-4000-8000-000000000003', event_a, team_senior, student_senior_id, 'Aluno Sênior', 'aluno.senior.e2e@ceitec.test', 'e2e-senior', 'active', student_senior_id),
    ('b1000000-0000-4000-8000-000000000001', event_b, team_b, student_b_id, 'Aluno B', 'aluno.b.e2e@ceitec.test', 'e2e-b', 'active', student_b_id)
  on conflict (id) do nothing;

  insert into public.canvas_activities (
    id, event_id, title, instructions, categories, opens_at, due_at,
    published, is_primary, allow_resubmission, created_by
  )
  values
    (activity_a, event_a, 'Canvas de impacto', 'Descreva a solução da equipe.', '{junior,senior}', now() - interval '2 days', now() + interval '2 days', true, true, true, professor_a_id),
    (activity_b, event_b, 'Canvas isolado B', 'Conteúdo privado do evento B.', '{junior}', now() - interval '2 days', now() + interval '2 days', true, true, true, professor_b_id)
  on conflict (id) do nothing;

  insert into public.canvas_blocks (
    id, activity_id, key, title, prompt, position, max_items
  )
  values
    (block_a, activity_a, 'problema', 'Problema', 'Qual problema a equipe resolve?', 1, null),
    (block_b, activity_b, 'segredo', 'Estratégia privada', 'Descreva a estratégia confidencial.', 1, null)
  on conflict (id) do nothing;

  insert into public.submissions (
    id, event_id, activity_id, team_id, status, revision, submitted_at
  )
  values
    (submission_a, event_a, activity_a, team_a, 'submitted', 1, now() - interval '1 hour'),
    (submission_b, event_b, activity_b, team_b, 'draft', 1, null)
  on conflict (id) do nothing;

  insert into public.submission_answers (
    submission_id, block_id, content, version, updated_by
  )
  values
    (submission_a, block_a, '{"text":"Solução sustentável da Equipe Aurora"}', 1, student_a_id),
    (submission_b, block_b, '{"text":"SEGREDO-EQUIPE-BOREAL"}', 1, student_b_id)
  on conflict (submission_id, block_id) do nothing;

  insert into public.submission_revisions (
    submission_id, revision, snapshot, created_by
  )
  values (
    submission_a, 1,
    '{"problema":{"text":"Solução sustentável da Equipe Aurora"}}',
    student_a_id
  )
  on conflict (submission_id, revision) do nothing;

  insert into public.evaluator_assignments (
    event_id, evaluator_id, category, assigned_by
  )
  values
    (event_a, evaluator_junior_id, 'junior', professor_a_id),
    (event_a, evaluator_senior_id, 'senior', professor_a_id)
  on conflict do nothing;

  insert into public.presentation_slots (
    event_id, category, team_id, position
  )
  values
    (event_a, 'junior', team_a, 1),
    (event_a, 'junior', team_a2, 2),
    (event_a, 'senior', team_senior, 1)
  on conflict do nothing;

  insert into public.evaluation_freezes (
    event_id, category, frozen_by, criteria_snapshot,
    evaluator_snapshot, team_snapshot
  )
  values
    (
      event_a, 'junior', professor_a_id,
      (select jsonb_agg(jsonb_build_object('id', id, 'name', name, 'position', position)) from public.evaluation_criteria where event_id = event_a and active),
      jsonb_build_array(jsonb_build_object('evaluatorId', evaluator_junior_id)),
      jsonb_build_array(jsonb_build_object('teamId', team_a), jsonb_build_object('teamId', team_a2))
    ),
    (
      event_a, 'senior', professor_a_id,
      (select jsonb_agg(jsonb_build_object('id', id, 'name', name, 'position', position)) from public.evaluation_criteria where event_id = event_a and active),
      jsonb_build_array(jsonb_build_object('evaluatorId', evaluator_senior_id)),
      jsonb_build_array(jsonb_build_object('teamId', team_senior))
    )
  on conflict do nothing;

  insert into public.evaluations (
    id, event_id, category, team_id, evaluator_id, comment
  )
  values
    (evaluation_junior, event_a, 'junior', team_a, evaluator_junior_id, 'Avaliação E2E A'),
    (evaluation_junior_2, event_a, 'junior', team_a2, evaluator_junior_id, 'Avaliação E2E A2'),
    (evaluation_senior, event_a, 'senior', team_senior, evaluator_senior_id, 'Avaliação E2E Sênior')
  on conflict (id) do nothing;

  insert into public.evaluation_scores (
    evaluation_id, event_id, criterion_id, score
  )
  select evaluation_id, event_a, criterion.id, 4
  from (
    values (evaluation_junior), (evaluation_junior_2), (evaluation_senior)
  ) as seeded(evaluation_id)
  cross join public.evaluation_criteria as criterion
  where criterion.event_id = event_a
  on conflict do nothing;

  insert into public.published_results (
    event_id, category, ranking, published_by
  )
  values
    (
      event_a, 'junior',
      '[{"position":1,"teamId":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1","teamName":"Equipe Aurora","score":4},{"position":2,"teamId":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2","teamName":"Equipe Horizonte","score":4}]',
      professor_a_id
    ),
    (
      event_a, 'senior',
      '[{"position":1,"teamId":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3","teamName":"Equipe Órbita","score":4}]',
      professor_a_id
    )
  on conflict do nothing;

  insert into public.event_public_content (
    event_id, tagline, presentation, objectives, venue, date_label,
    registration_open, updated_by
  )
  values
    (event_a, 'Criando soluções, conectando o futuro.', 'Conteúdo público seguro do evento A.', '["Inovação","Colaboração"]', 'CAC - CEI Roberto Freire', '24 e 25 de julho', true, professor_a_id),
    (event_b, 'Evento isolado B.', 'Conteúdo público do evento B.', '["Aprendizado"]', 'Unidade B', '26 de julho', false, professor_b_id)
  on conflict (event_id) do nothing;

  insert into public.event_schedule_items (
    event_id, day_number, starts_at, activity, position
  )
  values
    (event_a, 1, '14:00', 'Abertura oficial', 1),
    (event_a, 2, '14:00', 'Apresentações dos projetos', 1),
    (event_b, 1, '08:00', 'Abertura B', 1),
    (event_b, 2, '16:00', 'Encerramento B', 1)
  on conflict (event_id, day_number, position) do nothing;
end;
$$;

commit;
