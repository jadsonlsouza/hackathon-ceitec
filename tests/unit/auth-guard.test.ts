import { describe, expect, it } from 'vitest'
import { redirectIfUnauthenticated } from '../../app/utils/auth-guard'

describe('auth guard', () => {
  it('redirects only when Supabase returns no authenticated user', async () => {
    const redirects: string[] = []
    await redirectIfUnauthenticated(async () => ({ data: { user: null } }), () => redirects.push('/login'))
    await redirectIfUnauthenticated(async () => ({ data: { user: { id: 'user-1' } } }), () => redirects.push('/login'))

    expect(redirects).toEqual(['/login'])
  })
})
