import { flushPromises, mount } from '@vue/test-utils'
import { computed, defineComponent, h, nextTick, ref, Suspense } from 'vue'
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

const EVENT_ID = '10000000-0000-4000-8000-000000000601'
const TEAM_A = '20000000-0000-4000-8000-000000000601'
const TEAM_B = '20000000-0000-4000-8000-000000000602'
const rpc = vi.fn()
const refresh = vi.fn()
const eventRoles = ref([{ event_id: EVENT_ID, role: 'professor' }])
const routeParams = ref<Record<string, string>>({ eventId: EVENT_ID })
let mountedHost: ReturnType<typeof mount> | undefined

const source = {
  progress: [
    {
      event_id: EVENT_ID,
      category: 'junior',
      team_id: TEAM_A,
      team_name: 'Equipe Alpha',
      required_evaluator_count: 2,
      completed_evaluator_count: 1,
      missing_evaluators: [{ evaluator_id: 'evaluator-2', display_name: 'Avaliadora Bia' }],
      complete: false,
    },
  ],
  ranking: [
    {
      event_id: EVENT_ID,
      category: 'junior',
      team_id: TEAM_A,
      team_name: 'Equipe Alpha',
      exact_final_score: 4.504,
      final_score: 4.50,
      score_rank: 1,
    },
    {
      event_id: EVENT_ID,
      category: 'junior',
      team_id: TEAM_B,
      team_name: 'Equipe Beta',
      exact_final_score: 4.503,
      final_score: 4.50,
      score_rank: 1,
    },
  ],
  decisions: [],
  publications: [],
}

function query(table: string) {
  const payload = table === 'evaluation_progress'
    ? source.progress
    : table === 'administrative_ranking'
      ? source.ranking
      : table === 'tie_decisions'
        ? source.decisions
        : source.publications
  const builder: Record<string, unknown> = {}
  const chain = () => builder
  builder.select = chain
  builder.eq = chain
  builder.order = chain
  builder.then = (resolve: (value: unknown) => unknown) => (
    Promise.resolve({ data: payload, error: null }).then(resolve)
  )
  return builder
}

async function mountPage(component: unknown) {
  const Host = defineComponent({
    setup: () => () => h(Suspense, null, {
      default: () => h(component as never),
    }),
  })
  mountedHost = mount(Host, {
    attachTo: document.body,
    global: {
      stubs: {
        NuxtLink: { props: ['to'], template: '<a :href="to"><slot /></a>' },
      },
    },
  })
  await flushPromises()
  await nextTick()
  return mountedHost
}

describe('tie resolution controls', () => {
  it('requires justification and emits every tied team exactly once', async () => {
    const TieResolution = (
      await import('../../app/components/results/TieResolution.vue')
    ).default
    const wrapper = mount(TieResolution, {
      props: {
        eventId: EVENT_ID,
        category: 'junior',
        displayedScore: 4.5,
        teams: [
          { team_id: TEAM_A, team_name: 'Equipe Alpha' },
          { team_id: TEAM_B, team_name: 'Equipe Beta' },
        ],
        processing: false,
      },
    })

    expect(wrapper.findAll('[data-tie-team]')).toHaveLength(2)
    expect(wrapper.get('button[type="submit"]').attributes('disabled')).toBeDefined()
    await wrapper.get('[data-move-down]').trigger('click')
    await wrapper.get('textarea').setValue('Ordem acordada após deliberação.')
    await wrapper.get('form').trigger('submit')
    expect(wrapper.emitted('resolve')?.at(-1)).toEqual([{
      event_id: EVENT_ID,
      category: 'junior',
      displayed_score: 4.5,
      ordered_team_ids: [TEAM_B, TEAM_A],
      justification: 'Ordem acordada após deliberação.',
    }])
  })
})

