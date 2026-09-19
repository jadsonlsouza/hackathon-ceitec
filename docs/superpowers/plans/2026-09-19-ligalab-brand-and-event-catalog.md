# Ligalab Brand and Event Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebrand the platform as Ligalab and replace the single-event public landing with a secure Ligalab home, public event catalog, and event detail route while preserving Hackathon CEITEC as its first event.

**Architecture:** The existing event public-content tables remain the source of truth. A narrowly scoped database migration exposes a public catalog and slug-specific content RPC; Nitro endpoints are the only browser-facing access to those RPCs. The public UI separates platform identity from event identity through reusable header/logo/catalog components and moves the existing event sections under `/eventos/:eventSlug`.

**Tech Stack:** Nuxt 4, Vue 3, TypeScript, CSS custom properties, Nitro server routes, Supabase/Postgres RPCs with pgTAP, Vitest, Playwright, Vercel.

**Spec:** `docs/superpowers/specs/2026-09-19-ligalab-brand-and-event-catalog-design.md`

## Global Constraints

- Use **ligalab** for platform identity; retain **Hackathon CEITEC** in event records, event detail copy, fixture events, historical results, and public slugs.
- Use CSS custom properties and the existing theme system; do not add a component library, a remote font, or a client-side data SDK.
- Keep public event queries behind fixed-path `SECURITY DEFINER` RPCs and Nitro endpoints. Do not grant browser roles table access.
- Public results remain limited to already published categories.
- Production endpoint failures must be sanitized and must not fall back to a static event that presents a registration CTA.
- Copy the supplied assets into `public/brand/` as optimized Ligalab image files; do not retain their source paths outside the repository.
- Preserve keyboard navigation, 44px minimum interactive targets, skip links, focus indicators, `lang="pt-BR"`, theme behavior, and WCAG AA text contrast.
- Do not rename technical project identifiers, existing event slugs, production URLs, or E2E authentication accounts.

## Review Focus

- A public catalog request must exclude archived, unfeatured, and content-less events; Task 1 pgTAP asserts all three cases.
- An unknown event slug must not render a registration CTA or leak a database error; Task 2 API and Task 4 SSR tests assert its safe 404 state.
- An API failure in production must not expose the CEITEC fallback registration path; Task 2 unit test runs with fallback disabled and asserts 503/sanitized output.
- A color/white logo must retain an accessible name and fixed intrinsic dimensions; Task 3 component tests assert image alt/aria behavior and width/height.
- Switching light/dark themes must keep the catalog header links visible and focused; Task 3 mounted test checks both token classes and a focused link after toggle.

---

### Task 1: Secure public event catalog and slug content RPCs

**Files:**
- Create: `supabase/migrations/<timestamp>_ligalab_public_event_catalog.sql`
- Modify: `tests/integration/public-content.sql`
- Modify: `app/types/database.types.ts` (only after generating/refining types if the repo’s generated types include new RPCs)

**Interfaces:**
- Consumes: `public.events`, `public.event_public_content`, `public.event_schedule_items`, `public.get_published_results(text)`.
- Produces: `public.get_public_event_catalog()` returning `(event_name text, event_slug text, tagline text, venue text, date_label text, registration_open boolean)` and `public.get_public_event_content(requested_slug text)` returning the existing `PublicEventContent` fields for one public event.
- Guarantees: no direct table grants, `SECURITY DEFINER`, `set search_path = ''`, `anon` and `authenticated` receive execute only.

- [ ] **Step 1: Write failing pgTAP assertions for public catalog visibility**

  Add fixtures for a visible event, an archived event, an event without `event_public_content`, and a non-featured event. Add assertions like:

  ```sql
  select results_eq(
    $$ select event_slug from public.get_public_event_catalog() order by event_slug $$,
    $$ values ('landing-ceitec') $$,
    'catalog returns only a featured, non-archived event with public content'
  );

  select is_empty(
    $$ select * from public.get_public_event_content('missing-event') $$,
    'unknown public event slug has no content'
  );

  select throws_ok(
    $$ select * from public.event_public_content $$,
    '42501', null,
    'anon cannot read public content table directly'
  );
  ```

- [ ] **Step 2: Run the pgTAP file to verify RED**

  Run: `npx supabase test db tests/integration/public-content.sql`

  Expected: FAIL because `get_public_event_catalog()` and `get_public_event_content(text)` do not exist.

