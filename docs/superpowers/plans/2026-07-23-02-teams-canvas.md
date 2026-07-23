# Teams and Canvas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver team formation/approval and multi-activity collaborative Canvas submissions with Professor/Monitor review.

**Architecture:** PostgreSQL transactions enforce membership and submission invariants. Nuxt pages use typed Supabase queries and RPCs; Realtime refreshes durable database state rather than acting as the source of truth.

**Tech Stack:** Nuxt 4, Vue 3, TypeScript, Supabase PostgreSQL/RLS/Realtime, Zod, Vitest, pgTAP, Playwright

## Global Constraints

- Complete `2026-07-23-01-foundation-events-auth.md` first.
- Teams contain one to six reserved seats, including pending invitations.
- E-mail and matrícula cannot be reserved by two teams in the same event.
- The leader approves a member after matching-email authentication.
- Only the Professor approves teams.
- Unapproved teams may edit drafts but may not submit.
- Professor and Monitor may review Canvas submissions.
- Review feedback is optional.
- Every status change and revision is auditable.
- Follow `docs/superpowers/specs/2026-07-23-hackathon-ceitec-platform-design.md`.

---

## File Structure

- `supabase/migrations/202607230003_teams.sql`: team/member schema, constraints, RPCs, and RLS.
- `supabase/migrations/202607230004_canvas.sql`: activity, block, response, revision, review, RPC, and RLS schema.
- `shared/domain/team.ts`: team status/category types and UI guards.
- `shared/domain/submission.ts`: submission state machine.
- `app/pages/app/evento/[eventId]/equipe.vue`: leader/member team workspace.
- `app/pages/app/evento/[eventId]/equipes.vue`: Professor approval queue.
- `app/pages/app/evento/[eventId]/atividades/index.vue`: activity list.
- `app/pages/app/evento/[eventId]/atividades/[activityId].vue`: collaborative Canvas editor.
- `app/pages/app/evento/[eventId]/admin/canvas.vue`: Professor template/activity builder.
- `app/pages/app/evento/[eventId]/revisoes.vue`: Professor/Monitor review queue.
- `app/components/canvas/CanvasBlockEditor.vue`: one-block editor.
- `app/components/canvas/AutosaveState.vue`: accessible save status.
- `app/components/reviews/SubmissionReview.vue`: decision and optional feedback.
- `app/composables/useAutosave.ts`: debounced save/retry state.
- `app/composables/useEventRealtime.ts`: authorized Postgres Changes subscription.
- `tests/unit/team.test.ts`: team rule tests.
- `tests/unit/submission.test.ts`: state-machine tests.
- `tests/integration/teams.sql`: database team tests.
- `tests/integration/canvas.sql`: database activity/review tests.
- `tests/e2e/team-and-canvas.spec.ts`: full student/reviewer journey.

### Task 1: Team Domain and Transactional Schema

**Files:**
- Create: `shared/domain/team.ts`
- Create: `tests/unit/team.test.ts`
- Create: `supabase/migrations/202607230003_teams.sql`
- Create: `tests/integration/teams.sql`

**Interfaces:**
- Consumes: `events`, `profiles`, `is_event_professor(uuid)`.
- Produces: `teams`, `team_members`; RPCs `create_team`, `request_team_join`, `decide_team_join`, `decide_team`; types `TeamCategory`, `TeamStatus`, `MemberStatus`.

- [ ] **Step 1: Write failing domain tests**

Create `tests/unit/team.test.ts`:

```ts
import { describe, expect, it } from 'vitest'
import { canReserveSeat, canSubmitForTeam } from '../../shared/domain/team'

describe('team rules', () => {
  it('counts pending invitations as seats', () => {
    expect(canReserveSeat(5)).toBe(true)
    expect(canReserveSeat(6)).toBe(false)
  })

  it('allows submission only for approved teams', () => {
    expect(canSubmitForTeam('approved')).toBe(true)
    expect(canSubmitForTeam('pending')).toBe(false)
  })
})
```

