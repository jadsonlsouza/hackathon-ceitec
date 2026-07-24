<script setup lang="ts">
import ScoreCriterion from '../../../../../components/evaluation/ScoreCriterion.vue'
import { evaluationRpcErrorMessage } from '../../../../../utils/evaluation-rpc-error'

definePageMeta({ middleware: 'auth' })

type Category = 'junior' | 'senior'

interface Criterion {
  id: string
  name: string
  description: string
  position: number
}

interface Weight {
  criterion_id: string
  weight: number
}

interface Team {
  id: string
  name: string
  category: Category
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
        teams: [] as Team[],
        slots: [] as Slot[],
        evaluations: [] as Evaluation[],
        criteria: [] as Criterion[],
        weights: [] as Weight[],
      }
    }

    const [assignments, teams, slots, evaluations, criteria, weights] = await Promise.all([
      supabase
        .from('evaluator_assignments')
        .select('event_id,evaluator_id,category')
        .eq('event_id', eventId.value)
        .eq('evaluator_id', profile.value.id),
      supabase
        .from('teams')
        .select('id,name,category')
        .eq('event_id', eventId.value)
        .eq('status', 'approved'),
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
      supabase
        .from('evaluation_criteria')
        .select('id,name,description,position')
        .eq('event_id', eventId.value)
        .eq('active', true),
      supabase
        .from('criterion_weights')
        .select('criterion_id,category,weight')
        .eq('event_id', eventId.value),
    ])

    const failure = [
      assignments.error,
      teams.error,
      slots.error,
      evaluations.error,
      criteria.error,
      weights.error,
    ].find(Boolean)
    if (failure) throw failure

    return {
      assignments: (assignments.data ?? []) as Array<{ category: Category }>,
      teams: (teams.data ?? []) as Team[],
      slots: (slots.data ?? []) as Slot[],
      evaluations: (evaluations.data ?? []) as Evaluation[],
      criteria: (criteria.data ?? []) as Criterion[],
      weights: (weights.data ?? []) as Weight[],
    }
  },
  {
    server: false,
    watch: [eventId, teamId, eventRoles, profile],
    default: () => ({
      assignments: [] as Array<{ category: Category }>,
      teams: [] as Team[],
      slots: [] as Slot[],
      evaluations: [] as Evaluation[],
      criteria: [] as Criterion[],
      weights: [] as Weight[],
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

  const team = source.value.teams.find(item => item.id === teamId.value)
  if (!team) return null

  const categoryWeights = new Set(
    source.value.weights
      .filter(w => w.category === team.category)
      .map(w => w.criterion_id),
  )

  const activeCriteria = source.value.criteria
    .filter(c => categoryWeights.has(c.id))
    .sort((left, right) => left.position - right.position)
    .map(c => ({
      criterion_id: c.id,
      name: c.name,
      description: c.description,
      position: c.position,
    }))

  return {
    slot,
    team,
    criteria: activeCriteria,
    submitted: source.value.evaluations.some(
      evaluation => evaluation.team_id === teamId.value,
    ),
  }
})

const queueNavigation = computed(() => {
  if (!presentation.value) return { prev: null, next: null }
  
  const categorySlots = source.value.slots
    .filter(s => s.category === presentation.value!.slot.category)
    .sort((a, b) => a.position - b.position)
    
  const currentIndex = categorySlots.findIndex(s => s.team_id === teamId.value)
  
  return {
    prev: currentIndex > 0 ? categorySlots[currentIndex - 1] : null,
    next: currentIndex >= 0 && currentIndex < categorySlots.length - 1 ? categorySlots[currentIndex + 1] : null,
  }
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
    score: scores.value[criterion.criterion_id] || 0,
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

    if (queueNavigation.value.next) {
      await navigateTo(`/app/evento/${eventId.value}/avaliacao/${queueNavigation.value.next.team_id}`)
    } else {
      await navigateTo(`/app/evento/${eventId.value}/avaliacao`)
    }
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
        Dê suas notas com base nos critérios estabelecidos.
      </p>
    </header>

    <div class="evaluation-navigation-actions" style="margin-bottom: 2rem; display: flex; gap: 1rem;">
      <NuxtLink
        :to="`/app/evento/${eventId}/avaliacao`"
        class="nav-button list-button"
        style="padding: 0.5rem 1rem; border: 1px solid currentColor; border-radius: 4px; text-decoration: none;"
      >
        Ver lista de equipes
      </NuxtLink>
      <div style="margin-left: auto; display: flex; gap: 0.5rem;">
        <NuxtLink
          v-if="queueNavigation.prev"
          :to="`/app/evento/${eventId}/avaliacao/${queueNavigation.prev.team_id}`"
          class="nav-button prev-button"
          style="padding: 0.5rem 1rem; border: 1px solid currentColor; border-radius: 4px; text-decoration: none;"
        >
          Anterior
        </NuxtLink>
        <NuxtLink
          v-if="queueNavigation.next"
          :to="`/app/evento/${eventId}/avaliacao/${queueNavigation.next.team_id}`"
          class="nav-button next-button"
          style="padding: 0.5rem 1rem; border: 1px solid currentColor; border-radius: 4px; text-decoration: none;"
        >
          Próximo
        </NuxtLink>
      </div>
    </div>

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
      Esta equipe não pertence à sua ordem de avaliação ou não possui uma posição definida.
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
          {{ submitting ? 'Salvando…' : 'Salvar avaliação e ir para o próximo' }}
        </button>
      </form>
    </template>
  </main>
</template>
