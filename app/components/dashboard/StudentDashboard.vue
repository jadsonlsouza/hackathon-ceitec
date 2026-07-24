<script setup lang="ts">
const props = defineProps<{
  eventId: string
}>()

const { $supabase } = useNuxtApp()
const supabase = $supabase as any

// ── Types ─────────────────────────────────────────────────────────────────────

interface CanvasItem {
  activity_id: string
  activity_title: string
  due_at: string
  submission_status: 'draft' | 'submitted' | 'in_review' | 'returned' | 'resubmitted' | 'approved' | 'no_submission'
  last_review_decision: 'approved' | 'returned' | 'reopened' | null
  last_review_feedback: string | null
  last_review_at: string | null
}

interface EvaluationInfo {
  required_evaluator_count: number
  completed_evaluator_count: number
  complete: boolean
  next_position?: number
}

interface StudentDashboardData {
  event: { slug: string, status: string } | null
  team: { id: string, name: string, category: 'junior' | 'senior', status: string } | null
  slot: { position: number } | null
  canvas: CanvasItem[]
  evaluation: EvaluationInfo | null
}

// ── Data ─────────────────────────────────────────────────────────────────────

const dataKey = computed(() => `student-dashboard:${props.eventId}`)
const { data, pending, error } = await useAsyncData(
  dataKey,
  async (): Promise<StudentDashboardData> => {
    const { data: result, error: rpcError } = await supabase.rpc(
      'get_student_dashboard',
      { target_event: props.eventId },
    )
    if (rpcError) throw rpcError
    return result as StudentDashboardData
  },
  {
    server: false,
    watch: [() => props.eventId],
    default: (): StudentDashboardData => ({
      event: null, team: null, slot: null, canvas: [], evaluation: null,
    }),
  },
)

// ── Helpers ───────────────────────────────────────────────────────────────────

const expandedFeedback = ref<Set<string>>(new Set())
function toggleFeedback(id: string) {
  const next = new Set(expandedFeedback.value)
  if (next.has(id)) next.delete(id)
  else next.add(id)
  expandedFeedback.value = next
}

function statusLabel(status: CanvasItem['submission_status']) {
  return {
    no_submission: 'Não iniciado',
    draft: 'Rascunho',
    submitted: 'Enviado',
    in_review: 'Em revisão',
    returned: 'Devolvido',
    resubmitted: 'Reenviado',
    approved: 'Aprovado',
  }[status] ?? status
}

function statusClass(status: CanvasItem['submission_status']) {
  return {
    no_submission: 'chip--gray',
    draft: 'chip--gray',
    submitted: 'chip--blue',
    in_review: 'chip--yellow',
    returned: 'chip--red',
    resubmitted: 'chip--blue',
    approved: 'chip--green',
  }[status] ?? 'chip--gray'
}

function categoryLabel(cat: 'junior' | 'senior') {
  return cat === 'junior' ? 'Júnior' : 'Sênior'
}

function formatDate(iso: string) {
  return new Date(iso).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' })
}

const evalProgress = computed(() => {
  const ev = data.value.evaluation
  if (!ev) return null
  const pct = ev.required_evaluator_count > 0
    ? Math.round((ev.completed_evaluator_count / ev.required_evaluator_count) * 100)
    : 0
  return { ...ev, pct }
})
</script>

