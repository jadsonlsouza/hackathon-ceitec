create or replace function private.submit_canvas_impl(target_submission uuid)
returns public.submissions
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target public.submissions;
  target_team public.teams;
  activity public.canvas_activities;
  next_status text;
  next_revision integer;
  answer_snapshot jsonb;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  select submission.*
  into target
  from public.submissions as submission
  where submission.id = target_submission
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'submission_not_found';
  end if;

  perform 1 from public.events as event
  where event.id = target.event_id and event.status <> 'archived'
  for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'event_not_available';
  end if;

  select team.*
  into target_team
  from public.teams as team
  where team.id = target.team_id
    and team.event_id = target.event_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'cross_event_reference';
  end if;
  if not exists (
    select 1 from public.team_members as member
    where member.event_id = target.event_id
      and member.team_id = target.team_id
      and member.user_id = caller_id
      and member.status = 'active'
  ) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;
  if target_team.status <> 'approved' then
    raise exception using errcode = 'P0001', message = 'team_not_approved';
  end if;

  select canvas_activity.*
  into activity
  from public.canvas_activities as canvas_activity
  where canvas_activity.id = target.activity_id
    and canvas_activity.event_id = target.event_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'cross_event_reference';
  end if;
  if target_team.category <> all(activity.categories) then
    raise exception using errcode = 'P0001', message = 'activity_category_mismatch';
  end if;
  if not activity.published then
    raise exception using errcode = 'P0001', message = 'activity_not_published';
  end if;
  if now() < activity.opens_at then
    raise exception using errcode = 'P0001', message = 'activity_not_open';
  end if;
  if now() > activity.due_at then
    raise exception using errcode = 'P0001', message = 'activity_deadline_passed';
  end if;

  -- ALLOW 'submitted' and 'resubmitted' so students can edit their submissions
  if target.status not in ('draft', 'returned', 'submitted', 'resubmitted') then
    raise exception using errcode = 'P0001', message = 'submission_not_submittable';
  end if;
  if target.status in ('returned', 'resubmitted') and not activity.allow_resubmission then
    raise exception using errcode = 'P0001', message = 'resubmission_not_allowed';
  end if;

  next_status := case
    when target.status in ('draft', 'submitted') then 'submitted'
    else 'resubmitted'
  end;
  next_revision := case
    when target.status = 'draft' then target.revision
    else target.revision + 1
  end;

  select coalesce(
    jsonb_object_agg(block.key, coalesce(answer.content, '{}'::jsonb)
      order by block.position),
    '{}'::jsonb
  )
  into answer_snapshot
  from public.canvas_blocks as block
  left join public.submission_answers as answer
    on answer.submission_id = target.id
    and answer.block_id = block.id
  where block.activity_id = target.activity_id;

  insert into public.submission_revisions (
    submission_id, revision, snapshot, created_by
  )
  values (target.id, next_revision, answer_snapshot, caller_id);

  update public.submissions as submission
  set
    status = next_status,
    revision = next_revision,
    submitted_at = now(),
    claimed_by = null,
    claimed_at = null,
    updated_at = now()
  where submission.id = target.id
  returning * into target;

  insert into public.audit_log (
    event_id, actor_id, action, entity_type, entity_id, payload
  )
  values (
    target.event_id,
    caller_id,
    'canvas_' || next_status,
    'submission',
    target.id::text,
    jsonb_build_object(
      'activity_id', target.activity_id,
      'team_id', target.team_id,
      'revision', next_revision
    )
  );

  return target;
end;
$$;
