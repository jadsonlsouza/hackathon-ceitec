<script setup lang="ts">
import EventCatalog from '~/components/landing/EventCatalog.vue'
import PlatformHeader from '~/components/landing/PlatformHeader.vue'

useHead({ title: 'Eventos — Ligalab', meta: [{ name: 'description', content: 'Explore os eventos disponíveis no Ligalab.' }] })
</script>

<template>
  <div class="landing-page">
    <PlatformHeader />
    <main id="conteudo-principal" tabindex="-1"><EventCatalog /></main>
  </div>
</template>
