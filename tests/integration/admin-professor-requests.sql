begin;
create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;
select no_plan();
insert into auth.users(id,email) values
 ('51000000-0000-4000-8000-000000000001','request-admin@test.local'),
 ('51000000-0000-4000-8000-000000000002','request-student@test.local');
update public.profiles set global_role='global_admin' where id='51000000-0000-4000-8000-000000000001';
select set_config('request.jwt.claim.sub','51000000-0000-4000-8000-000000000001',true);
insert into public.events(id,name,slug,status,created_by) values ('52000000-0000-4000-8000-000000000001','Requests','request-admin-event','in_progress','51000000-0000-4000-8000-000000000001');
insert into public.role_requests(id,event_id,user_id,requested_role) values
 ('53000000-0000-4000-8000-000000000001','52000000-0000-4000-8000-000000000001','51000000-0000-4000-8000-000000000002','monitor');
set local role authenticated;
select set_config('request.jwt.claim.sub','51000000-0000-4000-8000-000000000002',true);
select throws_ok($$select public.decide_role_request('53000000-0000-4000-8000-000000000001','approved')$$,'P0001','forbidden','unrelated user cannot decide');
select set_config('request.jwt.claim.sub','51000000-0000-4000-8000-000000000001',true);
select lives_ok($$select public.decide_role_request('53000000-0000-4000-8000-000000000001','approved')$$,'admin without professor role can approve monitor');
reset role;
select is((select count(*) from public.event_roles where user_id='51000000-0000-4000-8000-000000000001'),0::bigint,'no manufactured professor role');
select is((select status::text from public.role_requests where id='53000000-0000-4000-8000-000000000001'),'approved','request approved');
select * from finish();
rollback;
