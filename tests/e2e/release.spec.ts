import { expect, test, type Page } from '@playwright/test'

const authState = (profile: string) => `tests/e2e/.auth/${profile}.json`

async function selectRoleView(page: Page, name: string) {
  const selector = page.locator('[data-role-view-selector]')
  await expect(selector).toBeVisible()
  await selector.getByRole('button', { name: /Visualização:/ }).click()
  await selector.getByRole('option', { name: new RegExp(name) }).click()
}

test('production-critical paths respond', async ({ page, request }) => {
  const health = await request.get('/api/health')
  expect(health.ok()).toBe(true)
  expect(await health.json()).toMatchObject({ ok: true, service: 'ligalab' })

  await page.goto('/')
  await expect(page.getByRole('heading', { name: /Uma plataforma para transformar desafios em aprendizagem/, level: 1 })).toBeVisible()

  await page.goto('/login')
  await expect(page.getByRole('button', { name: 'Continuar com Google' })).toBeVisible()
})

test.describe('admin notification action', () => {
  test.use({ storageState: authState('admin') })

  test('notification bell opens a pending role request action', async ({ page }) => {
    await page.goto('/app')
    await selectRoleView(page, 'Professor')
    await page.getByRole('button', { name: /Notificações/ }).click()
    await page.getByRole('link', { name: 'Solicitação de acesso' }).click()
    await expect(page.getByRole('heading', { name: 'Revisar solicitações' })).toBeVisible()
  })
})
