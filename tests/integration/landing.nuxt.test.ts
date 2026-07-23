import { existsSync, statSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { $fetch, setup } from '@nuxt/test-utils/e2e'

describe('CEITEC public landing page', async () => {
  const rootDir = fileURLToPath(new URL('../..', import.meta.url))
  await setup({ rootDir })

  it('server-renders the complete semantic event presentation', async () => {
    const html = await $fetch<string>('/')

    expect(html.match(/<h1(?:\s|>)/g)).toHaveLength(1)
    for (const text of [
      'Hackathon CEITEC',
      'Criando soluções, conectando o futuro',
      'O Hackathon CEITEC é um evento de dois dias',
      'Promover a criatividade no desenvolvimento de tecnologias sustentáveis',
      'Categoria Júnior',
      'Categoria Sênior',
      '24 e 25 de julho',
      'CAC - CEI Roberto Freire',
      'Dia 1',
      'Dia 2',
    ]) expect(html).toContain(text)
    expect(html).toContain('<main')
    expect(html).toContain('<section')
    expect(html).toContain('<table')
  })

  it('preserves detailed simultaneous tracks and mentor notes', async () => {
    const html = await $fetch<string>('/')

    for (const text of [
      'Fundamental: Protótipos com IA (CAC) / Protótipos com Hardware / Designs que impressionam / Apresentando minha ideia',
      'Médio: Startup (negócio + pitch + validação)',
      'Checkpoint com mentores (pitch 3 min por equipe) e Desenvolvimento inicial',
      'Pré-pitch com mentores (simulação)',
      'Cerimônia de encerramento e premiação',
    ]) expect(html).toContain(text)
  })

  it('offers registration and login while keeping unpublished results absent', async () => {
    const html = await $fetch<string>('/')

    expect(html).toMatch(/href="\/cadastro"/)
    expect(html).toMatch(/href="\/login"/)
    expect(html).not.toContain('data-public-ranking')
    expect(html).not.toContain('Resultado final publicado')
  })

  it('renders the supplied logo with accessible intrinsic dimensions', async () => {
    const html = await $fetch<string>('/')
    const logoPath = `${rootDir}/public/brand/ceitec-horizontal-white.png`

    expect(existsSync(logoPath)).toBe(true)
    expect(statSync(logoPath).size).toBeGreaterThan(0)
    expect(html).toMatch(
      /<img[^>]+src="\/brand\/ceitec-horizontal-white\.png"[^>]+alt="CEITEC"[^>]+width="\d+"[^>]+height="\d+"/,
    )
  })
})
