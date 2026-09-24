<script setup lang="ts">
import { z } from 'zod'
import type { Database } from '~/types/database'
import MemberList from '../../../../components/team/MemberList.vue'
import { teamRpcErrorMessage } from '../../../../utils/team-rpc-error'

definePageMeta({ middleware: 'auth' })

type Team = Database['public']['Tables']['teams']['Row']
type TeamMember = Database['public']['Tables']['team_members']['Row']
type TeamWithMembers = Team & { members: TeamMember[] }

const TeamInput = z.object({
  name: z.string().trim().min(2, 'Informe um nome com pelo menos 2 caracteres.').max(80, 'Use no máximo 80 caracteres.'),
  category: z.enum(['junior', 'senior']),
  members: z.array(z.object({
    name: z.string().trim().min(2, 'Informe o nome do integrante.'),
    email: z.string().email('Informe um e-mail válido.'),
    enrollment: z.string().trim().min(1, 'Informe a matrícula.'),
  })).min(1, 'Inclua pelo menos um integrante.').max(6, 'Uma equipe pode ter no máximo 6 integrantes.'),
})

type FormMember = { name: string, email: string, enrollment: string }
type FieldErrors = Record<string, string>

const route = useRoute()
const eventId = computed(() => String(route.params.eventId))
const { $supabase } = useNuxtApp()
const { profile, pending: accessPending, error: accessError } = useCurrentAccess()
const creating = ref(false)
const processingMemberId = ref<string | null>(null)
const pageError = ref<string | null>(null)
const successMessage = ref<string | null>(null)
const fieldErrors = ref<FieldErrors>({})
const teamName = ref('')
const category = ref<'junior' | 'senior'>('junior')
const memberRows = ref<FormMember[]>(Array.from({ length: 6 }, (_, index) => ({
  name: index === 0 ? profile.value?.display_name ?? '' : '',
  email: index === 0 ? profile.value?.email ?? '' : '',
  enrollment: '',
})))

watch(profile, (currentProfile) => {
  if (!currentProfile) return
  const leader = memberRows.value[0]
  if (!leader.name.trim()) leader.name = currentProfile.display_name
  if (!leader.email.trim()) leader.email = currentProfile.email
}, { immediate: true })

function teamPageKey(targetEventId: string) {
  return `event-team:${targetEventId}`
}

const teamKey = computed(() => teamPageKey(eventId.value))
const { data: team, pending, error } = await useAsyncData(
  teamKey,
  async () => {
    const { data, error: teamError } = await $supabase
      .from('teams')
      .select('*, members:team_members(*),membership:team_members!inner(user_id,status)')
      .eq('event_id', eventId.value)
      .eq('membership.user_id', profile.value?.id ?? '00000000-0000-0000-0000-000000000000')
      .eq('membership.status', 'active')
      .maybeSingle()

    if (teamError) throw teamError
    return data as TeamWithMembers | null
  },
  {
    server: false,
    default: () => null as TeamWithMembers | null,
    watch: [eventId, profile],
  },
)

const isLeader = computed(() => team.value?.leader_id === profile.value?.id)
const inviteeMemberId = computed(() => {
  const email = profile.value?.email.trim().toLowerCase()
  if (!email) return null
  return team.value?.members.find(member => (
    member.email.trim().toLowerCase() === email && member.status === 'invited'
  ))?.id ?? null
})

function clearFieldError(field: string) {
  if (!fieldErrors.value[field]) return
  const next = { ...fieldErrors.value }
  delete next[field]
  fieldErrors.value = next
}

function validateInput() {
  const indexedMembers = memberRows.value
    .map((member, index) => ({ member, index }))
    .filter(({ member }) => (
      member.name.trim() || member.email.trim() || member.enrollment.trim()
    ))
  const members = indexedMembers.map(({ member }) => member)
  const result = TeamInput.safeParse({
    name: teamName.value,
    category: category.value,
    members,
  })
  const errors: FieldErrors = {}

  if (!result.success) {
    for (const issue of result.error.issues) {
      if (issue.path[0] === 'name') errors['team-name'] = issue.message
      if (issue.path[0] === 'members' && typeof issue.path[1] === 'number') {
        const originalIndex = indexedMembers[issue.path[1]]?.index
        if (originalIndex !== undefined) {
          errors[`member-${originalIndex}-${issue.path[2]}`] = issue.message
        }
      }
    }
  }
  if (members.length === 0) {
    errors['member-0-name'] = 'Informe o nome do integrante.'
    errors['member-0-email'] = 'Informe o e-mail do integrante.'
    errors['member-0-enrollment'] = 'Informe a matrícula.'
  }
  const seenEmails = new Set<string>()
  const seenEnrollments = new Set<string>()
  indexedMembers.forEach(({ member, index }) => {
    const email = member.email.trim().toLowerCase()
    const enrollment = member.enrollment.trim().toLowerCase()
    if (email && seenEmails.has(email)) errors[`member-${index}-email`] = 'Este e-mail foi informado mais de uma vez.'
    if (enrollment && seenEnrollments.has(enrollment)) errors[`member-${index}-enrollment`] = 'Esta matrícula foi informada mais de uma vez.'
    seenEmails.add(email)
    seenEnrollments.add(enrollment)
  })
  fieldErrors.value = errors
  return result.success && Object.keys(errors).length === 0 ? result.data : null
}

