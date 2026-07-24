<script setup lang="ts">
import { evaluationRpcErrorMessage } from '../../../../../utils/evaluation-rpc-error'

definePageMeta({ middleware: 'auth' })

type Category = 'junior' | 'senior'

interface Criterion {
  id: string
  event_id: string
  name: string
  description: string
  position: number
  active: boolean
}

interface Weight {
  event_id: string
  criterion_id: string
  category: Category
  weight: number
}

interface Assignment {
  event_id: string
  evaluator_id: string
  category: Category
}

interface EvaluatorRole {
  event_id: string
  user_id: string
  role: 'evaluator'
  profile?: { display_name: string } | null
}

interface Team {
  id: string
  event_id: string
  category: Category
  status: 'approved'
}

interface Evaluation {
  id: string
  event_id: string
  category: Category
  team_id: string
  evaluator_id: string
}

interface Freeze {
  event_id: string
  category: Category
  evaluator_snapshot: Array<{ evaluator_id: string }>
  team_snapshot: Array<{ team_id: string }>
}

const categories: Category[] = ['junior', 'senior']
const route = useRoute()
const eventId = computed(() => String(route.params.eventId))
const { $supabase } = useNuxtApp()
const supabase = $supabase as any
const {
  eventRoles,
  pending: accessPending,
  error: accessError,
} = useCurrentAccess()
const criterionName = ref('')
const criterionDescription = ref('')
const criterionDrafts = ref<Record<
  string,
  { name: string, description: string, active: boolean }
>>({})
const processingAction = ref<string | null>(null)
const actionError = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const isProfessor = computed(() => 
  profile.value?.global_role === 'global_admin' ||
  eventRoles.value.some(role => (
    role.event_id === eventId.value && role.role === 'professor'
  ))
)

function evaluationAdminKey(targetEventId: string) {
  return `evaluation-admin:${targetEventId}`
}

const adminKey = computed(() => evaluationAdminKey(eventId.value))
const {
  data: source,
  pending,
  error,
  refresh: refreshAdmin,
} = await useAsyncData(
  adminKey,
  async () => {
    if (!isProfessor.value) {
      return {
        criteria: [] as Criterion[],
        weights: [] as Weight[],
        assignments: [] as Assignment[],
        evaluatorRoles: [] as EvaluatorRole[],
        teams: [] as Team[],
        evaluations: [] as Evaluation[],
        freezes: [] as Freeze[],
      }
    }

    const [
      criteria,
      weights,
      assignments,
      evaluatorRoles,
      teams,
      evaluations,
      freezes,
    ] = await Promise.all([
      supabase
        .from('evaluation_criteria')
        .select('id,event_id,name,description,position,active')
        .eq('event_id', eventId.value)
        .order('position'),
      supabase
        .from('criterion_weights')
        .select('event_id,criterion_id,category,weight')
        .eq('event_id', eventId.value),
      supabase
        .from('evaluator_assignments')
        .select('event_id,evaluator_id,category')
        .eq('event_id', eventId.value),
      supabase
        .from('event_roles')
        .select('event_id,user_id,role,profile:profiles!event_roles_user_id_fkey(display_name)')
        .eq('event_id', eventId.value)
        .eq('role', 'evaluator'),
      supabase
        .from('teams')
        .select('id,event_id,category,status')
        .eq('event_id', eventId.value)
        .eq('status', 'approved'),
      supabase
        .from('evaluations')
        .select('id,event_id,category,team_id,evaluator_id')
        .eq('event_id', eventId.value),
      supabase
        .from('evaluation_freezes')
        .select('event_id,category,evaluator_snapshot,team_snapshot')
        .eq('event_id', eventId.value),
    ])

    const failure = [
      criteria.error,
      weights.error,
      assignments.error,
      evaluatorRoles.error,
      teams.error,
      evaluations.error,
      freezes.error,
    ].find(Boolean)
    if (failure) throw failure

    return {
      criteria: (criteria.data ?? []) as Criterion[],
      weights: (weights.data ?? []) as Weight[],
      assignments: (assignments.data ?? []) as Assignment[],
      evaluatorRoles: (evaluatorRoles.data ?? []) as EvaluatorRole[],
      teams: (teams.data ?? []) as Team[],
      evaluations: (evaluations.data ?? []) as Evaluation[],
      freezes: (freezes.data ?? []) as Freeze[],
    }
  },
  {
    server: false,
    watch: [eventId, eventRoles],
    default: () => ({
      criteria: [] as Criterion[],
      weights: [] as Weight[],
      assignments: [] as Assignment[],
      evaluatorRoles: [] as EvaluatorRole[],
      teams: [] as Team[],
      evaluations: [] as Evaluation[],
      freezes: [] as Freeze[],
    }),
  },
)

