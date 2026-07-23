import { test } from '@playwright/test'

test.describe('multi-profile evaluation and publication journey', () => {
  test.skip(
    true,
    'Requires a deterministic multi-profile Supabase Auth harness with Professor, evaluator and anonymous sessions.',
  )

  test('publishes an audited manual tie order without changing scores', async () => {
    // The database and mounted-page suites cover this journey deterministically.
    // Enable this browser journey when isolated seeded auth sessions are available.
  })
})
