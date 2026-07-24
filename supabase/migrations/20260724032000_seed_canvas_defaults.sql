create function private.seed_event_canvas_defaults(target_event uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  event_creator uuid;
  activity_id uuid;
begin
  if target_event is null or not exists (
    select 1 from public.events as event where event.id = target_event
  ) then
    raise exception using errcode = 'P0001', message = 'event_not_found';
  end if;

  select created_by into event_creator from public.events where id = target_event;

  insert into public.canvas_activities (
    event_id,
    title,
    instructions,
    categories,
    opens_at,
    due_at,
    published,
    is_primary,
    created_by
  )
  values (
    target_event,
    'Canvas Hackathon',
    'Preencha as informações do seu projeto. Seja claro e objetivo. As respostas serão visíveis para os avaliadores.',
    array['junior'::public.team_category, 'senior'::public.team_category],
    now(),
    now() + interval '10 years',
    true,
    true,
    event_creator
  )
  returning id into activity_id;

  insert into public.canvas_blocks (
    activity_id, key, title, prompt, position, max_items
  )
  values
    (activity_id, 'causas', '🔍 EXPLORAR: Causas raiz', 'O que origina o problema? (5 Porquês)', 1, null),
    (activity_id, 'consequencias', '🔍 EXPLORAR: Consequências', 'O que acontece com quem vive este problema?', 2, null),
    (activity_id, 'solucoes_atuais', '🔍 EXPLORAR: Soluções atuais', 'Como resolvem hoje e por que é insuficiente?', 3, null),
    
    (activity_id, 'dores', '👤 CLIENTE: Dores', 'O que frustra ou atrapalha este cliente?', 4, null),
    (activity_id, 'desejos', '👤 CLIENTE: Desejos', 'O que ele quer conquistar ou evitar?', 5, null),
    (activity_id, 'comportamento', '👤 CLIENTE: Comportamento', 'Como ele age? Quais gambiarras usa?', 6, null),

    (activity_id, 'resumo', '💡 SOLUÇÃO: Resumo', 'Descreva em uma frase a sua solução. (Exibição fixa para o avaliador)', 7, null),
    (activity_id, 'proposta_valor', '💡 SOLUÇÃO: Proposta de valor', 'Qual o principal benefício e para quem?', 8, null),
    (activity_id, 'concorrentes', '💡 SOLUÇÃO: Concorrentes', 'Quais soluções diretas/indiretas existem?', 9, null),
    (activity_id, 'vantagem', '💡 SOLUÇÃO: Vantagem competitiva', 'O que torna a solução difícil de copiar?', 10, null),

    (activity_id, 'mvp', '⚖️ AVALIAR: MVP', 'Máximo de 3 funcionalidades essenciais.', 11, null),

    (activity_id, 'tam', '🚀 LANÇAR: TAM', 'Quantas pessoas têm este problema?', 12, null),
    (activity_id, 'posicionamento', '🚀 LANÇAR: Posicionamento', 'Como se compara aos concorrentes?', 13, null),

    (activity_id, 'modelo_receita', '📈 ACELERAR: Modelo de receita', 'De onde vem a sustentabilidade financeira?', 14, null),
    (activity_id, 'precificacao', '📈 ACELERAR: Precificação', 'Quanto custa e qual a justificativa?', 15, null);
end;
$$;

revoke all on function private.seed_event_canvas_defaults(uuid)
from public, anon, authenticated, service_role;

create function private.seed_new_event_canvas_defaults()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.seed_event_canvas_defaults(new.id);
  return new;
end;
$$;

revoke all on function private.seed_new_event_canvas_defaults()
from public, anon, authenticated, service_role;

create trigger seed_new_event_canvas_defaults
after insert on public.events
for each row execute function private.seed_new_event_canvas_defaults();
