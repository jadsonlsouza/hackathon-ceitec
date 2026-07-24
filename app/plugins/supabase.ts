import { createClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database'

export default defineNuxtPlugin(() => {
  const config = useRuntimeConfig()
  const url = config.public.supabaseUrl || 'https://vmbqqbjtmidjfrebppsz.supabase.co'
  const key = config.public.supabasePublishableKey || 'sb_publishable_DVQDKDL4D0MbbYgm5uTnXQ_0zu5_FBN'

  const supabase = createClient<Database>(
    url,
    key,
    { auth: { flowType: 'pkce', persistSession: true, detectSessionInUrl: true } },
  )

  return { provide: { supabase } }
})
