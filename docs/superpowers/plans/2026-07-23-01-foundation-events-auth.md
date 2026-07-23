# Foundation, Events, and Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a deployable Nuxt application with Supabase authentication, multi-event isolation, five profiles, approval workflows, and safe event archiving.

**Architecture:** Nuxt owns the public shell and authenticated UI; Supabase Auth owns Google and password identities; PostgreSQL tables, RPCs, grants, and RLS own authorization. Global administration uses a server-only endpoint for the extra archive secret.

**Tech Stack:** Nuxt 4, Vue 3, TypeScript, CSS, Supabase Auth/PostgreSQL/Realtime, Vitest, Nuxt Test Utils, Playwright

## Global Constraints

- Use Nuxt 4 and Vue 3.
- Deploy the Nuxt application to Vercel.
- Use Supabase Auth with Google OAuth and e-mail/password.
- Enable RLS on every table exposed through the Data API.
- Every operational row belongs to one `event_id`.
- Every new account starts as `student`.
- Use native dark mode and Portuguese UI copy.
- Keep the Supabase secret key and `EVENT_ARCHIVE_SECRET` server-only.
- Never delete an event; archive it as read-only.
- Follow the approved design at `docs/superpowers/specs/2026-07-23-hackathon-ceitec-platform-design.md`.

---

## File Structure

- `app/app.vue`: global application shell.
- `app/assets/css/main.css`: dark theme and shared accessibility styles.
- `app/layouts/default.vue`: public layout.
- `app/layouts/dashboard.vue`: authenticated navigation.
- `app/middleware/auth.ts`: blocks anonymous dashboard access.
- `app/middleware/global-admin.ts`: blocks non-global administrators.
- `app/pages/login.vue`: password and Google login.
- `app/pages/cadastro.vue`: account creation and requested-role selection.
- `app/pages/recuperar-senha.vue`: password recovery.
- `app/pages/redefinir-senha.vue`: password update.
- `app/pages/app/index.vue`: role-aware dashboard entry.
- `app/pages/app/admin/eventos.vue`: global event management.
- `app/pages/app/admin/solicitacoes.vue`: Professor approvals.
- `app/pages/app/evento/[eventId]/solicitacoes.vue`: Monitor/Avaliador approvals.
- `app/composables/useAuth.ts`: browser authentication API.
- `app/composables/useCurrentAccess.ts`: profile and event-role state.
- `app/types/database.ts`: generated Supabase types.
- `server/api/admin/archive-event.post.ts`: secret-protected archive endpoint.
- `server/utils/supabase-admin.ts`: server-only Supabase client.
- `shared/domain/access.ts`: stable role and request types.
- `supabase/config.toml`: local Supabase configuration.
- `supabase/seed.sql`: first global administrator and CEITEC event fixtures.
- `supabase/migrations/202607230001_identity_events.sql`: profiles, events, roles, requests, audit, functions, and RLS.
- `supabase/migrations/2026072300021_event_lifecycle.sql`: transactional archive-and-create RPC.
- `tests/unit/access.test.ts`: role-transition unit tests.
- `tests/integration/auth.nuxt.test.ts`: auth screen integration tests.
- `tests/e2e/auth-and-roles.spec.ts`: browser-level access journey.

### Task 1: Nuxt Application Baseline

**Files:**
- Create: `package.json`
- Create: `nuxt.config.ts`
- Create: `app/app.vue`
- Create: `app/assets/css/main.css`
- Create: `app/pages/index.vue`
- Create: `tests/integration/smoke.nuxt.test.ts`

**Interfaces:**
- Consumes: none.
- Produces: Nuxt app scripts `dev`, `build`, `test`, `test:unit`, `test:e2e`, and environment keys `NUXT_PUBLIC_SUPABASE_URL`, `NUXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`.

- [ ] **Step 1: Scaffold Nuxt and install test/runtime dependencies**

Run:

```bash
npm create nuxt@latest . -- --packageManager npm --gitInit false
npm install @supabase/supabase-js zod
npm install -D @nuxt/test-utils vitest @vue/test-utils happy-dom @playwright/test
```

Expected: `package.json`, `nuxt.config.ts`, `app/app.vue`, and `node_modules` exist.

- [ ] **Step 2: Write the failing smoke test**

Create `tests/integration/smoke.nuxt.test.ts`:

