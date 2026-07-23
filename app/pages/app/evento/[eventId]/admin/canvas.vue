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

interface ExistingActivity {
  id: string
  title: string
  categories: ('junior' | 'senior')[]
  blocks?: Array<{ id: string }>
  submissions?: Array<{ count: number }>
}

const route = useRoute()
const eventId = computed(() => String(route.params.eventId))
const { $supabase } = useNuxtApp()
const { eventRoles, pending: accessPending, error: accessError } = useCurrentAccess()
const isProfessor = computed(() => eventRoles.value.some(role => (
  role.event_id === eventId.value && role.role === 'professor'
)))
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
      .select('id,title,categories,blocks:canvas_blocks(id),submissions(count)')
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

async function saveCanvas() {
  if (!isProfessor.value || saving.value) return
  formError.value = null
  successMessage.value = null
  const input = validate()
  if (!input) return

  saving.value = true
  try {
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
  return activity.submissions?.[0]?.count ?? 0
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
          <article v-for="(block, index) in blocks" :key="block.key" class="builder-block">
            <h2>Bloco {{ index + 1 }}</h2>
            <label :for="`canvas-block-title-${index}`">Título</label>
            <input :id="`canvas-block-title-${index}`" v-model="block.title">
            <label :for="`canvas-block-prompt-${index}`">Orientação</label>
            <textarea :id="`canvas-block-prompt-${index}`" v-model="block.prompt" rows="2" />
            <label :for="`canvas-block-max-${index}`">Limite de itens (opcional)</label>
            <input :id="`canvas-block-max-${index}`" v-model.number="block.maxItems" type="number" min="1">
            <div class="block-actions">
              <button type="button" :disabled="index === 0" @click="moveBlock(index, -1)">Mover para cima</button>
              <button type="button" :disabled="index === blocks.length - 1" @click="moveBlock(index, 1)">Mover para baixo</button>
              <button type="button" class="danger-button" :disabled="blocks.length === 1" @click="removeBlock(index)">Remover bloco</button>
            </div>
          </article>
          <button type="button" class="secondary-button" @click="addBlock">Adicionar bloco</button>
        </fieldset>

        <button type="submit" :disabled="saving">{{ saving ? 'Criando…' : 'Salvar template e criar atividade' }}</button>
      </form>

      <section class="existing-canvases" aria-labelledby="existing-canvases-title">
        <h2 id="existing-canvases-title">Atividades criadas</h2>
        <p v-if="activities.length === 0" class="request-status">Nenhuma atividade criada.</p>
        <ul v-else class="activity-list">
          <li v-for="activity in activities" :key="activity.id" class="activity-card">
            <div>
              <h3>{{ activity.title }}</h3>
              <p>{{ activity.categories.map(category => category === 'junior' ? 'Júnior' : 'Sênior').join(' e ') }}</p>
              <p v-if="submissionCount(activity) > 0" class="locked-structure">
                Estrutura bloqueada após o primeiro envio.
              </p>
              <p v-else class="field-help">A estrutura ficará bloqueada quando a primeira equipe enviar.</p>
            </div>
          </li>
        </ul>
      </section>
    </template>
  </main>
</template>
