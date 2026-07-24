import type { SupabaseClient } from '@supabase/supabase-js'
import {
  computed,
  getCurrentInstance,
  onMounted,
  onScopeDispose,
  ref,
  type Ref,
} from 'vue'
import type { Database } from '~/types/database'
import { installBrowserReconciliation } from '../utils/browser-reconciliation'

type Profile = Database['public']['Tables']['profiles']['Row']
type EventRole = Database['public']['Tables']['event_roles']['Row']

export interface CurrentAccess {
  profile: Profile | null
  eventRoles: EventRole[]
}

interface CurrentAccessController {
  profile: Ref<Profile | null>
  eventRoles: Ref<EventRole[]>
  userId: Ref<string | null>
  reconciliationRevision: Ref<number>
  pending: Ref<boolean>
  error: Ref<unknown>
  retain: () => void
  release: () => void
  refresh: () => Promise<void>
}

const accessControllers = new WeakMap<object, CurrentAccessController>()

export async function loadCurrentAccess(
  supabase: SupabaseClient<Database>,
  userId: string,
): Promise<CurrentAccess> {
  const [profileResult, eventRolesResult] = await Promise.all([
    supabase
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .single(),
    supabase
      .from('event_roles')
      .select('*')
      .eq('user_id', userId),
  ])

  if (profileResult.error) throw profileResult.error
  if (eventRolesResult.error) throw eventRolesResult.error

  return {
    profile: profileResult.data,
    eventRoles: eventRolesResult.data ?? [],
  }
}

