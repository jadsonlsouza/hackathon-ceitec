import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

const fetchMock = vi.fn()
const runtimeConfig = {
  allowStaticPublicContentFallback: false,
  public: {
    supabaseUrl: 'https://project.supabase.co',
    supabasePublishableKey: 'sb_publishable_example',
  },
}

type Handler = (event?: { slug?: string }) => Promise<unknown>

let catalogHandler: Handler
let detailHandler: Handler

describe('public events API', () => {
  beforeAll(async () => {
    vi.stubGlobal('defineEventHandler', (candidate: Handler) => candidate)
    vi.stubGlobal('useRuntimeConfig', () => runtimeConfig)
    vi.stubGlobal('$fetch', fetchMock)
    vi.stubGlobal('getRouterParam', (event: { slug?: string }, key: string) => key === 'eventSlug' ? event.slug : undefined)
    vi.stubGlobal('createError', (input: { statusCode: number, statusMessage: string }) => (
      Object.assign(new Error(input.statusMessage), input)
    ))

    catalogHandler = (await import('../../server/api/public-events.get')).default
    detailHandler = (await import('../../server/api/public-events/[eventSlug].get')).default
  })

  afterAll(() => vi.unstubAllGlobals())

  beforeEach(() => {
    runtimeConfig.public.supabaseUrl = 'https://project.supabase.co'
    runtimeConfig.public.supabasePublishableKey = 'sb_publishable_example'
    runtimeConfig.allowStaticPublicContentFallback = false
    fetchMock.mockReset()
  })

  it('uses only apikey when fetching the public event catalog', async () => {
    fetchMock.mockResolvedValueOnce([{
      event_name: 'Hackathon CEITEC',
      event_slug: 'hackathon-ceitec',
      tagline: 'Criando soluções',
      venue: 'CAC',
      date_label: '24 e 25 de julho',
      registration_open: true,
    }])

    await expect(catalogHandler()).resolves.toMatchObject([{ event_slug: 'hackathon-ceitec' }])
    expect(fetchMock).toHaveBeenCalledWith(
      'https://project.supabase.co/rest/v1/rpc/get_public_event_catalog',
      { method: 'POST', headers: { apikey: 'sb_publishable_example' }, body: {} },
    )
    expect(JSON.stringify(fetchMock.mock.calls)).not.toContain('Authorization')
  })

  it('returns a sanitized 503 rather than an event fallback when production catalog loading fails', async () => {
    fetchMock.mockRejectedValueOnce(new Error('connection refused'))

    await expect(catalogHandler()).rejects.toMatchObject({
      statusCode: 503,
      statusMessage: 'Eventos temporariamente indisponíveis.',
    })
  })

  it('queries one valid slug and returns a safe 404 for a missing event', async () => {
    fetchMock.mockResolvedValueOnce([])

    await expect(detailHandler({ slug: 'evento-inexistente' })).rejects.toMatchObject({
      statusCode: 404,
      statusMessage: 'Evento não encontrado.',
    })
    expect(fetchMock).toHaveBeenCalledWith(
      'https://project.supabase.co/rest/v1/rpc/get_public_event_content',
      { method: 'POST', headers: { apikey: 'sb_publishable_example' }, body: { requested_slug: 'evento-inexistente' } },
    )
  })

  it('rejects malformed slugs before calling the public API', async () => {
    await expect(detailHandler({ slug: '../interno' })).rejects.toMatchObject({ statusCode: 404 })
    expect(fetchMock).not.toHaveBeenCalled()
  })
})
