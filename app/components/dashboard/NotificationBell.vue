<script setup lang="ts">
import { computed, nextTick, ref, useId, watch } from 'vue'
import type { Json } from '../../types/database'
import type { NotificationInboxItem } from '../../composables/useNotifications'

interface AudienceTeam {
  id: string
  name: string
}

interface AudiencePerson {
  id: string
  displayName: string
  email: string
}

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
const unread = computed(() => unreadManual.value.length)
const triggerLabel = computed(() => unread.value
  ? `Notificações, ${unread.value} aviso${unread.value === 1 ? '' : 's'} não lido${unread.value === 1 ? '' : 's'}`
  : 'Notificações, nenhum aviso não lido')
const pendingItems = computed(() => props.items.filter(item => item.source === 'automatic'))
const noticeItems = computed(() => props.items.filter(item => item.source === 'manual'))
const { $supabase } = useNuxtApp()
const title = ref('')
const body = ref('')
const audience = ref('event_all')
const users = ref<string[]>([])
const team = ref('')
const role = ref('student')
const message = ref('')
const actionError = ref('')
const busy = ref(false)
const audienceTeams = ref<AudienceTeam[]>([])
const audienceUsers = ref<AudiencePerson[]>([])
const audienceLoading = ref(false)
const audienceLoadError = ref(false)
const loadedAudienceEventId = ref<string | null>(null)
let audienceLoadGeneration = 0

watch(() => props.eventId, () => {
  composing.value = false
  actionError.value = ''
  audienceTeams.value = []
  audienceUsers.value = []
  audienceLoading.value = false
  audienceLoadError.value = false
  users.value = []
  team.value = ''
  loadedAudienceEventId.value = null
  ++audienceLoadGeneration
})
watch(() => props.canCompose, value => { if (!value) composing.value = false })
watch(composing, value => { if (value) void loadAudienceOptions(props.eventId ?? null) })
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
function personLabel(person: AudiencePerson) {
  if (person.displayName && person.email) return `${person.displayName} — ${person.email}`
  return person.displayName || person.email || 'Participante'
}
async function loadAudienceOptions(eventId: string | null) {
  if (!eventId || loadedAudienceEventId.value === eventId || audienceLoading.value) return
  const generation = ++audienceLoadGeneration
  audienceLoading.value = true
  audienceLoadError.value = false
  try {
    const teamsResult = await $supabase
      .from('teams')
      .select('id,name')
      .eq('event_id', eventId)
      .eq('status', 'approved')
      .order('name')
    if (teamsResult.error) throw teamsResult.error
    const teams = (teamsResult.data ?? []) as AudienceTeam[]
    const teamIds = teams.map(item => item.id)
    const rolesPromise = $supabase
      .from('event_roles')
      .select('user_id,profile:profiles!event_roles_user_id_fkey(display_name,email)')
      .eq('event_id', eventId)
    const membersPromise = teamIds.length
      ? $supabase
          .from('team_members')
          .select('user_id,name,email')
          .eq('event_id', eventId)
          .eq('status', 'active')
          .in('team_id', teamIds)
      : Promise.resolve({ data: [], error: null })
    const [rolesResult, membersResult] = await Promise.all([rolesPromise, membersPromise])
    if (rolesResult.error) throw rolesResult.error
    if (membersResult.error) throw membersResult.error
    if (generation !== audienceLoadGeneration) return

    const people = new Map<string, AudiencePerson>()
    for (const row of (rolesResult.data ?? []) as unknown as Array<{
      user_id: string
      profile: { display_name?: string | null, email?: string | null } | Array<{ display_name?: string | null, email?: string | null }> | null
    }>) {
      const profile = Array.isArray(row.profile) ? row.profile[0] : row.profile
      if (!row.user_id) continue
      people.set(row.user_id, {
        id: row.user_id,
        displayName: profile?.display_name?.trim() ?? '',
        email: profile?.email?.trim() ?? '',
      })
    }
    for (const row of (membersResult.data ?? []) as unknown as Array<{
      user_id: string | null
      name?: string | null
      email?: string | null
    }>) {
      if (!row.user_id) continue
      const existing = people.get(row.user_id)
      people.set(row.user_id, {
        id: row.user_id,
        displayName: existing?.displayName || row.name?.trim() || '',
        email: existing?.email || row.email?.trim() || '',
      })
    }
    audienceTeams.value = teams
    audienceUsers.value = [...people.values()].sort((a, b) => personLabel(a).localeCompare(personLabel(b), 'pt-BR'))
    loadedAudienceEventId.value = eventId
  }
  catch {
    if (generation === audienceLoadGeneration) {
      audienceTeams.value = []
      audienceUsers.value = []
      audienceLoadError.value = true
      loadedAudienceEventId.value = null
    }
  }
  finally {
    if (generation === audienceLoadGeneration) audienceLoading.value = false
  }
}
async function send() {
  if (busy.value || !props.canCompose) return
  actionError.value = ''; message.value = ''
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
  const eventId = props.eventId ?? ''
  const ids = [...new Set(users.value.filter(Boolean))]
  if (!title.value.trim() || !body.value.trim()) { actionError.value = 'Informe título e mensagem.'; return }
  if (!uuid.test(eventId)) { actionError.value = 'Abra um evento válido antes de enviar.'; return }
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
    await props.createManual({ title: title.value.trim(), body: body.value.trim(), event_id: eventId, audience: target })
    message.value = 'Notificação enviada.'; composing.value = false; title.value = ''; body.value = ''; users.value = []; team.value = ''
  }
  catch { actionError.value = 'Não foi possível enviar. Confira o público selecionado.' }
  finally { busy.value = false }
}
</script>

