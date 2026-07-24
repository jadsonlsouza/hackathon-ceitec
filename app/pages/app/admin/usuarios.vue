<script setup lang="ts">
import { ref, computed } from 'vue'
import type { Database } from '~/types/database'

definePageMeta({ middleware: 'auth' })

type EventRole = Database['public']['Enums']['event_role']

interface ProfileRow {
  id: string
  display_name: string
  email: string
  global_role: 'student' | 'global_admin'
  event_roles: {
    event_id: string
    role: EventRole
    event: { name: string } | null
  }[]
}

const { $supabase } = useNuxtApp()
const {
  profile,
  pending: accessPending,
  error: accessError,
} = useCurrentAccess()
const processingId = ref<string | null>(null)
const updateError = ref<string | null>(null)
const isAuthorized = computed(() => profile.value?.global_role === 'global_admin')

const { data: users, pending, error, refresh } = await useAsyncData(
  'admin-users-list',
  async () => {
    if (!isAuthorized.value) return []

    // Fetch profiles and their event roles
    const { data, error: usersError } = await $supabase
      .from('profiles')
      .select(`
        id,
        display_name,
        email,
        global_role,
        event_roles!event_roles_user_id_fkey (
          event_id,
          role,
          event:events!event_roles_event_id_fkey(name)
        )
      `)
      .order('display_name')

    if (usersError) throw usersError
    return (data ?? []) as unknown as ProfileRow[]
  },
  {
    server: false,
    default: () => [] as ProfileRow[],
    watch: [profile],
  },
)

const { data: activeEvents } = await useAsyncData(
  'admin-active-events',
  async () => {
    if (!isAuthorized.value) return []
    const { data, error } = await $supabase
      .from('events')
      .select('id, name')
      .neq('status', 'archived')
      .order('created_at', { ascending: false })
    if (error) return []
    return data
  },
  { server: false, watch: [profile] }
)

const editingUser = ref<string | null>(null)
const editEventId = ref<string>('')
const editNewRole = ref<EventRole | ''>('')

function roleLabel(role: EventRole | '') {
  if (role === 'monitor') return 'Monitor'
  if (role === 'evaluator') return 'Avaliador'
  if (role === 'professor') return 'Professor'
  return 'Estudante (Remover perfil)'
}

function startEditing(userId: string) {
  editingUser.value = userId
  editEventId.value = activeEvents.value?.[0]?.id ?? ''
  editNewRole.value = ''
  updateError.value = null
}

function cancelEditing() {
  editingUser.value = null
}

async function saveRole(userId: string) {
  if (!isAuthorized.value || processingId.value) return
  if (!editEventId.value) {
    updateError.value = 'Selecione um evento.'
    return
  }

  processingId.value = userId
  updateError.value = null

  try {
    const { error } = await $supabase.rpc('admin_update_event_role', {
      target_user_id: userId,
      target_event_id: editEventId.value,
      new_role: editNewRole.value === '' ? null : editNewRole.value,
    })

    if (error) throw error
    await refresh()
    editingUser.value = null
  }
  catch (err: any) {
    updateError.value = err?.message || 'Não foi possível atualizar o perfil.'
  }
  finally {
    processingId.value = null
  }
}
</script>

<template>
  <main class="requests-page admin-users-page">
    <header class="requests-header">
      <p class="eyebrow">
        Administração geral
      </p>
      <h1>Gerenciar Usuários</h1>
      <p class="intro">
        Altere o papel dos usuários dentro de eventos específicos.
      </p>
    </header>

    <p v-if="processingId" class="request-status" role="alert">
      Atualizando perfil…
    </p>
    <p v-if="updateError" class="form-error" role="alert">
      {{ updateError }}
    </p>

    <p v-if="accessPending || (isAuthorized && pending)" class="request-status">
      Carregando usuários…
    </p>
    <p v-else-if="accessError || (isAuthorized && error)" class="form-error" role="alert">
      Não foi possível carregar os usuários.
    </p>
    <p v-else-if="!isAuthorized" class="form-error" role="alert">
      Você não tem autorização para gerenciar usuários.
    </p>
    <p v-else-if="users.length === 0" class="request-status">
      Nenhum usuário encontrado.
    </p>

    <div v-else class="table-scroll">
      <table class="audit-table users-table">
        <thead>
          <tr>
            <th>Nome</th>
            <th>E-mail</th>
            <th>Perfis Atuais</th>
            <th>Ações</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="user in users" :key="user.id">
            <td>
              <strong>{{ user.display_name || 'Usuário sem nome' }}</strong>
              <span v-if="user.global_role === 'global_admin'" class="role-badge admin-badge">Admin</span>
            </td>
            <td>{{ user.email }}</td>
            <td>
              <ul v-if="user.event_roles.length > 0" class="user-roles-list">
                <li v-for="er in user.event_roles" :key="er.event_id">
                  <span class="role-badge">{{ roleLabel(er.role) }}</span> em <em>{{ er.event?.name || 'Evento' }}</em>
                </li>
              </ul>
              <span v-else class="text-muted">Somente Estudante</span>
            </td>
            <td>
              <div v-if="editingUser === user.id" class="edit-role-form">
                <select v-model="editEventId" class="edit-select">
                  <option disabled value="">Selecione o evento</option>
                  <option v-for="ev in activeEvents" :key="ev.id" :value="ev.id">
                    {{ ev.name }}
                  </option>
                </select>
                <select v-model="editNewRole" class="edit-select">
                  <option value="">Estudante (Remover)</option>
                  <option value="monitor">Monitor</option>
                  <option value="evaluator">Avaliador</option>
                  <option value="professor">Professor</option>
                </select>
                <button
                  type="button"
                  class="save-btn"
                  :disabled="processingId === user.id"
                  @click="saveRole(user.id)"
                >
                  Salvar
                </button>
                <button
                  type="button"
                  class="cancel-btn"
                  :disabled="processingId === user.id"
                  @click="cancelEditing"
                >
                  Cancelar
                </button>
              </div>
              <button
                v-else
                type="button"
                class="edit-btn"
                @click="startEditing(user.id)"
              >
                Alterar Papel
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </main>
</template>
