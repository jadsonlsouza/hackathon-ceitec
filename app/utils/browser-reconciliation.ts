export const DASHBOARD_RECONCILIATION_INTERVAL_MS = 15_000

const subscribers = new Set<() => void | Promise<void>>()
let intervalId: number | null = null
let queued = false

function canReconcile() {
  return (
    document.visibilityState === 'visible'
    && navigator.onLine !== false
  )
}

function schedule() {
  if (queued || !canReconcile()) return
  queued = true
  queueMicrotask(() => {
    queued = false
    if (!canReconcile()) return
    for (const reconcile of subscribers) void reconcile()
  })
}

function startDriver(intervalMs: number) {
  window.addEventListener('focus', schedule)
  window.addEventListener('online', schedule)
  document.addEventListener('visibilitychange', schedule)
  intervalId = window.setInterval(schedule, intervalMs)
}

function stopDriver() {
  if (intervalId !== null) window.clearInterval(intervalId)
  intervalId = null
  window.removeEventListener('focus', schedule)
  window.removeEventListener('online', schedule)
  document.removeEventListener('visibilitychange', schedule)
}

export function installBrowserReconciliation(
  reconcile: () => void | Promise<void>,
  intervalMs = DASHBOARD_RECONCILIATION_INTERVAL_MS,
) {
  if (typeof window === 'undefined' || typeof document === 'undefined') {
    return () => {}
  }

  subscribers.add(reconcile)
  if (subscribers.size === 1) startDriver(intervalMs)

  return () => {
    subscribers.delete(reconcile)
    if (subscribers.size === 0) stopDriver()
  }
}