- [ ] **Step 3: Create the migration via the Supabase CLI and implement the two RPCs**

  Use `npx supabase migration new ligalab_public_event_catalog`, then implement both SQL functions with an empty `search_path`. Build `schedule` with ordered `jsonb_agg`; use `event.is_featured`, `event.status <> 'archived'`, `event.archived_at is null`, and an inner join to `event_public_content`. For detail content, filter exact `event.slug = requested_slug` and return no row for missing/non-public events. Revoke all function permissions first, then grant execute to `anon, authenticated`.

  ```sql
  create function public.get_public_event_catalog()
  returns table (
    event_name text, event_slug text, tagline text,
    venue text, date_label text, registration_open boolean
  )
  language sql stable security definer set search_path = '' as $$
    select event.name, event.slug, content.tagline,
           content.venue, content.date_label, content.registration_open
    from public.events event
    join public.event_public_content content on content.event_id = event.id
    where event.is_featured and event.status <> 'archived'
      and event.archived_at is null
    order by event.created_at desc, event.name;
  $$;
  ```

- [ ] **Step 4: Run the focused pgTAP test to verify GREEN**

  Run: `npx supabase db reset && npx supabase test db tests/integration/public-content.sql`

  Expected: PASS, including direct-table denial, filtered catalog, detail isolation, and published-result behavior.

- [ ] **Step 5: Commit the isolated database change**

  ```bash
  git add supabase/migrations/*_ligalab_public_event_catalog.sql tests/integration/public-content.sql app/types/database.types.ts
  git commit -m "feat: expose public event catalog safely"
  ```

### Task 2: Add typed Nitro data endpoints with safe production failure behavior

**Files:**
- Create: `app/data/public-events.ts`
- Create: `server/api/public-events.get.ts`
- Create: `server/api/public-events/[eventSlug].get.ts`
- Modify: `server/api/public-event.get.ts` (make it a compatibility wrapper or remove callers after Task 4)
- Modify: `tests/unit/public-event-api.test.ts`
- Create: `tests/unit/public-events-api.test.ts`

**Interfaces:**
- Consumes: the two Task 1 RPCs and Nuxt runtime config fields `supabaseUrl`, `supabasePublishableKey`, `allowStaticPublicContentFallback`.
- Produces: `PublicEventCard[]` from `/api/public-events` and `PublicEventContent` or Nuxt `404` from `/api/public-events/:eventSlug`.
- Guarantees: server requests only send `apikey`; fallback data exists only in non-production test/dev; upstream failures become sanitized `503` responses.

- [ ] **Step 1: Write failing endpoint tests**

  Define the shared types and make the tests assert both exact RPC request and failure behavior:

  ```ts
  it('uses apikey without Authorization for the public catalog RPC', async () => {
    await handler()
    expect(fetchMock).toHaveBeenCalledWith(expect.stringContaining('/rpc/get_public_event_catalog'), {
      method: 'POST', headers: { apikey: 'public-key' }, body: {},
    })
  })

  it('returns a sanitized 503 instead of a registration fallback in production', async () => {
    runtime.allowStaticPublicContentFallback = false
    fetchMock.mockRejectedValueOnce(new Error('connection refused'))
    await expect(handler()).rejects.toMatchObject({ statusCode: 503 })
  })
  ```

- [ ] **Step 2: Run the new API tests to verify RED**

  Run: `npx vitest run tests/unit/public-events-api.test.ts`

  Expected: FAIL because the typed module and catalog/detail handlers are absent.

- [ ] **Step 3: Implement the shared types and minimal server handlers**

  In `app/data/public-events.ts`, export `PublicEventCard`, `PublicScheduleItem`, `PublishedCategoryResult`, and `PublicEventContent`. In handlers, POST `{}` or `{ requested_slug: getRouterParam(event, 'eventSlug') }` to the relevant RPC. Reject malformed slugs before requesting the API. Use `createError({ statusCode: 404, statusMessage: 'Evento não encontrado.' })` for empty rows and `503` with a Portuguese generic message for upstream failures. Retain the CEITEC static fixture only behind `allowStaticPublicContentFallback` for development/test.

- [ ] **Step 4: Run API tests to verify GREEN**

  Run: `npx vitest run tests/unit/public-event-api.test.ts tests/unit/public-events-api.test.ts`

  Expected: PASS, including apikey-only requests, unknown-slug 404, and production-safe failures.