watch(
  () => source.value.criteria,
  (criteria) => {
    for (const criterion of criteria) {
      if (criterionDrafts.value[criterion.id]) continue
      criterionDrafts.value[criterion.id] = {
        name: criterion.name,
        description: criterion.description,
        active: criterion.active,
      }
    }
  },
  { immediate: true },
)

function categoryLabel(category: Category) {
  return category === 'junior' ? 'Júnior' : 'Sênior'
}

function frozenCategory(category: Category) {
  return source.value.freezes.find(freeze => freeze.category === category)
}

function weightFor(criterionId: string, category: Category) {
  return source.value.weights.find(weight => (
    weight.criterion_id === criterionId && weight.category === category
  ))?.weight ?? 1
}

function isAssigned(evaluatorId: string, category: Category) {
  return source.value.assignments.some(assignment => (
    assignment.evaluator_id === evaluatorId
    && assignment.category === category
  ))
}

function progress(category: Category) {
  const approvedTeams = source.value.teams.filter(
    team => team.category === category,
  )
  const frozen = frozenCategory(category)
  const frozenTeamIds = new Set(
    frozen?.team_snapshot.map(team => team.team_id) ?? [],
  )
  const frozenEvaluatorIds = new Set(
    frozen?.evaluator_snapshot.map(evaluator => evaluator.evaluator_id) ?? [],
  )
  const teamCount = frozen?.team_snapshot.length ?? approvedTeams.length
  const evaluatorCount = frozen?.evaluator_snapshot.length ?? 0
  return {
    teams: teamCount,
    frozen: Boolean(frozen),
    completed: source.value.evaluations.filter(
      evaluation => (
        evaluation.category === category
        && frozenTeamIds.has(evaluation.team_id)
        && frozenEvaluatorIds.has(evaluation.evaluator_id)
      ),
    ).length,
    required: teamCount * evaluatorCount,
  }
}

function clearMessages() {
  actionError.value = null
  successMessage.value = null
}

async function refreshData() {
  await refreshAdmin()
  await refreshNuxtData(evaluationAdminKey(eventId.value))
}

async function createCriterion() {
  if (!isProfessor.value || processingAction.value) return
  const name = criterionName.value.trim()
  if (!name) {
    actionError.value = 'Informe o nome do critério.'
    return
  }

  processingAction.value = 'create-criterion'
  clearMessages()
  try {
    const { error: createError } = await supabase
      .from('evaluation_criteria')
      .insert({
        event_id: eventId.value,
        name,
        description: criterionDescription.value.trim(),
        position: Math.max(0, ...source.value.criteria.map(
          criterion => criterion.position,
        )) + 1,
        active: true,
      })
    if (createError) throw createError
    criterionName.value = ''
    criterionDescription.value = ''
    successMessage.value = 'Critério criado.'
    await refreshData()
  }
  catch (createError: unknown) {
    actionError.value = evaluationRpcErrorMessage(
      createError,
      'Não foi possível criar o critério.',
    )
  }
  finally {
    processingAction.value = null
  }
}

async function saveCriterion(criterionId: string) {
  const action = `criterion:${criterionId}`
  const draft = criterionDrafts.value[criterionId]
  if (
    !isProfessor.value
    || processingAction.value
    || source.value.freezes.length > 0
    || !draft
  ) return

  const name = draft.name.trim()
  if (!name) {
    actionError.value = 'Informe o nome do critério.'
    return
  }

  processingAction.value = action
  clearMessages()
  try {
    const { error: updateError } = await supabase
      .from('evaluation_criteria')
      .update({
        name,
        description: draft.description.trim(),
        active: draft.active,
      })
      .eq('event_id', eventId.value)
      .eq('id', criterionId)
    if (updateError) throw updateError
    successMessage.value = 'Critério atualizado.'
    await refreshData()
  }
  catch (updateError: unknown) {
    actionError.value = evaluationRpcErrorMessage(
      updateError,
      'Não foi possível atualizar o critério.',
    )
  }
  finally {
    processingAction.value = null
  }
}

