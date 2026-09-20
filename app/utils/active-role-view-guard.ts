import type { ActiveRole, ActiveRoleView } from './active-role-view'

interface ActiveRoleViewRouteRequirement {
  roles: ActiveRole[]
  eventId: string | null
}

export function activeRoleViewRequirementForPath(path: string): ActiveRoleViewRouteRequirement | null {
  if (path.startsWith('/app/admin/')) {
    return { roles: ['global_admin'], eventId: null }
  }

  const eventRoute = /^\/app\/evento\/([^/]+)\/(.+)$/.exec(path)
  if (!eventRoute) return null

  const [, eventId, route] = eventRoute
  if (route.startsWith('admin/')) return { roles: ['professor'], eventId }
  if (/^revisoes(?:\/|$)/.test(route)) return { roles: ['professor', 'monitor'], eventId }
  if (/^avaliacao(?:\/|$)/.test(route)) return { roles: ['evaluator'], eventId }
  if (/^(equipe|atividades|oficinas|presenca)(?:\/|$)/.test(route)) return { roles: ['student'], eventId }
  if (/^(equipes|solicitacoes)(?:\/|$)/.test(route)) return { roles: ['professor'], eventId }
  return null
}

export function shouldRedirectForActiveRoleView(input: {
  path: string
  activeView: ActiveRoleView | null
  isServer: boolean
}): boolean {
  const requirement = activeRoleViewRequirementForPath(input.path)
  if (!requirement) return false
  if (input.isServer) return true
  return !input.activeView
    || !requirement.roles.includes(input.activeView.role)
    || (requirement.eventId !== null && input.activeView.eventId !== requirement.eventId)
}
