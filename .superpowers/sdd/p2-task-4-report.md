# P2 Task 4 Report

## Status

DONE

## TDD evidence

- RED (autosave): `npx vitest run tests/unit/autosave.test.ts` failed because
  `useAutosave` did not exist. Later RED cycles reproduced a stale in-flight
  save incorrectly marking a newer debounced edit as saved.
- RED (mounted Canvas core): the component suite failed because
  `useEventRealtime`, `CanvasBlockEditor`, `AutosaveState`, and
  `SubmissionReview` did not exist. Follow-up RED covered access that hydrates
  after mount and initially has no permitted Realtime targets.
- RED (mounted pages): the page suite failed while the student detail,
  activity list, Professor builder, and review queue were absent. Follow-up RED
  covered immediate submit gating during debounce and the student's review
  status not changing to `Aprovado` from a scoped Realtime event.
- RED (database): `npx supabase test db
  tests/integration/canvas-realtime.sql` failed 2/2 assertions because the
  `supabase_realtime` publication contained neither `submissions` nor
  `submission_answers`.

## Implemented

- Per-block 700 ms autosave with optimistic versions, debounce, retry,
  `idle|saving|saved|error|conflict`, stale-request protection, serialized
  writes, and disposal cleanup.
- Event-scoped Realtime subscriptions with no duplicate active channel,
  late-access hydration, route/target restart, and disposal cleanup.
- Student activity groups, collaborative ordered editor, safe remote-update
  handling, conflict recovery, submission gating, duplicate-action guards, and
  immediate Portuguese review status updates.
- Professor Canvas builder with categories, dates, primary/publication/
  re-submission options, local block creation/reordering/removal, validation,
  and visible structural-lock state after the first submission.
- Professor/Monitor queue with category/status filters, atomic claim,
  immutable submitted snapshot rendering, guarded approve/return decisions,
  and optional feedback (including approval with `null` feedback).
- Sanitized deterministic Portuguese UI errors; no `v-html` or raw backend
  error rendering.
- Realtime publication migration generated through the Supabase CLI and pgTAP
  coverage for the two collaborative tables.

## Verification

- `npx supabase db reset`: PASS; six migrations applied in order.
- `npx vitest run`: PASS, 87 tests across 20 files.
- `npx supabase test db tests/integration`: PASS, 253 pgTAP assertions across
  six files.
- `npx supabase db lint --local --schema public --level warning
  --fail-on error`: PASS, no schema errors.
- `npx supabase db advisors --local --type all --level warn
  --fail-on error`: PASS, no issues.
- `npm run build`: PASS.
- `git diff --check`: PASS.

## Browser journey

The repository has the Playwright package but no Playwright configuration,
browser web-server fixture, or deterministic multi-role authenticated session
fixture. A runnable end-to-end journey therefore was not fabricated. The
journey is deferred until a seeded local browser harness can provision a
leader, invited member, Professor, and Monitor and inject their Supabase
sessions. The mounted suites cover autosave, disposal, conflict, debounce and
submit gating, Realtime preservation/cleanup/status refresh, atomic claim,
immutable revision rendering, duplicate guards, and optional feedback.

## Remaining concerns

- Full Playwright coverage remains dependent on the deterministic authenticated
  browser harness described above.

## Task-review fixes

### RED

- Mounted review tests with the real persisted snapshot shape
  `{ problema: { text: '...' } }` rendered no answers because the component
  expected a synthetic `answers[]` property.
- The two-block mounted conflict test showed no `block_id`-scoped answer query;
  the old recovery path fetched every answer and could replace another block's
  pending local edit.
- The mounted student page showed a returned status without its persisted
  feedback and did not refresh the latest review after the approval status
  event.

### GREEN

- The queue now fetches activity blocks with key, title, prompt, and position,
  sorts them, and maps each immutable snapshot property by `block.key`.
- Conflict recovery fetches and merges only the requested block, remounts only
  that editor with the remote content/version, and preserves other editor
  instances and their pending submit gate.
- The student page loads the authorized review history, shows the latest
  feedback or the explicit `Aprovado sem feedback adicional.` state, and
  refreshes only submission/review data after status Realtime events.
- The existing `submission_reviews` RLS already delegates through the
  submission's team/reviewer visibility. A new pgTAP assertion confirms an
  active team member can read the review; no access migration was necessary.

### Review-fix verification

- Focused Vitest: PASS, 19 tests.
- Canvas pgTAP: PASS, 70 assertions.
- Full Vitest: PASS, 87 tests across 20 files.
- Full pgTAP: PASS, 253 assertions across six files.
- Build, database lint, advisors, and `git diff --check`: PASS.
