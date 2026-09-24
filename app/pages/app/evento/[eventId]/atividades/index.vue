<script setup lang="ts">
definePageMeta({ middleware: 'auth' })

interface ActivityListItem {
  id: string
  event_id: string
  title: string
  opens_at: string
  due_at: string
}

interface SubmissionSummary {
  activity_id: string
  status: 'draft' | 'submitted' | 'in_review' | 'returned' | 'resubmitted' | 'approved'
}

const route = useRoute()
const eventId = computed(() => String(route.params.eventId))
const { $supabase } = useNuxtApp()
const { profile } = useCurrentAccess()

function activitiesPageKey(targetEventId: string) {
  return `canvas-activities:${targetEventId}`
}

const dataKey = computed(() => activitiesPageKey(eventId.value))
const { data: pageData, pending, error } = await useAsyncData(
  dataKey,
  async () => {
    const { data: team, error: teamError } = await $supabase
      .from('teams')
      .select('id,membership:team_members!inner(user_id,status)')
      .eq('event_id', eventId.value)
      .eq('membership.user_id', profile.value?.id ?? '00000000-0000-0000-0000-000000000000')
      .eq('membership.status', 'active')
      .maybeSingle()
    if (teamError) throw teamError

    const { data: activities, error: activitiesError } = await $supabase
      .from('canvas_activities')
      .select('id,event_id,title,opens_at,due_at')
      .eq('event_id', eventId.value)
      .eq('published', true)
      .order('opens_at')
    if (activitiesError) throw activitiesError

    let submissions: SubmissionSummary[] = []
    if (team) {
      const result = await $supabase
        .from('submissions')
        .select('activity_id,status')
        .eq('event_id', eventId.value)
        .eq('team_id', team.id)
      if (result.error) throw result.error
      submissions = (result.data ?? []) as SubmissionSummary[]
    }
    return { activities: (activities ?? []) as ActivityListItem[], submissions }
  },
  {
    server: false,
    watch: [eventId],
    default: () => ({ activities: [] as ActivityListItem[], submissions: [] as SubmissionSummary[] }),
  },
)

const submissionsByActivity = computed(() => new Map(
  pageData.value.submissions.map(submission => [submission.activity_id, submission.status]),
))
const groupedActivities = computed(() => {
  const now = Date.now()
  return {
    open: pageData.value.activities.filter(activity => (
      new Date(activity.opens_at).getTime() <= now && now <= new Date(activity.due_at).getTime()
    )),
    upcoming: pageData.value.activities.filter(activity => new Date(activity.opens_at).getTime() > now),
    closed: pageData.value.activities.filter(activity => new Date(activity.due_at).getTime() < now),
  }
})

function statusLabel(status: SubmissionSummary['status'] | undefined) {
  const labels = {
    draft: 'Rascunho',
    submitted: 'Enviado',
    in_review: 'Em validação',
    returned: 'Devolvido para ajustes',
    resubmitted: 'Reenviado',
    approved: 'Aprovado',
  }
  return status ? labels[status] : 'Não iniciado'
}

const sections = computed(() => [
  { key: 'open' as const, title: 'Abertas agora', empty: 'Nenhuma atividade aberta.' },
  { key: 'upcoming' as const, title: 'Em breve', empty: 'Nenhuma atividade futura.' },
  { key: 'closed' as const, title: 'Encerradas', empty: 'Nenhuma atividade encerrada.' },
])
</script>

<template>
  <main class="activities-page">
    <header class="activities-header">
      <p class="eyebrow">Canvas da equipe</p>
      <h1>Atividades</h1>
      <p class="intro">Acompanhe prazos, status de validação e o histórico da sua equipe.</p>
    </header>

    <p v-if="pending" class="request-status">Carregando atividades…</p>
    <p v-else-if="error" class="form-error" role="alert">Não foi possível carregar as atividades.</p>
    <div v-else class="activity-groups">
      <section v-for="section in sections" :key="section.key" class="activity-group">
        <h2>{{ section.title }}</h2>
        <p v-if="groupedActivities[section.key].length === 0" class="request-status">{{ section.empty }}</p>
        <ul v-else class="activity-list">
          <li v-for="activity in groupedActivities[section.key]" :key="activity.id" class="activity-card">
            <div>
              <h3>{{ activity.title }}</h3>
              <p>Status: {{ statusLabel(submissionsByActivity.get(activity.id)) }}</p>
              <p>
                Prazo:
                <time :datetime="activity.due_at">{{ new Date(activity.due_at).toLocaleString('pt-BR') }}</time>
              </p>
            </div>
            <NuxtLink :to="`/app/evento/${eventId}/atividades/${activity.id}`">Abrir atividade</NuxtLink>
          </li>
        </ul>
      </section>
    </div>
  </main>
</template>
