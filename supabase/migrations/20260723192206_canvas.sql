create table public.canvas_templates (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id),
  name text not null,
  instructions text not null default '',
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  constraint canvas_templates_id_event_key unique (id, event_id),
  constraint canvas_templates_event_name_key unique (event_id, name),
  constraint canvas_templates_name_normalized check (
    name = btrim(name) and name <> ''
  )
);

create index canvas_templates_event_id_idx
  on public.canvas_templates (event_id);
create index canvas_templates_created_by_idx
  on public.canvas_templates (created_by);

create table public.canvas_template_blocks (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.canvas_templates(id)
    on delete cascade,
  key text not null,
  title text not null,
  prompt text not null,
  position integer not null,
  max_items integer,
  constraint canvas_template_blocks_template_key_key
    unique (template_id, key),
  constraint canvas_template_blocks_template_position_key
    unique (template_id, position),
  constraint canvas_template_blocks_key_normalized check (
    key = btrim(key) and key <> ''
  ),
  constraint canvas_template_blocks_title_normalized check (
    title = btrim(title) and title <> ''
  ),
  constraint canvas_template_blocks_position_positive check (position > 0),
  constraint canvas_template_blocks_max_items_positive check (
    max_items is null or max_items > 0
  )
);

create index canvas_template_blocks_template_id_idx
  on public.canvas_template_blocks (template_id);

create table public.canvas_activities (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id),
  template_id uuid,
  title text not null,
  instructions text not null default '',
  categories public.team_category[] not null,
  opens_at timestamptz not null,
  due_at timestamptz not null,
  published boolean not null default false,
  is_primary boolean not null default false,
  allow_resubmission boolean not null default true,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  constraint canvas_activities_id_event_key unique (id, event_id),
  constraint canvas_activities_template_event_fkey
    foreign key (template_id, event_id)
    references public.canvas_templates(id, event_id),
  constraint canvas_activities_title_normalized check (
    title = btrim(title) and title <> ''
  ),
  constraint canvas_activities_window_valid check (due_at > opens_at),
  constraint canvas_activities_categories_present check (
    cardinality(categories) > 0
  )
);

create index canvas_activities_event_id_idx
  on public.canvas_activities (event_id);
create index canvas_activities_template_id_idx
  on public.canvas_activities (template_id)
  where template_id is not null;
create index canvas_activities_created_by_idx
  on public.canvas_activities (created_by);
create index canvas_activities_visible_idx
  on public.canvas_activities (event_id, opens_at, due_at)
  where published;
create unique index one_primary_canvas_activity_per_event_category_set
  on public.canvas_activities (event_id, categories)
  where is_primary;

create table public.canvas_blocks (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.canvas_activities(id)
    on delete cascade,
  key text not null,
  title text not null,
  prompt text not null,
  position integer not null,
  max_items integer,
  constraint canvas_blocks_activity_key_key unique (activity_id, key),
  constraint canvas_blocks_activity_position_key unique (activity_id, position),
  constraint canvas_blocks_key_normalized check (
    key = btrim(key) and key <> ''
  ),
  constraint canvas_blocks_title_normalized check (
    title = btrim(title) and title <> ''
  ),
  constraint canvas_blocks_position_positive check (position > 0),
  constraint canvas_blocks_max_items_positive check (
    max_items is null or max_items > 0
  )
);

create index canvas_blocks_activity_id_idx
  on public.canvas_blocks (activity_id);

create table public.submissions (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id),
  activity_id uuid not null,
  team_id uuid not null,
  status text not null default 'draft',
  revision integer not null default 1,
  submitted_at timestamptz,
  claimed_by uuid references public.profiles(id),
  claimed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint submissions_activity_event_fkey
    foreign key (activity_id, event_id)
    references public.canvas_activities(id, event_id),
  constraint submissions_team_event_fkey
    foreign key (team_id, event_id)
    references public.teams(id, event_id),
  constraint submissions_activity_team_key unique (activity_id, team_id),
  constraint submissions_status_valid check (
    status in (
      'draft', 'submitted', 'in_review', 'returned',
      'resubmitted', 'approved'
    )
  ),
  constraint submissions_revision_positive check (revision > 0),
  constraint submissions_claim_consistent check (
    (claimed_by is null and claimed_at is null)
    or (
      status = 'in_review'
      and claimed_by is not null
      and claimed_at is not null
    )
  )
);

