create or replace function public.test_throw_400() returns void language plpgsql as $$
begin
  raise exception using errcode = 'P0001', message = 'event_not_found';
end;
$$;
