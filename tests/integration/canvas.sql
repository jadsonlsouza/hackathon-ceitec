begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;

select plan(71);

select has_table('public', 'canvas_templates', 'Canvas templates exist');
select has_table('public', 'canvas_template_blocks', 'template blocks exist');
select has_table('public', 'canvas_activities', 'Canvas activities exist');
select has_table('public', 'canvas_blocks', 'immutable activity blocks exist');
select has_table('public', 'submissions', 'submissions exist');
select has_table('public', 'submission_answers', 'versioned answers exist');
select has_table('public', 'submission_revisions', 'submission revisions exist');
select has_table('public', 'submission_reviews', 'submission reviews exist');

select has_function('public', 'save_canvas_answer',
  array['uuid', 'uuid', 'jsonb', 'integer'], 'answer save RPC exists');
select has_function('public', 'submit_canvas',
  array['uuid'], 'submit RPC exists');
select has_function('public', 'claim_review',
  array['uuid'], 'review claim RPC exists');
select has_function('public', 'decide_submission',
  array['uuid', 'text', 'text'], 'review decision RPC exists');
select has_function('public', 'reopen_submission',
  array['uuid', 'text'], 'reopen RPC exists');

select is(
  (
    select count(*)::integer
    from pg_proc as function
    join pg_namespace as namespace on namespace.oid = function.pronamespace
    where namespace.nspname = 'public'
      and function.proname in (
        'save_canvas_answer', 'submit_canvas', 'claim_review',
        'decide_submission', 'reopen_submission'
      )
      and not function.prosecdef
      and function.proconfig @> array['search_path=""']
  ),
  5,
  'public Canvas RPCs are invoker wrappers with empty search paths'
);

select is(
  (
    select count(*)::integer
    from pg_proc as function
    join pg_namespace as namespace on namespace.oid = function.pronamespace
    where namespace.nspname = 'private'
      and function.proname in (
        'save_canvas_answer_impl', 'submit_canvas_impl', 'claim_review_impl',
        'decide_submission_impl', 'reopen_submission_impl'
      )
      and function.prosecdef
      and function.proconfig @> array['search_path=""']
      and not has_function_privilege('authenticated', function.oid, 'execute')
  ),
  5,
  'private Canvas implementations are inaccessible fixed-path definers'
);

select ok(
  (
    select bool_and(class.relrowsecurity)
    from pg_class as class
    join pg_namespace as namespace on namespace.oid = class.relnamespace
    where namespace.nspname = 'public'
      and class.relname in (
        'canvas_templates', 'canvas_template_blocks', 'canvas_activities',
        'canvas_blocks', 'submissions', 'submission_answers',
        'submission_revisions', 'submission_reviews'
      )
  ),
  'RLS is enabled on every Canvas table'
);

select ok(
  has_table_privilege('authenticated', 'public.submissions', 'select')
  and has_column_privilege(
    'authenticated', 'public.submissions', 'event_id', 'insert'
  )
  and has_column_privilege(
    'authenticated', 'public.submissions', 'activity_id', 'insert'
  )
  and has_column_privilege(
    'authenticated', 'public.submissions', 'team_id', 'insert'
  )
  and not has_column_privilege(
    'authenticated', 'public.submissions', 'status', 'insert'
  )
  and not has_table_privilege('authenticated', 'public.submissions', 'update')
  and not has_table_privilege('authenticated', 'public.submissions', 'delete'),
  'submission table writes expose only safe draft creation'
);

select ok(
  not has_function_privilege(
    'anon', 'public.save_canvas_answer(uuid,uuid,jsonb,integer)', 'execute'
  ),
  'anonymous callers cannot save answers'
);

select ok(
  has_function_privilege(
    'authenticated', 'public.save_canvas_answer(uuid,uuid,jsonb,integer)', 'execute'
  )
  and has_function_privilege(
    'authenticated', 'public.submit_canvas(uuid)', 'execute'
  )
  and has_function_privilege(
    'authenticated', 'public.claim_review(uuid)', 'execute'
  ),
  'authenticated callers can execute the Canvas workflow wrappers'
);

