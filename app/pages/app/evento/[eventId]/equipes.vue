<script setup lang="ts">
import type { Database } from '~/types/database'
import { canManageEventRoleRequests } from '../../../../utils/role-request-workflow'
import { teamRpcErrorMessage } from '../../../../utils/team-rpc-error'

definePageMeta({ middleware: 'auth' })

type Team = Database['public']['Tables']['teams']['Row']
type TeamMember = Database['public']['Tables']['team_members']['Row']
type TeamWithMembers = Team & { members: TeamMember[] }

const route = useRoute()
const eventId = computed(() => String(route.params.eventId))
const { $supabase } = useNuxtApp()
const { eventRoles, pending: accessPending, error: accessError } = useCurrentAccess()
const processingId = ref<string | null>(null)
const decisionError = ref<string | null>(null)
const successMessage = ref<string | null>(null)
const isAuthorized = computed(() => (
  canManageEventRoleRequests(eventRoles.value, eventId.value)
))

function pendingTeamsKey(targetEventId: string) {
  return `pending-teams:${targetEventId}`
}

const queueKey = computed(() => pendingTeamsKey(eventId.value))
const { data: teams, pending, error } = await useAsyncData(
  queueKey,
  async () => {
    if (!isAuthorized.value) return []

    const { data, error: teamsError } = await $supabase
      .from('teams')
      .select('*, members:team_members(*)')
      .eq('event_id', eventId.value)
      .eq('status', 'pending')
      .order('created_at')
    if (teamsError) throw teamsError
    return (data ?? []) as TeamWithMembers[]
  },
  {
    server: false,
    default: () => [] as TeamWithMembers[],
    watch: [eventId, eventRoles],
  },
)

function categoryLabel(category: Team['category']) {
  return category === 'junior' ? 'Júnior' : 'Sênior'
}

async function decide(teamId: string, decision: 'approved' | 'rejected') {
  if (!isAuthorized.value || processingId.value) return
  if (decision === 'rejected' && !confirm('Deseja recusar esta equipe? Esta decisão será registrada.')) return

  processingId.value = teamId
  decisionError.value = null
  successMessage.value = null
  try {
    const { error: rpcError } = await $supabase.rpc('decide_team', {
      team_id: teamId,
      decision,
    })
    if (rpcError) {
      decisionError.value = teamRpcErrorMessage(
        rpcError,
        'Não foi possível registrar a decisão. Tente novamente.',
      )
      return
    }
    successMessage.value = decision === 'approved'
      ? 'Equipe aprovada com sucesso.'
      : 'Equipe recusada com sucesso.'
    await refreshNuxtData(pendingTeamsKey(eventId.value))
  }
  catch (rpcError: unknown) {
    decisionError.value = teamRpcErrorMessage(
      rpcError,
      'Não foi possível registrar a decisão. Tente novamente.',
    )
  }
  finally {
    processingId.value = null
  }
}
</script>

<template>
  <main class="requests-page">
    <header class="requests-header">
      <p class="eyebrow">Administração do evento</p>
      <h1>Equipes aguardando validação</h1>
      <p class="intro">Confira categoria, vagas reservadas e integrantes antes de registrar a decisão.</p>
    </header>

    <p v-if="processingId" class="request-status" role="status">Processando decisão…</p>
    <p v-if="decisionError" class="form-error" role="alert">{{ decisionError }}</p>
    <p v-if="successMessage" class="form-success" role="status">{{ successMessage }}</p>
    <p v-if="accessPending || (isAuthorized && pending)" class="request-status">Carregando equipes…</p>
    <p v-else-if="accessError || (isAuthorized && error)" class="form-error" role="alert">Não foi possível carregar as equipes.</p>
    <p v-else-if="!isAuthorized" class="form-error" role="alert">Você não é o Professor responsável por este evento.</p>
    <p v-else-if="teams.length === 0" class="request-status">Não há equipes pendentes.</p>

    <ul v-else class="request-list">
      <li v-for="team in teams" :key="team.id" class="request-card">
        <div>
          <h2>{{ team.name }}</h2>
          <dl>
            <div><dt>Categoria</dt><dd>{{ categoryLabel(team.category) }}</dd></div>
            <div><dt>Integrantes reservados</dt><dd>{{ team.members.length }}</dd></div>
          </dl>
          <details>
            <summary>Ver integrantes</summary>
            <ul class="team-details">
              <li v-for="member in team.members" :key="member.id">{{ member.name }} · {{ member.email }} · {{ member.enrollment }}</li>
            </ul>
          </details>
        </div>
        <div class="request-actions">
          <button type="button" data-team-action="approve" :disabled="processingId !== null" @click="decide(team.id, 'approved')">Aprovar</button>
          <button type="button" class="danger-button" data-team-action="reject" :disabled="processingId !== null" @click="decide(team.id, 'rejected')">Recusar</button>
        </div>
      </li>
    </ul>
  </main>
</template>
