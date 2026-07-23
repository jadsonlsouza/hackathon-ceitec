import { flushPromises, mount } from '@vue/test-utils'
import { defineComponent, effectScope, h, nextTick, ref } from 'vue'
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

const rpc = vi.fn()
const channelOn = vi.fn()
const subscribe = vi.fn()
const removeChannel = vi.fn()
const channel = vi.fn(() => ({ on: channelOn, subscribe }))

beforeAll(() => {
  channelOn.mockImplementation(function (this: unknown) { return this })
  subscribe.mockImplementation(function (this: unknown) { return this })
  vi.stubGlobal('useNuxtApp', () => ({
    $supabase: { rpc, channel, removeChannel },
  }))
})

afterAll(() => vi.unstubAllGlobals())

beforeEach(() => {
  rpc.mockReset()
  channel.mockClear()
  channelOn.mockClear()
  subscribe.mockClear()
  removeChannel.mockReset().mockResolvedValue('ok')
})

describe('event Realtime lifecycle', () => {
  it('creates one scoped channel and removes it on disposal', async () => {
    const { useEventRealtime } = await import('../../app/composables/useEventRealtime')
    const eventId = ref('event-1')
    const refresh = vi.fn()
    const scope = effectScope()
    const realtime = scope.run(() => useEventRealtime(eventId, [
      { table: 'submissions', filter: 'event_id=eq.event-1' },
      { table: 'submission_answers', filter: 'submission_id=eq.submission-1' },
    ], refresh))!

    realtime.start()
    realtime.start()

    expect(channel).toHaveBeenCalledOnce()
    expect(channelOn).toHaveBeenCalledTimes(2)
    expect(channelOn).toHaveBeenNthCalledWith(1, 'postgres_changes', {
      event: '*', schema: 'public', table: 'submissions', filter: 'event_id=eq.event-1',
    }, refresh)

    scope.stop()
    await flushPromises()
    expect(removeChannel).toHaveBeenCalledOnce()
  })

  it('starts when permitted targets arrive after access hydration', async () => {
    const { useEventRealtime } = await import('../../app/composables/useEventRealtime')
    const targets = ref<Array<{ table: string, filter: string }>>([])
    const scope = effectScope()
    scope.run(() => useEventRealtime('event-1', targets, vi.fn()))!

    expect(channel).not.toHaveBeenCalled()
    targets.value = [{ table: 'submissions', filter: 'event_id=eq.event-1' }]
    await nextTick()

    expect(channel).toHaveBeenCalledOnce()
    scope.stop()
  })
})

describe('Canvas block editor', () => {
  it('autosaves text with the optimistic version and exposes retry after failure', async () => {
    vi.useFakeTimers()
    rpc
      .mockResolvedValueOnce({ data: null, error: { message: 'network failure' } })
      .mockResolvedValueOnce({ data: { version: 3 }, error: null })
    const CanvasBlockEditor = (await import('../../app/components/canvas/CanvasBlockEditor.vue')).default
    const wrapper = mount(CanvasBlockEditor, {
      props: {
        block: { id: 'block-1', title: 'Problema', prompt: 'Descreva o problema', position: 1, max_items: null },
        submissionId: 'submission-1',
        initialContent: { text: 'Inicial' },
        initialVersion: 2,
        editable: true,
      },
    })

    await wrapper.get('textarea').setValue('Novo conteúdo')
    await vi.advanceTimersByTimeAsync(700)
    await nextTick()

    expect(rpc).toHaveBeenCalledWith('save_canvas_answer', {
      submission_id: 'submission-1',
      block_id: 'block-1',
      content: { text: 'Novo conteúdo' },
      expected_version: 2,
    })
    expect(wrapper.get('[role="status"]').text()).toContain('Falha ao salvar')

    await wrapper.get('[data-action="retry-save"]').trigger('click')
    await flushPromises()
    expect(rpc).toHaveBeenCalledTimes(2)
    expect(wrapper.get('[role="status"]').text()).toContain('Salvo')
    wrapper.unmount()
    vi.useRealTimers()
  })

  it('shows a conflict recovery banner and requests the latest revision', async () => {
    vi.useFakeTimers()
    rpc.mockResolvedValueOnce({ data: null, error: { message: 'version_conflict' } })
    const CanvasBlockEditor = (await import('../../app/components/canvas/CanvasBlockEditor.vue')).default
    const wrapper = mount(CanvasBlockEditor, {
      props: {
        block: { id: 'block-1', title: 'Solução', prompt: '', position: 1, max_items: 3 },
        submissionId: 'submission-1',
        initialContent: { text: '' },
        initialVersion: 1,
        editable: true,
      },
    })

    await wrapper.get('textarea').setValue('Conflito')
    await vi.advanceTimersByTimeAsync(700)
    await nextTick()

    expect(wrapper.get('[role="alert"]').text()).toContain('Outra pessoa')
    await wrapper.get('[data-action="reload-latest"]').trigger('click')
    expect(wrapper.emitted('reload-latest')).toEqual([['block-1']])
    wrapper.unmount()
    vi.useRealTimers()
  })
})
