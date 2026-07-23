import { onScopeDispose, readonly, ref, type Ref } from 'vue'

export type AutosaveState = 'idle' | 'saving' | 'saved' | 'error' | 'conflict'

function isVersionConflict(error: unknown) {
  if (typeof error === 'string') return error.includes('version_conflict')
  if (error && typeof error === 'object' && 'message' in error) {
    return String(error.message).includes('version_conflict')
  }
  return false
}

export function useAutosave<T>(
  save: (value: T) => Promise<{ version: number }>,
  delayMs = 700,
): {
    state: Readonly<Ref<AutosaveState>>
    version: Readonly<Ref<number>>
    schedule: (value: T) => void
    retry: () => Promise<void>
  } {
  const state = ref<AutosaveState>('idle')
  const version = ref(0)
  let pendingValue: T | undefined
  let timer: ReturnType<typeof setTimeout> | undefined
  let disposed = false
  let sequence = 0
  let inFlight: Promise<void> | null = null

  async function runPersist() {
    if (disposed || pendingValue === undefined) return
    const value = pendingValue
    const attemptSequence = sequence
    state.value = 'saving'
    try {
      const result = await save(value)
      if (disposed) return
      version.value = result.version
      if (sequence !== attemptSequence) return
      state.value = 'saved'
    }
    catch (error: unknown) {
      if (disposed || sequence !== attemptSequence) return
      state.value = isVersionConflict(error) ? 'conflict' : 'error'
    }
  }

  async function persist() {
    if (inFlight) await inFlight
    if (disposed) return
    const job = runPersist()
    inFlight = job
    await job
    if (inFlight === job) inFlight = null
  }

  function schedule(value: T) {
    pendingValue = value
    sequence += 1
    state.value = 'idle'
    if (timer) clearTimeout(timer)
    timer = setTimeout(() => {
      timer = undefined
      void persist()
    }, delayMs)
  }

  async function retry() {
    if (timer) {
      clearTimeout(timer)
      timer = undefined
    }
    await persist()
  }

  onScopeDispose(() => {
    disposed = true
    if (timer) clearTimeout(timer)
    timer = undefined
  })

  return {
    state: readonly(state),
    version: readonly(version),
    schedule,
    retry,
  }
}
