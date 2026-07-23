export type GlobalRole = 'student' | 'global_admin'
export type EventRole = 'professor' | 'monitor' | 'evaluator'
export type RequestedRole = EventRole
export type RoleRequestStatus = 'pending' | 'approved' | 'rejected' | 'revoked'

export function canApproveRequest(
  globalRole: GlobalRole,
  eventRole: EventRole | null,
  requestedRole: RequestedRole,
): boolean {
  if (globalRole === 'global_admin') return requestedRole === 'professor'
  return eventRole === 'professor' && ['monitor', 'evaluator'].includes(requestedRole)
}
