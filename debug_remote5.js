import { createClient } from '@supabase/supabase-js';
const supabase = createClient(process.env.NUXT_PUBLIC_SUPABASE_URL, process.env.NUXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY);

async function run() {
  const { data, error } = await supabase.rpc('function_that_does_not_exist', { a: 1 });
  console.log("Error status:", error);
}
run();
