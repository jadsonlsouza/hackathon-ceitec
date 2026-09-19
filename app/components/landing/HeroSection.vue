<script setup lang="ts">
import BrandLogo from '../brand/BrandLogo.vue'

defineProps<{
  eventName: string
  eventSlug: string
  tagline: string
  registrationOpen: boolean
}>()
</script>

<template>
  <header class="landing-hero">
    <nav aria-label="Navegação principal" class="landing-nav">
      <NuxtLink to="/" aria-label="Página inicial do Ligalab">
        <BrandLogo variant="dark" />
      </NuxtLink>
      <div class="landing-nav__links">
        <NuxtLink to="/eventos">Eventos</NuxtLink>
        <NuxtLink class="nav-login" to="/login">Entrar</NuxtLink>
      </div>
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
