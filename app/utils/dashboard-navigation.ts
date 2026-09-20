import type { ActiveRole, ActiveRoleView } from './active-role-view'

export type Capability =
  | 'manage_events'
  | 'manage_event'
  | 'review_submissions'
  | 'evaluate_teams'
  | 'collaborate'

export interface DashboardNavigationItem {
  label: string
  to: string
}

interface NavigationDefinition {
  label: string
  to: string
  eventRelative?: boolean
}

const navigationByRole: Record<ActiveRole, NavigationDefinition[]> = {
  global_admin: [
    { label: 'Eventos', to: '/app/admin/eventos' },
    { label: 'Pessoas e permissões', to: '/app/admin/usuarios' },
    { label: 'Auditoria', to: '/app/admin/auditoria' },
  ],
  professor: [
    { label: 'Equipes', to: 'admin/equipes', eventRelative: true },
    { label: 'Atividades', to: 'admin/canvas', eventRelative: true },
    { label: 'Revisar envios', to: 'revisoes', eventRelative: true },
    { label: 'Configurar avaliação', to: 'admin/avaliacao', eventRelative: true },
    { label: 'Conteúdo do evento', to: 'admin/conteudo-publico', eventRelative: true },
    { label: 'Resultados', to: 'admin/resultados', eventRelative: true },
    { label: 'Configurações do evento', to: 'admin/professores', eventRelative: true },
  ],
  monitor: [
    { label: 'Revisar envios', to: 'revisoes', eventRelative: true },
  ],
  evaluator: [
    { label: 'Avaliar projetos', to: 'avaliacao', eventRelative: true },
  ],
  student: [
    { label: 'Minha equipe', to: 'equipe', eventRelative: true },
    { label: 'Atividades', to: 'atividades', eventRelative: true },
  ],
}

const capabilitiesByRole: Record<ActiveRole, Capability[]> = {
  global_admin: ['manage_events'],
  professor: ['manage_event', 'review_submissions'],
  monitor: ['review_submissions'],
  evaluator: ['evaluate_teams'],
  student: ['collaborate'],
}

export function capabilitiesForActiveView(view: ActiveRoleView | null): Capability[] {
  return view ? capabilitiesByRole[view.role] : []
}

export function navigationForActiveView(
  view: ActiveRoleView | null,
  currentEventId: string | null,
): DashboardNavigationItem[] {
  if (!view) return []

  return navigationByRole[view.role].flatMap((definition) => {
    const eventId = view.eventId ?? currentEventId
    if (definition.eventRelative && !eventId) return []
    return [{
      label: definition.label,
      to: definition.eventRelative ? `/app/evento/${eventId}/${definition.to}` : definition.to,
    }]
  })
}