<template>
  <div class="student-dashboard" aria-label="Painel do aluno">
    <!-- Loading / error -->
    <p v-if="pending" class="request-status">Carregando seu painel…</p>
    <p v-else-if="error" class="form-error" role="alert">Não foi possível carregar o painel.</p>

    <template v-else-if="data.team">
      <!-- ── Header de Resultados ────────────────────────────────────────────── -->
      <div v-if="data.event?.status === 'results_published'" class="sd-results-banner">
        <div>
          <h2>Resultados oficiais publicados!</h2>
          <p>Confira a classificação final da sua categoria.</p>
        </div>
        <NuxtLink :to="`/resultados/${data.event.slug}`" class="primary-button" target="_blank">
          Ver Classificação Oficial
        </NuxtLink>
      </div>

      <!-- ── Header da equipe ──────────────────────────────────────────────── -->
      <section class="sd-section sd-team-banner" aria-labelledby="sd-team-title">
        <div class="sd-team-info">
          <p class="eyebrow">Sua equipe</p>
          <h2 id="sd-team-title">{{ data.team.name }}</h2>
          <p class="sd-team-meta">
            Categoria {{ categoryLabel(data.team.category) }}
            <span class="sd-dot">·</span>
            <span :class="['chip', data.team.status === 'approved' ? 'chip--green' : data.team.status === 'rejected' ? 'chip--red' : 'chip--yellow']">
              {{ data.team.status === 'approved' ? 'Aprovada' : data.team.status === 'rejected' ? 'Recusada' : 'Aguardando validação' }}
            </span>
          </p>
        </div>
      </section>

      <div class="sd-columns">
        <!-- ── Coluna esquerda ──────────────────────────────────────────────── -->
        <div class="sd-col">

          <!-- Ordem de apresentação -->
          <section class="sd-section" aria-labelledby="sd-slot-title">
            <h3 id="sd-slot-title" class="sd-section-title">
              <span class="sd-section-icon" aria-hidden="true">🎤</span>
              Ordem de apresentação
            </h3>
            <div v-if="data.slot" class="sd-slot-card">
              <p class="sd-slot-label">Posição na fila de pitches</p>
              <p class="sd-slot-number">{{ data.slot.position }}</p>
            </div>
            <p v-else class="sd-empty">A ordem de apresentação ainda não foi definida.</p>
          </section>

          <!-- Status de avaliação -->
          <section class="sd-section" aria-labelledby="sd-eval-title">
            <h3 id="sd-eval-title" class="sd-section-title">
              <span class="sd-section-icon" aria-hidden="true">⭐</span>
              Avaliação do pitch
            </h3>
            <div v-if="evalProgress">
              <div class="sd-eval-header">
                <span>{{ evalProgress.completed_evaluator_count }} de {{ evalProgress.required_evaluator_count }} avaliadores</span>
                <span v-if="evalProgress.complete" class="chip chip--green">Avaliação completa ✓</span>
              </div>
              <div class="sd-progress-bar" role="progressbar" :aria-valuenow="evalProgress.completed_evaluator_count" :aria-valuemax="evalProgress.required_evaluator_count">
                <div class="sd-progress-fill" :style="{ width: evalProgress.pct + '%' }" />
              </div>
              <p v-if="!evalProgress.complete && evalProgress.next_position" class="sd-next-queue">
                <span class="sd-next-icon" aria-hidden="true">→</span>
                Próxima equipe a ser avaliada: <strong>posição {{ evalProgress.next_position }}</strong>
              </p>
              <p v-else-if="!evalProgress.complete" class="sd-empty">Avaliação em andamento…</p>
            </div>
            <p v-else class="sd-empty">Avaliações ainda não foram iniciadas para sua equipe.</p>
          </section>

        </div>

        <!-- ── Coluna direita — Canvas ─────────────────────────────────────── -->
        <div class="sd-col">
          <section class="sd-section" aria-labelledby="sd-canvas-title">
            <h3 id="sd-canvas-title" class="sd-section-title">
              <span class="sd-section-icon" aria-hidden="true">📋</span>
              Atividades Canvas
            </h3>

            <p v-if="data.canvas.length === 0" class="sd-empty">Nenhuma atividade publicada para sua categoria.</p>

            <ul v-else class="sd-canvas-list">
              <li v-for="item in data.canvas" :key="item.activity_id" class="sd-canvas-card">
                <div class="sd-canvas-header">
                  <div class="sd-canvas-info">
                    <p class="sd-canvas-title">{{ item.activity_title }}</p>
                    <p class="sd-canvas-due">Prazo: {{ formatDate(item.due_at) }}</p>
                  </div>
                  <span :class="['chip', statusClass(item.submission_status)]">
                    {{ statusLabel(item.submission_status) }}
                  </span>
                </div>

                <!-- Feedback da revisão -->
                <div v-if="item.last_review_decision" class="sd-review-block">
                  <button
                    type="button"
                    class="sd-review-toggle"
                    :aria-expanded="expandedFeedback.has(item.activity_id)"
                    @click="toggleFeedback(item.activity_id)"
                  >
                    <span>
                      {{ item.last_review_decision === 'approved' ? '✓ Aprovado' : item.last_review_decision === 'returned' ? '↩ Devolvido para ajustes' : '↺ Reaberto' }}
                      · {{ formatDate(item.last_review_at!) }}
                    </span>
                    <span aria-hidden="true">{{ expandedFeedback.has(item.activity_id) ? '▲' : '▼' }}</span>
                  </button>
                  <div v-if="expandedFeedback.has(item.activity_id)" class="sd-review-body">
                    <p v-if="item.last_review_feedback">{{ item.last_review_feedback }}</p>
                    <p v-else class="sd-empty">Sem feedback textual nesta revisão.</p>
                  </div>
                </div>

                <NuxtLink
                  :to="`/app/evento/${eventId}/atividades/${item.activity_id}`"
                  class="sd-canvas-link"
                >
                  Abrir atividade →
                </NuxtLink>
              </li>
            </ul>
          </section>
        </div>
      </div>
    </template>

    <p v-else class="sd-empty">Você ainda não pertence a uma equipe neste evento.</p>
  </div>
</template>
