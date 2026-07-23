# Task 5 Report: Safe Event Creation and Archiving

## Status

Implemented and verified.

## Delivered

- Added the CLI-generated `20260723172343_event_lifecycle.sql` migration.
- Added a server-only `archive_and_create_event(uuid,text,uuid)` invoker RPC.
- Kept the privileged implementation in `private` with `search_path = ''`,
  explicit `global_admin` authorization, exact-name validation, a row lock, and
  atomic archive/replacement/audit writes.
- Added a private invoker/trigger bridge so `service_role` cannot execute the
  privileged implementation directly.
- Added immutable archived-event and no-delete trigger enforcement.
- Added the Nuxt server admin client and `POST /api/admin/archive-event`.
- Added an accessible Portuguese event administration page with create,
  active/archive history, and destructive confirmation flows.
- Rejected blank and whitespace-only event names in both the browser and
  database, with an announced field error and focus recovery in the UI.
- Prevented Cancel, Escape, and backdrop dismissal while an archive request is
  in flight.
- Restricted replacement archiving to the current featured event at both UI
  and transaction boundaries.
- Added all four required environment variables to `.env.example`.
- Deliberately omitted template/configuration copying until Plan 04.

## TDD evidence

### RED

```text
npx vitest run tests/unit/archive-event.test.ts
FAIL: Cannot find module '../../server/api/admin/archive-event.post'

npx supabase test db tests/integration/event-lifecycle.sql --local
Failed: archive RPC and private implementation do not exist

# Least-privilege follow-up
Failed test: service_role must use the public wrapper instead of the private implementation

# Real service-role authorization follow-up
permission denied for table profiles
Failed: required id/global_role column privileges
```

### GREEN

```text
npx vitest run tests/unit/archive-event.test.ts
Test Files  1 passed
Tests       10 passed

npx supabase test db tests/integration/event-lifecycle.sql --local
Files=1, Tests=34
Result: PASS
```

## Security boundary

- The endpoint validates the Zod body, extracts one bearer token, and verifies
  it through `auth.getUser(token)`.
- The verified JWT must prove authentication no older than ten minutes.
  Custom signed `auth_time` is supported; standard Supabase tokens derive the
  time from non-refresh/non-anonymous `amr[].timestamp` entries.
- A recent `token_refresh` AMR entry cannot renew the authentication window.
- Authentication timestamps more than 60 seconds in the future are rejected;
  the bounded allowance handles ordinary clock skew.
- Authorization is read from `profiles.global_role`, never user metadata.
- `service_role` receives only column-level SELECT on `profiles.id` and
  `profiles.global_role`; profile e-mail remains inaccessible.
- The archive secret is compared only as constant-time SHA-256 digests and is
  never logged or persisted.
- Only the public wrapper is executable by `service_role`; `anon` and
  `authenticated` cannot execute it, and no application role can execute the
  private definer implementation directly.
- The transaction locks the target event, rechecks the actor and exact name,
  requires it to be the current featured event, archives it, creates one new
  featured draft, and writes the audit row atomically.
- A forced audit failure after both event mutations proves that the archive and
  replacement insert roll back together.
- Archived events are immutable, and all event deletion is rejected.
- The browser clears the archive secret in `finally` after every archive
  request and when cancelling before a request, never writes it to browser
  storage, and cannot dismiss the modal while the request is in flight.
- Archive errors are announced inside the still-open native modal.

## Verification

- `npx supabase db reset` — all three migrations and seed applied.
- `npx supabase test db tests/integration/*.sql --local` — all pgTAP tests pass.
- `npx supabase db lint --local --schema public,private --fail-on warning` —
  no schema errors.
- `npx supabase db advisors --local --type all --level warn --fail-on warn` —
  no issues.
- `npx vitest run` — full Vitest suite passes.
- `npm run build` — production client/server build completes.
- `git diff --check` — clean.

## Review follow-up

Independent security review caught that the baseline had revoked all
`service_role` access to `profiles`, which would have made every valid endpoint
request fail during its admin lookup. The migration now grants only the two
columns required by that lookup, and pgTAP executes the exact lookup under
`SET ROLE service_role` while proving profile e-mail remains denied.

