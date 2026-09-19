import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { $fetch, fetch as nuxtFetch, setup } from '@nuxt/test-utils/e2e'

describe('dashboard and recovery endpoints', async () => {
  await setup({ rootDir: fileURLToPath(new URL('../..', import.meta.url)) })

  it('server-renders the authenticated dashboard shell safely', async () => {
    const html = await $fetch<string>('/app')

    expect(html).toContain('Painel Ligalab')
    expect(html).toContain('Nenhum acesso ativo')
    expect(html).not.toContain('service_role')
  })

  it('keeps the global audit navigation target routable', async () => {
    const html = await $fetch<string>('/app/admin/auditoria')

    expect(html).toContain('Auditoria')
    expect(html).not.toContain('stack')
  })

  it('returns a minimal non-cacheable health contract', async () => {
    const response = await nuxtFetch('/api/health')
    const body = await response.json() as {
      ok: boolean
      service: string
      timestamp: string
    }

    expect(body).toEqual({
      ok: true,
      service: 'ligalab',
      timestamp: expect.any(String),
    })
    expect(new Date(body.timestamp).toISOString()).toBe(body.timestamp)
    expect(response.headers.get('cache-control')).toContain('no-store')
    expect(JSON.stringify(body)).not.toMatch(/secret|database|supabase/i)
  })
})
