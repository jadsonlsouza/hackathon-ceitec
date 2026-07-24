create or replace function public.test_unpublish(event_id uuid) returns void language plpgsql as $$
begin
  delete from public.published_results as pub
  where pub.event_id = test_unpublish.event_id;
end;
$$;
