<script setup lang="ts">
import { computed, reactive, ref } from 'vue'
import type { PublicScheduleItem } from '../../../../../data/ceitec-public-content'
import { ceitecPublicContent } from '../../../../../data/ceitec-public-content'
import { publicContentRpcError } from '../../../../../utils/public-content-rpc-error'

definePageMeta({ middleware: 'auth' })

type EditorContent = {
  tagline: string
  presentation: string
  objectives: string[]
  venue: string
  dateLabel: string
  registrationOpen: boolean
  schedule: EditorScheduleItem[]
}

type EditorScheduleItem = PublicScheduleItem & { clientKey: string }

type EditorRow = {
  tagline: string
  presentation: string
  objectives: string[]
  venue: string
  date_label: string
  registration_open: boolean
  schedule: PublicScheduleItem[]
}

const route = useRoute()
const eventId = computed(() => String(route.params.eventId ?? ''))
const { eventRoles, pending: accessPending } = useCurrentAccess()
const { $supabase } = useNuxtApp()
const saving = ref(false)
const feedback = ref('')
const validationErrors = ref<string[]>([])
let nextScheduleRowKey = 0
const withClientKey = (item: PublicScheduleItem): EditorScheduleItem => ({
  ...item,
  clientKey: `schedule-row-${++nextScheduleRowKey}`,
})
const canEdit = computed(() => eventRoles.value.some(role => (
  role.event_id === eventId.value && role.role === 'professor'
)))

const form = reactive<EditorContent>({
  tagline: ceitecPublicContent.tagline,
  presentation: ceitecPublicContent.presentation,
  objectives: [...ceitecPublicContent.objectives],
  venue: ceitecPublicContent.venue,
  dateLabel: ceitecPublicContent.date_label,
  registrationOpen: ceitecPublicContent.registration_open,
  schedule: ceitecPublicContent.schedule.map(withClientKey),
})

const { data, pending, error } = await useAsyncData(
  `public-content-editor:${eventId.value}`,
  async () => {
    const { data: rows, error: rpcError } = await $supabase.rpc(
      'get_event_public_content_for_edit',
      { target_event: eventId.value },
    )
    if (rpcError) throw rpcError
    return (rows?.[0] ?? null) as EditorRow | null
  },
)

if (data.value) {
  form.tagline = data.value.tagline
  form.presentation = data.value.presentation
  form.objectives = [...data.value.objectives]
  form.venue = data.value.venue
  form.dateLabel = data.value.date_label
  form.registrationOpen = data.value.registration_open
  form.schedule = data.value.schedule.map(withClientKey)
}

const dayItems = (dayNumber: 1 | 2) => form.schedule
  .filter(item => item.dayNumber === dayNumber)
  .sort((a, b) => a.position - b.position)

function addObjective() {
  form.objectives.push('')
}

function removeObjective(index: number) {
  if (form.objectives.length > 1) form.objectives.splice(index, 1)
}

function addScheduleRow(dayNumber: 1 | 2) {
  const items = dayItems(dayNumber)
  form.schedule.push({
    dayNumber,
    startsAt: '08:00',
    activity: '',
    position: Math.max(0, ...items.map(item => item.position)) + 1,
    clientKey: `schedule-row-${++nextScheduleRowKey}`,
  })
}

function removeScheduleRow(item: EditorScheduleItem) {
  const index = form.schedule.indexOf(item)
  if (index >= 0) form.schedule.splice(index, 1)
}

function validate() {
  const errors = new Set<string>()
  const objectives = form.objectives.map(value => value.trim()).filter(Boolean)
  if (!objectives.length) errors.add('Informe ao menos um objetivo.')

  for (const item of form.schedule) {
    const timeIsValid = /^(?:[01]\d|2[0-3]):[0-5]\d$/.test(item.startsAt)
    if (!timeIsValid) errors.add('Use um horário válido no formato HH:MM.')
    const activityLength = item.activity.trim().length
    if (activityLength < 2 || activityLength > 180) {
      errors.add('Cada atividade deve ter entre 2 e 180 caracteres.')
    }
    if (!Number.isInteger(item.position) || item.position <= 0) {
      errors.add('Use posições positivas para a programação.')
    }
  }
  if (!dayItems(1).length || !dayItems(2).length) {
    errors.add('Inclua ao menos uma atividade em cada dia.')
  }
  for (const dayNumber of [1, 2] as const) {
    const positions = dayItems(dayNumber).map(item => item.position)
    if (new Set(positions).size !== positions.length) {
      errors.add('Use posições únicas em cada dia.')
    }
  }

  validationErrors.value = [...errors]
  return !errors.size
}

