# Evaluation and Results Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver category-scoped presentation order, mobile evaluation, reproducible weighted rankings, audited manual tie-breaking, and safe result publication.

**Architecture:** PostgreSQL owns frozen evaluation configuration, completeness checks, score calculation, tie detection, and publication guards. Nuxt exposes mobile-first evaluator and administrative workflows; public results read only published snapshots.

**Tech Stack:** Nuxt 4, Vue 3, TypeScript, Supabase PostgreSQL/RLS/Realtime, Vitest, pgTAP, Playwright

## Global Constraints

- Complete plans 01 and 02 first.
- Criteria use integer scores from 1 through 5.
- Initial criteria are Time, Solução, Pensamento Computacional e Viabilidade, Apresentação, and Mercado.
- Every initial category weight is `1`.
- A Professor may configure different weights for Júnior and Sênior before evaluation starts.
- Every designated evaluator must evaluate every team in their category.
- An evaluator cannot belong to a team in the same category.
- Júnior and Sênior rankings are independent.
- Equal scores rounded to two decimal places are ties.
- A tie blocks category publication until the Professor records an order and mandatory justification.
- Tie-breaking never changes original scores.
- Follow `docs/superpowers/specs/2026-07-23-hackathon-ceitec-platform-design.md`.

---

## File Structure

- `supabase/migrations/202607230005_evaluations.sql`: criteria, weights, evaluator assignments, presentation order, evaluations, scores, and RLS.
- `supabase/migrations/202607230006_results.sql`: tie decisions, publication snapshots, RPCs, and guards.
- `shared/domain/scoring.ts`: pure weighted-score functions.
- `app/pages/app/evento/[eventId]/avaliacao/index.vue`: evaluator queue.
- `app/pages/app/evento/[eventId]/avaliacao/[teamId].vue`: mobile scoring form.
- `app/pages/app/evento/[eventId]/admin/avaliacao.vue`: configuration/progress.
- `app/pages/app/evento/[eventId]/admin/resultados.vue`: ranking/tie/publication.
- `app/components/evaluation/ScoreCriterion.vue`: accessible 1–5 selector.
- `app/components/results/TieResolution.vue`: manual tie order and justification.
- `app/pages/resultados/[eventSlug].vue`: published results.
- `tests/unit/scoring.test.ts`: formula and tie tests.
- `tests/integration/evaluations.sql`: database invariant tests.
- `tests/integration/results.sql`: publication/tie tests.
- `tests/e2e/evaluation-results.spec.ts`: full evaluation journey.

### Task 1: Scoring Domain and Evaluation Schema

**Files:**
- Create: `shared/domain/scoring.ts`
- Create: `tests/unit/scoring.test.ts`
- Create: `supabase/migrations/202607230005_evaluations.sql`
- Create: `tests/integration/evaluations.sql`

**Interfaces:**
- Consumes: approved teams, event roles, primary Canvas summary.
- Produces: `evaluation_criteria`, `criterion_weights`, `evaluator_assignments`, `presentation_slots`, `evaluations`, `evaluation_scores`; RPCs `freeze_evaluation`, `submit_evaluation`; `weightedScore()` and `finalTeamScore()`.

- [ ] **Step 1: Write failing scoring tests**

Create `tests/unit/scoring.test.ts`:

```ts
import { describe, expect, it } from 'vitest'
import { finalTeamScore, isDisplayedTie, weightedScore } from '../../shared/domain/scoring'

describe('scoring', () => {
  it('calculates a weighted evaluator score', () => {
    expect(weightedScore([{ score: 5, weight: 2 }, { score: 3, weight: 1 }])).toBeCloseTo(13 / 3)
  })

  it('averages evaluator scores and displays two decimals', () => {
    expect(finalTeamScore([4.333, 4.667])).toBe(4.5)
  })

  it('treats equal displayed scores as tied', () => {
    expect(isDisplayedTie(4.504, 4.503)).toBe(true)
  })
})
```

Run: `npx vitest run tests/unit/scoring.test.ts`

Expected: FAIL because the module is absent.

- [ ] **Step 2: Implement pure scoring**

Create `shared/domain/scoring.ts`:

```ts
export interface WeightedCriterion { score: number; weight: number }
const round2 = (value: number) => Math.round((value + Number.EPSILON) * 100) / 100

export function weightedScore(items: WeightedCriterion[]): number {
  const weight = items.reduce((sum, item) => sum + item.weight, 0)
  if (weight <= 0) throw new Error('positive_weight_required')
  if (items.some(item => item.score < 1 || item.score > 5 || item.weight < 0)) {
    throw new Error('invalid_score_or_weight')
  }
  return items.reduce((sum, item) => sum + item.score * item.weight, 0) / weight
}

export function finalTeamScore(evaluatorScores: number[]): number {
  if (!evaluatorScores.length) throw new Error('evaluation_required')
  return round2(evaluatorScores.reduce((sum, value) => sum + value, 0) / evaluatorScores.length)
}

export const isDisplayedTie = (left: number, right: number) => round2(left) === round2(right)
```

