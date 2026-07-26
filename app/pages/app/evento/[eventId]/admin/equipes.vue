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
const deleting = ref(false)
const actionError = ref<string | null>(null)
const successMessage = ref<string | null>(null)

// New member form state
const addingMember = ref(false)
const newMemberName = ref('')
const newMemberEmail = ref('')
const newMemberEnrollment = ref('')
const addMemberError = ref<string | null>(null)
const removingMemberId = ref<string | null>(null)
const showAddForm = ref(false)

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
  addMemberError.value = null
  showAddForm.value = false
  newMemberName.value = ''
  newMemberEmail.value = ''
  newMemberEnrollment.value = ''
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
      console.error('RPC Error:', rpcError)
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

async function addMember() {
  if (!editingTeam.value || addingMember.value) return
  if (!newMemberName.value.trim() || !newMemberEmail.value.trim() || !newMemberEnrollment.value.trim()) {
    addMemberError.value = 'Preencha todos os campos do novo integrante.'
    return
  }
  if (editMembers.value.length >= 6) {
    addMemberError.value = 'A equipe já atingiu o limite de 6 integrantes.'
    return
  }
  addingMember.value = true
  addMemberError.value = null
  try {
    const { data, error: rpcError } = await supabase.rpc('admin_add_team_member', {
      p_team_id: editingTeam.value.id,
      p_name: newMemberName.value.trim(),
      p_email: newMemberEmail.value.trim(),
      p_enrollment: newMemberEnrollment.value.trim(),
    })
    if (rpcError) {
      const msg = rpcError.message ?? ''
      if (msg.includes('member_already_reserved')) addMemberError.value = 'Este e-mail ou matrícula já está registrado neste evento.'
      else if (msg.includes('team_size_out_of_range')) addMemberError.value = 'A equipe já atingiu o limite de 6 integrantes.'
      else addMemberError.value = 'Não foi possível adicionar o integrante.'
      return
    }
    // Reload team list and reopen edit with fresh data
    await refreshList()
    const updatedTeam = teams.value.find(t => t.id === editingTeam.value!.id)
    if (updatedTeam) openEdit(updatedTeam)
    newMemberName.value = ''
    newMemberEmail.value = ''
    newMemberEnrollment.value = ''
    showAddForm.value = false
  }
  catch {
    addMemberError.value = 'Não foi possível adicionar o integrante.'
  }
  finally {
    addingMember.value = false
  }
}