<template>
  <div class="notification-bell" data-notification-bell @keydown.esc.stop.prevent="close">
    <button
      ref="trigger"
      type="button"
      class="notification-trigger"
      data-notification-trigger
      :aria-label="triggerLabel"
      :aria-expanded="open"
      :aria-controls="panelId"
      @click="toggle"
    >
      <svg data-notification-icon aria-hidden="true" viewBox="0 0 24 24" fill="none">
        <path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9Z" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" />
        <path d="M10 21h4" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" />
      </svg>
      <span class="sr-only">Notificações</span>
      <span v-if="unread" class="notification-badge" aria-hidden="true">{{ unread > 99 ? '99+' : unread }}</span>
    </button>
    <section v-if="open" :id="panelId" ref="panel" tabindex="-1" class="notification-panel" aria-label="Central de notificações">
      <header class="notification-panel__header">
        <div>
          <p class="notification-kicker">Central</p>
          <h2>Notificações</h2>
        </div>
        <button class="notification-close" type="button" aria-label="Fechar notificações" @click="close">×</button>
      </header>

      <div v-if="pending" class="notification-state" role="status">
        <span class="notification-state__dot" aria-hidden="true" />
        <div><strong>Carregando notificações</strong><p>Buscando suas pendências e avisos.</p></div>
      </div>
      <div v-else-if="error" class="notification-state notification-state--error" role="alert">
        <div><strong>Não foi possível carregar as notificações.</strong><p>Tente novamente em instantes.</p></div>
        <button type="button" data-notification-retry @click="refresh">Tentar novamente</button>
      </div>
      <div v-else-if="!items.length" class="notification-state notification-state--empty">
        <div><strong>Tudo em dia.</strong><p>Nenhuma pendência ou aviso novo por aqui.</p></div>
      </div>

      <div v-if="unreadManual.length && !pending && !error" class="notification-toolbar">
        <span>{{ unread }} {{ unread === 1 ? 'aviso não lido' : 'avisos não lidos' }}</span>
        <button type="button" data-mark-all-read @click="mark(unreadManual)">Marcar avisos como lidos</button>
      </div>

      <section v-if="!error && pendingItems.length" data-notification-pending class="notification-group">
        <header class="notification-group__header">
          <div><h3>Pendências</h3><p>Ações que ainda precisam da sua atenção.</p></div>
          <span class="notification-count">{{ pendingItems.length }}</span>
        </header>
        <ul>
          <li v-for="item in pendingItems" :key="item.id" class="notification-item notification-item--pending">
            <NuxtLink v-if="safePath(item.action_path)" class="notification-item__action" :to="safePath(item.action_path)" :data-notification-item="item.id">
              <strong>{{ item.title }}</strong><span>{{ item.body }}</span><small>Tarefa pendente</small>
            </NuxtLink>
            <div v-else class="notification-item__action" :data-notification-item="item.id">
              <strong>{{ item.title }}</strong><span>{{ item.body }}</span><small>Tarefa pendente</small>
            </div>
          </li>
        </ul>
      </section>
      <section v-if="!error && noticeItems.length" data-notification-notices class="notification-group">
        <header class="notification-group__header">
          <div><h3>Avisos</h3><p>Comunicados enviados pela organização.</p></div>
          <span class="notification-count">{{ noticeItems.length }}</span>
        </header>
        <ul>
          <li v-for="item in noticeItems" :key="item.id" class="notification-item" :class="{ 'is-unread': !item.read_at }">
            <NuxtLink v-if="safePath(item.action_path)" class="notification-item__action" :to="safePath(item.action_path)" :data-notification-item="item.id" @click="item.source === 'manual' && mark([item.id])">
              <strong>{{ item.title }}</strong><span>{{ item.body }}</span><small>{{ item.read_at ? 'Lida' : 'Não lida' }}</small>
            </NuxtLink>
            <button v-else type="button" class="notification-item__action" :data-notification-item="item.id" @click="mark([item.id])">
              <strong>{{ item.title }}</strong><span>{{ item.body }}</span><small>{{ item.read_at ? 'Lida' : 'Não lida' }}</small>
            </button>
          </li>
        </ul>
      </section>

      <p v-if="message" class="notification-feedback notification-feedback--success" role="status">{{ message }}</p>
      <p v-if="actionError" class="notification-feedback notification-feedback--error" role="alert">{{ actionError }}</p>
      <button v-if="canCompose" class="notification-compose-toggle" type="button" data-notification-compose @click="composing = !composing">{{ composing ? 'Fechar envio' : 'Enviar notificação' }}</button>
      <form v-if="canCompose && composing" class="notification-composer" data-notification-composer @submit.prevent="send">
        <div class="notification-composer__header"><strong>Novo aviso</strong><span>Envie um comunicado manual.</span></div>
        <p v-if="eventId" class="notification-composer__scope" data-notification-scope>Este aviso será enviado dentro do evento atual.</p>
        <p v-else class="notification-composer__scope notification-composer__scope--warning" role="alert">Abra um evento para escolher destinatários e enviar um aviso.</p>
        <p v-if="audienceLoading" class="notification-composer__hint" role="status">Carregando equipes e participantes…</p>
        <div v-else-if="audienceLoadError" class="notification-composer__load-error" role="alert">
          <span>Não foi possível carregar equipes e participantes.</span>
          <button type="button" data-notification-audience-retry @click="loadAudienceOptions(eventId ?? null)">Tentar novamente</button>
        </div>
        <label>Título<input v-model="title" name="title" required maxlength="160"></label>
        <label>Mensagem<textarea v-model="body" name="body" required maxlength="4000" /></label>
        <label>Público<select v-model="audience" name="audience"><option value="event_all">Todos os participantes aprovados</option><option value="event_role">Papel no evento</option><option value="team">Equipe</option><option value="users">Pessoas específicas</option></select></label>
        <label v-if="audience === 'event_role'">Papel<select v-model="role" name="role"><option value="student">Aluno</option><option value="professor">Professor</option><option value="monitor">Monitor</option><option value="evaluator">Avaliador</option></select></label>
        <label v-if="audience === 'team'">Equipe<select v-model="team" name="team" required :disabled="audienceLoading || audienceLoadError"><option disabled value="">Selecione uma equipe</option><option v-for="item in audienceTeams" :key="item.id" :value="item.id">{{ item.name }}</option></select></label>
        <label v-if="audience === 'users'">Pessoas específicas<select v-model="users" name="users" multiple required :disabled="audienceLoading || audienceLoadError"><option v-for="person in audienceUsers" :key="person.id" :value="person.id">{{ personLabel(person) }}</option></select><span class="notification-composer__hint">Selecione uma ou mais pessoas do evento.</span></label>
        <button type="submit" :disabled="busy || !eventId || audienceLoading || audienceLoadError">{{ busy ? 'Enviando…' : 'Enviar' }}</button>
      </form>
    </section>
  </div>
