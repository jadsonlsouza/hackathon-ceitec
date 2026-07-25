<script setup lang="ts">
import CanvasBlockEditor from '../../../../../components/canvas/CanvasBlockEditor.vue'
import { useEventRealtime } from '../../../../../composables/useEventRealtime'
import type { AutosaveState } from '../../../../../composables/useAutosave'
import { canvasRpcErrorMessage } from '../../../../../utils/canvas-rpc-error'

definePageMeta({ middleware: 'auth' })

interface CanvasBlock {
  id: string
  title: string
  prompt: string
  position: number
  max_items: number | null
}

interface Activity {
  id: string
  event_id: string
  title: string
  instructions: string
  opens_at: string
  due_at: string
  published: boolean
  allow_resubmission: boolean
  categories: ('junior' | 'senior')[]
  blocks: CanvasBlock[]
}

interface Team {
  id: string
  event_id: string
  status: 'pending' | 'approved' | 'rejected'
  category: 'junior' | 'senior'
}

interface Submission {
  id: string
  event_id: string
  activity_id: string
  team_id: string
  status: 'draft' | 'submitted' | 'in_review' | 'returned' | 'resubmitted' | 'approved'
  revision: number
}

interface Answer {
  submission_id: string
  block_id: string
  content: { text?: string } | null
  version: number
}

interface SubmissionReview {
  id: string
  submission_id: string
  decision: 'approved' | 'returned' | 'reopened'
  feedback: string | null
  created_at: string
}

const route = useRoute()
const eventId = computed(() => String(route.params.eventId))
const activityId = computed(() => String(route.params.activityId))
const { $supabase } = useNuxtApp()
const { profile } = useCurrentAccess()
const submitting = ref(false)
const actionError = ref<string | null>(null)
const successMessage = ref<string | null>(null)
const remoteUpdateAvailable = ref(false)
const blockStates = ref<Record<string, AutosaveState>>({})
const blockResetKeys = ref<Record<string, number>>({})

function activityPageKey(targetEventId: string, targetActivityId: string) {
  return `canvas-activity:${targetEventId}:${targetActivityId}`
}

async function loadAnswers(submissionId: string) {
  const { data, error } = await $supabase
    .from('submission_answers')
    .select('*')
    .eq('submission_id', submissionId)
  if (error) throw error
  return (data ?? []) as Answer[]
}

async function loadReviews(submissionId: string) {
  const { data, error } = await $supabase
    .from('submission_reviews')
    .select('id,submission_id,decision,feedback,created_at')
    .eq('submission_id', submissionId)
    .order('created_at', { ascending: false })
    .limit(10)
  if (error) throw error
  return (data ?? []) as SubmissionReview[]
}

const dataKey = computed(() => activityPageKey(eventId.value, activityId.value))
const { data: pageData, pending, error } = await useAsyncData(
  dataKey,
  async () => {
    const { data: teamData, error: teamError } = await $supabase
      .from('teams')
      .select('*')
      .eq('event_id', eventId.value)
      .maybeSingle()
    if (teamError) throw teamError

    const { data: activityData, error: activityError } = await $supabase
      .from('canvas_activities')
      .select('*, blocks:canvas_blocks(*)')
      .eq('event_id', eventId.value)
      .eq('id', activityId.value)
      .maybeSingle()
    if (activityError) throw activityError
    if (!activityData) {
      return {
        team: teamData as Team | null,
        activity: null,
        submission: null,
        answers: [] as Answer[],
        reviews: [] as SubmissionReview[],
      }
    }

    let { data: submissionData, error: submissionError } = await $supabase
      .from('submissions')
      .select('*')
      .eq('event_id', eventId.value)
      .eq('activity_id', activityId.value)
      .eq('team_id', teamData?.id ?? '')
      .maybeSingle()
    if (submissionError) throw submissionError

    if (!submissionData && teamData) {
      const created = await $supabase
        .from('submissions')
        .insert({
          event_id: eventId.value,
          activity_id: activityId.value,
          team_id: teamData.id,
        })
        .select('*')
        .single()
      if (created.error) throw created.error
      submissionData = created.data
    }

    const answers = submissionData ? await loadAnswers(submissionData.id) : []
    const reviews = submissionData ? await loadReviews(submissionData.id) : []
    return {
      team: teamData as Team | null,
      activity: {
        ...activityData,
        blocks: [...(activityData.blocks ?? [])].sort((a, b) => a.position - b.position),
      } as Activity,
      submission: submissionData as Submission | null,
      answers,
      reviews,
    }
  },
  {
    server: false,
    watch: [eventId, activityId],
    default: () => ({
      team: null,
      activity: null,
      submission: null,
      answers: [] as Answer[],
      reviews: [] as SubmissionReview[],
    }),
  },
)