async function createTeam() {
  if (creating.value) return

  const input = validateInput()
  if (!input) return

  creating.value = true
  pageError.value = null
  successMessage.value = null
  try {
    const { error: createError } = await $supabase.rpc('create_team', {
      event_id: eventId.value,
      name: input.name,
      category: input.category,
      members: input.members,
    })
    if (createError) {
      pageError.value = teamRpcErrorMessage(createError)
      return
    }
    successMessage.value = 'Equipe criada e enviada para validação do Professor.'
    await refreshNuxtData(teamPageKey(eventId.value))
  }
  catch (error: unknown) {
    pageError.value = teamRpcErrorMessage(error)
  }
  finally {
    creating.value = false
  }
}

async function decideJoin(memberId: string, approve: boolean) {
  if (processingMemberId.value) return

  processingMemberId.value = memberId
  pageError.value = null
  successMessage.value = null
  try {
    const { error: decisionError } = await $supabase.rpc('decide_team_join', {
      member_id: memberId,
      approve,
    })
    if (decisionError) {
      pageError.value = teamRpcErrorMessage(decisionError)
      return
    }
    successMessage.value = approve
      ? 'Entrada do integrante aprovada.'
      : 'Entrada do integrante recusada.'
    await refreshNuxtData(teamPageKey(eventId.value))
  }
  catch (error: unknown) {
    pageError.value = teamRpcErrorMessage(error)
  }
  finally {
    processingMemberId.value = null
  }
}

async function requestJoin(memberId: string) {
  if (processingMemberId.value) return

  processingMemberId.value = memberId
  pageError.value = null
  successMessage.value = null
  try {
    const { error: requestError } = await $supabase.rpc('request_team_join', {
      member_id: memberId,
    })
    if (requestError) {
      pageError.value = teamRpcErrorMessage(requestError)
      return
    }
    successMessage.value = 'Solicitação de entrada enviada ao líder da equipe.'
    await refreshNuxtData(teamPageKey(eventId.value))
  }
  catch (error: unknown) {
    pageError.value = teamRpcErrorMessage(error)
  }
  finally {
    processingMemberId.value = null
  }
}

// ── Add member (leader only) ─────────────────────────────────────────────

const showAddMember = ref(false)
const newName = ref('')
const newEmail = ref('')
const newEnrollment = ref('')
const addingMember = ref(false)
const addMemberError = ref<string | null>(null)
const removingMemberId = ref<string | null>(null)

function openAddMember() {
  showAddMember.value = true
  newName.value = ''
  newEmail.value = ''
  newEnrollment.value = ''
  addMemberError.value = null
}

function cancelAddMember() {
  showAddMember.value = false
  addMemberError.value = null
}

async function addMember() {
  if (addingMember.value) return
  if (!newName.value.trim() || !newEmail.value.trim() || !newEnrollment.value.trim()) {
    addMemberError.value = 'Preencha todos os campos.'
    return
  }
  addingMember.value = true
  addMemberError.value = null
  pageError.value = null
  try {
    const { error: rpcError } = await $supabase.rpc('leader_add_team_member', {
      p_team_id: team.value!.id,
      p_name: newName.value.trim(),
      p_email: newEmail.value.trim(),
      p_enrollment: newEnrollment.value.trim(),
    })
    if (rpcError) {
      const msg = rpcError.message ?? ''
      if (msg.includes('member_already_reserved')) addMemberError.value = 'Este e-mail ou matrícula já está registrado neste evento.'
      else if (msg.includes('team_size_out_of_range')) addMemberError.value = 'A equipe já tem 6 integrantes (limite máximo).'
      else if (msg.includes('forbidden')) addMemberError.value = 'Somente o líder pode adicionar integrantes.'
      else addMemberError.value = 'Não foi possível adicionar o integrante.'
      return
    }
    showAddMember.value = false
    await refreshNuxtData(teamPageKey(eventId.value))
  }
  catch {
    addMemberError.value = 'Não foi possível adicionar o integrante.'
  }
  finally {
    addingMember.value = false
  }
}

