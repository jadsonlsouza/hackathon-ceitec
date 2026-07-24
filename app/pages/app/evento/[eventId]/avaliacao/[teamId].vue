<script setup lang="ts">
import ScoreCriterion from '../../../../../components/evaluation/ScoreCriterion.vue'
import { evaluationRpcErrorMessage } from '../../../../../utils/evaluation-rpc-error'

definePageMeta({ middleware: 'auth' })

type Category = 'junior' | 'senior'

interface FrozenCriterion {
  criterion_id: string
  name: string
  description: string
  position: number
  weight: number
}

interface FrozenTeam {
  team_id: string
  name: string
  category: Category
  canvas_summary: unknown
}

interface Freeze {
  event_id: string
  category: Category
  criteria_snapshot: FrozenCriterion[]
  evaluator_snapshot: Array<{ evaluator_id: string, display_name: string }>
  team_snapshot: FrozenTeam[]
}

interface Slot {
  event_id: string
  category: Category
  team_id: string
  position: number
}

interface Evaluation {
  event_id: string
  category: Category
  team_id: string
  evaluator_id: string
  submitted_at: string
}

const route = useRoute()
const eventId = computed(() => String(route.params.eventId))
const teamId = computed(() => String(route.params.teamId))
const { $supabase } = useNuxtApp()
const supabase = $supabase as any
const {
  profile,
  eventRoles,
  pending: accessPending,
  error: accessError,
} = useCurrentAccess()
const scores = ref<Record<string, number>>({})
const comment = ref('')
const submitting = ref(false)
const formError = ref<string | null>(null)

const isEvaluator = computed(() => eventRoles.value.some(role => (
  role.event_id === eventId.value && role.role === 'evaluator'
)))

function evaluationFormKey(targetEventId: string, targetTeamId: string) {
  return `evaluation-form:${targetEventId}:${targetTeamId}`
}

const formKey = computed(() => evaluationFormKey(
  eventId.value,
  teamId.value,
))
const { data: source, pending, error } = await useAsyncData(
  formKey,
  async () => {
    if (!isEvaluator.value || !profile.value) {
      return {
        assignments: [] as Array<{ category: Category }>,
        freezes: [] as Freeze[],
        slots: [] as Slot[],
        evaluations: [] as Evaluation[],
      }
    }

    const [assignments, freezes, slots, evaluations] = await Promise.all([
      supabase
        .from('evaluator_assignments')
        .select('event_id,evaluator_id,category')
        .eq('event_id', eventId.value)
        .eq('evaluator_id', profile.value.id),
      supabase
        .from('evaluation_freezes')
        .select('event_id,category,criteria_snapshot,evaluator_snapshot,team_snapshot')
        .eq('event_id', eventId.value),
      supabase
        .from('presentation_slots')
        .select('event_id,category,team_id,position')
        .eq('event_id', eventId.value)
        .order('position'),
      supabase
        .from('evaluations')
        .select('event_id,category,team_id,evaluator_id,submitted_at')
        .eq('event_id', eventId.value)
        .eq('evaluator_id', profile.value.id),
    ])

    const failure = [
      assignments.error,
      freezes.error,
      slots.error,
      evaluations.error,
    ].find(Boolean)
    if (failure) throw failure

    return {
      assignments: (assignments.data ?? []) as Array<{ category: Category }>,
      freezes: (freezes.data ?? []) as Freeze[],
      slots: (slots.data ?? []) as Slot[],
      evaluations: (evaluations.data ?? []) as Evaluation[],
    }
  },
  {
    server: false,
    watch: [eventId, teamId, eventRoles, profile],
    default: () => ({
      assignments: [] as Array<{ category: Category }>,
      freezes: [] as Freeze[],
      slots: [] as Slot[],
      evaluations: [] as Evaluation[],
    }),
  },
)

const presentation = computed(() => {
  const evaluatorId = profile.value?.id
  const slot = source.value.slots.find(item => item.team_id === teamId.value)
  if (!slot || !evaluatorId) return null
  if (!source.value.assignments.some(item => item.category === slot.category)) {
    return null
  }

  const frozen = source.value.freezes.find(item => (
    item.category === slot.category
    && item.evaluator_snapshot.some(
      evaluator => evaluator.evaluator_id === evaluatorId,
    )
  ))
  const team = frozen?.team_snapshot.find(item => item.team_id === teamId.value)
  if (!frozen || !team) return null

  return {
    slot,
    frozen,
    team,
    criteria: [...frozen.criteria_snapshot].sort(
      (left, right) => left.position - right.position,
    ),
    submitted: source.value.evaluations.some(
      evaluation => evaluation.team_id === teamId.value,
    ),
  }
})

