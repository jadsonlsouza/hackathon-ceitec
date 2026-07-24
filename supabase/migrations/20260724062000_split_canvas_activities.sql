-- Migration: split the single "Canvas Hackathon" activity into 6 separate activities.
-- Safe to run even if the event already has submissions, since user confirmed there are no
-- real data to preserve. All existing canvas_activities and their blocks (and cascaded
-- submissions/answers) are deleted, then recreated as 6 focused activities.

-- 1. Remove all existing canvas activities for all events
--    submissions FK is not cascade from canvas_activities side, so delete manually in order
delete from public.submission_reviews  using public.submissions s where submission_reviews.submission_id = s.id;
delete from public.submission_revisions using public.submissions s where submission_revisions.submission_id = s.id;
delete from public.submission_answers  using public.submissions s where submission_answers.submission_id = s.id;
delete from public.submissions;
delete from public.canvas_activities;


-- 2. Replace the seed function with the new 6-activity layout
create or replace function private.seed_event_canvas_defaults(target_event uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  event_creator uuid;
  act_explorar  uuid;
  act_cliente   uuid;
  act_solucao   uuid;
  act_avaliar   uuid;
  act_lancar    uuid;
  act_acelerar  uuid;
  base_opens    timestamptz := now();
  far_future    timestamptz := now() + interval '10 years';
begin
  if target_event is null or not exists (
    select 1 from public.events as event where event.id = target_event
  ) then
    raise exception using errcode = 'P0001', message = 'event_not_found';
  end if;

  select created_by into event_creator from public.events where id = target_event;

  -- ── Atividade 1: EXPLORAR ────────────────────────────────────────────────
  insert into public.canvas_activities (
    event_id, title, instructions, categories, opens_at, due_at, published, is_primary, created_by
  ) values (
    target_event,
    '🔍 EXPLORAR',
    'Investigue a fundo o problema. Identifique causas raiz, consequências reais e como as pessoas já tentam resolver hoje.',
    '{junior, senior}', base_opens, far_future, true, false, event_creator
  ) returning id into act_explorar;

  insert into public.canvas_blocks (activity_id, key, title, prompt, position)
  values
    (act_explorar, 'causas',        '🔍 EXPLORAR: Causas raiz',       'O que origina o problema? (5 Porquês)', 1),
    (act_explorar, 'consequencias', '🔍 EXPLORAR: Consequências',      'O que acontece com quem vive este problema?', 2),
    (act_explorar, 'solucoes_hoje', '🔍 EXPLORAR: Soluções atuais',    'Como resolvem hoje e por que é insuficiente?', 3);

  -- ── Atividade 2: CLIENTE ────────────────────────────────────────────────
  insert into public.canvas_activities (
    event_id, title, instructions, categories, opens_at, due_at, published, is_primary, created_by
  ) values (
    target_event,
    '👤 CLIENTE',
    'Defina com clareza quem é o seu cliente. Entenda suas dores, desejos e comportamentos reais.',
    '{junior, senior}', base_opens, far_future, true, false, event_creator
  ) returning id into act_cliente;

  insert into public.canvas_blocks (activity_id, key, title, prompt, position)
  values
    (act_cliente, 'dores',         '👤 CLIENTE: Dores',         'O que frustra ou atrapalha este cliente?', 1),
    (act_cliente, 'desejos',       '👤 CLIENTE: Desejos',       'O que ele quer conquistar ou evitar?', 2),
    (act_cliente, 'comportamento', '👤 CLIENTE: Comportamento', 'Como ele age? Quais gambiarras usa?', 3);

  -- ── Atividade 3: SOLUÇÃO ────────────────────────────────────────────────
  insert into public.canvas_activities (
    event_id, title, instructions, categories, opens_at, due_at, published, is_primary, created_by
  ) values (
    target_event,
    '💡 SOLUÇÃO',
    'Apresente a sua solução de forma clara. Destaque a proposta de valor, como se diferencia da concorrência e sua vantagem competitiva.',
    '{junior, senior}', base_opens, far_future, true, true, event_creator
  ) returning id into act_solucao;

  insert into public.canvas_blocks (activity_id, key, title, prompt, position)
  values
    (act_solucao, 'resumo',          '💡 SOLUÇÃO: Resumo',               'Descreva em uma frase a sua solução. (Exibição fixa para o avaliador)', 1),
    (act_solucao, 'proposta_valor',  '💡 SOLUÇÃO: Proposta de valor',    'Qual o principal benefício e para quem?', 2),
    (act_solucao, 'concorrentes',    '💡 SOLUÇÃO: Concorrentes',         'Quais soluções diretas/indiretas existem?', 3),
    (act_solucao, 'vantagem',        '💡 SOLUÇÃO: Vantagem competitiva', 'O que torna a solução difícil de copiar?', 4);

  -- ── Atividade 4: AVALIAR ────────────────────────────────────────────────
  insert into public.canvas_activities (
    event_id, title, instructions, categories, opens_at, due_at, published, is_primary, created_by
  ) values (
    target_event,
    '⚖️ AVALIAR',
    'Defina o MVP da sua solução. Foque no essencial — máximo 3 funcionalidades.',
    '{junior, senior}', base_opens, far_future, true, false, event_creator
  ) returning id into act_avaliar;

  insert into public.canvas_blocks (activity_id, key, title, prompt, position)
  values
    (act_avaliar, 'mvp', '⚖️ AVALIAR: MVP', 'Máximo de 3 funcionalidades essenciais.', 1);

  -- ── Atividade 5: LANÇAR ─────────────────────────────────────────────────
  insert into public.canvas_activities (
    event_id, title, instructions, categories, opens_at, due_at, published, is_primary, created_by
  ) values (
    target_event,
    '🚀 LANÇAR',
    'Defina seu mercado e posicionamento. Mostre o tamanho da oportunidade e como a solução se diferencia.',
    '{junior, senior}', base_opens, far_future, true, false, event_creator
  ) returning id into act_lancar;

  insert into public.canvas_blocks (activity_id, key, title, prompt, position)
  values
    (act_lancar, 'tam',            '🚀 LANÇAR: TAM',           'Quantas pessoas têm este problema?', 1),
    (act_lancar, 'posicionamento', '🚀 LANÇAR: Posicionamento', 'Como se compara aos concorrentes?', 2);

  -- ── Atividade 6: ACELERAR ───────────────────────────────────────────────
  insert into public.canvas_activities (
    event_id, title, instructions, categories, opens_at, due_at, published, is_primary, created_by
  ) values (
    target_event,
    '📈 ACELERAR',
    'Mostre como o negócio se sustenta financeiramente. Detalhe modelo de receita e precificação.',
    '{junior, senior}', base_opens, far_future, true, false, event_creator
  ) returning id into act_acelerar;

  insert into public.canvas_blocks (activity_id, key, title, prompt, position)
  values
    (act_acelerar, 'modelo_receita', '📈 ACELERAR: Modelo de receita', 'De onde vem a sustentabilidade financeira?', 1),
    (act_acelerar, 'precificacao',   '📈 ACELERAR: Precificação',      'Quanto custa e qual a justificativa?', 2);

end;
$$;

-- 3. Re-seed all existing events with the new 6-activity layout
do $$
declare
  ev record;
begin
  for ev in select id from public.events loop
    perform private.seed_event_canvas_defaults(ev.id);
  end loop;
end;
$$;
