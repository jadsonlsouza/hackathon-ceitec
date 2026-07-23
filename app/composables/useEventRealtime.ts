import {
  getCurrentInstance,
  onMounted,
  onScopeDispose,
  toValue,
  watch,
  type MaybeRefOrGetter,
} from 'vue'

export interface EventRealtimeTarget {
  table: string
  filter: string
  event?: 'INSERT' | 'UPDATE' | 'DELETE' | '*'
}

export function useEventRealtime(
  eventId: MaybeRefOrGetter<string>,
  targets: MaybeRefOrGetter<EventRealtimeTarget[]>,
  onChange: (payload: unknown) => void,
) {
  const { $supabase } = useNuxtApp()
  let activeChannel: ReturnType<typeof $supabase.channel> | null = null

  function stop() {
    const channel = activeChannel
    activeChannel = null
    if (channel) void $supabase.removeChannel(channel)
  }

  function start() {
    if (activeChannel || typeof window === 'undefined') return
    const scopedEventId = toValue(eventId)
    const scopedTargets = toValue(targets)
    if (!scopedEventId || scopedTargets.length === 0) return

    let channel = $supabase.channel(`event:${scopedEventId}:${scopedTargets.map(target => target.table).join(',')}`)
    for (const target of scopedTargets) {
      channel = channel.on('postgres_changes', {
        event: target.event ?? '*',
        schema: 'public',
        table: target.table,
        filter: target.filter,
      }, onChange)
    }
    activeChannel = channel.subscribe()
  }

  if (getCurrentInstance()) onMounted(start)
  watch(() => [
    toValue(eventId),
    JSON.stringify(toValue(targets)),
  ], () => {
    stop()
    start()
  })
  onScopeDispose(stop)

  return { start, stop }
}
