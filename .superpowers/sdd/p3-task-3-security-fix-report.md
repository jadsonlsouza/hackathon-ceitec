# P3 Task 3 Security Fix Report

## Corrections

- Removed all client `SELECT` grants from `evaluation_progress`,
  `administrative_ranking`, and `published_results`.
- Added event-scoped, current-Professor-only RPCs for progress, private ranking,
  and category publication state. Evaluator, Monitor, and Student calls fail
  deterministically with `forbidden`.
- Updated the admin results page to use the protected RPCs. It no longer queries
  either administrative view or the publication table.
- Kept anonymous publication access exclusively through
  `get_published_results(event_slug)`. A single published category stays hidden
  until the event reaches `results_published`; direct anonymous and authenticated
  table reads are denied.
- Extended evaluation guards so any insert, update, or delete in a published
  category fails with `category_results_published`, even while the other
  category remains in evaluation. The unpublished category remains editable.
- Explicitly verified frozen semantics: revoking an evaluator after their
  submitted evaluation does not erase the frozen completeness requirement or
  completed result.

## TDD evidence

- Initial focused run failed because the three Professor-only RPCs did not exist
  and the direct grants were still present.
- After the first migration run, the test correctly failed where old assertions
  still selected the now-private views; those assertions were migrated to RPCs.
- Final focused results pgTAP: 57/57 passed.
- Focused UI/unit/Nuxt: 21/21 passed.

## Final verification

- Clean `supabase db reset`: passed.
- Full pgTAP: 422/422 passed across 9 files.
- Full Vitest: exit 0; 146 tests collected.
- Nuxt production build: passed.
- Supabase DB lint: no schema errors.
- Supabase DB advisors: no issues.
- Migration-to-local DB diff: empty.
- `git diff --check`: passed.
- Playwright result journey: 1 skipped because the repository still lacks the
  deterministic multi-profile auth harness documented in the original report.

## Deferred optional test

A real two-session concurrency test was not added because the repository has no
deterministic multi-session database/auth test harness. Advisory/event locks,
idempotent repeat calls, and category isolation remain covered by pgTAP; this
report does not claim real concurrent-session coverage.
