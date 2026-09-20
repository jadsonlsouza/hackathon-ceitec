export type ActiveRole = 'global_admin' | 'professor' | 'monitor' | 'evaluator' | 'student'

export interface ActiveRoleView {
  role: ActiveRole
  eventId: string | null
}

export interface AccessInput {
  globalRole: 'global_admin' | 'student' | null | undefined
  eventRoles: Array<{
    event_id: string
    role: 'professor' | 'monitor' | 'evaluator'
  }>
  teamEventIds: string[]
  eventId: string | null
}

const eventRolesInPriorityOrder = ['professor', 'monitor', 'evaluator'] as const

export function availableRoleViewsForAccess(input: AccessInput): ActiveRoleView[] {
  const views: ActiveRoleView[] = []
  const isGlobalAdmin = input.globalRole === 'global_admin'

  if (isGlobalAdmin) views.push({ role: 'global_admin', eventId: null })
  if (!input.eventId) return views

  for (const role of eventRolesInPriorityOrder) {
    if (isGlobalAdmin || input.eventRoles.some(assignment => (
      assignment.event_id === input.eventId && assignment.role === role
    ))) {
      views.push({ role, eventId: input.eventId })
    }
  }
  if (isGlobalAdmin || input.teamEventIds.includes(input.eventId)) {
    views.push({ role: 'student', eventId: input.eventId })
  }

  return views
}

export function resolveActiveRoleView(input: {
  stored: ActiveRoleView | null
  available: ActiveRoleView[]
}): ActiveRoleView | null {
  if (input.stored && input.available.some(view => (
    view.role === input.stored!.role && view.eventId === input.stored!.eventId
  ))) return input.stored

  return input.available[0] ?? null
}
