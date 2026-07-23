// @vitest-environment happy-dom
import { flushPromises, mount } from '@vue/test-utils'
import { computed, defineComponent, h, nextTick, ref, Suspense } from 'vue'
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

const EVENT_ID = '10000000-0000-4000-8000-000000000901'
const routePath = ref('/app')
const profile = ref<{ global_role: 'student' | 'global_admin' }>({ global_role: 'student' })
const eventRoles = ref<Array<{ event_id: string, role: 'professor' | 'monitor' | 'evaluator' }>>([])
const accessPending = ref(false)
const accessError = ref<unknown>(null)
const contextData = ref({ teamEventIds: [] as string[] })
const contextPending = ref(false)
const contextError = ref<unknown>(null)
const summaryData = ref({
  events: 0,
  teams: 0,
  reviews: 0,
  evaluations: 0,
  activities: 0,
})
const summaryPending = ref(false)
const summaryError = ref<unknown>(null)

const NuxtLink = {
  inheritAttrs: false,
  props: ['to'],
  template: '<a v-bind="$attrs" :href="to"><slot /></a>',
}

async function mountSuspended(component: unknown, options: Record<string, unknown> = {}) {
  const Host = defineComponent({
    setup: () => () => h(Suspense, null, {
      default: () => h(component as never, options),
    }),
  })
  const wrapper = mount(Host, {
    attachTo: document.body,
    global: { stubs: { NuxtLink } },
  })
  await flushPromises()
  await nextTick()
  return wrapper
}

