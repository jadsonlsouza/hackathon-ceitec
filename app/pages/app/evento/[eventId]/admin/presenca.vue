<script setup lang="ts">
import type { Database } from '~/types/database'

definePageMeta({ middleware: 'auth' })

const route = useRoute()
const eventId = computed(() => String(route.params.eventId))
const { $supabase } = useNuxtApp()
const { profile, eventRoles, pending: accessPending, error: accessError } = useCurrentAccess()
const isProfessor = computed(() => 
  profile.value?.global_role === 'global_admin' ||
  eventRoles.value.some(role => (
    role.event_id === eventId.value && role.role === 'professor'
  ))
)

interface SessionRow {
  id: string
  session_date: string
  secret_word: string
  created_at: string
  records_count: number
}

const sessions = ref<SessionRow[]>([])
const loading = ref(true)
const fetchError = ref<string | null>(null)

const saving = ref(false)
const formError = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const sessionDate = ref('')
const secretWord = ref('')

async function fetchSessions() {
  loading.value = true
  fetchError.value = null
  try {
    const { data, error } = await $supabase.rpc('admin_get_sessions', {
      p_event_id: eventId.value
    })
    
    if (error) throw error
    sessions.value = data as any[]
  } catch (err: any) {
    console.error(err)
    fetchError.value = 'Não foi possível carregar as sessões de presença.'
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  if (isProfessor.value) fetchSessions()
})

watch(isProfessor, (isProf) => {
  if (isProf) fetchSessions()
})

function resetForm() {
  sessionDate.value = ''
  secretWord.value = ''
  formError.value = null
}

async function createSession() {
  if (saving.value) return
  if (!sessionDate.value || !secretWord.value.trim()) {
    formError.value = 'Preencha a data e a palavra secreta.'
    return
  }

  saving.value = true
  formError.value = null
  successMessage.value = null

  try {
    const { error } = await $supabase.rpc('admin_create_attendance_session', {
      p_event_id: eventId.value,
      p_session_date: sessionDate.value,
      p_secret_word: secretWord.value.trim().toUpperCase()
    })

    if (error) {
      if (error.message.includes('secret_word_already_exists')) {
        formError.value = 'Esta palavra secreta já está em uso neste evento.'
      } else {
        formError.value = 'Não foi possível criar a sessão de presença.'
      }
      return
    }

    successMessage.value = 'Sessão de presença criada com sucesso!'
    resetForm()
    await fetchSessions()
  } catch (err) {
    console.error(err)
    formError.value = 'Ocorreu um erro ao criar a sessão.'
  } finally {
    saving.value = false
  }
}

async function deleteSession(id: string) {
  if (!confirm('Tem certeza que deseja excluir esta sessão? Todos os registros de presença vinculados serão perdidos.')) return
  
  try {
    const { error } = await $supabase
      .from('attendance_sessions')
      .delete()
      .eq('id', id)
    
    if (error) throw error
    await fetchSessions()
  } catch (err) {
    console.error(err)
    alert('Não foi possível excluir a sessão.')
  }
}

function formatDate(dateString: string) {
  const d = new Date(dateString)
  return new Intl.DateTimeFormat('pt-BR').format(new Date(d.getTime() + d.getTimezoneOffset() * 60000))
}
</script>