- [ ] **Step 5: Commit the endpoint layer**

  ```bash
  git add app/data/public-events.ts server/api/public-event.get.ts server/api/public-events.get.ts server/api/public-events/[eventSlug].get.ts tests/unit/public-event-api.test.ts tests/unit/public-events-api.test.ts
  git commit -m "feat: add public event catalog API"
  ```

### Task 3: Install Ligalab brand assets and reusable public navigation

**Files:**
- Create: `public/brand/ligalab-horizontal-white.png`
- Create: `public/brand/ligalab-color.png`
- Create: `app/components/brand/BrandLogo.vue`
- Create: `app/components/landing/PlatformHeader.vue`
- Modify: `app/assets/css/main.css`
- Modify: `app/layouts/dashboard.vue`
- Modify: `app/error.vue`
- Modify: `app/pages/login.vue`
- Modify: `app/pages/cadastro.vue`
- Modify: `app/pages/onboarding.vue`
- Modify: `app/pages/recuperar-senha.vue`
- Modify: `app/pages/redefinir-senha.vue`
- Modify: `nuxt.config.ts`
- Create: `tests/component/brand-logo.test.ts`
- Modify: `tests/component/landing-components.test.ts`

**Interfaces:**
- Consumes: user-supplied horizontal white and color Ligalab images.
- Produces: `<BrandLogo variant="light"|"dark" decorative?>` and `<PlatformHeader />` with links to `/`, `/eventos`, `/login`, and `/cadastro`.
- Guarantees: logo intrinsic dimensions, accessible platform label when non-decorative, theme-visible header links, and Ligalab as application title.

- [ ] **Step 1: Write failing component tests for the new brand and navigation**

  ```ts
  it('renders the Ligalab dark-background logo with an accessible platform name', () => {
    const wrapper = mount(BrandLogo, { props: { variant: 'dark' } })
    expect(wrapper.get('img').attributes('src')).toBe('/brand/ligalab-horizontal-white.png')
    expect(wrapper.get('img').attributes('alt')).toBe('ligalab')
    expect(wrapper.get('img').attributes('width')).toBeTruthy()
  })

  it('keeps Eventos focused after switching the platform theme', async () => {
    const wrapper = mount(PlatformHeader)
    const events = wrapper.get('a[href="/eventos"]')
    await events.trigger('focus')
    await wrapper.get('button[aria-label*="tema"]').trigger('click')
    expect(document.activeElement).toBe(events.element)
  })
  ```

- [ ] **Step 2: Run component tests to verify RED**

  Run: `npx vitest run tests/component/brand-logo.test.ts tests/component/landing-components.test.ts`

  Expected: FAIL because the assets/components and Ligalab navigation do not yet exist.

- [ ] **Step 3: Create optimized local assets and implement shared brand components**

  Copy the supplied images into the two exact paths, preserving transparency if available and using the supplied visual variants. Implement `BrandLogo` with immutable width/height values and variant-selected source. Implement `PlatformHeader` with semantic `<nav aria-label="Navegação principal">`, the existing theme toggle, and 44px links/buttons. Replace CEITEC dashboard/logo references with `BrandLogo variant="dark"` and institutional text. Change Nuxt default head title to `ligalab`.

- [ ] **Step 4: Add token-scoped CSS without breaking event detail styling**

  Add `.platform-header`, `.ligalab-home`, `.event-catalog`, `.event-card`, and brand logo rules using only existing `--surface-*`, `--text-*`, and `--accent-*` tokens. Keep the color logo on light raised surfaces and white logo on the dark dashboard/footer/header. Do not use a fixed black/white text color where a theme token is required.

- [ ] **Step 5: Run the component tests to verify GREEN**

  Run: `npx vitest run tests/component/brand-logo.test.ts tests/component/landing-components.test.ts`

  Expected: PASS with Ligalab alt text, intrinsic image layout protection, Events/Login/Register navigation, and theme focus persistence.

- [ ] **Step 6: Commit shared branding**

  ```bash
  git add public/brand/ligalab-horizontal-white.png public/brand/ligalab-color.png app/components/brand/BrandLogo.vue app/components/landing/PlatformHeader.vue app/assets/css/main.css app/layouts/dashboard.vue app/error.vue app/pages/login.vue app/pages/cadastro.vue app/pages/onboarding.vue app/pages/recuperar-senha.vue app/pages/redefinir-senha.vue nuxt.config.ts tests/component/brand-logo.test.ts tests/component/landing-components.test.ts
  git commit -m "feat: apply Ligalab platform branding"
  ```

