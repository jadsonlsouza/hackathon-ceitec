<script setup lang="ts">
definePageMeta({ middleware: 'auth' })

type Category = 'junior' | 'senior'

interface Assignment {
  event_id: string
  evaluator_id: string
  category: Category
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

interface QueueItem {
  teamId: string
  name: string
  position: number
  submitted: boolean
}

interface CategoryQueue {
  category: Category
  completed: number
  required: number
  items: QueueItem[]
  current: QueueItem | null
  next: QueueItem | null
}

const route = useRoute()
const eventId = computed(() => String(route.params.eventId))
const { $supabase } = useNuxtApp()
const supabase = $supabase as any
const {
  profile,
  eventRoles,
  pending: accessPending,
  error: accessError,
} = useCurrentAccess()

const isEvaluator = computed(() => eventRoles.value.some(role => (
  role.event_id === eventId.value && role.role === 'evaluator'
)))

function evaluationQueueKey(targetEventId: string) {
  return `evaluation-queue:${targetEventId}`
}

const queueKey = computed(() => evaluationQueueKey(eventId.value))
const { data: queueSource, pending, error } = await useAsyncData(
  queueKey,
  async () => {
    if (!isEvaluator.value || !profile.value) {
      return {
        assignments: [] as Assignment[],
        teams: [] as Team[],
        slots: [] as Slot[],
        evaluations: [] as Evaluation[],
      }
    }

    const [assignments, teams, slots, evaluations] = await Promise.all([
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
    ])

    const failure = [
      assignments.error,
      teams.error,
      slots.error,
      evaluations.error,
    ].find(Boolean)
    if (failure) throw failure

    return {
      assignments: (assignments.data ?? []) as Assignment[],
      teams: (teams.data ?? []) as Team[],
      slots: (slots.data ?? []) as Slot[],
      evaluations: (evaluations.data ?? []) as Evaluation[],
    }
  },
  {
    server: false,
    watch: [eventId, eventRoles, profile],
    default: () => ({
      assignments: [] as Assignment[],
      teams: [] as Team[],
      slots: [] as Slot[],
      evaluations: [] as Evaluation[],
    }),
  },
)

const queues = computed<CategoryQueue[]>(() => {
  const evaluatorId = profile.value?.id
  if (!evaluatorId) return []

  return queueSource.value.assignments.flatMap((assignment) => {
    const categoryTeams = queueSource.value.teams.filter(t => t.category === assignment.category)
    if (categoryTeams.length === 0) return []

    const teamsMap = new Map(
      categoryTeams.map(team => [team.id, team]),
    )
    const completedIds = new Set(
      queueSource.value.evaluations
        .filter(evaluation => evaluation.category === assignment.category)
        .map(evaluation => evaluation.team_id),
    )
    const items = queueSource.value.slots
      .filter(slot => (
        slot.category === assignment.category && teamsMap.has(slot.team_id)
      ))
      .sort((left, right) => left.position - right.position)
      .map((slot): QueueItem => ({
        teamId: slot.team_id,
        name: teamsMap.get(slot.team_id)?.name ?? 'Equipe',
        position: slot.position,
        submitted: completedIds.has(slot.team_id),
      }))
    const currentIndex = items.findIndex(item => !item.submitted)

    return [{
      category: assignment.category,
      completed: items.filter(item => item.submitted).length,
      required: items.length,
      items,
      current: currentIndex >= 0 ? items[currentIndex] : null,
      next: currentIndex >= 0
        ? items.slice(currentIndex + 1).find(item => !item.submitted) ?? null
        : null,
    }]
  })
})

function categoryLabel(category: Category) {
  return category === 'junior' ? 'Júnior' : 'Sênior'
}

function evaluationPath(teamId: string) {
  return `/app/evento/${eventId.value}/avaliacao/${teamId}`
}
</script>

<template>
  <main class="evaluation-page">
    <header class="evaluation-header">
      <p class="eyebrow">Avaliador</p>
      <h1>Fila de avaliação</h1>
      <p class="intro">
        Siga a ordem de apresentação congelada e envie uma avaliação por
        equipe.
      </p>
    </header>

    <p v-if="accessPending || (isEvaluator && pending)" class="request-status">
      Carregando fila…
    </p>
    <p
      v-else-if="accessError || (isEvaluator && error)"
      class="form-error"
      role="alert"
    >
      Não foi possível carregar a fila de avaliação.
    </p>
    <p v-else-if="!isEvaluator" class="form-error" role="alert">
      É necessário possuir um perfil de Avaliador ativo neste evento.
    </p>
    <p v-else-if="queues.length === 0" class="request-status">
      Nenhuma categoria congelada foi designada para você.
    </p>

    <section
      v-for="queue in queues"
      v-else
      :key="queue.category"
      class="evaluation-category"
      :aria-labelledby="`queue-${queue.category}`"
    >
      <header>
        <div>
          <p class="eyebrow">Categoria {{ categoryLabel(queue.category) }}</p>
          <h2 :id="`queue-${queue.category}`">
            {{ queue.completed }} de {{ queue.required }} avaliações concluídas
          </h2>
        </div>
        <progress
          :value="queue.completed"
          :max="Math.max(queue.required, 1)"
          :aria-label="`${queue.completed} de ${queue.required} avaliações concluídas`"
        />
      </header>

      <p v-if="queue.required === 0" class="request-status">
        A ordem de apresentação ainda não foi definida.
      </p>
      <article v-else-if="queue.current" class="current-team" data-current-team>
        <p class="team-position">Posição {{ queue.current.position }}</p>
        <h3>{{ queue.current.name }}</h3>
        <NuxtLink :to="evaluationPath(queue.current.teamId)">
          Avaliar agora
        </NuxtLink>
      </article>
      <p v-else class="form-success" role="status">
        Todas as avaliações desta categoria foram enviadas.
      </p>

      <article v-if="queue.next" class="next-team" data-next-team>
        <p>Próxima equipe · Posição {{ queue.next.position }}</p>
        <h3>{{ queue.next.name }}</h3>
      </article>

      <ol class="presentation-list">
        <li
          v-for="item in queue.items"
          :key="item.teamId"
          :class="{ submitted: item.submitted }"
        >
          <span>{{ item.position }}. {{ item.name }}</span>
          <NuxtLink v-if="item.submitted" :to="evaluationPath(item.teamId)">
            Editar avaliação
          </NuxtLink>
          <span v-else>Pendente</span>
        </li>
      </ol>
    </section>
  </main>
</template>