describe('result pages', () => {
  let AdminPage: unknown
  let PublicPage: unknown

  beforeAll(async () => {
    vi.stubGlobal('computed', computed)
    vi.stubGlobal('definePageMeta', vi.fn())
    vi.stubGlobal('nextTick', nextTick)
    vi.stubGlobal('ref', ref)
    vi.stubGlobal('refreshNuxtData', refresh)
    vi.stubGlobal('useRoute', () => ({ params: routeParams.value }))
    vi.stubGlobal('useNuxtApp', () => ({
      $supabase: { from: query, rpc },
    }))
    vi.stubGlobal('useCurrentAccess', () => ({
      eventRoles,
      pending: ref(false),
      error: ref(null),
    }))
    vi.stubGlobal('useAsyncData', async (_key: unknown, handler: () => Promise<unknown>) => {
      try {
        return {
          data: ref(await handler()),
          pending: ref(false),
          error: ref(null),
          refresh,
        }
      }
      catch (caught) {
        return {
          data: ref([]),
          pending: ref(false),
          error: ref(caught),
          refresh,
        }
      }
    })
    AdminPage = (
      await import('../../app/pages/app/evento/[eventId]/admin/resultados.vue')
    ).default
    PublicPage = (
      await import('../../app/pages/resultados/[eventSlug].vue')
    ).default
  })

  afterAll(() => vi.unstubAllGlobals())
  afterEach(() => {
    mountedHost?.unmount()
    mountedHost = undefined
  })
  beforeEach(() => {
    routeParams.value = { eventId: EVENT_ID }
    rpc.mockReset().mockResolvedValue({ data: null, error: null })
    refresh.mockReset().mockResolvedValue(undefined)
  })

  it('shows completeness blockers and missing evaluator names', async () => {
    const wrapper = await mountPage(AdminPage)
    expect(wrapper.text()).toContain('Resultados e desempates')
    expect(wrapper.text()).toContain('Avaliadora Bia')
    expect(wrapper.text()).toContain('Publicação bloqueada')
    expect(wrapper.text()).toContain('Equipe Alpha')
  })

  it('guards tie and publication actions against rapid duplicate clicks', async () => {
    const pending = new Promise(() => {})
    rpc.mockReturnValue(pending)
    const wrapper = await mountPage(AdminPage)

    const resolve = wrapper.get('[data-resolve-tie] form')
    await resolve.get('textarea').setValue('Decisão conjunta dos avaliadores.')
    await resolve.trigger('submit')
    await resolve.trigger('submit')
    expect(rpc).toHaveBeenCalledTimes(1)
    expect(rpc).toHaveBeenCalledWith('resolve_tie', {
      event_id: EVENT_ID,
      category: 'junior',
      displayed_score: 4.5,
      ordered_team_ids: [TEAM_A, TEAM_B],
      justification: 'Decisão conjunta dos avaliadores.',
    })
  })

  it('publishes one ready category with the exact scoped payload only once', async () => {
    const originalProgress = source.progress[0]
    const removedRanking = source.ranking.pop()
    source.progress[0] = {
      ...originalProgress,
      completed_evaluator_count: 2,
      missing_evaluators: [],
      complete: true,
    }
    rpc.mockReturnValue(new Promise(() => {}))
    const wrapper = await mountPage(AdminPage)

    const publish = wrapper.findAll('.publication-panel button')
      .find(button => button.text().includes('Publicar Júnior'))
    expect(publish).toBeDefined()
    await publish!.trigger('click')
    await publish!.trigger('click')
    expect(rpc).toHaveBeenCalledTimes(1)
    expect(rpc).toHaveBeenCalledWith('publish_category_results', {
      event_id: EVENT_ID,
      category: 'junior',
    })

    source.progress[0] = originalProgress
    if (removedRanking) source.ranking.push(removedRanking)
  })

  it('queries anonymous results by event slug and renders categories safely', async () => {
    routeParams.value = { eventSlug: 'hackathon-ceitec-2026' }
    rpc.mockResolvedValue({
      data: [{
        event_name: 'Hackathon CEITEC',
        event_slug: 'hackathon-ceitec-2026',
        category: 'junior',
        ranking: [{ position: 1, team_name: '<img src=x onerror=alert(1)>', score: 4.5 }],
        published_at: '2026-07-23T20:00:00.000Z',
      }, {
        event_name: 'Hackathon CEITEC',
        event_slug: 'hackathon-ceitec-2026',
        category: 'senior',
        ranking: [{ position: 1, team_name: 'Equipe Sênior', score: 4.75 }],
        published_at: '2026-07-23T20:05:00.000Z',
      }],
      error: null,
    })
    const wrapper = await mountPage(PublicPage)
    expect(rpc).toHaveBeenCalledWith('get_published_results', {
      event_slug: 'hackathon-ceitec-2026',
    })
    expect(wrapper.text()).toContain('Categoria Júnior')
    expect(wrapper.text()).toContain('Categoria Sênior')
    expect(wrapper.text()).toContain('Publicado em')
    expect(wrapper.html()).not.toContain('<img src=x')
  })

  it('shows a neutral not-published state for an empty slug lookup', async () => {
    routeParams.value = { eventSlug: 'evento-sem-publicacao' }
    rpc.mockResolvedValue({ data: [], error: null })
    const wrapper = await mountPage(PublicPage)
    expect(wrapper.text()).toContain('Resultados ainda não publicados')
  })

  it('shows a sanitized retry message when public loading fails', async () => {
    routeParams.value = { eventSlug: 'evento-com-falha' }
    rpc.mockResolvedValue({
      data: null,
      error: { message: '<script>segredo interno</script>' },
    })
    const wrapper = await mountPage(PublicPage)
    expect(wrapper.text()).toContain('Não foi possível carregar os resultados')
    expect(wrapper.text()).not.toContain('segredo interno')
  })
})
