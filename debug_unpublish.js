import { createClient } from '@supabase/supabase-js';
const supabase = createClient(process.env.NUXT_PUBLIC_SUPABASE_URL, process.env.NUXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY);

async function run() {
  const { data, error } = await supabase.rpc('unpublish_category_results', { event_id: '00000000-0000-0000-0000-000000000000', category: 'junior' });
  console.log("Error with event_id:", error);
  const { data2, error2 } = await supabase.rpc('unpublish_category_results', { target_event: '00000000-0000-0000-0000-000000000000', target_category: 'junior' });
  console.log("Error with target_event:", error2);
}
run();
