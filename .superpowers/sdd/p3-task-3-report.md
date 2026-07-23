# P3 Task 3 Report — Rankings, tie resolution, and publication

## Delivered

- Added timestamped migration `20260723220807_results.sql`.
- Added invoker-safe administrative views:
  - `evaluation_progress`, including frozen required/completed evaluator counts
    and missing evaluator identities;
  - `administrative_ranking`, using PostgreSQL `numeric`, frozen criterion
    weights and two-decimal displayed scores.
- Added RLS-protected, least-privilege result tables:
  - immutable and audited `tie_decisions`;
  - immutable public-only `published_results` snapshots.
- Added guarded RPCs:
  - `resolve_tie`, with current Professor-role checks, exact tied-team order,
    mandatory justification, event/advisory locks, idempotency, audit and a
    ranking fingerprint;
  - `publish_category_results`, with completeness, current fingerprint,
    unresolved-tie, category isolation and two-category lifecycle guards;
  - `get_published_results`, exposing only published snapshot fields by exact
    event slug.
- Locked evaluations and scores after a tie decision. Publication still checks
  the stored fingerprint defensively, so out-of-band changes cannot silently
  apply a stale decision.
- Added the Professor results screen, accessible manual ordering controls,
  anti-double-action guards, missing evaluator/blocker feedback, and sanitized
  errors.
- Added the public event-slug results screen with separate Júnior/Sênior
  sections, publication timestamps and empty/error states.

## TDD evidence

- Initial pgTAP contract: 7/7 failed because views, tables and RPCs were absent.
- Initial UI tests failed because the component and routes were absent.
- A stale-decision test reproduced publication after a changed tie; fingerprint
  validation fixed it.
- A score-lock test reproduced post-decision score mutation; the database
  trigger fixed it.
- Focused final results pgTAP: 40/40 passed.
- Focused final results UI/Nuxt: 10/10 passed.
- Result error mapping: 2/2 passed.

## Final verification

- `npx supabase db reset`: passed; all migrations applied in order.
- `npx supabase test db tests/integration`: 405/405 passed across 9 files.
- `npx vitest run`: exit 0; 145 tests collected across 27 files.
- `npm run build`: passed with Nuxt 4.5.0.
- `npx supabase db lint --local --level warning --fail-on error`: no schema
  errors.
- `npx supabase db advisors --local --fail-on error`: no issues found.
- `npx supabase db diff --from migrations --to local --schema public,private`:
  no schema drift.
- `git diff --check`: passed.

## Browser E2E prerequisite

The repository does not yet have a deterministic multi-profile Supabase Auth
harness that can isolate Professor, evaluator and anonymous browser sessions.
`tests/e2e/evaluation-results.spec.ts` records the intended journey and is
explicitly skipped for that reason. The journey is covered deterministically
at the database and mounted-page layers; the Playwright run reports `1 skipped`
instead of claiming an unrepeatable browser result.
