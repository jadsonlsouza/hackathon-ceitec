import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database'

type Profile = Database['public']['Tables']['profiles']['Row']
type EventRole = Database['public']['Tables']['event_roles']['Row']

export interface CurrentAccess {
  profile: Profile | null
  eventRoles: EventRole[]
}

export async function loadCurrentAccess(
  supabase: SupabaseClient<Database>,
  userId: string,
): Promise<CurrentAccess> {
  const [profileResult, eventRolesResult] = await Promise.all([
    supabase
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .single(),
    supabase
      .from('event_roles')
      .select('*')
      .eq('user_id', userId),
  ])

  if (profileResult.error) throw profileResult.error
  if (eventRolesResult.error) throw eventRolesResult.error

  return {
    profile: profileResult.data,
    eventRoles: eventRolesResult.data ?? [],
  }
}

export function useCurrentAccess() {
  const { $supabase } = useNuxtApp()
  const access = useAsyncData<CurrentAccess>(
    'current-access',
    async () => {
      const { data, error } = await $supabase.auth.getUser()
      if (error) throw error
      if (!data.user) return { profile: null, eventRoles: [] }
      return loadCurrentAccess($supabase, data.user.id)
    },
    {
      server: false,
      default: () => ({ profile: null, eventRoles: [] }),
    },
  )

  return {
    profile: computed(() => access.data.value.profile),
    eventRoles: computed(() => access.data.value.eventRoles),
    pending: access.pending,
    error: access.error,
    refresh: access.refresh,
  }
}
