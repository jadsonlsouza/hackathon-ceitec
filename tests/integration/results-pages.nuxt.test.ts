import { fileURLToPath } from 'node:url'
import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { $fetch, setup } from '@nuxt/test-utils/e2e'

describe('result routes', async () => {
  const rootDir = fileURLToPath(new URL('../..', import.meta.url))
  await setup({ rootDir })

  it('renders the Professor result administration route', async () => {
    const html = await $fetch('/app/evento/demo/admin/resultados')
    expect(html).toContain('Resultados e desempates')
  })

  it('renders the public event-slug result route', async () => {
    const html = await $fetch('/resultados/hackathon-ceitec')
    expect(html).toContain('Resultados do Hackathon')
  })

  it('documents the missing deterministic multi-profile Playwright prerequisite', () => {
    const packageSource = readFileSync(`${rootDir}/package.json`, 'utf8')
    expect(packageSource).not.toContain('multi-profile-auth-harness')
  })
})
