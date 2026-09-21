<script setup lang="ts">
import { computed, nextTick, ref, useId, watch } from 'vue'
import type { Json } from '../../types/database'
import type { NotificationInboxItem } from '../../composables/useNotifications'

const props = defineProps<{
  items: NotificationInboxItem[]
  pending: boolean
  error: unknown
  canCompose: boolean
  eventId?: string | null
  markRead: (ids: string[]) => unknown
  refresh: () => unknown
  createManual: (input: Json) => unknown
}>()
const open = ref(false)
const composing = ref(false)
const trigger = ref<HTMLButtonElement | null>(null)
const panel = ref<HTMLElement | null>(null)
const panelId = useId()
const unreadManual = computed(() => props.items.filter(item => item.source === 'manual' && !item.read_at).map(item => item.id))
const unread = computed(() => unreadManual.value.length + props.items.filter(item => item.source === 'automatic').length)
const title = ref('')
const body = ref('')
const audience = ref('event_all')
const selectedEvent = ref(props.eventId ?? '')
const users = ref('')
const team = ref('')
const role = ref('student')
const message = ref('')
const actionError = ref('')
const busy = ref(false)
watch(() => props.eventId, value => { selectedEvent.value = value ?? ''; composing.value = false; actionError.value = '' })
watch(() => props.canCompose, value => { if (!value) composing.value = false })
async function toggle() {
  open.value = !open.value
  if (open.value) { await nextTick(); panel.value?.focus() }
}
async function close() { open.value = false; await nextTick(); trigger.value?.focus() }
async function mark(ids: string[]) {
  actionError.value = ''
  try { await props.markRead(ids) }
  catch { actionError.value = 'Não foi possível marcar como lida. Tente novamente.' }
}
function safePath(path: string | null) { return path && /^\/app(?:\/[A-Za-z0-9_-]+)*$/.test(path) ? path : null }
async function send() {
  if (busy.value || !props.canCompose) return
  actionError.value = ''; message.value = ''
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
  const ids = [...new Set(users.value.split(/[\s,]+/).filter(Boolean))]
  if (!title.value.trim() || !body.value.trim()) { actionError.value = 'Informe título e mensagem.'; return }
  if ((audience.value !== 'users' && !selectedEvent.value) || (selectedEvent.value && !uuid.test(selectedEvent.value))) {
    actionError.value = 'Informe um evento válido.'; return
  }
  if (audience.value === 'users' && (!ids.length || ids.some(id => !uuid.test(id)))) {
    actionError.value = 'Informe ao menos um destinatário válido.'; return
  }
  if (audience.value === 'team' && !uuid.test(team.value)) { actionError.value = 'Informe uma equipe válida.'; return }
  const target: Record<string, Json> = { type: audience.value }
  if (audience.value === 'users') target.user_ids = ids
  if (audience.value === 'team') target.team_id = team.value
  if (audience.value === 'event_role') target.role = role.value
  busy.value = true
  try {
    await props.createManual({ title: title.value.trim(), body: body.value.trim(), event_id: selectedEvent.value || null, audience: target })
    message.value = 'Notificação enviada.'; composing.value = false; title.value = ''; body.value = ''
  }
  catch { actionError.value = 'Não foi possível enviar. Confira o público selecionado.' }
  finally { busy.value = false }
}
</script>

<template>
  <div class="notification-bell" data-notification-bell @keydown.esc.stop.prevent="close">
    <button ref="trigger" type="button" data-notification-trigger :aria-expanded="open" :aria-controls="panelId" @click="toggle">
      Notificações <span v-if="unread" aria-live="polite">{{ unread }}</span>
    </button>
    <section v-if="open" :id="panelId" ref="panel" tabindex="-1" class="notification-panel" aria-label="Central de notificações">
      <h2>Notificações</h2>
      <button type="button" aria-label="Fechar notificações" @click="close">Fechar</button>
      <p v-if="pending" role="status">Carregando notificações…</p>
      <div v-else-if="error" role="alert">Não foi possível carregar as notificações. <button type="button" data-notification-retry @click="refresh">Tentar novamente</button></div>
      <p v-else-if="!items.length">Nenhuma notificação por aqui.</p>
      <button v-if="unreadManual.length" type="button" data-mark-all-read @click="mark(unreadManual)">Marcar avisos como lidos</button>
      <ul v-if="!error">
        <li v-for="item in items" :key="item.id">
          <NuxtLink v-if="safePath(item.action_path)" :to="safePath(item.action_path)" :data-notification-item="item.id" @click="item.source === 'manual' && mark([item.id])">
            <strong>{{ item.title }}</strong><span>{{ item.body }}</span>
          </NuxtLink>
          <button v-else-if="item.source === 'manual'" type="button" :data-notification-item="item.id" @click="mark([item.id])">
            <strong>{{ item.title }}</strong><span>{{ item.body }}</span>
          </button>
          <p v-else :data-notification-item="item.id">{{ item.title }} — {{ item.body }}</p>
          <small>{{ item.source === 'automatic' ? 'Tarefa pendente' : item.read_at ? 'Lida' : 'Não lida' }}</small>
        </li>
      </ul>
      <p v-if="message" role="status">{{ message }}</p>
      <p v-if="actionError" role="alert">{{ actionError }}</p>
      <button v-if="canCompose" type="button" data-notification-compose @click="composing = !composing">Enviar notificação</button>
      <form v-if="canCompose && composing" data-notification-composer @submit.prevent="send">
        <label>Título<input v-model="title" name="title" required maxlength="160"></label>
        <label>Mensagem<textarea v-model="body" name="body" required maxlength="4000" /></label>
        <label>Evento (identificador)<input v-model="selectedEvent" name="event" :readonly="!!eventId" :required="audience !== 'users'"></label>
        <label>Público<select v-model="audience" name="audience"><option value="event_all">Todos os participantes aprovados</option><option value="event_role">Papel no evento</option><option value="team">Equipe</option><option value="users">Pessoas específicas</option></select></label>
        <label v-if="audience === 'event_role'">Papel<select v-model="role" name="role"><option value="student">Aluno</option><option value="professor">Professor</option><option value="monitor">Monitor</option><option value="evaluator">Avaliador</option></select></label>
        <label v-if="audience === 'team'">Identificador da equipe<input v-model="team" name="team" required></label>
        <label v-if="audience === 'users'">Identificadores dos destinatários, separados por vírgula<textarea v-model="users" name="users" required /></label>
        <button type="submit" :disabled="busy">{{ busy ? 'Enviando…' : 'Enviar' }}</button>
      </form>
    </section>
  </div>
</template>

<style scoped>
.notification-bell { position: relative; }
.notification-panel { position: absolute; right: 0; top: calc(100% + .5rem); z-index: 60; width: min(26rem, calc(100vw - 2rem)); max-height: 75vh; overflow: auto; background: var(--surface, #fff); color: var(--text, #18282a); padding: 1rem; border: 1px solid #cbd5d1; border-radius: .75rem; box-shadow: 0 12px 36px #0002; }
h2 { font-size: 1.15rem; }
ul { list-style: none; margin: 1rem 0; padding: 0; }
li { padding: .75rem 0; border-bottom: 1px solid #dce3df; }
li a, li button { display: grid; gap: .3rem; text-align: left; width: 100%; }
form, label { display: grid; gap: .4rem; }
form { gap: .75rem; margin-top: 1rem; }
input, select, textarea { width: 100%; box-sizing: border-box; }
button, a, input, textarea, select { min-height: 2.75rem; }
</style>