create index submissions_event_id_idx on public.submissions (event_id);
create index submissions_activity_id_idx on public.submissions (activity_id);
create index submissions_team_id_idx on public.submissions (team_id);
create index submissions_claimed_by_idx on public.submissions (claimed_by)
  where claimed_by is not null;
create index submissions_review_queue_idx
  on public.submissions (event_id, submitted_at)
  where status in ('submitted', 'resubmitted', 'in_review');

create table public.submission_answers (
  submission_id uuid not null references public.submissions(id)
    on delete cascade,
  block_id uuid not null references public.canvas_blocks(id),
  content jsonb not null default '{}',
  version integer not null default 1,
  updated_by uuid not null references public.profiles(id),
  updated_at timestamptz not null default now(),
  primary key (submission_id, block_id),
  constraint submission_answers_version_positive check (version > 0)
);

create index submission_answers_block_id_idx
  on public.submission_answers (block_id);
create index submission_answers_updated_by_idx
  on public.submission_answers (updated_by);

create table public.submission_revisions (
  submission_id uuid not null references public.submissions(id)
    on delete cascade,
  revision integer not null,
  snapshot jsonb not null,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  primary key (submission_id, revision),
  constraint submission_revisions_revision_positive check (revision > 0)
);

create index submission_revisions_created_by_idx
  on public.submission_revisions (created_by);

create table public.submission_reviews (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.submissions(id)
    on delete cascade,
  reviewer_id uuid not null references public.profiles(id),
  decision text not null,
  feedback text,
  created_at timestamptz not null default now(),
  constraint submission_reviews_decision_valid check (
    decision in ('approved', 'returned', 'reopened')
  ),
  constraint submission_reviews_feedback_normalized check (
    feedback is null or (feedback = btrim(feedback) and feedback <> '')
  )
);

create index submission_reviews_submission_id_idx
  on public.submission_reviews (submission_id);
create index submission_reviews_reviewer_id_idx
  on public.submission_reviews (reviewer_id);

create view private.current_canvas_team_access
with (security_barrier = true)
as
select distinct
  member.event_id,
  member.team_id,
  (select auth.uid()) as user_id
from public.team_members as member
join public.events as event on event.id = member.event_id
where (select auth.uid()) is not null
  and member.user_id = (select auth.uid())
  and member.status = 'active'
  and event.status <> 'archived';

create view private.current_canvas_review_access
with (security_barrier = true)
as
select
  event.id as event_id,
  (select auth.uid()) as user_id
from public.events as event
where (select auth.uid()) is not null
  and event.status <> 'archived'
  and (
    event.professor_id = (select auth.uid())
    or exists (
      select 1
      from public.event_roles as role_assignment
      where role_assignment.event_id = event.id
        and role_assignment.user_id = (select auth.uid())
        and role_assignment.role = 'monitor'
    )
  );

revoke all on table
  private.current_canvas_team_access,
  private.current_canvas_review_access
from public, anon, authenticated, service_role;
grant select on table
  private.current_canvas_team_access,
  private.current_canvas_review_access
to authenticated;

create function private.set_canvas_creator()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
begin
  if tg_op = 'INSERT' and caller_id is not null then
    new.created_by := caller_id;
  elsif tg_op = 'UPDATE' then
    if new.created_by is distinct from old.created_by
      or new.event_id is distinct from old.event_id
    then
      raise exception using
        errcode = 'P0001',
        message = 'immutable_activity_ownership';
    end if;
  end if;

  return new;
end;
$$;

create trigger set_canvas_template_creator
before insert or update on public.canvas_templates
for each row execute function private.set_canvas_creator();

create trigger set_canvas_activity_creator
before insert or update on public.canvas_activities
for each row execute function private.set_canvas_creator();