async function saveWeight(
  criterionId: string,
  category: Category,
  rawValue: string,
) {
  const action = `weight:${category}:${criterionId}`
  if (!isProfessor.value || processingAction.value) return
  const value = Number(rawValue)
  if (!Number.isFinite(value) || value < 0) {
    actionError.value = 'Informe um peso igual ou maior que zero.'
    return
  }

  processingAction.value = action
  clearMessages()
  try {
    const { error: weightError } = await supabase
      .from('criterion_weights')
      .update({ weight: value })
      .eq('event_id', eventId.value)
      .eq('criterion_id', criterionId)
      .eq('category', category)
    if (weightError) throw weightError
    successMessage.value = `Peso da categoria ${categoryLabel(category)} atualizado.`
    await refreshData()
  }
  catch (weightError: unknown) {
    actionError.value = evaluationRpcErrorMessage(
      weightError,
      'Não foi possível atualizar o peso.',
    )
  }
  finally {
    processingAction.value = null
  }
}

async function toggleAssignment(
  evaluatorId: string,
  category: Category,
  assign: boolean,
) {
  const action = `assignment:${category}:${evaluatorId}`
  if (!isProfessor.value || processingAction.value) return
  processingAction.value = action
  clearMessages()
  try {
    const request = assign
      ? supabase.from('evaluator_assignments').insert({
          event_id: eventId.value,
          evaluator_id: evaluatorId,
          category,
        })
      : supabase
          .from('evaluator_assignments')
          .delete()
          .eq('event_id', eventId.value)
          .eq('evaluator_id', evaluatorId)
          .eq('category', category)
    const { error: assignmentError } = await request
    if (assignmentError) throw assignmentError
    successMessage.value = 'Designação atualizada.'
    await refreshData()
  }
  catch (assignmentError: unknown) {
    actionError.value = evaluationRpcErrorMessage(
      assignmentError,
      'Não foi possível atualizar a designação.',
    )
  }
  finally {
    processingAction.value = null
  }
}

async function shuffle(category: Category) {
  const action = `shuffle:${category}`
  if (!isProfessor.value || processingAction.value) return
  processingAction.value = action
  clearMessages()
  try {
    const { error: shuffleError } = await supabase.rpc(
      'shuffle_presentations',
      { event_id: eventId.value, category },
    )
    if (shuffleError) throw shuffleError
    successMessage.value = `Ordem ${categoryLabel(category)} sorteada.`
    await refreshData()
  }
  catch (shuffleError: unknown) {
    actionError.value = evaluationRpcErrorMessage(
      shuffleError,
      'Não foi possível sortear a ordem de apresentação.',
    )
  }
  finally {
    processingAction.value = null
  }
}

async function freeze(category: Category) {
  const action = `freeze:${category}`
  if (!isProfessor.value || processingAction.value) return
  processingAction.value = action
  clearMessages()
  try {
    const { error: freezeError } = await supabase.rpc('freeze_evaluation', {
      event_id: eventId.value,
      category,
    })
    if (freezeError) throw freezeError
    successMessage.value = `Configuração ${categoryLabel(category)} congelada.`
    await refreshData()
  }
  catch (freezeError: unknown) {
    actionError.value = evaluationRpcErrorMessage(
      freezeError,
      'Não foi possível congelar a configuração.',
    )
  }
  finally {
    processingAction.value = null
  }
}
</script>

