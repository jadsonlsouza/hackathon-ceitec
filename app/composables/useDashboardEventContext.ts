export function useDashboardEventContext() {
  const route = useRoute()
  const { $supabase } = useNuxtApp()
  const access = useCurrentAccess()
  const routeEventId = computed(() => {
    const value = route.params.eventId
    return typeof value === 'string' && value ? value : null
  })

  const teamAccess = useAsyncData(
    'dashboard-event-context',
    async () => {
      const { data, error } = await $supabase
        .from('teams')
        .select('event_id')
      if (error) throw error
      return {
        teamEventIds: [...new Set((data ?? []).map(team => team.event_id))],
      }
    },
    {
      server: false,
      default: () => ({ teamEventIds: [] as string[] }),
      watch: [access.profile, access.eventRoles],
    },
  )

  const authorizedEventIds = computed(() => new Set([
    ...access.eventRoles.value.map(role => role.event_id),
    ...teamAccess.data.value.teamEventIds,
  ]))
  const currentEventId = computed(() => {
    if (routeEventId.value && authorizedEventIds.value.has(routeEventId.value)) {
      return routeEventId.value
    }
    return access.eventRoles.value[0]?.event_id
      ?? teamAccess.data.value.teamEventIds[0]
      ?? null
  })

  return {
    ...access,
    teamEventIds: computed(() => teamAccess.data.value.teamEventIds),
    contextPending: teamAccess.pending,
    contextError: teamAccess.error,
    currentEventId,
  }
}