create function private.copy_canvas_template_blocks()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.template_id is not null then
    insert into public.canvas_blocks (
      activity_id, key, title, prompt, position, max_items
    )
    select
      new.id, block.key, block.title, block.prompt, block.position,
      block.max_items
    from public.canvas_template_blocks as block
    where block.template_id = new.template_id
    order by block.position;
  end if;

  return new;
end;
$$;

create trigger copy_canvas_template_blocks
after insert on public.canvas_activities
for each row execute function private.copy_canvas_template_blocks();

create function private.assert_canvas_answer_scope()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.submissions as submission
    join public.canvas_blocks as block
      on block.activity_id = submission.activity_id
    where submission.id = new.submission_id
      and block.id = new.block_id
  ) then
    raise exception using errcode = 'P0001', message = 'block_not_in_activity';
  end if;

  return new;
end;
$$;

create trigger assert_canvas_answer_scope
before insert or update on public.submission_answers
for each row execute function private.assert_canvas_answer_scope();

alter table public.canvas_templates enable row level security;
alter table public.canvas_template_blocks enable row level security;
alter table public.canvas_activities enable row level security;
alter table public.canvas_blocks enable row level security;
alter table public.submissions enable row level security;
alter table public.submission_answers enable row level security;
alter table public.submission_revisions enable row level security;
alter table public.submission_reviews enable row level security;

create policy "templates visible to event reviewers"
on public.canvas_templates for select to authenticated
using (
  exists (
    select 1 from private.current_canvas_review_access as access
    where access.event_id = canvas_templates.event_id
      and access.user_id = (select auth.uid())
  )
);

create policy "Professors create templates"
on public.canvas_templates for insert to authenticated
with check (
  created_by = (select auth.uid())
  and (select public.is_event_professor(event_id))
  and exists (
    select 1 from public.events as event
    where event.id = canvas_templates.event_id
      and event.status <> 'archived'
  )
);

create policy "Professors update templates"
on public.canvas_templates for update to authenticated
using (
  (select public.is_event_professor(event_id))
  and exists (
    select 1 from public.events as event
    where event.id = canvas_templates.event_id
      and event.status <> 'archived'
  )
)
with check (
  created_by is not null
  and (select public.is_event_professor(event_id))
  and exists (
    select 1 from public.events as event
    where event.id = canvas_templates.event_id
      and event.status <> 'archived'
  )
);

create policy "template blocks visible to event reviewers"
on public.canvas_template_blocks for select to authenticated
using (
  exists (
    select 1
    from public.canvas_templates as template
    join private.current_canvas_review_access as access
      on access.event_id = template.event_id
      and access.user_id = (select auth.uid())
    where template.id = canvas_template_blocks.template_id
  )
);

create policy "Professors create template blocks"
on public.canvas_template_blocks for insert to authenticated
with check (
  exists (
    select 1 from public.canvas_templates as template
    where template.id = canvas_template_blocks.template_id
      and (select public.is_event_professor(template.event_id))
      and exists (
        select 1 from public.events as event
        where event.id = template.event_id
          and event.status <> 'archived'
      )
  )
);

create policy "Professors update template blocks"
on public.canvas_template_blocks for update to authenticated
using (
  exists (
    select 1 from public.canvas_templates as template
    where template.id = canvas_template_blocks.template_id
      and (select public.is_event_professor(template.event_id))
  )
)
with check (
  exists (
    select 1 from public.canvas_templates as template
    where template.id = canvas_template_blocks.template_id
      and (select public.is_event_professor(template.event_id))
      and exists (
        select 1 from public.events as event
        where event.id = template.event_id
          and event.status <> 'archived'
      )
  )
);

create policy "activities visible to scoped users"
on public.canvas_activities for select to authenticated
using (
  exists (
    select 1 from private.current_canvas_review_access as access
    where access.event_id = canvas_activities.event_id
      and access.user_id = (select auth.uid())
  )
  or (
    published
    and exists (
      select 1
      from private.current_canvas_team_access as access
      join public.teams as team
        on team.id = access.team_id
        and team.event_id = access.event_id
      where access.event_id = canvas_activities.event_id
        and access.user_id = (select auth.uid())
        and team.category = any(canvas_activities.categories)
    )
  )
);

