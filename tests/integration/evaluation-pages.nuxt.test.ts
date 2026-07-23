import { fileURLToPath } from 'node:url'
import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { $fetch, setup } from '@nuxt/test-utils/e2e'

describe('evaluation routes', async () => {
  const rootDir = fileURLToPath(new URL('../..', import.meta.url))
  await setup({ rootDir })

  it('renders the mobile evaluator queue route', async () => {
    const html = await $fetch('/app/evento/demo/avaliacao')
    expect(html).toContain('Fila de avaliação')
  })

  it('renders the evaluator form route', async () => {
    const html = await $fetch('/app/evento/demo/avaliacao/team-demo')
    expect(html).toContain('Avaliar apresentação')
  })

  it('renders the Professor evaluation administration route', async () => {
    const html = await $fetch('/app/evento/demo/admin/avaliacao')
    expect(html).toContain('Configuração da avaliação')
  })

  it('does not introduce a browser E2E without a multi-profile auth harness', () => {
    const packageSource = readFileSync(`${rootDir}/package.json`, 'utf8')
    expect(packageSource).not.toContain('multi-profile-auth-harness')
  })
})