Run: `npx vitest run tests/unit/team.test.ts`

Expected: FAIL because the module is absent.

- [ ] **Step 2: Implement domain types**

Create `shared/domain/team.ts`:

```ts
export type TeamCategory = 'junior' | 'senior'
export type TeamStatus = 'pending' | 'approved' | 'rejected'
export type MemberStatus = 'invited' | 'join_requested' | 'active' | 'rejected' | 'removed'

export const canReserveSeat = (reservedSeats: number) => reservedSeats < 6
export const canSubmitForTeam = (status: TeamStatus) => status === 'approved'
```

Run: `npx vitest run tests/unit/team.test.ts`

Expected: PASS.

- [ ] **Step 3: Create team tables and uniqueness constraints**

Create `supabase/migrations/202607230003_teams.sql`:

```sql
create type public.team_category as enum ('junior', 'senior');
create type public.team_status as enum ('pending', 'approved', 'rejected');
create type public.member_status as enum ('invited', 'join_requested', 'active', 'rejected', 'removed');

create table public.teams (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id),
  name text not null,
  category public.team_category not null,
  leader_id uuid not null references public.profiles(id),
  status public.team_status not null default 'pending',
  decided_by uuid references public.profiles(id),
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  unique(event_id, name)
);

create table public.team_members (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id),
  team_id uuid not null references public.teams(id) on delete cascade,
  user_id uuid references public.profiles(id),
  name text not null,
  email text not null,
  enrollment text not null,
  status public.member_status not null default 'invited',
  approved_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create unique index reserved_email_per_event on public.team_members(event_id, lower(email))
where status in ('invited', 'join_requested', 'active');
create unique index reserved_enrollment_per_event on public.team_members(event_id, enrollment)
where status in ('invited', 'join_requested', 'active');
create unique index one_team_membership_per_user on public.team_members(event_id, user_id)
where user_id is not null and status in ('join_requested', 'active');

alter table public.teams enable row level security;
alter table public.team_members enable row level security;
```

Add RLS policies granting team rows to active/reserved members, Professor access to their event, and denying direct client writes; writes go through RPCs.

- [ ] **Step 4: Implement team RPC invariants**

Implement `create_team(event_id,name,category,members jsonb)` as a `security definer` transaction that:

```sql
if jsonb_array_length(members) < 1 or jsonb_array_length(members) > 6 then
  raise exception 'team_size_out_of_range';
end if;
if exists(select 1 from public.team_members m where m.event_id = create_team.event_id
  and m.status in ('invited','join_requested','active')
  and (lower(m.email) in (select lower(value->>'email') from jsonb_array_elements(members))
    or m.enrollment in (select value->>'enrollment' from jsonb_array_elements(members)))) then
  raise exception 'member_already_reserved';
end if;
```

The RPC inserts the team, creates every reserved member, marks the authenticated leader as `active`, and records `team_created`.

Implement:

```sql
request_team_join(member_id uuid)
decide_team_join(member_id uuid, approve boolean)
decide_team(team_id uuid, decision public.team_status)
```

`request_team_join` compares `lower(auth.jwt()->>'email')` with the reserved e-mail. `decide_team_join` requires the team leader. `decide_team` accepts only `approved` or `rejected` and requires `is_event_professor(event_id)`.

- [ ] **Step 5: Add pgTAP coverage and commit**

`tests/integration/teams.sql` must assert table/RPC existence, partial unique indexes, six-seat success, seventh-seat rejection, duplicate e-mail rejection, wrong-e-mail join rejection, leader-only member approval, and Professor-only team approval.

Run:

```bash
npx supabase db reset
npx supabase test db tests/integration/teams.sql
npx vitest run tests/unit/team.test.ts
git add supabase shared/domain/team.ts tests
git commit -m "feat: add transactional team workflow"
```

Expected: all assertions PASS; commit succeeds.

### Task 2: Team Student and Professor Screens