create policy "Professors create activities"
on public.canvas_activities for insert to authenticated
with check (
  created_by = (select auth.uid())
  and (select public.is_event_professor(event_id))
  and exists (
    select 1 from public.events as event
    where event.id = canvas_activities.event_id
      and event.status <> 'archived'
  )
);

create policy "Professors update activities"
on public.canvas_activities for update to authenticated
using (
  (select public.is_event_professor(event_id))
  and exists (
    select 1 from public.events as event
    where event.id = canvas_activities.event_id
      and event.status <> 'archived'
  )
)
with check (
  (select public.is_event_professor(event_id))
  and exists (
    select 1 from public.events as event
    where event.id = canvas_activities.event_id
      and event.status <> 'archived'
  )
);

create policy "activity blocks visible with activity"
on public.canvas_blocks for select to authenticated
using (
  exists (
    select 1 from public.canvas_activities as activity
    where activity.id = canvas_blocks.activity_id
  )
);

create policy "submissions visible to teams and reviewers"
on public.submissions for select to authenticated
using (
  exists (
    select 1 from private.current_canvas_team_access as access
    where access.team_id = submissions.team_id
      and access.event_id = submissions.event_id
      and access.user_id = (select auth.uid())
  )
  or exists (
    select 1 from private.current_canvas_review_access as access
    where access.event_id = submissions.event_id
      and access.user_id = (select auth.uid())
  )
);

create policy "team members create draft submissions"
on public.submissions for insert to authenticated
with check (
  status = 'draft'
  and revision = 1
  and submitted_at is null
  and claimed_by is null
  and claimed_at is null
  and exists (
    select 1 from private.current_canvas_team_access as access
    where access.team_id = submissions.team_id
      and access.event_id = submissions.event_id
      and access.user_id = (select auth.uid())
  )
  and exists (
    select 1
    from public.canvas_activities as activity
    join public.teams as team
      on team.id = submissions.team_id
      and team.event_id = submissions.event_id
    where activity.id = submissions.activity_id
      and activity.event_id = submissions.event_id
      and team.category = any(activity.categories)
  )
);

create policy "answers visible to teams and reviewers"
on public.submission_answers for select to authenticated
using (
  exists (
    select 1 from public.submissions as submission
    where submission.id = submission_answers.submission_id
  )
);

create policy "revisions visible to teams and reviewers"
on public.submission_revisions for select to authenticated
using (
  exists (
    select 1 from public.submissions as submission
    where submission.id = submission_revisions.submission_id
  )
);

create policy "reviews visible to teams and reviewers"
on public.submission_reviews for select to authenticated
using (
  exists (
    select 1 from public.submissions as submission
    where submission.id = submission_reviews.submission_id
  )
);

revoke all on table
  public.canvas_templates,
  public.canvas_template_blocks,
  public.canvas_activities,
  public.canvas_blocks,
  public.submissions,
  public.submission_answers,
  public.submission_revisions,
  public.submission_reviews
from public, anon, authenticated, service_role;

grant select on table
  public.canvas_templates,
  public.canvas_template_blocks,
  public.canvas_activities,
  public.canvas_blocks,
  public.submissions,
  public.submission_answers,
  public.submission_revisions,
  public.submission_reviews
to authenticated;

grant insert (event_id, name, instructions),
  update (name, instructions)
on public.canvas_templates to authenticated;
grant insert (template_id, key, title, prompt, position, max_items),
  update (key, title, prompt, position, max_items)
on public.canvas_template_blocks to authenticated;
grant insert (
    event_id, template_id, title, instructions, categories, opens_at, due_at,
    published, is_primary, allow_resubmission
  ),
  update (
    title, instructions, categories, opens_at, due_at, published, is_primary,
    allow_resubmission
  )
on public.canvas_activities to authenticated;
grant insert (event_id, activity_id, team_id)
on public.submissions to authenticated;