### Task 4: Build Ligalab home, event catalog, and dynamic event detail page

**Files:**
- Create: `app/components/landing/EventCard.vue`
- Create: `app/components/landing/EventCatalog.vue`
- Create: `app/components/landing/LigalabHome.vue`
- Create: `app/pages/eventos/index.vue`
- Create: `app/pages/eventos/[eventSlug].vue`
- Modify: `app/pages/index.vue`
- Modify: `app/components/landing/HeroSection.vue`
- Modify: `app/components/landing/UnavailableState.vue`
- Modify: `app/components/landing/PublicResults.vue`
- Modify: `tests/integration/landing.nuxt.test.ts`
- Create: `tests/integration/events.nuxt.test.ts`
- Modify: `tests/component/landing-components.test.ts`

**Interfaces:**
- Consumes: `/api/public-events`, `/api/public-events/:eventSlug`, `PlatformHeader`, `EventCard`, and existing event detail section components.
- Produces: public pages `/`, `/eventos`, and `/eventos/:eventSlug`.
- Guarantees: root is Ligalab-only, cards never expose private participant data, event detail retains CEITEC-specific content and registration based on that event’s `registration_open`.

- [ ] **Step 1: Write failing SSR and mounted tests for all public route states**

  ```ts
  it('renders Ligalab at the root and links users to the catalog', async () => {
    const html = await $fetch('/')
    expect(html).toContain('ligalab')
    expect(html).toContain('href="/eventos"')
    expect(html).not.toContain('Acessar sistema de inscrição')
  })

  it('renders the CEITEC event from its slug without renaming it', async () => {
    const html = await $fetch('/eventos/hackathon-ceitec')
    expect(html).toContain('Hackathon CEITEC')
    expect(html).toContain('Criando soluções, conectando o futuro')
  })

  it('uses a safe unavailable state for an unknown event', async () => {
    const html = await $fetch('/eventos/inexistente', { ignoreResponseError: true })
    expect(html).toContain('Evento não encontrado')
    expect(html).not.toContain('href="/cadastro"')
  })
  ```

- [ ] **Step 2: Run the public route tests to verify RED**

  Run: `npx vitest run tests/integration/landing.nuxt.test.ts tests/integration/events.nuxt.test.ts tests/component/landing-components.test.ts`

  Expected: FAIL because `/eventos` and dynamic public event pages do not exist and root remains event-specific.

- [ ] **Step 3: Implement catalog components and the Ligalab home**

  `EventCard` renders event name, tagline, venue/date, an accessible registration status, and `<NuxtLink :to="\`/eventos/${event.event_slug}\`">Ver evento</NuxtLink>`. `EventCatalog` handles loading, empty, and failed data states. `LigalabHome` uses the color brand, a concise platform statement, `PlatformHeader`, and a CTA to `/eventos`; it must not render per-event enrollment buttons.

- [ ] **Step 4: Move detailed event rendering to slug route**

  In `/eventos/[eventSlug].vue`, fetch from the detail endpoint and set event-specific title/description. Update `HeroSection` to receive `eventSlug`, point its platform logo to `/`, include a visible `Eventos` link, and make its registration CTA point to `/cadastro` only for `registrationOpen`. Retain `AboutSection`, categories, facts, schedule, and `PublicResults`. Root `index.vue` becomes Ligalab home; do not duplicate the detail sections there.

- [ ] **Step 5: Implement explicit empty/404 behavior**

  Make `UnavailableState` accept `kind: 'catalog' | 'event' | 'service'` and render exactly the safe text and links for that state. The event missing state offers `/eventos` and `/login`, never `/cadastro`.

- [ ] **Step 6: Run route/component tests to verify GREEN**

  Run: `npx vitest run tests/integration/landing.nuxt.test.ts tests/integration/events.nuxt.test.ts tests/component/landing-components.test.ts`

  Expected: PASS for Ligalab root, event catalog, CEITEC detail preservation, empty catalog, unknown slug, and no unsafe registration CTA.