const activity = computed(() => pageData.value.activity)
const team = computed(() => pageData.value.team)
const submission = computed(() => pageData.value.submission)
const answersByBlock = computed(() => new Map(pageData.value.answers.map(answer => [answer.block_id, answer])))
const latestReview = computed(() => (
  [...pageData.value.reviews].sort((a, b) => (
    new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
  ))[0] ?? null
))
const isOpen = computed(() => {
  if (!activity.value) return false
  const now = Date.now()
  return activity.value.published
    && now >= new Date(activity.value.opens_at).getTime()
    && now <= new Date(activity.value.due_at).getTime()
})
const isEditable = computed(() => (
  isOpen.value && ['draft', 'returned', 'submitted', 'resubmitted'].includes(submission.value?.status ?? '')
))
const hasPendingSave = computed(() => (
  Object.values(blockStates.value).some(state => state !== 'saved')
))
const canSubmit = computed(() => (
  Boolean(
    submission.value
    && isOpen.value
    && isEditable.value
    && !hasPendingSave.value
    && !submitting.value,
  )
))

function submissionStatusLabel(status: Submission['status']) {
  return {
    draft: 'Rascunho',
    submitted: 'Enviado',
    in_review: 'Em validação',
    returned: 'Devolvido para ajustes',
    resubmitted: 'Reenviado',
    approved: 'Aprovado',
  }[status]
}

function handleBlockState(blockId: string, state: AutosaveState) {
  if (!(blockId in blockStates.value) && state === 'idle') {
    blockStates.value = { ...blockStates.value, [blockId]: 'saved' }
    return
  }
  blockStates.value = { ...blockStates.value, [blockId]: state }
}

async function reloadAnswer(blockId: string) {
  if (!submission.value) return
  try {
    const { data: remoteAnswer, error: answerError } = await $supabase
      .from('submission_answers')
      .select('*')
      .eq('submission_id', submission.value.id)
      .eq('block_id', blockId)
      .maybeSingle()
    if (answerError) throw answerError

    const answers = pageData.value.answers.filter(answer => answer.block_id !== blockId)
    if (remoteAnswer) answers.push(remoteAnswer as Answer)
    pageData.value = { ...pageData.value, answers }

    const otherPending = Object.entries(blockStates.value).some(([currentBlockId, state]) => (
      currentBlockId !== blockId && state !== 'saved'
    ))
    const nextStates = { ...blockStates.value }
    delete nextStates[blockId]
    blockStates.value = nextStates
    blockResetKeys.value = {
      ...blockResetKeys.value,
      [blockId]: (blockResetKeys.value[blockId] ?? 0) + 1,
    }
    remoteUpdateAvailable.value = otherPending
  }
  catch {
    actionError.value = 'Não foi possível carregar a versão mais recente.'
  }
}

async function handleRealtimeChange(payload: unknown) {
  const change = payload && typeof payload === 'object'
    ? payload as { table?: string, new?: Record<string, unknown> }
    : {}
  if (
    change.table === 'submissions'
    && submission.value
    && change.new?.id === submission.value.id
  ) {
    pageData.value = {
      ...pageData.value,
      submission: { ...submission.value, ...change.new } as Submission,
    }
    try {
      const reviews = await loadReviews(submission.value.id)
      pageData.value = { ...pageData.value, reviews }
    }
    catch {
      actionError.value = 'O status foi atualizado, mas o feedback ainda não pôde ser carregado.'
    }
    return
  }
  if (
    change.table === 'submission_answers'
    && change.new?.updated_by === profile.value?.id
  ) return
  if (hasPendingSave.value) {
    remoteUpdateAvailable.value = true
    return
  }
  if (!submission.value) return
  try {
    const answers = await loadAnswers(submission.value.id)
    pageData.value = { ...pageData.value, answers }
  }
  catch {
    remoteUpdateAvailable.value = true
  }
}

