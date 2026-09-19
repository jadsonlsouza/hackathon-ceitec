<script setup lang="ts">
withDefaults(defineProps<{ kind?: 'catalog' | 'event' | 'service' }>(), { kind: 'catalog' })
</script>

<template>
  <main id="conteudo-principal" class="landing-section">
    <template v-if="kind === 'event'">
      <h1>Evento não encontrado</h1><p class="section-copy">Este evento não está disponível ou não possui uma página pública.</p>
      <div class="hero-actions"><NuxtLink class="secondary-cta" to="/eventos">Ver eventos</NuxtLink><NuxtLink class="secondary-cta" to="/login">Entrar no sistema</NuxtLink></div>
    </template>
    <template v-else-if="kind === 'service'">
      <h1>Eventos temporariamente indisponíveis</h1><p class="section-copy">Não foi possível carregar as informações públicas agora. Tente novamente em breve.</p>
      <div class="hero-actions"><NuxtLink class="secondary-cta" to="/eventos">Tentar novamente</NuxtLink><NuxtLink class="secondary-cta" to="/login">Entrar no sistema</NuxtLink></div>
    </template>
    <template v-else>
      <h1>Nenhum evento público disponível</h1><p class="section-copy">Volte em breve para conhecer os próximos desafios.</p>
      <NuxtLink class="secondary-cta" to="/login">Entrar no sistema</NuxtLink>
    </template>
  </main>
</template>
