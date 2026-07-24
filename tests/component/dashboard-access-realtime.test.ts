// @vitest-environment happy-dom
import { flushPromises, mount } from '@vue/test-utils'
import { computed, defineComponent, h, nextTick, reactive, ref, watch } from 'vue'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import DashboardNavigation from '../../app/components/dashboard/DashboardNavigation.vue'
import { useCurrentAccess } from '../../app/composables/useCurrentAccess'
import { useDashboardEventContext } from '../../app/composables/useDashboardEventContext'

const EVENT_A = '10000000-0000-4000-8000-000000000901'
const EVENT_B = '10000000-0000-4000-8000-000000000902'
let lastAsyncWatchSources: unknown[] = []

interface FakeRole {
  event_id: string
  role: 'professor' | 'monitor' | 'evaluator'
  user_id: string
  categories: string[]
  approved_by: string
  approved_at: string
}

interface ChannelHandler {
  type: string
  config: { event: string, table?: string }
  callback: (payload: unknown) => void
}

function makeClient() {
  let currentUserId: string | null = 'user-a'
  let globalRole: 'student' | 'global_admin' = 'student'
  const roles = new Map<string, FakeRole[]>()
  const teamEvents = new Map<string, string[]>()
  const teamStatuses = new Map<string, 'pending' | 'approved' | 'rejected'>()
  const emails = new Map<string, string>()
  const selectCounts = new Map<string, number>()
  const authCallbacks = new Set<(event: string, session: unknown) => void>()
  const channels: Array<{
    name: string
    handlers: ChannelHandler[]
    active: boolean
    on: (type: string, config: ChannelHandler['config'], callback: ChannelHandler['callback']) => unknown
    subscribe: () => unknown
  }> = []
  const removed: unknown[] = []
  const unsubscribed = vi.fn()
  let deferNetwork = false
  let deferredResolvers: Array<() => void> = []
  let getUserCount = 0
  const failures = new Map<string, number>()

  roles.set('user-a', [])
  roles.set('user-b', [])
  teamEvents.set('user-a', [])
  teamEvents.set('user-b', [])
  emails.set('user-a', 'leader+one,(draft)@example.test')
  emails.set('user-b', 'user-b@example.test')

  function profileFor(userId: string) {
    return {
      id: userId,
      email: emails.get(userId) ?? `${userId}@example.test`,
      display_name: userId,
      global_role: globalRole,
      created_at: '2026-07-23T00:00:00Z',
      updated_at: '2026-07-23T00:00:00Z',
    }
  }

  function resolved<T>(value: T) {
    const promise = deferNetwork
      ? new Promise<T>((resolve) => {
          deferredResolvers.push(() => resolve(value))
        })
      : Promise.resolve(value)
    return {
      single: () => promise,
      then: promise.then.bind(promise),
    }
  }

  function takeFailure(table: string) {
    const remaining = failures.get(table) ?? 0
    if (remaining === 0) return null
    failures.set(table, remaining - 1)
    return new Error(`transient ${table} failure`)
  }

  const client = {
    auth: {
      async getUser() {
        getUserCount += 1
        return resolved({
          data: { user: currentUserId ? { id: currentUserId } : null },
          error: null,
        })
      },
      onAuthStateChange(callback: (event: string, session: unknown) => void) {
        authCallbacks.add(callback)
        return {
          data: {
            subscription: {
              unsubscribe: () => {
                authCallbacks.delete(callback)
                unsubscribed()
              },
            },
          },
        }
      },
    },
    from(table: string) {
      return {
        select() {
          selectCounts.set(table, (selectCounts.get(table) ?? 0) + 1)
          const transientError = takeFailure(table)
          if (table === 'teams') {
            return resolved({
              data: transientError
                ? null
                : (teamEvents.get(currentUserId ?? '') ?? []).map(event_id => ({
                    id: `team-${event_id}`,
                    event_id,
                    status: teamStatuses.get(event_id) ?? 'approved',
                  })),
              error: transientError,
            })
          }
          if (table === 'events') {
            return resolved({
              data: null,
              count: transientError ? null : 1,
              error: transientError,
            })
          }
          return {
            eq() {
              return resolved(
                transientError
                  ? { data: null, error: transientError }
                  : table === 'profiles'
                    ? { data: currentUserId ? profileFor(currentUserId) : null, error: null }
                    : { data: [...(roles.get(currentUserId ?? '') ?? [])], error: null },
              )
            },
          }
        },
      }
    },
    channel(name: string) {
      const channel = {
        name,
        handlers: [] as ChannelHandler[],
        active: true,
        on(type: string, config: ChannelHandler['config'], callback: ChannelHandler['callback']) {
          channel.handlers.push({ type, config, callback })
          return channel
        },
        subscribe() {
          return channel
        },
      }
      channels.push(channel)
      return channel
    },
    async removeChannel(channel: unknown) {
      if (channel && typeof channel === 'object' && 'active' in channel) {
        channel.active = false
      }
      removed.push(channel)
      return 'ok'
    },
  }

  return {
    client,
    roles,
    teamEvents,
    teamStatuses,
    emails,
    selectCounts,
    channels,
    removed,
    unsubscribed,
    get getUserCount() {
      return getUserCount
    },
    deferNetwork() {
      deferNetwork = true
    },
    releaseNetwork() {
      deferNetwork = false
      const resolvers = deferredResolvers
      deferredResolvers = []
      for (const resolve of resolvers) resolve()
    },
    failNext(table: string) {
      failures.set(table, (failures.get(table) ?? 0) + 1)
    },
    setGlobalRole(role: 'student' | 'global_admin') {
      globalRole = role
    },
    async emit(table: string, event: 'INSERT' | 'UPDATE' | 'DELETE') {
      for (const channel of channels) {
        if (!channel.active) continue
        for (const handler of channel.handlers) {
          if (
            handler.type === 'postgres_changes'
            && handler.config.table === table
            && (handler.config.event === '*' || handler.config.event === event)
          ) handler.callback({ eventType: event })
        }
      }
      await flushPromises()
      await nextTick()
    },
    async setUser(userId: string | null) {
      currentUserId = userId
      const event = userId ? 'SIGNED_IN' : 'SIGNED_OUT'
      for (const callback of authCallbacks) {
        callback(event, userId ? { user: { id: userId } } : null)
      }
      await flushPromises()
      await nextTick()
    },
  }
}

