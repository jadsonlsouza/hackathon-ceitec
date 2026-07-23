export interface SignUpInput {
  name: string
  email: string
  password: string
  requestedRole: 'student' | 'professor' | 'monitor' | 'evaluator'
  eventId?: string
}

export function useAuth() {
  const { $supabase } = useNuxtApp()

  const signInWithPassword = (email: string, password: string) =>
    $supabase.auth.signInWithPassword({ email, password })

  // Requested roles live in editable user metadata and are intentionally not authorization grants.
  const signUp = (input: SignUpInput) =>
    $supabase.auth.signUp({
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
    $supabase.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: `${location.origin}/app` },
    })

  const sendPasswordReset = (email: string) =>
    $supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${location.origin}/redefinir-senha`,
    })

  const signOut = () => $supabase.auth.signOut()

  return { signInWithPassword, signUp, signInWithGoogle, sendPasswordReset, signOut }
}