async function removeMember(memberId: string) {
  if (removingMemberId.value) return
  if (!confirm('Tem certeza que deseja remover este integrante?')) return
  removingMemberId.value = memberId
  pageError.value = null
  try {
    const { error: rpcError } = await $supabase.rpc('leader_remove_team_member', {
      p_member_id: memberId,
    })
    if (rpcError) {
      const msg = rpcError.message ?? ''
      if (msg.includes('last_member')) pageError.value = 'Não é possível remover o único integrante ativo.'
      else if (msg.includes('forbidden')) pageError.value = 'Somente o líder pode remover integrantes.'
      else pageError.value = 'Não foi possível remover o integrante.'
      return
    }
    await refreshNuxtData(teamPageKey(eventId.value))
  }
  catch {
    pageError.value = 'Não foi possível remover o integrante.'
  }
  finally {
    removingMemberId.value = null
  }
}
</script>

<template>
  <main class="team-page">
    <header class="team-header">
      <p class="eyebrow">Equipe do evento</p>
      <h1>{{ team ? 'Sua equipe' : 'Criar equipe' }}</h1>
      <p class="intro">Reserve de 1 a 6 vagas. O primeiro integrante deve ser você, líder da equipe.</p>
    </header>

    <p v-if="pageError" class="form-error" role="alert">{{ pageError }}</p>
    <p v-if="successMessage" class="form-success" role="status">{{ successMessage }}</p>
    <p v-if="accessPending || pending" class="request-status">Carregando equipe…</p>
    <p v-else-if="accessError || error" class="form-error" role="alert">Não foi possível carregar sua equipe.</p>

    <section v-else-if="team" class="team-panel" aria-labelledby="team-summary-title">
      <h2 id="team-summary-title">{{ team.name }}</h2>
      <p class="team-meta">Categoria {{ team.category === 'junior' ? 'Júnior' : 'Sênior' }} · Validação {{ team.status === 'pending' ? 'pendente' : team.status === 'approved' ? 'aprovada' : 'recusada' }}</p>
      <p v-if="processingMemberId" class="request-status" role="status">Processando decisão…</p>
      <MemberList
        :members="team.members"
        :is-leader="isLeader"
        :invitee-member-id="inviteeMemberId"
        :processing-id="processingMemberId"
        :removing-id="removingMemberId"
        @decide="decideJoin"
        @request="requestJoin"
        @remove="removeMember"
      />

      <!-- Leader: add member panel -->
      <div v-if="isLeader && team.members.filter(m => m.status === 'active').length < 6" class="add-member-panel">
        <template v-if="!showAddMember">
          <button type="button" class="add-member-toggle" @click="openAddMember">
            + Adicionar integrante
          </button>
        </template>
        <div v-else class="new-member-form">
          <div class="new-member-header">
            <strong>Novo integrante</strong>
            <button type="button" class="cancel-add-btn" @click="cancelAddMember">✕</button>
          </div>
          <p v-if="addMemberError" class="form-error">{{ addMemberError }}</p>
          <label for="new-member-name">Nome</label>
          <input id="new-member-name" v-model="newName" :disabled="addingMember" placeholder="Nome completo">
          <label for="new-member-email">E-mail</label>
          <input id="new-member-email" v-model="newEmail" type="email" :disabled="addingMember" placeholder="email@exemplo.com">
          <label for="new-member-enrollment">Matrícula</label>
          <input id="new-member-enrollment" v-model="newEnrollment" :disabled="addingMember" placeholder="Ex: 20221234">
          <div class="new-member-actions">
            <button type="button" class="cancel-btn" :disabled="addingMember" @click="cancelAddMember">Cancelar</button>
            <button
              type="button"
              :disabled="addingMember || !newName.trim() || !newEmail.trim() || !newEnrollment.trim()"
              @click="addMember"
            >
              {{ addingMember ? 'Adicionando…' : 'Confirmar' }}
            </button>
          </div>
        </div>
      </div>
    </section>

    <section v-else class="team-panel" aria-labelledby="team-form-title">
      <h2 id="team-form-title">Criar equipe</h2>
      <form class="team-form" novalidate @submit.prevent="createTeam">
        <label for="team-name">Nome da equipe</label>
        <input id="team-name" v-model="teamName" name="team-name" :aria-invalid="fieldErrors['team-name'] ? 'true' : undefined" :aria-describedby="fieldErrors['team-name'] ? 'team-name-error' : undefined" @input="clearFieldError('team-name')">
        <p v-if="fieldErrors['team-name']" id="team-name-error" class="form-error" role="alert">{{ fieldErrors['team-name'] }}</p>

        <label for="team-category">Categoria</label>
        <select id="team-category" v-model="category" name="team-category">
          <option value="junior">Júnior</option>
          <option value="senior">Sênior</option>
        </select>

        <fieldset class="member-fields">
          <legend>Integrantes reservados</legend>
          <p class="field-help">Preencha somente as vagas que deseja reservar agora.</p>
          <div v-for="(_member, index) in memberRows" :key="index" class="member-row">
            <h3>Integrante {{ index + 1 }}</h3>
            <label :for="`member-${index}-name`">Nome</label>
            <input :id="`member-${index}-name`" v-model="memberRows[index].name" :aria-invalid="fieldErrors[`member-${index}-name`] ? 'true' : undefined" :aria-describedby="fieldErrors[`member-${index}-name`] ? `member-${index}-name-error` : undefined" @input="clearFieldError(`member-${index}-name`)">
            <p v-if="fieldErrors[`member-${index}-name`]" :id="`member-${index}-name-error`" class="form-error" role="alert">{{ fieldErrors[`member-${index}-name`] }}</p>
            <label :for="`member-${index}-email`">E-mail</label>
            <input :id="`member-${index}-email`" v-model="memberRows[index].email" type="email" :aria-invalid="fieldErrors[`member-${index}-email`] ? 'true' : undefined" :aria-describedby="fieldErrors[`member-${index}-email`] ? `member-${index}-email-error` : undefined" @input="clearFieldError(`member-${index}-email`)">
            <p v-if="fieldErrors[`member-${index}-email`]" :id="`member-${index}-email-error`" class="form-error" role="alert">{{ fieldErrors[`member-${index}-email`] }}</p>
            <label :for="`member-${index}-enrollment`">Matrícula</label>
            <input :id="`member-${index}-enrollment`" v-model="memberRows[index].enrollment" :aria-invalid="fieldErrors[`member-${index}-enrollment`] ? 'true' : undefined" :aria-describedby="fieldErrors[`member-${index}-enrollment`] ? `member-${index}-enrollment-error` : undefined" @input="clearFieldError(`member-${index}-enrollment`)">
            <p v-if="fieldErrors[`member-${index}-enrollment`]" :id="`member-${index}-enrollment-error`" class="form-error" role="alert">{{ fieldErrors[`member-${index}-enrollment`] }}</p>
          </div>
        </fieldset>
        <button type="submit" :disabled="creating">{{ creating ? 'Criando equipe…' : 'Criar equipe' }}</button>
      </form>
    </section>
  </main>
