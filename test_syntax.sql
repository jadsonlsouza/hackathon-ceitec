create or replace function public.test_ambig(event_id uuid) returns void language plpgsql as $$
begin
  raise notice 'Param is: %', test_ambig.event_id;
end;
$$;
select public.test_ambig('00000000-0000-0000-0000-000000000000');
