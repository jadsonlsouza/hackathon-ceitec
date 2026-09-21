import { readFile } from 'node:fs/promises'
import { createClient } from '@supabase/supabase-js'
import { expect, test, type APIRequestContext } from '@playwright/test'
import {
  E2E_ACTIVITY_A,
  E2E_ARCHIVED_EVENT,
  E2E_EVENT_A,
  E2E_EVENT_B,
  E2E_PASSWORD,
  E2E_SUBMISSION_B,
  E2E_TEAM_A,
  E2E_TEAM_B,
  E2E_USERS,
} from './support/global-setup'
import { localSupabaseEnvironment } from './support/local-supabase'

test.describe.configure({ mode: 'serial' })
const local = localSupabaseEnvironment()

async function token(profile: keyof typeof E2E_USERS) {
  const state = JSON.parse(
    await readFile(`tests/e2e/.auth/${profile}.json`, 'utf8'),
  ) as { origins: Array<{ localStorage: Array<{ value: string }> }> }
  return JSON.parse(state.origins[0]!.localStorage[0]!.value).access_token as string
}

function headers(jwt?: string) {
  return {
    apikey: local.publishableKey,
    ...(jwt ? { Authorization: `Bearer ${jwt}` } : {}),
    'Content-Type': 'application/json',
  }
}

async function rest(
  request: APIRequestContext,
  path: string,
  profile?: keyof typeof E2E_USERS,
  options: { method?: string, data?: unknown } = {},
) {
  return request.fetch(`${local.apiUrl}/rest/v1/${path}`, {
    method: options.method ?? 'GET',
    headers: headers(profile ? await token(profile) : undefined),
    data: options.data,
  })
}

async function expectDenied(response: Awaited<ReturnType<typeof rest>>, protectedText?: string) {
  const body = await response.text()
  expect(
    response.status() === 401
    || response.status() === 403
    || response.status() === 404
    || (response.ok() && (body === '[]' || body === '')),
    `Resposta inesperada ${response.status()}: ${body}`,
  ).toBe(true)
  if (protectedText) expect(body).not.toContain(protectedText)
}

test('Aluno não lê rascunho nem respostas de outra equipe/evento', async ({ request }) => {
  const draft = await rest(
    request,
    `submissions?select=id,status,team_id&id=eq.${E2E_SUBMISSION_B}`,
    'studentA',
  )
  await expectDenied(draft, E2E_TEAM_B)

  const answer = await rest(
    request,
    `submission_answers?select=content&submission_id=eq.${E2E_SUBMISSION_B}`,
    'studentA',
  )
  await expectDenied(answer, 'SEGREDO-EQUIPE-BOREAL')
})

test('Notificações respeitam destinatário, escopo do professor e ações da campainha', async ({ request, browser }) => {
  const foreign = await rest(request, 'rpc/create_manual_notifications', 'professorA', {
    method: 'POST', data: { input: { event_id: E2E_EVENT_B, audience: { type: 'event_role', role: 'monitor' }, title: 'Proibida', body: 'Nunca entregue' } },
  })
  expect(foreign.ok()).toBe(false)
  const created = await rest(request, 'rpc/create_manual_notifications', 'professorA', {
    method: 'POST', data: { input: { event_id: E2E_EVENT_A, audience: { type: 'event_role', role: 'student' }, title: 'Aviso E2E privado', body: 'Somente participantes A' } },
  })
  expect(created.ok()).toBe(true)
  const inbox = await rest(request, 'rpc/get_notification_inbox', 'studentA', { method: 'POST', data: {} })
  expect(inbox.ok()).toBe(true)
  const own = (await inbox.json() as Array<{ id: string, title: string }>).find(item => item.title === 'Aviso E2E privado')!
  expect(own).toBeTruthy()
  const otherInbox = await rest(request, 'rpc/get_notification_inbox', 'studentB', { method: 'POST', data: {} })
  expect(await otherInbox.text()).not.toContain(own.id)
  const wrongRead = await rest(request, 'rpc/mark_notifications_read', 'studentB', { method: 'POST', data: { notification_ids: [own.id] } })
  expect(await wrongRead.json()).toBe(0)
  await expectDenied(await rest(request, 'notifications', 'studentA', { method: 'POST', data: { title: 'Bypass' } }))
  const context = await browser.newContext({ storageState: 'tests/e2e/.auth/studentA.json' })
  const page = await context.newPage()
  await page.goto('/app')
  await page.locator('[data-notification-trigger]').click()
  await expect(page.locator(`[data-notification-item="${own.id}"]`)).toBeVisible()
  await page.locator(`[data-notification-item="${own.id}"]`).click()
  await expect(page.locator(`[data-notification-item="${own.id}"]`).locator('..')).toContainText('Lida')
  await context.close()
})