```ts
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { $fetch, setup } from '@nuxt/test-utils/e2e'

describe('application shell', async () => {
  await setup({ rootDir: fileURLToPath(new URL('../..', import.meta.url)) })

  it('renders the CEITEC heading', async () => {
    expect(await $fetch('/')).toContain('Hackathon CEITEC')
  })
})
```

- [ ] **Step 3: Run the smoke test and confirm failure**

Run: `npx vitest run tests/integration/smoke.nuxt.test.ts`

Expected: FAIL because the CEITEC heading is absent.

- [ ] **Step 4: Configure the app and render the initial shell**

Set `nuxt.config.ts` to:

```ts
export default defineNuxtConfig({
  compatibilityDate: '2026-07-23',
  css: ['~/assets/css/main.css'],
  runtimeConfig: {
    supabaseSecretKey: '',
    eventArchiveSecret: '',
    public: {
      supabaseUrl: '',
      supabasePublishableKey: '',
    },
  },
  typescript: { strict: true },
})
```

Set `app/app.vue` to:

```vue
<template>
  <NuxtLayout>
    <NuxtPage />
  </NuxtLayout>
</template>
```

Set `app/pages/index.vue` to:

```vue
<template>
  <main>
    <h1>Hackathon CEITEC</h1>
    <p>Criando soluções, conectando o futuro.</p>
    <NuxtLink to="/cadastro">Inscreva-se agora</NuxtLink>
  </main>
</template>
```

Set `app/assets/css/main.css` to:

```css
:root { color-scheme: dark; font-family: Inter, ui-sans-serif, system-ui, sans-serif; }
* { box-sizing: border-box; }
body { margin: 0; min-height: 100vh; background: #070b14; color: #f8fafc; }
a { color: inherit; }
button, input, select, textarea { font: inherit; }
:focus-visible { outline: 3px solid #38bdf8; outline-offset: 2px; }
```

- [ ] **Step 5: Verify and commit the baseline**

Run:

```bash
npx vitest run tests/integration/smoke.nuxt.test.ts
npm run build
git add package.json package-lock.json nuxt.config.ts app tests/integration/smoke.nuxt.test.ts
git commit -m "feat: scaffold Nuxt application"
```

Expected: test PASS, build exits `0`, commit succeeds.

### Task 2: Identity and Event Database Boundary

**Files:**
- Create: `supabase/config.toml`
- Create: `supabase/migrations/202607230001_identity_events.sql`
- Create: `supabase/seed.sql`
- Create: `shared/domain/access.ts`
- Create: `tests/unit/access.test.ts`

**Interfaces:**
- Consumes: Supabase Auth `auth.users`.
- Produces: tables `profiles`, `events`, `event_roles`, `role_requests`, `audit_log`; functions `is_global_admin()`, `is_event_professor(uuid)`; TypeScript types `GlobalRole`, `EventRole`, `RoleRequestStatus`.

- [ ] **Step 1: Define and test stable access types**

Create `tests/unit/access.test.ts`:

```ts
import { describe, expect, it } from 'vitest'
import { canApproveRequest } from '../../shared/domain/access'

describe('canApproveRequest', () => {
  it('allows global admin to approve professors', () => {
    expect(canApproveRequest('global_admin', null, 'professor')).toBe(true)
  })

  it('allows professor to approve monitor and evaluator only', () => {
    expect(canApproveRequest('student', 'professor', 'monitor')).toBe(true)
    expect(canApproveRequest('student', 'professor', 'professor')).toBe(false)
  })
})
```

Run: `npx vitest run tests/unit/access.test.ts`

Expected: FAIL because `shared/domain/access.ts` does not exist.

- [ ] **Step 2: Implement the access types**

Create `shared/domain/access.ts`:

```ts
export type GlobalRole = 'student' | 'global_admin'
export type EventRole = 'professor' | 'monitor' | 'evaluator'
export type RequestedRole = EventRole
export type RoleRequestStatus = 'pending' | 'approved' | 'rejected' | 'revoked'

export function canApproveRequest(
  globalRole: GlobalRole,
  eventRole: EventRole | null,
  requestedRole: RequestedRole,
): boolean {
  if (globalRole === 'global_admin') return requestedRole === 'professor'
  return eventRole === 'professor' && ['monitor', 'evaluator'].includes(requestedRole)
}
```

