// @vitest-environment happy-dom
import { nextTick, ref } from 'vue'
import { afterEach, describe, expect, it } from 'vitest'
import { useActiveRoleView } from '../../app/composables/useActiveRoleView'
import {
  availableRoleViewsForAccess,
  resolveActiveRoleView,
} from '../../app/utils/active-role-view'

const EVENT_ID = '10000000-0000-4000-8000-000000000901'

describe('active role views', () => {
  it('keeps a saved student narrowing while access and membership arrive independently', async () => {
    const key = `ligalab:active-view:delayed-user:${EVENT_ID}`
    const saved = JSON.stringify({ role: 'student', eventId: EVENT_ID })
    localStorage.setItem(key, saved)
    const context = {
      userId: ref('delayed-user'), globalRole: ref<'student' | null>(null),
      eventRoles: ref<Array<{ event_id: string, role: 'professor' }>>([]),
      teamEventIds: ref<string[]>([]), currentEventId: ref(EVENT_ID), ready: ref(false),
    }
    const view = useActiveRoleView(context)
    expect(view.activeView.value).toBeNull()
    expect(localStorage.getItem(key)).toBe(saved)
    context.globalRole.value = 'student'
    context.eventRoles.value = [{ event_id: EVENT_ID, role: 'professor' }]
    await nextTick()
    expect(view.activeView.value).toBeNull()
    expect(localStorage.getItem(key)).toBe(saved)
    context.teamEventIds.value = [EVENT_ID]
    context.ready.value = true
    await nextTick()
    expect(view.activeView.value).toEqual({ role: 'student', eventId: EVENT_ID })
    context.teamEventIds.value = []
    await nextTick()
    expect(view.activeView.value).toEqual({ role: 'professor', eventId: EVENT_ID })
  })
  afterEach(() => localStorage.clear())
  it('lets a global admin narrow to professor but never derives admin from professor', () => {
    const views = availableRoleViewsForAccess({
      globalRole: 'global_admin',
      eventRoles: [],
      teamEventIds: [],
      eventId: EVENT_ID,
    })

    expect(views.map(view => view.role)).toEqual([
      'global_admin',
      'professor',
      'monitor',
      'evaluator',
      'student',
    ])
    expect(availableRoleViewsForAccess({
      globalRole: 'student',
      eventRoles: [{ event_id: EVENT_ID, role: 'professor' }],
      teamEventIds: [],
      eventId: EVENT_ID,
    }).map(view => view.role)).toEqual(['professor'])
  })

  it('falls back after a stored monitor role is revoked', () => {
    expect(resolveActiveRoleView({
      stored: { role: 'monitor', eventId: EVENT_ID },
      available: [{ role: 'student', eventId: EVENT_ID }],
    })).toEqual({ role: 'student', eventId: EVENT_ID })
  })

  it('restores an event-scoped stored selection and isolates it by user', async () => {
    localStorage.setItem(
      `ligalab:active-view:user-a:${EVENT_ID}`,
      JSON.stringify({ role: 'monitor', eventId: EVENT_ID }),
    )
    localStorage.setItem(
      `ligalab:active-view:user-b:${EVENT_ID}`,
      JSON.stringify({ role: 'professor', eventId: EVENT_ID }),
    )
    const context = {
      userId: ref('user-a'),
      globalRole: ref<'global_admin' | 'student' | null>('global_admin'),
      eventRoles: ref<Array<{ event_id: string, role: 'professor' | 'monitor' | 'evaluator' }>>([]),
      teamEventIds: ref<string[]>([]),
      currentEventId: ref<string | null>(EVENT_ID),
    }
    const roleView = useActiveRoleView(context)

    await nextTick()
    expect(roleView.activeView.value).toEqual({ role: 'monitor', eventId: EVENT_ID })

    context.userId.value = 'user-b'
    await nextTick()
    expect(roleView.activeView.value).toEqual({ role: 'professor', eventId: EVENT_ID })
  })

  it('clears malformed and revoked stored selections without a fallback', async () => {
    localStorage.setItem(`ligalab:active-view:bad-storage:${EVENT_ID}`, '{bad json')
    const context = {
      userId: ref('bad-storage'),
      globalRole: ref<'global_admin' | 'student' | null>('student'),
      eventRoles: ref<Array<{ event_id: string, role: 'professor' | 'monitor' | 'evaluator' }>>([]),
      teamEventIds: ref<string[]>([]),
      currentEventId: ref<string | null>(EVENT_ID),
    }
    const malformed = useActiveRoleView(context)

    await nextTick()
    expect(malformed.activeView.value).toBeNull()
    expect(localStorage.getItem(`ligalab:active-view:bad-storage:${EVENT_ID}`)).toBeNull()

    localStorage.setItem(
      `ligalab:active-view:revoked:${EVENT_ID}`,
      JSON.stringify({ role: 'monitor', eventId: EVENT_ID }),
    )
    const revoked = useActiveRoleView({ ...context, userId: ref('revoked') })
    await nextTick()
    expect(revoked.activeView.value).toBeNull()
    expect(localStorage.getItem(`ligalab:active-view:revoked:${EVENT_ID}`)).toBeNull()
  })

  it('shares an active selection between consumers in the same scope', async () => {
    const context = {
      userId: ref('shared-user'),
      globalRole: ref<'global_admin' | 'student' | null>('global_admin'),
      eventRoles: ref<Array<{ event_id: string, role: 'professor' | 'monitor' | 'evaluator' }>>([]),
      teamEventIds: ref<string[]>([]),
      currentEventId: ref<string | null>(EVENT_ID),
    }
    const first = useActiveRoleView(context)
    const second = useActiveRoleView(context)

    expect(first.setActiveView({ role: 'monitor', eventId: EVENT_ID })).toBe(true)
    await nextTick()
    expect(second.activeView.value).toEqual({ role: 'monitor', eventId: EVENT_ID })
  })
})