</template>

<style scoped>
.notification-bell { position: relative; }
.notification-trigger { align-items: center; background: #111827; border: 1px solid #334155; border-radius: .7rem; color: #cbd5e1; cursor: pointer; display: inline-flex; height: 2.75rem; justify-content: center; padding: 0; position: relative; transition: background .15s ease, border-color .15s ease, color .15s ease; width: 2.75rem; }
.notification-trigger:hover, .notification-trigger[aria-expanded="true"] { background: #172033; border-color: #38bdf8; color: #f8fafc; }
.notification-trigger svg { height: 1.3rem; width: 1.3rem; }
.notification-badge { align-items: center; background: #0ea5e9; border: 2px solid #070b14; border-radius: 999px; color: #03121c; display: inline-flex; font-size: .68rem; font-weight: 900; justify-content: center; line-height: 1; min-height: 1.25rem; min-width: 1.25rem; padding: 0 .22rem; position: absolute; right: -.42rem; top: -.42rem; }
.notification-panel { background: #0b1220; border: 1px solid #334155; border-radius: .9rem; box-shadow: 0 20px 50px #0009; color: #f8fafc; max-height: min(46rem, calc(100vh - 6rem)); overflow: auto; position: absolute; right: 0; top: calc(100% + .65rem); width: min(29rem, calc(100vw - 2rem)); z-index: 60; }
.notification-panel__header { align-items: center; background: linear-gradient(180deg, #111827, #0b1220); border-bottom: 1px solid #1e293b; display: flex; justify-content: space-between; padding: 1rem 1rem .9rem; position: sticky; top: 0; z-index: 2; }
.notification-kicker { color: #38bdf8; font-size: .7rem; font-weight: 850; letter-spacing: .1em; margin: 0 0 .2rem; text-transform: uppercase; }
.notification-panel h2 { font-size: 1.05rem; margin: 0; }
.notification-close { align-items: center; background: transparent; border: 1px solid #334155; border-radius: .55rem; color: #94a3b8; cursor: pointer; display: inline-flex; font-size: 1.35rem; height: 2.5rem; justify-content: center; line-height: 1; min-height: 2.5rem; width: 2.5rem; }
.notification-close:hover { background: #1e293b; color: #f8fafc; }
.notification-state { align-items: flex-start; color: #cbd5e1; display: flex; gap: .75rem; padding: 1.1rem; }
.notification-state strong { color: #f8fafc; display: block; font-size: .95rem; }
.notification-state p { color: #94a3b8; line-height: 1.45; margin: .25rem 0 0; }
.notification-state button { background: #0369a1; border: 0; border-radius: .5rem; color: #fff; cursor: pointer; font-weight: 750; margin-left: auto; min-height: 2.5rem; padding: .55rem .75rem; white-space: nowrap; }
.notification-state__dot { animation: notification-pulse 1.2s ease-in-out infinite; background: #38bdf8; border-radius: 999px; flex: 0 0 auto; height: .65rem; margin-top: .35rem; width: .65rem; }
.notification-state--error { background: #2a1114; border-bottom: 1px solid #7f1d1d; }
.notification-state--error p { color: #fecaca; }
.notification-state--empty { border-bottom: 1px solid #1e293b; }
.notification-toolbar { align-items: center; border-bottom: 1px solid #1e293b; color: #94a3b8; display: flex; font-size: .78rem; gap: .75rem; justify-content: space-between; padding: .7rem 1rem; }
.notification-toolbar button { background: transparent; border: 0; color: #7dd3fc; cursor: pointer; font-size: .78rem; font-weight: 750; min-height: 2.25rem; padding: .25rem .35rem; }
.notification-toolbar button:hover { color: #bae6fd; text-decoration: underline; }
.notification-group { padding: 1rem; }
.notification-group + .notification-group { border-top: 1px solid #1e293b; }
.notification-group__header { align-items: start; display: flex; gap: 1rem; justify-content: space-between; }
.notification-group h3 { font-size: .9rem; margin: 0; }
.notification-group__header p { color: #64748b; font-size: .76rem; line-height: 1.4; margin: .25rem 0 0; }
.notification-count { align-items: center; background: #172033; border: 1px solid #334155; border-radius: 999px; color: #94a3b8; display: inline-flex; font-size: .72rem; font-weight: 800; justify-content: center; min-height: 1.45rem; min-width: 1.45rem; padding: 0 .35rem; }
.notification-group ul { display: grid; gap: .55rem; list-style: none; margin: .8rem 0 0; padding: 0; }
.notification-item { border: 1px solid #263244; border-radius: .7rem; overflow: hidden; }
.notification-item.is-unread { border-color: #0c4a6e; box-shadow: inset 3px 0 0 #38bdf8; }
.notification-item--pending { border-color: #3f3f46; }
.notification-item__action { background: #101827; border: 0; color: inherit; cursor: pointer; display: grid; gap: .28rem; min-height: 0; padding: .8rem .85rem; text-align: left; text-decoration: none; width: 100%; }
.notification-item__action:hover { background: #172033; }
.notification-item__action strong { color: #e2e8f0; font-size: .88rem; line-height: 1.35; }
.notification-item__action span { color: #94a3b8; font-size: .8rem; line-height: 1.45; }
.notification-item__action small { color: #38bdf8; font-size: .7rem; font-weight: 750; margin-top: .1rem; }
.notification-feedback { border-radius: .55rem; font-size: .82rem; margin: .75rem 1rem 0; padding: .7rem .8rem; }
.notification-feedback--success { background: #052e1b; border: 1px solid #166534; color: #bbf7d0; }
.notification-feedback--error { background: #2a1114; border: 1px solid #7f1d1d; color: #fecaca; }
.notification-compose-toggle { background: #0369a1; border: 0; border-radius: .55rem; color: #fff; cursor: pointer; font-weight: 800; margin: 1rem; min-height: 2.75rem; padding: .65rem .9rem; width: calc(100% - 2rem); }
.notification-compose-toggle:hover { background: #075985; }
.notification-composer { border-top: 1px solid #1e293b; display: grid; gap: .75rem; padding: 1rem; }
.notification-composer__header { display: grid; gap: .15rem; }
.notification-composer__header span { color: #94a3b8; font-size: .8rem; }
.notification-composer__scope { background: #0c2535; border: 1px solid #164e63; border-radius: .5rem; color: #bae6fd; font-size: .78rem; line-height: 1.4; margin: 0; padding: .65rem .7rem; }
.notification-composer__scope--warning { background: #2a1d0a; border-color: #854d0e; color: #fde68a; }
.notification-composer__hint { color: #94a3b8; font-size: .74rem; font-weight: 500; line-height: 1.4; margin: 0; }
.notification-composer__load-error { align-items: center; background: #2a1114; border: 1px solid #7f1d1d; border-radius: .5rem; color: #fecaca; display: flex; font-size: .78rem; gap: .6rem; justify-content: space-between; padding: .65rem .7rem; }
.notification-composer__load-error button { background: transparent; border: 0; color: #7dd3fc; cursor: pointer; font-weight: 750; min-height: 2rem; padding: .2rem .3rem; white-space: nowrap; }
.notification-composer label { color: #cbd5e1; display: grid; font-size: .8rem; font-weight: 700; gap: .35rem; }
.notification-composer input, .notification-composer select, .notification-composer textarea { background: #070b14; border: 1px solid #475569; border-radius: .5rem; box-sizing: border-box; color: #f8fafc; min-height: 2.75rem; padding: .65rem .7rem; width: 100%; }
.notification-composer select[multiple] { min-height: 8.5rem; }
.notification-composer textarea { min-height: 5.5rem; resize: vertical; }
.notification-composer button[type="submit"] { background: #0369a1; border: 0; border-radius: .55rem; color: #fff; cursor: pointer; font-weight: 800; min-height: 2.75rem; padding: .65rem .9rem; }
.notification-composer button:disabled { cursor: wait; opacity: .55; }
@keyframes notification-pulse { 0%, 100% { opacity: .35; transform: scale(.85); } 50% { opacity: 1; transform: scale(1); } }
@media (max-width: 36rem) {
  .notification-panel { position: fixed; right: 1rem; top: 4.75rem; width: calc(100vw - 2rem); }
  .notification-state--error { display: grid; }
  .notification-state button { margin-left: 0; width: max-content; }
}
</style>