insert into auth.users (id, email, raw_user_meta_data)
values
  ('00000000-0000-4000-8000-000000000101', 'canvas-leader@example.test',
    '{"full_name":"Canvas Leader"}'::jsonb),
  ('00000000-0000-4000-8000-000000000102', 'pending-leader@example.test',
    '{"full_name":"Pending Leader"}'::jsonb),
  ('00000000-0000-4000-8000-000000000103', 'canvas-professor@example.test',
    '{"full_name":"Canvas Professor"}'::jsonb),
  ('00000000-0000-4000-8000-000000000104', 'canvas-monitor@example.test',
    '{"full_name":"Canvas Monitor"}'::jsonb),
  ('00000000-0000-4000-8000-000000000105', 'canvas-outsider@example.test',
    '{"full_name":"Canvas Outsider"}'::jsonb),
  ('00000000-0000-4000-8000-000000000106', 'other-professor@example.test',
    '{"full_name":"Other Professor"}'::jsonb);

insert into public.events (
  id, name, slug, status, professor_id, created_by
)
values
  ('10000000-0000-4000-8000-000000000101', 'Canvas Event',
    'canvas-event', 'in_progress',
    '00000000-0000-4000-8000-000000000103',
    '00000000-0000-4000-8000-000000000103'),
  ('10000000-0000-4000-8000-000000000102', 'Other Canvas Event',
    'other-canvas-event', 'in_progress',
    '00000000-0000-4000-8000-000000000106',
    '00000000-0000-4000-8000-000000000106');

insert into public.event_roles (event_id, user_id, role, approved_by)
values
  ('10000000-0000-4000-8000-000000000101',
    '00000000-0000-4000-8000-000000000103', 'professor',
    '00000000-0000-4000-8000-000000000103'),
  ('10000000-0000-4000-8000-000000000101',
    '00000000-0000-4000-8000-000000000104', 'monitor',
    '00000000-0000-4000-8000-000000000103'),
  ('10000000-0000-4000-8000-000000000102',
    '00000000-0000-4000-8000-000000000106', 'professor',
    '00000000-0000-4000-8000-000000000106');

insert into public.teams (
  id, event_id, name, category, leader_id, status, decided_by, decided_at
)
values
  ('20000000-0000-4000-8000-000000000101',
    '10000000-0000-4000-8000-000000000101', 'Approved Canvas Team',
    'junior', '00000000-0000-4000-8000-000000000101', 'approved',
    '00000000-0000-4000-8000-000000000103', now()),
  ('20000000-0000-4000-8000-000000000102',
    '10000000-0000-4000-8000-000000000101', 'Pending Canvas Team',
    'junior', '00000000-0000-4000-8000-000000000102', 'pending',
    null, null);

insert into public.team_members (
  event_id, team_id, user_id, name, email, enrollment, status, approved_by
)
values
  ('10000000-0000-4000-8000-000000000101',
    '20000000-0000-4000-8000-000000000101',
    '00000000-0000-4000-8000-000000000101', 'Canvas Leader',
    'canvas-leader@example.test', 'canvas-101', 'active',
    '00000000-0000-4000-8000-000000000101'),
  ('10000000-0000-4000-8000-000000000101',
    '20000000-0000-4000-8000-000000000102',
    '00000000-0000-4000-8000-000000000102', 'Pending Leader',
    'pending-leader@example.test', 'canvas-102', 'active',
    '00000000-0000-4000-8000-000000000102');

insert into public.canvas_templates (
  id, event_id, name, instructions, created_by
)
values (
  '30000000-0000-4000-8000-000000000101',
  '10000000-0000-4000-8000-000000000101',
  'Business Model Canvas', 'Fill every block.',
  '00000000-0000-4000-8000-000000000103'
);

insert into public.canvas_template_blocks (
  id, template_id, key, title, prompt, position, max_items
)
values
  ('31000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000101',
    'problem', 'Problem', 'Describe the problem.', 1, 5),
  ('31000000-0000-4000-8000-000000000102',
    '30000000-0000-4000-8000-000000000101',
    'solution', 'Solution', 'Describe the solution.', 2, 5);

insert into public.canvas_activities (
  id, event_id, template_id, title, instructions, categories,
  opens_at, due_at, published, is_primary, created_by
)
values
  ('40000000-0000-4000-8000-000000000101',
    '10000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000101',
    'Open Canvas', 'Submit it.', array['junior']::public.team_category[],
    now() - interval '1 hour', now() + interval '1 hour', true, true,
    '00000000-0000-4000-8000-000000000103'),
  ('40000000-0000-4000-8000-000000000102',
    '10000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000101',
    'Closed Canvas', '', array['junior']::public.team_category[],
    now() - interval '2 hours', now() - interval '1 hour', true, false,
    '00000000-0000-4000-8000-000000000103'),
  ('40000000-0000-4000-8000-000000000103',
    '10000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000101',
    'Future Canvas', '', array['junior']::public.team_category[],
    now() + interval '1 hour', now() + interval '2 hours', true, false,
    '00000000-0000-4000-8000-000000000103'),
  ('40000000-0000-4000-8000-000000000104',
    '10000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000101',
    'Draft Canvas', '', array['junior']::public.team_category[],
    now() - interval '1 hour', now() + interval '1 hour', false, false,
    '00000000-0000-4000-8000-000000000103');

