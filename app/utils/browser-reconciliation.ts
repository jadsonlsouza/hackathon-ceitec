export const DASHBOARD_RECONCILIATION_INTERVAL_MS = 15_000

export function installBrowserReconciliation(
  reconcile: () => void | Promise<void>,
  intervalMs = DASHBOARD_RECONCILIATION_INTERVAL_MS,
) {
  if (typeof window === 'undefined' || typeof document === 'undefined') {
    return () => {}
  }

  let queued = false
  let stopped = false
  const schedule = () => {
    if (queued || stopped) return
    queued = true
    queueMicrotask(() => {
      queued = false
      if (!stopped) void reconcile()
    })
  }
  const reconcileWhenVisible = () => {
    if (document.visibilityState === 'visible') schedule()
  }

  window.addEventListener('focus', schedule)
  window.addEventListener('online', schedule)
  document.addEventListener('visibilitychange', reconcileWhenVisible)
  const intervalId = window.setInterval(schedule, intervalMs)

  return () => {
    stopped = true
    window.clearInterval(intervalId)
    window.removeEventListener('focus', schedule)
    window.removeEventListener('online', schedule)
    document.removeEventListener('visibilitychange', reconcileWhenVisible)
  }
}
