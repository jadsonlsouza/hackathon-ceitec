<script setup lang="ts">
import EventWizard from '../../../components/events/EventWizard.vue'
import type { Database } from '~/types/database'

definePageMeta({ middleware: 'auth' })

type EventRow = Database['public']['Tables']['events']['Row']

const EVENTS_KEY = 'admin-events'
const { $supabase } = useNuxtApp()
const { profile, pending: accessPending, error: accessError } =
  useCurrentAccess()
const isAuthorized = computed(
  () => profile.value?.global_role === 'global_admin',
)

const creating = ref(false)
const createMessage = ref<string | null>(null)
const createSlugError = ref<string | null>(null)
const pageError = ref<string | null>(null)

const archiveDialog = ref<HTMLDialogElement | null>(null)
const selectedEvent = ref<EventRow | null>(null)
const confirmedName = ref('')
const archiveSecret = ref('')
const copyConfig = ref(false)
const archiving = ref(false)
const archiveMessage = ref<string | null>(null)
const archiveError = ref<string | null>(null)

const { data: events, pending, error } = await useAsyncData(
  EVENTS_KEY,
  async () => {
    if (!isAuthorized.value) return []

    const { data, error: eventsError } = await $supabase
      .from('events')
      .select('*')
      .order('created_at', { ascending: false })

    if (eventsError) throw eventsError
    return data ?? []
  },
  {
    server: false,
    default: () => [] as EventRow[],
    watch: [profile],
  },
)

const { data: professors } = await useAsyncData(
  'admin-event-professors',
  async () => {
    if (!isAuthorized.value) return []
    const { data, error: professorsError } = await $supabase
      .from('profiles')
      .select('id, display_name, email')
      .order('display_name', { ascending: true })
    if (professorsError) throw professorsError
    return data ?? []
  },
  { server: false, default: () => [] },
)

const activeEvents = computed(
  () => events.value.filter(event => event.status !== 'archived'),
)
const archivedEvents = computed(
  () => events.value.filter(event => event.status === 'archived'),
)
const sourceEvents = computed(
  () => events.value.map(event => ({
    id: event.id,
    name: event.name,
    slug: event.slug,
    status: event.status,
  })),
)
const canConfirmArchive = computed(
  () => Boolean(
    selectedEvent.value
    && confirmedName.value === selectedEvent.value.name
    && archiveSecret.value.length >= 12
    && !archiving.value,
  ),
)

async function createEvent(input: {
  name: string
  slug: string
  professor_id: string
  source_event_id: string | null
  copy_options: Record<string, boolean>
}) {
  if (!isAuthorized.value || !profile.value || creating.value) return

  creating.value = true
  createSlugError.value = null
  createMessage.value = null
  pageError.value = null

  try {
    const draft = {
      name: input.name,
      slug: input.slug,
      professor_id: input.professor_id,
    }
    const { data, error: createError } = input.source_event_id
      ? await $supabase.rpc('duplicate_event_configuration', {
          source_event_id: input.source_event_id,
          draft,
          copy_options: input.copy_options,
        })
      : await $supabase.rpc('create_event_draft', { draft })

    if (createError) throw createError

    const eventId = (data as Array<{ event_id: string }> | null)?.[0]?.event_id
    if (!eventId) throw new Error('missing event id')
    createMessage.value = 'Evento criado como rascunho.'
    await refreshNuxtData(EVENTS_KEY)
    await navigateTo(`/app/evento/${eventId}/admin/conteudo-publico`)
  }
  catch (error: unknown) {
    if ((error as { code?: string }).code === '23505') {
      createSlugError.value = 'Este identificador já está em uso.'
      return
    }
    pageError.value = 'Não foi possível criar o evento.'
  }
  finally {
    creating.value = false
  }
}

function openArchiveDialog(event: EventRow) {
  selectedEvent.value = event
  confirmedName.value = ''
  archiveSecret.value = ''
  copyConfig.value = false
  archiveMessage.value = null
  archiveError.value = null
  archiveDialog.value?.showModal()
}

function closeArchiveDialog() {
  if (archiving.value) return

  archiveSecret.value = ''
  copyConfig.value = false
  archiveError.value = null
  confirmedName.value = ''
  selectedEvent.value = null
  archiveDialog.value?.close()
}

function handleArchiveCancel(event: Event) {
  event.preventDefault()
  closeArchiveDialog()
}

function handleArchiveBackdrop(event: MouseEvent) {
  if (event.target === event.currentTarget) closeArchiveDialog()
}

