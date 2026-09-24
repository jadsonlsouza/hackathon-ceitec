import { nextTick, ref } from 'vue'
import { afterEach, expect, it, vi } from 'vitest'

const state = vi.hoisted(() => ({
  destinationEventId: null as string | null,
  refresh: vi.fn(),
  refreshTeamContext: vi.fn(),
}))

vi.mock('../../app/composables/useDashboardEventContext', () => ({
  useDashboardEventContext: (destinationEventId?: string | null) => {
    state.destinationEventId = destinationEventId ?? null
    return {
      activeView: ref({ role: 'professor', eventId: destinationEventId }),
      refresh: state.refresh,
      refreshTeamContext: state.refreshTeamContext,
    }
  },
}))

vi.mock('../../app/utils/active-role-view-guard', () => ({
  activeRoleViewRequirementForPath: () => ({ roles: ['professor'], eventId: 'event-b' }),
  shouldRedirectForActiveRoleView: () => false,
}))

afterEach(() => {
  vi.resetModules()
  vi.unstubAllGlobals()
  state.destinationEventId = null
  state.refresh.mockReset().mockResolvedValue(undefined)
  state.refreshTeamContext.mockReset().mockResolvedValue(undefined)
})

it('evaluates a client navigation against the destination event rather than the mounted route', async () => {
  vi.stubGlobal('defineNuxtRouteMiddleware', (handler: unknown) => handler)
  vi.stubGlobal('navigateTo', vi.fn())
  vi.stubGlobal('useState', () => ref(null))

  const middleware = (await import('../../app/middleware/active-role-view.global')).default as (to: unknown) => Promise<void>
  await middleware({ path: '/app/evento/event-b/admin/canvas', params: { eventId: 'event-b' } })
  await nextTick()

  expect(state.destinationEventId).toBe('event-b')
  expect(state.refresh).toHaveBeenCalledOnce()
  expect(state.refreshTeamContext).toHaveBeenCalledOnce()
})