create function private.save_canvas_answer_impl(
  target_submission uuid,
  target_block uuid,
  target_content jsonb,
  expected_version integer
)
returns public.submission_answers
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target public.submissions;
  answer public.submission_answers;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;
  if expected_version is null or expected_version < 0 then
    raise exception using errcode = 'P0001', message = 'invalid_expected_version';
  end if;
  if target_content is null then
    raise exception using errcode = 'P0001', message = 'answer_content_required';
  end if;

  select submission.*
  into target
  from public.submissions as submission
  where submission.id = target_submission
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'submission_not_found';
  end if;
  if not exists (
    select 1 from public.events as event
    where event.id = target.event_id and event.status <> 'archived'
  ) then
    raise exception using errcode = 'P0001', message = 'event_not_available';
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
  if target.status not in ('draft', 'returned') then
    raise exception using errcode = 'P0001', message = 'submission_not_editable';
  end if;
  if not exists (
    select 1 from public.canvas_blocks as block
    where block.id = target_block
      and block.activity_id = target.activity_id
  ) then
    raise exception using errcode = 'P0001', message = 'block_not_in_activity';
  end if;

  select stored.*
  into answer
  from public.submission_answers as stored
  where stored.submission_id = target.id
    and stored.block_id = target_block;

  if found then
    update public.submission_answers as stored
    set
      content = target_content,
      version = stored.version + 1,
      updated_by = caller_id,
      updated_at = now()
    where stored.submission_id = target.id
      and stored.block_id = target_block
      and stored.version = expected_version
    returning * into answer;

    if not found then
      raise exception using errcode = 'P0001', message = 'version_conflict';
    end if;
  else
    if expected_version <> 0 then
      raise exception using errcode = 'P0001', message = 'version_conflict';
    end if;

    insert into public.submission_answers (
      submission_id, block_id, content, version, updated_by
    )
    values (target.id, target_block, target_content, 1, caller_id)
    returning * into answer;
  end if;

  return answer;
end;
$$;

create function private.submit_canvas_impl(target_submission uuid)
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
  if target.status not in ('draft', 'returned') then
    raise exception using errcode = 'P0001', message = 'submission_not_submittable';
  end if;
  if target.status = 'returned' and not activity.allow_resubmission then
    raise exception using errcode = 'P0001', message = 'resubmission_not_allowed';
  end if;

  next_status := case
    when target.status = 'draft' then 'submitted'
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

create function private.claim_review_impl(target_submission uuid)
returns public.submissions
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target public.submissions;
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
  if not exists (
    select 1 from public.events as event
    where event.id = target.event_id and event.status <> 'archived'
  ) then
    raise exception using errcode = 'P0001', message = 'event_not_available';
  end if;
  if not (
    exists (
      select 1 from public.events as event
      where event.id = target.event_id
        and event.professor_id = caller_id
    )
    or exists (
      select 1 from public.event_roles as role_assignment
      where role_assignment.event_id = target.event_id
        and role_assignment.user_id = caller_id
        and role_assignment.role = 'monitor'
    )
  ) then
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;

  if target.status = 'in_review'
    and target.claimed_at > now() - interval '15 minutes'
  then
    raise exception using errcode = 'P0001', message = 'review_already_claimed';
  end if;
  if target.status not in ('submitted', 'resubmitted', 'in_review') then
    raise exception using errcode = 'P0001', message = 'submission_not_reviewable';
  end if;
  if target.status = 'in_review'
    and (
      target.claimed_at is null
      or target.claimed_at > now() - interval '15 minutes'
    )
  then
    raise exception using errcode = 'P0001', message = 'review_already_claimed';
  end if;

  update public.submissions as submission
  set
    status = 'in_review',
    claimed_by = caller_id,
    claimed_at = now(),
    updated_at = now()
  where submission.id = target.id
  returning * into target;

  insert into public.audit_log (
    event_id, actor_id, action, entity_type, entity_id
  )
  values (
    target.event_id, caller_id, 'canvas_review_claimed',
    'submission', target.id::text
  );

  return target;
end;
$$;

