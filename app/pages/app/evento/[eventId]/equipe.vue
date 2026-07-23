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
      .select('*, members:team_members(*)')
      .eq('event_id', eventId.value)
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
        @decide="decideJoin"
        @request="requestJoin"
      />
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