async function archiveEvent() {
  if (!selectedEvent.value || !canConfirmArchive.value) return

  archiving.value = true
  archiveMessage.value = null
  archiveError.value = null
  pageError.value = null

  try {
    const { data: sessionData, error: sessionError } =
      await $supabase.auth.getSession()
    const accessToken = sessionData.session?.access_token
    if (sessionError || !accessToken) throw new Error('session unavailable')

    await $fetch('/api/admin/archive-event', {
      method: 'POST',
      headers: { Authorization: `Bearer ${accessToken}` },
      body: {
        eventId: selectedEvent.value.id,
        eventName: confirmedName.value,
        archiveSecret: archiveSecret.value,
        copyConfig: copyConfig.value,
      },
    })

    archiveSecret.value = ''
    archiveMessage.value =
      'Evento arquivado e novo rascunho principal criado.'
    archiveDialog.value?.close()
    selectedEvent.value = null
    confirmedName.value = ''
    await refreshNuxtData(EVENTS_KEY)
  }
  catch {
    archiveError.value =
      'Não foi possível arquivar. Confirme o nome, o segredo e faça login novamente.'
  }
  finally {
    archiveSecret.value = ''
    archiving.value = false
  }
}

const updatingStatus = ref<string | null>(null)

async function updateEventStatus(event: EventRow, newStatus: string) {
  if (!isAuthorized.value || !profile.value || updatingStatus.value) return

  updatingStatus.value = event.id
  pageError.value = null

  try {
    const { error: updateError } = await $supabase
      .from('events')
      .update({ status: newStatus as EventRow['status'] })
      .eq('id', event.id)

    if (updateError) throw updateError

    await refreshNuxtData(EVENTS_KEY)
  }
  catch {
    pageError.value = 'Não foi possível atualizar o status do evento.'
  }
  finally {
    updatingStatus.value = null
  }
}
</script>

<template>
  <main class="event-admin-page">
    <header class="event-admin-header">
      <p class="eyebrow">
        Administração geral
      </p>
      <h1>Administração de eventos</h1>
      <p class="intro">
        Crie novos eventos e consulte o histórico sem apagar registros.
      </p>
    </header>

    <p v-if="pageError" class="form-error" role="alert">
      {{ pageError }}
    </p>
    <p v-if="createMessage" class="form-success" role="status">
      {{ createMessage }}
    </p>
    <p v-if="archiveMessage" class="form-success" role="status">
      {{ archiveMessage }}
    </p>

    <p v-if="accessPending || (isAuthorized && pending)" class="event-notice">
      Carregando eventos…
    </p>
    <p v-else-if="accessError || (isAuthorized && error)" class="form-error" role="alert">
      Não foi possível carregar os eventos.
    </p>
    <p v-else-if="!isAuthorized" class="form-error" role="alert">
      Você não tem autorização para administrar eventos.
    </p>

    <template v-else>
      <section class="event-panel" aria-labelledby="create-event-title">
        <h2 id="create-event-title">
          Criar evento
        </h2>
        <EventWizard
          :professors="professors"
          :source-events="sourceEvents"
          :submitting="creating"
          :slug-error="createSlugError"
          @submit="createEvent"
        />
      </section>

      <section class="event-panel" aria-labelledby="active-events-title">
        <h2 id="active-events-title">
          Eventos ativos
        </h2>
        <p v-if="activeEvents.length === 0" class="event-notice">
          Nenhum evento ativo.
        </p>
        <ul v-else class="event-list">
          <li v-for="event in activeEvents" :key="event.id" class="event-card">
            <div>
              <h3>{{ event.name }}</h3>
              <p class="event-status-controls">
                <select 
                  class="status-select"
                  :value="event.status" 
                  @change="updateEventStatus(event, ($event.target as HTMLSelectElement).value)" 
                  :disabled="updatingStatus === event.id"
                >
                  <option value="draft">Rascunho</option>
                  <option value="registration_open">Inscrições abertas</option>
                  <option value="in_progress">Em andamento</option>
                  <option value="evaluation">Avaliação</option>
                  <option value="results_published">Resultados publicados</option>
                </select>
                <span v-if="event.is_featured">Evento principal</span>
              </p>
            </div>
            <button
              v-if="event.is_featured"
              type="button"
              class="danger-button"
              @click="openArchiveDialog(event)"
            >
              Arquivar
            </button>
          </li>
        </ul>
      </section>

      <section class="event-panel" aria-labelledby="archived-events-title">
        <h2 id="archived-events-title">
          Eventos arquivados
        </h2>
        <p v-if="archivedEvents.length === 0" class="event-notice">
          Nenhum evento arquivado.
        </p>
        <ul v-else class="event-list">
          <li v-for="event in archivedEvents" :key="event.id" class="event-card">
            <div>
              <h3>{{ event.name }}</h3>
              <p>Arquivado em {{ event.archived_at }}</p>
            </div>
          </li>
        </ul>
      </section>
    </template>

    <dialog
      ref="archiveDialog"
      class="archive-dialog"
      aria-labelledby="archive-dialog-title"
      @cancel="handleArchiveCancel"
      @click.self="handleArchiveBackdrop"
    >
      <form @submit.prevent="archiveEvent">
        <h2 id="archive-dialog-title">
          Arquivar evento
        </h2>
        <p>
          Esta ação preserva o evento como histórico e cria um novo rascunho
          principal. O evento arquivado não poderá ser alterado.
        </p>
        <p v-if="archiveError" class="form-error" role="alert">
          {{ archiveError }}
        </p>

        <label for="confirmed-event-name">
          Confirme o nome exato do evento
        </label>
        <input
          id="confirmed-event-name"
          v-model="confirmedName"
          name="confirmed-event-name"
          required
          autocomplete="off"
        >
        <p class="field-help">
          Digite: <strong>{{ selectedEvent?.name }}</strong>
        </p>

        <label for="archive-secret">Segredo de arquivamento</label>
        <input
          id="archive-secret"
          v-model="archiveSecret"
          name="archive-secret"
          type="password"
          minlength="12"
          required
          autocomplete="off"
        >

        <label class="checkbox-field">
          <input
            id="copy-config"
            v-model="copyConfig"
            type="checkbox"
            name="copy-config"
          >
          Copiar programação, critérios e modelos de Canvas
        </label>

        <div class="dialog-actions">
          <button
            type="button"
            class="secondary-button"
            :disabled="archiving"
            @click="closeArchiveDialog"
          >
            Cancelar
          </button>
          <button type="submit" class="danger-button" :disabled="!canConfirmArchive">
            {{ archiving ? 'Arquivando…' : 'Confirmar arquivamento' }}
          </button>
        </div>
      </form>
    </dialog>
  </main>
