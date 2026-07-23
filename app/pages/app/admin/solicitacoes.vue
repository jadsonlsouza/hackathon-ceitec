<script setup lang="ts">
import type { Database } from '~/types/database'

definePageMeta({ middleware: 'auth' })

type RequestedRole = Database['public']['Enums']['event_role']

interface RoleRequestRow {
  id: string
  event_id: string
  requested_role: RequestedRole
  created_at: string
  profile: {
    display_name: string
    email: string
  } | null
  event: {
    name: string
  } | null
}

const { $supabase } = useNuxtApp()
const {
  profile,
  pending: accessPending,
  error: accessError,
} = useCurrentAccess()
const processingId = ref<string | null>(null)
const decisionError = ref<string | null>(null)
const isAuthorized = computed(() => canManageGlobalRoleRequests(profile.value))

const { data: requests, pending, error } = await useAsyncData(
  GLOBAL_ROLE_REQUESTS_KEY,
  async () => {
    if (!isAuthorized.value) return []

    const { data, error: requestError } = await $supabase
      .from('role_requests')
      .select(`
        id,
        event_id,
        requested_role,
        created_at,
        profile:profiles!role_requests_user_id_fkey(display_name,email),
        event:events!role_requests_event_id_fkey(name)
      `)
      .eq('status', 'pending')
      .eq('requested_role', 'professor')
      .order('created_at')

    if (requestError) throw requestError
    return (data ?? []) as unknown as RoleRequestRow[]
  },
  {
    server: false,
    default: () => [] as RoleRequestRow[],
    watch: [profile],
  },
)

async function decide(id: string, decision: 'approved' | 'rejected') {
  if (!isAuthorized.value || processingId.value) return

  await submitRoleDecision({
    rpc: $supabase.rpc.bind($supabase),
    refresh: refreshNuxtData,
    setProcessing: value => processingId.value = value,
    setError: value => decisionError.value = value,
    isProcessing: () => processingId.value !== null,
    requestId: id,
    decision,
    refreshKey: GLOBAL_ROLE_REQUESTS_KEY,
  })
}
</script>

<template>
  <main class="requests-page">
    <header class="requests-header">
      <p class="eyebrow">
        Administração geral
      </p>
      <h1>Solicitações de Professor</h1>
      <p class="intro">
        Aprove ou rejeite quem poderá administrar cada evento.
      </p>
    </header>

    <p v-if="processingId" class="request-status" role="alert">
      Processando decisão…
    </p>
    <p v-if="decisionError" class="form-error" role="alert">
      {{ decisionError }}
    </p>

    <p v-if="accessPending || (isAuthorized && pending)" class="request-status">
      Carregando solicitações…
    </p>
    <p v-else-if="accessError || (isAuthorized && error)" class="form-error" role="alert">
      Não foi possível carregar as solicitações.
    </p>
    <p v-else-if="!isAuthorized" class="form-error" role="alert">
      Você não tem autorização para gerenciar solicitações de Professor.
    </p>
    <p v-else-if="requests.length === 0" class="request-status">
      Não há solicitações pendentes.
    </p>

    <ul v-else class="request-list">
      <li v-for="request in requests" :key="request.id" class="request-card">
        <div>
          <h2>{{ request.profile?.display_name || 'Usuário sem nome' }}</h2>
          <p>{{ request.profile?.email || 'E-mail indisponível' }}</p>
          <dl>
            <div>
              <dt>Função solicitada</dt>
              <dd>Professor</dd>
            </div>
            <div>
              <dt>Evento</dt>
              <dd>{{ request.event?.name || request.event_id }}</dd>
            </div>
          </dl>
        </div>

        <div class="request-actions">
          <button
            type="button"
            :disabled="isRequestProcessing(processingId, request.id)"
            @click="decide(request.id, 'approved')"
          >
            Aprovar
          </button>
          <button
            type="button"
            class="danger-button"
            :disabled="isRequestProcessing(processingId, request.id)"
            @click="decide(request.id, 'rejected')"
          >
            Rejeitar
          </button>
        </div>
      </li>
    </ul>
  </main>
</template>
