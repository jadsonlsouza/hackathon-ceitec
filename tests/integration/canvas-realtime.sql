begin;

select plan(2);

select ok(
  exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'submissions'
  ),
  'submission status changes are published to scoped Realtime clients'
);

select ok(
  exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'submission_answers'
  ),
  'collaborative answer changes are published to scoped Realtime clients'
);

select * from finish();
rollback;