async function save() {
  if (saving.value || !canEdit.value || !validate()) return
  saving.value = true
  feedback.value = ''

  const content = {
    tagline: form.tagline.trim(),
    presentation: form.presentation.trim(),
    objectives: form.objectives.map(value => value.trim()).filter(Boolean),
    venue: form.venue.trim(),
    dateLabel: form.dateLabel.trim(),
    registrationOpen: form.registrationOpen,
    schedule: [...form.schedule]
      .sort((a, b) => a.dayNumber - b.dayNumber || a.position - b.position)
      .map(item => ({
        dayNumber: item.dayNumber,
        startsAt: item.startsAt,
        activity: item.activity.trim(),
        position: Number(item.position),
      })),
  }

  try {
    const { error: rpcError } = await $supabase.rpc('save_event_public_content', {
      target_event: eventId.value,
      content,
    })
    if (rpcError) throw rpcError
    feedback.value = 'Conteúdo público salvo com sucesso.'
  }
  catch (caught) {
    feedback.value = publicContentRpcError(caught)
  }
  finally {
    saving.value = false
  }
}
</script>

<template>
  <main class="public-content-page">
    <header class="editor-header">
      <p class="eyebrow">Administração do evento</p>
      <h1>Conteúdo público</h1>
      <p class="intro">Atualize a apresentação e a programação exibidas na landing page.</p>
    </header>

    <p v-if="accessPending || pending" role="status">Carregando conteúdo…</p>
    <p v-else-if="error" class="form-error" role="alert">
      Não foi possível carregar o conteúdo deste evento.
    </p>
    <p v-else-if="!canEdit" class="form-error" role="alert">
      Você não tem permissão para editar o conteúdo deste evento.
    </p>

    <form v-else class="public-content-form" @submit.prevent="save">
      <label for="tagline">Frase principal</label>
      <input id="tagline" v-model="form.tagline" required minlength="2" maxlength="180">

      <label for="presentation">Apresentação</label>
      <textarea id="presentation" v-model="form.presentation" required rows="7" maxlength="4000" />

      <fieldset>
        <legend>Objetivos</legend>
        <div v-for="(_objective, index) in form.objectives" :key="index" class="editor-row">
          <label class="sr-only" :for="`objective-${index}`">Objetivo {{ index + 1 }}</label>
          <input :id="`objective-${index}`" v-model="form.objectives[index]" data-objective maxlength="240">
          <button type="button" class="danger-outline" @click="removeObjective(index)">Remover</button>
        </div>
        <button type="button" class="secondary-button" @click="addObjective">Adicionar objetivo</button>
      </fieldset>

      <div class="editor-columns">
        <div>
          <label for="venue">Local</label>
          <input id="venue" v-model="form.venue" required maxlength="240">
        </div>
        <div>
          <label for="date-label">Data exibida</label>
          <input id="date-label" v-model="form.dateLabel" required maxlength="120">
        </div>
      </div>

      <label class="checkbox-row">
        <input v-model="form.registrationOpen" type="checkbox">
        Inscrições abertas
      </label>

      <fieldset v-for="dayNumber in [1, 2] as const" :key="dayNumber" :data-day="dayNumber">
        <legend>Programação do Dia {{ dayNumber }}</legend>
        <div
          v-for="item in dayItems(dayNumber)"
          :key="item.clientKey"
          class="schedule-editor-row"
          data-schedule-row
          :data-row-key="item.clientKey"
        >
          <label>
            <span>Horário</span>
            <input v-model="item.startsAt" data-schedule-time inputmode="numeric" placeholder="HH:MM">
          </label>
          <label>
            <span>Atividade</span>
            <textarea v-model="item.activity" rows="2" maxlength="180" />
          </label>
          <label>
            <span>Posição</span>
            <input v-model.number="item.position" type="number" min="1" step="1">
          </label>
          <button type="button" data-remove-row class="danger-outline" @click="removeScheduleRow(item)">
            Remover
          </button>
        </div>
        <button type="button" class="secondary-button" @click="addScheduleRow(dayNumber)">
          Adicionar atividade
        </button>
      </fieldset>

      <ul v-if="validationErrors.length" class="form-error" role="alert">
        <li v-for="message in validationErrors" :key="message">{{ message }}</li>
      </ul>
      <p
        v-if="feedback"
        :class="feedback.includes('sucesso') ? 'form-success' : 'form-error'"
        :role="feedback.includes('sucesso') ? 'status' : 'alert'"
      >
        {{ feedback }}
      </p>

      <button type="submit" :disabled="saving">
        {{ saving ? 'Salvando…' : 'Salvar conteúdo público' }}
      </button>
    </form>
  </main>
</template>
