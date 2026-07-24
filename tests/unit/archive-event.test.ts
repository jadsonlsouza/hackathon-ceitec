import { describe, expect, it, vi } from 'vitest'
import { processArchiveEvent } from '../../server/api/admin/archive-event.post'

const USER_ID = '00000000-0000-4000-8000-000000000001'
const EVENT_ID = '10000000-0000-4000-8000-000000000001'
const NEW_EVENT_ID = '10000000-0000-4000-8000-000000000002'
const ARCHIVE_SECRET = 'segredo-de-arquivamento'
const NOW_SECONDS = 1_800_000_000

function supabaseTokenWithAmr(
  authenticationTime: number,
  amr: Array<{ method: string, timestamp: number }> = [{
    method: 'password',
    timestamp: authenticationTime,
  }],
) {
  const payload = Buffer.from(JSON.stringify({
    aal: 'aal1',
    amr,
    aud: 'authenticated',
    email: 'admin@example.test',
    exp: NOW_SECONDS + 3600,
    iat: NOW_SECONDS - 30,
    iss: 'https://project-ref.supabase.co/auth/v1',
    role: 'authenticated',
    session_id: '20000000-0000-4000-8000-000000000001',
    sub: USER_ID,
    is_anonymous: false,
  }))
    .toString('base64url')

  return `header.${payload}.signature`
}

function adminClient(options: {
  globalRole?: 'student' | 'global_admin'
  rpcError?: { message: string, code?: string } | null
} = {}) {
  const rpc = vi.fn().mockResolvedValue({
    data: options.rpcError
      ? null
      : [{
          archived_event_id: EVENT_ID,
          new_event_id: NEW_EVENT_ID,
        }],
    error: options.rpcError ?? null,
  })
  const single = vi.fn().mockResolvedValue({
    data: { global_role: options.globalRole ?? 'global_admin' },
    error: null,
  })
  const eq = vi.fn(() => ({ single }))
  const select = vi.fn(() => ({ eq }))
  const from = vi.fn(() => ({ select }))
  const getUser = vi.fn().mockResolvedValue({
    data: {
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
    error: null,
  })

  return {
    client: {
      auth: { getUser },
      from,
      rpc,
    },
    getUser,
    rpc,
  }
}

function request(overrides: Record<string, unknown> = {}) {
  return {
    authorization: `Bearer ${supabaseTokenWithAmr(NOW_SECONDS - 60)}`,
    body: {
      eventId: EVENT_ID,
      eventName: 'Hackathon CEITEC',
      archiveSecret: ARCHIVE_SECRET,
    },
    nowSeconds: NOW_SECONDS,
    ...overrides,
  }
}

describe('POST /api/admin/archive-event', () => {
  it('rejects an invalid archive secret without calling the transaction', async () => {
    const { client, rpc } = adminClient()

    await expect(processArchiveEvent(
      request({
        body: {
          eventId: EVENT_ID,
          eventName: 'Hackathon CEITEC',
          archiveSecret: 'segredo-incorreto',
        },
      }),
      { admin: client, archiveSecret: ARCHIVE_SECRET },
    )).rejects.toMatchObject({ statusCode: 403 })
    expect(rpc).not.toHaveBeenCalled()
  })

  it('rejects a verified caller who is not a global admin', async () => {
    const { client, rpc } = adminClient({ globalRole: 'student' })

    await expect(processArchiveEvent(
      request(),
      { admin: client, archiveSecret: ARCHIVE_SECRET },
    )).rejects.toMatchObject({ statusCode: 403 })
    expect(rpc).not.toHaveBeenCalled()
  })

  it('maps an exact-name mismatch from the transaction to a bad request', async () => {
    const { client } = adminClient({
      rpcError: { message: 'event_name_mismatch', code: 'P0001' },
    })

    await expect(processArchiveEvent(
      request(),
      { admin: client, archiveSecret: ARCHIVE_SECRET },
    )).rejects.toMatchObject({ statusCode: 400 })
  })

  it('rejects archiving an event that is not the current featured event', async () => {
    const { client } = adminClient({
      rpcError: { message: 'event_not_featured', code: 'P0001' },
    })

    await expect(processArchiveEvent(
      request(),
      { admin: client, archiveSecret: ARCHIVE_SECRET },
    )).rejects.toMatchObject({ statusCode: 409 })
  })

  it('rejects a session authenticated more than ten minutes ago', async () => {
    const { client, rpc } = adminClient()

    await expect(processArchiveEvent(
      request({
        authorization: `Bearer ${supabaseTokenWithAmr(NOW_SECONDS - 601)}`,
      }),
      { admin: client, archiveSecret: ARCHIVE_SECRET },
    )).rejects.toMatchObject({ statusCode: 401 })
    expect(rpc).not.toHaveBeenCalled()
  })

  it('does not treat a recent token refresh as recent authentication', async () => {
    const { client, rpc } = adminClient()
    const token = supabaseTokenWithAmr(NOW_SECONDS - 900, [
      { method: 'password', timestamp: NOW_SECONDS - 900 },
      { method: 'token_refresh', timestamp: NOW_SECONDS - 10 },
    ])

    await expect(processArchiveEvent(
      request({ authorization: `Bearer ${token}` }),
      { admin: client, archiveSecret: ARCHIVE_SECRET },
    )).rejects.toMatchObject({ statusCode: 401 })
    expect(rpc).not.toHaveBeenCalled()
  })

  it('rejects an authentication timestamp beyond the clock-skew allowance', async () => {
    const { client, rpc } = adminClient()
    const token = supabaseTokenWithAmr(NOW_SECONDS + 61)

    await expect(processArchiveEvent(
      request({ authorization: `Bearer ${token}` }),
      { admin: client, archiveSecret: ARCHIVE_SECRET },
    )).rejects.toMatchObject({ statusCode: 401 })
    expect(rpc).not.toHaveBeenCalled()
  })

  it('rejects anonymous callers before any privileged operation', async () => {
    const { client, getUser, rpc } = adminClient()

    await expect(processArchiveEvent(
      request({ authorization: undefined }),
      { admin: client, archiveSecret: ARCHIVE_SECRET },
    )).rejects.toMatchObject({ statusCode: 401 })
    expect(getUser).not.toHaveBeenCalled()
    expect(rpc).not.toHaveBeenCalled()
  })

  it('calls exactly one transaction with the verified actor and returns its ids', async () => {
    const { client, getUser, rpc } = adminClient()
    const bearer = supabaseTokenWithAmr(NOW_SECONDS - 60)

    await expect(processArchiveEvent(
      request({ authorization: `Bearer ${bearer}` }),
      { admin: client, archiveSecret: ARCHIVE_SECRET },
    )).resolves.toEqual({
      archivedEventId: EVENT_ID,
      newEventId: NEW_EVENT_ID,
    })
    expect(getUser).toHaveBeenCalledWith(bearer)
    expect(rpc).toHaveBeenCalledTimes(1)
    expect(rpc).toHaveBeenCalledWith('archive_and_create_event', {
      target_event: EVENT_ID,
      confirmed_name: 'Hackathon CEITEC',
      actor: USER_ID,
      copy_config: false,
    })
  })
})