<template>
  <main class="evaluation-page evaluation-admin-page">
    <header class="evaluation-header">
      <p class="eyebrow">Professor</p>
      <h1>Configuração da avaliação</h1>
      <p class="intro">
        Configure critérios e pesos, designe todos os Avaliadores por categoria,
        sorteie a ordem e congele os dados.
      </p>
    </header>

    <p v-if="accessPending || (isProfessor && pending)" class="request-status">
      Carregando configuração…
    </p>
    <p v-else-if="accessError || (isProfessor && error)" class="form-error" role="alert">
      Não foi possível carregar a configuração da avaliação: {{ error?.message || error }}
    </p>
    <p v-else-if="!isProfessor" class="form-error" role="alert">
      Somente o Professor responsável pode gerenciar esta avaliação.
    </p>

    <template v-else>
      <p v-if="actionError" class="form-error" role="alert">
        {{ actionError }}
      </p>
      <p v-if="successMessage" class="form-success" role="status">
        {{ successMessage }}
      </p>

      <section class="evaluation-config-section">
        <h2>Critérios e pesos</h2>
        <form class="criterion-form" @submit.prevent="createCriterion">
          <label for="criterion-name">Novo critério</label>
          <input id="criterion-name" v-model="criterionName">
          <label for="criterion-description">Descrição</label>
          <textarea
            id="criterion-description"
            v-model="criterionDescription"
            rows="2"
          />
          <button
            type="submit"
            :disabled="processingAction !== null"
          >
            Adicionar critério
          </button>
        </form>

        <p v-if="source.criteria.length === 0" class="request-status">
          Nenhum critério cadastrado.
        </p>
        <ul v-else class="criteria-list">
          <li v-for="criterion in source.criteria" :key="criterion.id">
            <div v-if="criterionDrafts[criterion.id]" class="criterion-editor">
              <label
                class="sr-only"
                :for="`criterion-edit-name-${criterion.id}`"
              >
                Nome do critério
              </label>
              <input
                :id="`criterion-edit-name-${criterion.id}`"
                v-model="criterionDrafts[criterion.id].name"
                :disabled="processingAction !== null"
              >
              <label
                class="sr-only"
                :for="`criterion-edit-description-${criterion.id}`"
              >
                Descrição do critério
              </label>
              <textarea
                :id="`criterion-edit-description-${criterion.id}`"
                v-model="criterionDrafts[criterion.id].description"
                rows="2"
                :disabled="processingAction !== null"
              />
              <label>
                <input
                  v-model="criterionDrafts[criterion.id].active"
                  type="checkbox"
                  :disabled="processingAction !== null"
                >
                Critério ativo
              </label>
              <button
                type="button"
                :data-action="`save-criterion-${criterion.id}`"
                :disabled="processingAction !== null"
                @click="saveCriterion(criterion.id)"
              >
                {{ processingAction === `criterion:${criterion.id}`
                  ? 'Salvando…'
                  : 'Salvar critério' }}
              </button>
            </div>
            <label
              v-for="category in categories"
              :key="category"
              :for="`weight-${criterion.id}-${category}`"
            >
              {{ categoryLabel(category) }}
              <span>Peso {{ weightFor(criterion.id, category) }}</span>
              <input
                :id="`weight-${criterion.id}-${category}`"
                type="number"
                min="0"
                step="0.01"
                :value="weightFor(criterion.id, category)"
                :disabled="processingAction !== null"
                @change="saveWeight(
                  criterion.id,
                  category,
                  ($event.target as HTMLInputElement).value,
                )"
              >
            </label>
          </li>
        </ul>
      </section>

      <section class="evaluation-config-section">
        <h2>Avaliadores por categoria</h2>
        <p v-if="source.evaluatorRoles.length === 0" class="request-status">
          Nenhum perfil de Avaliador ativo neste evento.
        </p>
        <div v-else class="assignment-grid">
          <fieldset v-for="category in categories" :key="category">
            <legend>{{ categoryLabel(category) }}</legend>
            <label
              v-for="evaluator in source.evaluatorRoles"
              :key="evaluator.user_id"
            >
              <input
                type="checkbox"
                :checked="isAssigned(evaluator.user_id, category)"
                :disabled="processingAction !== null"
                @change="toggleAssignment(
                  evaluator.user_id,
                  category,
                  ($event.target as HTMLInputElement).checked,
                )"
              >
              {{ evaluator.profile?.display_name || 'Avaliador' }}
            </label>
          </fieldset>
        </div>
      </section>

      <section class="category-workflow" aria-label="Fluxo por categoria">
        <article
          v-for="category in categories"
          :key="category"
          class="category-workflow-card"
        >
          <p class="eyebrow">Categoria {{ categoryLabel(category) }}</p>
          <h2>Ordem, congelamento e progresso</h2>
          <div :data-progress="category" class="evaluation-progress">
            <p v-if="progress(category).teams === 0">
              Nenhuma equipe aprovada nesta categoria.
            </p>
            <p v-else-if="!progress(category).frozen">
              Configuração ainda não congelada.
            </p>
            <p v-else>
              {{ progress(category).completed }} de
              {{ progress(category).required }} avaliações concluídas
            </p>
          </div>
          <div class="workflow-actions">
            <button
              type="button"
              :data-action="`shuffle-${category}`"
              :disabled="processingAction !== null"
              @click="shuffle(category)"
            >
              {{ processingAction === `shuffle:${category}`
                ? 'Randomizando…'
                : 'Randomizar ordem' }}
            </button>
          </div>
        </article>
      </section>
    </template>
  </main>
</template>
