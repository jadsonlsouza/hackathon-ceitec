import { fileURLToPath } from 'node:url'
import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { $fetch, setup } from '@nuxt/test-utils/e2e'

describe('team pages', async () => {
  const rootDir = fileURLToPath(new URL('../..', import.meta.url))
  await setup({ rootDir })

  it('renders the student team page with six reserved member rows', async () => {
    const html = await $fetch('/app/evento/demo/equipe')

    expect(html).toContain('Criar equipe')
    expect(html).toContain('Categoria')
    expect(html).toContain('Integrante 6')
  })

  it('renders the professor pending-team queue', async () => {
    const html = await $fetch('/app/evento/demo/equipes')

    expect(html).toContain('Equipes aguardando validação')
  })

  it('uses per-event data keys, typed RPCs, and the event professor guard', () => {
    const teamPage = readFileSync(
      `${rootDir}/app/pages/app/evento/[eventId]/equipe.vue`,
      'utf8',
    )
    const queuePage = readFileSync(
      `${rootDir}/app/pages/app/evento/[eventId]/equipes.vue`,
      'utf8',
    )

    expect(teamPage).toContain('teamPageKey(eventId.value)')
    expect(teamPage).toContain("'create_team'")
    expect(teamPage).toContain("'request_team_join'")
    expect(teamPage).toContain("'decide_team_join'")
    expect(teamPage).not.toContain(".eq('leader_id'")
    expect(queuePage).toContain('pendingTeamsKey(eventId.value)')
    expect(queuePage).toContain('canManageEventRoleRequests')
    expect(queuePage).toContain("'decide_team'")
    expect(queuePage).toContain(".eq('event_id', eventId.value)")
  })
})
