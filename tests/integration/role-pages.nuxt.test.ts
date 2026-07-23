import { fileURLToPath } from 'node:url'
import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { $fetch, setup } from '@nuxt/test-utils/e2e'

describe('role request pages', async () => {
  const rootDir = fileURLToPath(new URL('../..', import.meta.url))
  await setup({ rootDir })

  it('renders the global professor approval page', async () => {
    const html = await $fetch('/app/admin/solicitacoes')

    expect(html).toContain('Solicitações de Professor')
  })

  it('renders the event team approval page', async () => {
    const html = await $fetch('/app/evento/event-1/solicitacoes')

    expect(html).toContain('Solicitações do evento')
  })

  it('wires each page to its own authorization guard and async-data key', () => {
    const globalPage = readFileSync(
      `${rootDir}/app/pages/app/admin/solicitacoes.vue`,
      'utf8',
    )
    const eventPage = readFileSync(
      `${rootDir}/app/pages/app/evento/[eventId]/solicitacoes.vue`,
      'utf8',
    )

    expect(globalPage).toContain('canManageGlobalRoleRequests')
    expect(globalPage).toContain('GLOBAL_ROLE_REQUESTS_KEY')
    expect(globalPage).toContain(
      'Você não tem autorização para gerenciar solicitações de Professor.',
    )
    expect(eventPage).toContain('canManageEventRoleRequests')
    expect(eventPage).toContain('eventRoleRequestsKey(eventId.value)')
    expect(eventPage).toContain(
      'Você não é o Professor responsável por este evento.',
    )
  })

  it('renders inline alert regions and disables actions while processing', () => {
    for (const path of [
      'app/pages/app/admin/solicitacoes.vue',
      'app/pages/app/evento/[eventId]/solicitacoes.vue',
    ]) {
      const page = readFileSync(`${rootDir}/${path}`, 'utf8')

      expect(page).toContain('role="alert"')
      expect(page).toContain(
        '<p v-if="processingId" class="request-status" role="alert">',
      )
      expect(page).toContain('Processando decisão…')
      expect(page).toContain('isRequestProcessing(processingId, request.id)')
      expect(page).toContain(
        'if (!isAuthorized.value || processingId.value) return',
      )
      expect(page).not.toContain('throw createError')
    }
  })
})
