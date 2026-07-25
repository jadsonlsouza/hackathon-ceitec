<script setup lang="ts">
import type { Database } from '~/types/database'

definePageMeta({ middleware: 'auth' })

const route = useRoute()
const eventId = computed(() => String(route.params.eventId))
const { $supabase } = useNuxtApp()
const { eventRoles, contextPending: accessPending, contextError: accessError, teamEventIds, profile } = useDashboardEventContext()

const isParticipant = computed(() => {
  // A participant is someone who has an active team in this event
  return teamEventIds.value.includes(eventId.value) || profile.value?.global_role === 'global_admin'
})

const secretWord = ref('')
const processing = ref(false)
const errorMessage = ref<string | null>(null)
const successMessage = ref<string | null>(null)
const checkedInSessions = ref<any[]>([])
const loadingHistory = ref(true)

async function fetchAttendanceHistory() {
  loadingHistory.value = true
  try {
    const { data, error } = await $supabase
      .from('attendance_records')
      .select('checked_in_at, session:attendance_sessions(session_date, secret_word)')
      .eq('session.event_id', eventId.value)
      .order('checked_in_at', { ascending: false })
    
    if (error) throw error
    // Filter out null sessions (due to inner join behavior on foreign tables if RLS blocks, though the query should be fine)
    checkedInSessions.value = data?.filter(r => r.session) || []
  } catch (err) {
    console.error('Failed to fetch attendance history:', err)
  } finally {
    loadingHistory.value = false
  }
}

onMounted(() => {
  if (isParticipant.value) {
    fetchAttendanceHistory()
  }
})

watch(isParticipant, (participant) => {
  if (participant) fetchAttendanceHistory()
})

async function checkIn() {
  if (processing.value || !secretWord.value.trim()) return

  processing.value = true
  errorMessage.value = null
  successMessage.value = null

  try {
    const { error } = await $supabase.rpc('student_check_in', {
      p_event_id: eventId.value,
      p_secret_word: secretWord.value.trim().toUpperCase()
    })

    if (error) {
      if (error.message.includes('invalid_secret_word')) {
        errorMessage.value = 'Palavra secreta inválida. Verifique com seu professor.'
      } else if (error.message.includes('already_checked_in')) {
        errorMessage.value = 'Você já registrou presença para esta sessão.'
      } else if (error.message.includes('not_a_participant')) {
        errorMessage.value = 'Apenas membros ativos de equipes podem registrar presença.'
      } else {
        errorMessage.value = 'Não foi possível registrar a presença.'
      }
      return
    }

    successMessage.value = 'Presença registrada com sucesso!'
    secretWord.value = ''
    await fetchAttendanceHistory()
  } catch (err) {
    console.error(err)
    errorMessage.value = 'Ocorreu um erro inesperado.'
  } finally {
    processing.value = false
  }
}

function formatDate(dateString: string) {
  const d = new Date(dateString)
  return new Intl.DateTimeFormat('pt-BR').format(new Date(d.getTime() + d.getTimezoneOffset() * 60000))
}

function formatTime(isoString: string) {
  const d = new Date(isoString)
  return new Intl.DateTimeFormat('pt-BR', { hour: '2-digit', minute: '2-digit' }).format(d)
}
</script>

<template>
  <main class="dashboard-page">
    <header class="page-header">
      <div class="header-content">
        <h1>Registrar Presença</h1>
        <p class="intro">Insira a palavra secreta informada pelo professor para validar sua presença.</p>
      </div>
    </header>

    <div v-if="accessPending" class="loading-state">Carregando…</div>
    <div v-else-if="!isParticipant" class="error-state" role="alert">
      Apenas participantes com equipes ativas podem registrar presença neste evento.
    </div>
    <div v-else class="page-content">
      
      <section class="checkin-section">
        <form class="checkin-form" @submit.prevent="checkIn">
          <p v-if="errorMessage" class="form-error" role="alert">{{ errorMessage }}</p>
          <p v-if="successMessage" class="form-success" role="status">{{ successMessage }}</p>

          <div class="field">
            <label for="secret-word">Palavra Secreta</label>
            <input 
              id="secret-word" 
              v-model="secretWord" 
              type="text" 
              required 
              placeholder="Digite aqui..." 
              style="text-transform: uppercase;"
              :disabled="processing"
            >
          </div>

          <button type="submit" class="submit-btn" :disabled="processing || !secretWord.trim()">
            {{ processing ? 'Registrando…' : 'Confirmar Presença' }}
          </button>
        </form>
      </section>

      <section class="history-section">
        <h2>Histórico de Presenças</h2>
        
        <div v-if="loadingHistory" class="loading-state">Buscando histórico…</div>
        <div v-else-if="checkedInSessions.length === 0" class="empty-state">
          Você ainda não registrou nenhuma presença neste evento.
        </div>
        <ul v-else class="history-list">
          <li v-for="record in checkedInSessions" :key="record.checked_in_at" class="history-card">
            <div class="history-date">
              <strong>{{ formatDate(record.session.session_date) }}</strong>
            </div>
            <div class="history-details">
              <span>Palavra: <strong>{{ record.session.secret_word }}</strong></span>
              <span class="time-badge">Registrado às {{ formatTime(record.checked_in_at) }}</span>
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
  max-width: 600px;
  margin: 0 auto;
}

.checkin-section {
  background: #111827;
  border: 1px solid #1e293b;
  border-radius: 12px;
  padding: 2rem;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
}

.checkin-form {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.field {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.field label {
  font-size: 1rem;
  font-weight: 500;
  color: #cbd5e1;
}

.field input {
  padding: 0.8rem 1rem;
  font-size: 1.25rem;
  font-weight: 600;
  letter-spacing: 2px;
  text-align: center;
  border: 2px solid #334155;
  border-radius: 8px;
  background: #0f172a;
  color: #f8fafc;
  transition: border-color 0.2s;
}

.field input:focus {
  outline: none;
  border-color: #6366f1;
}

.submit-btn {
  padding: 1rem;
  font-size: 1.1rem;
  font-weight: 600;
  background: #6366f1;
  color: white;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  transition: opacity 0.2s, transform 0.1s;
}

.submit-btn:hover:not(:disabled) {
  opacity: 0.9;
}

.submit-btn:active:not(:disabled) {
  transform: scale(0.98);
}

.submit-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.history-section {
  background: transparent;
}

.history-section h2 {
  font-size: 1.1rem;
  color: #94a3b8;
  margin-bottom: 1rem;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid #1e293b;
}

.history-list {
  list-style: none;
  padding: 0;
  margin: 0;
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.history-card {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem;
  background: #0f172a;
  border: 1px solid #1e293b;
  border-radius: 8px;
}

.history-date strong {
  font-size: 1.05rem;
  color: #e2e8f0;
}

.history-details {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 0.25rem;
  font-size: 0.85rem;
  color: #64748b;
}

.history-details strong {
  color: #94a3b8;
}

.time-badge {
  background: rgba(99, 102, 241, 0.1);
  color: #818cf8;
  padding: 0.15rem 0.5rem;
  border-radius: 4px;
  font-size: 0.75rem;
}

.empty-state {
  text-align: center;
  padding: 2rem 1rem;
  color: #64748b;
  font-style: italic;
  background: #0f172a;
  border-radius: 8px;
  border: 1px dashed #1e293b;
}
</style>
