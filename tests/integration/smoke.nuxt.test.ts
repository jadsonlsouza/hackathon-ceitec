import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { $fetch, setup } from '@nuxt/test-utils/e2e'

describe('application shell', async () => {
  await setup({ rootDir: fileURLToPath(new URL('../..', import.meta.url)) })

  it('renders the CEITEC heading', async () => {
    expect(await $fetch('/')).toContain('Hackathon CEITEC')
  })
})
