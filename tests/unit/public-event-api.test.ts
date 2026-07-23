import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

const fetchMock = vi.fn()
const runtimeConfig = {
  allowStaticPublicContentFallback: true,
  public: {
    supabaseUrl: 'https://project.supabase.co',
    supabasePublishableKey: 'sb_publishable_example',
  },
}
let handler: () => Promise<unknown>
let originalNodeEnv: string | undefined

describe('public event API', () => {
  beforeAll(async () => {
    originalNodeEnv = process.env.NODE_ENV
    vi.stubGlobal('defineEventHandler', (candidate: typeof handler) => candidate)
    vi.stubGlobal('useRuntimeConfig', () => runtimeConfig)
    vi.stubGlobal('$fetch', fetchMock)
    vi.stubGlobal('createError', (input: { statusCode: number, message: string }) => (
      Object.assign(new Error(input.message), input)
    ))
    handler = (await import('../../server/api/public-event.get')).default
  })

  afterAll(() => {
    process.env.NODE_ENV = originalNodeEnv
    vi.unstubAllGlobals()
  })

  beforeEach(() => {
    process.env.NODE_ENV = 'test'
    runtimeConfig.public.supabaseUrl = 'https://project.supabase.co'
    runtimeConfig.public.supabasePublishableKey = 'sb_publishable_example'
    runtimeConfig.allowStaticPublicContentFallback = true
    fetchMock.mockReset()
  })

  it('uses a publishable key only as apikey and returns sanitized RPC data', async () => {
    fetchMock
      .mockResolvedValueOnce([{
        event_name: 'Hackathon CEITEC',
        event_slug: 'hackathon-ceitec',
        tagline: 'Criando soluções',
        presentation: 'Apresentação',
        objectives: ['Objetivo'],
        venue: 'CAC',
        date_label: '24 e 25 de julho',
        registration_open: true,
        schedule: [],
      }])
      .mockResolvedValueOnce([])

    await expect(handler()).resolves.toMatchObject({
      event_slug: 'hackathon-ceitec',
      results: [],
    })
    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      'https://project.supabase.co/rest/v1/rpc/get_featured_event_content',
      expect.objectContaining({
        headers: { apikey: 'sb_publishable_example' },
      }),
    )
    expect(JSON.stringify(fetchMock.mock.calls)).not.toContain('Authorization')
  })

  it('never exposes the static open-registration fallback in production without config', async () => {
    process.env.NODE_ENV = 'production'
    runtimeConfig.allowStaticPublicContentFallback = false
    runtimeConfig.public.supabaseUrl = ''
    runtimeConfig.public.supabasePublishableKey = ''

    await expect(handler()).rejects.toMatchObject({ statusCode: 503 })
    expect(fetchMock).not.toHaveBeenCalled()
  })

  it('returns a safe 503 instead of static event data when the upstream RPC fails', async () => {
    process.env.NODE_ENV = 'production'
    runtimeConfig.allowStaticPublicContentFallback = false
    fetchMock.mockRejectedValue(new Error('upstream details must not leak'))

    await expect(handler()).rejects.toMatchObject({
      statusCode: 503,
      message: 'Conteúdo público temporariamente indisponível',
    })
  })
})
