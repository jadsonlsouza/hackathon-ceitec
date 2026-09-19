import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { $fetch, setup } from '@nuxt/test-utils/e2e'

describe('application shell', async () => {
  await setup({ rootDir: fileURLToPath(new URL('../..', import.meta.url)) })

  it('uses Ligalab for the application title and Hackathon CEITEC for its event detail', async () => {
    expect(await $fetch('/login')).toContain('ligalab')
    expect(await $fetch('/eventos/hackathon-ceitec')).toContain('Hackathon CEITEC')
    expect((await $fetch<{ service: string }>('/api/health')).service).toBe('ligalab')
  })
})