select throws_ok(
  $$
    insert into public.canvas_activities (
      event_id, title, instructions, categories, opens_at, due_at,
      published, is_primary, created_by
    )
    values (
      '10000000-0000-4000-8000-000000000101',
      'Overlapping Primary Canvas',
      '',
      array['junior', 'senior']::public.team_category[],
      now() - interval '1 hour',
      now() + interval '1 hour',
      true,
      true,
      '00000000-0000-4000-8000-000000000103'
    )
  $$,
  'P0001',
  'primary_activity_category_conflict',
  'primary activities cannot overlap an existing event category'
);

select lives_ok(
  $$
    insert into public.canvas_activities (
      event_id, title, instructions, categories, opens_at, due_at,
      published, is_primary, created_by
    )
    values (
      '10000000-0000-4000-8000-000000000101',
      'Senior Primary Canvas',
      '',
      array['senior']::public.team_category[],
      now() - interval '1 hour',
      now() + interval '1 hour',
      true,
      true,
      '00000000-0000-4000-8000-000000000103'
    )
  $$,
  'different categories may each have one primary activity'
);

insert into public.canvas_activities (
  event_id, title, instructions, categories, opens_at, due_at,
  published, is_primary, created_by
)
values (
  '10000000-0000-4000-8000-000000000102',
  'Other Event Primary Canvas',
  '',
  array['junior', 'senior']::public.team_category[],
  now() - interval '1 hour',
  now() + interval '1 hour',
  true,
  true,
  '00000000-0000-4000-8000-000000000106'
);

select throws_ok(
  $$
    insert into public.canvas_activities (
      event_id, title, instructions, categories, opens_at, due_at,
      published, is_primary, created_by
    )
    values (
      '10000000-0000-4000-8000-000000000102',
      'Reordered Other Primary Canvas',
      '',
      array['senior', 'junior']::public.team_category[],
      now() - interval '1 hour',
      now() + interval '1 hour',
      true,
      true,
      '00000000-0000-4000-8000-000000000106'
    )
  $$,
  'P0001',
  'primary_activity_category_conflict',
  'reordering categories cannot bypass primary uniqueness'
);

select is(
  (
    select count(*)::integer from public.canvas_blocks
    where activity_id = '40000000-0000-4000-8000-000000000101'
  ),
  2,
  'activity creation copies all template blocks'
);

update public.canvas_template_blocks
set title = 'Changed Template Title'
where id = '31000000-0000-4000-8000-000000000101';

select is(
  (
    select title from public.canvas_blocks
    where activity_id = '40000000-0000-4000-8000-000000000101'
      and key = 'problem'
  ),
  'Problem',
  'template edits never mutate an existing activity block copy'
);

insert into public.submissions (
  id, event_id, activity_id, team_id
)
values
  ('50000000-0000-4000-8000-000000000101',
    '10000000-0000-4000-8000-000000000101',
    '40000000-0000-4000-8000-000000000101',
    '20000000-0000-4000-8000-000000000101'),
  ('50000000-0000-4000-8000-000000000102',
    '10000000-0000-4000-8000-000000000101',
    '40000000-0000-4000-8000-000000000101',
    '20000000-0000-4000-8000-000000000102'),
  ('50000000-0000-4000-8000-000000000103',
    '10000000-0000-4000-8000-000000000101',
    '40000000-0000-4000-8000-000000000102',
    '20000000-0000-4000-8000-000000000101'),
  ('50000000-0000-4000-8000-000000000104',
    '10000000-0000-4000-8000-000000000101',
    '40000000-0000-4000-8000-000000000103',
    '20000000-0000-4000-8000-000000000101'),
  ('50000000-0000-4000-8000-000000000105',
    '10000000-0000-4000-8000-000000000101',
    '40000000-0000-4000-8000-000000000104',
    '20000000-0000-4000-8000-000000000101');

