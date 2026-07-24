const { createClient } = require('@supabase/supabase-js')
require('dotenv').config({ path: '.env' })
const supabase = createClient(process.env.NUXT_PUBLIC_SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY)
async function test() {
  const res = await supabase.from('profiles').select('id, event_roles(role)')
  console.log(res.error)
}
test()
