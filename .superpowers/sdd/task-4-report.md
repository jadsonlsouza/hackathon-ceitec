# Task 4 Report: Role Requests and Event Assignment

## Status

Implemented and verified.

Commit: `a0e7eb0 feat: add role approval workflow`

## Delivered

- Added the CLI-generated `20260723163524_role_workflow.sql` migration.
- Added `request_role(event_role, uuid)` and
  `decide_role_request(uuid, request_status)` as `SECURITY INVOKER` public
  wrappers.
- Kept privileged implementations in the non-exposed `private` schema with
  `search_path = ''`, explicit `auth.uid()` authorization, row locks on
  requests/events, archived-event rejection, and least-privilege grants.
- Made approval/rejection atomic with event-role assignment, professor
  assignment, and event-bound audit writes.
- Extended profile RLS only enough for event professors to read pending
  Monitor/Avaliador applicant names and e-mails.
- Added `useCurrentAccess` with `{ profile, eventRoles }` state.
- Added global Professor and per-event Monitor/Avaliador approval screens,
  including per-request disabled state while decisions are processing.
- Regenerated `app/types/database.ts`.

## Tests

RED was observed before implementation:

- pgTAP: missing `request_role` and `decide_role_request`.
- Vitest: missing access composable.
- Nuxt integration: both approval routes returned 404.

Final verification:

- `npx supabase db reset` — pass.
- `npx supabase test db tests/integration/identity-events.sql tests/integration/role-workflow.sql`
  — 69/69 pgTAP assertions pass.
- `npx supabase db lint --local --schema public --level warning --fail-on warning`
  — no schema errors.
- `npx supabase db advisors --local --type all --level warn --fail-on warn`
  — no security or performance issues.
- `npx vitest run` — 8 files, 14 tests pass.
- `npm run build` — production build passes.
- `git diff --check` — clean.

## Self-review

- Public RPCs are invoker functions and executable only by `authenticated`.
- Private definer functions are not in an exposed PostgREST schema and cannot
  be executed by `public`, `anon`, or `service_role`.
- Pending request and event rows are locked and revalidated before mutation.
- Archived events cannot accept requests or decisions.
- Decision writes, role assignment, professor assignment, and audit insertion
  share one database transaction.
- Audit rows always retain the affected `event_id`.
- Approval pages rely on RLS and filter only the role class they manage.

## Notes

The migration filename differs from the old plan placeholder because it was
created through `npx supabase migration new role_workflow`, as required.

## Reviewer Follow-up

The Task 4 review findings were resolved in a follow-up change:

- Revoked `authenticated` direct execution of both private definer
  implementations while preserving the authenticated public
  `SECURITY INVOKER` RPCs through a non-exposed trigger bridge.
- Scoped `role_requests` SELECT RLS to owners, global administrators deciding
  Professor requests, and assigned Professors deciding Monitor/Avaliador
  requests for their own events.
- Explicitly rejected a `NULL` decision.
- Removed previous Professor `event_roles` atomically during a replacement and
  recorded the revoked assignment in the event audit.
- Added dedicated global and event-id async-data keys, frontend access guards,
  and explicit unauthorized states.
- Added inline Portuguese processing/error alerts and darkened the primary
  action to `#0369a1` (at least 4.5:1 against white).
- Prevented concurrent decisions at both page and shared-helper boundaries;
  while one decision is active, every action is disabled.

### TDD evidence

- The focused UI suite initially failed because the workflow helper, scoped
  keys, guards, alerts, and contrast fix were absent.
- A processing-state regression was then observed failing because its
  `v-else-if` removed the request list instead of leaving disabled buttons
  visible.
- The deferred rapid-two-click regression failed by timing out before the
  concurrency guard was implemented.
- Final focused result:
  `npx vitest run tests/unit/role-request-ui.test.ts tests/integration/role-pages.nuxt.test.ts`
  — 2 files, 12 tests pass.

### Final verification

- `npx supabase db reset` — pass; both migrations and seed applied.
- `npx supabase test db tests/integration/identity-events.sql tests/integration/role-workflow.sql`
  — 2 files, 75 pgTAP assertions pass.
- `npx supabase db lint --local --schema public --level warning --fail-on warning`
  — no schema errors.
- `npx supabase db advisors --local --type all --level warn --fail-on warn`
  — no security or performance issues.
- `npx vitest run` — 9 files, 24 tests pass.
- `npm run build` — production client/server build completes.
- `git diff --check` — clean.

### Follow-up self-review

- Direct `EXECUTE` remains revoked on all private definer functions; the public
  API remains invoker-only and granted only to `authenticated`.
- The bridge exposes only the input columns and returned result needed by the
  wrappers, and its private schema is not exposed through PostgREST.
- Event and request row locks serialize decisions; replacement deletion,
  assignment, event update, and audit writes share the RPC transaction.
- Owners retain request visibility without widening either decision-maker
  boundary.
- Unauthorized pages do not query role requests, and an in-flight decision
  cannot be overlapped or re-enabled by a second click.
- Independent re-review found no remaining Critical or Important issues and
  returned a READY verdict.
