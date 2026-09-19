begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;
select no_plan();

select has_table('public', 'event_public_content', 'public content table exists');
select has_table('public', 'event_schedule_items', 'schedule table exists');
select has_function('public', 'get_featured_event_content', array[]::text[], 'fixed public fetch RPC exists');
select has_function('public', 'get_public_event_catalog', array[]::text[], 'public catalog RPC exists');
select has_function('public', 'get_public_event_content', array['text'], 'public slug content RPC exists');
select has_function('public', 'get_event_public_content_for_edit', array['uuid'], 'Professor editor fetch RPC exists');
select has_function('public', 'save_event_public_content', array['uuid', 'jsonb'], 'atomic Professor save RPC exists');

select ok(
  not has_table_privilege('anon', 'public.events', 'select')
  and not has_table_privilege('anon', 'public.event_public_content', 'select')
  and not has_table_privilege('anon', 'public.event_schedule_items', 'select'),
  'anonymous clients have no broad table access'
);
select function_privs_are(
  'public', 'get_featured_event_content', array[]::text[], 'anon',
  array['EXECUTE'], 'anonymous may only execute sanitized public fetch'
);
select function_privs_are(
  'public', 'get_public_event_catalog', array[]::text[], 'anon',
  array['EXECUTE'], 'anonymous may execute only the sanitized public catalog'
);
select function_privs_are(
  'public', 'get_public_event_content', array['text'], 'anon',
  array['EXECUTE'], 'anonymous may execute only sanitized public event detail'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  ('00000000-0000-4000-8000-000000000801', 'landing-professor@example.test', '{"full_name":"Professora Landing"}'),
  ('00000000-0000-4000-8000-000000000802', 'other-professor@example.test', '{"full_name":"Professor Outro"}');

insert into public.events (id, name, slug, status, is_featured, professor_id, created_by)
values
  ('10000000-0000-4000-8000-000000000801', 'Landing CEITEC', 'landing-ceitec', 'registration_open', true,
   '00000000-0000-4000-8000-000000000801', '00000000-0000-4000-8000-000000000801'),
  ('10000000-0000-4000-8000-000000000802', 'Evento privado', 'evento-privado', 'draft', false,
   '00000000-0000-4000-8000-000000000802', '00000000-0000-4000-8000-000000000802');

insert into public.event_roles (event_id, user_id, role, approved_by)
values
  ('10000000-0000-4000-8000-000000000801', '00000000-0000-4000-8000-000000000801', 'professor', '00000000-0000-4000-8000-000000000801'),
  ('10000000-0000-4000-8000-000000000802', '00000000-0000-4000-8000-000000000802', 'professor', '00000000-0000-4000-8000-000000000802');

-- A second operational event must be catalogued even though `is_featured` is
-- intentionally unique. Draft and content-less events remain private.
insert into public.events (id, name, slug, status, is_featured, professor_id, created_by)
values
  ('10000000-0000-4000-8000-000000000803', 'Mostra de Projetos', 'mostra-projetos', 'in_progress', false,
   '00000000-0000-4000-8000-000000000801', '00000000-0000-4000-8000-000000000801'),
  ('10000000-0000-4000-8000-000000000804', 'Sem conteúdo', 'sem-conteudo', 'registration_open', false,
   '00000000-0000-4000-8000-000000000801', '00000000-0000-4000-8000-000000000801');

insert into public.event_public_content (
  event_id, tagline, presentation, objectives, venue, date_label, registration_open
)
values
  ('10000000-0000-4000-8000-000000000803', 'Projetos em destaque', 'Uma mostra pública de projetos.', '["Criatividade"]', 'Ligalab', '12 de agosto', false),
  ('10000000-0000-4000-8000-000000000802', 'Rascunho', 'Conteúdo que não pode ser publicado.', '["Privado"]', 'Interno', 'Nunca', false);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000801', true);

select lives_ok(
  $$select public.save_event_public_content(
    '10000000-0000-4000-8000-000000000801',
    '{"tagline":" Tagline pública ","presentation":" Apresentação segura ","objectives":[" Objetivo A "],"venue":" CAC ","dateLabel":"24 e 25 de julho","registrationOpen":true,"schedule":[{"dayNumber":1,"startsAt":"14:00","activity":" Credenciamento ","position":1},{"dayNumber":2,"startsAt":"07:15","activity":" Acolhimento ","position":1}]}'::jsonb
  )$$,
  'current Professor may save valid event content'
);

select throws_ok(
  $$select public.save_event_public_content(
    '10000000-0000-4000-8000-000000000802',
    '{"tagline":"Tagline","presentation":"Apresentação","objectives":["Objetivo"],"venue":"CAC","dateLabel":"Data","registrationOpen":true,"schedule":[{"dayNumber":1,"startsAt":"14:00","activity":"Atividade","position":1},{"dayNumber":2,"startsAt":"07:15","activity":"Atividade","position":1}]}'::jsonb
  )$$,
  'P0001', 'forbidden', 'Professor cannot save another event'
);

select throws_ok(
  $$select public.save_event_public_content(
    '10000000-0000-4000-8000-000000000801',
    '{"tagline":"Tagline","presentation":"Apresentação","objectives":[],"venue":"CAC","dateLabel":"Data","registrationOpen":true,"schedule":[{"dayNumber":1,"startsAt":"25:00","activity":"A","position":1}]}'::jsonb
  )$$,
  'P0001', 'invalid_objectives', 'empty objectives are rejected deterministically'
);

select throws_ok(
  $$select public.save_event_public_content(
    '10000000-0000-4000-8000-000000000801',
    '{"tagline":"Tagline","presentation":"Apresentação","objectives":["Objetivo"],"venue":"CAC","dateLabel":"Data","registrationOpen":"yes","schedule":[{"dayNumber":1,"startsAt":"14:00","activity":"Atividade","position":1},{"dayNumber":2,"startsAt":"07:15","activity":"Atividade","position":1}]}'::jsonb
  )$$,
  'P0001', 'invalid_content', 'registration state must be a JSON boolean'
);

reset role;
delete from public.event_roles
where event_id = '10000000-0000-4000-8000-000000000801'
  and user_id = '00000000-0000-4000-8000-000000000801'
  and role = 'professor';
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000801', true);
select throws_ok(
  $$select public.save_event_public_content(
    '10000000-0000-4000-8000-000000000801',
    '{"tagline":"Tagline","presentation":"Apresentação","objectives":["Objetivo"],"venue":"CAC","dateLabel":"Data","registrationOpen":true,"schedule":[{"dayNumber":1,"startsAt":"14:00","activity":"Atividade","position":1},{"dayNumber":2,"startsAt":"07:15","activity":"Atividade","position":1}]}'::jsonb
  )$$,
  'P0001', 'forbidden', 'revoked Professor immediately loses edit access'
);

reset role;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);

