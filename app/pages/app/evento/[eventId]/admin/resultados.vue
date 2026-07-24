<script setup lang="ts">
import TieResolution from '../../../../../components/results/TieResolution.vue'
import { resultsRpcErrorMessage } from '../../../../../utils/results-rpc-error'

definePageMeta({ middleware: 'auth' })

type Category = 'junior' | 'senior'

interface ProgressRow {
  event_id: string
  category: Category
  team_id: string
  team_name: string
  required_evaluator_count: number
  completed_evaluator_count: number
  missing_evaluators: Array<{
    evaluator_id: string
    display_name: string
  }>
  complete: boolean
}

interface RankingRow {
  event_id: string
  category: Category
  team_id: string
  team_name: string
  exact_final_score: number
  final_score: number
  score_rank: number
}

interface Decision {
  event_id: string
  category: Category
  displayed_score: number
  ordered_team_ids: string[]
  justification: string
  created_at: string
}

interface Publication {
  event_id: string
  category: Category
  published_at: string
}

const categories: Category[] = ['junior', 'senior']
const route = useRoute()
const eventId = computed(() => String(route.params.eventId))
const { $supabase } = useNuxtApp()
const supabase = $supabase as any
const {
  profile,
  eventRoles,
  pending: accessPending,
  error: accessError,
} = useCurrentAccess()
const processingAction = ref<string | null>(null)
const actionError = ref<string | null>(null)
const successMessage = ref<string | null>(null)

const isProfessor = computed(() => 
  profile.value?.global_role === 'global_admin' ||
  eventRoles.value.some(role => (
    role.event_id === eventId.value && role.role === 'professor'
  ))
)

const resultKey = computed(() => `result-admin:${eventId.value}`)
const {
  data: source,
  pending,
  error,
  refresh,
} = await useAsyncData(
  resultKey,
  async () => {
    if (!isProfessor.value) {
      return {
        eventSlug: null as string | null,
        progress: [] as ProgressRow[],
        ranking: [] as RankingRow[],
        decisions: [] as Decision[],
        publications: [] as Publication[],
      }
    }
    const [eventRow, progress, ranking, decisions, publications] = await Promise.all([
      supabase.from('events').select('slug').eq('id', eventId.value).single(),
      supabase.rpc('get_evaluation_progress', {
        target_event: eventId.value,
      }),
      supabase.rpc('get_administrative_ranking', {
        target_event: eventId.value,
      }),
      supabase
        .from('tie_decisions')
        .select('*')
        .eq('event_id', eventId.value),
      supabase.rpc('get_administrative_publications', {
        target_event: eventId.value,
      }),
    ])
    const failure = [
      eventRow.error,
      progress.error,
      ranking.error,
      decisions.error,
      publications.error,
    ].find(Boolean)
    if (failure) throw failure
    return {
      eventSlug: eventRow.data?.slug ?? null,
      progress: (progress.data ?? []) as ProgressRow[],
      ranking: (ranking.data ?? []) as RankingRow[],
      decisions: (decisions.data ?? []) as Decision[],
      publications: (publications.data ?? []) as Publication[],
    }
  },
  {
    server: false,
    watch: [eventId, eventRoles],
    default: () => ({
      eventSlug: null as string | null,
      progress: [] as ProgressRow[],
      ranking: [] as RankingRow[],
      decisions: [] as Decision[],
      publications: [] as Publication[],
    }),
  },
)

function categoryLabel(category: Category) {
  return category === 'junior' ? 'Júnior' : 'Sênior'
}

function categoryProgress(category: Category) {
  return source.value.progress.filter(row => row.category === category)
}

function categoryRanking(category: Category) {
  return source.value.ranking.filter(row => row.category === category)
}

function publication(category: Category) {
  return source.value.publications.find(row => row.category === category)
}

