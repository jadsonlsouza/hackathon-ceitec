# P2 Task 3 Report

## TDD evidence

- RED (unit): `npx vitest run tests/unit/submission.test.ts` failed on
  2026-07-23 because `shared/domain/submission.ts` did not exist.
- RED (database): `npx supabase test db tests/integration/canvas.sql` failed
  on 2026-07-23 with the eight Canvas tables and five RPCs absent; pgTAP
  reached the expected missing-schema failure before fixture setup.

## Migration ordering adaptation

The plan's illustrative filename `202607230004_canvas.sql` would sort before
the existing timestamped team migration. The implementation therefore uses a
CLI-generated timestamp lexicographically after
`20260723182122_teams.sql`, so local reset applies the dependency chain in the
correct order.

## Verification

- `npx supabase db reset`: PASS; all five migrations applied in order,
  including `20260723192206_canvas.sql`.
- `npx supabase test db tests/integration/canvas.sql`: PASS, 58 assertions.
- `npx supabase test db tests/integration`: PASS, 237 assertions across five
  pgTAP files.
- `npx vitest run tests/unit/submission.test.ts`: PASS, 6 tests.
- `npx vitest run`: PASS, 68 tests across 16 files.
- `npx supabase db lint --local --schema public --level warning
  --fail-on error`: PASS, no schema errors.
- `npx supabase db advisors --local --type all --level warn
  --fail-on error`: PASS, no security or performance issues.
- `npm run build`: PASS.
- `git diff --check`: PASS.

## Implementation notes

- Activity rows optionally reference a same-event template; an insert trigger
  snapshots the template blocks into immutable activity-owned rows.
- Submission creation exposes only the three routing columns. Status, revision,
  claim, reviewer, version, and audit fields are writable only through the
  authenticated workflow RPCs.
- Review claims lock the submission row, expire after 15 minutes, and can be
  replaced only after expiry.
- Approval and return feedback remain nullable. Reopen normalizes and requires
  a nonblank reason.
- Event membership, review roles, Professor authority, category, archive,
  publication, opening, and deadline checks are resolved against the
  submission's event.
