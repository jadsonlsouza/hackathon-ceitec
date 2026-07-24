<script setup lang="ts">
import type { Database } from '~/types/database'
import { teamRpcErrorMessage } from '../../../../../utils/team-rpc-error'

definePageMeta({ middleware: 'auth' })

type Team = Database['public']['Tables']['teams']['Row']
type TeamMember = Database['public']['Tables']['team_members']['Row']
type TeamWithMembers = Team & { members: TeamMember[] }

interface ActivityStatus {
  id: string
  title: string
  submissionByTeam: Record<string, { status: string, submitted_at: string | null }>
}

const route = useRoute()
const eventId = computed(() => String(route.params.eventId))
const { $supabase } = useNuxtApp()
const supabase = $supabase as any
const { profile, eventRoles, pending: accessPending, error: accessError } = useCurrentAccess()

const isProfessor = computed(() =>
  profile.value?.global_role === 'global_admin'
  || eventRoles.value.some(role =>
    role.event_id === eventId.value && role.role === 'professor',
  ),
)

// ── List ─────────────────────────────────────────────────────────────────────

function allTeamsKey(targetEventId: string) {
  return `admin-all-teams:${targetEventId}`
}

const listKey = computed(() => allTeamsKey(eventId.value))
const { data: teams, pending, error, refresh: refreshList } = await useAsyncData(
  listKey,
  async () => {
    if (!isProfessor.value) return [] as TeamWithMembers[]
    const { data, error: teamsError } = await supabase
      .from('teams')
      .select('*, members:team_members(*)')
      .eq('event_id', eventId.value)
      .order('created_at')
    if (teamsError) throw teamsError
    return (data ?? []) as TeamWithMembers[]
  },
  {
    server: false,
    default: () => [] as TeamWithMembers[],
    watch: [eventId, eventRoles, profile],
  },
)

// ── Canvas activities + submission status per team ────────────────────────────

function canvasStatusKey(targetEventId: string) {
  return `admin-canvas-status:${targetEventId}`
}

const canvasKey = computed(() => canvasStatusKey(eventId.value))
const { data: activities } = await useAsyncData(
  canvasKey,
  async (): Promise<ActivityStatus[]> => {
    if (!isProfessor.value) return []
    const { data, error: actError } = await supabase
      .from('canvas_activities')
      .select('id,title,submissions(team_id,status,submitted_at)')
      .eq('event_id', eventId.value)
      .order('created_at')
    if (actError) throw actError
    return (data ?? []).map((act: any) => ({
      id: act.id,
      title: act.title,
      submissionByTeam: Object.fromEntries(
        (act.submissions ?? []).map((s: any) => [
          s.team_id,
          { status: s.status, submitted_at: s.submitted_at },
        ]),
      ),
    }))
  },
  {
    server: false,
    default: () => [] as ActivityStatus[],
    watch: [eventId, eventRoles, profile],
  },
)

// ── Edit modal ────────────────────────────────────────────────────────────────

const editingTeam = ref<TeamWithMembers | null>(null)
const editName = ref('')
const editCategory = ref<'junior' | 'senior'>('junior')
const editMembers = ref<Array<{ id: string, name: string, email: string, enrollment: string }>>([])
const saving = ref(false)
const actionError = ref<string | null>(null)
const successMessage = ref<string | null>(null)

function openEdit(team: TeamWithMembers) {
  editingTeam.value = team
  editName.value = team.name
  editCategory.value = team.category
  editMembers.value = team.members.map(m => ({
    id: m.id,
    name: m.name,
    email: m.email,
    enrollment: m.enrollment,
  }))
  actionError.value = null
  successMessage.value = null
}

function closeEdit() {
  editingTeam.value = null
}

async function saveTeam() {
  if (!editingTeam.value || saving.value) return
  saving.value = true
  actionError.value = null
  successMessage.value = null
  try {
    const { error: rpcError } = await supabase.rpc('admin_update_team', {
      team_id: editingTeam.value.id,
      new_name: editName.value.trim(),
      new_category: editCategory.value,
      members: editMembers.value,
    })
    if (rpcError) {
      actionError.value = teamRpcErrorMessage(rpcError, 'Não foi possível salvar as alterações.')
      return
    }
    successMessage.value = 'Equipe atualizada com sucesso.'
    await refreshList()
    closeEdit()
  }
  catch (err: unknown) {
    actionError.value = teamRpcErrorMessage(err, 'Não foi possível salvar as alterações.')
  }
  finally {
    saving.value = false
  }
}

function categoryLabel(cat: Team['category']) {
  return cat === 'junior' ? 'Júnior' : 'Sênior'
}

function statusLabel(status: Team['status']) {
  return { pending: 'Pendente', approved: 'Aprovada', rejected: 'Recusada' }[status] ?? status
}

