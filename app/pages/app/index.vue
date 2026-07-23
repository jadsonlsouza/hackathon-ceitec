<script setup lang="ts">
import StatusCard from '../../components/dashboard/StatusCard.vue'
import { useDashboardEventContext } from '../../composables/useDashboardEventContext'
import {
  capabilitiesForAccess,
  type Capability,
} from '../../utils/dashboard-navigation'

definePageMeta({ middleware: 'auth' })

interface DashboardSummary {
  events: number
  teams: number
  reviews: number
  evaluations: number
  activities: number
}

const { $supabase } = useNuxtApp()
const {
  profile,
  eventRoles,
  pending: accessPending,
  error: accessError,
  teamEventIds,
  contextPending,
  contextError,
  currentEventId,
} = useDashboardEventContext()
const capabilities = computed(() => capabilitiesForAccess(
  profile.value,
  eventRoles.value,
  currentEventId.value,
  teamEventIds.value,
))

const summary = useAsyncData(
  'dashboard-summary',
  async (): Promise<DashboardSummary> => {
    const result: DashboardSummary = {
      events: 0,
      teams: 0,
      reviews: 0,
      evaluations: 0,
      activities: 0,
    }
    const activeCapabilities = new Set(capabilities.value)

    if (activeCapabilities.has('manage_events')) {
      const response = await $supabase.from('events').select('id', { count: 'exact', head: true })
      if (response.error) throw response.error
      result.events = response.count ?? 0
    }
    if (currentEventId.value && activeCapabilities.has('manage_event')) {
      const response = await $supabase
        .from('teams')
        .select('id', { count: 'exact', head: true })
        .eq('event_id', currentEventId.value)
      if (response.error) throw response.error
      result.teams = response.count ?? 0
    }
    if (currentEventId.value && activeCapabilities.has('review_submissions')) {
      const response = await $supabase
        .from('submissions')
        .select('id', { count: 'exact', head: true })
        .eq('event_id', currentEventId.value)
        .in('status', ['submitted', 'resubmitted', 'in_review'])
      if (response.error) throw response.error
      result.reviews = response.count ?? 0
    }
    if (
      currentEventId.value
      && profile.value
      && activeCapabilities.has('evaluate_teams')
    ) {
      const response = await $supabase
        .from('evaluator_assignments')
        .select('category', { count: 'exact', head: true })
        .eq('event_id', currentEventId.value)
        .eq('evaluator_id', profile.value.id)
      if (response.error) throw response.error
      result.evaluations = response.count ?? 0
    }
    if (currentEventId.value && activeCapabilities.has('collaborate')) {
      const response = await $supabase
        .from('canvas_activities')
        .select('id', { count: 'exact', head: true })
        .eq('event_id', currentEventId.value)
        .eq('published', true)
      if (response.error) throw response.error
      result.activities = response.count ?? 0
    }
    return result
  },
  {
    server: false,
    default: (): DashboardSummary => ({
      events: 0,
      teams: 0,
      reviews: 0,
      evaluations: 0,
      activities: 0,
    }),
    watch: [profile, eventRoles, currentEventId, teamEventIds],
  },
)

const cardDefinitions: Record<Capability, {
  title: string
  count: keyof DashboardSummary
  actionLabel: string
  actionPath: string
  eventRelative?: boolean
}> = {
  manage_events: {
    title: 'Eventos',
    count: 'events',
    actionLabel: 'Gerenciar eventos',
    actionPath: '/app/admin/eventos',
  },
  manage_event: {
    title: 'Equipes do evento',
    count: 'teams',
    actionLabel: 'Ver equipes',
    actionPath: 'equipes',
    eventRelative: true,
  },
  review_submissions: {
    title: 'Envios para revisar',
    count: 'reviews',
    actionLabel: 'Abrir revisões',
    actionPath: 'revisoes',
    eventRelative: true,
  },
  evaluate_teams: {
    title: 'Avaliações atribuídas',
    count: 'evaluations',
    actionLabel: 'Abrir avaliações',
    actionPath: 'avaliacao',
    eventRelative: true,
  },
  collaborate: {
    title: 'Atividades publicadas',
    count: 'activities',
    actionLabel: 'Ver atividades',
    actionPath: 'atividades',
    eventRelative: true,
  },
}

const cards = computed(() => capabilities.value.flatMap((capability) => {
  const definition = cardDefinitions[capability]
  if (definition.eventRelative && !currentEventId.value) return []
  const count = summary.data.value[definition.count]
  const hasError = Boolean(accessError.value || contextError.value || summary.error.value)
  const isPending = Boolean(accessPending.value || contextPending.value || summary.pending.value)
  const state = hasError ? 'error' : isPending ? 'pending' : count === 0 ? 'empty' : 'ready'
  const status = state === 'error'
    ? 'Não foi possível carregar este resumo.'
    : state === 'pending'
      ? 'Carregando informações…'
      : state === 'empty'
        ? 'Nenhum item encontrado.'
        : 'Resumo atualizado.'
  const actionTo = definition.eventRelative
    ? `/app/evento/${currentEventId.value}/${definition.actionPath}`
    : definition.actionPath
  return [{
    ...definition,
    value: state === 'pending' ? '—' : String(count),
    state,
    status,
    actionTo,
  }]
}))
</script>

<template>
  <main class="dashboard-page">
    <header class="dashboard-header">
      <p class="eyebrow">
        Visão geral
      </p>
      <h1>Painel do Hackathon</h1>
      <p class="intro">
        Acompanhe somente os fluxos liberados para o seu perfil.
      </p>
    </header>

    <p
      v-if="accessPending || contextPending"
      class="request-status"
      role="status"
    >
      Carregando seus acessos…
    </p>
    <p
      v-else-if="accessError || contextError"
      class="form-error"
      role="alert"
    >
      Não foi possível carregar seus acessos.
    </p>
    <p v-else-if="cards.length === 0" class="request-status">
      Nenhum acesso ativo. Solicitações pendentes aparecerão aqui depois da aprovação.
    </p>

    <section v-else class="status-card-grid" aria-label="Resumos do painel">
      <StatusCard
        v-for="card in cards"
        :key="card.title"
        :title="card.title"
        :value="card.value"
        :status="card.status"
        :state="card.state"
        :action-label="card.actionLabel"
        :action-to="card.actionTo"
      />
    </section>
  </main>
</template>
