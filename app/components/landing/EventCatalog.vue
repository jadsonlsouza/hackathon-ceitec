<script setup lang="ts">
import type { PublicEventCard } from '~/data/public-events'
import UnavailableState from './UnavailableState.vue'
import EventCard from './EventCard.vue'

const { data, error, status } = await useFetch<PublicEventCard[]>('/api/public-events')
const events = computed(() => data.value ?? [])
</script>

<template>
  <section class="landing-section event-catalog" aria-labelledby="event-catalog-title">
    <p class="section-index">Eventos</p>
    <h1 id="event-catalog-title">Encontre o próximo desafio</h1>
    <p class="section-copy">Conheça os eventos do Ligalab e escolha onde quer colaborar, criar e aprender.</p>
    <p v-if="status === 'pending'" role="status" class="section-copy">Carregando eventos…</p>
    <UnavailableState v-else-if="error" kind="service" />
    <UnavailableState v-else-if="!events.length" kind="catalog" />
    <div v-else class="event-card-grid"><EventCard v-for="event in events" :key="event.event_slug" :event="event" /></div>
  </section>
</template>
