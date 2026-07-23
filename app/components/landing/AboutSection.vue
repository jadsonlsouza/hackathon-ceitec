<script setup lang="ts">
defineProps<{ presentation: string, objectives: string[] }>()
</script>

<template>
  <section id="apresentacao" class="landing-section about-grid" aria-labelledby="about-title">
    <div>
      <p class="section-index">01 — Apresentação</p>
      <h2 id="about-title">Uma imersão para transformar ideias em soluções</h2>
      <p class="section-copy">{{ presentation }}</p>
    </div>
    <div class="objectives-card">
      <h3>Objetivos</h3>
      <ul>
        <li v-for="objective in objectives" :key="objective">{{ objective }}</li>
      </ul>
    </div>
  </section>
</template>
