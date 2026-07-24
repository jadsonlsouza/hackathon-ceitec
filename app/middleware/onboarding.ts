// Redirects users who have just logged in (e.g. via Google OAuth) and have
// not yet selected a role to the /onboarding page.
// Only applies when navigating into /app routes.
export default defineNuxtRouteMiddleware(async (to) => {
  if (import.meta.server) return
  if (!to.path.startsWith('/app')) return

  const { $supabase } = useNuxtApp()
  const { data: { user } } = await $supabase.auth.getUser()
  if (!user) return navigateTo('/login')

  // Global admins never need onboarding — they manage the system.
  const profileResult = await $supabase
    .from('profiles')
    .select('global_role')
    .eq('id', user.id)
    .single()

  if (profileResult.data?.global_role === 'global_admin') return

  // If user already has any role_request or event_role, skip onboarding.
  const [roleRequestsResult, eventRolesResult] = await Promise.all([
    $supabase
      .from('role_requests')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', user.id),
    $supabase
      .from('event_roles')
      .select('event_id', { count: 'exact', head: true })
      .eq('user_id', user.id),
  ])

  const hasRoleRequest = (roleRequestsResult.count ?? 0) > 0
  const hasEventRole = (eventRolesResult.count ?? 0) > 0

  // Check user metadata for a completed onboarding flag (set for students)
  const onboardingDone = user.user_metadata?.onboarding_done === true

  if (!hasRoleRequest && !hasEventRole && !onboardingDone) {
    return navigateTo('/onboarding')
  }
})

