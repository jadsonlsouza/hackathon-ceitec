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
it('unmounts an already-open administration page and clears its data when narrowing', async () => {
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
  expect(wrapper.findComponent(Child).exists()).toBe(false)
  expect(navigate).toHaveBeenCalledWith('/app')
  expect(clear).toHaveBeenCalled()
  expect(mutate).not.toHaveBeenCalled()
  wrapper.unmount()
})
