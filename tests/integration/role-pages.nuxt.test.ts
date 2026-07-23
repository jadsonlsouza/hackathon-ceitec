import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { $fetch, setup } from '@nuxt/test-utils/e2e'

describe('role request pages', async () => {
  await setup({ rootDir: fileURLToPath(new URL('../..', import.meta.url)) })

  it('renders the global professor approval page', async () => {
    const html = await $fetch('/app/admin/solicitacoes')

    expect(html).toContain('Solicitações de Professor')
  })

  it('renders the event team approval page', async () => {
    const html = await $fetch('/app/evento/event-1/solicitacoes')

    expect(html).toContain('Solicitações do evento')
  })
})
