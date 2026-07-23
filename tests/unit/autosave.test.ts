import { effectScope, nextTick } from 'vue'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { useAutosave } from '../../app/composables/useAutosave'

describe('useAutosave', () => {
  afterEach(() => {
    vi.useRealTimers()
  })

  it('debounces repeated changes and saves only the latest value after 700 ms', async () => {
    vi.useFakeTimers()
    const save = vi.fn().mockResolvedValue({ version: 4 })
    const scope = effectScope()
    const autosave = scope.run(() => useAutosave(save))!

    autosave.schedule('primeiro')
    await vi.advanceTimersByTimeAsync(500)
    autosave.schedule('mais recente')
    await vi.advanceTimersByTimeAsync(699)

    expect(save).not.toHaveBeenCalled()

    await vi.advanceTimersByTimeAsync(1)
    expect(save).toHaveBeenCalledOnce()
    expect(save).toHaveBeenCalledWith('mais recente')
    expect(autosave.state.value).toBe('saved')
    expect(autosave.version.value).toBe(4)
    scope.stop()
  })

  it('keeps the latest value after a network failure and retries it explicitly', async () => {
    vi.useFakeTimers()
    const save = vi.fn()
      .mockRejectedValueOnce(new Error('network unavailable'))
      .mockResolvedValueOnce({ version: 2 })
    const scope = effectScope()
    const autosave = scope.run(() => useAutosave(save, 50))!

    autosave.schedule({ text: 'Hipótese validada' })
    await vi.advanceTimersByTimeAsync(50)
    expect(autosave.state.value).toBe('error')

    await autosave.retry()
    expect(save).toHaveBeenCalledTimes(2)
    expect(save).toHaveBeenLastCalledWith({ text: 'Hipótese validada' })
    expect(autosave.state.value).toBe('saved')
    expect(autosave.version.value).toBe(2)
    scope.stop()
  })

  it('classifies optimistic version conflicts separately and retains the value', async () => {
    vi.useFakeTimers()
    const save = vi.fn().mockRejectedValue({ message: 'version_conflict' })
    const scope = effectScope()
    const autosave = scope.run(() => useAutosave(save, 20))!

    autosave.schedule('conteúdo concorrente')
    await vi.advanceTimersByTimeAsync(20)

    expect(autosave.state.value).toBe('conflict')
    expect(autosave.version.value).toBe(0)
    await autosave.retry()
    expect(save).toHaveBeenCalledTimes(2)
    scope.stop()
  })

  it('cancels pending work when its Vue scope is disposed', async () => {
    vi.useFakeTimers()
    const save = vi.fn().mockResolvedValue({ version: 1 })
    const scope = effectScope()
    const autosave = scope.run(() => useAutosave(save, 100))!

    autosave.schedule('não persistir')
    scope.stop()
    await vi.advanceTimersByTimeAsync(100)
    await nextTick()

    expect(save).not.toHaveBeenCalled()
  })

  it('does not mark a newer scheduled edit as saved when an older request finishes', async () => {
    vi.useFakeTimers()
    let resolveFirst!: (value: { version: number }) => void
    const first = new Promise<{ version: number }>(resolve => { resolveFirst = resolve })
    const save = vi.fn()
      .mockReturnValueOnce(first)
      .mockResolvedValueOnce({ version: 2 })
    const scope = effectScope()
    const autosave = scope.run(() => useAutosave(save, 100))!

    autosave.schedule('primeira')
    await vi.advanceTimersByTimeAsync(100)
    expect(autosave.state.value).toBe('saving')

    autosave.schedule('segunda')
    resolveFirst({ version: 1 })
    await Promise.resolve()
    expect(autosave.state.value).toBe('idle')

    await vi.advanceTimersByTimeAsync(100)
    expect(save).toHaveBeenLastCalledWith('segunda')
    expect(autosave.state.value).toBe('saved')
    scope.stop()
  })
})
