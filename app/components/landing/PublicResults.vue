<script setup lang="ts">
import type { PublishedCategoryResult } from '~/data/ceitec-public-content'

defineProps<{ eventSlug: string, results: PublishedCategoryResult[] }>()
const categoryName = (category: string) => category === 'junior' ? 'Júnior' : 'Sênior'
</script>

<template>
  <section
    v-if="results.length"
    id="resultados"
    class="landing-section"
    aria-labelledby="published-results-title"
  >
    <p class="section-index">05 — Resultados</p>
    <h2 id="published-results-title">Resultado final publicado</h2>
    <div class="category-grid">
      <article v-for="result in results" :key="result.category" class="category-card">
        <h3>Categoria {{ categoryName(result.category) }}</h3>
        <ol data-public-ranking class="landing-ranking">
          <li v-for="team in result.ranking" :key="team.position">
            <span>{{ team.position }}º</span>
            <strong>{{ team.team_name }}</strong>
            <span>{{ team.score }}</span>
          </li>
        </ol>
      </article>
    </div>
    <NuxtLink class="text-link" :to="`/resultados/${eventSlug}`">
      Ver resultados completos
    </NuxtLink>
  </section>
</template>
