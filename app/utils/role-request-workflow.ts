import type { Database } from '~/types/database'

type Profile = Pick<
  Database['public']['Tables']['profiles']['Row'],
  'global_role'
>
type EventRole = Pick<
  Database['public']['Tables']['event_roles']['Row'],
  'event_id' | 'role'
>
type Decision = 'approved' | 'rejected'

interface SubmitRoleDecisionOptions {
  rpc: (
    functionName: 'decide_role_request',
    args: { request_id: string, decision: Decision },
  ) => PromiseLike<{ error: unknown }>
  refresh: (key: string) => Promise<unknown>
  setProcessing: (requestId: string | null) => void
  setError: (message: string | null) => void
  isProcessing: () => boolean
  requestId: string
  decision: Decision
  refreshKey: string
}

export const GLOBAL_ROLE_REQUESTS_KEY = 'global-professor-role-requests'
export const ROLE_DECISION_ERROR = 'Não foi possível registrar a decisão.'

export function eventRoleRequestsKey(eventId: string) {
  return `event-role-requests:${eventId}`
}

export function canManageGlobalRoleRequests(profile: Profile | null) {
  return profile?.global_role === 'global_admin'
}

export function canManageEventRoleRequests(
  eventRoles: EventRole[],
  eventId: string,
  profile: Profile | null = null,
) {
  return profile?.global_role === 'global_admin' || eventRoles.some(role => (
    role.event_id === eventId && role.role === 'professor'
  ))
}

export function isRequestProcessing(
  processingId: string | null,
  _requestId: string,
) {
  return processingId !== null
}

export async function submitRoleDecision({
  rpc,
  refresh,
  setProcessing,
  setError,
  isProcessing,
  requestId,
  decision,
  refreshKey,
}: SubmitRoleDecisionOptions) {
  if (isProcessing()) return false

  setError(null)
  setProcessing(requestId)

  try {
    const { error } = await rpc('decide_role_request', {
      request_id: requestId,
      decision,
    })

    if (error) {
      setError(ROLE_DECISION_ERROR)
      return false
    }

    await refresh(refreshKey)
    return true
  }
  catch {
    setError(ROLE_DECISION_ERROR)
    return false
  }
  finally {
    setProcessing(null)
  }
}
