import { describe, expect, it } from 'vitest'
import { createAuthActions } from '../../app/composables/useAuth'

describe('auth actions', () => {
  it('forwards password, role-request metadata, OAuth, reset, and sign-out calls to Auth', async () => {
    const calls: Array<{ method: string, value?: unknown }> = []
    const auth = {
      signInWithPassword: async (value: unknown) => { calls.push({ method: 'password', value }); return { error: null } },
      signUp: async (value: unknown) => { calls.push({ method: 'signup', value }); return { error: null } },
      signInWithOAuth: async (value: unknown) => { calls.push({ method: 'google', value }); return { error: null } },
      resetPasswordForEmail: async (email: string, value: unknown) => { calls.push({ method: 'reset', value: { email, ...value as object } }); return { error: null } },
      signOut: async () => { calls.push({ method: 'signout' }); return { error: null } },
    }
    const actions = createAuthActions({ auth } as never, 'https://hackathon.example')

    await actions.signInWithPassword('aluna@ceitec.br', 'senha-segura')
    await actions.signUp({ name: 'Ana', email: 'ana@ceitec.br', password: 'senha-segura', requestedRole: 'monitor', eventId: 'event-1' })
    await actions.signInWithGoogle()
    await actions.sendPasswordReset('ana@ceitec.br')
    await actions.signOut()

    expect(calls).toEqual([
      { method: 'password', value: { email: 'aluna@ceitec.br', password: 'senha-segura' } },
      { method: 'signup', value: { email: 'ana@ceitec.br', password: 'senha-segura', options: { data: { full_name: 'Ana', requested_role: 'monitor', event_id: 'event-1' } } } },
      { method: 'google', value: { provider: 'google', options: { redirectTo: 'https://hackathon.example/app' } } },
      { method: 'reset', value: { email: 'ana@ceitec.br', redirectTo: 'https://hackathon.example/redefinir-senha' } },
      { method: 'signout' },
    ])
  })
})
