# Final integration fix report

## Scope retained

This recovery retains only the role-view, event-operation, notification, Canvas-copy, and their regression-test changes from the interrupted fix wave. The unrelated untracked plan at `docs/superpowers/plans/2026-09-20-role-views-notifications-events.md` was not edited or staged.

## Review findings resolved

### P1

1. **Mounted-page narrowing:** the dashboard layout derives route compatibility from the active view, removes the incompatible slot immediately, redirects to `/app` after access is settled, and clears role-specific Nuxt data on view changes. Event administration also clears sensitive local state and rechecks the active view before opening or submitting archive actions.
2. **Destination event middleware:** middleware creates a short-lived destination-scoped dashboard context from `to.params.eventId`, refreshes access and team membership, and evaluates the selected view for that destination rather than the currently mounted route.
3. **Activity navigation:** the student activity-list action is now `NuxtLink`, preserving browser-side navigation to the protected editor instead of causing an SSR request.
4. **Archived destructive operations:** the team/member write trigger locks and verifies the old event before any delete authorization. `admin_delete_team` locks the team/event and rejects archived events before authorization or dependent deletes.

### P2

5. **Saved-view hydration:** active-view persistence waits until profile access and team membership are authoritative, retaining stored narrowing during independently delayed loads.
6. **Aluno derivation:** event membership is derived from the caller's own active membership, not broad staff/evaluator team visibility. Student team queries also require that active membership.
7. **Reachable workflows:** Professor and Aluno navigation retain event-scoped Workshop and Attendance links.
8. **Canvas copying:** copied activity blocks use a temporary key/position phase before exact source-block overwrite, avoiding template-seed collisions while keeping the duplicate RPC `SECURITY INVOKER` and preserving the no-DELETE client grant.
9. **Global-admin role requests:** the UI and `private.decide_role_request_impl` allow a global admin in Professor view to resolve monitor/evaluator requests without a fabricated Professor assignment; unrelated users remain denied.

## Regression coverage

- Mounted admin page is removed and redirected when its active view narrows; stale archive submit cannot call the API.
- Middleware receives a destination event while the mounted route still points at another event; membership availability covers active, invited, join-requested, and unrelated members.
- Activity list renders an internal Nuxt link; student data queries are membership-scoped.
- Saved student narrowing survives delayed access/team data and falls back only after confirmed membership loss.
- pgTAP covers archived member/team deletion, a no-submission archived team, renamed/reordered Canvas blocks, rollback behavior, global-admin request decisions with no event Professor role, and unrelated-user denial.

## Verification evidence

- `npm exec vitest run tests/unit` — **20 files, 112 tests passed**.
- Focused component regression suite — **6 files, 53 tests passed**: mounted boundary, role context, event administration, Canvas pages, team pages, and dashboard UI.
- `npm run build` — **passed**.
- After `supabase db reset --local --yes`, targeted `supabase test db --local tests/integration/event-duplication.sql tests/integration/admin-professor-requests.sql` — **2 files, 54 tests passed**. A subsequent identical rerun was blocked by Docker's host-side `/tmp/containerd-mount…` I/O error; no migration or test source changed after the last passing database run.

The repository-wide `npm run test:unit` command was also attempted. It includes Nuxt integration/component suites beyond its name and remained red in unrelated existing suites (dashboard-access realtime mock expects a `useAsyncData` default that the context does not provide; evaluation/results fixtures return their pages' guarded error states; Nuxt test-utils builds were skipped after a harness build failure). These failures are not included as passing verification.

## Remaining design coverage decisions

The review's wizard-field/review-summary/accessibility gaps and the Meu Canvas / Administration mappings were not changed in this final-fix wave. They require an approved product/spec decision rather than a security or integration repair and remain explicitly out of scope here.
