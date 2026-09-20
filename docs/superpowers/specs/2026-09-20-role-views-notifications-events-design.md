# Role Views, Notifications, and Event Operations Design

## Intent

Make the Ligalab dashboard understandable by function while preserving the current authorization model. People with more than one approved role must choose an explicit active view; the selected view limits interface, client data loading, and action affordances to that role. Global administrators can use any supported event view, but must deliberately switch back to Administration before administrative controls return.

Success means: a user never sees unrelated operational controls; pending work is discoverable from a notification bell; a global administrator can create or duplicate an event without copying private participant data; and navigation uses names that describe the task, not internal implementation terms.

## Scope and Constraints

- Keep `profiles.global_role`, `event_roles`, existing RLS policies, and server-side authorization as the source of truth.
- An active view never grants a role. It can only narrow roles the person already has; `global_admin` may select an event-scoped view for any event.
- Enforce the active view in the client route guard/navigation/action layer. Database functions retain their authorization checks, so a forged route or stale view cannot elevate access.
- Persist an active view only in browser storage. It is valid only for the authenticated user, selected event, and current access revision; invalid selections fall back deterministically.
- Create persistent in-app notifications for manual messages. Automatic notifications are derived from pending domain work and never duplicate records on each page load.
- A duplicated event copies only reusable configuration. It never copies users, teams, members, invitations, submissions, reviews, evaluations, rankings, results, audit history, attendance, or notifications.
- New and duplicated events begin as `draft`; public visibility and registrations require existing explicit status/public-content controls.
- All new labels are Portuguese, task-oriented, and use the Ligalab institutional brand. Preserve event-owned names such as Hackathon CEITEC.

## Active Role Views

### Available views

`Administration` is available only to `global_admin` users. `Professor`, `Monitor`, and `Avaliador` are available when the user has an approved matching `event_roles` row for the active event; a global administrator may enter any of these views for the selected event. `Aluno` is available to users with an active team in that event, and to global administrators for observation.

The selector appears in the dashboard header only when two or more views are available. It shows the active view and event context, uses a native accessible list/button pattern, closes on Escape, and returns focus to its trigger after selection. A single-view user has no redundant selector.

### Authorization behavior

The active view produces `ActiveView = { eventId: string | null, role: 'global_admin' | 'professor' | 'monitor' | 'evaluator' | 'student' }`. `useActiveRoleView()` derives `availableViews`, validates stored state, and exposes `setActiveView(view)`. Dashboard navigation accepts this object instead of the raw union of access roles. Page-level action guards use the same value to hide or disable controls before issuing requests.

Switching views does not alter `event_roles` or sessions. If Realtime revokes a role, the composable discards that view, clears role-specific cached data, and selects the highest-priority valid fallback: Administration for a global admin, otherwise Professor, Monitor, Avaliador, then Aluno. A user entering an incompatible deep link sees a clear access state and is redirected to `/app` rather than a blank page.

## Navigation Labels

Navigation is grouped by the active view and retains only tasks relevant to that view.

| Current purpose | New visible label | Views |
| --- | --- | --- |
| team membership and collaboration | Minha equipe | Aluno |
| organization roster | Equipes | Professor, Administração |
| content builders and workshops | Atividades | Aluno, Professor |
| canvas creation/submission | Meu canvas | Aluno |
| monitor workflow | Revisar envios | Monitor, Professor |
| evaluator queue | Avaliar projetos | Avaliador, Professor |
| judging configuration | Configurar avaliação | Professor |
| public page editing | Conteúdo do evento | Professor |
| outcomes/ties | Resultados | Professor, Administração |
| event-level operations | Configurações do evento | Professor |
| global event registry | Eventos | Administração |
| global identity management | Pessoas e permissões | Administração |
| audit trail | Auditoria | Administração |

There is no fixed `Solicitações` link. Its actionable items move to the notification bell, which links to a filtered task destination when the user selects an item.

## Notification Center

### Data model