create function private.decide_submission_impl(
  target_submission uuid,
  target_decision text,
  target_feedback text default null
)
returns public.submissions
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target public.submissions;
  normalized_feedback text := nullif(btrim(target_feedback), '');
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;
  if target_decision is null
    or target_decision not in ('approved', 'returned')
  then
    raise exception using errcode = 'P0001', message = 'invalid_decision';
  end if;

  select submission.*
  into target
  from public.submissions as submission
  where submission.id = target_submission
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'submission_not_found';
  end if;
  if not exists (
    select 1 from public.events as event
    where event.id = target.event_id and event.status <> 'archived'
  ) then
    raise exception using errcode = 'P0001', message = 'event_not_available';
  end if;
  if target.status <> 'in_review'
    or target.claimed_by is distinct from caller_id
  then
    raise exception using errcode = 'P0001', message = 'not_active_claimant';
  end if;
  if target.claimed_at <= now() - interval '15 minutes' then
    raise exception using errcode = 'P0001', message = 'review_claim_expired';
  end if;

  insert into public.submission_reviews (
    submission_id, reviewer_id, decision, feedback
  )
  values (
    target.id, caller_id, target_decision, normalized_feedback
  );

  update public.submissions as submission
  set
    status = target_decision,
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
    'canvas_' || target_decision,
    'submission',
    target.id::text,
    jsonb_build_object('revision', target.revision)
  );

  return target;
end;
$$;

create function private.reopen_submission_impl(
  target_submission uuid,
  target_reason text
)
returns public.submissions
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target public.submissions;
  normalized_reason text := nullif(btrim(target_reason), '');
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;
  if normalized_reason is null then
    raise exception using errcode = 'P0001', message = 'reopen_reason_required';
  end if;

  select submission.*
  into target
  from public.submissions as submission
  where submission.id = target_submission
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'submission_not_found';
  end if;
  if not exists (
    select 1 from public.events as event
    where event.id = target.event_id
      and event.status <> 'archived'
      and event.professor_id = caller_id
  ) then
    if exists (
      select 1 from public.events as event
      where event.id = target.event_id and event.status = 'archived'
    ) then
      raise exception using errcode = 'P0001', message = 'event_not_available';
    end if;
    raise exception using errcode = 'P0001', message = 'forbidden';
  end if;
  if target.status <> 'approved' then
    raise exception using errcode = 'P0001', message = 'submission_not_approved';
  end if;

  insert into public.submission_reviews (
    submission_id, reviewer_id, decision, feedback
  )
  values (target.id, caller_id, 'reopened', normalized_reason);

  update public.submissions as submission
  set
    status = 'returned',
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
    'canvas_reopened',
    'submission',
    target.id::text,
    jsonb_build_object('reason', normalized_reason)
  );

  return target;
end;
$$;

create view private.canvas_workflow_dispatch
with (security_invoker = true)
as
select
  null::text as operation,
  null::uuid as submission_id,
  null::uuid as block_id,
  null::jsonb as content,
  null::integer as expected_version,
  null::text as decision,
  null::text as feedback,
  null::text as reason,
  null::public.submissions as submission_result,
  null::public.submission_answers as answer_result
where false;

create function private.dispatch_canvas_workflow()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.operation = 'save_canvas_answer' then
    new.answer_result := private.save_canvas_answer_impl(
      new.submission_id,
      new.block_id,
      new.content,
      new.expected_version
    );
  elsif new.operation = 'submit_canvas' then
    new.submission_result := private.submit_canvas_impl(new.submission_id);
  elsif new.operation = 'claim_review' then
    new.submission_result := private.claim_review_impl(new.submission_id);
  elsif new.operation = 'decide_submission' then
    new.submission_result := private.decide_submission_impl(
      new.submission_id,
      new.decision,
      new.feedback
    );
  elsif new.operation = 'reopen_submission' then
    new.submission_result := private.reopen_submission_impl(
      new.submission_id,
      new.reason
    );
  else
    raise exception using errcode = 'P0001', message = 'invalid_operation';
  end if;

  return new;