function tieGroups(category: Category) {
  const grouped = new Map<number, RankingRow[]>()
  for (const row of categoryRanking(category)) {
    const group = grouped.get(Number(row.final_score)) ?? []
    group.push(row)
    grouped.set(Number(row.final_score), group)
  }
  return [...grouped.entries()]
    .filter(([, rows]) => rows.length > 1)
    .map(([score, rows]) => {
      const decision = source.value.decisions.find(d => (
        d.category === category && Number(d.displayed_score) === score
      ))
      return {
        score,
        rows,
        decision: decision ?? null,
        resolved: Boolean(decision),
      }
    })
}

function blockers(category: Category) {
  const messages: string[] = []
  const progress = categoryProgress(category)
  if (!progress.length) messages.push('A avaliação ainda não foi congelada.')
  if (progress.some(row => !row.complete)) {
    messages.push('Há equipes com avaliações pendentes.')
  }
  if (tieGroups(category).some(group => !group.resolved)) {
    messages.push('Há empates sem decisão registrada.')
  }
  return messages
}

async function refreshResults() {
  await refresh()
  await refreshNuxtData(`result-admin:${eventId.value}`)
}

async function resolveTie(payload: {
  event_id: string
  category: Category
  displayed_score: number
  ordered_team_ids: string[]
  justification: string
}) {
  const action = `resolve:${payload.category}:${payload.displayed_score}`
  if (!isProfessor.value || processingAction.value) return
  processingAction.value = action
  actionError.value = null
  successMessage.value = null
  try {
    const { error: rpcError } = await supabase.rpc('resolve_tie', payload)
    if (rpcError) throw rpcError
    successMessage.value = 'Desempate registrado e auditado.'
    await refreshResults()
  }
  catch (caught) {
    actionError.value = resultsRpcErrorMessage(
      caught,
      'Não foi possível registrar o desempate. Tente novamente.',
    )
  }
  finally {
    processingAction.value = null
  }
}

async function publishCategory(category: Category) {
  const action = `publish:${category}`
  if (
    !isProfessor.value
    || processingAction.value
    || blockers(category).length
    || publication(category)
  ) return
  processingAction.value = action
  actionError.value = null
  successMessage.value = null
  try {
    const { error: rpcError } = await supabase.rpc(
      'publish_category_results',
      { event_id: eventId.value, category },
    )
    if (rpcError) throw rpcError
    successMessage.value = `Resultados da categoria ${categoryLabel(category)} publicados.`
    await refreshResults()
  }
  catch (caught) {
    actionError.value = resultsRpcErrorMessage(
      caught,
      'Não foi possível publicar esta categoria. Tente novamente.',
    )
  }
  finally {
    processingAction.value = null
  }
}

async function unpublishCategory(category: Category) {
  const action = `unpublish:${category}`
  if (!isProfessor.value || processingAction.value) return
  if (!confirm(`Deseja despublicar a categoria ${categoryLabel(category)}? Os resultados deixarão de ser visíveis publicamente.`)) return
  processingAction.value = action
  actionError.value = null
  successMessage.value = null
  try {
    const { error: rpcError } = await supabase.rpc(
      'unpublish_category_results',
      { event_id: eventId.value, category },
    )
    if (rpcError) throw rpcError
    successMessage.value = `Categoria ${categoryLabel(category)} despublicada.`
    await refreshResults()
  }
  catch (caught) {
    actionError.value = resultsRpcErrorMessage(
      caught,
      'Não foi possível despublicar esta categoria. Tente novamente.',
    )
  }
  finally {
    processingAction.value = null
  }
}
const isExporting = ref(false)