const summaryText = computed(() => {
  const values: string[] = []
  function collect(value: unknown) {
    if (typeof value === 'string' && value.trim()) {
      values.push(value.trim())
    }
    else if (Array.isArray(value)) {
      value.forEach(collect)
    }
    else if (value && typeof value === 'object') {
      Object.values(value).forEach(collect)
    }
  }
  collect(presentation.value?.team.canvas_summary)
  return values.join(' · ')
})

function categoryLabel(category: Category) {
  return category === 'junior' ? 'Júnior' : 'Sênior'
}

function updateScore(criterionId: string, value: number) {
  scores.value = { ...scores.value, [criterionId]: value }
  formError.value = null
}

async function submitEvaluation() {
  if (!isEvaluator.value || submitting.value || !presentation.value) return
  const payloadScores = presentation.value.criteria.map(criterion => ({
    criterion_id: criterion.criterion_id,
    score: scores.value[criterion.criterion_id],
  }))
  if (payloadScores.some(score => !score.score)) {
    formError.value = 'Informe uma nota para todos os critérios.'
    await nextTick()
    document
      .querySelector<HTMLButtonElement>(
        '.evaluation-form [role="radio"][tabindex="0"]',
      )
      ?.focus()
    return
  }

  submitting.value = true
  formError.value = null
  try {
    const { error: submitError } = await supabase.rpc('submit_evaluation', {
      team_id: teamId.value,
      scores: payloadScores,
      comment: comment.value.trim() || null,
    })
    if (submitError) {
      formError.value = evaluationRpcErrorMessage(
        submitError,
        'Não foi possível salvar a avaliação. Seus dados continuam nesta tela.',
      )
      return
    }

    const completed = new Set(
      source.value.evaluations.map(evaluation => evaluation.team_id),
    )
    completed.add(teamId.value)
    const frozenTeamIds = new Set(
      presentation.value.frozen.team_snapshot.map(team => team.team_id),
    )
    const next = source.value.slots
      .filter(slot => (
        slot.category === presentation.value?.slot.category
        && frozenTeamIds.has(slot.team_id)
        && slot.position > (presentation.value?.slot.position ?? 0)
        && !completed.has(slot.team_id)
      ))
      .sort((left, right) => left.position - right.position)[0]

    await navigateTo(
      next
        ? `/app/evento/${eventId.value}/avaliacao/${next.team_id}`
        : `/app/evento/${eventId.value}/avaliacao`,
    )
  }
  catch (submitError: unknown) {
    formError.value = evaluationRpcErrorMessage(
      submitError,
      'Não foi possível salvar a avaliação. Seus dados continuam nesta tela.',
    )
  }
  finally {
    submitting.value = false
  }
}
</script>

<template>
  <main class="evaluation-page evaluation-form-page">
    <header class="evaluation-header">
      <p class="eyebrow">Avaliador</p>
      <h1>Avaliar apresentação</h1>
      <p class="intro">
        As notas usam os critérios e pesos congelados pelo Professor.
      </p>
    </header>

    <p v-if="accessPending || (isEvaluator && pending)" class="request-status">
      Carregando apresentação…
    </p>
    <p
      v-else-if="accessError || (isEvaluator && error)"
      class="form-error"
      role="alert"
    >
      Não foi possível carregar esta apresentação.
    </p>
    <p v-else-if="!isEvaluator" class="form-error" role="alert">
      É necessário possuir um perfil de Avaliador ativo neste evento.
    </p>
    <p v-else-if="!presentation" class="form-error" role="alert">
      Esta equipe não pertence à sua ordem de avaliação congelada.
    </p>

    <template v-else>
      <section class="presentation-summary">
        <p class="team-position">
          Posição {{ presentation.slot.position }} · Categoria
          {{ categoryLabel(presentation.team.category) }}
        </p>
        <h2>{{ presentation.team.name }}</h2>
        <p v-if="presentation.submitted" class="form-success" role="status">
          Avaliação já enviada. Um novo envio substituirá suas notas anteriores.
        </p>
        <h3>Resumo do Canvas aprovado</h3>
        <p>{{ summaryText || 'A equipe não possui resumo aprovado disponível.' }}</p>
      </section>

      <p v-if="formError" class="form-error" role="alert">
        {{ formError }}
      </p>

      <form class="evaluation-form" novalidate @submit.prevent="submitEvaluation">
        <ScoreCriterion
          v-for="criterion in presentation.criteria"
          :key="criterion.criterion_id"
          :criterion-id="criterion.criterion_id"
          :name="criterion.name"
          :description="criterion.description"
          :model-value="scores[criterion.criterion_id]"
          @update:model-value="updateScore(criterion.criterion_id, $event)"
        />

        <label for="evaluation-comment">Comentário opcional</label>
        <textarea
          id="evaluation-comment"
          v-model="comment"
          rows="5"
          maxlength="4000"
        />
        <button type="submit" :disabled="submitting">
          {{ submitting ? 'Salvando…' : 'Salvar avaliação' }}
        </button>
      </form>
    </template>
  </main>
</template>