test('Monitor não aprova equipe nem reabre submissão', async ({ request }) => {
  await expectDenied(await rest(request, 'rpc/decide_team', 'monitor', {
    method: 'POST',
    data: { team_id: E2E_TEAM_A, decision: 'approved' },
  }))
  await expectDenied(await rest(request, 'rpc/reopen_submission', 'monitor', {
    method: 'POST',
    data: {
      submission_id: 'da000000-0000-4000-8000-000000000001',
      reason: 'Tentativa indevida do Monitor',
    },
  }))
})

test('Avaliador não lê outra categoria nem modifica nota alheia', async ({ request }) => {
  const seniorSlots = await rest(
    request,
    `presentation_slots?select=team_id,category&event_id=eq.${E2E_EVENT_A}&category=eq.senior`,
    'evaluatorJunior',
  )
  await expectDenied(seniorSlots, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3')

  const foreignScore = await rest(
    request,
    'evaluation_scores?evaluation_id=eq.ea000000-0000-4000-8000-000000000003',
    'evaluatorJunior',
    { method: 'PATCH', data: { score: 1 } },
  )
  await expectDenied(foreignScore)
})

test('Professor não acessa evento alheio nem edita seu conteúdo público', async ({ request, page }) => {
  await expectDenied(await rest(request, 'rpc/get_administrative_ranking', 'professorA', {
    method: 'POST',
    data: { target_event: E2E_EVENT_B },
  }), 'Equipe Boreal')

  await expectDenied(await rest(request, 'rpc/save_event_public_content', 'professorA', {
    method: 'POST',
    data: {
      target_event: E2E_EVENT_B,
      content: {
        tagline: 'Alteração indevida',
        presentation: 'Alteração indevida',
        objectives: ['Alteração indevida'],
        venue: 'Alteração indevida',
        dateLabel: 'Hoje',
        registrationOpen: false,
        schedule: [],
      },
    },
  }))

  await page.context().addCookies([])
  await page.goto(`/app/evento/${E2E_EVENT_B}/admin/resultados`)
  await expect(page).toHaveURL(/\/login/)
})

test('Anônimo não lê ranking administrativo ou publicação privada', async ({ request }) => {
  await expectDenied(await rest(request, 'rpc/get_administrative_ranking', undefined, {
    method: 'POST',
    data: { target_event: E2E_EVENT_A },
  }), 'Equipe Aurora')
  await expectDenied(await rest(request, 'rpc/get_administrative_publications', undefined, {
    method: 'POST',
    data: { target_event: E2E_EVENT_A },
  }), 'published_by')
})

test('Não global não arquiva/limpa evento e segredo não retorna no corpo', async ({ request }) => {
  const response = await request.post('/api/admin/archive-event', {
    headers: { Authorization: `Bearer ${await token('professorA')}` },
    data: {
      eventId: E2E_EVENT_A,
      eventName: 'Hackathon CEITEC E2E A',
      archiveSecret: 'SEGREDO-QUE-NAO-DEVE-RETORNAR',
    },
  })
  expect([401, 403]).toContain(response.status())
  expect(await response.text()).not.toContain('SEGREDO-QUE-NAO-DEVE-RETORNAR')
})

test('Somente o administrador global cria ou duplica rascunhos de eventos', async ({ request }) => {
  const denied = await rest(request, 'rpc/create_event_draft', 'professorA', {
    method: 'POST',
    data: {
      draft: {
        name: 'Rascunho proibido E2E',
        slug: 'rascunho-proibido-e2e',
        professor_id: '00000000-0000-0000-0000-000000000000',
      },
    },
  })
  await expectDenied(denied)

  const service = createClient(local.apiUrl, local.serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data: users, error: usersError } = await service.auth.admin.listUsers()
  if (usersError) throw usersError
  const admin = users.users.find(user => user.email === E2E_USERS.admin[0])
  expect(admin).toBeTruthy()

  const created = await rest(request, 'rpc/create_event_draft', 'admin', {
    method: 'POST',
    data: {
      draft: {
        name: 'Rascunho global E2E',
        slug: 'rascunho-global-e2e',
        professor_id: admin!.id,
      },
    },
  })
  expect(created.ok()).toBe(true)
  const [{ event_id: createdId }] = await created.json() as Array<{ event_id: string }>

  const cloned = await rest(request, 'rpc/duplicate_event_configuration', 'admin', {
    method: 'POST',
    data: {
      source_event_id: E2E_EVENT_A,
      draft: {
        name: 'Cópia global E2E',
        slug: 'copia-global-e2e',
        professor_id: admin!.id,
      },
      copy_options: {},
    },
  })
  expect(cloned.ok()).toBe(true)
  const [{ event_id: clonedId }] = await cloned.json() as Array<{ event_id: string }>

  const [createdEvent, clonedTeams] = await Promise.all([
    rest(request, `events?select=status&id=eq.${createdId}`, 'admin'),
    rest(request, `teams?select=id&event_id=eq.${clonedId}`, 'admin'),
  ])
  expect(await createdEvent.json()).toEqual([{ status: 'draft' }])
  expect(await clonedTeams.json()).toEqual([])
})

test('Evento arquivado rejeita novas escritas', async ({ request }) => {
  await expectDenied(await rest(request, 'rpc/create_team', 'studentA', {
    method: 'POST',
    data: {
      event_id: E2E_ARCHIVED_EVENT,
      team_name: 'Equipe indevida',
      category: 'junior',
      members: [{
        name: 'Aluno A',
        email: E2E_USERS.studentA[0],
        enrollment: 'arquivado-e2e',
      }],
    },
  }))
})

test('Snapshot publicado é imutável por API autenticada', async ({ request }) => {
  await expectDenied(await rest(
    request,
    `published_results?event_id=eq.${E2E_EVENT_A}&category=eq.junior`,
    'professorA',
    { method: 'PATCH', data: { ranking: [{ position: 1, team_name: 'Fraude', score: 5 }] } },
  ))
})

test('Resultados anônimos só aparecem após as duas categorias e são sanitizados', async ({ request }) => {
  const incomplete = await rest(request, 'rpc/get_published_results', undefined, {
    method: 'POST',
    data: { event_slug: 'hackathon-e2e-b' },
  })
  expect(incomplete.ok()).toBe(true)
  expect(await incomplete.json()).toEqual([])

  const published = await rest(request, 'rpc/get_published_results', undefined, {
    method: 'POST',
    data: { event_slug: 'hackathon-e2e-a' },
  })
  expect(published.ok()).toBe(true)
  const body = await published.text()
  expect(body).toContain('Equipe Aurora')
  for (const secret of [
    'SEGREDO-EQUIPE-BOREAL',
    E2E_USERS.studentA[0],
    'Avaliação E2E',
    'published_by',
  ]) expect(body).not.toContain(secret)
})

test('Revogação do papel atual remove acesso imediatamente', async ({ request }) => {
  const before = await rest(
    request,
    `presentation_slots?select=team_id&event_id=eq.${E2E_EVENT_A}`,
    'evaluatorJunior',
  )
  expect(before.ok()).toBe(true)
  expect(await before.text()).toContain(E2E_TEAM_A)

  const service = createClient(local.apiUrl, local.serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data: user, error: userError } = await service.auth.admin.listUsers()
  if (userError) throw userError
  const evaluator = user.users.find(item => item.email === E2E_USERS.evaluatorJunior[0])
  expect(evaluator).toBeTruthy()
  const { error: revokeError } = await service
    .from('event_roles')
    .delete()
    .eq('event_id', E2E_EVENT_A)
    .eq('user_id', evaluator!.id)
    .eq('role', 'evaluator')
  if (revokeError) throw revokeError

  const after = await rest(
    request,
    `presentation_slots?select=team_id&event_id=eq.${E2E_EVENT_A}`,
    'evaluatorJunior',
  )
  await expectDenied(after, E2E_TEAM_A)
})

test('Credenciais de fixture permanecem locais e funcionam como usuários reais', async () => {
  const client = createClient(local.apiUrl, local.publishableKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data, error } = await client.auth.signInWithPassword({
    email: E2E_USERS.studentB[0],
    password: E2E_PASSWORD,
  })
  expect(error).toBeNull()
  expect(data.user?.email).toBe(E2E_USERS.studentB[0])
  await client.auth.signOut()
})