**Files:**
- Create: `app/pages/app/evento/[eventId]/equipe.vue`
- Create: `app/pages/app/evento/[eventId]/equipes.vue`
- Create: `app/components/team/MemberList.vue`
- Create: `tests/integration/team-pages.nuxt.test.ts`

**Interfaces:**
- Consumes: team RPCs and tables from Task 1.
- Produces: forms for team creation, member join decisions, and Professor team decisions.

- [ ] **Step 1: Write failing page tests**

Test that `/app/evento/demo/equipe` includes “Criar equipe”, “Categoria”, and six member rows; test that the Professor page includes “Equipes aguardando validação”.

Run: `npx vitest run tests/integration/team-pages.nuxt.test.ts`

Expected: FAIL because routes are absent.

- [ ] **Step 2: Build the team creation and membership page**

Use a Zod schema with:

```ts
const TeamInput = z.object({
  name: z.string().trim().min(2).max(80),
  category: z.enum(['junior', 'senior']),
  members: z.array(z.object({
    name: z.string().trim().min(2),
    email: z.string().email(),
    enrollment: z.string().trim().min(1),
  })).min(1).max(6),
})
```

Call `create_team`, show field errors for duplicate e-mail/matrícula, render invitation states, and expose approve/reject buttons only to the leader.

- [ ] **Step 3: Build the Professor queue**

Query pending teams ordered by `created_at`, show category/member count, and call `decide_team`. Require confirmation before rejection; refresh the queue and emit an accessible success message after either decision.

- [ ] **Step 4: Verify and commit**

Run:

```bash
npx vitest run tests/unit/team.test.ts tests/integration/team-pages.nuxt.test.ts
npm run build
git add app tests/integration/team-pages.nuxt.test.ts
git commit -m "feat: add team collaboration and approval screens"
```

Expected: tests PASS, build exits `0`, commit succeeds.

### Task 3: Canvas Activity and Submission State Machine

**Files:**
- Create: `shared/domain/submission.ts`
- Create: `tests/unit/submission.test.ts`
- Create: `supabase/migrations/202607230004_canvas.sql`
- Create: `tests/integration/canvas.sql`

**Interfaces:**
- Consumes: approved `teams`, Professor/Monitor event roles.
- Produces: `canvas_templates`, `canvas_template_blocks`, `canvas_activities`, `canvas_blocks`, `submissions`, `submission_answers`, `submission_revisions`, `submission_reviews`; RPCs `save_canvas_answer`, `submit_canvas`, `claim_review`, `decide_submission`, `reopen_submission`.

- [ ] **Step 1: Test the submission transitions**

Create `tests/unit/submission.test.ts`:

```ts
import { describe, expect, it } from 'vitest'
import { canTransition } from '../../shared/domain/submission'

describe('submission transitions', () => {
  it.each([
    ['draft', 'submitted', true],
    ['submitted', 'in_review', true],
    ['in_review', 'approved', true],
    ['in_review', 'returned', true],
    ['returned', 'resubmitted', true],
    ['approved', 'draft', false],
  ] as const)('%s -> %s is %s', (from, to, allowed) => {
    expect(canTransition(from, to)).toBe(allowed)
  })
})
```

Run: `npx vitest run tests/unit/submission.test.ts`

Expected: FAIL because the module is absent.

- [ ] **Step 2: Implement the state machine**

Create `shared/domain/submission.ts`:

```ts
export type SubmissionStatus = 'draft' | 'submitted' | 'in_review' | 'returned' | 'resubmitted' | 'approved'
const transitions: Record<SubmissionStatus, SubmissionStatus[]> = {
  draft: ['submitted'],
  submitted: ['in_review'],
  in_review: ['approved', 'returned'],
  returned: ['resubmitted'],
  resubmitted: ['in_review'],
  approved: [],
}
export const canTransition = (from: SubmissionStatus, to: SubmissionStatus) =>
  transitions[from].includes(to)
```

- [ ] **Step 3: Create Canvas storage**

The migration creates:

