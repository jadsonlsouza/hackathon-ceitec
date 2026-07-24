import { defineConfig, devices } from '@playwright/test'
import { localSupabaseEnvironment } from './tests/e2e/support/local-supabase'

const local = localSupabaseEnvironment()

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: false,
  workers: 1,
  timeout: 30_000,
  expect: { timeout: 8_000 },
  globalSetup: './tests/e2e/support/global-setup.ts',
  outputDir: 'test-results',
  reporter: [['list'], ['html', { outputFolder: 'playwright-report', open: 'never' }]],
  use: {
    baseURL: process.env.PLAYWRIGHT_BASE_URL || 'http://127.0.0.1:3000',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    actionTimeout: 8_000,
    navigationTimeout: 15_000,
  },
  webServer: process.env.PLAYWRIGHT_BASE_URL
    ? undefined
    : {
        command: 'npm run dev -- --host 127.0.0.1',
        url: 'http://127.0.0.1:3000',
        reuseExistingServer: false,
        timeout: 120_000,
        env: {
          NUXT_PUBLIC_SUPABASE_URL: local.apiUrl,
          NUXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: local.publishableKey,
          NUXT_SUPABASE_SECRET_KEY: local.serviceRoleKey,
          NODE_ENV: 'test',
        },
      },
  projects: [
    {
      name: 'desktop',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'mobile',
      use: { ...devices['Pixel 7'] },
    },
  ],
})
