<script setup lang="ts">
const options = defineModel<Record<string, boolean>>({ required: true })

const copyOptions = [
  { key: 'public_content', label: 'Conteúdo público e programação' },
  { key: 'evaluation', label: 'Critérios e pesos de avaliação' },
  { key: 'canvas', label: 'Modelos e atividades do Canvas' },
  { key: 'workshops', label: 'Oficinas' },
  { key: 'general', label: 'Datas gerais do evento' },
] as const
</script>

<template>
  <fieldset class="copy-checklist">
    <legend>Configuração reutilizável</legend>
    <label v-for="option in copyOptions" :key="option.key" class="checkbox-field">
      <input
        v-model="options[option.key]"
        type="checkbox"
        :data-copy-option="option.key"
      >
      {{ option.label }}
    </label>
    <p class="field-help">
      Nunca serão copiados: usuários, equipes, membros, convites, submissões,
      revisões, avaliações, rankings, resultados, auditoria, presença ou notificações.
    </p>
  </fieldset>
</template>

<style scoped>
.copy-checklist {
  border: 1px solid #475569;
  border-radius: .5rem;
  margin: .5rem 0;
  padding: .75rem 1rem;
}
.copy-checklist legend { padding: 0 .25rem; }
.checkbox-field { display: flex; gap: .6rem; margin: .5rem 0; }
.field-help { color: #cbd5e1; font-size: .9rem; line-height: 1.4; }
</style>