select is(
  (select count(*)::integer from public.get_featured_event_content()),
  1,
  'anonymous sees one intentionally featured active event'
);
select is(
  (select tagline from public.get_featured_event_content()),
  'Tagline pública',
  'public RPC returns trimmed sanitized content'
);
select is(
  (select count(*)::integer from public.get_featured_event_content()
    where event_slug = 'evento-privado'),
  0,
  'unfeatured event remains absent'
);
select results_eq(
  $$ select event_slug from public.get_public_event_catalog() order by event_slug $$,
  $$ values ('landing-ceitec'), ('mostra-projetos') $$,
  'catalog includes every operational event with public content and excludes draft or content-less events'
);
select is(
  (select event_name from public.get_public_event_content('mostra-projetos')),
  'Mostra de Projetos',
  'slug content returns only the requested public event'
);
select is_empty(
  $$ select * from public.get_public_event_content('evento-privado') $$,
  'draft event is absent from public detail'
);
select is_empty(
  $$ select * from public.get_public_event_content('missing-event') $$,
  'unknown public event slug has no content'
);

reset role;
update public.events
set status = 'archived', archived_at = now(), is_featured = false
where id = '10000000-0000-4000-8000-000000000801';
set local role anon;
select is(
  (select count(*)::integer from public.get_featured_event_content()),
  0,
  'archived event remains absent'
);
select results_eq(
  $$ select event_slug from public.get_public_event_catalog() order by event_slug $$,
  $$ values ('mostra-projetos') $$,
  'archived events are absent from the catalog'
);
reset role;

select is(
  (select count(*)::integer from public.audit_log
   where event_id = '10000000-0000-4000-8000-000000000801'
     and action = 'event_public_content_saved'),
  1,
  'content edit is audited once'
);

select * from finish();
rollback;
