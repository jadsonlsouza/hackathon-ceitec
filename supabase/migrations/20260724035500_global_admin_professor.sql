-- Adiciona poderes de professor ao global_admin
create or replace function public.is_event_professor(target_event uuid)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from private.current_event_professorships as professorship
    where professorship.event_id = target_event
      and professorship.user_id = (select auth.uid())
  ) or (select public.is_global_admin());
$$;