Self-review also removed direct `service_role` execution of the private
implementation by adopting the existing non-exposed trigger-bridge pattern.
Reviewer follow-up then restricted archiving to the featured/current event and
moved failure feedback inside the modal so it is visible to assistive
technology while the document background is inert.

The final token review replaced the fabricated unit JWT with the documented
Supabase JWT shape. Supabase does not issue a standard top-level `auth_time`
claim, so standard tokens now derive the original authentication time from
AMR while explicitly ignoring refresh, anonymous, and e-mail-change entries.

## P1 review follow-up

### RED

```text
npx supabase test db tests/integration/event-lifecycle.sql
Failed test 12: event names have a database check constraint
Failed test 16: the database rejects whitespace-only event names

npx vitest run tests/component/event-admin-ui.test.ts --config vitest.config.ts
Test Files  1 failed (1)
Tests       2 failed | 1 passed (3)
Failure: whitespace-only name called events.insert
Failure: Cancel remained enabled while the archive request was pending
```

The authenticated `global_admin` direct-archive regression was added in the
same RED cycle and already passed because the existing RLS boundary rejected
the write with SQLSTATE `42501`.

### GREEN

```text
npx supabase db reset --local
Applied migration 20260723172343_event_lifecycle.sql
Finished supabase db reset

npx supabase test db tests/integration/event-lifecycle.sql
Files=1, Tests=37
Result: PASS

npx supabase test db tests/integration/*.sql
Files=3, Tests=112
Result: PASS

npx supabase db lint --local --schema public,private --fail-on warning
No schema errors found

npx supabase db advisors --local --type all --level warn --fail-on warn
No issues found

npx vitest run tests/unit/archive-event.test.ts tests/component/event-admin-ui.test.ts --config vitest.config.ts
Test Files  2 passed (2)
Tests       12 passed (12)

npx vitest run --config vitest.config.ts
Test Files  11 passed (11)
Tests       36 passed (36)

npm run build
Nuxt 4.5.0 production client and Nitro server build complete

git diff --check
Clean
```

The component gate mounts the real administration page with Vue Test Utils in
`happy-dom`; it verifies whitespace validation and focus, accessible errors,
all in-flight user dismissal paths, and secret clearing on both success and
failure. Source-text scanning was removed from the endpoint unit suite.

## Final focused P1 follow-up

### RED

```text
npx supabase test db tests/integration/event-lifecycle.sql
Failed test 17: the database rejects tab-only event names
Failed test 18: the database rejects newline-only event names

npx vitest run tests/component/event-admin-ui.test.ts --config vitest.config.ts
Test Files  1 failed (1)
Tests       1 failed | 5 passed (6)
Failure: the archive secret remained populated while refreshNuxtData was pending
```

The pre-request Cancel, Escape, and backdrop cases passed in the RED cycle,
confirming and preserving the existing cleanup behavior through mounted
interactions.

### GREEN

```text
npx supabase db reset --local
Applied migration 20260723172343_event_lifecycle.sql
Finished supabase db reset

npx supabase test db tests/integration/event-lifecycle.sql
Files=1, Tests=39
Result: PASS

npx vitest run tests/component/event-admin-ui.test.ts --config vitest.config.ts
Test Files  1 passed (1)
Tests       6 passed (6)

npx supabase test db tests/integration/*.sql
Files=3, Tests=114
Result: PASS

npx supabase db lint --local --schema public,private --fail-on warning
No schema errors found

npx supabase db advisors --local --type all --level warn --fail-on warn
No issues found

npx vitest run --config vitest.config.ts
Test Files  11 passed (11)
Tests       39 passed (39)

npm run build
Nuxt 4.5.0 production client and Nitro server build complete
```

The database constraint now rejects names matching only PostgreSQL's POSIX
`[[:space:]]` class, including tabs and newlines, while ordinary event names
continue through the lifecycle tests. On successful archival, the browser
clears the secret immediately after the request settles and before refreshing
event data; `finally` remains as defense-in-depth for every error path.
