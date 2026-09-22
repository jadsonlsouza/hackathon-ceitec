# Task 4 — event wizard and configuration-only duplication

## Delivered

- Added the three-step global-admin event wizard: basic event details, optional
  source/configuration and responsible professor, then review.
- Added `create_event_draft(jsonb)` and
  `duplicate_event_configuration(uuid, jsonb, jsonb)` as `SECURITY INVOKER`
  RPCs. They require `auth.uid()` and `is_global_admin()`, validate exact JSON
  shapes, create only a draft, lock the source event, and return the new ID.
- Duplication is opt-in for public content/schedule, evaluation criteria and
  weights, Canvas templates/blocks/activities, workshops, and general dates.
  Canvas references use a source-ID to destination-ID map.
- The clone always gets only the selected responsible professor role and
  remains unpublished/draft. The SQL neither reads nor inserts users, teams,
  members/invitations, submissions/reviews, evaluations, rankings/results,
  audit records, attendance, or notifications.
- Added pgTAP coverage for authorization, validation, selected-copy behavior,
  excluded operational data, unpublished state, source preservation, and a
  forced late failure proving transaction rollback. Added wizard component and
  authorization E2E coverage.

## Verification evidence

- `npx vitest run tests/component/event-admin-ui.test.ts` — passed: 1 file,
  9 tests.
- `npx nuxt build` — passed (client and Nitro production build completed).
- `git diff --check` — passed (no whitespace errors).
- `npx supabase test db tests/integration/event-duplication.sql` — not run to
  completion: the local database at `127.0.0.1:54322` is unavailable. Docker
  reports that the Colima socket is absent, so the required local Supabase
  stack cannot start from this workspace.
- `npx playwright test tests/e2e/authorization.spec.ts --list` did not
  complete within the 30-second command window; it was not counted as a pass.
- `npx nuxi typecheck` is unavailable in this repository because there is no
  root `tsconfig.json`; the production Nuxt build remains the available
  compile verification.

## Notes

The migration file already existed as the CLI-generated
`20260921202947_event_wizard_duplication.sql` in the supplied Task 4 working
tree. I retained that generated migration rather than creating a duplicate.

## Review-fix pass (round 1)

- Added CLI-generated migration `20260921221944_event_wizard_duplication_review_fixes.sql`.
  It replaces the permissive global-admin Canvas write policies with policies
  that require a non-archived parent event; read access remains sufficient to
  copy archived source configuration. Direct archived Canvas inserts and
  updates are now denied.
- Added a narrow private `SECURITY DEFINER` source-lock helper. It verifies
  `auth.uid()` is a global admin, locks an archived or active source for the
  duration of the atomic clone, and exposes no write capability. The public
  duplication RPC remains `SECURITY INVOKER` and uses that helper.
- Added a private global-admin-or-current-professor assertion used only by the
  public-content editor RPCs. This permits a global admin to configure a
  non-archived event assigned to another professor without assigning the
  creator an event role.
- After creation, the admin page persists the target event's Professor active
  view before navigation. The dashboard context now recognizes route event IDs
  for global admins, so the active-view middleware accepts that UI-only
  narrowing; database authorization remains independent of the selected view.

### Review-fix verification

- RED: before the migration, `event-duplication.sql` confirmed the global
  admin could insert a Canvas template on an archived event. The component
  regressions also failed because no Professor view was persisted and the
  destination editor rendered its permission error.
- GREEN: `npx vitest run tests/component/dashboard-ui.test.ts
  tests/component/event-admin-ui.test.ts tests/component/public-content-editor.test.ts`
  — 32 passed.
- GREEN: `supabase test db tests/integration/event-duplication.sql
  tests/integration/public-content.sql` — 73 pgTAP checks passed. The first
  suite includes archived-source copying, archived Canvas insert/update denial,
  and global-admin configuration entry for an event whose responsible professor
  is different.
- GREEN: `supabase db advisors --local --type security` — no issues.
- GREEN: `supabase db reset --local` applied both Task 4 migrations and
  `supabase migration list --local` confirms `20260921221944` is present.
- GREEN: `npx nuxt build` completed.
- `npx playwright test tests/e2e/authorization.spec.ts` cannot currently run:
  its global setup hard-codes `supabase_db_hackathon-ceitec`, while this
  project's configured local container is `supabase_db_vmbqqbjtmidjfrebppsz`.
  The suite resets successfully, then exits before tests execute with
  `No such container: supabase_db_hackathon-ceitec`.
- The full `npx vitest run` suite remains red for pre-existing unrelated
  dashboard-access mock assumptions, evaluation/results component fixtures,
  and Nuxt integration port allocation. Task 4's affected component and
  pgTAP suites are listed above and pass.
