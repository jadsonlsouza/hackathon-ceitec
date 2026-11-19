import { mount } from '@vue/test-utils'
import { computed, defineComponent, h, nextTick, ref, watch } from 'vue'
import { afterEach, expect, it, vi } from 'vitest'
const state = vi.hoisted(() => ({ context: null as any }))
vi.mock('../../app/composables/useDashboardEventContext', () => ({ useDashboardEventContext: () => state.context }))
vi.mock('../../app/composables/useNotifications', () => ({ useNotifications: () => ({
  items: ref([]), pending: ref(false), error: ref(null), canCompose: ref(false),
  markRead: vi.fn(), refresh: vi.fn(), createManual: vi.fn(),
}) }))
afterEach(() => vi.unstubAllGlobals())
it('keeps an authorized administration page mounted without clearing loaded page data when only the presentation view changes', async () => {
  const activeView = ref({ role: 'global_admin', eventId: null } as any)
  state.context = { activeView, profile: ref({ global_role: 'global_admin' }), eventRoles: ref([]), pending: ref(false), error: ref(null), teamEventIds: ref([]), contextPending: ref(false), contextError: ref(null), currentEventId: ref('event-a'), availableViews: ref([]) }
  const navigate = vi.fn(), clear = vi.fn(), mutate = vi.fn()
  vi.stubGlobal('useRoute', () => ({ path: '/app/admin/eventos' }))
  vi.stubGlobal('useState', () => ref(null))
  vi.stubGlobal('navigateTo', navigate)
  vi.stubGlobal('clearNuxtData', clear)
  vi.stubGlobal('computed', computed)
  vi.stubGlobal('watch', watch)
  const Layout = (await import('../../app/layouts/dashboard.vue')).default
  const Child = defineComponent({ setup: () => () => h('button', { onClick: mutate }, 'Sensitive mutation') })
  const wrapper = mount(Layout, { slots: { default: () => h(Child) }, global: { stubs: { NuxtLink: true, BrandLogo: true, NotificationBell: true, DashboardNavigation: true } } })
  expect(wrapper.findComponent(Child).exists()).toBe(true)
  activeView.value = { role: 'student', eventId: 'event-a' }
  await nextTick()
  expect(wrapper.findComponent(Child).exists()).toBe(true)
  expect(navigate).not.toHaveBeenCalled()
  expect(clear).not.toHaveBeenCalled()
  expect(mutate).not.toHaveBeenCalled()
  wrapper.unmount()
})

it('passes the authorized event context to notifications independently of the presentation view', async () => {
  const activeView = ref({ role: 'student', eventId: 'event-a' } as any)
  state.context = {
    activeView,
    profile: ref({ global_role: 'global_admin' }),
    eventRoles: ref([]),
    pending: ref(false),
    error: ref(null),
    teamEventIds: ref([]),
    contextPending: ref(false),
    contextError: ref(null),
    currentEventId: ref('event-a'),
    availableViews: ref([]),
  }
  vi.stubGlobal('useRoute', () => ({ path: '/app' }))
  vi.stubGlobal('useState', () => ref(null))
  vi.stubGlobal('navigateTo', vi.fn())
  vi.stubGlobal('clearNuxtData', vi.fn())
  vi.stubGlobal('computed', computed)
  vi.stubGlobal('watch', watch)

  const Layout = (await import('../../app/layouts/dashboard.vue')).default
  const wrapper = mount(Layout, {
    global: {
      stubs: {
        NuxtLink: true,
        BrandLogo: true,
        NotificationBell: true,
        DashboardNavigation: true,
      },
    },
  })

  expect(wrapper.get('notification-bell-stub').attributes('eventid')).toBe('event-a')
  wrapper.unmount()
})

it('defaults to light and remembers a user-selected dark theme', async () => {
  localStorage.removeItem('ligalab-dashboard-theme')
  state.context = { activeView: ref(null), profile: ref(null), eventRoles: ref([]), pending: ref(false), error: ref(null), teamEventIds: ref([]), contextPending: ref(false), contextError: ref(null), currentEventId: ref(null), availableViews: ref([]) }
  vi.stubGlobal('useRoute', () => ({ path: '/app' }))
  vi.stubGlobal('useState', () => ref(null))
  const Layout = (await import('../../app/layouts/dashboard.vue')).default
  const options = { global: { stubs: { NuxtLink: true, BrandLogo: true, NotificationBell: true, DashboardNavigation: true } } }
  const wrapper = mount(Layout, options)
  expect(wrapper.get('.dashboard-shell').attributes('data-theme')).toBe('light')
  await wrapper.get('.dashboard-theme-toggle').trigger('click')
  expect(wrapper.get('.dashboard-shell').attributes('data-theme')).toBe('dark')
  expect(localStorage.getItem('ligalab-dashboard-theme')).toBe('dark')
  wrapper.unmount()
  const restored = mount(Layout, options)
  await nextTick()
  expect(restored.get('.dashboard-shell').attributes('data-theme')).toBe('dark')
  restored.unmount()
  localStorage.removeItem('ligalab-dashboard-theme')
})