const realtimeTargets = computed(() => {
  if (!submission.value) return []
  return [
    { table: 'submissions', filter: `event_id=eq.${eventId.value}` },
    { table: 'submission_answers', filter: `submission_id=eq.${submission.value.id}` },
  ]
})
useEventRealtime(eventId, realtimeTargets, handleRealtimeChange)

async function submitCanvas() {
  if (!canSubmit.value || submitting.value || !submission.value) return
  submitting.value = true
  actionError.value = null
  successMessage.value = null
  try {
    const { data, error: submitError } = await $supabase.rpc('submit_canvas', {
      submission_id: submission.value.id,
    })
    if (submitError) {
      actionError.value = canvasRpcErrorMessage(submitError)
      return
    }
    pageData.value = {
      ...pageData.value,
      submission: { ...submission.value, ...(data ?? {}), status: data?.status ?? 'submitted' },
    }
    successMessage.value = 'Canvas enviado para validação.'
  }
  catch (submitError: unknown) {
    actionError.value = canvasRpcErrorMessage(submitError)
  }
  finally {
    submitting.value = false
  }
}
</script>

<template>
  <main class="canvas-page">
    <p v-if="pending" class="request-status">Carregando Canvas…</p>
    <p v-else-if="error" class="form-error" role="alert">Não foi possível carregar esta atividade.</p>
    <p v-else-if="!activity || !submission || !team" class="request-status">Esta atividade não está disponível para sua equipe.</p>
    <template v-else>
      <header class="canvas-header">
        <p class="eyebrow">Atividade colaborativa</p>
        <h1>{{ activity.title }}</h1>
        <p class="intro">{{ activity.instructions }}</p>
        <p class="canvas-meta">
          Status: {{ submissionStatusLabel(submission.status) }} · Prazo:
          <time :datetime="activity.due_at">{{ new Date(activity.due_at).toLocaleString('pt-BR') }}</time>
        </p>
      </header>

      <p v-if="remoteUpdateAvailable" class="conflict-banner" data-remote-update role="status">
        Há uma atualização de outra pessoa. Conclua ou recarregue seus blocos antes de sincronizar.
      </p>
      <p v-if="!isOpen" class="request-status">A atividade está fora do período de edição.</p>
      <p v-if="actionError" class="form-error" role="alert">{{ actionError }}</p>
      <p v-if="successMessage" class="form-success" role="status">{{ successMessage }}</p>
      <section v-if="latestReview" class="review-feedback" aria-labelledby="latest-review-title">
        <h2 id="latest-review-title">Última validação</h2>
        <p v-if="latestReview.feedback">{{ latestReview.feedback }}</p>
        <p v-else-if="latestReview.decision === 'approved'">Aprovado sem feedback adicional.</p>
        <p v-else class="field-help">A validação não incluiu feedback.</p>
      </section>

      <section class="canvas-block-list" aria-label="Blocos do Canvas">
        <CanvasBlockEditor
          v-for="block in activity.blocks"
          :key="`${block.id}:${blockResetKeys[block.id] ?? 0}`"
          :block="block"
          :submission-id="submission.id"
          :initial-content="answersByBlock.get(block.id)?.content ?? null"
          :initial-version="answersByBlock.get(block.id)?.version ?? 0"
          :editable="isEditable"
          @state-change="handleBlockState"
          @reload-latest="reloadAnswer"
        />
      </section>

      <footer class="canvas-submit-bar">
        <p v-if="hasPendingSave" class="field-help">Aguarde todos os blocos terminarem de salvar.</p>
        <button
          type="button"
          data-action="submit-canvas"
          :disabled="!canSubmit"
          @click="submitCanvas"
        >
          {{ submitting ? 'Enviando…' : (['submitted', 'resubmitted'].includes(submission.status) ? 'Atualizar Envio' : 'Enviar Canvas para validação') }}
        </button>
      </footer>
    </template>
  </main>
</template>