Run: `npx vitest run tests/unit/access.test.ts`

Expected: PASS.

- [ ] **Step 3: Create the identity and event migration**

Create `supabase/migrations/202607230001_identity_events.sql` with:

```sql
create type public.global_role as enum ('student', 'global_admin');
create type public.event_role as enum ('professor', 'monitor', 'evaluator');
create type public.request_status as enum ('pending', 'approved', 'rejected', 'revoked');
create type public.event_status as enum ('draft', 'registration_open', 'in_progress', 'evaluation', 'results_published', 'archived');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  display_name text not null default '',
  global_role public.global_role not null default 'student',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  status public.event_status not null default 'draft',
  is_featured boolean not null default false,
  starts_at timestamptz,
  ends_at timestamptz,
  professor_id uuid references public.profiles(id),
  archived_at timestamptz,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  check ((status = 'archived') = (archived_at is not null))
);

create unique index one_featured_event on public.events(is_featured) where is_featured;

create table public.event_roles (
  event_id uuid not null references public.events(id),
  user_id uuid not null references public.profiles(id),
  role public.event_role not null,
  categories text[] not null default '{}',
  approved_by uuid not null references public.profiles(id),
  approved_at timestamptz not null default now(),
  primary key (event_id, user_id, role)
);

create table public.role_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  event_id uuid not null references public.events(id),
  requested_role public.event_role not null,
  status public.request_status not null default 'pending',
  decided_by uuid references public.profiles(id),
  decided_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index one_open_role_request
on public.role_requests (user_id, event_id, requested_role)
where status = 'pending';

create table public.audit_log (
  id bigint generated always as identity primary key,
  event_id uuid references public.events(id),
  actor_id uuid references public.profiles(id),
  action text not null,
  entity_type text not null,
  entity_id text not null,
  payload jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, email, display_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  if coalesce(new.raw_user_meta_data ->> 'requested_role', 'student') <> 'student'
    and nullif(new.raw_user_meta_data ->> 'event_id', '') is not null then
    insert into public.role_requests(user_id, event_id, requested_role)
    values (
      new.id,
      (new.raw_user_meta_data ->> 'event_id')::uuid,
      (new.raw_user_meta_data ->> 'requested_role')::public.event_role
    );
  end if;
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users for each row execute function public.handle_new_user();

create function public.is_global_admin() returns boolean
language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.profiles where id = auth.uid() and global_role = 'global_admin'); $$;

create function public.is_event_professor(target_event uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.events where id = target_event and professor_id = auth.uid()); $$;

alter table public.profiles enable row level security;
alter table public.events enable row level security;
alter table public.event_roles enable row level security;
alter table public.role_requests enable row level security;
alter table public.audit_log enable row level security;

create policy "profile self read" on public.profiles for select to authenticated using (id = auth.uid() or public.is_global_admin());
create policy "events visible to authenticated" on public.events for select to authenticated using (true);
create policy "global admins manage events" on public.events for all to authenticated using (public.is_global_admin()) with check (public.is_global_admin());
create policy "roles visible to owner and admins" on public.event_roles for select to authenticated
using (user_id = auth.uid() or public.is_global_admin() or public.is_event_professor(event_id));
create policy "requests created by owner" on public.role_requests for insert to authenticated with check (user_id = auth.uid());
create policy "requests visible to decision makers" on public.role_requests for select to authenticated
using (user_id = auth.uid() or public.is_global_admin() or (event_id is not null and public.is_event_professor(event_id)));
create policy "audit visible to admins" on public.audit_log for select to authenticated
using (public.is_global_admin() or (event_id is not null and public.is_event_professor(event_id)));
```

- [ ] **Step 4: Reset the local database and inspect policies**

Run:

```bash
npx supabase init
npx supabase start
npx supabase db reset
npx supabase db lint
```

Expected: reset and lint finish without SQL errors.

- [ ] **Step 5: Generate database types and commit**

Run:

```bash
npx supabase gen types typescript --local > app/types/database.ts
git add supabase shared/domain/access.ts app/types/database.ts tests/unit/access.test.ts
git commit -m "feat: add identity and event authorization schema"
```

Expected: generated types include `profiles`, `events`, `event_roles`, and `role_requests`; commit succeeds.

### Task 3: Password and Google Authentication