```sql
create table public.canvas_templates (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id),
  name text not null,
  instructions text not null default '',
  created_by uuid not null references public.profiles(id),
  unique(event_id, name)
);

create table public.canvas_template_blocks (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.canvas_templates(id) on delete cascade,
  key text not null,
  title text not null,
  prompt text not null,
  position integer not null,
  max_items integer,
  unique(template_id, key),
  unique(template_id, position)
);

create table public.canvas_activities (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id),
  title text not null,
  instructions text not null default '',
  categories public.team_category[] not null,
  opens_at timestamptz not null,
  due_at timestamptz not null,
  published boolean not null default false,
  is_primary boolean not null default false,
  allow_resubmission boolean not null default true,
  created_by uuid not null references public.profiles(id),
  check (due_at > opens_at)
);

create table public.canvas_blocks (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.canvas_activities(id) on delete cascade,
  key text not null,
  title text not null,
  prompt text not null,
  position integer not null,
  max_items integer,
  unique(activity_id, key),
  unique(activity_id, position)
);

create table public.submissions (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id),
  activity_id uuid not null references public.canvas_activities(id),
  team_id uuid not null references public.teams(id),
  status text not null default 'draft' check (status in ('draft','submitted','in_review','returned','resubmitted','approved')),
  revision integer not null default 1,
  submitted_at timestamptz,
  claimed_by uuid references public.profiles(id),
  claimed_at timestamptz,
  unique(activity_id, team_id)
);

create table public.submission_answers (
  submission_id uuid not null references public.submissions(id) on delete cascade,
  block_id uuid not null references public.canvas_blocks(id),
  content jsonb not null default '{}',
  version integer not null default 1,
  updated_by uuid not null references public.profiles(id),
  updated_at timestamptz not null default now(),
  primary key(submission_id, block_id)
);

create table public.submission_revisions (
  submission_id uuid not null references public.submissions(id),
  revision integer not null,
  snapshot jsonb not null,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  primary key(submission_id, revision)
);

create table public.submission_reviews (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.submissions(id),
  reviewer_id uuid not null references public.profiles(id),
  decision text not null check (decision in ('approved','returned','reopened')),
  feedback text,
  created_at timestamptz not null default now()
);
```

Enable RLS on every table. Members read/write only their team drafts; Professor/Monitor read reviewable submissions; only Professor creates templates/activities and reopens submissions. Creating an activity from a template copies template blocks into `canvas_blocks`, so later template edits never mutate a published activity.

- [ ] **Step 4: Implement Canvas RPCs**

`save_canvas_answer(submission_id,block_id,content,expected_version)` must update only when `version = expected_version`, otherwise raise `version_conflict`.

`submit_canvas(submission_id)` must lock the team/submission, require team `approved`, activity published/open, `now() <= due_at`, snapshot all answers, and move `draft|returned` to `submitted|resubmitted`.

`claim_review(submission_id)` must require Professor/Monitor and atomically set `claimed_by=auth.uid()`, `claimed_at=now()`, `status='in_review'` only when no active claim exists. A claim expires after 15 minutes and can be replaced.

`decide_submission(submission_id,decision,feedback default null)` accepts `approved|returned`, requires the active claimant, inserts a review even when feedback is null, clears the claim, and records audit.

`reopen_submission(submission_id,reason)` requires Professor and nonempty reason, changes `approved` to `returned`, inserts a `reopened` review, and records audit.

- [ ] **Step 5: Verify database behavior and commit**

`tests/integration/canvas.sql` must cover unapproved-team submission rejection, deadline rejection, optimistic-lock conflict, exclusive review claim, claim expiry, feedback-null approval, return/re-submit, and Professor-only reopen.

Run:

```bash
npx supabase db reset
npx supabase test db tests/integration/canvas.sql
npx vitest run tests/unit/submission.test.ts
git add supabase shared/domain/submission.ts tests
git commit -m "feat: add Canvas submission and review workflow"
```