Create `public.notifications` with `id`, `recipient_id`, nullable `event_id`, nullable `team_id`, `kind`, `title`, `body`, nullable `action_path`, `created_by`, `created_at`, and nullable `read_at`. Add a check that manual notifications have a non-null creator and a `kind` prefix of `manual_`; system notifications are not stored in this table.

Create a security-definer RPC `get_notification_inbox()` that returns only the caller's manual notifications plus sanitized automatic notification rows. Each result has `{ id, source: 'manual' | 'automatic', kind, title, body, event_id, team_id, action_path, created_at, read_at }`. Automatic IDs are stable deterministic strings derived from the pending entity and recipient, so marking a manual notification read cannot affect them. The RPC only reveals events and teams already visible to the caller.

Create `mark_notifications_read(notification_ids uuid[])`, which updates only the caller's manual records, and `create_manual_notifications(input)` for global admins and event professors. Manual recipients are chosen by exactly one audience: users, team, active role in the event, or all approved participants of the event. The RPC validates event ownership for professors and prevents manual delivery outside their event.

### Interface

`NotificationBell` in the dashboard header fetches the inbox, displays unread count for unread manual plus current automatic items, and subscribes to recipient-filtered notification inserts/updates. It offers mark-one-read, mark-all-manual-read, and navigation to `action_path`. The composer is available from the bell only to Administration/Professor views and requires title, message, audience, and event when the audience is event-scoped.

Automatic items initially cover pending role requests, team join requests awaiting a leader, submitted canvases awaiting monitor/professor review, returned submissions for the team, and presentation/evaluation work assigned to an evaluator. Each automatic item links to the existing contextual screen; no generic inbox page is necessary in the first increment.

## Event Operations

### Event list and wizard

Replace the flat create form in global `Eventos` with a controlled multi-step dialog/page:

1. **Informações básicas:** name, immutable URL slug, dates/period label, venue, optional main-event flag.
2. **Estrutura:** categories, selected professor responsible, and either blank structure or a source event for duplication.
3. **Revisão:** a concise copy summary and explicit "Criar evento como rascunho" action.

Validation runs before leaving each step and on submission. Slug conflicts keep the user in step one. The success state opens the event configuration workspace.

### Safe duplication

Add `duplicate_event_configuration(source_event_id, draft)` guarded for global admins. It creates the draft event and atomically copies: event public-content row as unpublished draft, categories/criteria/weights, canvas templates/activities/blocks, workshops, and any event configuration values explicitly listed in the implementation plan. It assigns the selected responsible professor as an approved `event_roles` record. It leaves all operational tables empty.

The user selects what is copied through a conservative checklist defaulting to all reusable configuration. The review step names each copied and excluded group. If a source has no reusable content, the action still creates a valid empty draft.

## Error Handling and Accessibility

- Active-view failures never silently fall back to elevated abilities; invalid views show a status message and a safe valid view.
- Notification errors leave current navigation usable and show a non-blocking retry status.
- Notification bell, menu, composer, wizard, and duplication checklist use labeled controls, focus trapping only for true dialogs, Escape dismissal, visible focus, and live status for async work.
- Server/RPC errors return generic messages; database error bodies, secrets, recipient e-mails outside an authorized audience, and private team data are never exposed.

## Testing Strategy

- Unit tests cover available-view derivation, persistence validation, fallback after revocation, and navigation filtered by active view rather than raw union roles.
- Component tests cover keyboard interaction/focus behavior for the view selector and notification bell, unread counts, manual composer audience validation, and task-oriented labels.
- pgTAP tests cover notification RLS/RPC audience boundaries, professor event scope, read ownership, and duplication inclusion/exclusion invariants.
- Nuxt/Playwright tests cover switching Admin → Professor blocks administrative controls/routes, notification actions navigate correctly, a draft duplicate has copied configuration but no participant data, and wizard validation errors remain accessible.

## Out of Scope

- E-mail, push, SMS, or WhatsApp delivery.
- Editing/deleting another author's manual notification.
- Cross-event Professor visibility or cross-event manual audience selection.
- Copying historical activity data during duplication.
- Replacing the existing database authorization/RLS system.
