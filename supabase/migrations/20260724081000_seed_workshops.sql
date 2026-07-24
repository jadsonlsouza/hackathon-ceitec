do $$
declare
  evt record;
begin
  for evt in select id, created_by from public.events loop
    insert into public.workshops (
      event_id, title, description, starts_at, ends_at, capacity, created_by
    ) values
    (evt.id, 'Protótipos com IA', 'Aprenda a integrar inteligência artificial no seu projeto.', '2026-10-01 10:00:00+00', '2026-10-01 12:00:00+00', 30, evt.created_by),
    (evt.id, 'Protótipos com Hardware', 'Construa protótipos funcionais com hardware e eletrônica básica.', '2026-10-01 14:00:00+00', '2026-10-01 16:00:00+00', 30, evt.created_by),
    (evt.id, 'Designs que impressionam', 'Técnicas de UI/UX para destacar o seu projeto.', '2026-10-02 10:00:00+00', '2026-10-02 12:00:00+00', 30, evt.created_by),
    (evt.id, 'Apresentando minha ideia', 'Técnicas de oratória e pitch para hackathons.', '2026-10-02 14:00:00+00', '2026-10-02 16:00:00+00', 30, evt.created_by),
    (evt.id, 'Startups (Sênior)', 'Mentoria avançada para formação de startups (foco na categoria Sênior).', '2026-10-03 10:00:00+00', '2026-10-03 12:00:00+00', 30, evt.created_by);
  end loop;
end;
$$;