end;
$$;

create trigger dispatch_canvas_workflow
instead of insert on private.canvas_workflow_dispatch
for each row execute function private.dispatch_canvas_workflow();

create function public.save_canvas_answer(
  submission_id uuid,
  block_id uuid,
  content jsonb,
  expected_version integer
)
returns public.submission_answers
language plpgsql
security invoker
set search_path = ''
as $$
declare
  answer public.submission_answers;
begin
  insert into private.canvas_workflow_dispatch (
    operation, submission_id, block_id, content, expected_version
  )
  values (
    'save_canvas_answer', submission_id, block_id, content, expected_version
  )
  returning (answer_result).* into answer;

  return answer;
end;
$$;

create function public.submit_canvas(submission_id uuid)
returns public.submissions
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target public.submissions;
begin
  insert into private.canvas_workflow_dispatch (operation, submission_id)
  values ('submit_canvas', submission_id)
  returning (submission_result).* into target;

  return target;
end;
$$;

create function public.claim_review(submission_id uuid)
returns public.submissions
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target public.submissions;
begin
  insert into private.canvas_workflow_dispatch (operation, submission_id)
  values ('claim_review', submission_id)
  returning (submission_result).* into target;

  return target;
end;
$$;

create function public.decide_submission(
  submission_id uuid,
  decision text,
  feedback text default null
)
returns public.submissions
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target public.submissions;
begin
  insert into private.canvas_workflow_dispatch (
    operation, submission_id, decision, feedback
  )
  values ('decide_submission', submission_id, decision, feedback)
  returning (submission_result).* into target;

  return target;
end;
$$;

create function public.reopen_submission(
  submission_id uuid,
  reason text
)
returns public.submissions
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target public.submissions;
begin
  insert into private.canvas_workflow_dispatch (
    operation, submission_id, reason
  )
  values ('reopen_submission', submission_id, reason)
  returning (submission_result).* into target;

  return target;
end;
$$;

revoke all on function
  private.set_canvas_creator(),
  private.copy_canvas_template_blocks(),
  private.assert_canvas_answer_scope(),
  private.save_canvas_answer_impl(uuid, uuid, jsonb, integer),
  private.submit_canvas_impl(uuid),
  private.claim_review_impl(uuid),
  private.decide_submission_impl(uuid, text, text),
  private.reopen_submission_impl(uuid, text),
  private.dispatch_canvas_workflow()
from public, anon, authenticated, service_role;

revoke all on table private.canvas_workflow_dispatch
from public, anon, authenticated, service_role;

grant insert (
  operation, submission_id, block_id, content, expected_version,
  decision, feedback, reason
) on private.canvas_workflow_dispatch to authenticated;
grant select (submission_result, answer_result)
on private.canvas_workflow_dispatch to authenticated;

revoke all on function
  public.save_canvas_answer(uuid, uuid, jsonb, integer),
  public.submit_canvas(uuid),
  public.claim_review(uuid),
  public.decide_submission(uuid, text, text),
  public.reopen_submission(uuid, text)
from public, anon, authenticated, service_role;

grant execute on function
  public.save_canvas_answer(uuid, uuid, jsonb, integer),
  public.submit_canvas(uuid),
  public.claim_review(uuid),
  public.decide_submission(uuid, text, text),
  public.reopen_submission(uuid, text)
to authenticated;

comment on function private.save_canvas_answer_impl(uuid, uuid, jsonb, integer)
is 'Privileged optimistic Canvas answer save implementation.';
comment on function private.submit_canvas_impl(uuid)
is 'Privileged event-locked Canvas submission implementation.';
comment on function private.claim_review_impl(uuid)
is 'Privileged atomic 15-minute review claim implementation.';
comment on function private.decide_submission_impl(uuid, text, text)
is 'Privileged active-claim review decision implementation.';
comment on function private.reopen_submission_impl(uuid, text)
is 'Privileged assigned-Professor submission reopen implementation.';
comment on view private.canvas_workflow_dispatch
is 'Non-exposed invoker bridge to privileged Canvas workflow triggers.';
