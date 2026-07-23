<script setup lang="ts">
defineProps<{
  error: {
    statusCode?: number
    message?: string
    stack?: string
  }
}>()

function retry() {
  clearError({ redirect: '/app' })
}
</script>

<template>
  <main class="error-page">
    <section class="error-card" aria-labelledby="error-title">
      <p class="eyebrow">
        Hackathon CEITEC
      </p>
      <h1 id="error-title">
        Algo não saiu como esperado
      </h1>
      <p class="intro">
        Não foi possível concluir esta ação. Tente novamente ou volte ao início.
      </p>
      <div class="error-actions">
        <button type="button" @click="retry">
          Tentar novamente
        </button>
        <NuxtLink to="/">
          Voltar ao início
        </NuxtLink>
      </div>
    </section>
  </main>
</template>
