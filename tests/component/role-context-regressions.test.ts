import { effectScope, computed, nextTick, ref } from 'vue'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { useDashboardEventContext } from '../../app/composables/useDashboardEventContext'

afterEach(() => { vi.unstubAllGlobals(); localStorage.clear() })

function setup(userId: string, globalRole: 'student' | 'global_admin', members: unknown[]) {
  const rows = [{ id: 'team-a', event_id: 'event-a', status: 'approved', members }]
  vi.stubGlobal('useRoute', () => ({ params: { eventId: 'event-a' } }))
  vi.stubGlobal('useNuxtApp', () => ({ $supabase: { from: () => ({ select: async () => ({ data: rows, error: null }) }) } }))
  vi.stubGlobal('useCurrentAccess', () => ({
    userId: ref(userId), profile: ref({ global_role: globalRole }),
    eventRoles: ref([{ event_id: 'event-a', role: 'professor' }]),
    pending: ref(false), error: ref(null), refresh: async () => {},
  }))
  vi.stubGlobal('useAsyncData', () => ({ data: ref({ id: 'event-a' }), pending: ref(false) }))
}

describe('destination and membership context', () => {
  it('uses destination B while the mounted route still points at A', async () => {
    setup('destination-admin', 'global_admin', [])
    localStorage.setItem('ligalab:active-view:destination-admin:event-b', JSON.stringify({ role: 'professor', eventId: 'event-b' }))
    const scope = effectScope()
    const context = scope.run(() => useDashboardEventContext('event-b'))!
    await context.refreshTeamContext()
    await nextTick()
    expect(context.currentEventId.value).toBe('event-b')
    expect(context.activeView.value).toEqual({ role: 'professor', eventId: 'event-b' })
    scope.stop()
  })

  it.each(['invited', 'join_requested', 'none', 'active'])('derives student access only from own active membership, not %s visibility', async (status) => {
    const user = `membership-${status}`
    setup(user, 'student', [{ user_id: 'other', status: 'active' }, { user_id: user, status }])
    const scope = effectScope()
    const context = scope.run(() => useDashboardEventContext())!
    await context.refreshTeamContext()
    await nextTick()
    expect(context.availableViews.value.some(view => view.role === 'student')).toBe(status === 'active')
    scope.stop()
  })
})
