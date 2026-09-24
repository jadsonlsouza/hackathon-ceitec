import { describe, expect, it } from 'vitest'
import {
  capabilitiesForActiveView,
  navigationForActiveView,
} from '../../app/utils/dashboard-navigation'

const EVENT_ID = '10000000-0000-4000-8000-000000000901'

describe('active role-view navigation', () => {
  it('shows professor tasks only while an admin is in Professor view', () => {
    expect(navigationForActiveView({ role: 'professor', eventId: EVENT_ID }, EVENT_ID))
      .toEqual(expect.arrayContaining([
        { label: 'Oficinas', to: `/app/evento/${EVENT_ID}/admin/oficinas` },
        { label: 'Presença', to: `/app/evento/${EVENT_ID}/admin/presenca` },
      ]))
  })

  it.each([
    ['global_admin', null, ['Eventos', 'Pessoas e permissões', 'Auditoria']],
    ['monitor', EVENT_ID, ['Revisar envios']],
    ['evaluator', EVENT_ID, ['Avaliar projetos']],
    ['student', EVENT_ID, ['Minha equipe', 'Atividades', 'Oficinas', 'Presença']],
  ] as const)('maps only %s tasks for the active view', (role, eventId, labels) => {
    expect(navigationForActiveView({ role, eventId }, EVENT_ID).map(item => item.label)).toEqual(labels)
  })

  it('does not expose event-relative tasks without an active event', () => {
    expect(navigationForActiveView({ role: 'monitor', eventId: null }, null)).toEqual([])
  })

  it('maps dashboard summaries to only the active role capabilities', () => {
    expect(capabilitiesForActiveView({ role: 'professor', eventId: EVENT_ID }))
      .toEqual(['manage_event', 'review_submissions'])
  })
})