Expected: all tests PASS; commit succeeds.

### Task 4: Collaborative Canvas Editor and Review Queue

**Files:**
- Create: `app/composables/useAutosave.ts`
- Create: `app/composables/useEventRealtime.ts`
- Create: `app/components/canvas/CanvasBlockEditor.vue`
- Create: `app/components/canvas/AutosaveState.vue`
- Create: `app/components/reviews/SubmissionReview.vue`
- Create: `app/pages/app/evento/[eventId]/atividades/index.vue`
- Create: `app/pages/app/evento/[eventId]/atividades/[activityId].vue`
- Create: `app/pages/app/evento/[eventId]/admin/canvas.vue`
- Create: `app/pages/app/evento/[eventId]/revisoes.vue`
- Create: `tests/unit/autosave.test.ts`
- Create: `tests/e2e/team-and-canvas.spec.ts`

**Interfaces:**
- Consumes: Task 3 tables/RPCs.
- Produces: reusable `useAutosave(save,delayMs)` with states `idle|saving|saved|error|conflict`; event Realtime subscription cleanup.

- [ ] **Step 1: Test autosave retry and conflict behavior**

Use fake timers to assert one save after 700 ms, retry after a network error, `conflict` on `version_conflict`, and no save after component disposal.

Run: `npx vitest run tests/unit/autosave.test.ts`

Expected: FAIL because `useAutosave` is absent.

- [ ] **Step 2: Implement autosave**

Create `useAutosave` with this public contract:

```ts
export function useAutosave<T>(
  save: (value: T) => Promise<{ version: number }>,
  delayMs = 700,
): {
  state: Readonly<Ref<'idle' | 'saving' | 'saved' | 'error' | 'conflict'>>
  version: Readonly<Ref<number>>
  schedule: (value: T) => void
  retry: () => Promise<void>
}
```

Keep the last unsaved value in memory; classify `version_conflict` separately; clear the timer in `onScopeDispose`.

- [ ] **Step 3: Build activity list and editor**

The list groups activities by open/upcoming/closed and shows status/deadline. The editor renders blocks ordered by `position`, uses one autosave instance per block, displays `AutosaveState`, subscribes to permitted Postgres Changes, and shows a conflict banner with “Recarregar versão mais recente”.

The submit button is disabled unless the team is approved, the activity is open, and no block is saving or conflicted.

- [ ] **Step 4: Build the Professor Canvas builder**

The builder creates/reorders/removes template blocks, saves templates, creates an activity from a template, chooses Júnior/Sênior/both, opening/deadline, primary-activity flag, re-submission policy, and publication state. Validate `due_at > opens_at`, require at least one category and one block, and prevent structural changes after the first submission.

Use this form contract:

```ts
interface ActivityBuilderInput {
  title: string
  instructions: string
  categories: ('junior' | 'senior')[]
  opensAt: string
  dueAt: string
  isPrimary: boolean
  allowResubmission: boolean
  published: boolean
  blocks: { key: string; title: string; prompt: string; position: number; maxItems: number | null }[]
}
```

- [ ] **Step 5: Build the review queue**

The queue filters by category/status, calls `claim_review`, renders the immutable submitted revision, and uses:

```ts
async function decide(decision: 'approved' | 'returned') {
  await $supabase.rpc('decide_submission', {
    submission_id: props.submissionId,
    decision,
    feedback: feedback.value.trim() || null,
  })
}
```

Show the new status to students through the Realtime refresh.

- [ ] **Step 6: Add full browser journey and commit**

The Playwright test creates a leader and invited member, approves the join, has a Professor approve the team, edits two blocks concurrently, submits, has a Monitor approve without feedback, and verifies the student sees `Aprovado`.

Run:

```bash
npx vitest run
npx playwright test tests/e2e/team-and-canvas.spec.ts
npm run build
git add app tests
git commit -m "feat: add collaborative Canvas and review experience"
```

Expected: unit/integration/E2E tests PASS, build exits `0`, commit succeeds.