export function createCurrentAccessController(
  supabase: SupabaseClient<Database>,
): CurrentAccessController {
  const profile = ref<Profile | null>(null)
  const eventRoles = ref<EventRole[]>([])
  const userId = ref<string | null>(null)
  const reconciliationRevision = ref(0)
  const pending = ref(false)
  const error = ref<unknown>(null)
  let accessChannel: ReturnType<typeof supabase.channel> | null = null
  let authSubscription: { unsubscribe: () => void } | null = null
  let consumers = 0
  let active = false
  let generation = 0
  let authEpoch = 0
  let reloadPromise: Promise<boolean> | null = null
  let refreshPromise: Promise<void> | null = null
  let stopReconciliation: (() => void) | null = null

  function sameProfile(left: Profile | null, right: Profile | null) {
    if (!left || !right) return left === right
    return (
      left.id === right.id
      && left.email === right.email
      && left.display_name === right.display_name
      && left.global_role === right.global_role
      && left.created_at === right.created_at
      && left.updated_at === right.updated_at
    )
  }

  function roleKey(role: EventRole) {
    return JSON.stringify([
      role.event_id,
      role.role,
      role.user_id,
      role.approved_by,
      role.approved_at,
      [...role.categories].sort(),
    ])
  }

  function sameEventRoles(left: EventRole[], right: EventRole[]) {
    if (left.length !== right.length) return false
    const leftKeys = left.map(roleKey).sort()
    const rightKeys = right.map(roleKey).sort()
    return leftKeys.every(
      (key, index) => key === rightKeys[index],
    )
  }

  function clearAccess() {
    profile.value = null
    eventRoles.value = []
    error.value = null
  }

  function stopAccessChannel() {
    const channel = accessChannel
    accessChannel = null
    if (channel) void supabase.removeChannel(channel)
  }

  function startAccessChannel(targetUserId: string) {
    if (!active || accessChannel || typeof window === 'undefined') return
    accessChannel = supabase
      .channel(`current-access:${targetUserId}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'profiles',
        filter: `id=eq.${targetUserId}`,
      }, () => {
        void reloadCurrent(true)
      })
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'profiles',
        filter: `id=eq.${targetUserId}`,
      }, () => {
        void reloadCurrent(true)
      })
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'event_roles',
        filter: `user_id=eq.${targetUserId}`,
      }, () => {
        void reloadCurrent(true)
      })
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'event_roles',
        filter: `user_id=eq.${targetUserId}`,
      }, () => {
        void reloadCurrent(true)
      })
      .subscribe()
  }

  async function reloadCurrent(silent = false) {
    const expectedUserId = userId.value
    if (!expectedUserId) return
    if (reloadPromise) return reloadPromise
    const expectedGeneration = generation
    if (!silent) {
      pending.value = true
      error.value = null
    }
    const currentPromise = (async () => {
      try {
        const loaded = await loadCurrentAccess(supabase, expectedUserId)
        if (
          expectedGeneration !== generation
          || expectedUserId !== userId.value
        ) return false
        if (!sameProfile(profile.value, loaded.profile)) {
          profile.value = loaded.profile
        }
        if (!sameEventRoles(eventRoles.value, loaded.eventRoles)) {
          eventRoles.value = loaded.eventRoles
        }
        error.value = null
        return true
      }
      catch (caught) {
        if (
          expectedGeneration !== generation
          || expectedUserId !== userId.value
        ) return false
        if (!silent) {
          clearAccess()
          error.value = caught
        }
        return false
      }
      finally {
        if (
          expectedGeneration === generation
          && expectedUserId === userId.value
          && !silent
        ) pending.value = false
      }
    })()
    reloadPromise = currentPromise
    try {
      return await currentPromise
    }
    finally {
      if (reloadPromise === currentPromise) reloadPromise = null
    }
  }

  async function changeUser(nextUserId: string | null, silent = false) {
    const changed = nextUserId !== userId.value
    if (changed) {
      generation += 1
      reloadPromise = null
      stopAccessChannel()
      userId.value = nextUserId
      clearAccess()
      pending.value = Boolean(nextUserId)
      if (nextUserId) startAccessChannel(nextUserId)
    }
    if (!nextUserId) {
      pending.value = false
      return true
    }
    return reloadCurrent(changed ? false : silent)
  }

  async function refresh(silent = false) {
    if (refreshPromise) return refreshPromise
    const expectedAuthEpoch = authEpoch
    if (!silent) pending.value = true
    const currentPromise = (async () => {
      try {
        const { data, error: authError } = await supabase.auth.getUser()
        if (expectedAuthEpoch !== authEpoch) return
        if (authError) throw authError
        const nextUserId = data.user?.id ?? null
        const succeeded = await changeUser(nextUserId, silent)
        if (
          silent
          && succeeded
          && nextUserId
          && expectedAuthEpoch === authEpoch
        ) reconciliationRevision.value += 1
      }
      catch (caught) {
        if (expectedAuthEpoch !== authEpoch || silent) return
        generation += 1
        stopAccessChannel()
        userId.value = null
        clearAccess()
        error.value = caught
        pending.value = false
      }
    })()
    refreshPromise = currentPromise
    try {
      await currentPromise
    }
    finally {
      if (refreshPromise === currentPromise) refreshPromise = null
    }
  }

  function start() {
    if (active) return
    active = true
    const { data } = supabase.auth.onAuthStateChange((_event, session) => {
      authEpoch += 1
      const nextUserId = session?.user?.id ?? null
      void changeUser(nextUserId)
    })
    authSubscription = data.subscription
    // Filtered DELETE events cannot reliably identify a row after RLS removes
    // access. Reconciliation covers revocations; INSERT/UPDATE stay immediate.
    stopReconciliation = installBrowserReconciliation(() => refresh(true))
    void refresh()
  }

  function stop() {
    if (!active) return
    active = false
    authEpoch += 1
    generation += 1
    reloadPromise = null
    refreshPromise = null
    authSubscription?.unsubscribe()
    authSubscription = null
    stopReconciliation?.()
    stopReconciliation = null
    stopAccessChannel()
    userId.value = null
    clearAccess()
    pending.value = false
  }

  return {
    profile,
    eventRoles,
    userId,
    reconciliationRevision,
    pending,
    error,
    retain() {
      consumers += 1
      if (consumers === 1) start()
    },
    release() {
      consumers = Math.max(0, consumers - 1)
      if (consumers === 0) stop()
    },
    refresh,
  }
}

export function useCurrentAccess() {
  const { $supabase } = useNuxtApp()
  if (!$supabase) {
    return {
      profile: computed(() => null as Profile | null),
      eventRoles: computed(() => [] as EventRole[]),
      userId: computed(() => null as string | null),
      reconciliationRevision: ref(0),
      pending: ref(false),
      error: ref<unknown>(null),
      refresh: async () => {},
    }
  }
  let access = accessControllers.get($supabase)
  if (!access) {
    access = createCurrentAccessController($supabase)
    accessControllers.set($supabase, access)
  }

  if (getCurrentInstance()) {
    onMounted(access.retain)
    onScopeDispose(access.release)
  }

  return {
    profile: computed(() => access.profile.value),
    eventRoles: computed(() => access.eventRoles.value),
    userId: computed(() => access.userId.value),
    reconciliationRevision: access.reconciliationRevision,
    pending: access.pending,
    error: access.error,
    refresh: access.refresh,
  }
}
