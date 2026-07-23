import { createClient } from '@supabase/supabase-js'
import { createError, type H3Event } from 'h3'

export function createSupabaseAdminClient(event?: H3Event) {
  const config = useRuntimeConfig(event)
  const url = config.public.supabaseUrl
  const secretKey = config.supabaseSecretKey

  if (!url || !secretKey) {
    throw createError({
      statusCode: 500,
      message: 'Supabase server configuration is missing',
    })
  }

  return createClient(url, secretKey, {
    auth: {
      autoRefreshToken: false,
      detectSessionInUrl: false,
      persistSession: false,
    },
  })
}
