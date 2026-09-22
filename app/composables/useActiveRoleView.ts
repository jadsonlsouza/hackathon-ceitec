import { computed, ref, watch, type ComputedRef, type Ref } from 'vue'
import {
  availableRoleViewsForAccess,
  resolveActiveRoleView,
  type ActiveRoleView,
} from '../utils/active-role-view'

interface ActiveRoleViewContext {
  userId: Ref<string | null> | ComputedRef<string | null>
  globalRole: Ref<'global_admin' | 'student' | null> | ComputedRef<'global_admin' | 'student' | null>
  eventRoles: Ref<Array<{ event_id: string, role: 'professor' | 'monitor' | 'evaluator' }>> | ComputedRef<Array<{ event_id: string, role: 'professor' | 'monitor' | 'evaluator' }>>
  teamEventIds: Ref<string[]> | ComputedRef<string[]>
  currentEventId: Ref<string | null> | ComputedRef<string | null>
}

interface StoredView {
  exists: boolean
  view: ActiveRoleView | null
  valid: boolean
}

interface ActiveRoleViewController {
  activeView: Ref<ActiveRoleView | null>
  stored: StoredView | null
}

const controllers = new Map<string, ActiveRoleViewController>()
const isBrowser = import.meta.client || typeof window !== 'undefined'

function sameView(left: ActiveRoleView | null, right: ActiveRoleView | null) {
  return left?.role === right?.role && left?.eventId === right?.eventId
}

function storageKey(userId: string, eventId: string | null) {
  return `ligalab:active-view:${userId}:${eventId ?? 'global'}`
}

function isActiveRoleView(value: unknown): value is ActiveRoleView {
  return (
    typeof value === 'object'
    && value !== null
    && 'role' in value
    && 'eventId' in value
    && ['global_admin', 'professor', 'monitor', 'evaluator', 'student'].includes(String(value.role))
    && (typeof value.eventId === 'string' || value.eventId === null)
  )
}

function readStoredView(key: string): StoredView {
  if (!isBrowser) return { exists: false, valid: true, view: null }
  const raw = localStorage.getItem(key)
  if (raw === null) return { exists: false, valid: true, view: null }
  try {
    const value: unknown = JSON.parse(raw)
    if (isActiveRoleView(value)) return { exists: true, valid: true, view: value }
  }
  catch {
    // Invalid browser storage is cleared during reconciliation.
  }
  return { exists: true, valid: false, view: null }
}

function getController(key: string) {
  let controller = controllers.get(key)
  if (!controller) {
    controller = { activeView: ref<ActiveRoleView | null>(null), stored: readStoredView(key) }
    controllers.set(key, controller)
  }
  return controller
}

function persist(key: string, view: ActiveRoleView | null) {
  if (!isBrowser) return
  if (view) localStorage.setItem(key, JSON.stringify(view))
  else localStorage.removeItem(key)
}

// This stores only the client-side dashboard narrowing. Authorization remains
// in the database and route middleware validates the stored view against the
// user's actual global/event access before using it.
export function setStoredActiveRoleView(
  userId: string,
  eventId: string,
  view: ActiveRoleView,
) {
  if (!userId || !eventId || view.eventId !== eventId) return false
  const key = storageKey(userId, eventId)
  persist(key, view)
  const controller = controllers.get(key)
  if (controller) {
    controller.activeView.value = view
    controller.stored = null
  }
  return isBrowser
}

export function useActiveRoleView(context: ActiveRoleViewContext) {
  const availableViews = computed(() => availableRoleViewsForAccess({
    globalRole: context.globalRole.value,
    eventRoles: context.eventRoles.value,
    teamEventIds: context.teamEventIds.value,
    eventId: context.currentEventId.value,
  }))
  const scopeKey = computed(() => {
    const userId = context.userId.value
    return userId ? storageKey(userId, context.currentEventId.value) : null
  })

  const isViewValid = (view: ActiveRoleView | null) => Boolean(view && availableViews.value.some(available => (
    available.role === view.role && available.eventId === view.eventId
  )))

  function reconcile() {
    const key = scopeKey.value
    if (!key) return
    const controller = getController(key)
    const stored = controller.stored
    const candidate = controller.activeView.value ?? stored?.view ?? null
    const resolved = resolveActiveRoleView({ stored: candidate, available: availableViews.value })

    if (stored?.exists && (!stored.valid || !sameView(stored.view, resolved))) persist(key, resolved)
    else if (candidate && !sameView(candidate, resolved)) persist(key, resolved)
    controller.activeView.value = resolved
    controller.stored = null
  }

  function setActiveView(view: ActiveRoleView) {
    const key = scopeKey.value
    if (!key || !isViewValid(view)) return false
    const controller = getController(key)
    controller.activeView.value = view
    controller.stored = null
    persist(key, view)
    return true
  }

  watch(
    () => [scopeKey.value, availableViews.value.map(view => `${view.role}:${view.eventId ?? ''}`).join(',')],
    reconcile,
    { immediate: true },
  )

  return {
    activeView: computed(() => {
      const key = scopeKey.value
      return key ? getController(key).activeView.value : null
    }),
    availableViews,
    setActiveView,
    isViewValid,
  }
}