const NuxtLink = {
  inheritAttrs: false,
  props: ['to'],
  template: '<a v-bind="$attrs" :href="to"><slot /></a>',
}

function dashboardHarness() {
  return defineComponent({
    setup() {
      const context = useDashboardEventContext()
      return () => h('div', {
        'data-current-event': context.currentEventId.value ?? '',
      }, [
        h(DashboardNavigation, {
          profile: context.profile.value,
          eventRoles: context.eventRoles.value,
          currentEventId: context.currentEventId.value,
          teamEventIds: context.teamEventIds.value,
          currentPath: '/app',
        }),
      ])
    },
  })
}

function dashboardShellHarness() {
  return defineComponent({
    setup() {
      const context = useDashboardEventContext()
      return () => h('div', [
        context.pending.value || context.contextPending.value
          ? h('p', { 'data-loading': '' }, 'Carregando')
          : context.error.value || context.contextError.value
            ? h('p', { 'data-error': '' }, 'Falha')
          : h(DashboardNavigation, {
              profile: context.profile.value,
              eventRoles: context.eventRoles.value,
              currentEventId: context.currentEventId.value,
              teamEventIds: context.teamEventIds.value,
              currentPath: '/app',
            }),
      ])
    },
  })
}

describe('dashboard access lifecycle', () => {
  let fake: ReturnType<typeof makeClient>
  const route = reactive<{ path: string, params: { eventId?: string } }>({
    path: '/app',
    params: {},
  })

  beforeEach(() => {
    fake = makeClient()
    route.path = '/app'
    delete route.params.eventId
    lastAsyncWatchSources = []
    vi.stubGlobal('useNuxtApp', () => ({ $supabase: fake.client }))
    vi.stubGlobal('useRoute', () => route)
    vi.stubGlobal('useCurrentAccess', useCurrentAccess)
    vi.stubGlobal('computed', computed)
    vi.stubGlobal('definePageMeta', vi.fn())
    vi.stubGlobal('useAsyncData', (key: string, handler: () => Promise<unknown>, options: {
      default: () => unknown
      watch?: unknown[]
    }) => {
      if (key === 'dashboard-summary') lastAsyncWatchSources = options.watch ?? []
      const data = ref(options.default())
      const pending = ref(true)
      const error = ref<unknown>(null)
      const refresh = async () => {
        pending.value = true
        error.value = null
        try {
          data.value = await handler()
        }
        catch (caught) {
          error.value = caught
        }
        finally {
          pending.value = false
        }
      }
      if (options.watch) watch(options.watch as never, () => { void refresh() })
      void refresh()
      return { data, pending, error, refresh }
    })
  })

  afterEach(() => {
    vi.useRealTimers()
    vi.unstubAllGlobals()
  })

  it('adds approved roles and removes revoked roles from mounted navigation', async () => {
    const wrapper = mount(dashboardHarness(), { global: { stubs: { NuxtLink } } })
    await flushPromises()
    expect(wrapper.findAll('[data-dashboard-link]')).toHaveLength(0)

    fake.roles.set('user-a', [{
      event_id: EVENT_A,
      role: 'monitor',
      user_id: 'user-a',
      categories: [],
      approved_by: 'admin',
      approved_at: '2026-07-23T00:00:00Z',
    }])
    await fake.emit('event_roles', 'INSERT')
    expect(wrapper.findAll('[data-dashboard-link]').map(link => link.text())).toEqual(['Revisões'])

    fake.roles.set('user-a', [])
    window.dispatchEvent(new Event('focus'))
    await flushPromises()
    await nextTick()
    expect(wrapper.findAll('[data-dashboard-link]')).toHaveLength(0)
    wrapper.unmount()
  })

  it('adds and removes collaboration when team membership changes', async () => {
    const wrapper = mount(dashboardHarness(), { global: { stubs: { NuxtLink } } })
    await flushPromises()

    fake.teamEvents.set('user-a', [EVENT_A])
    await fake.emit('team_members', 'UPDATE')
    expect(wrapper.findAll('[data-dashboard-link]').map(link => link.text())).toEqual([
      'Minha equipe',
      'Atividades',
    ])

    fake.teamStatuses.set(EVENT_A, 'rejected')
    window.dispatchEvent(new Event('focus'))
    await flushPromises()
    await nextTick()
    expect(wrapper.findAll('[data-dashboard-link]')).toHaveLength(0)

    fake.teamStatuses.set(EVENT_A, 'approved')
    await fake.emit('team_members', 'UPDATE')
    expect(wrapper.findAll('[data-dashboard-link]')).toHaveLength(2)

    fake.teamEvents.set('user-a', [])
    Object.defineProperty(document, 'visibilityState', {
      configurable: true,
      value: 'visible',
    })
    document.dispatchEvent(new Event('visibilitychange'))
    await flushPromises()
    await nextTick()
    expect(wrapper.findAll('[data-dashboard-link]')).toHaveLength(0)
    wrapper.unmount()
  })

  it('clears user A before loading user B and rebuilds user-scoped channels', async () => {
    fake.roles.set('user-a', [{
      event_id: EVENT_A,
      role: 'monitor',
      user_id: 'user-a',
      categories: [],
      approved_by: 'admin',
      approved_at: '2026-07-23T00:00:00Z',
    }])
    fake.roles.set('user-b', [{
      event_id: EVENT_B,
      role: 'evaluator',
      user_id: 'user-b',
      categories: [],
      approved_by: 'admin',
      approved_at: '2026-07-23T00:00:00Z',
    }])
    const wrapper = mount(dashboardHarness(), { global: { stubs: { NuxtLink } } })
    await flushPromises()
    expect(wrapper.text()).toContain('Revisões')

    await fake.setUser(null)
    expect(wrapper.findAll('[data-dashboard-link]')).toHaveLength(0)
    await fake.setUser('user-b')
    expect(wrapper.findAll('[data-dashboard-link]').map(link => link.text())).toEqual(['Avaliações'])
    expect(fake.channels.some(channel => channel.name.includes('user-a'))).toBe(true)
    expect(fake.channels.some(channel => channel.name.includes('user-b'))).toBe(true)
    expect(fake.removed.length).toBeGreaterThan(0)
    wrapper.unmount()
  })

  it('deduplicates shared listeners and removes channels and auth listener on cleanup', async () => {
    vi.useFakeTimers()
    const intervalSpy = vi.spyOn(window, 'setInterval')
    const Parent = defineComponent({
      setup: () => () => h('div', [h(dashboardHarness()), h(dashboardHarness())]),
    })
    const wrapper = mount(Parent, { global: { stubs: { NuxtLink } } })
    await flushPromises()

    expect(fake.channels.filter(channel => channel.name.includes('user-a'))).toHaveLength(2)
    expect(intervalSpy).toHaveBeenCalledOnce()

    const beforeInterval = new Map(fake.selectCounts)
    await vi.advanceTimersByTimeAsync(15_000)
    await flushPromises()
    expect(fake.selectCounts.get('profiles')).toBe((beforeInterval.get('profiles') ?? 0) + 1)
    expect(fake.selectCounts.get('event_roles')).toBe((beforeInterval.get('event_roles') ?? 0) + 1)
    expect(fake.selectCounts.get('teams')).toBe((beforeInterval.get('teams') ?? 0) + 1)

    const beforeBurst = new Map(fake.selectCounts)
    window.dispatchEvent(new Event('focus'))
    window.dispatchEvent(new Event('online'))
    document.dispatchEvent(new Event('visibilitychange'))
    await flushPromises()
    expect(fake.selectCounts.get('profiles')).toBe((beforeBurst.get('profiles') ?? 0) + 1)
    expect(fake.selectCounts.get('event_roles')).toBe((beforeBurst.get('event_roles') ?? 0) + 1)
    expect(fake.selectCounts.get('teams')).toBe((beforeBurst.get('teams') ?? 0) + 1)

    wrapper.unmount()
    await flushPromises()
    expect(fake.removed).toHaveLength(2)
    expect(fake.unsubscribed).toHaveBeenCalledOnce()

    const afterCleanup = new Map(fake.selectCounts)
    await vi.advanceTimersByTimeAsync(15_000)
    window.dispatchEvent(new Event('focus'))
    window.dispatchEvent(new Event('online'))
    await flushPromises()
    expect(fake.selectCounts).toEqual(afterCleanup)
  })

  it('keeps focused navigation mounted during silent single-flight reconciliation', async () => {
    fake.roles.set('user-a', [{
      event_id: EVENT_A,
      role: 'monitor',
      user_id: 'user-a',
      categories: [],
      approved_by: 'admin',
      approved_at: '2026-07-23T00:00:00Z',
    }])
    const wrapper = mount(dashboardShellHarness(), { attachTo: document.body, global: { stubs: { NuxtLink } } })
    await flushPromises()
    const originalLink = wrapper.get('[data-dashboard-link]').element as HTMLElement
    originalLink.focus()
    expect(document.activeElement).toBe(originalLink)

    fake.deferNetwork()
    const beforeGetUser = fake.getUserCount
    window.dispatchEvent(new Event('focus'))
    await Promise.resolve()
    window.dispatchEvent(new Event('online'))
    await Promise.resolve()

    expect(fake.getUserCount).toBe(beforeGetUser + 1)
    expect(wrapper.find('[data-loading]').exists()).toBe(false)
    expect(wrapper.get('[data-dashboard-link]').element).toBe(originalLink)
    expect(document.activeElement).toBe(originalLink)

    fake.releaseNetwork()
    await flushPromises()
    wrapper.unmount()
  })

  it('polls only while visible and online, then reconciles on resume', async () => {
    vi.useFakeTimers()
    Object.defineProperty(document, 'visibilityState', {
      configurable: true,
      value: 'hidden',
    })
    Object.defineProperty(navigator, 'onLine', {
      configurable: true,
      value: false,
    })
    const wrapper = mount(dashboardHarness(), { global: { stubs: { NuxtLink } } })
    await flushPromises()
    const beforeHidden = new Map(fake.selectCounts)

    await vi.advanceTimersByTimeAsync(30_000)
    expect(fake.selectCounts).toEqual(beforeHidden)

    Object.defineProperty(document, 'visibilityState', {
      configurable: true,
      value: 'visible',
    })
    document.dispatchEvent(new Event('visibilitychange'))
    await flushPromises()
    expect(fake.selectCounts).toEqual(beforeHidden)

    Object.defineProperty(navigator, 'onLine', {
      configurable: true,
      value: true,
    })
    window.dispatchEvent(new Event('online'))
    await flushPromises()
    expect(fake.selectCounts.get('profiles')).toBe((beforeHidden.get('profiles') ?? 0) + 1)
    expect(fake.selectCounts.get('teams')).toBe((beforeHidden.get('teams') ?? 0) + 1)
    wrapper.unmount()
  })

  it('preserves access references when reconciliation returns unchanged data', async () => {
    fake.roles.set('user-a', [{
      event_id: EVENT_A,
      role: 'monitor',
      user_id: 'user-a',
      categories: [],
      approved_by: 'admin',
      approved_at: '2026-07-23T00:00:00Z',
    }])
    fake.teamEvents.set('user-a', [EVENT_A])
    const changes = { profile: 0, roles: 0, teams: 0 }
    const Observer = defineComponent({
      setup() {
        const context = useDashboardEventContext()
        watch(context.profile, () => { changes.profile += 1 })
        watch(context.eventRoles, () => { changes.roles += 1 })
        watch(context.teamEventIds, () => { changes.teams += 1 })
        return () => h('div')
      },
    })
    const wrapper = mount(Observer)
    await flushPromises()
    changes.profile = 0
    changes.roles = 0
    changes.teams = 0

    window.dispatchEvent(new Event('focus'))
    await flushPromises()
    expect(changes).toEqual({ profile: 0, roles: 0, teams: 0 })
    wrapper.unmount()
  })

  it('clears transient access and team errors after a successful mounted reconciliation', async () => {
    fake.roles.set('user-a', [{
      event_id: EVENT_A,
      role: 'monitor',
      user_id: 'user-a',
      categories: [],
      approved_by: 'admin',
      approved_at: '2026-07-23T00:00:00Z',
    }])
    fake.teamEvents.set('user-a', [EVENT_A])
    fake.failNext('profiles')
    fake.failNext('teams')
    const wrapper = mount(dashboardShellHarness(), { global: { stubs: { NuxtLink } } })
    await flushPromises()
    expect(wrapper.find('[data-error]').exists()).toBe(true)

    window.dispatchEvent(new Event('focus'))
    await flushPromises()
    expect(wrapper.find('[data-error]').exists()).toBe(false)
    expect(wrapper.text()).toContain('Revisões')
    expect(wrapper.text()).toContain('Minha equipe')
    wrapper.unmount()
  })

  it('does not let an old successful response clear the next user error', async () => {
    const wrapper = mount(dashboardShellHarness(), { global: { stubs: { NuxtLink } } })
    await flushPromises()

    fake.deferNetwork()
    window.dispatchEvent(new Event('focus'))
    await Promise.resolve()
    fake.failNext('profiles')
    void fake.setUser('user-b')
    await Promise.resolve()
    fake.releaseNetwork()
    await flushPromises()

    expect(wrapper.find('[data-error]').exists()).toBe(true)
    expect(wrapper.findAll('[data-dashboard-link]')).toHaveLength(0)
    wrapper.unmount()
  })

  it('retries a failed dashboard summary on successful unchanged reconciliation', async () => {
    fake.setGlobalRole('global_admin')
    fake.failNext('events')
    const DashboardPage = (await import('../../app/pages/app/index.vue')).default
    const wrapper = mount(DashboardPage, { global: { stubs: { NuxtLink } } })
    await flushPromises()
    expect(wrapper.text()).toContain('Não foi possível carregar')
    const failedAttempts = fake.selectCounts.get('events') ?? 0
    const beforeGetUser = fake.getUserCount
    const revision = lastAsyncWatchSources[4] as { value: number }
    const beforeRevision = revision.value

    window.dispatchEvent(new Event('focus'))
    await flushPromises()
    await nextTick()
    await flushPromises()
    expect(fake.getUserCount).toBe(beforeGetUser + 1)
    expect(revision.value).toBe(beforeRevision + 1)
    expect(fake.selectCounts.get('events')).toBe(failedAttempts + 1)
    expect(wrapper.text()).not.toContain('Não foi possível carregar')
    wrapper.unmount()
  })

  it('subscribes to team membership without embedding reserved email characters', async () => {
    fake.teamEvents.set('user-a', [EVENT_A, EVENT_B])
    const wrapper = mount(dashboardHarness(), { global: { stubs: { NuxtLink } } })
    await flushPromises()

    const activeTeamChannel = fake.channels.findLast(
      channel => channel.active && channel.name.startsWith('dashboard-teams:'),
    )
    const teamMemberHandlers = activeTeamChannel?.handlers
      .filter(handler => handler.config.table === 'team_members')
      ?? []
    expect(teamMemberHandlers).toHaveLength(1)
    expect(teamMemberHandlers[0]?.config).not.toHaveProperty('filter')
    const teamHandlers = activeTeamChannel?.handlers
      .filter(handler => handler.config.table === 'teams')
      ?? []
    expect(teamHandlers).toHaveLength(1)
    expect(teamHandlers[0]?.config).not.toHaveProperty('filter')

    const roleHandlers = fake.channels
      .flatMap(channel => channel.handlers)
      .filter(handler => handler.config.table === 'event_roles')
    expect(roleHandlers.map(handler => handler.config.event)).toEqual(['INSERT', 'UPDATE'])
    wrapper.unmount()
  })

  it('denies an unauthorized route event instead of falling back to another event', async () => {
    fake.roles.set('user-a', [{
      event_id: EVENT_A,
      role: 'monitor',
      user_id: 'user-a',
      categories: [],
      approved_by: 'admin',
      approved_at: '2026-07-23T00:00:00Z',
    }])
    route.params.eventId = EVENT_B
    const wrapper = mount(dashboardHarness(), { global: { stubs: { NuxtLink } } })
    await flushPromises()

    expect(wrapper.attributes('data-current-event')).toBe('')
    expect(wrapper.findAll('[data-dashboard-link]')).toHaveLength(0)

    delete route.params.eventId
    await nextTick()
    expect(wrapper.attributes('data-current-event')).toBe(EVENT_A)
    expect(wrapper.text()).toContain('Revisões')
    wrapper.unmount()
  })
})