describe('dashboard UI', () => {
  let DashboardNavigation: unknown
  let DashboardPage: unknown
  let ErrorPage: unknown

  beforeAll(async () => {
    vi.stubGlobal('computed', computed)
    vi.stubGlobal('nextTick', nextTick)
    vi.stubGlobal('ref', ref)
    vi.stubGlobal('definePageMeta', vi.fn())
    vi.stubGlobal('useRoute', () => ({
      path: routePath.value,
      params: {},
    }))
    vi.stubGlobal('useCurrentAccess', () => ({
      profile,
      eventRoles,
      pending: accessPending,
      error: accessError,
    }))
    vi.stubGlobal('useNuxtApp', () => ({ $supabase: {} }))
    vi.stubGlobal('useAsyncData', (key: string) => (
      key === 'dashboard-event-context'
        ? { data: contextData, pending: contextPending, error: contextError }
        : { data: summaryData, pending: summaryPending, error: summaryError }
    ))
    vi.stubGlobal('clearError', vi.fn())

    DashboardNavigation = (await import('../../app/components/dashboard/DashboardNavigation.vue')).default
    DashboardPage = (await import('../../app/pages/app/index.vue')).default
    ErrorPage = (await import('../../app/error.vue')).default
  })

  afterAll(() => vi.unstubAllGlobals())

  beforeEach(() => {
    routePath.value = '/app'
    profile.value = { global_role: 'student' }
    eventRoles.value = []
    accessPending.value = false
    accessError.value = null
    contextData.value = { teamEventIds: [] }
    contextPending.value = false
    contextError.value = null
    summaryData.value = { events: 0, teams: 0, reviews: 0, evaluations: 0, activities: 0 }
    summaryPending.value = false
    summaryError.value = null
    vi.mocked(clearError).mockReset()
  })

  it.each([
    ['global_admin', [], null, [], ['Eventos', 'Professores', 'Auditoria']],
    ['student', [{ event_id: EVENT_ID, role: 'professor' }], EVENT_ID, [], ['Equipes', 'Canvas', 'Conteúdo público', 'Avaliadores', 'Resultados']],
    ['student', [{ event_id: EVENT_ID, role: 'monitor' }], EVENT_ID, [], ['Revisões']],
    ['student', [{ event_id: EVENT_ID, role: 'evaluator' }], EVENT_ID, [], ['Avaliações']],
    ['student', [], EVENT_ID, [EVENT_ID], ['Minha equipe', 'Atividades']],
  ] as const)(
    'mounts the correct navigation for %s access',
    async (globalRole, roles, currentEventId, teamEventIds, labels) => {
      const wrapper = mount(DashboardNavigation as never, {
        props: {
          profile: { global_role: globalRole },
          eventRoles: roles,
          currentEventId,
          teamEventIds,
          currentPath: '/app',
        },
        global: { stubs: { NuxtLink } },
      })

      expect(wrapper.findAll('[data-dashboard-link]').map(link => link.text())).toEqual(labels)
    },
  )

  it('updates immediately when an approved role is revoked and deduplicates links', async () => {
    const wrapper = mount(DashboardNavigation as never, {
      props: {
        profile: { global_role: 'student' },
        eventRoles: [
          { event_id: EVENT_ID, role: 'monitor' },
          { event_id: EVENT_ID, role: 'monitor' },
          { event_id: EVENT_ID, role: 'evaluator' },
        ],
        currentEventId: EVENT_ID,
        teamEventIds: [],
        currentPath: '/app',
      },
      global: { stubs: { NuxtLink } },
    })

    expect(wrapper.findAll('[data-dashboard-link]').map(link => link.text())).toEqual([
      'Revisões',
      'Avaliações',
    ])
    await wrapper.setProps({ eventRoles: [{ event_id: EVENT_ID, role: 'evaluator' }] })
    expect(wrapper.findAll('[data-dashboard-link]').map(link => link.text())).toEqual(['Avaliações'])
  })

  it('marks the current page and operates the mobile menu with focus and Escape', async () => {
    const current = `/app/evento/${EVENT_ID}/revisoes`
    const wrapper = mount(DashboardNavigation as never, {
      attachTo: document.body,
      props: {
        profile: { global_role: 'student' },
        eventRoles: [{ event_id: EVENT_ID, role: 'monitor' }],
        currentEventId: EVENT_ID,
        teamEventIds: [],
        currentPath: current,
      },
      global: { stubs: { NuxtLink } },
    })
    const toggle = wrapper.get('[data-dashboard-menu-toggle]')

    expect(wrapper.get('[data-dashboard-link]').attributes('aria-current')).toBe('page')
    await toggle.trigger('click')
    await nextTick()
    expect(toggle.attributes('aria-expanded')).toBe('true')
    expect(document.activeElement).toBe(wrapper.get('[data-dashboard-link]').element)

    await wrapper.get('[data-dashboard-navigation]').trigger('keydown', { key: 'Escape' })
    await nextTick()
    expect(toggle.attributes('aria-expanded')).toBe('false')
    expect(document.activeElement).toBe(toggle.element)
    wrapper.unmount()
  })

  it('renders explicit pending, empty, error and success card states', async () => {
    profile.value = { global_role: 'global_admin' }
    summaryPending.value = true
    const wrapper = await mountSuspended(DashboardPage)

    expect(wrapper.get('[data-card-status="pending"]').text()).toContain('Carregando')

    summaryPending.value = false
    await nextTick()
    expect(wrapper.get('[data-card-status="empty"]').text()).toContain('Nenhum')

    summaryError.value = new Error('backend detail')
    await nextTick()
    expect(wrapper.get('[data-card-status="error"]').text()).toContain('Não foi possível')
    expect(wrapper.html()).not.toContain('backend detail')

    summaryError.value = null
    summaryData.value = { ...summaryData.value, events: 3 }
    await nextTick()
    expect(wrapper.get('[data-card-status="ready"]').text()).toContain('3')
    expect(wrapper.get('[data-card-action]').attributes('href')).toBe('/app/admin/eventos')
  })

  it('shows a sanitized recoverable global error', async () => {
    const wrapper = await mountSuspended(ErrorPage, {
      error: {
        statusCode: 500,
        message: 'password=secret database stack trace',
        stack: 'private backend details',
      },
    })

    expect(wrapper.text()).toContain('Algo não saiu como esperado')
    expect(wrapper.html()).not.toContain('password=secret')
    expect(wrapper.html()).not.toContain('private backend details')
    expect(wrapper.get('a').attributes('href')).toBe('/')
    await wrapper.get('button').trigger('click')
    expect(clearError).toHaveBeenCalledWith({ redirect: '/app' })
  })
})
