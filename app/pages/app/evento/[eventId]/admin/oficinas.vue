<script setup lang="ts">
definePageMeta({ middleware: 'auth' })

interface EnrollmentRow {
  user_id: string
  team_id: string
  profile: { display_name: string, email: string }
  team: { name: string }
}

interface ExistingWorkshop {
  id: string
  title: string
  description: string
  starts_at: string
  ends_at: string
  capacity: number
  enrollments?: { count: number }[]
  enrollment_details?: EnrollmentRow[]
}

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

const saving = ref(false)
const formError = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const editingWorkshopId = ref<string | null>(null)
const title = ref('')
const description = ref('')
const startsAt = ref('')
const endsAt = ref('')
const capacity = ref<number>(30)

function toLocalDatetimeString(isoString: string) {
  const d = new Date(isoString)
  if (Number.isNaN(d.getTime())) return ''
  const pad = (n: number) => n.toString().padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

function resetForm() {
  editingWorkshopId.value = null
  title.value = ''
  description.value = ''
  startsAt.value = ''
  endsAt.value = ''
  capacity.value = 30
}

function editWorkshop(workshop: ExistingWorkshop) {
  editingWorkshopId.value = workshop.id
  title.value = workshop.title
  description.value = workshop.description
  startsAt.value = toLocalDatetimeString(workshop.starts_at)
  endsAt.value = toLocalDatetimeString(workshop.ends_at)
  capacity.value = workshop.capacity
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

function cancelEdit() {
  resetForm()
  formError.value = null
  successMessage.value = null
}

const dataKey = computed(() => `admin-workshops:${eventId.value}`)
const { data: workshops, pending, error } = await useAsyncData(
  dataKey,
  async () => {
    if (!isProfessor.value) return []
    const { data, error: wError } = await $supabase
      .from('workshops')
      .select('id,title,description,starts_at,ends_at,capacity,enrollments:workshop_enrollments(count),enrollment_details:workshop_enrollments(user_id,team_id,profile:profiles!workshop_enrollments_user_id_fkey(display_name,email),team:teams(name))')
      .eq('event_id', eventId.value)
      .order('starts_at')
    
    if (wError) throw wError
    return (data ?? []) as unknown as ExistingWorkshop[]
  },
  {
    server: false,
    watch: [eventId, eventRoles],
    default: () => [] as ExistingWorkshop[],
  }
)

async function saveWorkshop() {
  if (!isProfessor.value || saving.value) return
  formError.value = null
  successMessage.value = null

  if (!title.value.trim() || !startsAt.value || !endsAt.value || !capacity.value) {
    formError.value = 'Preencha todos os campos obrigatórios.'
    return
  }

  const s = new Date(startsAt.value)
  const e = new Date(endsAt.value)

  if (Number.isNaN(s.getTime()) || Number.isNaN(e.getTime())) {
    formError.value = 'Datas inválidas.'
    return
  }
  if (e.getTime() <= s.getTime()) {
    formError.value = 'O término deve ser após o início.'
    return
  }
  if (capacity.value < 1) {
    formError.value = 'A capacidade deve ser maior que zero.'
    return
  }

  saving.value = true
  try {
    if (editingWorkshopId.value) {
      const { error: updateError } = await $supabase
        .from('workshops')
        .update({
          title: title.value.trim(),
          description: description.value.trim(),
          starts_at: s.toISOString(),
          ends_at: e.toISOString(),
          capacity: capacity.value,
        })
        .eq('id', editingWorkshopId.value)
      if (updateError) throw updateError
      successMessage.value = 'Oficina atualizada com sucesso.'
    } else {
      const { error: insertError } = await $supabase
        .from('workshops')
        .insert({
          event_id: eventId.value,
          title: title.value.trim(),
          description: description.value.trim(),
          starts_at: s.toISOString(),
          ends_at: e.toISOString(),
          capacity: capacity.value,
          created_by: profile.value!.id,
        })
      if (insertError) throw insertError
      successMessage.value = 'Oficina criada com sucesso.'
    }
    resetForm()
    await refreshNuxtData(dataKey.value)
  } catch (err: any) {
    formError.value = err.message || 'Erro ao salvar a oficina.'
  } finally {
    saving.value = false
  }
}

async function deleteWorkshop(id: string) {
  if (!confirm('Tem certeza que deseja excluir esta oficina? Todas as inscrições serão perdidas.')) return
  try {
    const { error: delError } = await $supabase
      .from('workshops')
      .delete()
      .eq('id', id)
    if (delError) throw delError
    await refreshNuxtData(dataKey.value)
  } catch (err: any) {
    alert('Erro ao excluir: ' + err.message)
  }
}

const expandedWorkshop = ref<string | null>(null)
function toggleEnrollments(id: string) {
  expandedWorkshop.value = expandedWorkshop.value === id ? null : id
}

function getEnrollmentCount(w: ExistingWorkshop) {
  return w.enrollments?.[0]?.count ?? 0
}
</script>

<template>
  <main class="builder-page">
    <header class="builder-header">
      <p class="eyebrow">Professor</p>
      <h1>Gestão de Oficinas</h1>
      <p class="intro">Crie oficinas e minicursos para o evento, e acompanhe as inscrições.</p>
    </header>

    <p v-if="accessPending || (isProfessor && pending)" class="request-status">Carregando…</p>
    <p v-else-if="accessError || (isProfessor && error)" class="form-error" role="alert">Não foi possível carregar as oficinas.</p>
    <p v-else-if="!isProfessor" class="form-error" role="alert">Somente o Professor responsável pode gerenciar Oficinas.</p>
    <template v-else>
      <p v-if="formError" class="form-error" role="alert">{{ formError }}</p>
      <p v-if="successMessage" class="form-success" role="status">{{ successMessage }}</p>

      <form class="builder-form" novalidate @submit.prevent="saveWorkshop">
        <label for="w-title">Título da Oficina</label>
        <input id="w-title" v-model="title">

        <label for="w-description">Descrição (opcional)</label>
        <textarea id="w-description" v-model="description" rows="3" />

        <div class="date-grid">
          <label for="w-starts">Início</label>
          <input id="w-starts" v-model="startsAt" type="datetime-local">
          <label for="w-ends">Término</label>
          <input id="w-ends" v-model="endsAt" type="datetime-local">
        </div>

        <label for="w-capacity">Capacidade (vagas)</label>
        <input id="w-capacity" v-model.number="capacity" type="number" min="1">

        <div class="form-actions" style="display: flex; gap: var(--space-4); margin-top: var(--space-6);">
          <button type="submit" :disabled="saving">
            {{ saving ? 'Salvando…' : editingWorkshopId ? 'Salvar alterações' : 'Criar Oficina' }}
          </button>
          <button v-if="editingWorkshopId" type="button" class="secondary-button" :disabled="saving" @click="cancelEdit">
            Cancelar edição
          </button>
        </div>
      </form>

      <section class="existing-canvases" style="margin-top: var(--space-12);">
        <h2>Oficinas Cadastradas</h2>
        <p v-if="workshops.length === 0" class="request-status">Nenhuma oficina criada.</p>
        <ul v-else class="activity-list">
          <li v-for="w in workshops" :key="w.id" class="activity-card">
            <div class="activity-card-header">
              <div>
                <h3>{{ w.title }}</h3>
                <p class="field-help">
                  {{ new Date(w.starts_at).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' }) }} até
                  {{ new Date(w.ends_at).toLocaleString('pt-BR', { timeStyle: 'short' }) }}
                </p>
                <p class="locked-structure" style="margin-top: 0.5rem;">
                  Vagas: {{ getEnrollmentCount(w) }} / {{ w.capacity }} ocupadas
                </p>
              </div>
              <div style="display: flex; gap: var(--space-2);">
                <button type="button" class="secondary-button" @click="editWorkshop(w)">Editar</button>
                <button type="button" class="secondary-button" @click="toggleEnrollments(w.id)">
                  {{ expandedWorkshop === w.id ? 'Ocultar inscritos' : 'Ver inscritos' }}
                </button>
                <button type="button" class="danger-button" @click="deleteWorkshop(w.id)">Excluir</button>
              </div>
            </div>

            <div v-if="expandedWorkshop === w.id" class="submission-viewer" style="margin-top: 1rem;">
              <table class="submission-table">
                <thead>
                  <tr>
                    <th>Nome</th>
                    <th>E-mail</th>
                    <th>Equipe</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="en in w.enrollment_details" :key="en.user_id">
                    <td>{{ (en.profile as any)?.display_name ?? '—' }}</td>
                    <td>{{ (en.profile as any)?.email ?? '—' }}</td>
                    <td>{{ (en.team as any)?.name ?? '—' }}</td>
                  </tr>
                  <tr v-if="!w.enrollment_details?.length">
                    <td colspan="3" style="text-align: center; color: var(--color-gray-500);">Nenhum inscrito.</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </li>
        </ul>
      </section>
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
.builder-form {
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
  background-color: var(--color-gray-900);
  padding: var(--space-6);
  border-radius: var(--radius-lg);
  border: 1px solid var(--color-gray-800);
}
.builder-form label {
  font-weight: 500;
  color: var(--color-gray-100);
}
.builder-form input,
.builder-form textarea {
  width: 100%;
  padding: var(--space-3);
  border-radius: var(--radius-md);
  border: 1px solid var(--color-gray-700);
  background-color: var(--color-gray-950);
  color: var(--color-white);
}
.date-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--space-4);
}
.activity-list {
  list-style: none;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
}
.activity-card {
  background-color: var(--color-gray-900);
  padding: var(--space-6);
  border-radius: var(--radius-lg);
  border: 1px solid var(--color-gray-800);
}
.activity-card-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
}
.activity-card-header h3 {
  margin: 0 0 var(--space-2);
  color: var(--color-white);
}
.field-help {
  font-size: 0.875rem;
  color: var(--color-gray-400);
}
.locked-structure {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-primary-400);
}
.submission-viewer {
  border-top: 1px solid var(--color-gray-800);
  padding-top: var(--space-4);
}
.submission-table {
  width: 100%;
  border-collapse: collapse;
}
.submission-table th,
.submission-table td {
  padding: var(--space-3);
  text-align: left;
  border-bottom: 1px solid var(--color-gray-800);
  font-size: 0.875rem;
}
.submission-table th {
  font-weight: 600;
  color: var(--color-gray-300);
}
.submission-table td {
  color: var(--color-gray-100);
}
.danger-button {
  background-color: var(--color-gray-800);
  color: var(--color-red-400);
  border: 1px solid var(--color-gray-700);
  padding: var(--space-2) var(--space-4);
  border-radius: var(--radius-md);
  cursor: pointer;
  font-weight: 500;
}
.danger-button:hover {
  background-color: var(--color-red-900);
  border-color: var(--color-red-700);
}
</style>
