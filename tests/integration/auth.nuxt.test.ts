import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { $fetch, setup } from '@nuxt/test-utils/e2e'

describe('auth pages', async () => {
  await setup({ rootDir: fileURLToPath(new URL('../..', import.meta.url)) })

  it('offers password and Google login', async () => {
    const html = await $fetch('/login')

    expect(html).toContain('Entrar com e-mail')
    expect(html).toContain('Continuar com Google')
  })
})
