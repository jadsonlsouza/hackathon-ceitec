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
const processingId = ref<string | null>(null)

const { data: requests, pending, error } = await useAsyncData(
  'role-requests',
  async () => {
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
  },
)

async function decide(id: string, decision: 'approved' | 'rejected') {
  processingId.value = id

  try {
    const { error } = await $supabase.rpc('decide_role_request', {
      request_id: id,
      decision,
    })
    if (error) {
      throw createError({
        statusCode: 400,
        statusMessage: 'Não foi possível registrar a decisão.',
      })
    }
    await refreshNuxtData('role-requests')
  }
  finally {
    processingId.value = null
  }
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

    <p v-if="pending" class="request-status">
      Carregando solicitações…
    </p>
    <p v-else-if="error" class="form-error" role="alert">
      Não foi possível carregar as solicitações.
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
            :disabled="processingId === request.id"
            @click="decide(request.id, 'approved')"
          >
            Aprovar
          </button>
          <button
            type="button"
            class="danger-button"
            :disabled="processingId === request.id"
            @click="decide(request.id, 'rejected')"
          >
            Rejeitar
          </button>
        </div>
      </li>
    </ul>
  </main>
</template>
