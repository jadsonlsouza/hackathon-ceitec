-- Fix the protect_result_immutability trigger to allow DELETE.
-- Since the table has RLS and no DELETE policies exist, users cannot
-- delete rows anyway. The only way to delete is via our security definer
-- unpublish_category_results RPC, which we want to allow.

drop trigger if exists protect_published_result on public.published_results;
create trigger protect_published_result
  before update on public.published_results
  for each row execute function private.protect_result_immutability();
