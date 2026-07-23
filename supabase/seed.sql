-- Identity rows and events remain administrator-owned. If a featured active event
-- already exists, this idempotently attaches the approved CEITEC public content.
-- A fresh database with no event is intentionally left without private identifiers.
do $$
declare
  featured_event_id uuid;
begin
  select event.id
  into featured_event_id
  from public.events as event
  where event.is_featured
    and event.status <> 'archived'
  limit 1;

  if featured_event_id is null then
    return;
  end if;

  insert into public.event_public_content (
    event_id, tagline, presentation, objectives, venue, date_label,
    registration_open
  )
  values (
    featured_event_id,
    'Criando soluções, conectando o futuro.',
    'O Hackathon CEITEC é um evento de dois dias que visa estimular a resolução criativa de problemas relacionados à tecnologia e à sustentabilidade. Participantes de diversas faixas etárias colaboram em grupos para desenvolver soluções tecnológicas inovadoras, vivenciando a rotina de uma verdadeira startup.',
    '["Inovação: Promover a criatividade no desenvolvimento de tecnologias sustentáveis.","Trabalho em Equipe: Estimular a colaboração interdisciplinar entre os alunos.","Prática Educativa: Proporcionar uma imersão real no campo do desenvolvimento e tecnologia."]'::jsonb,
    'CAC - CEI Roberto Freire',
    '24 e 25 de julho',
    true
  )
  on conflict (event_id) do nothing;

  insert into public.event_schedule_items (
    event_id, day_number, starts_at, activity, position
  )
  values
    (featured_event_id, 1, '14:00', 'Chegada e credenciamento', 1),
    (featured_event_id, 1, '14:30', 'Abertura oficial + explicação do Hackathon', 2),
    (featured_event_id, 1, '15:40', 'Pausa para lanche + networking', 3),
    (featured_event_id, 1, '16:00', 'Dinâmica de ideação guiada (5W2H)', 4),
    (featured_event_id, 1, '17:00', 'Checkpoint com mentores (pitch 3 min por equipe) e Desenvolvimento inicial', 5),
    (featured_event_id, 1, '18:00', 'Encerramento do Dia 1', 6),
    (featured_event_id, 2, '07:15', 'Acolhimento + energização', 1),
    (featured_event_id, 2, '07:30', 'Recall do dia anterior', 2),
    (featured_event_id, 2, '08:00', E'Trilhas simultâneas:\nFundamental: Protótipos com IA (CAC) / Protótipos com Hardware / Designs que impressionam / Apresentando minha ideia\nMédio: Startup (negócio + pitch + validação)', 3),
    (featured_event_id, 2, '09:00', 'Desenvolvimento guiado dos projetos', 4),
    (featured_event_id, 2, '10:00', 'Intervalo para lanche', 5),
    (featured_event_id, 2, '10:20', 'Continuação do desenvolvimento', 6),
    (featured_event_id, 2, '11:30', 'Pré-pitch com mentores (simulação)', 7),
    (featured_event_id, 2, '12:15', 'Intervalo para almoço', 8),
    (featured_event_id, 2, '13:15', 'Preparação final dos pitches', 9),
    (featured_event_id, 2, '14:00', 'Apresentações dos projetos', 10),
    (featured_event_id, 2, '16:30', 'Deliberação dos jurados', 11),
    (featured_event_id, 2, '17:15', 'Cerimônia de encerramento e premiação', 12)
  on conflict (event_id, day_number, position) do nothing;
end;
$$;
