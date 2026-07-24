const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY);

async function run() {
  const { data, error } = await supabase
    .from('teams')
    .select('id, name, leader_id, members:team_members(user_id, name, status)')
    .eq('name', 'ceitec') // The user's team name is probably 'ceitec' based on the screenshot logo? Wait, it just says "Minha equipe". Let's get Jadson's team.
    .limit(10);
    
  console.log("Teams:", JSON.stringify(data, null, 2));
}
run();
