import AxeBuilder from '@axe-core/playwright'
import { expect, test, type Page } from '@playwright/test'
import {
  E2E_ACTIVITY_A,
  E2E_EVENT_A,
  E2E_TEAM_A,
} from './support/global-setup'

const authState = (profile: string) => `tests/e2e/.auth/${profile}.json`

async function waitForNuxtHydration(page: Page) {
  await page.waitForFunction(() => Boolean(
    (document.querySelector('main') as HTMLElement & {
      __vueParentComponent?: unknown
    } | null)?.__vueParentComponent,
  ))
}

async function expectAccessible(page: Page) {
  await waitForNuxtHydration(page)
  const result = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'])
    .analyze()
  const releaseBlocking = result.violations.filter(
    violation => violation.impact === 'serious' || violation.impact === 'critical',
  )
  expect(releaseBlocking, JSON.stringify(releaseBlocking, null, 2)).toEqual([])
}

test.describe('páginas públicas', () => {
  for (const [path, heading] of [
    ['/', 'Uma plataforma para transformar desafios em aprendizagem.'],
    ['/eventos', 'Encontre o próximo desafio'],
    ['/login', 'Entrar'],
    ['/cadastro', 'Criar conta'],
    ['/resultados/hackathon-e2e-a', 'Resultados do evento'],
  ] as const) {
    test(`${path} não possui violações graves`, async ({ page }) => {
      await page.goto(path)
      await expect(page.getByRole('heading', { name: heading, level: 1 })).toBeVisible()
      await expectAccessible(page)
    })
  }

  test('skip link alcança o conteúdo principal', async ({ page }) => {
    await page.goto('/')
    await waitForNuxtHydration(page)
    await page.keyboard.press('Tab')
    const skipLink = page.getByRole('link', { name: 'Pular para o conteúdo' })
    await expect(skipLink).toBeFocused()
    await skipLink.press('Enter')
    await expect(page.locator('#conteudo-principal')).toBeFocused()
  })

  test('validação leva o foco ao primeiro campo inválido', async ({ page }) => {
    await page.goto('/login')
    await waitForNuxtHydration(page)
    await page.getByRole('button', { name: 'Entrar com e-mail' }).click()
    await expect(page.locator('#login-email')).toBeFocused()
    await expect(page.locator('#login-email')).toHaveAttribute('aria-invalid', 'true')
    await expect(page.getByRole('alert').first()).toBeVisible()
  })
})

test.describe('aluno autenticado', () => {
  test.use({ storageState: authState('studentA') })

  for (const [path, heading] of [
    ['/app', 'Painel Ligalab'],
    [`/app/evento/${E2E_EVENT_A}/equipe`, 'Sua equipe'],
    [`/app/evento/${E2E_EVENT_A}/atividades`, 'Atividades'],
    [`/app/evento/${E2E_EVENT_A}/atividades/${E2E_ACTIVITY_A}`, 'Canvas de impacto'],
  ] as const) {
    test(`${heading} é uma página autenticada acessível`, async ({ page }) => {
      await page.goto(path)
      await expect(page).toHaveURL(new RegExp(path.replaceAll('/', '\\/')))
      await expect(page.getByRole('heading', { name: heading, level: 1 })).toBeVisible()
      await expectAccessible(page)
    })
  }

  test('drawer móvel abre, recebe foco e fecha com Escape', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'mobile', 'O drawer só existe no layout móvel.')
    await page.goto('/app')
    const menu = page.getByRole('button', { name: 'Menu' })
    await menu.click()
    await expect(menu).toHaveAttribute('aria-expanded', 'true')
    await expect(page.locator('[data-dashboard-link]').first()).toBeFocused()
    await page.keyboard.press('Escape')
    await expect(menu).toHaveAttribute('aria-expanded', 'false')
    await expect(menu).toBeFocused()
  })
})

test.describe('Monitor autenticado', () => {
  test.use({ storageState: authState('monitor') })

  test('fila de revisão é real e acessível', async ({ page }) => {
    await page.goto(`/app/evento/${E2E_EVENT_A}/revisoes`)
    await expect(page.getByRole('heading', { name: 'Fila de validação dos Canvas' })).toBeVisible()
    await expect(page.getByText('Equipe Aurora')).toBeVisible()
    await expectAccessible(page)
  })
})

