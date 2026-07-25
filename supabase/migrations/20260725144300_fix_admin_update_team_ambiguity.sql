create or replace function public.admin_update_team(
  team_id       uuid,
  new_name      text,
  new_category  public.team_category,
  members       jsonb
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
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  select * into target_team
  from public.teams
  where id = admin_update_team.team_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'team_not_found';
  end if;

  if not (select public.is_global_admin() or public.is_event_professor(target_team.event_id)) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  if new_name is null or btrim(new_name) = '' then
    raise exception using errcode = 'P0001', message = 'team_name_required';
  end if;

  if new_category is null then
    raise exception using errcode = 'P0001', message = 'category_required';
  end if;

  update public.teams
  set
    name     = btrim(new_name),
    category = new_category
  where id = admin_update_team.team_id;

  if members is not null and jsonb_typeof(members) = 'array' then
    declare
      item jsonb;
      v_member_id uuid;
    begin
      for item in select * from jsonb_array_elements(members) loop
        v_member_id := (item->>'id')::uuid;

        if v_member_id is null then continue; end if;

        update public.team_members
        set
          name       = btrim(coalesce(item->>'name', name)),
          email      = lower(btrim(coalesce(item->>'email', email))),
          enrollment = lower(btrim(coalesce(item->>'enrollment', enrollment)))
        where id = v_member_id
          and public.team_members.team_id = admin_update_team.team_id
          and event_id = target_team.event_id;
      end loop;
    end;
  end if;
end;
$$;
