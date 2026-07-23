# Landing, Hardening, and Launch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the CEITEC landing page, role dashboards, accessibility, security verification, observability, and production deployment.

**Architecture:** Public content is server-rendered by Nuxt; authenticated dashboards compose the workflows delivered in plans 01–03. Automated RLS, E2E, accessibility, and production smoke tests form the release gate.

**Tech Stack:** Nuxt 4, Vue 3, TypeScript, Supabase, Vitest, Playwright, axe-core, Vercel

## Global Constraints

- Complete plans 01–03 first.
- Use a native dark theme.
- Make evaluator workflows aggressively mobile-first.
- Preserve Portuguese copy from the approved design.
- The landing page must include hero, presentation, objectives, categories, date/local, two-day schedule, registration CTA, and published results.
- Do not expose private rankings, service secrets, archive secret, drafts, evaluations, or audit payloads publicly.
- Follow `docs/superpowers/specs/2026-07-23-hackathon-ceitec-platform-design.md`.

---

## File Structure

- `app/pages/index.vue`: complete landing page.
- `public/brand/ceitec-horizontal-white.png`: dark-theme logo copied from the supplied brand assets.
- `supabase/migrations/2026072300061_public_event_content.sql`: event presentation and schedule.
- `app/components/landing/HeroSection.vue`: title and registration CTA.
- `app/components/landing/AboutSection.vue`: presentation/objectives.
- `app/components/landing/CategoriesSection.vue`: Júnior/Sênior explanation.
- `app/components/landing/ScheduleSection.vue`: accessible two-day schedule.
- `app/components/landing/PublicResults.vue`: published rankings.
- `app/pages/app/evento/[eventId]/admin/conteudo-publico.vue`: Professor public-content/schedule editor.
- `app/layouts/dashboard.vue`: role-aware navigation.
- `app/pages/app/index.vue`: dashboard routing/cards.
- `app/components/dashboard/StatusCard.vue`: reusable summary card.
- `app/error.vue`: recoverable error page.
- `server/api/health.get.ts`: deployment health endpoint.
- `tests/integration/landing.nuxt.test.ts`: public content tests.
- `tests/e2e/accessibility.spec.ts`: axe and keyboard checks.
- `tests/e2e/authorization.spec.ts`: cross-role/cross-event denial tests.
- `tests/e2e/release.spec.ts`: full release smoke test.
- `playwright.config.ts`: browser projects and web server.
- `.github/workflows/ci.yml`: automated quality gate.
- `README.md`: setup, environment, database, tests, deploy, and operations.
- `docs/operations/new-event.md`: safe new-hackathon runbook.

### Task 1: Complete Public Landing Page

**Files:**
- Create: `supabase/migrations/2026072300061_public_event_content.sql`
- Modify: `supabase/seed.sql`
- Create: `public/brand/ceitec-horizontal-white.png`
- Modify: `app/pages/index.vue`
- Create: `app/components/landing/HeroSection.vue`
- Create: `app/components/landing/AboutSection.vue`
- Create: `app/components/landing/CategoriesSection.vue`
- Create: `app/components/landing/ScheduleSection.vue`
- Create: `app/components/landing/PublicResults.vue`
- Create: `app/pages/app/evento/[eventId]/admin/conteudo-publico.vue`
- Create: `tests/integration/landing.nuxt.test.ts`

**Interfaces:**
- Consumes: anonymous-readable event metadata and `published_results`.
- Produces: semantic public page and `/resultados/[eventSlug]` links.

- [ ] **Step 1: Write failing public-content tests**

Create `tests/integration/landing.nuxt.test.ts`:

```ts
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { $fetch, setup } from '@nuxt/test-utils/e2e'

describe('CEITEC landing page', async () => {
  await setup({ rootDir: fileURLToPath(new URL('../..', import.meta.url)) })

  it('contains the complete event information', async () => {
    const html = await $fetch('/')
    for (const text of [
      'Hackathon CEITEC',
      'Criando soluções, conectando o futuro',
      'Categoria Júnior',
      'Categoria Sênior',
      '24 e 25 de julho',
      'CAC - CEI Roberto Freire',
      'Dia 1',
      'Dia 2',
    ]) expect(html).toContain(text)
  })
})
```

Run: `npx vitest run tests/integration/landing.nuxt.test.ts`

Expected: FAIL because the baseline page lacks sections.

