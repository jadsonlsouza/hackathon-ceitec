<script setup lang="ts">
import type { PublicEventContent } from '~/data/public-events'
import BrandLogo from '~/components/brand/BrandLogo.vue'
import AboutSection from '~/components/landing/AboutSection.vue'
import CategoriesSection from '~/components/landing/CategoriesSection.vue'
import HeroSection from '~/components/landing/HeroSection.vue'
import PublicResults from '~/components/landing/PublicResults.vue'
import ScheduleSection from '~/components/landing/ScheduleSection.vue'
import UnavailableState from '~/components/landing/UnavailableState.vue'

const route = useRoute()
const eventSlug = computed(() => String(route.params.eventSlug ?? ''))
const { data, error: loadError } = await useFetch<PublicEventContent>(() => `/api/public-events/${eventSlug.value}`)
const event = computed(() => data.value)
const unavailableKind = computed(() => (loadError.value?.statusCode === 404 ? 'event' : 'service'))

useHead(() => ({ title: event.value ? `${event.value.event_name} — Ligalab` : 'Evento — Ligalab', meta: [{ name: 'description', content: event.value?.tagline ?? 'Informações sobre um evento Ligalab.' }] }))
</script>

<template>
  <div class="landing-page">
    <a class="skip-link" href="#conteudo-principal">Pular para o conteúdo</a>
    <template v-if="event && !loadError">
      <HeroSection :event-name="event.event_name" :event-slug="event.event_slug" :tagline="event.tagline" :registration-open="event.registration_open" />
      <main id="conteudo-principal" tabindex="-1">
        <AboutSection :presentation="event.presentation" :objectives="event.objectives" />
        <CategoriesSection />
        <section class="landing-section event-facts" aria-labelledby="facts-title"><div><p class="section-index">Quando</p><h2 id="facts-title">{{ event.date_label }}</h2></div><div><p class="section-index">Onde</p><p class="fact-value">{{ event.venue }}</p></div></section>
        <ScheduleSection :items="event.schedule" />
        <section id="inscricoes" class="landing-section registration-panel" aria-labelledby="registration-title">
          <p class="section-index">04 — Inscrições</p><h2 id="registration-title">Monte sua equipe e participe</h2>
          <p class="section-copy">A inscrição é online e individual. No momento do cadastro, o líder deverá fornecer o nome do grupo, cadastrar os membros e selecionar a categoria.</p>
          <div v-if="event.registration_open" class="hero-actions"><NuxtLink class="primary-cta" to="/cadastro">Acessar sistema de inscrição</NuxtLink><NuxtLink class="secondary-cta" to="/login">Já tenho cadastro</NuxtLink></div>
          <p v-else class="registration-closed" role="status">Inscrições encerradas.</p>
        </section>
        <PublicResults :event-slug="event.event_slug" :results="event.results" />
      </main>
    </template>
    <UnavailableState v-else :kind="unavailableKind" />
    <footer class="landing-footer ligalab-footer"><BrandLogo variant="dark" decorative /><p>Ligalab — desafios que conectam pessoas e possibilidades.</p></footer>
  </div>
</template>
