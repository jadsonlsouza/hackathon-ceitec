# Task 5: Integration, copy audit, and release verification

## Delivered

- Request-review pages now share the task-oriented heading **"Revisar
  solicitações"** and explain that requests arrive through notifications.
- Dashboard navigation remains task-only: the accessibility regression asserts
  that a Professor view contains no primary request-review link and cannot open
  global people management.
- The E2E fixture gives the global admin a Professor assignment for Event A and
  seeds a pending Monitor role request. The release test switches to that view,
  opens the notification bell, follows the automatic request action, and checks
  the review heading.
- README documents active views, notification audiences and recovery, request
  destinations, duplication exclusions, and event-copy recovery.

## TDD evidence

The new Playwright assertion was added before changing fixture/page copy.
The requested RED command was attempted:

```text
npx playwright test tests/e2e/accessibility.spec.ts tests/e2e/release.spec.ts
```

It could not reach assertion execution because `tests/e2e/support/global-setup.ts`
attempts `docker exec -i supabase_db_hackathon-ceitec ...`, while the local
Supabase CLI created `supabase_db_vmbqqbjtmidjfrebppsz`. The elevated retry
completed `supabase db reset` and then failed at global setup line 56 with:

```text
Error response from daemon: No such container: supabase_db_hackathon-ceitec
Error: spawnSync docker EPIPE
```

Direct fixture validation also revealed an existing Canvas setup failure after
the newly added role-request rows: the original primary Canvas activity insert
raises `primary_activity_category_conflict` from
`private.sync_canvas_primary_categories()`. It is unrelated to the Task 5
request fixture, so no unrelated Canvas migration or fixture behavior was
changed.

## Release verification

| Command | Result | Evidence |
| --- | --- | --- |
| `npx supabase db reset` | Pass | Exit 0; all migrations and `supabase/seed.sql` applied. |
| `npx supabase test db tests/integration` | Existing failures | Exit 1. Canvas/evaluations stop on `primary_activity_category_conflict`; event lifecycle expects missing `public.archive_and_create_event(uuid,text,uuid)`; presentation order hits duplicate slot key; results has 9 expectation failures; role workflow has 4 expectation failures; teams has 1 expectation failure. Task 5 did not modify these areas. |
| `npx vitest run` | Existing failures | Exit 1: 12 failed files, 28 passed; 19 failed tests, 182 passed, 24 skipped. Failures include `dashboard-access-realtime` (`options.default is not a function`), evaluation/results page fixture expectations, and Nuxt integration suites unable to allocate a localhost port. |
| `npm run build` | Pass | Exit 0; Nuxt client/server/Nitro build completed. |
| `npx playwright test` | Harness blocked | Exit 1 before collection: stale hard-coded `supabase_db_hackathon-ceitec` name in global setup, while the local CLI uses the project-ref container name above. |
| `git diff --check` | Pass | Exit 0; no whitespace errors. |

## Scope

Only Task 5 product, E2E fixture/test, documentation, and this report are
included. The pre-existing untracked plan at
`docs/superpowers/plans/2026-09-20-role-views-notifications-events.md` was
left untouched and is not part of the commit.