async function removeMember(memberId: string) {
  if (!editingTeam.value || removingMemberId.value) return
  if (!confirm('Tem certeza que deseja remover este integrante da equipe?')) return
  removingMemberId.value = memberId
  actionError.value = null
  try {
    const { error: rpcError } = await supabase.rpc('admin_remove_team_member', {
      p_member_id: memberId,
    })
    if (rpcError) {
      const msg = rpcError.message ?? ''
      if (msg.includes('last_member')) actionError.value = 'Não é possível remover o único integrante ativo da equipe.'
      else actionError.value = 'Não foi possível remover o integrante.'
      return
    }
    await refreshList()
    const updatedTeam = teams.value.find(t => t.id === editingTeam.value!.id)
    if (updatedTeam) openEdit(updatedTeam)
  }
  catch {
    actionError.value = 'Não foi possível remover o integrante.'
  }
  finally {
    removingMemberId.value = null
  }
}

  async function deleteTeam(teamId: string) {
    if (deleting.value) return
    if (!confirm('Tem certeza que deseja EXCLUIR DEFINITIVAMENTE esta equipe? Todos os dados vinculados (integrantes, apresentações, avaliações) serão apagados irreversivelmente.')) return
    
    deleting.value = true
    actionError.value = null
    try {
      const { error: rpcError } = await supabase.rpc('admin_delete_team', {
        p_team_id: teamId,
      })
      if (rpcError) {
        console.error('RPC Error:', rpcError)
        actionError.value = 'Não foi possível excluir a equipe.'
        return
      }
      await refreshList()
      closeEdit()
    } catch (err) {
      console.error(err)
      actionError.value = 'Não foi possível excluir a equipe.'
    } finally {
      deleting.value = false
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
            <legend>Integrantes ({{ editMembers.length }}/6)</legend>
            <div v-for="(member, index) in editMembers" :key="member.id" class="member-row">
              <div class="member-row-header">
                <h3>Integrante {{ index + 1 }}</h3>
                <button
                  type="button"
                  class="remove-member-btn"
                  :disabled="removingMemberId === member.id || editMembers.length <= 1"
                  :title="editMembers.length <= 1 ? 'Não é possível remover o único integrante' : 'Remover integrante'"
                  @click="removeMember(member.id)"
                >
                  {{ removingMemberId === member.id ? '…' : '✕ Remover' }}
                </button>
              </div>
              <label :for="`edit-member-${index}-name`">Nome</label>
              <input :id="`edit-member-${index}-name`" v-model="editMembers[index].name">
              <label :for="`edit-member-${index}-email`">E-mail</label>
              <input :id="`edit-member-${index}-email`" v-model="editMembers[index].email" type="email">
              <label :for="`edit-member-${index}-enrollment`">Matrícula</label>
              <input :id="`edit-member-${index}-enrollment`" v-model="editMembers[index].enrollment">
            </div>

            <!-- Add member section -->
            <div v-if="editMembers.length < 6" class="add-member-section">
              <button
                v-if="!showAddForm"
                type="button"
                class="add-member-toggle"
                @click="showAddForm = true"
              >
                + Adicionar integrante
              </button>

              <div v-else class="new-member-form">
                <div class="new-member-header">
                  <h3>Novo integrante</h3>
                  <button type="button" class="remove-member-btn" @click="showAddForm = false; addMemberError = null">✕</button>
                </div>
                <p v-if="addMemberError" class="form-error">{{ addMemberError }}</p>
                <label for="new-member-name">Nome</label>
                <input id="new-member-name" v-model="newMemberName" :disabled="addingMember">
                <label for="new-member-email">E-mail</label>
                <input id="new-member-email" v-model="newMemberEmail" type="email" :disabled="addingMember">
                <label for="new-member-enrollment">Matrícula</label>
                <input id="new-member-enrollment" v-model="newMemberEnrollment" :disabled="addingMember">
                <button
                  type="button"
                  class="add-member-confirm"
                  :disabled="addingMember || !newMemberName.trim() || !newMemberEmail.trim() || !newMemberEnrollment.trim()"
                  @click="addMember"
                >
                  {{ addingMember ? 'Adicionando…' : 'Confirmar adição' }}
                </button>
              </div>
            </div>
          </fieldset>

          <div class="modal-footer" style="justify-content: space-between;">
            <button
              type="button"
              style="color: var(--color-danger); border-color: var(--color-danger); background: transparent;"
              :disabled="deleting"
              @click="editingTeam && deleteTeam(editingTeam.id)"
            >
              {{ deleting ? 'Excluindo…' : 'Excluir equipe' }}
            </button>
            <div style="display: flex; gap: 0.75rem;">
              <button type="button" @click="closeEdit">Cancelar</button>
              <button type="submit" :disabled="saving">
                {{ saving ? 'Salvando…' : 'Salvar alterações' }}
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>
  </main>
</template>

<style scoped>
.member-row-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.25rem;
}

.member-row-header h3 {
  margin: 0;
}

.remove-member-btn {
  background: transparent;
  border: 1px solid rgba(248, 113, 113, 0.35);
  color: #f87171;
  border-radius: 6px;
  padding: 0.25rem 0.6rem;
  font-size: 0.75rem;
  cursor: pointer;
  transition: background 0.15s;
}

.remove-member-btn:hover:not(:disabled) {
  background: rgba(248, 113, 113, 0.12);
}

.remove-member-btn:disabled {
  opacity: 0.35;
  cursor: not-allowed;
}

.add-member-section {
  margin-top: 1rem;
  border-top: 1px solid rgba(255, 255, 255, 0.08);
  padding-top: 1rem;
}

.add-member-toggle {
  background: transparent;
  border: 1px dashed rgba(99, 102, 241, 0.5);
  color: #818cf8;
  border-radius: 8px;
  padding: 0.5rem 1rem;
  font-size: 0.875rem;
  cursor: pointer;
  width: 100%;
  transition: background 0.15s, border-color 0.15s;
}

.add-member-toggle:hover {
  background: rgba(99, 102, 241, 0.08);
  border-color: rgba(99, 102, 241, 0.8);
}

.new-member-form {
  background: rgba(99, 102, 241, 0.05);
  border: 1px solid rgba(99, 102, 241, 0.2);
  border-radius: 8px;
  padding: 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

.new-member-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.5rem;
}

.new-member-header h3 {
  margin: 0;
  color: #a5b4fc;
  font-size: 0.9rem;
}

.add-member-confirm {
  margin-top: 0.5rem;
  background: #6366f1;
  color: #fff;
  border: none;
  border-radius: 8px;
  padding: 0.5rem 1rem;
  font-weight: 600;
  cursor: pointer;
  transition: opacity 0.15s;
}

.add-member-confirm:hover:not(:disabled) {
  opacity: 0.88;
}

.add-member-confirm:disabled {
  opacity: 0.45;
  cursor: not-allowed;
}
</style>
