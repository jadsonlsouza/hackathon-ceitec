import { flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import { computed, defineComponent, h, nextTick, ref, Suspense, watch } from 'vue'
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

const EVENT_ID = 'event-1'
const ACTIVITY_ID = 'activity-1'
const TEAM_ID = 'team-1'
const SUBMISSION_ID = 'submission-1'
const USER_ID = 'user-1'

type Result = { data: unknown, error: unknown }
type Operation = { table: string, action: string, payload?: unknown, filters: Array<[string, unknown]> }

const profile = ref({
  id: USER_ID, email: 'pessoa@example.test', display_name: 'Pessoa', global_role: 'student',
  created_at: '2026-07-23T00:00:00.000Z', updated_at: '2026-07-23T00:00:00.000Z',
})
const eventRoles = ref<Array<{ event_id: string, role: 'professor' | 'monitor' }>>([])
const routeParams = { eventId: EVENT_ID, activityId: ACTIVITY_ID }
const results = new Map<string, Result>()
const operations: Operation[] = []
const rpc = vi.fn()
const refresh = vi.fn()
const channelOn = vi.fn()
const subscribe = vi.fn()
const removeChannel = vi.fn()
let mountedHost: VueWrapper | undefined

function resultKey(table: string, action = 'select') {
  return `${table}:${action}`
}

function query(table: string) {
  const operation: Operation = { table, action: 'select', filters: [] }
  let singleResult = false
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
  builder.maybeSingle = () => {
    singleResult = true
    return builder
  }
  builder.single = () => {
    singleResult = true
    return builder
  }
  builder.then = (resolve: (value: Result) => unknown, reject: (reason: unknown) => unknown) => (
    Promise.resolve(results.get(resultKey(table, operation.action)) ?? { data: null, error: null })
      .then((result) => {
        if (!singleResult || !Array.isArray(result.data)) return result
        const blockId = operation.filters.find(([column]) => column === 'block_id')?.[1]
        return {
          ...result,
          data: blockId
            ? result.data.find(row => (row as { block_id?: unknown }).block_id === blockId) ?? null
            : result.data[0] ?? null,
        }
      })
      .then(resolve, reject)
  )
  return builder
}

async function mountPage(component: unknown) {
  const Host = defineComponent({
    setup() {
      return () => h(Suspense, null, { default: () => h(component as never) })
    },
  })
  mountedHost = mount(Host, { attachTo: document.body })
  await flushPromises()
  await nextTick()
  return mountedHost
}

beforeAll(() => {
  channelOn.mockImplementation(function (this: unknown) { return this })
  subscribe.mockImplementation(function (this: unknown) { return this })
  const supabase = {
    rpc,
    from: query,
    channel: vi.fn(() => ({ on: channelOn, subscribe })),
    removeChannel,
  }
  vi.stubGlobal('computed', computed)
  vi.stubGlobal('definePageMeta', vi.fn())
  vi.stubGlobal('nextTick', nextTick)
  vi.stubGlobal('ref', ref)
  vi.stubGlobal('watch', watch)
  vi.stubGlobal('useRoute', () => ({ params: routeParams }))
  vi.stubGlobal('useNuxtApp', () => ({ $supabase: supabase }))
  vi.stubGlobal('useCurrentAccess', () => ({
    profile, eventRoles, pending: ref(false), error: ref(null), refresh: vi.fn(),
  }))
  vi.stubGlobal('refreshNuxtData', refresh)
  vi.stubGlobal('useAsyncData', async (_key: unknown, handler: () => Promise<unknown>) => ({
    data: ref(await handler()), pending: ref(false), error: ref(null), refresh: handler,
  }))
})

afterAll(() => vi.unstubAllGlobals())
afterEach(() => {
  mountedHost?.unmount()
  mountedHost = undefined
})

beforeEach(() => {
  vi.useRealTimers()
  results.clear()
  operations.length = 0
  rpc.mockReset().mockResolvedValue({ data: null, error: null })
  refresh.mockReset().mockResolvedValue(undefined)
  channelOn.mockClear()
  removeChannel.mockReset().mockResolvedValue('ok')
  eventRoles.value = []
  results.set(resultKey('teams'), {
    data: { id: TEAM_ID, event_id: EVENT_ID, status: 'approved', category: 'junior' }, error: null,
  })
  results.set(resultKey('canvas_activities'), {
    data: {
      id: ACTIVITY_ID,
      event_id: EVENT_ID,
      title: 'Canvas principal',
      instructions: 'Preencha em equipe.',
      opens_at: '2020-01-01T00:00:00.000Z',
      due_at: '2099-01-01T00:00:00.000Z',
      published: true,
      allow_resubmission: true,
      categories: ['junior'],
      blocks: [{ id: 'block-1', title: 'Problema', prompt: '', position: 1, max_items: null }],
    },
    error: null,
  })
  results.set(resultKey('submissions'), {
    data: { id: SUBMISSION_ID, event_id: EVENT_ID, activity_id: ACTIVITY_ID, team_id: TEAM_ID, status: 'draft', revision: 1 },
    error: null,
  })
  results.set(resultKey('submission_answers'), {
    data: [{ submission_id: SUBMISSION_ID, block_id: 'block-1', content: { text: 'Rascunho' }, version: 1 }],
    error: null,
  })
})

describe('student Canvas page', () => {
  it('gates submit while a block is saving and prevents duplicate submission actions', async () => {
    let resolveDecision!: (value: Result) => void
    const pendingDecision = new Promise<Result>(resolve => { resolveDecision = resolve })
    rpc.mockReturnValueOnce(pendingDecision)
    const ActivityPage = (await import('../../app/pages/app/evento/[eventId]/atividades/[activityId].vue')).default
    const wrapper = await mountPage(ActivityPage)
    const editor = wrapper.findComponent({ name: 'CanvasBlockEditor' })
    const submit = wrapper.get('[data-action="submit-canvas"]')

    expect(submit.attributes('disabled')).toBeUndefined()
    await editor.get('textarea').setValue('Edição ainda no debounce')
    await nextTick()
    expect(submit.attributes()).toHaveProperty('disabled')

    editor.vm.$emit('state-change', 'block-1', 'saved')
    await nextTick()
    editor.vm.$emit('state-change', 'block-1', 'saving')
    await nextTick()
    expect(submit.attributes()).toHaveProperty('disabled')

    editor.vm.$emit('state-change', 'block-1', 'saved')
    await nextTick()
    await submit.trigger('click')
    await submit.trigger('click')
    resolveDecision({ data: { status: 'submitted' }, error: null })
    await flushPromises()

    expect(rpc).toHaveBeenCalledOnce()
    expect(rpc).toHaveBeenCalledWith('submit_canvas', { submission_id: SUBMISSION_ID })
  })

  it('keeps unsaved content in place when Realtime announces a remote change', async () => {
    const ActivityPage = (await import('../../app/pages/app/evento/[eventId]/atividades/[activityId].vue')).default
    const wrapper = await mountPage(ActivityPage)
    const editor = wrapper.findComponent({ name: 'CanvasBlockEditor' })
    editor.vm.$emit('state-change', 'block-1', 'idle')
    await nextTick()

    const callback = channelOn.mock.calls[0]?.[2] as (() => void)
    callback()
    await nextTick()

    expect(wrapper.get('[data-remote-update]').text()).toContain('atualização de outra pessoa')
    expect(refresh).not.toHaveBeenCalled()
  })

  it('shows an approved review status immediately from the scoped submission event', async () => {
    const ActivityPage = (await import('../../app/pages/app/evento/[eventId]/atividades/[activityId].vue')).default
    const wrapper = await mountPage(ActivityPage)
    const callback = channelOn.mock.calls.find(call => call[1]?.table === 'submissions')?.[2] as ((payload: unknown) => void)

    callback({
      table: 'submissions',
      new: { id: SUBMISSION_ID, event_id: EVENT_ID, status: 'approved', revision: 1 },
    })
    await nextTick()

    expect(wrapper.text()).toContain('Status: Aprovado')
  })

  it('reloads only the conflicted block and preserves another pending local edit', async () => {
    results.set(resultKey('canvas_activities'), {
      data: {
        id: ACTIVITY_ID,
        event_id: EVENT_ID,
        title: 'Canvas principal',
        instructions: 'Preencha em equipe.',
        opens_at: '2020-01-01T00:00:00.000Z',
        due_at: '2099-01-01T00:00:00.000Z',
        published: true,
        allow_resubmission: true,
        categories: ['junior'],
        blocks: [
          { id: 'block-1', key: 'problema', title: 'Problema', prompt: '', position: 1, max_items: null },
          { id: 'block-2', key: 'solucao', title: 'Solução', prompt: '', position: 2, max_items: null },
        ],
      },
      error: null,
    })
    results.set(resultKey('submission_answers'), {
      data: [
        { submission_id: SUBMISSION_ID, block_id: 'block-1', content: { text: 'Versão remota' }, version: 4 },
        { submission_id: SUBMISSION_ID, block_id: 'block-2', content: { text: 'Versão remota que não deve entrar' }, version: 8 },
      ],
      error: null,
    })
    const ActivityPage = (await import('../../app/pages/app/evento/[eventId]/atividades/[activityId].vue')).default
    const wrapper = await mountPage(ActivityPage)
    const editors = wrapper.findAllComponents({ name: 'CanvasBlockEditor' })
    vi.useFakeTimers()

    await editors[1].get('textarea').setValue('Edição local pendente')
    editors[0].vm.$emit('state-change', 'block-1', 'conflict')
    editors[0].vm.$emit('reload-latest', 'block-1')
    await flushPromises()

    const refreshedEditors = wrapper.findAllComponents({ name: 'CanvasBlockEditor' })
    expect(refreshedEditors[0].get<HTMLTextAreaElement>('textarea').element.value).toBe('Versão remota')
    expect(refreshedEditors[1].get<HTMLTextAreaElement>('textarea').element.value).toBe('Edição local pendente')
    expect(wrapper.get('[data-action="submit-canvas"]').attributes()).toHaveProperty('disabled')
    const targetedQuery = operations.find(operation => (
      operation.table === 'submission_answers'
      && operation.filters.some(([column, value]) => column === 'block_id' && value === 'block-1')
    ))
    expect(targetedQuery).toBeDefined()

    await refreshedEditors[0].get('textarea').setValue('Edição após recarregar')
    await vi.advanceTimersByTimeAsync(700)
    expect(rpc).toHaveBeenCalledWith('save_canvas_answer', expect.objectContaining({
      block_id: 'block-1',
      expected_version: 4,
    }))
    vi.useRealTimers()
  })

  it('shows returned feedback and refreshes the latest review without touching draft answers', async () => {
    results.set(resultKey('submissions'), {
      data: { id: SUBMISSION_ID, event_id: EVENT_ID, activity_id: ACTIVITY_ID, team_id: TEAM_ID, status: 'returned', revision: 1 },
      error: null,
    })
    results.set(resultKey('submission_reviews'), {
      data: [{
        id: 'review-1',
        submission_id: SUBMISSION_ID,
        decision: 'returned',
        feedback: 'Detalhe melhor a validação.',
        created_at: '2026-07-23T12:00:00.000Z',
      }],
      error: null,
    })
    const ActivityPage = (await import('../../app/pages/app/evento/[eventId]/atividades/[activityId].vue')).default
    const wrapper = await mountPage(ActivityPage)
    expect(wrapper.text()).toContain('Detalhe melhor a validação.')

    results.set(resultKey('submission_reviews'), {
      data: [{
        id: 'review-2',
        submission_id: SUBMISSION_ID,
        decision: 'approved',
        feedback: null,
        created_at: '2026-07-23T13:00:00.000Z',
      }],
      error: null,
    })
    const callback = channelOn.mock.calls.find(call => call[1]?.table === 'submissions')?.[2] as ((payload: unknown) => void)
    callback({
      table: 'submissions',
      new: { id: SUBMISSION_ID, event_id: EVENT_ID, status: 'approved', revision: 1 },
    })
    await flushPromises()

    expect(wrapper.text()).toContain('Aprovado sem feedback adicional.')
    expect(wrapper.find('textarea').exists()).toBe(true)
    expect(wrapper.get<HTMLTextAreaElement>('textarea').element.value).toBe('Rascunho')
  })
})

describe('activity list', () => {
  it('groups activities by time window and shows the team submission status', async () => {
    results.set(resultKey('canvas_activities'), {
      data: [
        { id: 'open', event_id: EVENT_ID, title: 'Aberta', opens_at: '2020-01-01T00:00:00.000Z', due_at: '2099-01-01T00:00:00.000Z' },
        { id: 'upcoming', event_id: EVENT_ID, title: 'Futura', opens_at: '2098-01-01T00:00:00.000Z', due_at: '2099-01-01T00:00:00.000Z' },
        { id: 'closed', event_id: EVENT_ID, title: 'Encerrada', opens_at: '2019-01-01T00:00:00.000Z', due_at: '2020-01-01T00:00:00.000Z' },
      ],
      error: null,
    })
    results.set(resultKey('submissions'), {
      data: [{ activity_id: 'open', status: 'returned' }],
      error: null,
    })
    const ListPage = (await import('../../app/pages/app/evento/[eventId]/atividades/index.vue')).default
    const wrapper = await mountPage(ListPage)

    expect(wrapper.text()).toContain('Abertas agora')
    expect(wrapper.text()).toContain('Em breve')
    expect(wrapper.text()).toContain('Encerradas')
    expect(wrapper.text()).toContain('Devolvido para ajustes')
    expect(wrapper.get('a[href$="/atividades/open"]').exists()).toBe(true)
  })
})

describe('Professor Canvas builder', () => {
  it('validates the date window and creates a template with ordered blocks and activity options', async () => {
    eventRoles.value = [{ event_id: EVENT_ID, role: 'professor' }]
    results.set(resultKey('canvas_activities'), { data: [], error: null })
    results.set(resultKey('canvas_templates'), { data: [], error: null })
    results.set(resultKey('canvas_templates', 'insert'), { data: { id: 'template-1' }, error: null })
    results.set(resultKey('canvas_template_blocks', 'insert'), { data: null, error: null })
    results.set(resultKey('canvas_activities', 'insert'), { data: { id: 'new-activity' }, error: null })
    const BuilderPage = (await import('../../app/pages/app/evento/[eventId]/admin/canvas.vue')).default
    const wrapper = await mountPage(BuilderPage)

    await wrapper.get('#canvas-title').setValue('Canvas de validação')
    await wrapper.get('#canvas-block-title-0').setValue('Problema')
    await wrapper.get('#canvas-block-prompt-0').setValue('Descreva com evidências.')
    await wrapper.get('#canvas-opens-at').setValue('2026-08-10T10:00')
    await wrapper.get('#canvas-due-at').setValue('2026-08-10T09:00')
    await wrapper.get('form').trigger('submit')
    await flushPromises()
    expect(wrapper.get('[role="alert"]').text()).toContain('posterior')
    expect(operations.filter(operation => operation.action === 'insert')).toHaveLength(0)

    await wrapper.get('#canvas-due-at').setValue('2026-08-11T10:00')
    await wrapper.get('form').trigger('submit')
    await flushPromises()

    const blockInsert = operations.find(operation => operation.table === 'canvas_template_blocks' && operation.action === 'insert')
    const activityInsert = operations.find(operation => operation.table === 'canvas_activities' && operation.action === 'insert')
    expect(blockInsert?.payload).toEqual([expect.objectContaining({
      template_id: 'template-1', title: 'Problema', position: 1,
    })])
    expect(activityInsert?.payload).toEqual(expect.objectContaining({
      event_id: EVENT_ID,
      template_id: 'template-1',
      categories: ['junior'],
      allow_resubmission: true,
    }))
  })
})

describe('review queue', () => {
  it('filters, claims atomically once, and opens the immutable submitted revision', async () => {
    eventRoles.value = [{ event_id: EVENT_ID, role: 'monitor' }]
    results.set(resultKey('submissions'), {
      data: [{
        id: SUBMISSION_ID,
        event_id: EVENT_ID,
        status: 'submitted',
        revision: 1,
        team: { id: TEAM_ID, name: 'Equipe Átomo', category: 'junior' },
        activity: {
          id: ACTIVITY_ID,
          title: 'Canvas principal',
          blocks: [{ id: 'b1', key: 'problema', title: 'Problema', prompt: 'Explique.', position: 1 }],
        },
        revisions: [{ revision: 1, snapshot: { problema: { text: 'Imutável' } } }],
      }],
      error: null,
    })
    let resolveClaim!: (value: Result) => void
    rpc.mockReturnValueOnce(new Promise(resolve => { resolveClaim = resolve }))
    const ReviewPage = (await import('../../app/pages/app/evento/[eventId]/revisoes.vue')).default
    const wrapper = await mountPage(ReviewPage)

    await wrapper.get('[data-action="claim-review"]').trigger('click')
    await wrapper.get('[data-action="claim-review"]').trigger('click')
    expect(rpc).toHaveBeenCalledOnce()
    expect(rpc).toHaveBeenCalledWith('claim_review', { submission_id: SUBMISSION_ID })

    resolveClaim({ data: { status: 'in_review' }, error: null })
    await flushPromises()
    expect(wrapper.text()).toContain('Imutável')
    expect(wrapper.text()).toContain('Explique.')
    expect(wrapper.get('#review-category-filter').exists()).toBe(true)
    expect(wrapper.get('#review-status-filter').exists()).toBe(true)
  })
})
