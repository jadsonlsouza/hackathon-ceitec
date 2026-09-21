create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  event_id uuid references public.events(id),
  team_id uuid,
  kind text not null default 'manual_message' check (kind like 'manual\_%' escape '\'),
  title text not null check (char_length(btrim(title)) between 1 and 160),
  body text not null check (char_length(btrim(body)) between 1 and 4000),
  action_path text check (action_path is null or action_path ~ '^/app(/[A-Za-z0-9_-]+)*$'),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  read_at timestamptz,
  foreign key (team_id, event_id) references public.teams(id, event_id),
  check (team_id is null or event_id is not null)
);
create index notifications_recipient_created_idx on public.notifications(recipient_id, created_at desc);
create index notifications_event_idx on public.notifications(event_id);
create index notifications_team_event_idx on public.notifications(team_id, event_id);
create index notifications_author_idx on public.notifications(created_by);
alter table public.notifications enable row level security;
revoke all on public.notifications from public, anon, authenticated;
grant select on public.notifications to authenticated;
create policy "recipients read their notifications" on public.notifications
for select to authenticated using (recipient_id = (select auth.uid()));

create function private.create_manual_notifications_impl(input jsonb)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  admin boolean;
  target_event uuid;
  target_team uuid;
  audience jsonb := input->'audience';
  audience_type text := input#>>'{audience,type}';
  recipients uuid[];
  recipient_count integer;
begin
  if actor is null then raise exception 'authentication_required'; end if;
  select p.global_role = 'global_admin' into admin from public.profiles p where p.id = actor;
  target_event := nullif(input->>'event_id','')::uuid;
  if not coalesce(admin,false) and not exists (
    select 1 from public.event_roles r where r.user_id=actor and r.event_id=target_event and r.role='professor'
  ) then raise exception 'forbidden'; end if;
  if jsonb_typeof(input) is distinct from 'object'
     or char_length(btrim(coalesce(input->>'title',''))) not between 1 and 160
     or char_length(btrim(coalesce(input->>'body',''))) not between 1 and 4000
  then raise exception 'invalid_message'; end if;
  if target_event is not null and not exists(select 1 from public.events e where e.id=target_event and e.status<>'archived') then
    raise exception 'event_not_available';
  end if;
  if jsonb_typeof(audience) is distinct from 'object' or audience_type is null
    or audience_type not in ('users','team','event_role','event_all')
  then raise exception 'invalid_audience'; end if;
  -- Reject extra selectors rather than silently ignoring ambiguous audiences.
  if (audience_type='users' and (audience - array['type','user_ids']) <> '{}'::jsonb)
    or (audience_type='team' and (audience - array['type','team_id']) <> '{}'::jsonb)
    or (audience_type='event_role' and (audience - array['type','role']) <> '{}'::jsonb)
    or (audience_type='event_all' and (audience - 'type') <> '{}'::jsonb)
    or (audience_type<>'users' and target_event is null)
  then raise exception 'invalid_audience'; end if;
  if audience_type='users' then
    if jsonb_typeof(audience->'user_ids') is distinct from 'array' then raise exception 'invalid_audience'; end if;
    if jsonb_array_length(audience->'user_ids') not between 1 and 500 then raise exception 'invalid_audience'; end if;
    select array_agg(distinct value::uuid) into recipients from jsonb_array_elements_text(audience->'user_ids');
    if exists(select 1 from unnest(recipients) u(id) where u.id is null or not exists(select 1 from public.profiles p where p.id=u.id)) then
      raise exception 'invalid_audience';
    end if;
    if target_event is not null and exists (
      select 1 from unnest(recipients) u(id) where not exists (
        select 1 from public.event_roles r where r.event_id=target_event and r.user_id=u.id
      ) and not exists (
        select 1 from public.team_members m join public.teams t on t.id=m.team_id
        where m.event_id=target_event and m.user_id=u.id and m.status='active' and t.status='approved'
      )
    ) then raise exception 'forbidden'; end if;
  elsif audience_type='team' then
    target_team := (audience->>'team_id')::uuid;
    if target_team is null or not exists(select 1 from public.teams t where t.id=target_team and t.event_id=target_event and t.status='approved') then
      raise exception 'forbidden';
    end if;
    select array_agg(distinct m.user_id) into recipients from public.team_members m
    where m.team_id=target_team and m.status='active' and m.user_id is not null;
  else
    if audience_type='event_role' and coalesce(audience->>'role','') not in ('student','professor','monitor','evaluator') then
      raise exception 'invalid_audience';
    end if;
    select array_agg(distinct u.id) into recipients from (
      select r.user_id id from public.event_roles r where r.event_id=target_event
      and (audience_type='event_all' or r.role::text=audience->>'role')
      union
      select m.user_id from public.team_members m join public.teams t on t.id=m.team_id
      where m.event_id=target_event and m.status='active' and t.status='approved' and m.user_id is not null
      and (audience_type='event_all' or audience->>'role'='student')
    ) u;
  end if;
  if coalesce(cardinality(recipients),0)=0 then raise exception 'empty_audience'; end if;
  -- Action destinations are derived server-side; callers cannot inject external URLs.
  insert into public.notifications(recipient_id,event_id,team_id,title,body,created_by)
  select u.id,target_event,target_team,btrim(input->>'title'),btrim(input->>'body'),actor from unnest(recipients) u(id);
  get diagnostics recipient_count = row_count;
  return recipient_count;
exception when invalid_text_representation then raise exception 'invalid_audience';
end;
$$;

