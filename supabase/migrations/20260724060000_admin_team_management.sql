-- RPC: admin_update_team
-- Allows the event professor (or global_admin) to update a team's name,
-- category, member names/emails/enrollments. Members are identified by ID;
-- the update is an in-place patch rather than a full replace so existing
-- user_id / status linkages are preserved.

create function public.admin_update_team(
  team_id     uuid,
  new_name    text,
  new_category public.team_category,
  members     jsonb   -- [{id: uuid, name: text, email: text, enrollment: text}]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target_team public.teams;
begin
  -- Auth check
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  -- Load & lock the team
  select * into target_team
  from public.teams
  where id = team_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'team_not_found';
  end if;

  -- Professor / global-admin check
  if not (select public.is_event_professor(target_team.event_id)) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  -- Validate name
  if new_name is null or btrim(new_name) = '' then
    raise exception using errcode = 'P0001', message = 'team_name_required';
  end if;

  if new_category is null then
    raise exception using errcode = 'P0001', message = 'category_required';
  end if;

  -- Update team header
  update public.teams
  set
    name     = btrim(new_name),
    category = new_category
  where id = team_id;

  -- Update each member row that was supplied
  if members is not null and jsonb_typeof(members) = 'array' then
    declare
      item jsonb;
      member_id uuid;
    begin
      for item in select * from jsonb_array_elements(members) loop
        member_id := (item->>'id')::uuid;

        if member_id is null then continue; end if;

        update public.team_members
        set
          name       = btrim(coalesce(item->>'name', name)),
          email      = lower(btrim(coalesce(item->>'email', email))),
          enrollment = lower(btrim(coalesce(item->>'enrollment', enrollment)))
        where id = member_id
          and team_id = team_id
          and event_id = target_team.event_id;
      end loop;
    end;
  end if;
end;
$$;

grant execute on function public.admin_update_team(uuid, text, public.team_category, jsonb)
  to authenticated;

comment on function public.admin_update_team is
  'Privileged Professor / global-admin team update.';
