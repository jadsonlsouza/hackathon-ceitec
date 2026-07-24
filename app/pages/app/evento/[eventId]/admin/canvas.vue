<script setup lang="ts">
import { canvasRpcErrorMessage } from '../../../../../utils/canvas-rpc-error'

definePageMeta({ middleware: 'auth' })

interface ActivityBuilderInput {
  title: string
  instructions: string
  categories: ('junior' | 'senior')[]
  opensAt: string
  dueAt: string
  isPrimary: boolean
  allowResubmission: boolean
  published: boolean
  blocks: { key: string, title: string, prompt: string, position: number, maxItems: number | null }[]
}

interface BuilderBlock {
  key: string
  title: string
  prompt: string
  maxItems: number | null
}

interface SubmissionRow {
  id: string
  status: string
  revision: number
  submitted_at: string | null
  team: { id: string, name: string, category: 'junior' | 'senior' } | null
}

interface ExistingActivity {
  id: string
  template_id: string
  title: string
  instructions: string
  categories: ('junior' | 'senior')[]
  opens_at: string
  due_at: string
  is_primary: boolean
  allow_resubmission: boolean
  published: boolean
  blocks?: Array<{
    id: string
    key: string
    title: string
    prompt: string
    position: number
    max_items: number | null
  }>
  submissions?: SubmissionRow[]
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
const title = ref('')
const instructions = ref('')
const categories = ref<Array<'junior' | 'senior'>>(['junior'])
const opensAt = ref('')
const dueAt = ref('')
const isPrimary = ref(false)
const allowResubmission = ref(true)
const published = ref(false)
const blocks = ref<BuilderBlock[]>([{ key: 'bloco-1', title: '', prompt: '', maxItems: null }])

const editingActivityId = ref<string | null>(null)
const editingTemplateId = ref<string | null>(null)

function canvasAdminKey(targetEventId: string) {
  return `canvas-admin:${targetEventId}`
}

const dataKey = computed(() => canvasAdminKey(eventId.value))
const { data: activities, pending, error } = await useAsyncData(
  dataKey,
  async () => {
    if (!isProfessor.value) return []
    const { data, error: activitiesError } = await $supabase
      .from('canvas_activities')
      .select('id,template_id,title,instructions,categories,opens_at,due_at,is_primary,allow_resubmission,published,blocks:canvas_blocks(id,key,title,prompt,position,max_items),submissions(id,status,revision,submitted_at,team:teams(id,name,category))')
      .eq('event_id', eventId.value)
      .order('created_at')
    if (activitiesError) throw activitiesError
    return (data ?? []) as ExistingActivity[]
  },
  {
    server: false,
    watch: [eventId, eventRoles],
    default: () => [] as ExistingActivity[],
  },
)

function addBlock() {
  blocks.value.push({
    key: `bloco-${Date.now()}-${blocks.value.length + 1}`,
    title: '',
    prompt: '',
    maxItems: null,
  })
}

function removeBlock(index: number) {
  if (blocks.value.length === 1) return
  blocks.value.splice(index, 1)
}

function moveBlock(index: number, direction: -1 | 1) {
  const target = index + direction
  if (target < 0 || target >= blocks.value.length) return
  const [block] = blocks.value.splice(index, 1)
  blocks.value.splice(target, 0, block)
}

function validate(): ActivityBuilderInput | null {
  const normalizedTitle = title.value.trim()
  const normalizedBlocks = blocks.value.map((block, index) => ({
    key: `bloco-${index + 1}`,
    title: block.title.trim(),
    prompt: block.prompt.trim(),
    position: index + 1,
    maxItems: block.maxItems && block.maxItems > 0 ? block.maxItems : null,
  }))
  if (!normalizedTitle) {
    formError.value = 'Informe o título da atividade.'
    return null
  }
  if (categories.value.length === 0) {
    formError.value = 'Selecione pelo menos uma categoria.'
    return null
  }
  if (normalizedBlocks.length === 0 || normalizedBlocks.some(block => !block.title)) {
    formError.value = 'Informe o título de todos os blocos.'
    return null
  }
  const opens = new Date(opensAt.value)
  const due = new Date(dueAt.value)
  if (!opensAt.value || !dueAt.value || Number.isNaN(opens.getTime()) || Number.isNaN(due.getTime())) {
    formError.value = 'Informe a abertura e o prazo da atividade.'
    return null
  }
  if (due.getTime() <= opens.getTime()) {
    formError.value = 'O prazo deve ser posterior à abertura.'
    return null
  }
  return {
    title: normalizedTitle,
    instructions: instructions.value.trim(),
    categories: [...categories.value],
    opensAt: opens.toISOString(),
    dueAt: due.toISOString(),
    isPrimary: isPrimary.value,
    allowResubmission: allowResubmission.value,
    published: published.value,
    blocks: normalizedBlocks,
  }
}

function resetForm() {
  editingActivityId.value = null
  editingTemplateId.value = null
  title.value = ''
  instructions.value = ''
  categories.value = ['junior']
  opensAt.value = ''
  dueAt.value = ''
  isPrimary.value = false
  allowResubmission.value = true
  published.value = false
  blocks.value = [{ key: 'bloco-1', title: '', prompt: '', maxItems: null }]
}

function toLocalDatetimeString(isoString: string) {
  const d = new Date(isoString)
  if (Number.isNaN(d.getTime())) return ''
  const pad = (n: number) => n.toString().padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

function editActivity(activity: ExistingActivity) {
  editingActivityId.value = activity.id
  editingTemplateId.value = activity.template_id
  title.value = activity.title
  instructions.value = activity.instructions
  categories.value = [...activity.categories]
  opensAt.value = toLocalDatetimeString(activity.opens_at)
  dueAt.value = toLocalDatetimeString(activity.due_at)
  isPrimary.value = activity.is_primary
  allowResubmission.value = activity.allow_resubmission
  published.value = activity.published
  
  if (activity.blocks && activity.blocks.length > 0) {
    blocks.value = [...activity.blocks].sort((a, b) => a.position - b.position).map(b => ({
      key: b.key,
      title: b.title,
      prompt: b.prompt,
      maxItems: b.max_items,
    }))
  }
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

function cancelEdit() {
  resetForm()
  formError.value = null
  successMessage.value = null
}

async function saveCanvas() {
  if (!isProfessor.value || saving.value) return
  formError.value = null
  successMessage.value = null
  const input = validate()
  if (!input) return

  saving.value = true
  try {
    if (editingActivityId.value) {
      if (editingTemplateId.value) {
        const templateResult = await $supabase
          .from('canvas_templates')
          .update({
            name: input.title,
            instructions: input.instructions,
          })
          .eq('id', editingTemplateId.value)
        if (templateResult.error) throw templateResult.error
      }

      const activityResult = await $supabase
        .from('canvas_activities')
        .update({
          title: input.title,
          instructions: input.instructions,
          categories: input.categories,
          opens_at: input.opensAt,
          due_at: input.dueAt,
          is_primary: input.isPrimary,
          allow_resubmission: input.allowResubmission,
          published: input.published,
        })
        .eq('id', editingActivityId.value)
      if (activityResult.error) throw activityResult.error

      successMessage.value = 'Atividade atualizada com sucesso.'
    } else {
      const templateResult = await $supabase
        .from('canvas_templates')
        .insert({
          event_id: eventId.value,
          name: input.title,
          instructions: input.instructions,
        })
        .select('id')
        .single()
      if (templateResult.error) throw templateResult.error

      const blocksResult = await $supabase
        .from('canvas_template_blocks')
        .insert(input.blocks.map(block => ({
          template_id: templateResult.data.id,
          key: block.key,
          title: block.title,
          prompt: block.prompt,
          position: block.position,
          max_items: block.maxItems,
        })))
      if (blocksResult.error) throw blocksResult.error

      const activityResult = await $supabase
        .from('canvas_activities')
        .insert({
          event_id: eventId.value,
          template_id: templateResult.data.id,
          title: input.title,
          instructions: input.instructions,
          categories: input.categories,
          opens_at: input.opensAt,
          due_at: input.dueAt,
          is_primary: input.isPrimary,
          allow_resubmission: input.allowResubmission,
          published: input.published,
        })
        .select('id')
        .single()
      if (activityResult.error) throw activityResult.error

      successMessage.value = 'Template e atividade criados com sucesso.'
    }

    resetForm()
    await refreshNuxtData(canvasAdminKey(eventId.value))
  }
  catch (saveError: unknown) {
    formError.value = canvasRpcErrorMessage(saveError, 'Não foi possível criar o Canvas. Revise os dados e tente novamente.')
  }
  finally {
    saving.value = false
  }
}

function submissionCount(activity: ExistingActivity) {
  return activity.submissions?.length ?? 0
}

const expandedActivity = ref<string | null>(null)
function toggleSubmissions(activityId: string) {
  expandedActivity.value = expandedActivity.value === activityId ? null : activityId
}

const submissionStatusLabel: Record<string, string> = {
  draft: 'Rascunho',
  submitted: 'Enviado',
  in_review: 'Em revisão',
  returned: 'Devolvido',
  resubmitted: 'Reenviado',
  approved: 'Aprovado',
}

function submissionStatusClass(status: string) {
  return {
    draft: 'chip--gray',
    submitted: 'chip--blue',
    in_review: 'chip--yellow',
    returned: 'chip--red',
    resubmitted: 'chip--blue',
    approved: 'chip--green',
  }[status] ?? 'chip--gray'
}
</script>

<template>
  <main class="builder-page">
    <header class="builder-header">
      <p class="eyebrow">Professor</p>
      <h1>Construtor de Canvas</h1>
      <p class="intro">Crie um template ordenado e publique uma atividade para uma ou ambas as categorias.</p>
    </header>

    <p v-if="accessPending || (isProfessor && pending)" class="request-status">Carregando construtor…</p>
    <p v-else-if="accessError || (isProfessor && error)" class="form-error" role="alert">Não foi possível carregar o construtor.</p>
    <p v-else-if="!isProfessor" class="form-error" role="alert">Somente o Professor responsável pode gerenciar Canvas.</p>
    <template v-else>
      <p v-if="formError" class="form-error" role="alert">{{ formError }}</p>
      <p v-if="successMessage" class="form-success" role="status">{{ successMessage }}</p>
      <form class="builder-form" novalidate @submit.prevent="saveCanvas">
        <label for="canvas-title">Título</label>
        <input id="canvas-title" v-model="title">
        <label for="canvas-instructions">Instruções</label>
        <textarea id="canvas-instructions" v-model="instructions" rows="3" />

        <fieldset>
          <legend>Categorias</legend>
          <label><input v-model="categories" type="checkbox" value="junior"> Júnior</label>
          <label><input v-model="categories" type="checkbox" value="senior"> Sênior</label>
        </fieldset>

        <div class="date-grid">
          <label for="canvas-opens-at">Abertura</label>
          <input id="canvas-opens-at" v-model="opensAt" type="datetime-local">
          <label for="canvas-due-at">Prazo</label>
          <input id="canvas-due-at" v-model="dueAt" type="datetime-local">
        </div>

        <div class="builder-options">
          <label><input v-model="isPrimary" type="checkbox"> Atividade principal</label>
          <label><input v-model="allowResubmission" type="checkbox"> Permitir reenvio após devolução</label>
          <label><input v-model="published" type="checkbox"> Publicar imediatamente</label>
        </div>

        <fieldset class="builder-blocks">
          <legend>Blocos do template</legend>
          <p v-if="editingActivityId" class="field-help" style="margin-bottom: var(--space-4);">
            <strong>Aviso:</strong> A estrutura de blocos não pode ser alterada para atividades existentes, para garantir a integridade das submissões já enviadas.
          </p>
          <article v-for="(block, index) in blocks" :key="block.key" class="builder-block">
            <h2>Bloco {{ index + 1 }}</h2>
            <label :for="`canvas-block-title-${index}`">Título</label>
            <input :id="`canvas-block-title-${index}`" v-model="block.title" :disabled="!!editingActivityId">
            <label :for="`canvas-block-prompt-${index}`">Orientação</label>
            <textarea :id="`canvas-block-prompt-${index}`" v-model="block.prompt" rows="2" :disabled="!!editingActivityId" />
            <label :for="`canvas-block-max-${index}`">Limite de itens (opcional)</label>
            <input :id="`canvas-block-max-${index}`" v-model.number="block.maxItems" type="number" min="1" :disabled="!!editingActivityId">
            <div v-if="!editingActivityId" class="block-actions">
              <button type="button" :disabled="index === 0" @click="moveBlock(index, -1)">Mover para cima</button>
              <button type="button" :disabled="index === blocks.length - 1" @click="moveBlock(index, 1)">Mover para baixo</button>
              <button type="button" class="danger-button" :disabled="blocks.length === 1" @click="removeBlock(index)">Remover bloco</button>
            </div>
          </article>
          <button v-if="!editingActivityId" type="button" class="secondary-button" @click="addBlock">Adicionar bloco</button>
        </fieldset>

        <div class="form-actions" style="display: flex; gap: var(--space-4); margin-top: var(--space-6);">
          <button type="submit" :disabled="saving">
            {{ saving ? 'Salvando…' : editingActivityId ? 'Salvar alterações' : 'Salvar template e atividade' }}
          </button>
          <button v-if="editingActivityId" type="button" class="secondary-button" :disabled="saving" @click="cancelEdit">
            Cancelar edição
          </button>
        </div>
      </form>

      <section class="existing-canvases" aria-labelledby="existing-canvases-title">
        <h2 id="existing-canvases-title">Atividades criadas</h2>
        <p v-if="activities.length === 0" class="request-status">Nenhuma atividade criada.</p>
        <ul v-else class="activity-list">
          <li v-for="activity in activities" :key="activity.id" class="activity-card">
            <div class="activity-card-header">
              <div>
                <h3>{{ activity.title }}</h3>
                <p>{{ activity.categories.map(c => c === 'junior' ? 'Júnior' : 'Sênior').join(' e ') }}</p>
                <p v-if="submissionCount(activity) > 0" class="locked-structure">
                  {{ submissionCount(activity) }} envio(s).
                </p>
                <p v-else class="field-help">Nenhum envio recebido ainda.</p>
              </div>
              <div style="display: flex; gap: var(--space-2);">
                <button
                  type="button"
                  class="secondary-button"
                  @click="editActivity(activity)"
                >
                  Editar
                </button>
                <button
                  v-if="submissionCount(activity) > 0"
                  type="button"
                  class="secondary-button"
                  :aria-expanded="expandedActivity === activity.id"
                  @click="toggleSubmissions(activity.id)"
                >
                  {{ expandedActivity === activity.id ? 'Ocultar envios' : 'Ver envios' }}
                </button>
              </div>
            </div>

            <!-- Submissions table -->
            <div v-if="expandedActivity === activity.id" class="submission-viewer">
              <table class="submission-table">
                <thead>
                  <tr>
                    <th>Equipe</th>
                    <th>Categoria</th>
                    <th>Status</th>
                    <th>Revisão</th>
                    <th>Enviado em</th>
                    <th>Ação</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="sub in activity.submissions" :key="sub.id">
                    <td>{{ sub.team?.name ?? '—' }}</td>
                    <td>{{ sub.team?.category === 'junior' ? 'Júnior' : sub.team?.category === 'senior' ? 'Sênior' : '—' }}</td>
                    <td>
                      <span :class="['chip', submissionStatusClass(sub.status)]">
                        {{ submissionStatusLabel[sub.status] ?? sub.status }}
                      </span>
                    </td>
                    <td>{{ sub.revision }}</td>
                    <td>{{ sub.submitted_at ? new Date(sub.submitted_at).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' }) : '—' }}</td>
                    <td>
                      <NuxtLink
                        :to="`/app/evento/${eventId}/atividades/${activity.id}?team=${sub.team?.id}`"
                        class="table-link"
                      >
                        Ver envio →
                      </NuxtLink>
                    </td>
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