- [ ] **Step 3: Create evaluation schema**

Create tables:

```sql
create table public.evaluation_criteria (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id),
  name text not null,
  description text not null default '',
  position integer not null,
  active boolean not null default true,
  unique(event_id, name),
  unique(event_id, position)
);

create table public.criterion_weights (
  criterion_id uuid not null references public.evaluation_criteria(id),
  category public.team_category not null,
  weight numeric(8,2) not null default 1 check (weight >= 0),
  primary key(criterion_id, category)
);

create table public.evaluator_assignments (
  event_id uuid not null references public.events(id),
  evaluator_id uuid not null references public.profiles(id),
  category public.team_category not null,
  assigned_by uuid not null references public.profiles(id),
  primary key(event_id, evaluator_id, category)
);

create table public.presentation_slots (
  event_id uuid not null references public.events(id),
  category public.team_category not null,
  team_id uuid not null references public.teams(id),
  position integer not null,
  presented_at timestamptz,
  primary key(event_id, category, team_id),
  unique(event_id, category, position)
);

create table public.evaluations (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id),
  team_id uuid not null references public.teams(id),
  evaluator_id uuid not null references public.profiles(id),
  comment text,
  submitted_at timestamptz,
  updated_at timestamptz not null default now(),
  unique(event_id, team_id, evaluator_id)
);

create table public.evaluation_scores (
  evaluation_id uuid not null references public.evaluations(id) on delete cascade,
  criterion_id uuid not null references public.evaluation_criteria(id),
  score smallint not null check (score between 1 and 5),
  primary key(evaluation_id, criterion_id)
);

create table public.evaluation_freezes (
  event_id uuid not null references public.events(id),
  category public.team_category not null,
  frozen_at timestamptz not null default now(),
  frozen_by uuid not null references public.profiles(id),
  criteria_snapshot jsonb not null,
  evaluator_snapshot jsonb not null,
  primary key(event_id, category)
);
```

Enable RLS on all six tables. Professor manages configuration before freeze; evaluators read criteria/assigned teams and write only their own evaluation; students cannot read private evaluations.

- [ ] **Step 4: Implement freeze and evaluation RPCs**

`freeze_evaluation(event_id,category)` requires the Professor, at least one approved team, one positive-weight criterion, and one evaluator. Reject an evaluator who is an active member of a same-category team. Save immutable criteria/evaluator snapshots.

`submit_evaluation(team_id,scores jsonb,comment text)` requires an assignment matching team category and a freeze; rejects missing/extra criteria and scores outside 1–5; upserts one evaluation and its scores; sets `submitted_at=now()` in one transaction.

- [ ] **Step 5: Test and commit**

`tests/integration/evaluations.sql` must cover default weights, weight editing before freeze, editing rejection after freeze, wrong-category access, participant/evaluator conflict, incomplete scores, invalid score, one evaluation per evaluator/team, and update before event close.

Run:

```bash
npx supabase db reset
npx supabase test db tests/integration/evaluations.sql
npx vitest run tests/unit/scoring.test.ts
git add supabase shared/domain/scoring.ts tests
git commit -m "feat: add frozen category evaluation model"
```

Expected: all tests PASS; commit succeeds.

### Task 2: Presentation Order and Mobile Evaluation

**Files:**
- Create: `supabase/migrations/2026072300051_presentation_order.sql`
- Create: `app/components/evaluation/ScoreCriterion.vue`
- Create: `app/pages/app/evento/[eventId]/avaliacao/index.vue`
- Create: `app/pages/app/evento/[eventId]/avaliacao/[teamId].vue`
- Create: `app/pages/app/evento/[eventId]/admin/avaliacao.vue`
- Create: `tests/integration/evaluation-pages.nuxt.test.ts`

**Interfaces:**
- Consumes: evaluation schema/RPCs.
- Produces: RPC `shuffle_presentations(event_id,category)` and mobile evaluation form.

- [ ] **Step 1: Add deterministic database-backed shuffle**

Create an RPC that requires the Professor, deletes only the selected category order, and inserts every approved team using:

```sql
row_number() over (order by gen_random_uuid())
```

Record `presentation_order_shuffled` in `audit_log`. Reject shuffle after any evaluation in the category is submitted.

- [ ] **Step 2: Write failing page tests**

Assert the evaluator queue contains category, progress, current team, and presentation position. Assert the form renders one 1–5 radiogroup per active criterion and “Salvar avaliação”.

Run: `npx vitest run tests/integration/evaluation-pages.nuxt.test.ts`

Expected: FAIL because pages are absent.

- [ ] **Step 3: Build mobile-first evaluator components**

