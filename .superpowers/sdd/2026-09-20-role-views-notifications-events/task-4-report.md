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
