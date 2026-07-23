import { flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import {
  computed,
  defineComponent,
  h,
  nextTick,
  ref,
  Suspense,
  watch,
} from 'vue'
import {
  afterAll,
  afterEach,
  beforeAll,
  beforeEach,
  describe,
  expect,
  it,
  vi,
} from 'vitest'

const EVENT_ID = '10000000-0000-4000-8000-000000000501'
const EVALUATOR_ID = '00000000-0000-4000-8000-000000000501'
const TEAM_A = '20000000-0000-4000-8000-000000000501'
const TEAM_B = '20000000-0000-4000-8000-000000000502'
const TEAM_C = '20000000-0000-4000-8000-000000000503'
const TEAM_EXTRA = '20000000-0000-4000-8000-000000000504'
const CRITERION_A = '60000000-0000-4000-8000-000000000501'
const CRITERION_B = '60000000-0000-4000-8000-000000000502'

type Result = { data: unknown, error: unknown }
type Operation = {
  table: string
  action: string
  payload?: unknown
  filters: Array<[string, unknown]>
}

const routeParams = ref<Record<string, string>>({ eventId: EVENT_ID })
const eventRoles = ref<Array<{ event_id: string, role: string }>>([])
const results = new Map<string, Result>()
const operations: Operation[] = []
const rpc = vi.fn()
const navigateTo = vi.fn()
const refresh = vi.fn()
const asyncKeys: string[] = []
let mountedHost: VueWrapper | undefined

const freeze = {
  event_id: EVENT_ID,
  category: 'junior',
  frozen_at: '2026-07-23T12:00:00.000Z',
  frozen_by: 'professor-id',
  criteria_snapshot: [
    {
      criterion_id: CRITERION_A,
      name: 'Solução',
      description: 'Qualidade da proposta',
      position: 1,
      weight: 1,
    },
    {
      criterion_id: CRITERION_B,
      name: 'Mercado',
      description: 'Potencial de adoção',
      position: 2,
      weight: 1,
    },
  ],
  evaluator_snapshot: [
    { evaluator_id: EVALUATOR_ID, display_name: 'Avaliadora' },
    { evaluator_id: 'evaluator-2', display_name: 'Avaliador 2' },
  ],
  team_snapshot: [
    {
      team_id: TEAM_A,
      name: 'Equipe A',
      category: 'junior',
      canvas_summary: { resumo: 'Resumo aprovado da equipe A' },
    },
    {
      team_id: TEAM_B,
      name: 'Equipe B',
      category: 'junior',
      canvas_summary: { resumo: 'Resumo aprovado da equipe B' },
    },
    {
      team_id: TEAM_C,
      name: 'Equipe C',
      category: 'junior',
      canvas_summary: null,
    },
  ],
}

function resultKey(table: string, action = 'select') {
  return `${table}:${action}`
}

function query(table: string) {
  const operation: Operation = {
    table,
    action: 'select',
    filters: [],
  }
  operations.push(operation)
  const builder: Record<string, unknown> = {}
  const chain = () => builder
  builder.select = chain
  builder.order = chain
  builder.limit = chain
  builder.eq = (column: string, value: unknown) => {
    operation.filters.push([column, value])
    return builder
  }
  builder.in = (column: string, value: unknown) => {
    operation.filters.push([column, value])
    return builder
  }
  builder.insert = (payload: unknown) => {
    operation.action = 'insert'
    operation.payload = payload
    return builder
  }
  builder.update = (payload: unknown) => {
    operation.action = 'update'
    operation.payload = payload
    return builder
  }
  builder.delete = () => {
    operation.action = 'delete'
    return builder
  }
  builder.single = chain
  builder.maybeSingle = chain
  builder.then = (
    resolve: (value: Result) => unknown,
    reject: (reason: unknown) => unknown,
  ) => Promise.resolve(
    results.get(resultKey(table, operation.action))
      ?? results.get(resultKey(table))
      ?? { data: [], error: null },
  ).then(resolve, reject)
  return builder
}

async function mountPage(component: unknown) {
  const Host = defineComponent({
    setup() {
      return () => h(Suspense, null, {
        default: () => h(component as never),
      })
    },
  })
  mountedHost = mount(Host, {
    attachTo: document.body,
    global: {
      stubs: {
        NuxtLink: {
          props: ['to'],
          template: '<a :href="to"><slot /></a>',
        },
      },
    },
  })
  await flushPromises()
  await nextTick()
  return mountedHost
}

function deferred<T>() {
  let resolve!: (value: T) => void
  const promise = new Promise<T>((resolvePromise) => {
    resolve = resolvePromise
  })
  return { promise, resolve }
}

function seedEvaluatorData() {
  results.set(resultKey('evaluator_assignments'), {
    data: [{
      event_id: EVENT_ID,
      evaluator_id: EVALUATOR_ID,
      category: 'junior',
    }],
    error: null,
  })
  results.set(resultKey('evaluation_freezes'), {
    data: [freeze],
    error: null,
  })
  results.set(resultKey('presentation_slots'), {
    data: [
      { event_id: EVENT_ID, category: 'junior', team_id: TEAM_A, position: 1 },
      { event_id: EVENT_ID, category: 'junior', team_id: TEAM_B, position: 2 },
      { event_id: EVENT_ID, category: 'junior', team_id: TEAM_EXTRA, position: 3 },
      { event_id: EVENT_ID, category: 'junior', team_id: TEAM_C, position: 4 },
    ],
    error: null,
  })
  results.set(resultKey('evaluations'), {
    data: [{
      event_id: EVENT_ID,
      category: 'junior',
      team_id: TEAM_A,
      evaluator_id: EVALUATOR_ID,
      submitted_at: '2026-07-23T13:00:00.000Z',
    }],
    error: null,
  })
}

describe('accessible evaluation score selector', () => {
  it('exposes real radio semantics and updates selection with keyboard focus', async () => {
    const ScoreCriterion = (
      await import('../../app/components/evaluation/ScoreCriterion.vue')
    ).default
    const wrapper = mount(ScoreCriterion, {
      attachTo: document.body,
      props: {
        criterionId: CRITERION_A,
        name: 'Solução',
        description: 'Qualidade da proposta',
        modelValue: 2,
      },
    })

    const group = wrapper.get('[role="radiogroup"]')
    const radios = wrapper.findAll('[role="radio"]')
    expect(group.attributes('aria-describedby')).toBe(
      `criterion-${CRITERION_A}-description`,
    )
    expect(radios).toHaveLength(5)
    expect(radios[1].attributes('aria-checked')).toBe('true')
    expect(radios[1].classes()).toContain('is-selected')
    expect(radios.every(item => item.classes().includes('score-option'))).toBe(true)

    radios[1].element.focus()
    await radios[1].trigger('keydown', { key: 'ArrowRight' })
    expect(wrapper.emitted('update:modelValue')?.at(-1)).toEqual([3])
    expect(document.activeElement).toBe(radios[2].element)

    await radios[2].trigger('keydown', { key: 'End' })
    expect(wrapper.emitted('update:modelValue')?.at(-1)).toEqual([5])
    expect(document.activeElement).toBe(radios[4].element)

    await radios[4].trigger('keydown', { key: 'Home' })
    expect(wrapper.emitted('update:modelValue')?.at(-1)).toEqual([1])
    expect(document.activeElement).toBe(radios[0].element)
    wrapper.unmount()
  })
})

describe('evaluation pages', () => {
  let QueuePage: unknown
  let FormPage: unknown
  let AdminPage: unknown

  beforeAll(async () => {
    const supabase = { from: query, rpc }
    vi.stubGlobal('computed', computed)
    vi.stubGlobal('definePageMeta', vi.fn())
    vi.stubGlobal('navigateTo', navigateTo)
    vi.stubGlobal('nextTick', nextTick)
    vi.stubGlobal('ref', ref)
    vi.stubGlobal('watch', watch)
    vi.stubGlobal('refreshNuxtData', refresh)
    vi.stubGlobal('useRoute', () => ({ params: routeParams.value }))
    vi.stubGlobal('useNuxtApp', () => ({ $supabase: supabase }))
    vi.stubGlobal('useCurrentAccess', () => ({
      profile: ref({
        id: EVALUATOR_ID,
        email: 'evaluator@example.test',
        display_name: 'Avaliadora',
        global_role: 'student',
      }),
      eventRoles,
      pending: ref(false),
      error: ref(null),
    }))
    vi.stubGlobal(
      'useAsyncData',
      async (key: unknown, handler: () => Promise<unknown>) => {
        const resolvedKey = typeof key === 'object' && key && 'value' in key
          ? String((key as { value: unknown }).value)
          : String(key)
        asyncKeys.push(resolvedKey)
        return {
          data: ref(await handler()),
          pending: ref(false),
          error: ref(null),
          refresh,
        }
      },
    )
    QueuePage = (
      await import('../../app/pages/app/evento/[eventId]/avaliacao/index.vue')
    ).default
    FormPage = (
      await import('../../app/pages/app/evento/[eventId]/avaliacao/[teamId].vue')
    ).default
    AdminPage = (
      await import('../../app/pages/app/evento/[eventId]/admin/avaliacao.vue')
    ).default
  })

  afterAll(() => vi.unstubAllGlobals())

  afterEach(() => {
    mountedHost?.unmount()
    mountedHost = undefined
  })

  beforeEach(() => {
    routeParams.value = { eventId: EVENT_ID }
    eventRoles.value = [{
      event_id: EVENT_ID,
      role: 'evaluator',
    }]
    results.clear()
    operations.length = 0
    asyncKeys.length = 0
    rpc.mockReset().mockResolvedValue({ data: null, error: null })
    navigateTo.mockReset().mockResolvedValue(undefined)
    refresh.mockReset().mockResolvedValue(undefined)
    seedEvaluatorData()
  })

  it('shows the frozen assigned-category queue, progress and current/next teams', async () => {
    const wrapper = await mountPage(QueuePage)

    expect(wrapper.text()).toContain('Categoria Júnior')
    expect(wrapper.text()).toContain('1 de 3 avaliações concluídas')
    expect(wrapper.get('[data-current-team]').text()).toContain('Equipe B')
    expect(wrapper.get('[data-current-team]').text()).toContain('Posição 2')
    expect(wrapper.get('[data-next-team]').text()).toContain('Equipe C')
    expect(wrapper.text()).toContain('Enviada')
    expect(asyncKeys).toContain(`evaluation-queue:${EVENT_ID}`)
    expect(operations.every(operation => (
      operation.filters.some(([column, value]) => (
        column === 'event_id' && value === EVENT_ID
      ))
    ))).toBe(true)
  })

  it('blocks queue access without a current evaluator role', async () => {
    eventRoles.value = []
    const wrapper = await mountPage(QueuePage)

    expect(wrapper.get('[role="alert"]').text()).toContain(
      'Avaliador ativo',
    )
    expect(operations).toHaveLength(0)
  })

  it('submits the exact frozen-score payload and advances to the next pending team', async () => {
    routeParams.value = { eventId: EVENT_ID, teamId: TEAM_B }
    const wrapper = await mountPage(FormPage)
    const groups = wrapper.findAll('[role="radiogroup"]')

    expect(wrapper.text()).toContain('Equipe B')
    expect(wrapper.text()).toContain('Categoria Júnior')
    expect(wrapper.text()).toContain('Resumo aprovado da equipe B')
    expect(groups).toHaveLength(2)
    await groups[0].findAll('[role="radio"]')[3].trigger('click')
    await groups[1].findAll('[role="radio"]')[4].trigger('click')
    await wrapper.get('#evaluation-comment').setValue('Ótima validação')
    await wrapper.get('form').trigger('submit')
    await flushPromises()

    expect(rpc).toHaveBeenCalledWith('submit_evaluation', {
      team_id: TEAM_B,
      scores: [
        { criterion_id: CRITERION_A, score: 4 },
        { criterion_id: CRITERION_B, score: 5 },
      ],
      comment: 'Ótima validação',
    })
    expect(navigateTo).toHaveBeenCalledWith(
      `/app/evento/${EVENT_ID}/avaliacao/${TEAM_C}`,
    )
  })

  it('preserves unsent scores and comment after a sanitized network failure', async () => {
    routeParams.value = { eventId: EVENT_ID, teamId: TEAM_B }
    rpc.mockResolvedValueOnce({
      data: null,
      error: { message: 'socket secret detail' },
    })
    const wrapper = await mountPage(FormPage)
    const groups = wrapper.findAll('[role="radiogroup"]')
    await groups[0].findAll('[role="radio"]')[1].trigger('click')
    await groups[1].findAll('[role="radio"]')[2].trigger('click')
    await wrapper.get('#evaluation-comment').setValue('Rascunho local')
    await wrapper.get('form').trigger('submit')
    await flushPromises()

    expect(wrapper.get('[role="alert"]').text()).toContain(
      'Não foi possível salvar a avaliação',
    )
    expect(wrapper.text()).not.toContain('socket secret detail')
    expect(groups[0].findAll('[role="radio"]')[1].attributes('aria-checked')).toBe('true')
    expect(
      wrapper.get<HTMLTextAreaElement>('#evaluation-comment').element.value,
    ).toBe('Rascunho local')
    expect(navigateTo).not.toHaveBeenCalled()
  })

  it('blocks rapid duplicate evaluation submission while the first request is pending', async () => {
    routeParams.value = { eventId: EVENT_ID, teamId: TEAM_B }
    const request = deferred<{ data: null, error: null }>()
    rpc.mockReturnValueOnce(request.promise)
    const wrapper = await mountPage(FormPage)
    for (const group of wrapper.findAll('[role="radiogroup"]')) {
      await group.findAll('[role="radio"]')[3].trigger('click')
    }

    await wrapper.get('form').trigger('submit')
    await wrapper.get('form').trigger('submit')
    await flushPromises()

    expect(rpc).toHaveBeenCalledOnce()
    expect(wrapper.get('button[type="submit"]').attributes()).toHaveProperty(
      'disabled',
    )
    request.resolve({ data: null, error: null })
    await flushPromises()
  })

  it('shows Professor progress per category and defaults weights to one', async () => {
    eventRoles.value = [{ event_id: EVENT_ID, role: 'professor' }]
    results.set(resultKey('evaluation_criteria'), {
      data: [{
        id: CRITERION_A,
        event_id: EVENT_ID,
        name: 'Solução',
        description: '',
        position: 1,
        active: true,
      }],
      error: null,
    })
    results.set(resultKey('criterion_weights'), {
      data: [
        {
          event_id: EVENT_ID,
          criterion_id: CRITERION_A,
          category: 'junior',
          weight: 1,
        },
        {
          event_id: EVENT_ID,
          criterion_id: CRITERION_A,
          category: 'senior',
          weight: 1,
        },
      ],
      error: null,
    })
    results.set(resultKey('event_roles'), {
      data: [{
        event_id: EVENT_ID,
        user_id: EVALUATOR_ID,
        role: 'evaluator',
        profile: { display_name: 'Avaliadora' },
      }],
      error: null,
    })
    results.set(resultKey('teams'), {
      data: [
        { id: TEAM_A, event_id: EVENT_ID, category: 'junior', status: 'approved' },
        { id: TEAM_EXTRA, event_id: EVENT_ID, category: 'junior', status: 'approved' },
        { id: TEAM_C, event_id: EVENT_ID, category: 'senior', status: 'approved' },
      ],
      error: null,
    })
    results.set(resultKey('evaluations'), {
      data: [
        {
          id: 'evaluation-1',
          event_id: EVENT_ID,
          category: 'junior',
          team_id: TEAM_A,
          evaluator_id: EVALUATOR_ID,
        },
        {
          id: 'evaluation-2',
          event_id: EVENT_ID,
          category: 'junior',
          team_id: TEAM_B,
          evaluator_id: 'evaluator-2',
        },
        {
          id: 'evaluation-post-freeze-team',
          event_id: EVENT_ID,
          category: 'junior',
          team_id: TEAM_EXTRA,
          evaluator_id: EVALUATOR_ID,
        },
        {
          id: 'evaluation-post-freeze-evaluator',
          event_id: EVENT_ID,
          category: 'junior',
          team_id: TEAM_C,
          evaluator_id: 'evaluator-3',
        },
      ],
      error: null,
    })
    results.set(resultKey('evaluation_freezes'), {
      data: [freeze],
      error: null,
    })

    const wrapper = await mountPage(AdminPage)

    expect(wrapper.text()).toContain('Peso 1')
    expect(wrapper.get('[data-progress="junior"]').text()).toContain(
      '2 de 6 avaliações concluídas',
    )
    expect(wrapper.get('[data-progress="senior"]').text()).toContain(
      'Configuração ainda não congelada',
    )
    expect(asyncKeys).toContain(`evaluation-admin:${EVENT_ID}`)
  })

  it('edits an existing criterion only before any category freeze', async () => {
    eventRoles.value = [{ event_id: EVENT_ID, role: 'professor' }]
    results.set(resultKey('evaluation_criteria'), {
      data: [{
        id: CRITERION_A,
        event_id: EVENT_ID,
        name: 'Solução',
        description: '',
        position: 1,
        active: true,
      }],
      error: null,
    })
    results.set(resultKey('criterion_weights'), { data: [], error: null })
    results.set(resultKey('evaluator_assignments'), { data: [], error: null })
    results.set(resultKey('event_roles'), { data: [], error: null })
    results.set(resultKey('teams'), { data: [], error: null })
    results.set(resultKey('evaluations'), { data: [], error: null })
    results.set(resultKey('evaluation_freezes'), { data: [], error: null })
    const wrapper = await mountPage(AdminPage)

    await wrapper.get(`#criterion-edit-name-${CRITERION_A}`)
      .setValue('Solução validada')
    await wrapper.get(`[data-action="save-criterion-${CRITERION_A}"]`)
      .trigger('click')
    await flushPromises()

    const update = operations.find(operation => (
      operation.table === 'evaluation_criteria'
      && operation.action === 'update'
    ))
    expect(update?.payload).toEqual({
      name: 'Solução validada',
      description: '',
      active: true,
    })
    expect(update?.filters).toContainEqual(['event_id', EVENT_ID])
  })

  it('scopes Professor actions by category and blocks duplicate shuffle requests', async () => {
    eventRoles.value = [{ event_id: EVENT_ID, role: 'professor' }]
    results.set(resultKey('evaluation_criteria'), { data: [], error: null })
    results.set(resultKey('criterion_weights'), { data: [], error: null })
    results.set(resultKey('event_roles'), { data: [], error: null })
    results.set(resultKey('teams'), {
      data: [{ id: TEAM_A, event_id: EVENT_ID, category: 'junior', status: 'approved' }],
      error: null,
    })
    results.set(resultKey('evaluation_freezes'), { data: [], error: null })
    results.set(resultKey('evaluations'), { data: [], error: null })
    const request = deferred<{ data: number, error: null }>()
    rpc.mockReturnValueOnce(request.promise)
    const wrapper = await mountPage(AdminPage)

    const shuffle = wrapper.get('[data-action="shuffle-junior"]')
    await shuffle.trigger('click')
    await shuffle.trigger('click')
    await flushPromises()

    expect(rpc).toHaveBeenCalledOnce()
    expect(rpc).toHaveBeenCalledWith('shuffle_presentations', {
      event_id: EVENT_ID,
      category: 'junior',
    })
    expect(shuffle.attributes()).toHaveProperty('disabled')
    request.resolve({ data: 1, error: null })
    await flushPromises()
  })
})
