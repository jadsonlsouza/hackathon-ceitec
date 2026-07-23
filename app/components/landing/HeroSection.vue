<script setup lang="ts">
defineProps<{
  eventName: string
  tagline: string
  registrationOpen: boolean
}>()
</script>

<template>
  <header class="landing-hero">
    <nav aria-label="Navegação principal" class="landing-nav">
      <NuxtLink to="/" aria-label="Página inicial do Hackathon CEITEC">
        <img
          src="/brand/ceitec-horizontal-white.png"
          alt="CEITEC"
          width="1029"
          height="252"
        >
      </NuxtLink>
      <NuxtLink class="nav-login" to="/login">Entrar</NuxtLink>
    </nav>

    <div class="hero-content">
      <p class="eyebrow">Tecnologia, sustentabilidade e colaboração</p>
      <h1>{{ eventName }}</h1>
      <p class="hero-tagline">{{ tagline }}</p>
      <div class="hero-actions">
        <NuxtLink v-if="registrationOpen" class="primary-cta" to="/cadastro">
          Inscreva-se agora
        </NuxtLink>
        <NuxtLink class="secondary-cta" to="/login">Acessar sistema</NuxtLink>
      </div>
    </div>
  </header>
</template>
