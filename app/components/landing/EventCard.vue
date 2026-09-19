<script setup lang="ts">
import type { PublicEventCard } from '~/data/public-events'

defineProps<{ event: PublicEventCard }>()
</script>

<template>
  <article class="event-card">
    <p class="section-index">{{ event.date_label }}</p>
    <h2>{{ event.event_name }}</h2>
    <p class="event-card__tagline">{{ event.tagline }}</p>
    <p class="event-card__venue">{{ event.venue }}</p>
    <p class="event-card__status" role="status">{{ event.registration_open ? 'Inscrições abertas' : 'Inscrições encerradas' }}</p>
    <NuxtLink class="primary-cta" :to="`/eventos/${event.event_slug}`">Ver evento</NuxtLink>
  </article>
</template>
