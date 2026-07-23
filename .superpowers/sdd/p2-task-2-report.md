# P2 Task 2 — Team Student and Professor Screens

## Delivered

- Added the student route `/app/evento/[eventId]/equipe` with a dark, accessible team form, Zod validation, six reserved member rows, local duplicate e-mail/matrícula feedback, sanitised database error messages, and processing guards.
- Added `MemberList` to show invitation/member states and expose join decisions only in the leader view. Decisions use the existing typed `decide_team_join` RPC.
- Added the Professor route `/app/evento/[eventId]/equipes`, guarded by the assigned event Professor role. It displays pending teams in creation order with category, member count and expandable details; reject requires confirmation and both actions use the typed `decide_team` RPC.
- Both pages use distinct event-scoped async-data keys, revalidate after mutation, and never use client-side authorization as a replacement for database/RPC authorization.

## TDD evidence

- RED: `npx vitest run tests/integration/team-pages.nuxt.test.ts` initially failed with both team routes missing (404) and absent source files.
- GREEN: added route and mounted interaction tests covering inline validation, RPC payloads, rapid-click protection, duplicate/error messages, leader actions, Professor guard, rejection confirmation, and successful/failed decisions.

## Verification

- Focused: `npx vitest run tests/unit/team.test.ts tests/component/team-pages-ui.test.ts tests/integration/team-pages.nuxt.test.ts` — 11 passed.
- Full: `npx vitest run` — 14 files / 50 tests passed.
- Build: `npm run build` — passed.
- `git diff --check` — passed.

No database migration changed in this task, so no database regression command was required; the existing typed RPC contracts from Task 1 are consumed unchanged.
