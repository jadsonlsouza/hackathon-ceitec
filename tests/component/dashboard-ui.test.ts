// @vitest-environment happy-dom
import { flushPromises, mount } from '@vue/test-utils'
import { computed, defineComponent, h, nextTick, ref, Suspense } from 'vue'
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

const EVENT_ID = '10000000-0000-4000-8000-000000000901'
const routePath = ref('/app')
const routeEventId = ref<string | null>(null)
const profile = ref<{ global_role: 'student' | 'global_admin' }>({ global_role: 'student' })
const eventRoles = ref<Array<{ event_id: string, role: 'professor' | 'monitor' | 'evaluator' }>>([])
const accessUserId = ref<string | null>('dashboard-test-user')
const reconciliationRevision = ref(0)
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
const notificationRpc = vi.fn()
const notificationFrom = vi.fn()

function supabaseQueryResult(data: unknown[] = [], error: unknown = null) {
  const result = { data, error }
  const builder: Record<string, unknown> = {}
  for (const method of ['select', 'eq', 'in', 'order']) {
    builder[method] = vi.fn(() => builder)
  }
  builder.then = (resolve: (value: typeof result) => unknown, reject?: (reason: unknown) => unknown) =>
    Promise.resolve(result).then(resolve, reject)
  return builder
}

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
  let RoleViewSelector: unknown
  let DashboardPage: unknown
  let ErrorPage: unknown
  let DashboardContextProbe: unknown
  let NotificationBell: unknown
  let NotificationComposeProbe: unknown
  let NotificationErrorProbe: unknown

  beforeAll(async () => {
    vi.stubGlobal('computed', computed)
    vi.stubGlobal('nextTick', nextTick)
    vi.stubGlobal('ref', ref)
    vi.stubGlobal('definePageMeta', vi.fn())
    vi.stubGlobal('useRoute', () => ({
      path: routePath.value,
      params: routeEventId.value ? { eventId: routeEventId.value } : {},
    }))
    vi.stubGlobal('useCurrentAccess', () => ({
      profile,
      eventRoles,
      userId: accessUserId,
      reconciliationRevision,
      pending: accessPending,
      error: accessError,
    }))
    const channel = {
      on: vi.fn(function () { return this }),
      subscribe: vi.fn(function () { return this }),
    }
    vi.stubGlobal('useNuxtApp', () => ({
      $supabase: {
        rpc: notificationRpc,
        channel: vi.fn(() => channel),
        removeChannel: vi.fn(),
        from: notificationFrom,
      },
    }))
    vi.stubGlobal('useAsyncData', (key: string) => (
      key === 'context-featured-event'
        ? { data: ref(null), pending: ref(false), error: ref(null) }
        : { data: summaryData, pending: summaryPending, error: summaryError }
    ))
    vi.stubGlobal('clearError', vi.fn())

    DashboardNavigation = (await import('../../app/components/dashboard/DashboardNavigation.vue')).default
    RoleViewSelector = (await import('../../app/components/dashboard/RoleViewSelector.vue')).default
    DashboardPage = (await import('../../app/pages/app/index.vue')).default
    ErrorPage = (await import('../../app/error.vue')).default
    const { useDashboardEventContext } = await import('../../app/composables/useDashboardEventContext')
    const { useNotifications } = await import('../../app/composables/useNotifications')
    DashboardContextProbe = defineComponent({
      setup() {
        const context = useDashboardEventContext()
        return () => h('output', {
          'data-active-role-view': context.activeView.value?.role ?? '',
          'data-current-event-id': context.currentEventId.value ?? '',
        })
      },
    })
    NotificationComposeProbe = defineComponent({
      props: {
        activeView: { type: Object, required: true },
        eventId: { type: String, default: null },
      },
      setup(props) {
        const activeView = computed(() => props.activeView as never)
        const eventId = computed(() => props.eventId)
        const notifications = useNotifications(activeView, eventId)
        return () => h('output', {
          'data-can-compose': String(notifications.canCompose.value),
        })
      },
    })
    NotificationErrorProbe = defineComponent({
      props: {
        activeView: { type: Object, required: true },
        eventId: { type: String, default: null },
      },
      setup(props) {
        const activeView = computed(() => props.activeView as never)
        const eventId = computed(() => props.eventId)
        const notifications = useNotifications(activeView, eventId)
        return () => h('output', {
          'data-error-message': notifications.error.value instanceof Error
            ? notifications.error.value.message
            : '',
        })
      },
    })
  })

  afterAll(() => vi.unstubAllGlobals())

  beforeEach(() => {
    routePath.value = '/app'
    routeEventId.value = null
    profile.value = { global_role: 'student' }
    eventRoles.value = []
    accessUserId.value = 'dashboard-test-user'
    reconciliationRevision.value = 0
    accessPending.value = false
    accessError.value = null
    contextData.value = { teamEventIds: [] }
    contextPending.value = false
    contextError.value = null
    summaryData.value = { events: 0, teams: 0, reviews: 0, evaluations: 0, activities: 0 }
    summaryPending.value = false
    summaryError.value = null
    notificationRpc.mockReset()
    notificationRpc.mockResolvedValue({ data: [], error: null })
    notificationFrom.mockReset()
    notificationFrom.mockImplementation(() => supabaseQueryResult())
    vi.mocked(clearError).mockReset()
  })

  it.each([
    [{ role: 'global_admin', eventId: null }, null, ['Eventos', 'Pessoas e permissões', 'Auditoria']],
    [{ role: 'professor', eventId: EVENT_ID }, EVENT_ID, ['Equipes', 'Atividades', 'Oficinas', 'Presença', 'Revisar envios', 'Configurar avaliação', 'Conteúdo do evento', 'Resultados', 'Configurações do evento']],
    [{ role: 'monitor', eventId: EVENT_ID }, EVENT_ID, ['Revisar envios']],
    [{ role: 'evaluator', eventId: EVENT_ID }, EVENT_ID, ['Avaliar projetos']],
    [{ role: 'student', eventId: EVENT_ID }, EVENT_ID, ['Minha equipe', 'Atividades', 'Oficinas', 'Presença']],
  ] as const)(
    'mounts the correct navigation for the active %s view',
    async (activeView, currentEventId, labels) => {
      const wrapper = mount(DashboardNavigation as never, {
        props: {
          activeView,
          currentEventId,
          currentPath: '/app',
        },
        global: { stubs: { NuxtLink } },
      })

      expect(wrapper.findAll('[data-dashboard-link]').map(link => link.text())).toEqual(labels)
    },
  )

  it('marks only manual notifications read and preserves automatic action links', async () => {
    NotificationBell = (await import('../../app/components/dashboard/NotificationBell.vue')).default
    const markRead = vi.fn()
    const wrapper = mount(NotificationBell as never, {
      props: {
        items: [
          { id: 'manual-1', source: 'manual', title: 'Aviso', body: 'Mensagem', read_at: null, action_path: null },
          { id: 'automatic:1', source: 'automatic', title: 'Revisar', body: 'Envio pendente', read_at: null, action_path: '/app/evento/event-a/revisoes' },
        ],
        pending: false, error: null, canCompose: false, markRead, refresh: vi.fn(), createManual: vi.fn(),
      },
      global: { stubs: { NuxtLink } },
    })
    const trigger = wrapper.get('[data-notification-trigger]')
    expect(trigger.text()).toContain('1')
    expect(trigger.attributes('aria-label')).toContain('1 aviso não lido')
    expect(trigger.find('[data-notification-icon]').exists()).toBe(true)
    await wrapper.get('[data-notification-trigger]').trigger('click')
    expect(wrapper.get('[data-notification-pending]').text()).toContain('Pendências')
    expect(wrapper.get('[data-notification-notices]').text()).toContain('Avisos')
    await wrapper.get('[data-notification-item="manual-1"]').trigger('click')
    expect(markRead).toHaveBeenCalledWith(['manual-1'])
    expect(wrapper.get('[data-notification-item="automatic:1"]').attributes('href')).toBe('/app/evento/event-a/revisoes')
    await wrapper.get('[data-notification-item="automatic:1"]').trigger('click')
    expect(markRead).toHaveBeenCalledTimes(1)
    wrapper.unmount()
  })

  it('offers retry, restores bell focus, and marks only unread manual items in bulk', async () => {
    const Bell = (await import('../../app/components/dashboard/NotificationBell.vue')).default
    const markRead = vi.fn()
    const refresh = vi.fn()
    const wrapper = mount(Bell, { attachTo: document.body, global: { stubs: { NuxtLink } }, props: {
      items: [
        { id: 'manual-1', source: 'manual', title: 'Aviso', body: 'Texto', read_at: null },
        { id: 'automatic:1', source: 'automatic', title: 'Tarefa', body: 'Texto', read_at: null },
        { id: 'manual-2', source: 'manual', title: 'Lido', body: 'Texto', read_at: '2026-01-01' },
      ] as never,
      pending: false, error: null, canCompose: false, markRead, refresh, createManual: vi.fn(),
    } })
    await wrapper.get('[data-notification-trigger]').trigger('click')
    await wrapper.get('[data-mark-all-read]').trigger('click')
    expect(markRead).toHaveBeenCalledWith(['manual-1'])
    await wrapper.setProps({ error: new Error('secret backend details') })
    expect(wrapper.text()).not.toContain('secret backend details')
    await wrapper.get('[data-notification-retry]').trigger('click')
    expect(refresh).toHaveBeenCalledOnce()
    await wrapper.get('[data-notification-bell]').trigger('keydown', { key: 'Escape' })
    expect(document.activeElement).toBe(wrapper.get('[data-notification-trigger]').element)
    expect(wrapper.find('[data-notification-composer]').exists()).toBe(false)
    wrapper.unmount()
  })

  it('requires a scoped audience before sending and constructs only the selected selector', async () => {
    const Bell = (await import('../../app/components/dashboard/NotificationBell.vue')).default
    const createManual = vi.fn().mockResolvedValue(undefined)
    const wrapper = mount(Bell, { global: { stubs: { NuxtLink } }, props: {
      items: [], pending: false, error: null, canCompose: true, eventId: EVENT_ID,
      markRead: vi.fn(), refresh: vi.fn(), createManual,
    } })
    await wrapper.get('[data-notification-trigger]').trigger('click')
    await wrapper.get('[data-notification-compose]').trigger('click')
    await wrapper.get('[name="title"]').setValue('Aviso importante')
    await wrapper.get('[name="body"]').setValue('Mensagem da organização')
    await wrapper.get('[name="audience"]').setValue('users')
    await wrapper.get('form').trigger('submit')
    expect(createManual).not.toHaveBeenCalled()
    expect(wrapper.get('[role="alert"]').text()).toContain('destinatário')
    await wrapper.get('[name="audience"]').setValue('event_role')
    await wrapper.get('[name="role"]').setValue('monitor')
    await wrapper.get('form').trigger('submit')
    expect(createManual).toHaveBeenCalledWith({ title: 'Aviso importante', body: 'Mensagem da organização', event_id: EVENT_ID, audience: { type: 'event_role', role: 'monitor' } })
    wrapper.unmount()
  })

  it('uses readable approved-team and event-participant selectors for manual notifications', async () => {
    const TEAM_ID = '20000000-0000-4000-8000-000000000901'
    const MONITOR_ID = '30000000-0000-4000-8000-000000000901'
    const STUDENT_ID = '40000000-0000-4000-8000-000000000901'
    notificationFrom.mockImplementation((table: string) => {
      if (table === 'teams') return supabaseQueryResult([{ id: TEAM_ID, name: 'Equipe Aurora' }])
      if (table === 'event_roles') {
        return supabaseQueryResult([{
          user_id: MONITOR_ID,
          profile: { display_name: 'Maria Monitor', email: 'maria@example.com' },
        }])
      }
      if (table === 'team_members') {
        return supabaseQueryResult([{
          user_id: STUDENT_ID,
          name: 'João Aluno',
          email: 'joao@example.com',
        }])
      }
      return supabaseQueryResult()
    })

    const Bell = (await import('../../app/components/dashboard/NotificationBell.vue')).default
    const createManual = vi.fn().mockResolvedValue(undefined)
    const wrapper = mount(Bell, { global: { stubs: { NuxtLink } }, props: {
      items: [], pending: false, error: null, canCompose: true, eventId: EVENT_ID,
      markRead: vi.fn(), refresh: vi.fn(), createManual,
    } })

    await wrapper.get('[data-notification-trigger]').trigger('click')
    await wrapper.get('[data-notification-compose]').trigger('click')
    await flushPromises()

    expect(wrapper.find('[name="event"]').exists()).toBe(false)
    expect(notificationFrom).toHaveBeenCalledWith('teams')
    expect(notificationFrom).toHaveBeenCalledWith('event_roles')
    expect(notificationFrom).toHaveBeenCalledWith('team_members')

    await wrapper.get('[name="title"]').setValue('Aviso de equipe')
    await wrapper.get('[name="body"]').setValue('Mensagem para a equipe')
    await wrapper.get('[name="audience"]').setValue('team')
    expect(wrapper.get('[name="team"]').text()).toContain('Equipe Aurora')
    await wrapper.get('[name="team"]').setValue(TEAM_ID)
    await wrapper.get('form').trigger('submit')
    await flushPromises()
    expect(createManual).toHaveBeenCalledWith({
      title: 'Aviso de equipe',
      body: 'Mensagem para a equipe',
      event_id: EVENT_ID,
      audience: { type: 'team', team_id: TEAM_ID },
    })

    await wrapper.get('[data-notification-compose]').trigger('click')
    await wrapper.get('[name="title"]').setValue('Aviso individual')
    await wrapper.get('[name="body"]').setValue('Mensagem para pessoas')
    await wrapper.get('[name="audience"]').setValue('users')
    const people = wrapper.get('[name="users"]')
    expect(people.text()).toContain('Maria Monitor')
    expect(people.text()).toContain('maria@example.com')
    expect(people.text()).toContain('João Aluno')
    expect(people.text()).toContain('joao@example.com')
    await people.setValue([MONITOR_ID, STUDENT_ID])
    await wrapper.get('form').trigger('submit')
    await flushPromises()
    expect(createManual).toHaveBeenLastCalledWith({
      title: 'Aviso individual',
      body: 'Mensagem para pessoas',
      event_id: EVENT_ID,
      audience: { type: 'users', user_ids: [STUDENT_ID, MONITOR_ID] },
    })
    wrapper.unmount()
  })

  it('keeps notification authoring authorized for a global admin regardless of the selected presentation view', async () => {
    profile.value = { global_role: 'global_admin' }
    eventRoles.value = []

    const wrapper = await mountSuspended(NotificationComposeProbe, {
      activeView: { role: 'student', eventId: EVENT_ID },
      eventId: EVENT_ID,
    })

    expect(wrapper.get('output').attributes('data-can-compose')).toBe('true')
    wrapper.unmount()
  })

  it('keeps notification authoring authorized by the real professor role when another presentation view is selected', async () => {
    profile.value = { global_role: 'student' }
    eventRoles.value = [{ event_id: EVENT_ID, role: 'professor' }]

    const wrapper = await mountSuspended(NotificationComposeProbe, {
      activeView: { role: 'monitor', eventId: EVENT_ID },
      eventId: EVENT_ID,
    })

    expect(wrapper.get('output').attributes('data-can-compose')).toBe('true')
    wrapper.unmount()
  })

  it('preserves the backend failure internally while the bell can keep its public error copy generic', async () => {
    const rpcFailure = new Error('rpc diagnostics for operators')
    notificationRpc.mockRejectedValueOnce(rpcFailure)

    const wrapper = await mountSuspended(NotificationErrorProbe, {
      activeView: { role: 'student', eventId: EVENT_ID },
      eventId: EVENT_ID,
    })

    expect(wrapper.get('output').attributes('data-error-message')).toBe(rpcFailure.message)
    wrapper.unmount()
  })

  it('updates immediately when the selected view changes', async () => {
    const wrapper = mount(DashboardNavigation as never, {
      props: {
        activeView: { role: 'monitor', eventId: EVENT_ID },
        currentEventId: EVENT_ID,
        currentPath: '/app',
      },
      global: { stubs: { NuxtLink } },
    })

    expect(wrapper.findAll('[data-dashboard-link]').map(link => link.text())).toEqual([
      'Revisar envios',
    ])
    await wrapper.setProps({ activeView: { role: 'evaluator', eventId: EVENT_ID } })
    expect(wrapper.findAll('[data-dashboard-link]').map(link => link.text())).toEqual(['Avaliar projetos'])
  })

  it('keeps focus on the selector trigger after Escape', async () => {
    const wrapper = mount(RoleViewSelector as never, {
      attachTo: document.body,
      props: {
        activeView: { role: 'professor', eventId: EVENT_ID },
        availableViews: [
          { role: 'global_admin', eventId: null },
          { role: 'professor', eventId: EVENT_ID },
        ],
        setActiveView: vi.fn(),
      },
    })

    await wrapper.get('[data-role-view-trigger]').trigger('click')
    await nextTick()
    expect(wrapper.get('[role="listbox"]').attributes('aria-label')).toBe('Escolher visualização')
    await wrapper.get('[data-role-view-selector]').trigger('keydown', { key: 'Escape' })
    await nextTick()

    expect(document.activeElement).toBe(wrapper.get('[data-role-view-trigger]').element)
    wrapper.unmount()
  })

  it('exposes an active role view without changing the authorized event context', async () => {
    eventRoles.value = [{ event_id: EVENT_ID, role: 'professor' }]
    const wrapper = await mountSuspended(DashboardContextProbe)

    expect(wrapper.get('output').attributes('data-current-event-id')).toBe(EVENT_ID)
    expect(wrapper.get('output').attributes('data-active-role-view')).toBe('professor')

    eventRoles.value = []
    await nextTick()
    expect(wrapper.get('output').attributes('data-current-event-id')).toBe('')
    expect(wrapper.get('output').attributes('data-active-role-view')).toBe('')
  })

  it('opens a global admin’s newly-created event in its stored professor view without creating an event role', async () => {
    const newEventId = '10000000-0000-4000-8000-000000000999'
    accessUserId.value = 'global-admin-new-event'
    profile.value = { global_role: 'global_admin' }
    routePath.value = `/app/evento/${newEventId}/admin/conteudo-publico`
    routeEventId.value = newEventId
    localStorage.setItem(
      `ligalab:active-view:${accessUserId.value}:${newEventId}`,
      JSON.stringify({ role: 'professor', eventId: newEventId }),
    )

    const wrapper = await mountSuspended(DashboardContextProbe)

    expect(wrapper.get('output').attributes('data-current-event-id')).toBe(newEventId)
    expect(wrapper.get('output').attributes('data-active-role-view')).toBe('professor')
    expect(eventRoles.value).toEqual([])
  })

  it('marks the current page and operates the mobile menu with focus and Escape', async () => {
    const current = `/app/evento/${EVENT_ID}/revisoes`
    const wrapper = mount(DashboardNavigation as never, {
      attachTo: document.body,
      props: {
        activeView: { role: 'monitor', eventId: EVENT_ID },
        currentEventId: EVENT_ID,
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
    await nextTick()
    await flushPromises()
    await nextTick()
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

  it('labels evaluator assignment totals as assigned categories', async () => {
    eventRoles.value = [{ event_id: EVENT_ID, role: 'evaluator' }]
    summaryData.value = { ...summaryData.value, evaluations: 2 }
    const wrapper = await mountSuspended(DashboardPage)

    expect(wrapper.get('.status-card h2').text()).toBe('Categorias atribuídas')
    expect(wrapper.text()).not.toContain('Avaliações atribuídas')
  })

  it('sends professors directly to the full team management screen', async () => {
    eventRoles.value = [{ event_id: EVENT_ID, role: 'professor' }]
    summaryData.value = { ...summaryData.value, teams: 2 }
    const wrapper = await mountSuspended(DashboardPage)

    const action = wrapper.get('[data-card-action]')
    expect(action.text()).toBe('Ver e editar equipes')
    expect(action.attributes('href')).toBe(`/app/evento/${EVENT_ID}/admin/equipes`)
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
