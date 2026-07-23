export default defineNuxtRouteMiddleware(async () => {
  if (import.meta.server) return

  const { $supabase } = useNuxtApp()
  return redirectIfUnauthenticated(
    () => $supabase.auth.getUser(),
    () => navigateTo('/login'),
  )
})
