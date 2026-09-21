<script setup lang="ts">
import { watch } from 'vue'
import EventCopyChecklist from './EventCopyChecklist.vue'

type Person = { id: string, display_name: string, email: string }
type SourceEvent = { id: string, name: string, slug: string, status: string }
type WizardSubmission = {
  name: string
  slug: string
  professor_id: string
  source_event_id: string | null
  copy_options: Record<string, boolean>
}

const props = defineProps<{
  professors: Person[]
  sourceEvents: SourceEvent[]
  submitting: boolean
  slugError?: string | null
}>()
const emit = defineEmits<{ submit: [submission: WizardSubmission] }>()

const step = ref(1)
const name = ref('')
const slug = ref('')
const professorId = ref('')
const sourceEventId = ref('')
const nameInput = ref<HTMLInputElement | null>(null)
const errors = ref({ name: '', slug: '', professor: '' })
const copyOptions = ref<Record<string, boolean>>({
  public_content: true,
  evaluation: true,
  canvas: true,
  workshops: true,
  general: true,
})

watch(() => props.slugError, (error) => {
  if (error) step.value = 1
})

function validateBasics() {
  errors.value.name = name.value.trim() ? '' : 'Informe um nome de evento.'
  errors.value.slug = /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(slug.value.trim())
    ? ''
    : 'Informe um identificador válido.'
  if (errors.value.name) {
    nextTick(() => nameInput.value?.focus())
  }
  return !errors.value.name && !errors.value.slug
}

function next() {
  if (step.value === 1) {
    if (validateBasics()) step.value = 2
    return
  }
  if (!professorId.value) {
    errors.value.professor = 'Selecione o professor responsável.'
    return
  }
  errors.value.professor = ''
  step.value = 3
}

function previous() {
  if (step.value > 1) step.value -= 1
}

function submit() {
  if (step.value === 1) {
    next()
    return
  }
  if (step.value === 2) {
    next()
    return
  }
  emit('submit', {
    name: name.value.trim(),
    slug: slug.value.trim(),
    professor_id: professorId.value,
    source_event_id: sourceEventId.value || null,
    copy_options: { ...copyOptions.value },
  })
}
</script>

<template>
  <form class="event-form" @submit.prevent="submit">
    <p class="field-help">Etapa {{ step }} de 3</p>

    <div v-if="step === 1" class="wizard-step">
      <h3>Dados básicos</h3>
      <label for="event-name">Nome do evento</label>
      <input
        id="event-name"
        ref="nameInput"
        v-model="name"
        name="event-name"
        autocomplete="off"
        :aria-invalid="errors.name ? 'true' : undefined"
        :aria-describedby="errors.name ? 'event-name-error' : undefined"
        @input="errors.name = ''"
      >
      <p v-if="errors.name" id="event-name-error" class="form-error" role="alert">{{ errors.name }}</p>

      <label for="event-slug">Identificador na URL</label>
      <input
        id="event-slug"
        v-model="slug"
        name="event-slug"
        pattern="[a-z0-9]+(?:-[a-z0-9]+)*"
        autocomplete="off"
        :aria-invalid="errors.slug || props.slugError ? 'true' : undefined"
        :aria-describedby="errors.slug || props.slugError ? 'event-slug-error' : 'event-slug-help'"
        @input="errors.slug = ''"
      >
      <p v-if="errors.slug || props.slugError" id="event-slug-error" class="form-error" role="alert">
        {{ errors.slug || props.slugError }}
      </p>
      <p v-else id="event-slug-help" class="field-help">Use letras minúsculas, números e hífens.</p>
    </div>

    <div v-else-if="step === 2" class="wizard-step">
      <h3>Estrutura e responsável</h3>
      <label for="event-professor">Professor responsável</label>
      <select id="event-professor" v-model="professorId" @change="errors.professor = ''">
        <option value="">Selecione uma pessoa</option>
        <option v-for="professor in professors" :key="professor.id" :value="professor.id">
          {{ professor.display_name || professor.email }}
        </option>
      </select>
      <p v-if="errors.professor" id="event-professor-error" class="form-error" role="alert">{{ errors.professor }}</p>

      <label for="event-source">Copiar configuração de outro evento (opcional)</label>
      <select id="event-source" v-model="sourceEventId">
        <option value="">Começar sem copiar</option>
        <option v-for="source in sourceEvents" :key="source.id" :value="source.id">
          {{ source.name }} ({{ source.slug }})
        </option>
      </select>
      <EventCopyChecklist v-if="sourceEventId" v-model="copyOptions" />
    </div>

    <div v-else class="wizard-step">
      <h3>Revisar rascunho</h3>
      <p><strong>{{ name.trim() }}</strong> ficará como rascunho.</p>
      <p v-if="sourceEventId">Apenas os itens marcados da configuração serão copiados.</p>
      <p v-else>O evento começará sem configurações copiadas.</p>
      <p class="field-help">
        Nunca serão copiados: usuários, equipes, membros, convites, submissões,
        revisões, avaliações, rankings, resultados, auditoria, presença ou notificações.
      </p>
    </div>

    <div class="wizard-actions">
      <button v-if="step > 1" type="button" class="secondary-button" :disabled="submitting" @click="previous">Voltar</button>
      <button v-if="step < 3" type="button" data-wizard-next :disabled="submitting" @click="next">Continuar</button>
      <button v-else type="submit" :disabled="submitting">{{ submitting ? 'Criando…' : 'Criar rascunho' }}</button>
    </div>
  </form>
</template>

<style scoped>
.wizard-actions { display: flex; gap: .75rem; margin-top: 1rem; }
.secondary-button { background: transparent !important; border: 1px solid #64748b !important; }
</style>