- [ ] **Step 2: Build semantic landing components**

Copy the supplied dark-theme logo without modifying the source asset:

```bash
mkdir -p public/brand
cp "CEITEC_MARCAS/MARCA HORIZONTAL BRANCA.png" public/brand/ceitec-horizontal-white.png
```

Create public event content storage:

```sql
create table public.event_public_content (
  event_id uuid primary key references public.events(id),
  tagline text not null,
  presentation text not null,
  objectives jsonb not null,
  venue text not null,
  registration_open boolean not null default false
);

create table public.event_schedule_items (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id),
  day_number smallint not null check (day_number in (1, 2)),
  starts_at time not null,
  activity text not null,
  position integer not null,
  unique(event_id, day_number, position)
);

alter table public.event_public_content enable row level security;
alter table public.event_schedule_items enable row level security;
create policy "public reads active event content" on public.event_public_content for select to anon, authenticated
using (exists(select 1 from public.events e where e.id = event_id and e.status <> 'archived'));
create policy "public reads active schedule" on public.event_schedule_items for select to anon, authenticated
using (exists(select 1 from public.events e where e.id = event_id and e.status <> 'archived'));
```

Seed the supplied CEITEC presentation, objectives, venue, and every schedule row listed below in `supabase/seed.sql`.

Use one `h1`, sequential `h2` headings, semantic `section`, and real table markup for the schedule. The page queries `event_schedule_items`; `ScheduleSection.vue` accepts those rows as props and groups them using this typed shape:

```ts
const days = [
  {
    title: 'Dia 1 — Imersão e ideação',
    items: [
      ['14:00', 'Chegada e credenciamento'],
      ['14:30', 'Abertura oficial e explicação do Hackathon'],
      ['15:40', 'Pausa para lanche e networking'],
      ['16:00', 'Dinâmica de ideação guiada (5W2H)'],
      ['17:00', 'Checkpoint com mentores e desenvolvimento inicial'],
      ['18:00', 'Encerramento do Dia 1'],
    ],
  },
  {
    title: 'Dia 2 — Desenvolvimento e apresentação',
    items: [
      ['07:15', 'Acolhimento e energização'],
      ['07:30', 'Recall do dia anterior'],
      ['08:00', 'Trilhas simultâneas por categoria'],
      ['09:00', 'Desenvolvimento guiado dos projetos'],
      ['10:00', 'Intervalo para lanche'],
      ['10:20', 'Continuação do desenvolvimento'],
      ['11:30', 'Pré-pitch com mentores'],
      ['12:15', 'Intervalo para almoço'],
      ['13:15', 'Preparação final dos pitches'],
      ['14:00', 'Apresentações dos projetos'],
      ['16:30', 'Deliberação dos jurados'],
      ['17:15', 'Cerimônia de encerramento e premiação'],
    ],
  },
] as const
```

- [ ] **Step 3: Build the Professor public-content editor**

Allow the assigned Professor to edit tagline, presentation, objectives, venue, registration state, and ordered schedule rows for their event. Save through an RLS-protected upsert and validate every schedule row with:

```ts
const ScheduleItem = z.object({
  dayNumber: z.union([z.literal(1), z.literal(2)]),
  startsAt: z.string().regex(/^\d{2}:\d{2}$/),
  activity: z.string().trim().min(2).max(180),
  position: z.number().int().positive(),
})
```

The global landing page selects the event with `is_featured = true`; archived-event result pages continue using their slug.

- [ ] **Step 4: Compose page and published results**

The page must include the supplied presentation/objectives, category definitions, location/date, schedule, and CTAs to `/cadastro` and `/login`. `PublicResults` queries only the active event's published snapshot and renders nothing before publication.

- [ ] **Step 5: Verify and commit**

Run:

```bash
npx vitest run tests/integration/landing.nuxt.test.ts
npm run build
git add app tests/integration/landing.nuxt.test.ts
git commit -m "feat: complete CEITEC public landing page"
```

Expected: test PASS, build exits `0`, commit succeeds.

### Task 2: Role-Aware Dashboard and Error Recovery

**Files:**
- Create: `app/layouts/dashboard.vue`
- Create: `app/pages/app/index.vue`
- Create: `app/components/dashboard/StatusCard.vue`
- Create: `app/error.vue`
- Create: `server/api/health.get.ts`
- Create: `tests/integration/dashboard.nuxt.test.ts`