**Files:**
- Create: `app/plugins/supabase.client.ts`
- Create: `app/composables/useAuth.ts`
- Create: `app/pages/login.vue`
- Create: `app/pages/cadastro.vue`
- Create: `app/pages/recuperar-senha.vue`
- Create: `app/pages/redefinir-senha.vue`
- Create: `app/middleware/auth.ts`
- Create: `tests/integration/auth.nuxt.test.ts`

**Interfaces:**
- Consumes: runtime Supabase URL/publishable key and `profiles`.
- Produces: `signInWithPassword(email,password)`, `signUp(input)`, `signInWithGoogle()`, `sendPasswordReset(email)`, `signOut()`.

- [ ] **Step 1: Write failing auth-page tests**

Create `tests/integration/auth.nuxt.test.ts`:

```ts
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { $fetch, setup } from '@nuxt/test-utils/e2e'

describe('auth pages', async () => {
  await setup({ rootDir: fileURLToPath(new URL('../..', import.meta.url)) })

  it('offers password and Google login', async () => {
    const html = await $fetch('/login')
    expect(html).toContain('Entrar com e-mail')
    expect(html).toContain('Continuar com Google')
  })
})
```

Run: `npx vitest run tests/integration/auth.nuxt.test.ts`

Expected: FAIL with route not found.

- [ ] **Step 2: Create the browser client and auth composable**

Create `app/plugins/supabase.client.ts`:

```ts
import { createClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database'

export default defineNuxtPlugin(() => {
  const config = useRuntimeConfig()
  const supabase = createClient<Database>(
    config.public.supabaseUrl,
    config.public.supabasePublishableKey,
    { auth: { flowType: 'pkce', persistSession: true, detectSessionInUrl: true } },
  )
  return { provide: { supabase } }
})
```

Create `app/composables/useAuth.ts`:

```ts
export interface SignUpInput {
  name: string
  email: string
  password: string
  requestedRole: 'student' | 'professor' | 'monitor' | 'evaluator'
  eventId?: string
}

export function useAuth() {
  const { $supabase } = useNuxtApp()
  const signInWithPassword = (email: string, password: string) =>
    $supabase.auth.signInWithPassword({ email, password })
  const signUp = (input: SignUpInput) =>
    $supabase.auth.signUp({
      email: input.email,
      password: input.password,
      options: { data: { full_name: input.name, requested_role: input.requestedRole, event_id: input.eventId } },
    })
  const signInWithGoogle = () =>
    $supabase.auth.signInWithOAuth({ provider: 'google', options: { redirectTo: `${location.origin}/app` } })
  const sendPasswordReset = (email: string) =>
    $supabase.auth.resetPasswordForEmail(email, { redirectTo: `${location.origin}/redefinir-senha` })
  const signOut = () => $supabase.auth.signOut()
  return { signInWithPassword, signUp, signInWithGoogle, sendPasswordReset, signOut }
}
```

- [ ] **Step 3: Build the four auth pages**

Implement each page with labels connected by `for`/`id`, inline validation, loading state, and `role="alert"` for errors. `cadastro.vue` must submit `SignUpInput`, default the role selector to `student`, and show “Verifique seu e-mail” on success. `login.vue` must call both login methods and link to password recovery.

Use this complete submit contract in `login.vue`:

```ts
const email = ref('')
const password = ref('')
const errorMessage = ref('')
const pending = ref(false)
const { signInWithPassword, signInWithGoogle } = useAuth()

async function submitPassword() {
  pending.value = true
  errorMessage.value = ''
  const { error } = await signInWithPassword(email.value, password.value)
  pending.value = false
  if (error) return void (errorMessage.value = 'E-mail ou senha inválidos.')
  await navigateTo('/app')
}
```

- [ ] **Step 4: Add authenticated-route middleware**

Create `app/middleware/auth.ts`:

```ts
export default defineNuxtRouteMiddleware(async () => {
  if (import.meta.server) return
  const { $supabase } = useNuxtApp()
  const { data } = await $supabase.auth.getUser()
  if (!data.user) return navigateTo('/login')
})
```

Mark authenticated pages with `definePageMeta({ middleware: 'auth', layout: 'dashboard' })`.

- [ ] **Step 5: Verify auth UI and commit**

Run:

```bash
npx vitest run tests/integration/auth.nuxt.test.ts tests/unit/access.test.ts
npm run build
git add app tests/integration/auth.nuxt.test.ts
git commit -m "feat: add Google and password authentication"
```

Expected: tests PASS, build exits `0`, commit succeeds.

### Task 4: Role Requests and Event Assignment

**Files:**
- Create: `supabase/migrations/202607230002_role_workflow.sql`
- Create: `app/composables/useCurrentAccess.ts`
- Create: `app/pages/app/admin/solicitacoes.vue`
- Create: `app/pages/app/evento/[eventId]/solicitacoes.vue`
- Create: `tests/integration/role-workflow.sql`

**Interfaces:**
- Consumes: `role_requests`, `events`, `event_roles`, `is_global_admin()`, `is_event_professor(uuid)`.
- Produces: RPCs `request_role(event_role,uuid)`, `decide_role_request(uuid,request_status)`, and access state `{ profile, eventRoles }`.

- [ ] **Step 1: Write failing SQL workflow tests**

Create `tests/integration/role-workflow.sql`:

```sql
begin;
select plan(3);
select has_function('public', 'request_role', array['event_role', 'uuid'], 'role request RPC exists');
select has_function('public', 'decide_role_request', array['uuid', 'request_status'], 'decision RPC exists');
select col_is_pk('public', 'event_roles', array['event_id', 'user_id', 'role'], 'event role key is stable');
select * from finish();
rollback;
```

Run: `npx supabase test db tests/integration/role-workflow.sql`

Expected: FAIL because both RPCs are absent.

- [ ] **Step 2: Implement transactional role RPCs**

Create `supabase/migrations/202607230002_role_workflow.sql` with RPCs that:

```sql
create function public.request_role(target_role public.event_role, target_event uuid default null)
returns public.role_requests
language plpgsql security invoker set search_path = ''
as $$
declare created public.role_requests;
begin
  if target_event is null then raise exception 'event_required'; end if;
  insert into public.role_requests(user_id, event_id, requested_role)
  values (auth.uid(), target_event, target_role) returning * into created;
  return created;
end;
$$;

create function public.decide_role_request(request_id uuid, decision public.request_status)
returns public.role_requests
language plpgsql security definer set search_path = ''
as $$
declare target public.role_requests;
begin
  if decision not in ('approved', 'rejected') then raise exception 'invalid_decision'; end if;
  select * into target from public.role_requests where id = request_id and status = 'pending' for update;
  if not found then raise exception 'request_not_pending'; end if;
  if target.requested_role = 'professor' and not public.is_global_admin() then raise exception 'forbidden'; end if;
  if target.requested_role <> 'professor' and not public.is_event_professor(target.event_id) then raise exception 'forbidden'; end if;
  update public.role_requests set status = decision, decided_by = auth.uid(), decided_at = now()
  where id = request_id returning * into target;
  if decision = 'approved' then
    insert into public.event_roles(event_id, user_id, role, approved_by)
    values (target.event_id, target.user_id, target.requested_role, auth.uid())
    on conflict do nothing;
    if target.requested_role = 'professor' then
      update public.events set professor_id = target.user_id where id = target.event_id;
    end if;
  end if;
  insert into public.audit_log(event_id, actor_id, action, entity_type, entity_id)
  values (target.event_id, auth.uid(), 'role_request_' || decision::text, 'role_request', target.id::text);
  return target;
end;
$$;
```

Grant execute only to `authenticated`, then reset and rerun pgTAP.

- [ ] **Step 3: Build approval screens**

Create global and event request pages that query pending requests allowed by RLS, render name/e-mail/requested role, and call:

```ts
async function decide(id: string, decision: 'approved' | 'rejected') {
  const { error } = await $supabase.rpc('decide_role_request', {
    request_id: id,
    decision,
  })
  if (error) throw createError({ statusCode: 400, statusMessage: 'Não foi possível registrar a decisão.' })
  await refreshNuxtData('role-requests')
}
```

Buttons must be disabled while the request is being processed.

- [ ] **Step 4: Verify and commit**

Run:

```bash
npx supabase db reset
npx supabase test db tests/integration/role-workflow.sql
npx vitest run
git add supabase app tests/integration/role-workflow.sql
git commit -m "feat: add role approval workflow"
```

Expected: database and Nuxt tests PASS; commit succeeds.

