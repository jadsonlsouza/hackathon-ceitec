<script setup lang="ts">
import { z } from 'zod'
import type { Database } from '~/types/database'
import { teamRpcErrorMessage } from '../../../../utils/team-rpc-error'

definePageMeta({ middleware: 'auth' })

interface Workshop {
  id: string
  title: string
  description: string
  starts_at: string
  ends_at: string
  capacity: number
  enrollments?: { count: number }[]
}

interface TeamMember {
  user_id: string | null
  name: string
  status: string
}

interface TeamInfo {
  id: string
  leader_id: string
  members: TeamMember[]
}

const route = useRoute()
const eventId = computed(() => String(route.params.eventId))
const { $supabase } = useNuxtApp()
const { profile, pending: accessPending, error: accessError } = useCurrentAccess()

const saving = ref(false)
const pageError = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const dataKey = computed(() => `workshops:${eventId.value}`)

const { data, pending, error } = await useAsyncData(
  dataKey,
  async () => {
    // 1. Fetch workshops
    const { data: wData, error: wError } = await $supabase
      .from('workshops')
      .select('id,title,description,starts_at,ends_at,capacity,enrollments:workshop_enrollments(count)')
      .eq('event_id', eventId.value)
      .order('starts_at')
    if (wError) throw wError

    // 2. Fetch team info
    const { data: tData, error: tError } = await $supabase
      .from('teams')
      .select('id, leader_id, members:team_members(user_id, name, status)')
      .eq('event_id', eventId.value)
      .maybeSingle()
    if (tError) throw tError

    // 3. Fetch team enrollments (RLS limits this to my team's enrollments)
    let enrollments: Array<{ workshop_id: string, user_id: string }> = []
    if (tData) {
      const { data: eData, error: eError } = await $supabase
        .from('workshop_enrollments')
        .select('workshop_id, user_id')
      if (eError) throw eError
      enrollments = eData ?? []
    }

    return {
      workshops: (wData ?? []) as unknown as Workshop[],
      team: tData as unknown as TeamInfo | null,
      enrollments,
    }
  },
  {
    server: false,
    watch: [eventId],
    default: () => ({ workshops: [], team: null, enrollments: [] }),
  }
)

const workshops = computed(() => data.value?.workshops ?? [])
const teamInfo = computed(() => data.value?.team ?? null)
const enrollments = computed(() => data.value?.enrollments ?? [])
const isLeader = computed(() => teamInfo.value?.leader_id === profile.value?.id)

function getAvailableSeats(w: Workshop) {
  const count = w.enrollments?.[0]?.count ?? 0
  return Math.max(0, w.capacity - count)
}

function isEnrolled(workshopId: string, userId: string) {
  return enrollments.value.some(e => e.workshop_id === workshopId && e.user_id === userId)
}

function hasActiveMembers() {
  return teamInfo.value?.members.some(m => m.status === 'active' && m.user_id) ?? false
}

const expandedWorkshop = ref<string | null>(null)
function toggleEnrollmentPanel(id: string) {
  if (expandedWorkshop.value === id) {
    expandedWorkshop.value = null
  } else {
    expandedWorkshop.value = id
    pageError.value = null
    successMessage.value = null
  }
}

async function enroll(workshopId: string, userId: string) {
  if (saving.value) return
  saving.value = true
  pageError.value = null
  successMessage.value = null

  try {
    const { error: err } = await $supabase.rpc('enroll_in_workshop', {
      p_workshop_id: workshopId,
      p_user_id: userId,
    })
    if (err) throw err
    
    successMessage.value = 'Inscrição realizada com sucesso!'
    await refreshNuxtData(dataKey.value)
  } catch (err: any) {
    if (err.message.includes('workshop_full')) {
      pageError.value = 'Esta oficina já está lotada.'
    } else if (err.message.includes('enrollment_forbidden')) {
      pageError.value = 'Você não tem permissão para inscrever este usuário.'
    } else {
      pageError.value = 'Erro ao realizar a inscrição.'
    }
  } finally {
    saving.value = false
  }
}

