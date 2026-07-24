import type { SupabaseClient } from '@supabase/supabase-js'
import {
  computed,
  getCurrentInstance,
  onMounted,
  onScopeDispose,
  ref,
  watch,
  type ComputedRef,
  type Ref,
} from 'vue'
import type { Database } from '~/types/database'
import { installBrowserReconciliation } from '../utils/browser-reconciliation'

interface TeamContext {
  teamEventIds: string[]
  teamIds: string[]
}

interface TeamContextController {
  data: Ref<TeamContext>
  pending: Ref<boolean>
  error: Ref<unknown>
  retain: () => void
  release: () => void
  refresh: () => Promise<void>
}

const teamControllers = new WeakMap<object, TeamContextController>()

function createTeamContextController(
  supabase: SupabaseClient<Database>,
  userId: ComputedRef<string | null>,
): TeamContextController {
  const data = ref<TeamContext>({ teamEventIds: [], teamIds: [] })
  const pending = ref(false)
  const error = ref<unknown>(null)
  let channel: ReturnType<typeof supabase.channel> | null = null
  let stopIdentityWatch: (() => void) | null = null
  let consumers = 0
  let active = false
  let generation = 0
  let reloadPromise: Promise<void> | null = null
  let stopReconciliation: (() => void) | null = null

  function stopChannel() {
    const current = channel
    channel = null
    if (current) void supabase.removeChannel(current)
  }

  function startChannel() {
    const scopedUserId = userId.value
    if (
      !active
      || !scopedUserId
      || channel
      || typeof window === 'undefined'
    ) return

    // This subscription is deliberately unfiltered. Realtime applies the
    // authenticated user's RLS policies, and raw emails may contain filter
    // syntax characters. Revocations are reconciled independently.
    channel = supabase
      .channel(`dashboard-teams:${scopedUserId}`)
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'team_members',
      }, () => {
        void refresh(true)
      })
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'teams',
      }, () => {
        void refresh(true)
      })
      .subscribe()
  }

  async function refresh(silent = false) {
    const expectedUserId = userId.value
    if (!expectedUserId) {
      data.value = { teamEventIds: [], teamIds: [] }
      pending.value = false
      return
    }
    if (reloadPromise) return reloadPromise
    const expectedGeneration = generation
    if (!silent) {
      pending.value = true
      error.value = null
    }
    const currentPromise = (async () => {
      try {
        const { data: rows, error: teamError } = await supabase
          .from('teams')
          .select('id,event_id,status')
        if (teamError) throw teamError
        if (
          expectedGeneration !== generation
          || expectedUserId !== userId.value
        ) return
        const visibleTeams = (rows ?? []).filter(team => team.status !== 'rejected')
        const nextData = {
          teamEventIds: [...new Set(visibleTeams.map(team => team.event_id))].sort(),
          teamIds: visibleTeams.map(team => team.id).sort(),
        }
        if (
          nextData.teamEventIds.join(',') !== data.value.teamEventIds.join(',')
          || nextData.teamIds.join(',') !== data.value.teamIds.join(',')
        ) {
          data.value = nextData
        }
        error.value = null
      }
      catch (caught) {
        if (
          expectedGeneration !== generation
          || expectedUserId !== userId.value
        ) return
        if (!silent) {
          data.value = { teamEventIds: [], teamIds: [] }
          error.value = caught
        }
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
      await currentPromise
    }
    finally {
      if (reloadPromise === currentPromise) reloadPromise = null
    }
  }

  function start() {
    if (active) return
    active = true
    stopIdentityWatch = watch(
      userId,
      (nextUserId, previousUserId) => {
        if (nextUserId !== previousUserId) {
          generation += 1
          reloadPromise = null
          data.value = { teamEventIds: [], teamIds: [] }
          error.value = null
        }
        stopChannel()
        if (!nextUserId) {
          pending.value = false
          return
        }
        startChannel()
        void refresh(false)
      },
      { immediate: true },
    )
    stopReconciliation = installBrowserReconciliation(() => refresh(true))
  }

  function stop() {
    if (!active) return
    active = false
    generation += 1
    reloadPromise = null
    stopIdentityWatch?.()
    stopIdentityWatch = null
    stopReconciliation?.()
    stopReconciliation = null
    stopChannel()
    data.value = { teamEventIds: [], teamIds: [] }
    pending.value = false
    error.value = null
  }

  return {
    data,
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

export function useDashboardEventContext() {
  const route = useRoute()
  const { $supabase } = useNuxtApp()
  const access = useCurrentAccess()
  const routeEventId = computed(() => {
    const value = route.params.eventId
    return typeof value === 'string' && value ? value : null
  })

  if (!$supabase) {
    const teamEventIds = computed(() => [] as string[])
    return {
      ...access,
      teamEventIds,
      contextPending: ref(false),
      contextError: ref<unknown>(null),
      refreshTeamContext: async () => {},
      currentEventId: computed(() => null as string | null),
    }
  }
  let teamAccess = teamControllers.get($supabase)
  if (!teamAccess) {
    teamAccess = createTeamContextController(
      $supabase,
      access.userId,
    )
    teamControllers.set($supabase, teamAccess)
  }
  if (getCurrentInstance()) {
    onMounted(teamAccess.retain)
    onScopeDispose(teamAccess.release)
  }

  const { data: featuredEvent, pending: featuredEventPending } = useAsyncData(
    'context-featured-event',
    () => $fetch('/api/featured-event'),
    { server: false }
  )

  const teamEventIds = computed(
    () => teamAccess?.data.value.teamEventIds ?? [],
  )

  const authorizedEventIds = computed(() => {
    const ids = new Set([
      ...access.eventRoles.value.map(role => role.event_id),
      ...teamEventIds.value,
    ])
    if (featuredEvent.value?.id) {
      ids.add(featuredEvent.value.id)
    }
    return ids
  })

  const currentEventId = computed(() => {
    if (routeEventId.value) {
      return authorizedEventIds.value.has(routeEventId.value)
        ? routeEventId.value
        : null
    }
    return access.eventRoles.value[0]?.event_id
      ?? teamEventIds.value[0]
      ?? featuredEvent.value?.id
      ?? null
  })

  return {
    ...access,
    teamEventIds,
    contextPending: computed(() => teamAccess!.pending.value || featuredEventPending.value),
    contextError: teamAccess.error,
    refreshTeamContext: teamAccess.refresh,
    currentEventId,
  }
}