`ScoreCriterion.vue` accepts:

```ts
defineProps<{ criterionId: string; name: string; description: string; modelValue?: number }>()
defineEmits<{ 'update:modelValue': [value: number] }>()
```

Render five buttons with minimum 44×44 px targets, `role="radiogroup"`, `aria-checked`, keyboard arrow navigation, and visible selected state.

- [ ] **Step 4: Build evaluator and Professor pages**

The evaluator queue reads only assigned categories, orders by presentation position, and marks submitted teams. The form shows team/category/summary, validates every criterion, calls `submit_evaluation`, preserves unsent input after network errors, and navigates to the next team on success.

The Professor page creates criteria, edits category weights, assigns evaluators, shuffles presentations, freezes each category, and shows `completed / required` evaluation progress.

- [ ] **Step 5: Verify and commit**

Run:

```bash
npx supabase db reset
npx vitest run tests/integration/evaluation-pages.nuxt.test.ts
npm run build
git add supabase app tests/integration/evaluation-pages.nuxt.test.ts
git commit -m "feat: add presentation order and mobile evaluation"
```

Expected: tests PASS, build exits `0`, commit succeeds.

### Task 3: Ranking, Tie Resolution, and Publication

**Files:**
- Create: `supabase/migrations/202607230006_results.sql`
- Create: `app/components/results/TieResolution.vue`
- Create: `app/pages/app/evento/[eventId]/admin/resultados.vue`
- Create: `app/pages/resultados/[eventSlug].vue`
- Create: `tests/integration/results.sql`
- Create: `tests/e2e/evaluation-results.spec.ts`

**Interfaces:**
- Consumes: frozen evaluation snapshots and submitted evaluation scores.
- Produces: views `evaluation_progress`, `administrative_ranking`; tables `tie_decisions`, `published_results`; RPCs `resolve_tie`, `publish_category_results`.

- [ ] **Step 1: Create score and completeness views**

`evaluation_progress` returns event/category/team, required evaluator count, completed evaluator count, and `complete`.

`administrative_ranking` includes only complete teams and calculates:

```sql
round(avg(evaluator_weighted_score)::numeric, 2) as final_score
```

Use the frozen weights, not current editable configuration. Add `dense_rank()` by category/final score for tie groups.

- [ ] **Step 2: Create immutable decision and publication tables**

Create:

```sql
create table public.tie_decisions (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id),
  category public.team_category not null,
  displayed_score numeric(4,2) not null,
  ordered_team_ids uuid[] not null,
  justification text not null check (length(trim(justification)) > 0),
  decided_by uuid not null references public.profiles(id),
  decided_at timestamptz not null default now(),
  unique(event_id, category, displayed_score)
);

create table public.published_results (
  event_id uuid not null references public.events(id),
  category public.team_category not null,
  ranking jsonb not null,
  published_by uuid not null references public.profiles(id),
  published_at timestamptz not null default now(),
  primary key(event_id, category)
);
```

Enable RLS. Professor reads/administers pending results; anonymous users select only `published_results`.

- [ ] **Step 3: Implement guarded RPCs**

`resolve_tie(event_id,category,displayed_score,ordered_team_ids,justification)` must require the Professor, lock ranking rows, verify the array contains every tied team exactly once and no other team, require nonblank justification, insert the decision, and audit it.

`publish_category_results(event_id,category)` must reject incomplete teams and unresolved tie groups, merge tie order without changing scores, store an immutable JSON snapshot, advance the event to `results_published` only after both categories are published, and audit publication.

- [ ] **Step 4: Test publication invariants**

`tests/integration/results.sql` must cover weighted calculation, missing evaluator exclusion, two-decimal tie detection, publication blocked by incompleteness, publication blocked by unresolved tie, invalid manual order, mandatory justification, three-team tie, unchanged scores after resolution, and anonymous published-only access.

Run: `npx supabase test db tests/integration/results.sql`

Expected: all assertions PASS.

- [ ] **Step 5: Build administrative and public result screens**

The admin page shows evaluation progress, private category rankings, missing evaluators, tie cards, draggable/manual ordered team list, required justification, and publication button with explicit blockers.

The public route queries by event slug and renders only `published_results`, with separate Júnior and Sênior sections and publication timestamp.

- [ ] **Step 6: Add end-to-end tie journey and commit**

The Playwright test freezes both categories, completes all required evaluations, produces a two-team tie, verifies publication is blocked, resolves it as Professor with justification, publishes, and confirms the anonymous page shows the chosen order while preserving equal scores.

Run:

```bash
npx supabase db reset
npx supabase test db
npx vitest run
npx playwright test tests/e2e/evaluation-results.spec.ts
npm run build
git add supabase app tests
git commit -m "feat: add audited rankings and publication"
```

Expected: all tests PASS, build exits `0`, commit succeeds.