test.describe('Avaliador autenticado', () => {
  test.use({ storageState: authState('evaluatorJunior') })

  test('fila e formulário de notas são reais e acessíveis', async ({ page }) => {
    await page.goto(`/app/evento/${E2E_EVENT_A}/avaliacao`)
    await expect(page.getByRole('heading', { name: 'Fila de avaliação' })).toBeVisible()
    await expect(page.getByText('Equipe Aurora')).toBeVisible()
    await expectAccessible(page)

    await page.goto(`/app/evento/${E2E_EVENT_A}/avaliacao/${E2E_TEAM_A}`)
    await expect(page.getByRole('heading', { name: 'Avaliar apresentação' })).toBeVisible()
    await expect(page.getByRole('radiogroup').first()).toBeVisible()
    await expectAccessible(page)
  })

  test('radiogroup aceita setas, Home e End', async ({ page }) => {
    await page.goto(`/app/evento/${E2E_EVENT_A}/avaliacao/${E2E_TEAM_A}`)
    const group = page.getByRole('radiogroup').first()
    const one = group.getByRole('radio', { name: '1 de 5' })
    await one.focus()
    await one.press('End')
    await expect(group.getByRole('radio', { name: '5 de 5' })).toBeFocused()
    await page.keyboard.press('Home')
    await expect(one).toBeFocused()
    await page.keyboard.press('ArrowRight')
    await expect(group.getByRole('radio', { name: '2 de 5' })).toBeFocused()
  })

  test('avaliação incompleta leva o foco ao primeiro critério', async ({ page }) => {
    await page.goto(`/app/evento/${E2E_EVENT_A}/avaliacao/${E2E_TEAM_A}`)
    await page.getByRole('button', { name: 'Salvar avaliação' }).click()
    await expect(page.getByRole('alert')).toContainText('Informe uma nota')
    await expect(page.getByRole('radio', { name: '1 de 5' }).first()).toBeFocused()
  })
})

test.describe('Professor autenticado', () => {
  test.use({ storageState: authState('professorA') })

  for (const [path, heading] of [
    [`/app/evento/${E2E_EVENT_A}/admin/avaliacao`, 'Configuração da avaliação'],
    [`/app/evento/${E2E_EVENT_A}/admin/resultados`, 'Resultados e desempates'],
    [`/app/evento/${E2E_EVENT_A}/admin/conteudo-publico`, 'Conteúdo público'],
  ] as const) {
    test(`${heading} é acessível`, async ({ page }) => {
      await page.goto(path)
      await expect(page.getByRole('heading', { name: heading, level: 1 })).toBeVisible()
      await expect(page.getByText('Somente o Professor responsável')).toHaveCount(0)
      await expectAccessible(page)
    })
  }

  test('desempate pode ser reordenado e justificado pelo teclado', async ({ page }) => {
    await page.goto(`/app/evento/${E2E_EVENT_A}/admin/resultados`)
    const tie = page.locator('[data-resolve-tie]').first()
    await expect(tie).toBeVisible()
    const before = await tie.locator('[data-tie-team] strong').allTextContents()
    const moveDown = tie.getByRole('button', { name: `Mover ${before[0]} para baixo` })
    await moveDown.focus()
    await page.keyboard.press('Enter')
    await expect(tie.locator('[data-tie-team] strong').first()).toHaveText(before[1]!)
    await tie.getByLabel('Justificativa da decisão').fill('Critérios debatidos com os avaliadores.')
    await expect(tie.getByRole('button', { name: 'Registrar desempate' })).toBeEnabled()
  })
})

test.describe('Admin global autenticado', () => {
  test.use({ storageState: authState('admin') })

  test('confirmação de arquivamento restaura foco com Escape', async ({ page }) => {
    await page.goto('/app/admin/eventos')
    const prepare = page.getByRole('button', { name: /Preparar novo hackathon/ }).first()
    await prepare.click()
    const dialog = page.getByRole('dialog')
    await expect(dialog).toBeVisible()
    await page.keyboard.press('Escape')
    await expect(dialog).toBeHidden()
    await expect(prepare).toBeFocused()
  })
})
