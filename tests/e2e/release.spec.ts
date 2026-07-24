import { expect, test } from '@playwright/test'

test('production-critical paths respond', async ({ page, request }) => {
  const health = await request.get('/api/health')
  expect(health.ok()).toBe(true)
  expect(await health.json()).toMatchObject({ ok: true, service: 'hackathon-ceitec' })

  await page.goto('/')
  await expect(page.getByRole('heading', { name: /Hackathon CEITEC/, level: 1 })).toBeVisible()

  await page.goto('/login')
  await expect(page.getByRole('button', { name: 'Continuar com Google' })).toBeVisible()
})