async function unenroll(workshopId: string, userId: string) {
  if (saving.value) return
  saving.value = true
  pageError.value = null
  successMessage.value = null

  try {
    const { error: err } = await $supabase.rpc('unenroll_from_workshop', {
      p_workshop_id: workshopId,
      p_user_id: userId,
    })
    if (err) throw err
    
    successMessage.value = 'Inscrição cancelada com sucesso.'
    await refreshNuxtData(dataKey.value)
  } catch (err: any) {
    pageError.value = 'Erro ao cancelar a inscrição.'
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <main class="builder-page">
    <header class="builder-header">
      <p class="eyebrow">Oficinas e Minicursos</p>
      <h1>Aprimore seus conhecimentos</h1>
      <p class="intro">
        Participe das oficinas exclusivas do evento. Vagas são limitadas, garanta a sua!
      </p>
    </header>

    <p v-if="accessPending || pending" class="request-status">Carregando oficinas…</p>
    <p v-else-if="accessError || error" class="form-error" role="alert">Erro ao carregar os dados.</p>
    <p v-else-if="!teamInfo" class="form-error" role="alert">
      Você precisa estar em uma equipe aprovada para participar das oficinas.
    </p>
    <template v-else>
      <p v-if="pageError" class="form-error" role="alert">{{ pageError }}</p>
      <p v-if="successMessage" class="form-success" role="status">{{ successMessage }}</p>

      <section v-if="workshops.length === 0" class="no-workshops">
        <p>Nenhuma oficina cadastrada para este evento ainda.</p>
      </section>

      <ul v-else class="workshop-list">
        <li v-for="w in workshops" :key="w.id" class="workshop-card">
          <div class="workshop-card-content">
            <div class="workshop-info">
              <h3>{{ w.title }}</h3>
              <p class="workshop-time">
                {{ new Date(w.starts_at).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' }) }} - 
                {{ new Date(w.ends_at).toLocaleString('pt-BR', { timeStyle: 'short' }) }}
              </p>
              <p v-if="w.description" class="workshop-desc">{{ w.description }}</p>
              
              <div class="seats-indicator" :class="{ 'seats-full': getAvailableSeats(w) === 0 }">
                <span v-if="getAvailableSeats(w) > 0">Restam {{ getAvailableSeats(w) }} vagas</span>
                <span v-else>Vagas Esgotadas</span>
              </div>
            </div>

            <div class="workshop-actions">
              <!-- Líder: Painel de membros -->
              <button
                v-if="isLeader"
                class="primary-button"
                @click="toggleEnrollmentPanel(w.id)"
              >
                {{ expandedWorkshop === w.id ? 'Fechar' : 'Inscrever equipe' }}
              </button>

              <!-- Membro normal: Botão direto -->
              <template v-else-if="profile">
                <button
                  v-if="isEnrolled(w.id, profile.id)"
                  class="secondary-button"
                  :disabled="saving"
                  @click="unenroll(w.id, profile.id)"
                >
                  {{ saving ? 'Processando…' : 'Cancelar minha inscrição' }}
                </button>
                <button
                  v-else
                  class="primary-button"
                  :disabled="saving || getAvailableSeats(w) === 0"
                  @click="enroll(w.id, profile.id)"
                >
                  {{ saving ? 'Processando…' : 'Quero Participar' }}
                </button>
              </template>
            </div>
          </div>

          <!-- Painel do Líder -->
          <div v-if="isLeader && expandedWorkshop === w.id" class="leader-panel">
            <h4>Selecione os membros para inscrever</h4>
            <p v-if="!hasActiveMembers()" class="field-help">Sua equipe ainda não possui membros ativos.</p>
            <ul v-else class="member-list">
              <li v-for="member in teamInfo.members.filter(m => m.status === 'active' && m.user_id)" :key="member.user_id!">
                <span class="member-name">{{ member.name }} <span v-if="member.user_id === profile?.id">(Você)</span></span>
                
                <button
                  v-if="isEnrolled(w.id, member.user_id!)"
                  class="secondary-button compact-btn"
                  :disabled="saving"
                  @click="unenroll(w.id, member.user_id!)"
                >
                  Cancelar Inscrição
                </button>
                <button
                  v-else
                  class="primary-button compact-btn"
                  :disabled="saving || getAvailableSeats(w) === 0"
                  @click="enroll(w.id, member.user_id!)"
                >
                  Inscrever
                </button>
              </li>
            </ul>
          </div>
        </li>
      </ul>
    </template>
  </main>
</template>

<style scoped>
.builder-page {
  max-width: 800px;
  margin: 0 auto;
}
.builder-header {
  margin-bottom: var(--space-8);
}
.no-workshops {
  background-color: var(--color-gray-900);
  padding: var(--space-8);
  border-radius: var(--radius-lg);
  border: 1px solid var(--color-gray-800);
  text-align: center;
  color: var(--color-gray-400);
}
.workshop-list {
  list-style: none;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: var(--space-6);
}
.workshop-card {
  background-color: var(--color-gray-900);
  border-radius: var(--radius-lg);
  border: 1px solid var(--color-gray-800);
  overflow: hidden;
}
.workshop-card-content {
  padding: var(--space-6);
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: var(--space-6);
}
@media (max-width: 600px) {
  .workshop-card-content {
    flex-direction: column;
  }
}
.workshop-info {
  flex: 1;
}
.workshop-info h3 {
  margin: 0 0 var(--space-2);
  color: var(--color-white);
  font-size: 1.25rem;
}
.workshop-time {
  font-size: 0.875rem;
  color: var(--color-primary-400);
  margin-bottom: var(--space-2);
  font-weight: 500;
}
.workshop-desc {
  font-size: 0.95rem;
  color: var(--color-gray-300);
  line-height: 1.5;
  margin-bottom: var(--space-4);
}
.seats-indicator {
  display: inline-block;
  padding: var(--space-1) var(--space-3);
  border-radius: var(--radius-full);
  background-color: var(--color-green-900);
  color: var(--color-green-400);
  font-size: 0.75rem;
  font-weight: 600;
  border: 1px solid var(--color-green-800);
}
.seats-indicator.seats-full {
  background-color: var(--color-red-900);
  color: var(--color-red-400);
  border-color: var(--color-red-800);
}
.workshop-actions {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
  min-width: 150px;
}
.leader-panel {
  background-color: var(--color-gray-950);
  border-top: 1px solid var(--color-gray-800);
  padding: var(--space-6);
}
.leader-panel h4 {
  margin: 0 0 var(--space-4);
  color: var(--color-gray-200);
}
.member-list {
  list-style: none;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
}
.member-list li {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--space-3);
  background-color: var(--color-gray-900);
  border-radius: var(--radius-md);
  border: 1px solid var(--color-gray-800);
}
.member-name {
  color: var(--color-white);
  font-weight: 500;
}
.compact-btn {
  padding: var(--space-1) var(--space-3);
  font-size: 0.875rem;
}
</style>
