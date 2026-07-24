export type Capability =
  | 'manage_events'
  | 'manage_event'
  | 'review_submissions'
  | 'evaluate_teams'
  | 'collaborate'

interface AccessProfile {
  global_role: 'student' | 'global_admin'
}

interface EventRoleAssignment {
  event_id: string
  role: 'professor' | 'monitor' | 'evaluator'
}

export interface DashboardNavigationItem {
  label: string
  to: string
}

interface NavigationDefinition {
  label: string
  to: string
  eventRelative?: boolean
}

const navigationByCapability: Record<Capability, NavigationDefinition[]> = {
  manage_events: [
    { label: 'Eventos', to: '/app/admin/eventos' },
    { label: 'Professores', to: '/app/admin/solicitacoes' },
    { label: 'Usuários', to: '/app/admin/usuarios' },
    { label: 'Auditoria', to: '/app/admin/auditoria' },
  ],
  manage_event: [
    { label: 'Todas as equipes', to: 'admin/equipes', eventRelative: true },
    { label: 'Equipes', to: 'equipes', eventRelative: true },
    { label: 'Solicitações', to: 'solicitacoes', eventRelative: true },
    { label: 'Canvas', to: 'admin/canvas', eventRelative: true },
    { label: 'Oficinas', to: 'admin/oficinas', eventRelative: true },
    { label: 'Conteúdo público', to: 'admin/conteudo-publico', eventRelative: true },
    { label: 'Revisões', to: 'revisoes', eventRelative: true },
    { label: 'Avaliadores', to: 'admin/avaliacao', eventRelative: true },
    { label: 'Resultados', to: 'admin/resultados', eventRelative: true },
    { label: 'Professores', to: 'admin/professores', eventRelative: true },
    { label: 'Presença', to: 'admin/presenca', eventRelative: true },
  ],
  review_submissions: [
    { label: 'Revisões', to: 'revisoes', eventRelative: true },
  ],
  evaluate_teams: [
    { label: 'Avaliações', to: 'avaliacao', eventRelative: true },
  ],
  collaborate: [
    { label: 'Minha equipe', to: 'equipe', eventRelative: true },
    { label: 'Atividades', to: 'atividades', eventRelative: true },
    { label: 'Oficinas', to: 'oficinas', eventRelative: true },
    { label: 'Presença', to: 'presenca', eventRelative: true },
  ],
}

export function capabilitiesForAccess(
  profile: AccessProfile | null,
  eventRoles: EventRoleAssignment[],
  currentEventId: string | null,
  teamEventIds: string[],
): Capability[] {
  const capabilities = new Set<Capability>()

  if (profile?.global_role === 'global_admin') capabilities.add('manage_events')
  if (!currentEventId) return [...capabilities]

  for (const assignment of eventRoles) {
    if (assignment.event_id !== currentEventId) continue
    if (assignment.role === 'professor') capabilities.add('manage_event')
    if (assignment.role === 'monitor') capabilities.add('review_submissions')
    if (assignment.role === 'evaluator') capabilities.add('evaluate_teams')
  }
  const isStaffForEvent = eventRoles.some(r => r.event_id === currentEventId)
  const isEvaluatorForEvent = eventRoles.some(r => r.event_id === currentEventId && r.role === 'evaluator')
  if (
    !isEvaluatorForEvent
    && (teamEventIds.includes(currentEventId) || (!isStaffForEvent && profile?.global_role !== 'global_admin'))
  ) {
    capabilities.add('collaborate')
  }

  return [...capabilities]
}

export function dashboardNavigation(
  capabilities: Capability[],
  currentEventId: string | null,
): DashboardNavigationItem[] {
  const links = new Map<string, DashboardNavigationItem>()

  for (const capability of capabilities) {
    for (const definition of navigationByCapability[capability]) {
      if (definition.eventRelative && !currentEventId) continue
      const to = definition.eventRelative
        ? `/app/evento/${currentEventId}/${definition.to}`
        : definition.to
      if (!links.has(to)) links.set(to, { label: definition.label, to })
    }
  }

  return [...links.values()]
}