**Interfaces:**
- Consumes: `useCurrentAccess`, event/team/activity/evaluation progress.
- Produces: navigation filtered by allowed capabilities and `GET /api/health`.

- [ ] **Step 1: Test dashboard role visibility**

Mock each access profile and assert:

- global admin: Eventos, Professores, Auditoria;
- Professor: Equipes, Canvas, Avaliadores, Resultados;
- Monitor: Revisões;
- Avaliador: Avaliações;
- Aluno: Minha equipe, Atividades.

Run: `npx vitest run tests/integration/dashboard.nuxt.test.ts`

Expected: FAIL because dashboard components are absent.

- [ ] **Step 2: Build capability-based navigation**

Use explicit capabilities:

```ts
export type Capability =
  | 'manage_events'
  | 'manage_event'
  | 'review_submissions'
  | 'evaluate_teams'
  | 'collaborate'

const navigationByCapability: Record<Capability, { label: string; to: string }[]> = {
  manage_events: [{ label: 'Eventos', to: '/app/admin/eventos' }, { label: 'Professores', to: '/app/admin/solicitacoes' }],
  manage_event: [{ label: 'Equipes', to: 'equipes' }, { label: 'Canvas', to: 'atividades' }, { label: 'Resultados', to: 'admin/resultados' }],
  review_submissions: [{ label: 'Revisões', to: 'revisoes' }],
  evaluate_teams: [{ label: 'Avaliações', to: 'avaliacao' }],
  collaborate: [{ label: 'Minha equipe', to: 'equipe' }, { label: 'Atividades', to: 'atividades' }],
}
```

Deduplicate links, resolve event-relative paths, and keep server authorization independent of navigation visibility.

- [ ] **Step 3: Add resilient error and health endpoints**

`app/error.vue` must show a friendly Portuguese message, preserve a “Tentar novamente” action using `clearError`, and link home.

Create `server/api/health.get.ts`:

```ts
export default defineEventHandler(() => ({
  ok: true,
  service: 'hackathon-ceitec',
  timestamp: new Date().toISOString(),
}))
```

- [ ] **Step 4: Verify and commit**

Run:

```bash
npx vitest run tests/integration/dashboard.nuxt.test.ts
npm run build
git add app server tests/integration/dashboard.nuxt.test.ts
git commit -m "feat: add role dashboards and error recovery"
```

Expected: tests PASS, build exits `0`, commit succeeds.

### Task 3: Security and Accessibility Release Gates

**Files:**
- Create: `playwright.config.ts`
- Create: `tests/e2e/accessibility.spec.ts`
- Create: `tests/e2e/authorization.spec.ts`
- Modify: `package.json`

**Interfaces:**
- Consumes: seeded accounts for every role and two isolated events.
- Produces: `npm run test:a11y`, `npm run test:security`, and browser release gate.

- [ ] **Step 1: Configure Playwright**

Set `playwright.config.ts`:

```ts
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './tests/e2e',
  use: { baseURL: 'http://127.0.0.1:3000', trace: 'retain-on-failure' },
  webServer: { command: 'npm run dev -- --host 127.0.0.1', url: 'http://127.0.0.1:3000', reuseExistingServer: true },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile', use: { ...devices['Pixel 7'] } },
  ],
})
```

Install `@axe-core/playwright` and add scripts:

```json
{
  "test:a11y": "playwright test tests/e2e/accessibility.spec.ts",
  "test:security": "playwright test tests/e2e/authorization.spec.ts"
}
```

- [ ] **Step 2: Add accessibility tests**

For `/`, `/login`, the student Canvas, evaluator form, Monitor queue, and Professor results:

```ts
const results = await new AxeBuilder({ page }).analyze()
expect(results.violations).toEqual([])
```

Also use keyboard-only navigation to submit a score and verify focus moves to the first validation error.

- [ ] **Step 3: Add authorization tests**

Seed two events and assert direct URL/API attempts fail for:

- student reading another team's draft;
- Monitor approving a team;
- Monitor reopening a submission;
- evaluator reading another category;
- evaluator modifying another evaluator's score;
- Professor accessing another event;
- anonymous user reading administrative ranking;
- non-global user calling archive endpoint;
- any user modifying an archived event.

Expected HTTP status is `401`, `403`, or an empty RLS result according to the interface; never `200` with protected data.

- [ ] **Step 4: Run gates and commit**

Run:

```bash
npx supabase db reset
npm run test:a11y
npm run test:security
git add package.json package-lock.json playwright.config.ts tests/e2e
git commit -m "test: add accessibility and authorization gates"
```

Expected: desktop/mobile projects PASS; commit succeeds.

### Task 4: CI, Operations, and Production Verification

**Files:**
- Create: `.github/workflows/ci.yml`
- Create: `README.md`
- Create: `docs/operations/new-event.md`
- Create: `tests/e2e/release.spec.ts`
- Create: `supabase/migrations/202607230007_archive_configuration_copy.sql`
- Modify: `server/api/admin/archive-event.post.ts`
- Modify: `app/pages/app/admin/eventos.vue`

**Interfaces:**
- Consumes: all application modules and environment variables.
- Produces: reproducible CI and deployment runbook.

- [ ] **Step 1: Extend new-event creation with safe configuration copying**

Replace the original archive RPC with `archive_and_create_event(target_event,confirmed_name,actor,copy_config boolean)`. Keep all checks and archive/create actions from Plan 01 in the same transaction. When `copy_config` is true, copy:

- `event_public_content` and `event_schedule_items`;
- `evaluation_criteria` and their Júnior/Sênior `criterion_weights`;
- `canvas_templates` and their `canvas_template_blocks`.

Use `INSERT ... RETURNING id` loops to map old criterion/template IDs to new IDs. Do not read or insert teams, members, activities, submissions, reviews, evaluator assignments, presentation slots, evaluations, scores, tie decisions, published results, role assignments, or audit rows from the old event.

Modify the endpoint schema to:

```ts
const ArchiveBody = z.object({
  eventId: z.string().uuid(),
  eventName: z.string().min(1),
  archiveSecret: z.string().min(12),
  copyConfig: z.boolean(),
})
```

Add a “Copiar programação, critérios e modelos de Canvas” checkbox to the confirmation dialog and pass `copyConfig` to the RPC.

- [ ] **Step 2: Add continuous integration**

Create `.github/workflows/ci.yml`:

```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm
      - uses: supabase/setup-cli@v1
      - run: npm ci
      - run: npx playwright install --with-deps chromium
      - run: npx supabase start
      - run: npx supabase db reset
      - run: npx supabase db lint
      - run: npx supabase test db
      - run: npx vitest run
      - run: npx playwright test
      - run: npm run build
```

- [ ] **Step 3: Write operational documentation**

`README.md` must contain exact prerequisites, `npm ci`, `npx supabase start`, `npx supabase db reset`, environment key setup, Google callback URL, test commands, Vercel configuration, and local seeded accounts.

`docs/operations/new-event.md` must instruct the global admin to confirm published results, export audit data, open “Preparar novo hackathon”, reauthenticate, enter the event name and secret, choose reusable templates, verify the old event is read-only, and assign the new Professor.

- [ ] **Step 4: Add production smoke test**

`tests/e2e/release.spec.ts` must verify:

```ts
test('production-critical paths respond', async ({ page, request }) => {
  expect(await (await request.get('/api/health')).json()).toMatchObject({ ok: true })
  await page.goto('/')
  await expect(page.getByRole('heading', { name: 'Hackathon CEITEC' })).toBeVisible()
  await page.goto('/login')
  await expect(page.getByRole('button', { name: 'Continuar com Google' })).toBeVisible()
})
```

- [ ] **Step 5: Run complete local release gate**

Run:

```bash
npx supabase db reset
npx supabase db lint
npx supabase test db
npx vitest run
npx playwright test
npm run build
```

Expected: every command exits `0`.

- [ ] **Step 6: Deploy and verify**

Configure Vercel with the four variables from `.env.example`, configure Supabase site URL/callback URLs, deploy the built commit, and run:

```bash
PLAYWRIGHT_BASE_URL="$CEITEC_DEPLOYMENT_URL" npx playwright test tests/e2e/release.spec.ts
```

Expected: with `CEITEC_DEPLOYMENT_URL` set to the URL returned by Vercel, the release smoke test passes against production.

- [ ] **Step 7: Commit launch documentation**

Run:

```bash
git add .github README.md docs/operations tests/e2e/release.spec.ts supabase server/api/admin/archive-event.post.ts app/pages/app/admin/eventos.vue
git commit -m "chore: add CI and launch operations"
```

Expected: commit succeeds and the platform is ready for production handoff.