insert into public.submission_answers (
  submission_id, block_id, content, updated_by
)
select
  '50000000-0000-4000-8000-000000000103',
  block.id,
  '{"items":["Private draft answer"]}'::jsonb,
  '00000000-0000-4000-8000-000000000101'
from public.canvas_blocks as block
where block.activity_id = '40000000-0000-4000-8000-000000000102'
  and block.key = 'problem';

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000104', true);
select is(
  (
    select count(*)::integer
    from public.teams
    where event_id = '10000000-0000-4000-8000-000000000101'
  ),
  2,
  'an event Monitor can identify teams in the scoped review queue'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102', true);

select throws_ok(
  $$select public.submit_canvas(
    '50000000-0000-4000-8000-000000000102')$$,
  'P0001', 'team_not_approved',
  'an unapproved team cannot submit'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101', true);
select throws_ok(
  $$select public.submit_canvas(
    '50000000-0000-4000-8000-000000000103')$$,
  'P0001', 'activity_deadline_passed',
  'submission after the deadline is rejected'
);
select throws_ok(
  $$select public.submit_canvas(
    '50000000-0000-4000-8000-000000000104')$$,
  'P0001', 'activity_not_open',
  'submission before opening is rejected'
);
select throws_ok(
  $$select public.submit_canvas(
    '50000000-0000-4000-8000-000000000105')$$,
  'P0001', 'activity_not_published',
  'an unpublished activity cannot be submitted'
);

select is(
  (
    select (public.save_canvas_answer(
      '50000000-0000-4000-8000-000000000101',
      (select id from public.canvas_blocks
       where activity_id = '40000000-0000-4000-8000-000000000101'
         and key = 'problem'),
      '{"items":["First answer"]}'::jsonb, 0
    )).version
  ),
  1,
  'first answer save creates optimistic version one'
);
select is(
  (
    select content from public.submission_answers
    where submission_id = '50000000-0000-4000-8000-000000000101'
      and block_id = (
        select id from public.canvas_blocks
        where activity_id = '40000000-0000-4000-8000-000000000101'
          and key = 'problem'
      )
  ),
  '{"items":["First answer"]}'::jsonb,
  'answer content is stored without interpolation'
);
select throws_ok(
  $$select public.save_canvas_answer(
    '50000000-0000-4000-8000-000000000101',
    (select id from public.canvas_blocks
     where activity_id = '40000000-0000-4000-8000-000000000101'
       and key = 'problem'),
    '{"items":["Stale answer"]}'::jsonb, 0)$$,
  'P0001', 'version_conflict',
  'stale answer versions are rejected'
);

select is(
  (select (public.submit_canvas(
    '50000000-0000-4000-8000-000000000101')).status),
  'submitted',
  'a valid draft becomes submitted'
);
reset role;

select is(
  (
    select count(*)::integer
    from public.submission_revisions
    where submission_id = '50000000-0000-4000-8000-000000000101'
      and revision = 1
      and snapshot -> 'problem' = '{"items":["First answer"]}'::jsonb
  ),
  1,
  'submission snapshots the current answers as revision one'
);

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000105', true);
select throws_ok(
  $$select public.claim_review(
    '50000000-0000-4000-8000-000000000101')$$,
  'P0001', 'forbidden',
  'students cannot claim reviews'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000106', true);
select throws_ok(
  $$select public.claim_review(
    '50000000-0000-4000-8000-000000000101')$$,
  'P0001', 'forbidden',
  'a Professor assigned to another event cannot claim the review'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000104', true);
select is(
  (select (public.claim_review(
    '50000000-0000-4000-8000-000000000101')).status),
  'in_review',
  'an event Monitor can atomically claim a submitted review'
);
reset role;

delete from public.event_roles
where event_id = '10000000-0000-4000-8000-000000000101'
  and user_id = '00000000-0000-4000-8000-000000000104'
  and role = 'monitor';

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000104', true);
select throws_ok(
  $$select public.decide_submission(
    '50000000-0000-4000-8000-000000000101',
    'approved', null)$$,
  'P0001', 'forbidden',
  'a Monitor whose role was revoked cannot decide an active claim'
);
reset role;

insert into public.event_roles (event_id, user_id, role, approved_by)
values (
  '10000000-0000-4000-8000-000000000101',
  '00000000-0000-4000-8000-000000000104',
  'monitor',
  '00000000-0000-4000-8000-000000000103'
);

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000103', true);
select throws_ok(
  $$select public.claim_review(
    '50000000-0000-4000-8000-000000000101')$$,
  'P0001', 'review_already_claimed',
  'an active review claim is exclusive'
);
reset role;

update public.submissions
set claimed_at = now() - interval '16 minutes'
where id = '50000000-0000-4000-8000-000000000101';

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000103', true);
select is(
  (select (public.claim_review(
    '50000000-0000-4000-8000-000000000101')).claimed_by),
  '00000000-0000-4000-8000-000000000103'::uuid,
  'an expired claim can be replaced'
);
reset role;

update public.events
set professor_id = '00000000-0000-4000-8000-000000000106'
where id = '10000000-0000-4000-8000-000000000101';

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000103', true);
select throws_ok(
  $$select public.decide_submission(
    '50000000-0000-4000-8000-000000000101',
    'approved', null)$$,
  'P0001', 'forbidden',
  'a replaced Professor cannot decide an active claim'
);
reset role;

update public.events
set professor_id = '00000000-0000-4000-8000-000000000103'
where id = '10000000-0000-4000-8000-000000000101';

update public.submissions
set claimed_at = now() - interval '16 minutes'
where id = '50000000-0000-4000-8000-000000000101';

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000103', true);
select throws_ok(
  $$select public.decide_submission(
    '50000000-0000-4000-8000-000000000101',
    'approved', null)$$,
  'P0001', 'review_claim_expired',
  'an expired claimant cannot decide the submission'
);
reset role;

update public.submissions
set claimed_at = now()
where id = '50000000-0000-4000-8000-000000000101';

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000103', true);
select is(
  (select (public.decide_submission(
    '50000000-0000-4000-8000-000000000101',
    'approved', null)).status),
  'approved',
  'the active claimant can approve without feedback'
);
reset role;

select ok(
  exists (
    select 1 from public.submission_reviews
    where submission_id = '50000000-0000-4000-8000-000000000101'
      and decision = 'approved' and feedback is null
  ),
  'a null-feedback approval still records a review'
);

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101', true);
select is(
  (
    select count(*)::integer
    from public.submission_reviews
    where submission_id = '50000000-0000-4000-8000-000000000101'
      and decision = 'approved'
  ),
  1,
  'an active team member can read the latest review through submission RLS'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000104', true);
select throws_ok(
  $$select public.reopen_submission(
    '50000000-0000-4000-8000-000000000101', 'Needs another pass')$$,
  'P0001', 'forbidden',
  'a Monitor cannot reopen an approved submission'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000103', true);
select throws_ok(
  $$select public.reopen_submission(
    '50000000-0000-4000-8000-000000000101', '   ')$$,
  'P0001', 'reopen_reason_required',
  'reopen requires a nonblank reason'
);
select is(
  (select (public.reopen_submission(
    '50000000-0000-4000-8000-000000000101',
    ' Clarify the evidence. ')).status),
  'returned',
  'the event Professor can reopen an approved submission'
);
reset role;

select is(
  (
    select feedback from public.submission_reviews
    where submission_id = '50000000-0000-4000-8000-000000000101'
      and decision = 'reopened'
  ),
  'Clarify the evidence.',
  'reopen stores the normalized reason'
);

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101', true);
select is(
  (
    select (public.save_canvas_answer(
      '50000000-0000-4000-8000-000000000101',
      (select id from public.canvas_blocks
       where activity_id = '40000000-0000-4000-8000-000000000101'
         and key = 'problem'),
      '{"items":["Improved answer"]}'::jsonb, 1
    )).version
  ),
  2,
  'a returned submission can be edited'
);
select is(
  (select (public.submit_canvas(
    '50000000-0000-4000-8000-000000000101')).status),
  'resubmitted',
  'a returned submission becomes resubmitted'
);
reset role;

select is(
  (
    select revision from public.submissions
    where id = '50000000-0000-4000-8000-000000000101'
  ),
  2,
  'resubmission increments the immutable revision number'
);

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000104', true);
select is(
  (select (public.claim_review(
    '50000000-0000-4000-8000-000000000101')).status),
  'in_review',
  'a Monitor can claim a resubmission'
);
select is(
  (select (public.decide_submission(
    '50000000-0000-4000-8000-000000000101',
    'returned', null)).status),
  'returned',
  'a review may return work without feedback'
);
reset role;

select ok(
  exists (
    select 1 from public.submission_reviews
    where submission_id = '50000000-0000-4000-8000-000000000101'
      and decision = 'returned' and feedback is null
  ),
  'a null-feedback return still records a review'
);

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101', true);
select is(
  (select (public.submit_canvas(
    '50000000-0000-4000-8000-000000000101')).status),
  'resubmitted',
  'returned work can be resubmitted again'
);
reset role;

select is(
  (
    select count(*)::integer from public.audit_log
    where event_id = '10000000-0000-4000-8000-000000000101'
      and action in (
        'canvas_submitted', 'canvas_review_claimed',
        'canvas_resubmitted', 'canvas_approved', 'canvas_reopened',
        'canvas_returned'
      )
  ),
  9,
  'submission, claim, decision, and reopen actions are event-audited'
);

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101', true);
select is(
  (
    select count(*)::integer from public.submissions
    where id = '50000000-0000-4000-8000-000000000101'
  ),
  1,
  'a team member can read their own submission'
);
select is(
  (
    select count(*)::integer from public.submissions
    where id = '50000000-0000-4000-8000-000000000103'
      and status = 'draft'
  ),
  1,
  'a team member can read their own draft'
);
select is(
  (
    select count(*)::integer
    from public.submission_answers
    where submission_id = '50000000-0000-4000-8000-000000000103'
  ),
  1,
  'a team member can read answers from their own draft'
);
select is(
  (
    select count(*)::integer from public.submissions
    where id = '50000000-0000-4000-8000-000000000102'
  ),
  0,
  'a team member cannot read another team submission'
);
select throws_ok(
  $$update public.submissions set status = 'approved'
    where id = '50000000-0000-4000-8000-000000000101'$$,
  '42501', 'permission denied for table submissions',
  'students cannot directly write privileged submission state'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000104', true);
select is(
  (
    select count(*)::integer from public.submissions
    where event_id = '10000000-0000-4000-8000-000000000101'
  ),
  1,
  'an event Monitor can read only submitted or historical submissions'
);
select is(
  (
    select count(*)::integer
    from public.submission_answers
    where submission_id = '50000000-0000-4000-8000-000000000103'
  ),
  0,
  'an event Monitor cannot read draft answers'
);
select throws_ok(
  $$insert into public.canvas_templates (
      event_id, name, instructions
    ) values (
      '10000000-0000-4000-8000-000000000101', 'Monitor Template', ''
    )$$,
  '42501',
  'new row violates row-level security policy for table "canvas_templates"',
  'a Monitor cannot create Canvas templates'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000103', true);
select is(
  (
    select count(*)::integer from public.submissions
    where status = 'draft'
      and event_id = '10000000-0000-4000-8000-000000000101'
  ),
  0,
  'an event Professor cannot read team drafts'
);
select is(
  (
    select count(*)::integer
    from public.submission_answers
    where submission_id = '50000000-0000-4000-8000-000000000103'
  ),
  0,
  'an event Professor cannot read draft answers'
);
select lives_ok(
  $$insert into public.canvas_templates (
      event_id, name, instructions
    ) values (
      '10000000-0000-4000-8000-000000000101', 'Professor Template', ''
    )$$,
  'the assigned Professor can create a template'
);
select lives_ok(
  $$insert into public.canvas_activities (
      event_id, title, instructions, categories, opens_at, due_at
    ) values (
      '10000000-0000-4000-8000-000000000101', 'Professor Activity', '',
      array['junior']::public.team_category[],
      now(), now() + interval '1 hour'
    )$$,
  'the assigned Professor can create an activity'
);
reset role;

select cmp_ok(
  (
    select count(*)::integer
    from pg_indexes
    where schemaname = 'public'
      and tablename in (
        'canvas_template_blocks', 'canvas_activities', 'canvas_blocks',
        'submissions', 'submission_answers', 'submission_revisions',
        'submission_reviews'
      )
      and indexdef ilike '%_id%'
  ),
  '>=',
  16,
  'Canvas foreign keys and access predicates are indexed'
);

update public.events
set status = 'archived', archived_at = now()
where id = '10000000-0000-4000-8000-000000000101';

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101', true);
select throws_ok(
  $$select public.save_canvas_answer(
    '50000000-0000-4000-8000-000000000101',
    (select id from public.canvas_blocks
     where activity_id = '40000000-0000-4000-8000-000000000101'
       and key = 'problem'),
    '{"items":["Archived mutation"]}'::jsonb, 2)$$,
  'P0001', 'event_not_available',
  'archived events reject Canvas workflow writes'
);
reset role;

select * from finish();
rollback;