### Task 5: Safe Event Creation and Archiving

**Files:**
- Create: `supabase/migrations/2026072300021_event_lifecycle.sql`
- Create: `server/utils/supabase-admin.ts`
- Create: `server/api/admin/archive-event.post.ts`
- Create: `app/pages/app/admin/eventos.vue`
- Create: `tests/unit/archive-event.test.ts`
- Modify: `.env.example`

**Interfaces:**
- Consumes: `events`, authenticated bearer token, `SUPABASE_SECRET_KEY`, `EVENT_ARCHIVE_SECRET`.
- Produces: RPC `archive_and_create_event(uuid,text,uuid)` and `POST /api/admin/archive-event` with `{ eventId, eventName, archiveSecret }` and response `{ archivedEventId, newEventId }`.

- [ ] **Step 1: Write failing endpoint tests**

Create `tests/unit/archive-event.test.ts` with mocked admin client cases for wrong secret, non-admin caller, mismatched event name, and success. Assert HTTP `403`, `403`, `400`, and `200` respectively.

Run: `npx vitest run tests/unit/archive-event.test.ts`

Expected: FAIL because the endpoint is absent.

- [ ] **Step 2: Implement the server-only archive endpoint**

Validate the body with:

```ts
const ArchiveBody = z.object({
  eventId: z.string().uuid(),
  eventName: z.string().min(1),
  archiveSecret: z.string().min(12),
})
```

Create `supabase/migrations/2026072300021_event_lifecycle.sql`:

```sql
create function public.archive_and_create_event(target_event uuid, confirmed_name text, actor uuid)
returns table(archived_event_id uuid, new_event_id uuid)
language plpgsql security definer set search_path = ''
as $$
declare current_event public.events;
declare created_id uuid;
begin
  if not exists(select 1 from public.profiles where id = actor and global_role = 'global_admin') then
    raise exception 'forbidden';
  end if;
  select * into current_event from public.events where id = target_event for update;
  if not found then raise exception 'event_not_found'; end if;
  if current_event.name <> confirmed_name then raise exception 'event_name_mismatch'; end if;
  if current_event.status = 'archived' then raise exception 'event_already_archived'; end if;

  update public.events set status = 'archived', archived_at = now(), is_featured = false where id = target_event;
  insert into public.events(name, slug, status, is_featured, created_by)
  values (
    current_event.name || ' — novo',
    current_event.slug || '-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISS'),
    'draft',
    true,
    actor
  ) returning id into created_id;
  insert into public.audit_log(event_id, actor_id, action, entity_type, entity_id, payload)
  values (target_event, actor, 'event_archived', 'event', target_event::text, jsonb_build_object('new_event_id', created_id));
  return query select target_event, created_id;
end;
$$;

revoke all on function public.archive_and_create_event(uuid,text,uuid) from public, anon, authenticated;
grant execute on function public.archive_and_create_event(uuid,text,uuid) to service_role;
```

The handler must use `timingSafeEqual` on SHA-256 digests, verify the bearer user with `auth.getUser(token)`, verify `profiles.global_role = 'global_admin'`, and call this RPC with the verified actor. On any failure, the RPC transaction leaves the event unchanged.

- [ ] **Step 3: Build the global event page**

Render active/archived events, a create form, and a danger-zone dialog requiring the current event name plus the archive secret. Template/configuration copying is added after those schemas exist in Plan 04. Submit:

```ts
await $fetch('/api/admin/archive-event', {
  method: 'POST',
  headers: { Authorization: `Bearer ${session.access_token}` },
  body: { eventId, eventName, archiveSecret },
})
```

Clear the secret field after every attempt and never persist it in browser storage.

- [ ] **Step 4: Document environment variables**

Add to `.env.example`:

```dotenv
NUXT_PUBLIC_SUPABASE_URL=
NUXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=
NUXT_SUPABASE_SECRET_KEY=
NUXT_EVENT_ARCHIVE_SECRET=
```

- [ ] **Step 5: Run plan-level verification and commit**

Run:

```bash
npx supabase db reset
npx supabase db lint
npx supabase test db
npx vitest run
npm run build
git add server app/pages/app/admin/eventos.vue tests/unit/archive-event.test.ts .env.example
git commit -m "feat: add safe event lifecycle administration"
```

Expected: all checks PASS and the first subsystem is deployable.
