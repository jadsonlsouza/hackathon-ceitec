import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://vmbqqbjtmidjfrebppsz.supabase.co'
const supabaseKey = 'sb_publishable_DVQDKDL4D0MbbYgm5uTnXQ_0zu5_FBN'
const supabase = createClient(supabaseUrl, supabaseKey)

async function test() {
  const { data, error } = await supabase
      .from('attendance_sessions')
      .select('id, session_date, secret_word, created_at, attendance_records(count)')
      .limit(1)
  
  console.log('Result for attendance_records(count):', error ? error.message : 'SUCCESS', error?.details || '')
}

test()
