create function public.admin_update_event_role(
  target_user_id uuid,
  target_event_id uuid,
  new_role public.event_role -- pass null to remove role
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target_event_row public.events;
  old_role public.event_role;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  if not exists (
    select 1
    from public.profiles
    where id = caller_id
      and global_role = 'global_admin'
  ) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  -- Lock the event row to prevent concurrent role changes
  select event.*
  into target_event_row
  from public.events as event
  where event.id = target_event_id
  for update;

  if not found or target_event_row.status = 'archived' then
    raise exception using errcode = 'P0001', message = 'event_not_available';
  end if;

  -- Find existing role if any
  select role into old_role
  from public.event_roles
  where user_id = target_user_id
    and event_id = target_event_id;

  if old_role = new_role then
    return; -- Nothing to do
  end if;

  -- Delete existing role
  if old_role is not null then
    delete from public.event_roles
    where user_id = target_user_id
      and event_id = target_event_id;

    if old_role = 'professor' then
      update public.events
      set professor_id = null
      where id = target_event_id;
    end if;
  end if;

  -- Insert new role if one is provided
  if new_role is not null then
    insert into public.event_roles (
      event_id,
      user_id,
      role,
      approved_by
    )
    values (
      target_event_id,
      target_user_id,
      new_role,
      caller_id
    );

    if new_role = 'professor' then
      -- If there is an existing professor, their role must have been replaced.
      -- To simplify, we remove the existing professor if they exist.
      with revoked as (
        delete from public.event_roles
        where event_id = target_event_id
          and role = 'professor'
          and user_id <> target_user_id
        returning user_id
      )
      insert into public.audit_log (event_id, actor_id, action, entity_type, entity_id, payload)
      select target_event_id, caller_id, 'event_professor_replaced', 'event_role', revoked.user_id::text, jsonb_build_object('replacement_user_id', target_user_id, 'role', 'professor')
      from revoked;

      update public.events
      set professor_id = target_user_id
      where id = target_event_id;
    end if;
  end if;

  insert into public.audit_log (
    event_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    payload
  )
  values (
    target_event_id,
    caller_id,
    'admin_changed_role',
    'event_role',
    target_user_id::text,
    jsonb_build_object('old_role', old_role, 'new_role', new_role)
  );

end;
$$;

revoke all on function public.admin_update_event_role(uuid, uuid, public.event_role) from public, anon, authenticated, service_role;
grant execute on function public.admin_update_event_role(uuid, uuid, public.event_role) to authenticated;
