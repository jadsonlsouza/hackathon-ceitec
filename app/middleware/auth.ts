export default defineNuxtRouteMiddleware(async () => {
  if (import.meta.server) return

  const { $supabase } = useNuxtApp()
  const { data } = await $supabase.auth.getUser()

  if (!data.user) return navigateTo('/login')
})
