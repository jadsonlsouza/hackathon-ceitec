import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database'

export interface SignUpInput {
  name: string
  email: string
  password: string
  requestedRole: 'student' | 'professor' | 'monitor' | 'evaluator'
  eventId?: string
}

function currentOrigin(customOrigin?: string) {
  if (customOrigin) return customOrigin
  if (import.meta.client && typeof window !== 'undefined' && window.location?.origin) {
    return window.location.origin
  }
  return process.env.NUXT_PUBLIC_APP_URL || 'http://localhost:3000'
}

export function createAuthActions(supabase: SupabaseClient<Database>, origin?: string) {
  const signInWithPassword = (email: string, password: string) =>
    supabase.auth.signInWithPassword({ email, password })

  // Requested roles live in editable user metadata and are intentionally not authorization grants.
  const signUp = (input: SignUpInput) =>
    supabase.auth.signUp({
      email: input.email,
      password: input.password,
      options: {
        data: {
          full_name: input.name,
          requested_role: input.requestedRole,
          event_id: input.eventId,
        },
      },
    })

  const signInWithGoogle = () =>
    supabase.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: `${currentOrigin(origin)}/app` },
    })

  const sendPasswordReset = (email: string) =>
    supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${currentOrigin(origin)}/redefinir-senha`,
    })

  const signOut = () => supabase.auth.signOut()

  return { signInWithPassword, signUp, signInWithGoogle, sendPasswordReset, signOut }
}

export function useAuth() {
  const { $supabase } = useNuxtApp()
  return createAuthActions($supabase)
}
