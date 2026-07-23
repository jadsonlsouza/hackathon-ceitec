import { createClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database'

export default defineNuxtPlugin(() => {
  const config = useRuntimeConfig()
  const supabase = createClient<Database>(
    config.public.supabaseUrl,
    config.public.supabasePublishableKey,
    { auth: { flowType: 'pkce', persistSession: true, detectSessionInUrl: true } },
  )

  return { provide: { supabase } }
})
