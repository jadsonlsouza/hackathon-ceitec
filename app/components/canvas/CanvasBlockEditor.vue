<script setup lang="ts">
import { ref, watch } from 'vue'
import AutosaveState from './AutosaveState.vue'
import { useAutosave, type AutosaveState as SaveState } from '../../composables/useAutosave'

interface CanvasBlock {
  id: string
  title: string
  prompt: string
  position: number
  max_items: number | null
}

const props = defineProps<{
  block: CanvasBlock
  submissionId: string
  initialContent: { text?: string } | null
  initialVersion: number
  editable: boolean
}>()

const emit = defineEmits<{
  'reload-latest': [blockId: string]
  'state-change': [blockId: string, state: SaveState]
}>()

const { $supabase } = useNuxtApp()
const text = ref(props.initialContent?.text ?? '')
const answerVersion = ref(props.initialVersion)

const autosave = useAutosave(async (content: { text: string }) => {
  const { data, error } = await $supabase.rpc('save_canvas_answer', {
    submission_id: props.submissionId,
    block_id: props.block.id,
    content,
    expected_version: answerVersion.value,
  })
  if (error) throw error
  const version = Number(data?.version)
  answerVersion.value = Number.isFinite(version) ? version : answerVersion.value + 1
  return { version: answerVersion.value }
})

watch(autosave.state, state => emit('state-change', props.block.id, state), { immediate: true })
watch(() => [props.initialContent, props.initialVersion] as const, ([content, version]) => {
  text.value = content?.text ?? ''
  answerVersion.value = version
})

function scheduleSave() {
  if (!props.editable) return
  emit('state-change', props.block.id, 'idle')
  autosave.schedule({ text: text.value })
}
</script>

<template>
  <article class="canvas-block">
    <header>
      <div>
        <p class="block-position">Bloco {{ block.position }}</p>
        <h2>{{ block.title }}</h2>
      </div>
      <AutosaveState :state="autosave.state.value" @retry="autosave.retry" />
    </header>
    <p v-if="block.prompt" class="block-prompt">{{ block.prompt }}</p>
    <label :for="`answer-${block.id}`" class="sr-only">Resposta para {{ block.title }}</label>
    <textarea
      :id="`answer-${block.id}`"
      v-model="text"
      :disabled="!editable"
      :maxlength="block.max_items ? undefined : 10000"
      rows="7"
      @input="scheduleSave"
    />
    <div v-if="autosave.state.value === 'conflict'" class="conflict-banner" role="alert">
      <p>Outra pessoa atualizou este bloco. Recarregue antes de continuar para evitar perda de conteúdo.</p>
      <button type="button" data-action="reload-latest" @click="emit('reload-latest', block.id)">
        Recarregar versão mais recente
      </button>
    </div>
  </article>
</template>
