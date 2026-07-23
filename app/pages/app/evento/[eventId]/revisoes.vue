<script setup lang="ts">
import SubmissionReview from '../../../../components/reviews/SubmissionReview.vue'
import { useEventRealtime } from '../../../../composables/useEventRealtime'
import { canvasRpcErrorMessage } from '../../../../utils/canvas-rpc-error'

definePageMeta({ middleware: 'auth' })

interface ReviewItem {
  id: string
  event_id: string
  status: 'submitted' | 'resubmitted' | 'in_review'
  revision: number
  team: { id: string, name: string, category: 'junior' | 'senior' }
  activity: { id: string, title: string }
  revisions: Array<{ revision: number, snapshot: { answers?: Array<Record<string, unknown>> } }>
}

const route = useRoute()
const eventId = computed(() => String(route.params.eventId))
const { $supabase } = useNuxtApp()
const { eventRoles, pending: accessPending, error: accessError } = useCurrentAccess()
const categoryFilter = ref<'all' | 'junior' | 'senior'>('all')
const statusFilter = ref<'all' | 'submitted' | 'resubmitted' | 'in_review'>('all')
const processingId = ref<string | null>(null)
const selected = ref<ReviewItem | null>(null)
const actionError = ref<string | null>(null)

const isReviewer = computed(() => eventRoles.value.some(role => (
  role.event_id === eventId.value && ['professor', 'monitor'].includes(role.role)
)))

function reviewsPageKey(targetEventId: string) {
  return `canvas-reviews:${targetEventId}`
}

const queueKey = computed(() => reviewsPageKey(eventId.value))
const { data: submissions, pending, error } = await useAsyncData(
  queueKey,
  async () => {
    if (!isReviewer.value) return []
    const { data, error: queueError } = await $supabase
      .from('submissions')
      .select('*, team:teams(id,name,category), activity:canvas_activities(id,title), revisions:submission_revisions(revision,snapshot)')
      .eq('event_id', eventId.value)
      .in('status', ['submitted', 'resubmitted', 'in_review'])
      .order('submitted_at')
    if (queueError) throw queueError
    return (data ?? []) as ReviewItem[]
  },
  {
    server: false,
    watch: [eventId, eventRoles],
    default: () => [] as ReviewItem[],
  },
)

const filteredSubmissions = computed(() => submissions.value.filter(item => (
  (categoryFilter.value === 'all' || item.team.category === categoryFilter.value)
  && (statusFilter.value === 'all' || item.status === statusFilter.value)
)))
const selectedRevision = computed(() => {
  if (!selected.value) return null
  return selected.value.revisions.find(revision => revision.revision === selected.value?.revision)
    ?? [...selected.value.revisions].sort((a, b) => b.revision - a.revision)[0]
    ?? null
})

async function claim(item: ReviewItem) {
  if (!isReviewer.value || processingId.value) return
  processingId.value = item.id
  actionError.value = null
  try {
    const { error: claimError } = await $supabase.rpc('claim_review', {
      submission_id: item.id,
    })
    if (claimError) {
      actionError.value = canvasRpcErrorMessage(claimError, 'Não foi possível assumir esta revisão.')
      return
    }
    item.status = 'in_review'
    selected.value = item
  }
  catch (claimError: unknown) {
    actionError.value = canvasRpcErrorMessage(claimError, 'Não foi possível assumir esta revisão.')
  }
  finally {
    processingId.value = null
  }
}

async function handleDecision() {
  selected.value = null
  await refreshNuxtData(reviewsPageKey(eventId.value))
}

useEventRealtime(eventId, computed(() => (
  isReviewer.value
    ? [{ table: 'submissions', filter: `event_id=eq.${eventId.value}` }]
    : []
)), () => {
  if (!processingId.value && !selected.value) void refreshNuxtData(reviewsPageKey(eventId.value))
})
</script>

<template>
  <main class="reviews-page">
    <header class="reviews-header">
      <p class="eyebrow">Professor e Monitor</p>
      <h1>Fila de validação dos Canvas</h1>
      <p class="intro">Assuma um envio antes de decidir. O feedback é opcional.</p>
    </header>

    <p v-if="accessPending || (isReviewer && pending)" class="request-status">Carregando revisões…</p>
    <p v-else-if="accessError || (isReviewer && error)" class="form-error" role="alert">Não foi possível carregar as revisões.</p>
    <p v-else-if="!isReviewer" class="form-error" role="alert">Você não possui acesso à revisão deste evento.</p>
    <template v-else>
      <p v-if="actionError" class="form-error" role="alert">{{ actionError }}</p>
      <div class="review-filters">
        <label for="review-category-filter">Categoria</label>
        <select id="review-category-filter" v-model="categoryFilter">
          <option value="all">Todas</option>
          <option value="junior">Júnior</option>
          <option value="senior">Sênior</option>
        </select>
        <label for="review-status-filter">Status</label>
        <select id="review-status-filter" v-model="statusFilter">
          <option value="all">Todos</option>
          <option value="submitted">Enviado</option>
          <option value="resubmitted">Reenviado</option>
          <option value="in_review">Em revisão</option>
        </select>
      </div>

      <p v-if="filteredSubmissions.length === 0" class="request-status">Nenhum envio corresponde aos filtros.</p>
      <ul v-else class="request-list">
        <li v-for="item in filteredSubmissions" :key="item.id" class="request-card">
          <div>
            <h2>{{ item.team.name }}</h2>
            <p>{{ item.activity.title }} · {{ item.team.category === 'junior' ? 'Júnior' : 'Sênior' }} · {{ item.status }}</p>
          </div>
          <div class="request-actions">
            <button
              v-if="selected?.id !== item.id"
              type="button"
              data-action="claim-review"
              :disabled="processingId !== null"
              @click="claim(item)"
            >
              {{ processingId === item.id ? 'Assumindo…' : 'Assumir revisão' }}
            </button>
          </div>
        </li>
      </ul>

      <SubmissionReview
        v-if="selected && selectedRevision"
        :submission-id="selected.id"
        :revision="selectedRevision.revision"
        :snapshot="selectedRevision.snapshot"
        @decided="handleDecision"
      />
    </template>
  </main>
</template>
