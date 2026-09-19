import { existsSync, statSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { $fetch, setup } from '@nuxt/test-utils/e2e'

describe('Ligalab public landing page', async () => {
  const rootDir = fileURLToPath(new URL('../..', import.meta.url))
  await setup({ rootDir })

  it('renders Ligalab at the root and links visitors to the catalog', async () => {
    const html = await $fetch<string>('/')

    expect(html.match(/<h1(?:\s|>)/g)).toHaveLength(1)
    expect(html).toContain('ligalab')
    expect(html).toContain('href="/eventos"')
    expect(html).toContain('Uma plataforma para transformar desafios em aprendizagem')
    expect(html).toContain('<main')
    expect(html).not.toContain('Acessar sistema de inscrição')
    expect(html).not.toContain('Hackathon CEITEC')
  })

  it('renders the supplied logo with accessible intrinsic dimensions', async () => {
    const html = await $fetch<string>('/')
    const logoPath = `${rootDir}/public/brand/ligalab-color.png`

    expect(existsSync(logoPath)).toBe(true)
    expect(statSync(logoPath).size).toBeGreaterThan(0)
    expect(html).toMatch(
      /<img[^>]+src="\/brand\/ligalab-color\.png"[^>]+alt="ligalab"[^>]+width="1254"[^>]+height="1254"/,
    )
  })
})
