import { computed, ref, watch, type ComputedRef, type Ref } from 'vue'
import {
  availableRoleViewsForAccess,
  resolveActiveRoleView,
  type ActiveRoleView,
} from '../utils/active-role-view'

interface ActiveRoleViewContext {
  userId: Ref<string | null> | ComputedRef<string | null>
  globalRole: Ref<'global_admin' | 'student' | null> | ComputedRef<'global_admin' | 'student' | null>
  eventRoles: Ref<Array<{
    event_id: string
    role: 'professor' | 'monitor' | 'evaluator'
  }>> | ComputedRef<Array<{
    event_id: string
    role: 'professor' | 'monitor' | 'evaluator'
  }>>
  teamEventIds: Ref<string[]> | ComputedRef<string[]>
  currentEventId: Ref<string | null> | ComputedRef<string | null>
}

function sameView(left: ActiveRoleView | null, right: ActiveRoleView | null) {
  return left?.role === right?.role && left?.eventId === right?.eventId
}

function storageKey(userId: string, eventId: string | null) {
  return `ligalab:active-view:${userId}:${eventId ?? 'global'}`
}

function readStoredView(key: string): ActiveRoleView | null {
  if (!import.meta.client) return null
  try {
    const value: unknown = JSON.parse(localStorage.getItem(key) ?? 'null')
    if (
      typeof value === 'object'
      && value !== null
      && 'role' in value
      && 'eventId' in value
      && typeof value.role === 'string'
      && (typeof value.eventId === 'string' || value.eventId === null)
    ) return value as ActiveRoleView
  }
  catch {
    // Invalid browser storage is treated as no selection.
  }
  return null
}

export function useActiveRoleView(context: ActiveRoleViewContext) {
  const availableViews = computed(() => availableRoleViewsForAccess({
    globalRole: context.globalRole.value,
    eventRoles: context.eventRoles.value,
    teamEventIds: context.teamEventIds.value,
    eventId: context.currentEventId.value,
  }))
  const activeView = ref<ActiveRoleView | null>(null)
  let activeScope: string | null = null

  const isViewValid = (view: ActiveRoleView | null) => Boolean(view && availableViews.value.some(available => (
    available.role === view.role && available.eventId === view.eventId
  )))

  function persist(view: ActiveRoleView | null) {
    const userId = context.userId.value
    if (!import.meta.client || !userId) return
    const key = storageKey(userId, context.currentEventId.value)
    if (view) localStorage.setItem(key, JSON.stringify(view))
    else localStorage.removeItem(key)
  }

  function setActiveView(view: ActiveRoleView) {
    if (!isViewValid(view)) return false
    activeView.value = view
    persist(view)
    return true
  }

  watch(
    () => [
      context.userId.value,
      context.currentEventId.value,
      availableViews.value.map(view => `${view.role}:${view.eventId ?? ''}`).join(','),
    ],
    () => {
      const userId = context.userId.value
      if (!userId) {
        activeView.value = null
        activeScope = null
        return
      }
      const key = storageKey(userId, context.currentEventId.value)
      const scopeChanged = key !== activeScope
      const stored = scopeChanged ? readStoredView(key) : activeView.value
      const resolved = resolveActiveRoleView({
        stored,
        available: availableViews.value,
      })
      if (!sameView(stored, resolved) && import.meta.client) {
        if (resolved) localStorage.setItem(key, JSON.stringify(resolved))
        else localStorage.removeItem(key)
      }
      activeView.value = resolved
      activeScope = key
    },
    { immediate: true },
  )

  return {
    activeView: computed(() => activeView.value),
    availableViews,
    setActiveView,
    isViewValid,
  }
}
