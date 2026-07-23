import { flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import { computed, defineComponent, h, nextTick, ref, Suspense } from 'vue'
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

const EVENT_ID = '10000000-0000-4000-8000-000000000001'
const USER_ID = '00000000-0000-4000-8000-000000000001'

const profile = ref({
  id: USER_ID,
  email: 'lider@example.test',
  display_name: 'Líder',
  global_role: 'student' as const,
  created_at: '2026-07-23T00:00:00.000Z',
  updated_at: '2026-07-23T00:00:00.000Z',
})
const eventRoles = ref<Array<{ event_id: string, role: 'professor' }>>([])
const testState = {
  rpc: vi.fn(),
  refresh: vi.fn(),
  teamFetch: vi.fn(),
  queueFetch: vi.fn(),
  confirm: vi.fn(),
}

let mountedHost: VueWrapper | undefined
let TeamPage: Awaited<ReturnType<typeof import('../../app/pages/app/evento/[eventId]/equipe.vue')>>['default']
let QueuePage: Awaited<ReturnType<typeof import('../../app/pages/app/evento/[eventId]/equipes.vue')>>['default']

function deferred<T>() {
  let resolve!: (value: T) => void
  const promise = new Promise<T>((resolvePromise) => { resolve = resolvePromise })
  return { promise, resolve }
}

async function mountPage(component: typeof TeamPage | typeof QueuePage) {
  const Host = defineComponent({
    setup() {
      return () => h(Suspense, null, { default: () => h(component) })
    },
  })
  mountedHost = mount(Host, { attachTo: document.body })
  await flushPromises()
  await nextTick()
  return mountedHost
}

describe('team page interactions', () => {
  beforeAll(async () => {
    const supabase = {
      rpc: testState.rpc,
      from(table: string) {
        void table
        return {
          select: () => ({
            eq: () => ({
              eq: () => ({
                maybeSingle: testState.teamFetch,
                order: testState.queueFetch,
              }),
            }),
          }),
        }
      },
    }
    vi.stubGlobal('computed', computed)
    vi.stubGlobal('definePageMeta', vi.fn())
    vi.stubGlobal('nextTick', nextTick)
    vi.stubGlobal('ref', ref)
    vi.stubGlobal('useRoute', () => ({ params: { eventId: EVENT_ID } }))
    vi.stubGlobal('useNuxtApp', () => ({ $supabase: supabase }))
    vi.stubGlobal('useCurrentAccess', () => ({
      profile,
      eventRoles,
      pending: ref(false),
      error: ref(null),
      refresh: vi.fn(),
    }))
    vi.stubGlobal('refreshNuxtData', testState.refresh)
    vi.stubGlobal('useAsyncData', async (_key: unknown, handler: () => Promise<unknown>) => ({
      data: ref(await handler()), pending: ref(false), error: ref(null),
    }))
    vi.stubGlobal('confirm', testState.confirm)
    TeamPage = (await import('../../app/pages/app/evento/[eventId]/equipe.vue')).default
    QueuePage = (await import('../../app/pages/app/evento/[eventId]/equipes.vue')).default
  })

  afterAll(() => vi.unstubAllGlobals())
  afterEach(() => { mountedHost?.unmount(); mountedHost = undefined })

  beforeEach(() => {
    profile.value = {
      id: USER_ID, email: 'lider@example.test', display_name: 'Líder', global_role: 'student',
      created_at: '2026-07-23T00:00:00.000Z', updated_at: '2026-07-23T00:00:00.000Z',
    }
    eventRoles.value = []
    testState.rpc.mockReset().mockResolvedValue({ data: null, error: null })
    testState.refresh.mockReset().mockResolvedValue(undefined)
    testState.teamFetch.mockReset().mockResolvedValue({ data: null, error: null })
    testState.queueFetch.mockReset().mockResolvedValue({ data: [], error: null })
    testState.confirm.mockReset().mockReturnValue(true)
  })

  it('validates form fields inline before calling create_team', async () => {
    const wrapper = await mountPage(TeamPage)
    await wrapper.get('form').trigger('submit')
    await flushPromises()

    expect(testState.rpc).not.toHaveBeenCalled()
    expect(wrapper.get('#team-name-error').text()).toContain('Informe um nome')
    expect(wrapper.get('#member-0-enrollment-error').text()).toContain('Informe a matrícula')
    expect(wrapper.get<HTMLInputElement>('#team-name').attributes('aria-invalid')).toBe('true')
  })

  it('sends typed event-scoped member payload once while create_team is processing', async () => {
    const pending = deferred<{ data: null, error: null }>()
    testState.rpc.mockReturnValueOnce(pending.promise)
    const wrapper = await mountPage(TeamPage)
    await wrapper.get('#team-name').setValue('Equipe Átomo')
    await wrapper.get('#member-0-name').setValue('Líder')
    await wrapper.get('#member-0-email').setValue('lider@example.test')
    await wrapper.get('#member-0-enrollment').setValue('M-1')

    await wrapper.get('form').trigger('submit')
    await wrapper.get('form').trigger('submit')
    await flushPromises()

    expect(testState.rpc).toHaveBeenCalledOnce()
    expect(testState.rpc).toHaveBeenCalledWith('create_team', {
      event_id: EVENT_ID,
      name: 'Equipe Átomo',
      category: 'junior',
      members: [{ name: 'Líder', email: 'lider@example.test', enrollment: 'M-1' }],
    })
    expect(wrapper.get('button[type="submit"]').attributes()).toHaveProperty('disabled')

    pending.resolve({ data: null, error: null })
    await flushPromises()
    expect(testState.refresh).toHaveBeenCalled()
  })

  it('maps duplicate seat failures to an actionable Portuguese message', async () => {
    testState.rpc.mockResolvedValueOnce({ data: null, error: { message: 'duplicate key value' } })
    const wrapper = await mountPage(TeamPage)
    await wrapper.get('#team-name').setValue('Equipe Átomo')
    await wrapper.get('#member-0-name').setValue('Ana')
    await wrapper.get('#member-0-email').setValue('ana@example.test')
    await wrapper.get('#member-0-enrollment').setValue('M-1')
    await wrapper.get('form').trigger('submit')
    await flushPromises()

    expect(wrapper.get('[role="alert"]').text()).toContain('e-mail ou matrícula já está em uso')
    expect(wrapper.text()).not.toContain('duplicate key value')
  })

  it('shows join decisions only to the leader and calls decide_team_join', async () => {
    testState.teamFetch.mockResolvedValueOnce({
      data: {
        id: 'team-1', event_id: EVENT_ID, leader_id: USER_ID, name: 'Equipe Átomo', category: 'junior', status: 'pending',
        created_at: '2026-07-23T00:00:00.000Z', decided_at: null, decided_by: null,
        members: [{ id: 'member-1', name: 'Ana', email: 'ana@example.test', enrollment: 'M-1', status: 'join_requested', event_id: EVENT_ID, team_id: 'team-1', user_id: null, approved_by: null, created_at: '2026-07-23T00:00:00.000Z' }],
      }, error: null,
    })
    const wrapper = await mountPage(TeamPage)
    await wrapper.get('[data-member-action="approve"]').trigger('click')
    await flushPromises()

    expect(testState.rpc).toHaveBeenCalledWith('decide_team_join', { member_id: 'member-1', approve: true })
  })

  it('guards the professor queue and requires confirmation before rejection', async () => {
    const forbidden = await mountPage(QueuePage)
    expect(forbidden.get('[role="alert"]').text()).toContain('Professor responsável')
    expect(testState.rpc).not.toHaveBeenCalled()
    forbidden.unmount()
    mountedHost = undefined

    eventRoles.value = [{ event_id: EVENT_ID, role: 'professor' }]
    testState.queueFetch.mockResolvedValueOnce({
      data: [{ id: 'team-1', event_id: EVENT_ID, name: 'Equipe Átomo', category: 'senior', status: 'pending', leader_id: USER_ID, created_at: '2026-07-23T00:00:00.000Z', decided_at: null, decided_by: null, members: [{ id: 'member-1' }] }], error: null,
    })
    const wrapper = await mountPage(QueuePage)
    testState.confirm.mockReturnValueOnce(false)
    await wrapper.get('[data-team-action="reject"]').trigger('click')
    expect(testState.rpc).not.toHaveBeenCalled()

    await wrapper.get('[data-team-action="approve"]').trigger('click')
    await flushPromises()
    expect(testState.rpc).toHaveBeenCalledWith('decide_team', { team_id: 'team-1', decision: 'approved' })
    expect(wrapper.get('[role="status"]').text()).toContain('Equipe aprovada')
  })

  it('announces professor decision failures without exposing database details', async () => {
    eventRoles.value = [{ event_id: EVENT_ID, role: 'professor' }]
    testState.queueFetch.mockResolvedValueOnce({
      data: [{ id: 'team-1', event_id: EVENT_ID, name: 'Equipe Átomo', category: 'senior', status: 'pending', leader_id: USER_ID, created_at: '2026-07-23T00:00:00.000Z', decided_at: null, decided_by: null, members: [] }], error: null,
    })
    testState.rpc.mockResolvedValueOnce({ data: null, error: { message: 'permission denied' } })
    const wrapper = await mountPage(QueuePage)
    await wrapper.get('[data-team-action="approve"]').trigger('click')
    await flushPromises()

    expect(wrapper.get('[role="alert"]').text()).toContain('Não foi possível registrar a decisão')
    expect(wrapper.text()).not.toContain('permission denied')
  })
})