async function exportToCsv() {
  if (isExporting.value) return
  isExporting.value = true
  
  try {
    const { data: criteria } = await supabase
      .from('evaluation_criteria')
      .select('id, name')
      .eq('event_id', eventId.value)
      .order('position')
      
    const { data: evaluations } = await supabase
      .from('evaluations')
      .select(`
        id,
        category,
        comment,
        submitted_at,
        team:teams(name),
        evaluator:profiles!evaluations_evaluator_id_fkey(display_name, email),
        scores:evaluation_scores(criterion_id, score)
      `)
      .eq('event_id', eventId.value)
      .order('submitted_at')

    if (!evaluations || !criteria) return

    const rows = []
    
    // Header
    const header = [
      'Data da Avaliação',
      'Categoria',
      'Equipe',
      'Avaliador (Nome)',
      'Avaliador (Email)'
    ]
    criteria.forEach(c => header.push(`Nota: ${c.name}`))
    header.push('Nota Total')
    header.push('Comentário')
    
    rows.push(header)

    // Data
    for (const ev of evaluations) {
      const finalScore = (ev.scores as any[]).reduce((sum, s) => sum + s.score, 0)
      const row = [
        new Date(ev.submitted_at).toLocaleString('pt-BR'),
        ev.category === 'junior' ? 'Júnior' : 'Sênior',
        (ev.team as any)?.name ?? '',
        (ev.evaluator as any)?.display_name ?? '',
        (ev.evaluator as any)?.email ?? '',
      ]
      
      // add criteria scores
      criteria.forEach(c => {
        const score = (ev.scores as any[]).find(s => s.criterion_id === c.id)
        row.push(score ? score.score : '')
      })
      
      row.push(finalScore)
      row.push(ev.comment ?? '')
      
      rows.push(row)
    }

    const csvContent = rows.map(row => 
      row.map(cell => {
        const cellStr = String(cell ?? '')
        if (cellStr.includes(',') || cellStr.includes('\n') || cellStr.includes('"')) {
          return `"${cellStr.replace(/"/g, '""')}"`
        }
        return cellStr
      }).join(',')
    ).join('\n')

    const blob = new Blob(['\ufeff' + csvContent], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `avaliacoes_${source.value.eventSlug || eventId.value}.csv`
    a.click()
    URL.revokeObjectURL(url)
  } catch (err) {
    console.error('Failed to export CSV', err)
    alert('Erro ao exportar dados.')
  } finally {
    isExporting.value = false
  }
}
</script>

<template>
  <main class="results-admin-page">
    <header class="results-header">
      <div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 1rem;">
        <div>
          <p class="eyebrow">
            Administração
          </p>
          <h1>Resultados e desempates</h1>
          <p class="intro" style="margin-bottom: 0;">
            Confira a completude, colabore com os avaliadores nos empates e publique
            cada categoria separadamente.
          </p>
        </div>
        <button
          type="button"
          class="secondary-button"
          :disabled="isExporting"
          @click="exportToCsv"
          style="white-space: nowrap;"
        >
          {{ isExporting ? 'Exportando...' : 'Exportar CSV' }}
        </button>
      </div>
    </header>

    <p v-if="accessPending || pending" class="request-status" role="status">
      Carregando resultados…
    </p>
    <p v-else-if="accessError || error" class="form-error" role="alert">
      Não foi possível carregar os resultados.
    </p>
    <p v-else-if="!isProfessor" class="form-error" role="alert">
      Somente o Professor responsável pode acessar esta área.
    </p>
    <template v-else>
      <p v-if="actionError" class="form-error" role="alert">
        {{ actionError }}
      </p>
      <p v-if="successMessage" class="form-success" role="status">
        {{ successMessage }}
      </p>

      <section
        v-for="category in categories"
        :key="category"
        class="result-category"
      >
        <header>
          <div>
            <p class="eyebrow">
              Categoria
            </p>
            <h2>{{ categoryLabel(category) }}</h2>
          </div>
          <span v-if="publication(category)" class="published-badge">
            Publicada
          </span>
        </header>

        <div class="result-progress">
          <h3>Progresso das avaliações</h3>
          <p v-if="!categoryProgress(category).length">
            Nenhuma configuração congelada nesta categoria.
          </p>
          <ul v-else>
            <li
              v-for="row in categoryProgress(category)"
              :key="row.team_id"
            >
              <strong>{{ row.team_name }}</strong>
              <span>
                {{ row.completed_evaluator_count }} de
                {{ row.required_evaluator_count }}
              </span>
              <span v-if="row.complete" class="complete-label">Completa</span>
              <span v-else class="missing-label">
                Faltam:
                {{
                  row.missing_evaluators
                    .map(item => item.display_name || 'Avaliador')
                    .join(', ')
                }}
              </span>
            </li>
          </ul>
        </div>

        <div class="private-ranking">
          <h3>Classificação administrativa</h3>
          <p v-if="!categoryRanking(category).length">
            A classificação aparecerá quando uma equipe estiver completa.
          </p>
          <ol v-else>
            <li
              v-for="row in categoryRanking(category)"
              :key="row.team_id"
            >
              <span>{{ row.score_rank }}º</span>
              <strong>{{ row.team_name }}</strong>
              <b>{{ Number(row.final_score).toFixed(2) }}</b>
            </li>
          </ol>
        </div>

        <div
          v-for="group in tieGroups(category)"
          :key="`${category}:${group.score}`"
          class="tie-card"
        >
          <div v-if="group.resolved" class="tie-audit">
            <h4>Desempate de nota {{ group.score.toFixed(2) }}</h4>
            <p><strong>Decisão registrada:</strong> {{ group.decision!.justification }}</p>
            <ol>
              <li v-for="(teamId, index) in group.decision!.ordered_team_ids" :key="teamId">
                {{ index + 1 }}º lugar do empate:
                <strong>{{ group.rows.find(r => r.team_id === teamId)?.team_name ?? 'Equipe' }}</strong>
              </li>
            </ol>
            <p class="tie-audit-meta">
              Registrado em {{ new Date(group.decision!.created_at).toLocaleString('pt-BR') }}
            </p>
          </div>
          <TieResolution
            v-else
            data-resolve-tie
            :event-id="eventId"
            :category="category"
            :displayed-score="group.score"
            :teams="group.rows.map(row => ({
              team_id: row.team_id,
              team_name: row.team_name,
            }))"
            :processing="processingAction === `resolve:${category}:${group.score}`"
            @resolve="resolveTie"
          />
        </div>

        <div class="publication-panel">
          <template v-if="publication(category)">
            <h3>Categoria publicada</h3>
            <p>
              Snapshot imutável criado em
              {{ new Date(publication(category)!.published_at).toLocaleString('pt-BR') }}.
            </p>
            <div class="publication-actions">
              <NuxtLink v-if="source.eventSlug" :to="`/resultados/${source.eventSlug}`" class="secondary-button" target="_blank">
                Ver Ranking Público ↗
              </NuxtLink>
              <button
                type="button"
                class="danger-button"
                :disabled="Boolean(processingAction)"
                @click="unpublishCategory(category)"
              >
                {{
                  processingAction === `unpublish:${category}`
                    ? 'Despublicando…'
                    : `Despublicar ${categoryLabel(category)}`
                }}
              </button>
            </div>
          </template>
          <template v-else>
            <h3 v-if="blockers(category).length">
              Publicação bloqueada
            </h3>
            <h3 v-else>
              Pronta para publicar
            </h3>
            <ul v-if="blockers(category).length">
              <li v-for="message in blockers(category)" :key="message">
                {{ message }}
              </li>
            </ul>
            <button
              type="button"
              :disabled="Boolean(processingAction) || blockers(category).length > 0"
              @click="publishCategory(category)"
            >
              {{
                processingAction === `publish:${category}`
                  ? 'Publicando…'
                  : `Publicar ${categoryLabel(category)}`
              }}
            </button>
          </template>
        </div>
      </section>
    </template>
  </main>
</template>