create function private.mark_notifications_read_impl(notification_ids uuid[])
returns integer language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); changed integer;
begin
  if actor is null then raise exception 'authentication_required'; end if;
  update public.notifications n set read_at=now()
  where n.recipient_id=actor and n.id=any(notification_ids) and n.read_at is null;
  get diagnostics changed = row_count;
  return changed;
end;
$$;

create function private.get_notification_inbox_impl()
returns table(id text, source text, kind text, title text, body text, event_id uuid, team_id uuid, action_path text, created_at timestamptz, read_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := auth.uid(); admin boolean;
begin
  if actor is null then raise exception 'authentication_required'; end if;
  select p.global_role='global_admin' into admin from public.profiles p where p.id=actor;
  return query
  with work as (
    select 'role:'||r.id entity, 'role_request_'||r.requested_role::text k,
      'Solicitação de acesso' t, 'Uma solicitação aguarda sua decisão.' b, r.event_id e, null::uuid tm,
      case when r.requested_role='professor' then '/app/admin/solicitacoes' else '/app/evento/'||r.event_id||'/solicitacoes' end path, r.created_at dt
    from public.role_requests r join public.events ev on ev.id=r.event_id
    where r.status='pending' and ev.status<>'archived' and (
      coalesce(admin,false) or (r.requested_role in ('monitor','evaluator') and exists(
        select 1 from public.event_roles er where er.event_id=r.event_id and er.user_id=actor and er.role='professor'
      ))
    )
    union all
    select 'join:'||m.id, 'team_join_request','Solicitação para sua equipe','Uma pessoa aguarda aprovação.',m.event_id,m.team_id,
      '/app/evento/'||m.event_id||'/equipe',m.created_at
    from public.team_members m join public.teams t on t.id=m.team_id join public.events ev on ev.id=m.event_id
    where m.status='join_requested' and t.leader_id=actor and t.status<>'rejected' and ev.status<>'archived'
    union all
    select 'review:'||s.id,'submission_review','Envio para revisar','Uma atividade aguarda revisão.',s.event_id,s.team_id,
      '/app/evento/'||s.event_id||'/revisoes',s.updated_at
    from public.submissions s join public.events ev on ev.id=s.event_id
    where ev.status<>'archived' and (s.status in ('submitted','resubmitted') or (s.status='in_review' and s.claimed_by=actor))
    and (coalesce(admin,false) or exists(select 1 from public.event_roles r where r.event_id=s.event_id and r.user_id=actor and r.role in ('professor','monitor')))
    union all
    select 'returned:'||s.id,'submission_returned','Envio devolvido','Revise sua atividade para enviar novamente.',s.event_id,s.team_id,
      '/app/evento/'||s.event_id||'/atividades/'||s.activity_id,s.updated_at
    from public.submissions s join public.events ev on ev.id=s.event_id
    where s.status='returned' and ev.status<>'archived' and exists(
      select 1 from public.team_members m where m.team_id=s.team_id and m.user_id=actor and m.status='active'
    )
    union all
    select 'evaluation:'||a.event_id||':'||ps.team_id,'evaluation_pending','Projeto para avaliar','Uma apresentação atribuída aguarda avaliação.',a.event_id,ps.team_id,
      '/app/evento/'||a.event_id||'/avaliacao/'||ps.team_id,a.assigned_at
    from public.evaluator_assignments a join public.presentation_slots ps on ps.event_id=a.event_id and ps.category=a.category
    join public.events ev on ev.id=a.event_id
    where a.evaluator_id=actor and ev.status<>'archived'
    and exists(select 1 from public.event_roles r where r.event_id=a.event_id and r.user_id=actor and r.role='evaluator')
    and not exists(select 1 from public.evaluations x where x.event_id=a.event_id and x.team_id=ps.team_id and x.evaluator_id=actor)
  )
  select n.id::text,'manual'::text,n.kind,n.title,n.body,n.event_id,n.team_id,n.action_path,n.created_at,n.read_at
  from public.notifications n where n.recipient_id=actor
  union all
  select 'automatic:'||w.entity||':'||actor,'automatic',w.k,w.t,w.b,w.e,w.tm,w.path,w.dt,null::timestamptz from work w
  order by 9 desc,1;
end;
$$;

create function public.create_manual_notifications(input jsonb) returns integer
language sql security invoker set search_path='' as $$select private.create_manual_notifications_impl(input)$$;
create function public.mark_notifications_read(notification_ids uuid[]) returns integer
language sql security invoker set search_path='' as $$select private.mark_notifications_read_impl(notification_ids)$$;
create function public.get_notification_inbox()
returns table(id text, source text, kind text, title text, body text, event_id uuid, team_id uuid, action_path text, created_at timestamptz, read_at timestamptz)
language sql stable security invoker set search_path='' as $$select * from private.get_notification_inbox_impl()$$;
revoke all on function private.create_manual_notifications_impl(jsonb), private.mark_notifications_read_impl(uuid[]), private.get_notification_inbox_impl(),
public.create_manual_notifications(jsonb), public.mark_notifications_read(uuid[]), public.get_notification_inbox() from public, anon, authenticated;
grant execute on function private.create_manual_notifications_impl(jsonb), private.mark_notifications_read_impl(uuid[]), private.get_notification_inbox_impl(),
public.create_manual_notifications(jsonb), public.mark_notifications_read(uuid[]), public.get_notification_inbox() to authenticated;

alter publication supabase_realtime add table public.notifications;
