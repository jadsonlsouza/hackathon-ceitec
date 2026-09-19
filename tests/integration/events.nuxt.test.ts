import { describe, expect, it } from 'vitest'
import { $fetch, setup } from '@nuxt/test-utils/e2e'
import { fileURLToPath } from 'node:url'

describe('public event routes', async () => {
  const rootDir = fileURLToPath(new URL('../..', import.meta.url))
  await setup({ rootDir })

  it('renders the CEITEC event from its slug without renaming it', async () => {
    const html = await $fetch<string>('/eventos/hackathon-ceitec')

    expect(html).toContain('Hackathon CEITEC')
    expect(html).toContain('Criando soluções, conectando o futuro')
    expect(html).toContain('Fundamental: Protótipos com IA')
    expect(html).toContain('href="/eventos"')
  })

  it('renders catalog cards without exposing private participant data', async () => {
    const html = await $fetch<string>('/eventos')

    expect(html).toContain('Eventos')
    expect(html).toContain('Hackathon CEITEC')
    expect(html).toContain('href="/eventos/hackathon-ceitec"')
    expect(html).not.toContain('team_members')
  })

  it('uses a safe unavailable state for an unknown event', async () => {
    const html = await $fetch<string>('/eventos/inexistente', { ignoreResponseError: true })

    expect(html).toContain('Evento não encontrado')
    expect(html).toContain('href="/eventos"')
    expect(html).toContain('href="/login"')
    expect(html).not.toContain('href="/cadastro"')
  })
})