- [ ] **Step 7: Commit public navigation and pages**

  ```bash
  git add app/components/landing/EventCard.vue app/components/landing/EventCatalog.vue app/components/landing/LigalabHome.vue app/pages/index.vue app/pages/eventos/index.vue app/pages/eventos/[eventSlug].vue app/components/landing/HeroSection.vue app/components/landing/UnavailableState.vue app/components/landing/PublicResults.vue tests/integration/landing.nuxt.test.ts tests/integration/events.nuxt.test.ts tests/component/landing-components.test.ts
  git commit -m "feat: add Ligalab home and event catalog"
  ```

### Task 5: Complete the institutional rebrand and release verification

**Files:**
- Modify: `app/pages/resultados/[eventSlug].vue`
- Modify: `app/composables/useAuth.ts`
- Modify: `server/api/health.get.ts`
- Modify: `README.md`
- Modify: `tests/integration/smoke.nuxt.test.ts`
- Modify: `tests/integration/dashboard.nuxt.test.ts`
- Modify: `tests/e2e/release.spec.ts`
- Modify: `tests/e2e/accessibility.spec.ts`
- Modify: `tests/e2e/fixtures.sql` only where assertions or visible labels need Ligalab; retain CEITEC event names and email domains.

**Interfaces:**
- Consumes: Task 3 platform branding and Task 4 public routes.
- Produces: Ligalab institutional copy everywhere outside event-owned content, Ligalab health service identifier, and release/a11y coverage for the new routes.
- Guarantees: event slugs and technical Vercel project naming remain unchanged.

- [ ] **Step 1: Write failing regression assertions for institutional versus event naming**

  ```ts
  it('uses Ligalab for the application title and Hackathon CEITEC for its event detail', async () => {
    expect(await $fetch('/login')).toContain('ligalab')
    expect(await $fetch('/eventos/hackathon-ceitec')).toContain('Hackathon CEITEC')
    expect((await $fetch('/api/health')).service).toBe('ligalab')
  })
  ```

- [ ] **Step 2: Run these regression tests to verify RED**

  Run: `npx vitest run tests/integration/smoke.nuxt.test.ts tests/integration/dashboard.nuxt.test.ts`

  Expected: FAIL where old institutional CEITEC names or health service values remain.

- [ ] **Step 3: Make targeted copy/configuration/test changes**

  Replace platform-level labels and document titles with `ligalab`. Keep dynamic event names untouched. Update the authentication redirect default only if it remains an obsolete public Vercel URL; do not hardcode a new deployment hostname. Change health `service` to `ligalab`, then update only test expectations that represent institutional identity. Ensure the README distinguishes the Ligalab platform from the Hackathon CEITEC example event.

- [ ] **Step 4: Run focused regression tests to verify GREEN**

  Run: `npx vitest run tests/integration/smoke.nuxt.test.ts tests/integration/dashboard.nuxt.test.ts tests/e2e/release.spec.ts`

  Expected: PASS in the configured test harness, showing Ligalab platform identity and intact Hackathon CEITEC event identity.

- [ ] **Step 5: Run full verification**

  Run:

  ```bash
  npx supabase db reset
  npx supabase test db tests/integration
  npx vitest run
  npm run build
  npx playwright test
  git diff --check
  ```

  Expected: pgTAP, Vitest, production build, browser accessibility/release checks, and whitespace validation all pass. If Docker/browser infrastructure is unavailable, record the exact failed prerequisite and run every remaining command successfully.

- [ ] **Step 6: Commit verification-aligned rebrand changes**

  ```bash
  git add app/pages/resultados/[eventSlug].vue app/composables/useAuth.ts server/api/health.get.ts README.md tests/integration/smoke.nuxt.test.ts tests/integration/dashboard.nuxt.test.ts tests/e2e/release.spec.ts tests/e2e/accessibility.spec.ts tests/e2e/fixtures.sql
  git commit -m "chore: finish Ligalab platform rebrand"
  ```

## Plan Self-Review

- **Spec coverage:** Tasks 1–2 implement secure catalog/detail data flow and safe failures; Task 3 implements assets, shared navigation, themes and accessibility; Task 4 implements the three new public pages and event preservation; Task 5 covers remaining institutional text, docs, E2E and complete verification.
- **Placeholder scan:** no TBD/TODO/follow-up implementation placeholders; every task names concrete files, APIs, tests, commands and expected outcomes.
- **Type consistency:** `PublicEventCard` and `PublicEventContent` are defined in Task 2 and consumed unchanged in Tasks 3–4. RPC names defined in Task 1 match Task 2 endpoints.
- **Review focus coverage:** each of the five risky cases is assigned to an explicit Task 1–4 test step.
