import { createClient } from '@supabase/supabase-js';
const supabase = createClient(process.env.NUXT_PUBLIC_SUPABASE_URL, process.env.NUXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY);

async function run() {
  const { data, error } = await supabase.rpc('unpublish_category_results', { event_id: '123e4567-e89b-12d3-a456-426614174000', category: 'junior' });
  console.log("Error with event_id:", error);
}
run();
