<script setup lang="ts">
interface PublishedCategory {
  event_name: string
  event_slug: string
  category: 'junior' | 'senior'
  ranking: Array<{
    position: number
    team_id: string
    team_name: string
    category: 'junior' | 'senior'
    score: number
  }>
  published_at: string
}

const route = useRoute()
const eventSlug = computed(() => String(route.params.eventSlug))
const { $supabase } = useNuxtApp()
const supabase = $supabase as any

const {
  data: results,
  pending,
  error,
} = await useAsyncData(
  computed(() => `published-results:${eventSlug.value}`),
  async () => {
    const { data, error: rpcError } = await supabase.rpc(
      'get_published_results',
      { event_slug: eventSlug.value },
    )
    if (rpcError) throw rpcError
    return (data ?? []) as PublishedCategory[]
  },
  {
    server: false,
    watch: [eventSlug],
    default: () => [] as PublishedCategory[],
  },
)

function categoryLabel(category: 'junior' | 'senior') {
  return category === 'junior' ? 'Júnior' : 'Sênior'
}
</script>

<template>
  <main class="public-results-page">
    <header class="public-results-hero">
      <p class="eyebrow">
        Classificação oficial
      </p>
      <h1>Resultados do Hackathon</h1>
      <p v-if="results[0]" class="intro">
        {{ results[0].event_name }}
      </p>
    </header>

    <p v-if="pending" class="request-status" role="status">
      Carregando resultados publicados…
    </p>
    <p v-else-if="error" class="form-error" role="alert">
      Não foi possível carregar os resultados. Tente novamente.
    </p>
    <section v-else-if="!results.length" class="public-empty-state">
      <h2>Resultados ainda não publicados</h2>
      <p>Volte em breve para conferir a classificação oficial.</p>
    </section>
    <section
      v-for="result in results"
      v-else
      :key="result.category"
      class="public-category"
    >
      <header>
        <div>
          <p class="eyebrow">
            Categoria
          </p>
          <h2>Categoria {{ categoryLabel(result.category) }}</h2>
        </div>
        <time :datetime="result.published_at">
          Publicado em
          {{ new Date(result.published_at).toLocaleString('pt-BR') }}
        </time>
      </header>
      <ol class="public-ranking">
        <li v-for="team in result.ranking" :key="team.team_id">
          <span class="public-position">{{ team.position }}º</span>
          <strong>{{ team.team_name }}</strong>
        </li>
      </ol>
    </section>
  </main>
</template>