</template>

<style scoped>
.add-member-panel {
  margin-top: 1.25rem;
  border-top: 1px solid rgba(255,255,255,0.08);
  padding-top: 1.25rem;
}

.add-member-toggle {
  width: 100%;
  background: transparent;
  border: 1px dashed rgba(99,102,241,0.5);
  color: #818cf8;
  border-radius: 8px;
  padding: 0.6rem 1rem;
  font-size: 0.9rem;
  cursor: pointer;
  transition: background 0.15s, border-color 0.15s;
}

.add-member-toggle:hover {
  background: rgba(99,102,241,0.08);
  border-color: rgba(99,102,241,0.8);
}

.new-member-form {
  background: rgba(99,102,241,0.05);
  border: 1px solid rgba(99,102,241,0.2);
  border-radius: 10px;
  padding: 1.25rem;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.new-member-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.5rem;
}

.new-member-header strong {
  color: #a5b4fc;
  font-size: 0.95rem;
}

.cancel-add-btn {
  background: transparent;
  border: none;
  color: #64748b;
  cursor: pointer;
  font-size: 1rem;
  padding: 0.2rem 0.4rem;
}

.cancel-add-btn:hover { color: #f1f5f9; }

.new-member-actions {
  display: flex;
  gap: 0.75rem;
  margin-top: 0.5rem;
}

.cancel-btn {
  background: transparent;
  border: 1px solid rgba(255,255,255,0.1);
  color: #94a3b8;
  border-radius: 8px;
  padding: 0.5rem 1rem;
  cursor: pointer;
}

.cancel-btn:hover:not(:disabled) { background: rgba(255,255,255,0.05); }

.remove-btn {
  font-size: 0.8rem;
  padding: 0.3rem 0.75rem;
}
</style>
