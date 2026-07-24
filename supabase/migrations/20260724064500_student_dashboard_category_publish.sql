-- Update get_student_dashboard to return a boolean indicating if the team's category
-- has published results. This is better than relying on event status, since categories
-- can be published independently.

create or replace function public.get_student_dashboard(target_event uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  caller_id  uuid := (select auth.uid());
  event_row  public.events;
  team_row   public.teams;
  slot_pos   integer;
  canvas_agg jsonb;
  eval_agg   jsonb;
  next_pos   integer;
  category_published boolean;
begin
  -- Auth check
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  select * into event_row from public.events where id = target_event;
  if not found then
    raise exception using errcode = 'P0001', message = 'event_not_found';
  end if;

  -- Resolve caller's team in this event (must be active member)
  select t.*
  into team_row
  from public.teams as t
  join public.team_members as tm
    on tm.team_id = t.id
   and tm.event_id = t.event_id
  where t.event_id = target_event
    and tm.user_id  = caller_id
    and tm.status   = 'active'
  limit 1;

  if not found then
    return jsonb_build_object(
      'event',      jsonb_build_object(
                      'slug', event_row.slug,
                      'status', event_row.status,
                      'category_published', false
                    ),
      'team',       null,
      'slot',       null,
      'canvas',     '[]'::jsonb,
      'evaluation', null
    );
  end if;

  -- Check if this team's category is published
  select exists (
    select 1
    from public.published_results as pr
    where pr.event_id = target_event
      and pr.category = team_row.category
  ) into category_published;

  -- Presentation slot
  select ps.position
  into slot_pos
  from public.presentation_slots as ps
  where ps.event_id = target_event
    and ps.team_id  = team_row.id
  limit 1;

  -- Canvas activities + submission status + latest review feedback
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'activity_id',          act.id,
        'activity_title',       act.title,
        'due_at',               act.due_at,
        'submission_status',    coalesce(sub.status, 'no_submission'),
        'last_review_decision', rev.decision,
        'last_review_feedback', rev.feedback,
        'last_review_at',       rev.created_at
      )
      order by act.due_at, act.title
    ),
    '[]'::jsonb
  )
  into canvas_agg
  from public.canvas_activities as act
  left join public.submissions as sub
    on  sub.activity_id = act.id
    and sub.team_id     = team_row.id
    and sub.event_id    = target_event
  left join lateral (
    select r.decision, r.feedback, r.created_at
    from public.submission_reviews as r
    where r.submission_id = sub.id
    order by r.created_at desc
    limit 1
  ) as rev on true
  where act.event_id  = target_event
    and act.published  = true
    and team_row.category = any(act.categories);

  -- Evaluation progress for this team
  select coalesce(
    jsonb_build_object(
      'required_evaluator_count',  p.required_evaluator_count,
      'completed_evaluator_count', p.completed_evaluator_count,
      'complete',                  p.complete
    ),
    null
  )
  into eval_agg
  from public.evaluation_progress as p
  where p.event_id = target_event
    and p.team_id  = team_row.id;

  -- Next team in queue to be evaluated (same category, not yet complete, lowest position)
  select ps2.position
  into next_pos
  from public.presentation_slots as ps2
  join public.evaluation_progress as ep2
    on  ep2.event_id = target_event
    and ep2.team_id  = ps2.team_id
    and ep2.category = team_row.category
    and ep2.complete = false
  where ps2.event_id = target_event
  order by ps2.position asc
  limit 1;

  if eval_agg is not null and next_pos is not null then
    eval_agg := eval_agg || jsonb_build_object('next_position', next_pos);
  end if;

  return jsonb_build_object(
    'event', jsonb_build_object(
      'slug',   event_row.slug,
      'status', event_row.status,
      'category_published', category_published
    ),
    'team', jsonb_build_object(
      'id',       team_row.id,
      'name',     team_row.name,
      'category', team_row.category,
      'status',   team_row.status
    ),
    'slot',       case when slot_pos is not null
                    then jsonb_build_object('position', slot_pos)
                    else null
                  end,
    'canvas',     canvas_agg,
    'evaluation', eval_agg
  );
end;
$$;
