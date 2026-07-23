import { flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import {
  computed,
  defineComponent,
  h,
  nextTick,
  ref,
  Suspense,
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

const EVENT_ID = '10000000-0000-4000-8000-000000000001'
const USER_ID = '00000000-0000-4000-8000-000000000001'
const EVENT_NAME = 'Hackathon CEITEC'

const testState = {
  insert: vi.fn(),
  order: vi.fn(),
  getSession: vi.fn(),
  archiveFetch: vi.fn(),
  refresh: vi.fn(),
}

const featuredEvent = {
  id: EVENT_ID,
  name: EVENT_NAME,
  slug: 'hackathon-ceitec',
  status: 'draft',
  is_featured: true,
  starts_at: null,
  ends_at: null,
  professor_id: null,
  archived_at: null,
  created_by: USER_ID,
  created_at: '2026-07-23T00:00:00.000Z',
}

function deferred<T>() {
  let resolve!: (value: T) => void
  const promise = new Promise<T>((resolvePromise) => {
    resolve = resolvePromise
  })
  return { promise, resolve }
}

let mountedHost: VueWrapper | undefined
let EventAdminPage: Awaited<
  ReturnType<typeof import('../../app/pages/app/admin/eventos.vue')>
>['default']

async function mountPage() {
  const Host = defineComponent({
    setup() {
      return () => h(Suspense, null, {
        default: () => h(EventAdminPage),
      })
    },
  })

  mountedHost = mount(Host, { attachTo: document.body })
  await flushPromises()
  await nextTick()
  return mountedHost
}

async function openReadyArchiveDialog(
  wrapper: Awaited<ReturnType<typeof mountPage>>,
) {
  await wrapper.get('.event-card .danger-button').trigger('click')
  await wrapper.get('#confirmed-event-name').setValue(EVENT_NAME)
  await wrapper.get('#archive-secret').setValue('segredo-de-arquivamento')
  return wrapper.get('dialog')
}

describe('event administration interactions', () => {
  beforeAll(async () => {
    const supabase = {
      auth: {
        getSession: testState.getSession,
      },
      from: () => ({
        insert: testState.insert,
        select: () => ({
          order: testState.order,
        }),
      }),
    }

    vi.stubGlobal('computed', computed)
    vi.stubGlobal('definePageMeta', vi.fn())
    vi.stubGlobal('nextTick', nextTick)
    vi.stubGlobal('ref', ref)
    vi.stubGlobal('refreshNuxtData', testState.refresh)
    vi.stubGlobal('useCurrentAccess', () => ({
      profile: ref({
        id: USER_ID,
        email: 'admin@example.test',
        display_name: 'Admin',
        global_role: 'global_admin',
        created_at: '2026-07-23T00:00:00.000Z',
        updated_at: '2026-07-23T00:00:00.000Z',
      }),
      eventRoles: ref([]),
      pending: ref(false),
      error: ref(null),
      refresh: vi.fn(),
    }))
    vi.stubGlobal('useNuxtApp', () => ({ $supabase: supabase }))
    vi.stubGlobal(
      'useAsyncData',
      async (_key: string, handler: () => Promise<unknown>) => ({
        data: ref(await handler()),
        pending: ref(false),
        error: ref(null),
      }),
    )
    vi.stubGlobal('$fetch', testState.archiveFetch)

    Object.defineProperty(HTMLDialogElement.prototype, 'showModal', {
      configurable: true,
      value() {
        this.setAttribute('open', '')
      },
    })
    Object.defineProperty(HTMLDialogElement.prototype, 'close', {
      configurable: true,
      value() {
        this.removeAttribute('open')
        this.dispatchEvent(new Event('close'))
      },
    })

    EventAdminPage = (
      await import('../../app/pages/app/admin/eventos.vue')
    ).default
  })

  afterAll(() => {
    vi.unstubAllGlobals()
  })

  afterEach(() => {
    mountedHost?.unmount()
    mountedHost = undefined
  })

  beforeEach(() => {
    testState.insert.mockReset().mockResolvedValue({ data: null, error: null })
    testState.order.mockReset().mockResolvedValue({
      data: [featuredEvent],
      error: null,
    })
    testState.getSession.mockReset().mockResolvedValue({
      data: {
        session: {
          access_token: 'verified-access-token',
          token_type: 'bearer',
          expires_in: 3600,
          expires_at: 1_800_003_600,
          refresh_token: 'refresh-token',
          user: {
            id: USER_ID,
            aud: 'authenticated',
            role: 'authenticated',
            email: 'admin@example.test',
            app_metadata: {},
            user_metadata: {},
            identities: [],
            created_at: '2026-07-23T00:00:00.000Z',
          },
        },
      },
      error: null,
    })
    testState.archiveFetch.mockReset().mockResolvedValue({
      archivedEventId: EVENT_ID,
      newEventId: '10000000-0000-4000-8000-000000000002',
    })
    testState.refresh.mockReset().mockResolvedValue(undefined)
  })

  it('rejects a whitespace-only event name, announces the error, and focuses the field', async () => {
    const wrapper = await mountPage()
    const nameInput = wrapper.get<HTMLInputElement>('#event-name')

    await nameInput.setValue('   ')
    await wrapper.get('#event-slug').setValue('evento-valido')
    await wrapper.get('.event-form').trigger('submit')
    await flushPromises()

    expect(testState.insert).not.toHaveBeenCalled()
    expect(wrapper.get('#event-name-error').text())
      .toBe('Informe um nome de evento.')
    expect(nameInput.attributes('aria-invalid')).toBe('true')
    expect(nameInput.attributes('aria-describedby')).toContain('event-name-error')
    expect(document.activeElement).toBe(nameInput.element)
  })

  it('blocks Cancel, Escape, and backdrop dismissal while archiving is in flight', async () => {
    const pendingArchive = deferred<{
      archivedEventId: string
      newEventId: string
    }>()
    testState.archiveFetch.mockReturnValueOnce(pendingArchive.promise)
    const wrapper = await mountPage()
    const dialog = await openReadyArchiveDialog(wrapper)

    await wrapper.get('.archive-dialog form').trigger('submit')
    await flushPromises()

    const cancelButton = wrapper.get<HTMLButtonElement>(
      '.dialog-actions .secondary-button',
    )
    expect(cancelButton.attributes()).toHaveProperty('disabled')
    expect(dialog.attributes()).toHaveProperty('open')

    const escape = new Event('cancel', { cancelable: true })
    dialog.element.dispatchEvent(escape)
    await dialog.trigger('click')

    expect(escape.defaultPrevented).toBe(true)
    expect(dialog.attributes()).toHaveProperty('open')
    expect(wrapper.get<HTMLInputElement>('#archive-secret').element.value)
      .toBe('segredo-de-arquivamento')

    pendingArchive.resolve({
      archivedEventId: EVENT_ID,
      newEventId: '10000000-0000-4000-8000-000000000002',
    })
    await flushPromises()

    expect(dialog.attributes()).not.toHaveProperty('open')
    expect(wrapper.get<HTMLInputElement>('#archive-secret').element.value)
      .toBe('')
  })

  it('keeps the dialog open, clears the secret, and announces archive errors inside it', async () => {
    testState.archiveFetch.mockRejectedValueOnce(new Error('archive failed'))
    const wrapper = await mountPage()
    const dialog = await openReadyArchiveDialog(wrapper)

    await wrapper.get('.archive-dialog form').trigger('submit')
    await flushPromises()

    expect(dialog.attributes()).toHaveProperty('open')
    expect(wrapper.get<HTMLInputElement>('#archive-secret').element.value)
      .toBe('')
    const alert = dialog.get('[role="alert"]')
    expect(alert.text()).toContain('Não foi possível arquivar.')
  })
})
