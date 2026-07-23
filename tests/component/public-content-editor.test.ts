import { flushPromises, mount } from '@vue/test-utils'
import { computed, defineComponent, h, nextTick, ref, Suspense } from 'vue'
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

const EVENT_ID = '10000000-0000-4000-8000-000000000801'
const rpc = vi.fn()
const refresh = vi.fn()

async function mountPage(component: unknown) {
  const Host = defineComponent({
    setup: () => () => h(Suspense, null, {
      default: () => h(component as never),
    }),
  })
  const wrapper = mount(Host, { attachTo: document.body })
  await flushPromises()
  await nextTick()
  return wrapper
}

describe('Professor public-content editor', () => {
  let EditorPage: unknown

  beforeAll(async () => {
    vi.stubGlobal('computed', computed)
    vi.stubGlobal('definePageMeta', vi.fn())
    vi.stubGlobal('ref', ref)
    vi.stubGlobal('useRoute', () => ({ params: { eventId: EVENT_ID } }))
    vi.stubGlobal('useCurrentAccess', () => ({
      eventRoles: ref([{ event_id: EVENT_ID, role: 'professor' }]),
      pending: ref(false),
      error: ref(null),
    }))
    vi.stubGlobal('useNuxtApp', () => ({ $supabase: { rpc } }))
    vi.stubGlobal('useAsyncData', async (_key: string, handler: () => Promise<unknown>) => ({
      data: ref(await handler()),
      pending: ref(false),
      error: ref(null),
      refresh,
    }))
    EditorPage = (
      await import('../../app/pages/app/evento/[eventId]/admin/conteudo-publico.vue')
    ).default
  })

  afterAll(() => vi.unstubAllGlobals())

  beforeEach(() => {
    rpc.mockReset().mockImplementation((name: string) => {
      if (name === 'get_event_public_content_for_edit') {
        return Promise.resolve({
          data: [{
            tagline: 'Criando soluções, conectando o futuro.',
            presentation: 'Apresentação completa.',
            objectives: ['Objetivo um'],
            venue: 'CAC - CEI Roberto Freire',
            date_label: '24 e 25 de julho',
            registration_open: true,
            schedule: [
              { dayNumber: 1, startsAt: '14:00', activity: 'Credenciamento', position: 1 },
              { dayNumber: 2, startsAt: '07:15', activity: 'Acolhimento', position: 1 },
            ],
          }],
          error: null,
        })
      }
      return Promise.resolve({ data: null, error: null })
    })
    refresh.mockReset().mockResolvedValue(undefined)
  })

  it('blocks invalid time, blank objectives and missing day rows', async () => {
    const wrapper = await mountPage(EditorPage)
    const objective = wrapper.get('[data-objective]')
    await objective.setValue(' ')
    const firstTime = wrapper.get('[data-schedule-time]')
    await firstTime.setValue('25:00')
    await wrapper.get('[data-day="2"] [data-remove-row]').trigger('click')
    await wrapper.get('form').trigger('submit')

    expect(rpc).toHaveBeenCalledTimes(1)
    expect(wrapper.text()).toContain('Informe ao menos um objetivo')
    expect(wrapper.text()).toContain('Use um horário válido')
    expect(wrapper.text()).toContain('Inclua ao menos uma atividade em cada dia')
  })

  it('saves one exact trimmed payload and guards rapid submissions', async () => {
    const wrapper = await mountPage(EditorPage)
    rpc.mockClear().mockReturnValue(new Promise(() => {}))

    await wrapper.get('form').trigger('submit')
    await wrapper.get('form').trigger('submit')

    expect(rpc).toHaveBeenCalledTimes(1)
    expect(rpc).toHaveBeenCalledWith('save_event_public_content', {
      target_event: EVENT_ID,
      content: {
        tagline: 'Criando soluções, conectando o futuro.',
        presentation: 'Apresentação completa.',
        objectives: ['Objetivo um'],
        venue: 'CAC - CEI Roberto Freire',
        dateLabel: '24 e 25 de julho',
        registrationOpen: true,
        schedule: [
          { dayNumber: 1, startsAt: '14:00', activity: 'Credenciamento', position: 1 },
          { dayNumber: 2, startsAt: '07:15', activity: 'Acolhimento', position: 1 },
        ],
      },
    })
    expect(wrapper.get('button[type="submit"]').attributes('disabled')).toBeDefined()
  })

  it('sanitizes deterministic backend errors into Portuguese feedback', async () => {
    rpc.mockImplementation((name: string) => {
      if (name === 'save_event_public_content') {
        return Promise.resolve({ data: null, error: { message: 'forbidden' } })
      }
      return Promise.resolve({
        data: [{
          tagline: 'Tagline',
          presentation: 'Apresentação',
          objectives: ['Objetivo'],
          venue: 'Local',
          date_label: 'Data',
          registration_open: false,
          schedule: [
            { dayNumber: 1, startsAt: '14:00', activity: 'Atividade', position: 1 },
            { dayNumber: 2, startsAt: '08:00', activity: 'Atividade', position: 1 },
          ],
        }],
        error: null,
      })
    })
    const wrapper = await mountPage(EditorPage)
    await wrapper.get('form').trigger('submit')
    await flushPromises()

    expect(wrapper.text()).toContain('Você não tem permissão')
    expect(wrapper.html()).not.toContain('forbidden')
  })
})