</template>

<style scoped>
.event-admin-page {
  margin: 0 auto;
  max-width: 72rem;
  min-height: 100vh;
  padding: 3rem 1.5rem;
}
.event-admin-header {
  max-width: 42rem;
}
.event-admin-header h1 {
  font-size: clamp(2rem, 5vw, 3.25rem);
  margin: 0;
}
.event-panel {
  background: #111827;
  border: 1px solid #334155;
  border-radius: 1rem;
  margin-top: 1.5rem;
  padding: 1.5rem;
}
.event-panel h2 {
  margin-top: 0;
}
.event-form,
.archive-dialog form {
  display: grid;
  gap: .65rem;
}
.event-form {
  max-width: 34rem;
}
.event-form input:not([type="checkbox"]),
.archive-dialog input {
  background: #0f172a;
  border: 1px solid #64748b;
  border-radius: .5rem;
  color: #f8fafc;
  min-height: 2.75rem;
  padding: .65rem .75rem;
}
.event-form button,
.event-card button,
.archive-dialog button {
  background: #0369a1;
  border: 0;
  border-radius: .5rem;
  color: #fff;
  cursor: pointer;
  font-weight: 700;
  min-height: 2.75rem;
  padding: .65rem 1rem;
}
.checkbox-field {
  align-items: center;
  display: flex;
  gap: .6rem;
  margin: .5rem 0;
}
.event-notice {
  color: #cbd5e1;
}
.event-list {
  display: grid;
  gap: .75rem;
  list-style: none;
  margin: 0;
  padding: 0;
}
.event-card {
  align-items: center;
  border: 1px solid #334155;
  border-radius: .75rem;
  display: flex;
  gap: 1rem;
  justify-content: space-between;
  padding: 1rem;
}
.event-card h3 {
  margin: 0 0 .35rem;
}
.event-card p {
  color: #cbd5e1;
  display: flex;
  flex-wrap: wrap;
  gap: .75rem;
  margin: 0;
}
.danger-button {
  background: #991b1b !important;
}
.archive-dialog {
  background: #111827;
  border: 1px solid #64748b;
  border-radius: 1rem;
  color: #f8fafc;
  max-width: 34rem;
  padding: 1.5rem;
  width: calc(100% - 2rem);
}
.archive-dialog::backdrop {
  background: #020617d9;
}
.dialog-actions {
  display: flex;
  gap: .75rem;
  justify-content: flex-end;
  margin-top: 1rem;
}
.secondary-button {
  background: transparent !important;
  border: 1px solid #64748b !important;
}
button:disabled {
  cursor: wait;
  opacity: .65;
}
.status-select {
  background: #0f172a;
  border: 1px solid #64748b;
  border-radius: .25rem;
  color: #f8fafc;
  padding: .25rem .5rem;
  font-size: .875rem;
}
.status-select:disabled {
  opacity: 0.5;
  cursor: wait;
}
@media (max-width: 36rem) {
  .event-card,
  .dialog-actions {
    align-items: stretch;
    flex-direction: column;
  }
}
</style>
