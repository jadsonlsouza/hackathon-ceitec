import { createClient } from '@supabase/supabase-js';
const supabase = createClient(process.env.NUXT_PUBLIC_SUPABASE_URL, process.env.NUXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY);

async function run() {
  const { data, error } = await supabase.rpc('api_unpublish_category', { p_event_id: '123e4567-e89b-12d3-a456-426614174000', p_category: 'junior' });
  console.log("Error object from Supabase JS:", error);
}
run();
