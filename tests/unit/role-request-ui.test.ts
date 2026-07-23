import { readFileSync } from 'node:fs'
import { describe, expect, it, vi } from 'vitest'
import {
  GLOBAL_ROLE_REQUESTS_KEY,
  ROLE_DECISION_ERROR,
  canManageEventRoleRequests,
  canManageGlobalRoleRequests,
  eventRoleRequestsKey,
  isRequestProcessing,
  submitRoleDecision,
} from '../../app/utils/role-request-workflow'

describe('role request page access', () => {
  it('allows only a global admin to manage professor requests', () => {
    expect(canManageGlobalRoleRequests({ global_role: 'global_admin' })).toBe(true)
    expect(canManageGlobalRoleRequests({ global_role: 'student' })).toBe(false)
    expect(canManageGlobalRoleRequests(null)).toBe(false)
  })

  it('allows only the assigned event professor to manage event requests', () => {
    const roles = [
      { event_id: 'event-1', role: 'professor' },
      { event_id: 'event-2', role: 'monitor' },
    ]

    expect(canManageEventRoleRequests(roles, 'event-1')).toBe(true)
    expect(canManageEventRoleRequests(roles, 'event-2')).toBe(false)
    expect(canManageEventRoleRequests(roles, 'event-3')).toBe(false)
  })
})

describe('role request async-data isolation', () => {
  it('uses a dedicated global key', () => {
    expect(GLOBAL_ROLE_REQUESTS_KEY).toBe('global-professor-role-requests')
  })

  it('changes the event key when navigation changes the event id', () => {
    const firstEventKey = eventRoleRequestsKey('event-1')
    const secondEventKey = eventRoleRequestsKey('event-2')

    expect(firstEventKey).toBe('event-role-requests:event-1')
    expect(secondEventKey).toBe('event-role-requests:event-2')
    expect(secondEventKey).not.toBe(firstEventKey)
  })
})

describe('role request decisions', () => {
  it('sets and clears the matching processing state and refreshes only its key', async () => {
    const rpc = vi.fn().mockResolvedValue({ error: null })
    const refresh = vi.fn().mockResolvedValue(undefined)
    const setProcessing = vi.fn()
    const setError = vi.fn()

    await expect(submitRoleDecision({
      rpc,
      refresh,
      setProcessing,
      setError,
      isProcessing: () => false,
      requestId: 'request-1',
      decision: 'approved',
      refreshKey: 'event-role-requests:event-1',
    })).resolves.toBe(true)

    expect(setProcessing.mock.calls).toEqual([['request-1'], [null]])
    expect(setError).toHaveBeenCalledWith(null)
    expect(refresh).toHaveBeenCalledOnce()
    expect(refresh).toHaveBeenCalledWith('event-role-requests:event-1')
    expect(isRequestProcessing('request-1', 'request-1')).toBe(true)
    expect(isRequestProcessing('request-1', 'request-2')).toBe(true)
  })

  it('shows an inline Portuguese error and does not throw when the RPC fails', async () => {
    const refresh = vi.fn()
    const setProcessing = vi.fn()
    const setError = vi.fn()

    await expect(submitRoleDecision({
      rpc: vi.fn().mockResolvedValue({ error: new Error('database unavailable') }),
      refresh,
      setProcessing,
      setError,
      isProcessing: () => false,
      requestId: 'request-1',
      decision: 'rejected',
      refreshKey: 'global-professor-role-requests',
    })).resolves.toBe(false)

    expect(setError).toHaveBeenCalledWith(ROLE_DECISION_ERROR)
    expect(setProcessing.mock.calls).toEqual([['request-1'], [null]])
    expect(refresh).not.toHaveBeenCalled()
  })

  it('rejects a rapid second decision while the first RPC is in flight', async () => {
    let processingId: string | null = null
    let resolveRpc!: (value: { error: null }) => void
    const rpc = vi.fn().mockImplementation(() => new Promise((resolve) => {
      resolveRpc = resolve
    }))
    const options = {
      rpc,
      refresh: vi.fn().mockResolvedValue(undefined),
      setProcessing: (value: string | null) => processingId = value,
      setError: vi.fn(),
      isProcessing: () => processingId !== null,
      decision: 'approved' as const,
      refreshKey: 'global-professor-role-requests',
    }

    const firstDecision = submitRoleDecision({
      ...options,
      requestId: 'request-1',
    })
    const secondDecision = submitRoleDecision({
      ...options,
      requestId: 'request-2',
    })

    await expect(secondDecision).resolves.toBe(false)
    expect(rpc).toHaveBeenCalledOnce()
    expect(processingId).toBe('request-1')

    resolveRpc({ error: null })
    await expect(firstDecision).resolves.toBe(true)
    expect(processingId).toBeNull()
  })
})

describe('request action contrast', () => {
  it('uses a primary background with at least 4.5:1 contrast against white', () => {
    const css = readFileSync(
      new URL('../../app/assets/css/main.css', import.meta.url),
      'utf8',
    )
    const token = css.match(/\.request-actions button \{[^}]*background: (#[\da-f]{6})/i)?.[1]

    expect(token).toBe('#0369a1')
    expect(contrastRatio(token!, '#ffffff')).toBeGreaterThanOrEqual(4.5)
  })
})

function contrastRatio(first: string, second: string) {
  const luminance = (color: string) => {
    const channels = color.slice(1).match(/.{2}/g)!.map(channel => (
      Number.parseInt(channel, 16) / 255
    )).map(channel => (
      channel <= 0.04045
        ? channel / 12.92
        : ((channel + 0.055) / 1.055) ** 2.4
    ))
    return 0.2126 * channels[0]! + 0.7152 * channels[1]! + 0.0722 * channels[2]!
  }

  const [lighter, darker] = [luminance(first), luminance(second)]
    .sort((a, b) => b - a)
  return (lighter! + 0.05) / (darker! + 0.05)
}
