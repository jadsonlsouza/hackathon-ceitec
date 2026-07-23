<script setup lang="ts">
import type { AutosaveState } from '../../composables/useAutosave'

defineProps<{ state: AutosaveState }>()
defineEmits<{ retry: [] }>()

const labels: Record<AutosaveState, string> = {
  idle: 'Alterações pendentes',
  saving: 'Salvando…',
  saved: 'Salvo',
  error: 'Falha ao salvar',
  conflict: 'Conflito de edição',
}
</script>

<template>
  <div class="autosave-state" role="status" aria-live="polite">
    <span>{{ labels[state] }}</span>
    <button
      v-if="state === 'error'"
      type="button"
      class="link-button"
      data-action="retry-save"
      @click="$emit('retry')"
    >
      Tentar novamente
    </button>
  </div>
</template>
