import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'https://vmbqqbjtmidjfrebppsz.supabase.co',
  'sb_publishable_DVQDKDL4D0MbbYgm5uTnXQ_0zu5_FBN'
);

async function run() {
  const { data, error } = await supabase
    .from('workshops')
    .select('id,title,description,starts_at,ends_at,capacity,enrollments:workshop_enrollments(count),enrollment_details:workshop_enrollments(user_id,team_id,profile:profiles!workshop_enrollments_user_id_fkey(display_name,email),team:teams(name))')
    .order('starts_at');
    
  if (error) {
    console.error("ERROR:", error);
  } else {
    console.log("SUCCESS, found items: ", data.length);
  }
}
run();
