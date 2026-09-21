import { computed, onMounted, onScopeDispose, ref, watch, type Ref } from 'vue'
import type { Json } from '../types/database'
import type { ActiveRoleView } from '../utils/active-role-view'
import { installBrowserReconciliation } from '../utils/browser-reconciliation'

export interface NotificationInboxItem {
  id: string
  source: 'manual' | 'automatic'
  kind: string
  title: string
  body: string
  event_id: string | null
  team_id: string | null
  action_path: string | null
  created_at: string
  read_at: string | null
}

export function useNotifications(activeView: Ref<ActiveRoleView | null>, eventId: Ref<string | null>) {
  const { $supabase } = useNuxtApp()
  const access = useCurrentAccess()
  const rows = ref<NotificationInboxItem[]>([])
  const pending = ref(false)
  const error = ref<unknown>(null)
  let generation = 0
  let channel: ReturnType<typeof $supabase.channel> | null = null
  let stopWatch: (() => void) | undefined
  let stopReconcile: (() => void) | undefined
  let alive = true
  const items = computed(() => rows.value.filter(item => {
    const view = activeView.value
    if (!view) return false
    if (item.source === 'manual') return view.role === 'global_admin' || !item.event_id || item.event_id === view.eventId
    if (view.role === 'global_admin') return item.kind === 'role_request_professor'
    if (item.event_id !== view.eventId) return false
    const kinds = {
      professor: ['role_request_monitor', 'role_request_evaluator', 'submission_review'],
      monitor: ['submission_review'], evaluator: ['evaluation_pending'],
      student: ['team_join_request', 'submission_returned'],
    }
    return kinds[view.role].includes(item.kind)
  }))
  const canCompose = computed(() => {
    const view = activeView.value
    const admin = access.profile.value?.global_role === 'global_admin'
    return (view?.role === 'global_admin' && admin) || (view?.role === 'professor' && (
      admin || access.eventRoles.value.some(role => role.event_id === view.eventId && role.role === 'professor')
    ))
  })
  async function refresh() {
    const request = ++generation
    const userId = access.userId.value
    if (!userId || !$supabase) { rows.value = []; pending.value = false; return }
    pending.value = true
    error.value = null
    try {
      const result = await $supabase.rpc('get_notification_inbox')
      if (request !== generation || !alive || userId !== access.userId.value) return
      if (result.error) throw result.error
      rows.value = (result.data ?? []) as NotificationInboxItem[]
    }
    catch {
      if (request === generation && alive) { rows.value = []; error.value = true }
    }
    finally { if (request === generation && alive) pending.value = false }
  }
  async function markRead(ids: string[]) {
    const manualIds = items.value.filter(item => item.source === 'manual' && !item.read_at && ids.includes(item.id)).map(item => item.id)
    if (!manualIds.length) return
    const result = await $supabase.rpc('mark_notifications_read', { notification_ids: manualIds })
    if (result.error) throw new Error('Não foi possível marcar como lida.')
    await refresh()
  }
  async function createManual(input: Json) {
    if (!canCompose.value) throw new Error('Envio não autorizado.')
    const result = await $supabase.rpc('create_manual_notifications', { input })
    if (result.error) throw new Error('Não foi possível enviar. Confira o público selecionado.')
    await refresh()
  }
  function removeChannel() {
    if (channel) void $supabase.removeChannel(channel)
    channel = null
  }
  onMounted(() => {
    stopWatch = watch([access.userId, activeView, eventId, access.reconciliationRevision], () => {
      ++generation
      rows.value = []
      removeChannel()
      if (access.userId.value && $supabase) {
        channel = $supabase.channel(`notifications:${access.userId.value}`)
          .on('postgres_changes', { event: '*', schema: 'public', table: 'notifications', filter: `recipient_id=eq.${access.userId.value}` }, () => { void refresh() })
          .subscribe()
      }
      void refresh()
    }, { immediate: true })
    stopReconcile = installBrowserReconciliation(refresh)
  })
  onScopeDispose(() => { alive = false; ++generation; stopWatch?.(); stopReconcile?.(); removeChannel() })
  return { items, pending, error, canCompose, refresh, markRead, createManual }
}
