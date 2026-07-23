# P2 Task 1 Report: Team Domain and Transactional Schema

## Status

**COMPLETE**

## Delivered

- Added `TeamCategory`, `TeamStatus`, `MemberStatus`, `canReserveSeat`, and
  `canSubmitForTeam` to `shared/domain/team.ts`.
- Created the CLI-generated `20260723182122_teams.sql` migration.
- Added event-bound `teams` and `team_members` tables, normalized member data,
  composite event/team integrity, decision consistency checks, foreign-key
  indexes, and partial unique reservation indexes.
- Added `create_team`, `request_team_join`, `decide_team_join`, and
  `decide_team` as public security-invoker RPC wrappers.
- Kept all privileged implementations in `private` as security-definer
  functions with `search_path = ''`, explicit caller authorization, and direct
  execution revoked from every application role.
- Added event/team/member row locking, archived-event write guards,
  database-enforced six-seat capacity, an active-leader membership invariant,
  scoped read-only RLS, and atomic event-bound audits.
- Regenerated `app/types/database.ts` with the team tables, enums, relations,
  and RPC signatures.

## TDD evidence

### RED

```text
npx vitest run tests/unit/team.test.ts
FAIL: Cannot find module '../../shared/domain/team'

npx supabase test db tests/integration/teams.sql
FAIL: teams table, team_members table, enums, and RPCs do not exist

# Schema-capacity self-review
npx supabase test db tests/integration/teams.sql
Failed test: the schema rejects a seventh reserved seat outside the RPC too
caught: no exception
wanted: P0001 team_size_out_of_range
```

### GREEN

```text
npx vitest run tests/unit/team.test.ts
Test Files  1 passed (1)
Tests       2 passed (2)

npx supabase test db tests/integration/teams.sql
Files=1, Tests=52
Result: PASS
```

## Transaction and security boundary

- Team tables are directly read-only for `authenticated`; `anon` has no table
  or RPC access, and no client role receives insert, update, or delete grants.
- Public RPCs are invoker-only wrappers over a non-exposed private dispatch
  bridge. Private implementations and trigger functions cannot be executed
  directly by `PUBLIC`, `anon`, `authenticated`, or `service_role`.
- Every implementation obtains `auth.uid()` itself. Matching-email join
  requests compare the normalized signed JWT e-mail with the normalized
  reservation; leader and Professor decisions reauthorize against locked
  database rows.
- Team creation locks the event before checking or inserting reservations.
  Member writes additionally lock the team before counting reserved
  `invited`, `join_requested`, and `active` seats, so concurrent writers cannot
  create a seventh seat.
- E-mail and enrollment are trimmed and lowercased before storage. Partial
  unique indexes reserve them transactionally per event, including pending
  invitations, and the event lock plus unique indexes prevent duplicate races.
- A composite `(team_id, event_id)` foreign key rejects cross-event member
  references. RPCs re-read and lock the event, team, and member in a consistent
  order before changing state.
- A deferred constraint trigger requires every leader to have a matching
  active member row. Team creation supplies that row atomically, and later
  removal or demotion is rejected.
- Both team tables have scoped SELECT policies for active/reserved members and
  the assigned event Professor. Direct writes remain unavailable.
- Archived events reject RPC and privileged direct team/member writes.
  Deletion is forbidden so historical rows remain available.
- Team creation, join requests, leader decisions, and Professor decisions write
  event-bound audit rows in the same transaction as their state changes.

## Verification

```text
npx supabase db reset
Finished supabase db reset; all four migrations and seed applied

npx supabase test db tests/integration/*.sql
Files=4, Tests=166
Result: PASS

npx supabase db lint --local --schema public,private --level warning --fail-on error
No schema errors found

npx supabase db advisors --local --type all --level warn --fail-on error
No issues found

npx vitest run
Test Files  12 passed (12)
Tests       41 passed (41)

npm run build
Nuxt production client and Nitro server build complete

git diff --check
Clean
```

## Self-review

The final review strengthened capacity from RPC-only validation to a
database-level event/team-locked guard, then added a direct-insert regression
test proving the seventh reservation is rejected. It also added the missing
full event foreign-key index for all member states. A reset exposed ambiguous
enum resolution in the shared table trigger; the guard now narrows to the
`team_members` branch before reading member status, and the complete reset,
focused pgTAP, full pgTAP, lint, advisors, Vitest, and production build gates
were rerun afterward.

No known concerns remain for this task's interface.
