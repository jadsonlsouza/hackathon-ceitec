import { describe, expect, it } from 'vitest'
import {
  capabilitiesForAccess,
  dashboardNavigation,
} from '../../app/utils/dashboard-navigation'

const EVENT_ID = '10000000-0000-4000-8000-000000000901'

describe('dashboard capability navigation', () => {
  it('gives the global administrator only global administration links', () => {
    const capabilities = capabilitiesForAccess(
      { global_role: 'global_admin' },
      [],
      null,
      [],
    )

    expect(dashboardNavigation(capabilities, null).map(item => item.label)).toEqual([
      'Eventos',
      'Professores',
      'Auditoria',
    ])
  })

  it.each([
    ['professor', ['Equipes', 'Solicitações', 'Canvas', 'Conteúdo público', 'Revisões', 'Avaliadores', 'Resultados']],
    ['monitor', ['Revisões']],
    ['evaluator', ['Avaliações']],
  ] as const)('maps the approved %s role to its event capabilities', (role, labels) => {
    const capabilities = capabilitiesForAccess(
      { global_role: 'student' },
      [{ event_id: EVENT_ID, role }],
      EVENT_ID,
      [],
    )

    expect(dashboardNavigation(capabilities, EVENT_ID).map(item => item.label)).toEqual(labels)
  })

  it('offers collaboration only for an event visible through team membership', () => {
    const capabilities = capabilitiesForAccess(
      { global_role: 'student' },
      [],
      EVENT_ID,
      [EVENT_ID],
    )

    expect(dashboardNavigation(capabilities, EVENT_ID)).toEqual([
      { label: 'Minha equipe', to: `/app/evento/${EVENT_ID}/equipe` },
      { label: 'Atividades', to: `/app/evento/${EVENT_ID}/atividades` },
    ])
  })

  it('returns the deduplicated union for multiple approved roles', () => {
    const capabilities = capabilitiesForAccess(
      { global_role: 'student' },
      [
        { event_id: EVENT_ID, role: 'professor' },
        { event_id: EVENT_ID, role: 'monitor' },
        { event_id: EVENT_ID, role: 'evaluator' },
        { event_id: EVENT_ID, role: 'monitor' },
      ],
      EVENT_ID,
      [EVENT_ID],
    )
    const links = dashboardNavigation(capabilities, EVENT_ID)

    expect(new Set(links.map(item => item.to)).size).toBe(links.length)
    expect(links.map(item => item.label)).toEqual([
      'Equipes',
      'Solicitações',
      'Canvas',
      'Conteúdo público',
      'Revisões',
      'Avaliadores',
      'Resultados',
      'Avaliações',
      'Minha equipe',
      'Atividades',
    ])
  })

  it('never resolves event-relative links without an authorized current event', () => {
    const capabilities = capabilitiesForAccess(
      { global_role: 'student' },
      [{ event_id: EVENT_ID, role: 'monitor' }],
      'event-not-authorized',
      [],
    )

    expect(capabilities).toEqual([])
    expect(dashboardNavigation(['review_submissions'], null)).toEqual([])
  })
})
