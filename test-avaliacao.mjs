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

const eventId = '50b2f8ca-c0e9-4298-bee5-7c2e2719a01f'

const queries = [
  supabase.from('evaluation_criteria').select('id,event_id,name,description,position,active').eq('event_id', eventId).order('position'),
  supabase.from('criterion_weights').select('event_id,criterion_id,category,weight').eq('event_id', eventId),
  supabase.from('evaluator_assignments').select('event_id,evaluator_id,category').eq('event_id', eventId),
  supabase.from('event_roles').select('event_id,user_id,role,profile:profiles(display_name)').eq('event_id', eventId).eq('role', 'evaluator'),
  supabase.from('teams').select('id,event_id,category,status').eq('event_id', eventId).eq('status', 'approved'),
  supabase.from('evaluations').select('id,event_id,category,team_id,evaluator_id').eq('event_id', eventId),
  supabase.from('evaluation_freezes').select('event_id,category,evaluator_snapshot,team_snapshot').eq('event_id', eventId)
]

const results = await Promise.all(queries)

for (let i = 0; i < results.length; i++) {
  if (results[i].error) {
    console.error(`Query ${i} failed:`, results[i].error)
  }
}
console.log("Done checking queries")
