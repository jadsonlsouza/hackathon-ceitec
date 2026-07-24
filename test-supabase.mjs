import { createClient } from '@supabase/supabase-js'
import { readFileSync } from 'fs'

const envStr = readFileSync('.env', 'utf8')
const env = Object.fromEntries(envStr.split('\n').filter(Boolean).map(line => line.split('=')))

const supabase = createClient(env.NUXT_PUBLIC_SUPABASE_URL, env.NUXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY)

const { data: auth, error: authErr } = await supabase.auth.signInWithPassword({
  email: 'jadsonlukas@gmail.com',
  password: 'geek2846'
})

if (authErr) {
  console.error("Auth Error", authErr)
  process.exit(1)
}

const { data, error } = await supabase
  .from('profiles')
  .select(`
    id,
    display_name,
    email,
    global_role,
    event_roles!event_roles_user_id_fkey (
      event_id,
      role,
      event:events!event_roles_event_id_fkey(name)
    )
  `)
  .order('display_name')

console.log(JSON.stringify({ data, error }, null, 2))