const canvasStatusLabel: Record<string, string> = {
  draft: 'Rascunho',
  submitted: 'Enviado',
  in_review: 'Em revisão',
  returned: 'Devolvido',
  resubmitted: 'Reenviado',
  approved: 'Aprovado',
}

function canvasStatusClass(status: string | undefined) {
  if (!status) return 'chip--gray'
  return {
    draft: 'chip--gray',
    submitted: 'chip--blue',
    in_review: 'chip--yellow',
    returned: 'chip--red',
    resubmitted: 'chip--blue',
    approved: 'chip--green',
  }[status] ?? 'chip--gray'
}

function teamCanvasStatus(teamId: string) {
  return activities.value.map(act => ({
    title: act.title,
    sub: act.submissionByTeam[teamId] ?? null,
  }))
}
</script>

<template>
  <main class="requests-page">
    <header class="requests-header">
      <p class="eyebrow">Administração do evento</p>
      <h1>Equipes</h1>
      <p class="intro">Visualize e edite todas as equipes deste evento.</p>
    </header>

    <p v-if="accessPending || (isProfessor && pending)" class="request-status">Carregando equipes…</p>
    <p v-else-if="accessError || (isProfessor && error)" class="form-error" role="alert">Não foi possível carregar as equipes.</p>
    <p v-else-if="!isProfessor" class="form-error" role="alert">Somente o Professor responsável pode gerenciar equipes.</p>
    <p v-else-if="teams.length === 0" class="request-status">Nenhuma equipe cadastrada neste evento.</p>

    <ul v-else class="request-list">
      <li v-for="team in teams" :key="team.id" class="request-card team-canvas-card">
        <div class="team-canvas-main">
          <div>
            <h2>{{ team.name }}</h2>
            <dl>
              <div><dt>Categoria</dt><dd>{{ categoryLabel(team.category) }}</dd></div>
              <div><dt>Status</dt><dd>{{ statusLabel(team.status) }}</dd></div>
              <div><dt>Integrantes</dt><dd>{{ team.members.length }}</dd></div>
            </dl>
            <details>
              <summary>Ver integrantes</summary>
              <ul class="team-details">
                <li v-for="member in team.members" :key="member.id">
                  {{ member.name }} · {{ member.email }} · {{ member.enrollment }}
                </li>
              </ul>
            </details>
          </div>
          <div class="request-actions">
            <button type="button" data-action="edit-team" @click="openEdit(team)">Editar equipe</button>
          </div>
        </div>

        <!-- Canvas progress per activity -->
        <div v-if="activities.length > 0" class="team-canvas-progress">
          <p class="team-canvas-progress-title">Atividades Canvas</p>
          <div class="canvas-activity-chips">
            <div
              v-for="item in teamCanvasStatus(team.id)"
              :key="item.title"
              class="canvas-activity-chip"
            >
              <span class="canvas-activity-name">{{ item.title }}</span>
              <span :class="['chip', canvasStatusClass(item.sub?.status)]">
                {{ item.sub ? (canvasStatusLabel[item.sub.status] ?? item.sub.status) : 'Não iniciado' }}
              </span>
            </div>
          </div>
        </div>
      </li>
    </ul>


    <!-- Edit modal -->
    <div v-if="editingTeam" class="modal-overlay" role="dialog" aria-modal="true" aria-labelledby="edit-team-title">
      <div class="modal-panel">
        <header class="modal-header">
          <h2 id="edit-team-title">Editar equipe</h2>
          <button type="button" class="modal-close" aria-label="Fechar" @click="closeEdit">✕</button>
        </header>

        <p v-if="actionError" class="form-error" role="alert">{{ actionError }}</p>

        <form class="team-form" novalidate @submit.prevent="saveTeam">
          <label for="edit-team-name">Nome da equipe</label>
          <input id="edit-team-name" v-model="editName" required>

          <label for="edit-team-category">Categoria</label>
          <select id="edit-team-category" v-model="editCategory">
            <option value="junior">Júnior</option>
            <option value="senior">Sênior</option>
          </select>

          <fieldset class="member-fields">
            <legend>Integrantes</legend>
            <div v-for="(member, index) in editMembers" :key="member.id" class="member-row">
              <h3>Integrante {{ index + 1 }}</h3>
              <label :for="`edit-member-${index}-name`">Nome</label>
              <input :id="`edit-member-${index}-name`" v-model="editMembers[index].name">
              <label :for="`edit-member-${index}-email`">E-mail</label>
              <input :id="`edit-member-${index}-email`" v-model="editMembers[index].email" type="email">
              <label :for="`edit-member-${index}-enrollment`">Matrícula</label>
              <input :id="`edit-member-${index}-enrollment`" v-model="editMembers[index].enrollment">
            </div>
          </fieldset>

          <div class="modal-footer">
            <button type="button" @click="closeEdit">Cancelar</button>
            <button type="submit" :disabled="saving">
              {{ saving ? 'Salvando…' : 'Salvar alterações' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </main>
</template>