<template>
  <main class="dashboard-page">
    <header class="page-header">
      <div class="header-content">
        <h1>Presença</h1>
        <p class="intro">Gerencie as palavras secretas para controle de presença dos alunos.</p>
      </div>
    </header>

    <div v-if="accessPending" class="loading-state">Verificando acesso…</div>
    <div v-else-if="accessError" class="error-state" role="alert">Não foi possível verificar seu acesso.</div>
    <div v-else-if="!isProfessor" class="error-state" role="alert">Você não tem permissão para acessar esta página.</div>
    <div v-else class="page-content">
      
      <section class="form-section">
        <h2>Nova Sessão de Presença</h2>
        <p v-if="formError" class="form-error" role="alert">{{ formError }}</p>
        <p v-if="successMessage" class="form-success" role="status">{{ successMessage }}</p>

        <form class="admin-form" @submit.prevent="createSession">
          <div class="form-row">
            <div class="field">
              <label for="session-date">Data</label>
              <input id="session-date" v-model="sessionDate" type="date" required>
            </div>
            <div class="field">
              <label for="secret-word">Palavra Secreta</label>
              <input id="secret-word" v-model="secretWord" type="text" required placeholder="Ex: CEITEC2026" style="text-transform: uppercase;">
              <span class="field-hint">Os alunos precisarão digitar esta palavra exatamente como está.</span>
            </div>
          </div>
          <div class="form-actions">
            <button type="submit" :disabled="saving">
              {{ saving ? 'Criando…' : 'Criar Sessão' }}
            </button>
          </div>
        </form>
      </section>

      <section class="list-section">
        <h2>Sessões Criadas</h2>
        <div v-if="loading" class="loading-state">Carregando sessões…</div>
        <div v-else-if="fetchError" class="error-state" role="alert">{{ fetchError }}</div>
        <div v-else-if="sessions.length === 0" class="empty-state">
          Nenhuma sessão de presença foi criada ainda.
        </div>
        <ul v-else class="session-list">
          <li v-for="session in sessions" :key="session.id" class="session-card">
            <div class="session-info">
              <div class="session-header">
                <h3>{{ formatDate(session.session_date) }}</h3>
                <span class="session-word">Palavra secreta: <strong>{{ session.secret_word }}</strong></span>
              </div>
              <div class="session-stats">
                <span class="badge">{{ session.records_count ?? 0 }} aluno(s) presentes</span>
              </div>
            </div>
            <div class="session-actions">
              <button class="danger-btn" @click="deleteSession(session.id)">Excluir</button>
            </div>
          </li>
        </ul>
      </section>

    </div>
  </main>
</template>

<style scoped>
.page-content {
  display: flex;
  flex-direction: column;
  gap: 2rem;
}

.form-section, .list-section {
  background: #111827;
  border: 1px solid #1e293b;
  border-radius: 12px;
  padding: 1.5rem;
}

.form-section h2, .list-section h2 {
  margin-top: 0;
  margin-bottom: 1.5rem;
  font-size: 1.1rem;
  color: #f1f5f9;
}

.form-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.5rem;
  margin-bottom: 1.5rem;
}

@media (max-width: 640px) {
  .form-row {
    grid-template-columns: 1fr;
  }
}

.field {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.field label {
  font-size: 0.9rem;
  font-weight: 500;
  color: #cbd5e1;
}

.field input {
  padding: 0.6rem 0.75rem;
  border: 1px solid #334155;
  border-radius: 6px;
  background: #0f172a;
  color: #f8fafc;
}

.field input:focus {
  outline: none;
  border-color: #0369a1;
}

.field-hint {
  font-size: 0.75rem;
  color: #64748b;
}

.form-actions {
  display: flex;
  justify-content: flex-end;
}

.form-actions button {
  padding: 0.6rem 1.25rem;
  background: #0369a1;
  color: white;
  border: none;
  border-radius: 6px;
  font-weight: 700;
  cursor: pointer;
  transition: opacity 0.2s;
}

.form-actions button:hover:not(:disabled) {
  opacity: 0.9;
}

.form-actions button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.session-list {
  list-style: none;
  padding: 0;
  margin: 0;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.session-card {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 1.25rem;
  background: #0f172a;
  border: 1px solid #1e293b;
  border-radius: 8px;
}

.session-header {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-bottom: 0.5rem;
}

.session-header h3 {
  margin: 0;
  font-size: 1.05rem;
  color: #f1f5f9;
}

.session-word {
  font-size: 0.85rem;
  color: #94a3b8;
  background: #1e293b;
  padding: 0.2rem 0.5rem;
  border-radius: 4px;
}

.session-word strong {
  color: #38bdf8;
}

.badge {
  display: inline-block;
  background: rgba(16, 185, 129, 0.1);
  color: #34d399;
  font-size: 0.8rem;
  padding: 0.2rem 0.6rem;
  border-radius: 12px;
  border: 1px solid rgba(52, 211, 153, 0.2);
}

.danger-btn {
  background: #991b1b;
  color: white;
  border: none;
  padding: 0.5rem 1rem;
  border-radius: 6px;
  cursor: pointer;
  font-size: 0.85rem;
  font-weight: 700;
  transition: all 0.2s;
}

.danger-btn:hover {
  background: #7f1d1d;
}

.empty-state {
  text-align: center;
  padding: 3rem 1rem;
  color: #64748b;
  font-style: italic;
}
</style>
