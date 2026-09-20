import { describe, expect, it } from 'vitest'
import { shouldRedirectForActiveRoleView } from '../../app/utils/active-role-view-guard'

const EVENT_A = '10000000-0000-4000-8000-000000000901'
const EVENT_B = '10000000-0000-4000-8000-000000000902'

describe('active role-view route guard', () => {
  it('redirects an SSR request to a protected route before browser-only state exists', () => {
    expect(shouldRedirectForActiveRoleView({
      path: '/app/admin/usuarios',
      activeView: null,
      isServer: true,
    })).toBe(true)
  })

  it.each([
    ['professor', `/app/evento/${EVENT_B}/admin/equipes`],
    ['monitor', `/app/evento/${EVENT_B}/revisoes`],
    ['evaluator', `/app/evento/${EVENT_B}/avaliacao`],
  ] as const)('redirects %s when the protected event differs from the selected event', (role, path) => {
    expect(shouldRedirectForActiveRoleView({
      path,
      activeView: { role, eventId: EVENT_A },
      isServer: false,
    })).toBe(true)
  })

  it('allows a matching client-side event role view', () => {
    expect(shouldRedirectForActiveRoleView({
      path: `/app/evento/${EVENT_A}/revisoes`,
      activeView: { role: 'monitor', eventId: EVENT_A },
      isServer: false,
    })).toBe(false)
  })
})
