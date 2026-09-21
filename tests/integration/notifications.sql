begin;
create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;
select no_plan();
select has_function('public', 'get_notification_inbox', array[]::text[], 'inbox RPC exists');
select has_function('public', 'mark_notifications_read', array['uuid[]'], 'read RPC exists');
select has_function('public', 'create_manual_notifications', array['jsonb'], 'composer RPC exists');

insert into auth.users(id,email)
select ('99000000-0000-4000-8000-' || lpad(i::text,12,'0'))::uuid, 'notification-' || i || '@example.test'
from generate_series(1,9) i;
update public.profiles set global_role='global_admin' where id='99000000-0000-4000-8000-000000000001';
insert into public.events(id,name,slug,professor_id,created_by) values
('99100000-0000-4000-8000-000000000001','Inbox A','inbox-a','99000000-0000-4000-8000-000000000002','99000000-0000-4000-8000-000000000001'),
('99100000-0000-4000-8000-000000000002','Inbox B','inbox-b',null,'99000000-0000-4000-8000-000000000001');
insert into public.event_roles(event_id,user_id,role,approved_by) values
('99100000-0000-4000-8000-000000000001','99000000-0000-4000-8000-000000000002','professor','99000000-0000-4000-8000-000000000001'),
('99100000-0000-4000-8000-000000000001','99000000-0000-4000-8000-000000000003','monitor','99000000-0000-4000-8000-000000000001'),
('99100000-0000-4000-8000-000000000002','99000000-0000-4000-8000-000000000004','monitor','99000000-0000-4000-8000-000000000001');
insert into public.role_requests(id,event_id,user_id,requested_role) values
('99200000-0000-4000-8000-000000000001','99100000-0000-4000-8000-000000000001','99000000-0000-4000-8000-000000000005','monitor'),
('99200000-0000-4000-8000-000000000002','99100000-0000-4000-8000-000000000002','99000000-0000-4000-8000-000000000005','monitor');

set local role authenticated;
select set_config('request.jwt.claim.sub','99000000-0000-4000-8000-000000000002',true);
select throws_ok($$select public.create_manual_notifications('{"event_id":"99100000-0000-4000-8000-000000000002","audience":{"type":"event_role","role":"monitor"},"title":"x","body":"y"}')$$,'P0001','forbidden','professor cannot notify another event');
select throws_ok($$select public.create_manual_notifications('{"event_id":"99100000-0000-4000-8000-000000000001","audience":{"type":"users","user_ids":["99000000-0000-4000-8000-000000000004"]},"title":"x","body":"y"}')$$,'P0001','forbidden','professor cannot target a user outside their event');
select throws_ok($$select public.create_manual_notifications('{"event_id":"99100000-0000-4000-8000-000000000001","audience":{"type":"users","user_ids":["99000000-0000-4000-8000-000000000010"]},"title":"x","body":"y"}')$$,'P0001','forbidden','nonexistent and out-of-event recipients have the same rejection');
select throws_ok($$select public.create_manual_notifications('{"event_id":"99100000-0000-4000-8000-000000000001","audience":{"type":"event_role","role":"monitor","team_id":"99300000-0000-4000-8000-000000000001"},"title":"x","body":"y"}')$$,'P0001','invalid_audience','mixed audiences are rejected');
select is(public.create_manual_notifications('{"event_id":"99100000-0000-4000-8000-000000000001","audience":{"type":"event_role","role":"monitor"},"title":"Aviso","body":"Mensagem privada"}'),1,'professor sends only to the chosen event role');
select is((select count(*) from public.get_notification_inbox() where source='automatic'),1::bigint,'professor sees only own event pending request');
select is((select count(*) from public.get_notification_inbox() where source='manual'),0::bigint,'author cannot read recipient inbox');
select throws_ok($$insert into public.notifications(recipient_id,title,body,kind,created_by) values ('99000000-0000-4000-8000-000000000003','x','y','manual_message',auth.uid())$$,'42501',null,'direct inserts are denied');
select set_config('request.jwt.claim.sub','99000000-0000-4000-8000-000000000003',true);
select is((select count(*) from public.get_notification_inbox() where source='manual'),1::bigint,'recipient sees own manual message');
select is((select count(*) from public.notifications),1::bigint,'RLS permits recipient read');
select throws_ok($$select public.create_manual_notifications('{"event_id":"99100000-0000-4000-8000-000000000001","audience":{"type":"event_all"},"title":"x","body":"y"}')$$,'P0001','forbidden','monitor cannot send');
select is(public.mark_notifications_read(array(select id from public.notifications)),1,'recipient marks own notification read');
select is((select count(*) from public.notifications where read_at is not null),1::bigint,'read state is persisted');
select throws_ok($$update public.notifications set recipient_id='99000000-0000-4000-8000-000000000004'$$,'42501',null,'recipient cannot reassign notification');
reset role;
insert into public.notifications(id,recipient_id,title,body,kind,created_by) values ('99400000-0000-4000-8000-000000000001','99000000-0000-4000-8000-000000000004','Foreign','Private','manual_message','99000000-0000-4000-8000-000000000001');
set local role authenticated;
select is(public.mark_notifications_read(array['99400000-0000-4000-8000-000000000001'::uuid]),0,'cannot mark another recipient message');
select is((select count(*) from public.notifications where id='99400000-0000-4000-8000-000000000001'),0::bigint,'cannot read another recipient message');
reset role;
select ok((select read_at is null from public.notifications where id='99400000-0000-4000-8000-000000000001'),'foreign message remains unread');
set local role anon;
select throws_ok($$select * from public.get_notification_inbox()$$,'42501',null,'anon cannot execute inbox');
select throws_ok($$select * from public.notifications$$,'42501',null,'anon cannot read notifications');
reset role;
-- Domain work is derived, not stored; resolved or revoked work disappears.
insert into public.teams(id,event_id,name,category,leader_id,status,decided_by,decided_at) values
('99300000-0000-4000-8000-000000000001','99100000-0000-4000-8000-000000000001','Inbox team','junior','99000000-0000-4000-8000-000000000006','approved','99000000-0000-4000-8000-000000000002',now());
insert into public.team_members(event_id,team_id,user_id,name,email,enrollment,status,approved_by) values
('99100000-0000-4000-8000-000000000001','99300000-0000-4000-8000-000000000001','99000000-0000-4000-8000-000000000006','Leader','notification-6@example.test','n6','active','99000000-0000-4000-8000-000000000002'),
('99100000-0000-4000-8000-000000000001','99300000-0000-4000-8000-000000000001','99000000-0000-4000-8000-000000000007','Student','notification-7@example.test','n7','active','99000000-0000-4000-8000-000000000002'),
('99100000-0000-4000-8000-000000000001','99300000-0000-4000-8000-000000000001','99000000-0000-4000-8000-000000000009','Applicant','notification-9@example.test','n9','join_requested',null);
insert into public.canvas_activities(id,event_id,title,categories,opens_at,due_at,created_by) values
('99500000-0000-4000-8000-000000000001','99100000-0000-4000-8000-000000000001','Activity','{junior}',now()-interval '1 day',now()+interval '1 day','99000000-0000-4000-8000-000000000002');
insert into public.submissions(id,event_id,activity_id,team_id,status,submitted_at) values
('99600000-0000-4000-8000-000000000001','99100000-0000-4000-8000-000000000001','99500000-0000-4000-8000-000000000001','99300000-0000-4000-8000-000000000001','submitted',now());
insert into public.event_roles(event_id,user_id,role,approved_by) values
('99100000-0000-4000-8000-000000000001','99000000-0000-4000-8000-000000000008','evaluator','99000000-0000-4000-8000-000000000002');
select set_config('request.jwt.claim.sub','99000000-0000-4000-8000-000000000002',true);
insert into public.evaluator_assignments(event_id,evaluator_id,category,assigned_by) values
('99100000-0000-4000-8000-000000000001','99000000-0000-4000-8000-000000000008','junior','99000000-0000-4000-8000-000000000002');
set local role authenticated;
select set_config('request.jwt.claim.sub','99000000-0000-4000-8000-000000000006',true);
select is((select count(*) from public.get_notification_inbox() where kind='team_join_request'),1::bigint,'leader sees join request');
select set_config('request.jwt.claim.sub','99000000-0000-4000-8000-000000000007',true);
select is((select count(*) from public.get_notification_inbox() where kind='team_join_request'),0::bigint,'nonleader cannot see join request');
select set_config('request.jwt.claim.sub','99000000-0000-4000-8000-000000000003',true);
select is((select count(*) from public.get_notification_inbox() where kind='submission_review'),1::bigint,'monitor sees submitted canvas');
select set_config('request.jwt.claim.sub','99000000-0000-4000-8000-000000000004',true);
select is((select count(*) from public.get_notification_inbox() where kind='submission_review'),0::bigint,'other event monitor cannot see canvas');
select set_config('request.jwt.claim.sub','99000000-0000-4000-8000-000000000008',true);
select is((select count(*) from public.get_notification_inbox() where kind='evaluation_pending'),1::bigint,'assigned evaluator sees pending project');
select is((select id from public.get_notification_inbox() where kind='evaluation_pending'),(select id from public.get_notification_inbox() where kind='evaluation_pending'),'automatic IDs remain stable across reads');
reset role;
update public.submissions set status='returned' where id='99600000-0000-4000-8000-000000000001';
delete from public.event_roles where user_id='99000000-0000-4000-8000-000000000008';
set local role authenticated;
select is((select count(*) from public.get_notification_inbox() where kind='evaluation_pending'),0::bigint,'revoked evaluator loses automatic item despite assignment');
select set_config('request.jwt.claim.sub','99000000-0000-4000-8000-000000000007',true);
select is((select count(*) from public.get_notification_inbox() where kind='submission_returned'),1::bigint,'active team member sees returned work');
select set_config('request.jwt.claim.sub','99000000-0000-4000-8000-000000000004',true);
select is((select count(*) from public.get_notification_inbox() where kind='submission_returned'),0::bigint,'outside member cannot see returned work');
select set_config('request.jwt.claim.sub','99000000-0000-4000-8000-000000000002',true);
select is(public.create_manual_notifications('{"event_id":"99100000-0000-4000-8000-000000000001","audience":{"type":"team","team_id":"99300000-0000-4000-8000-000000000001"},"title":"Equipe","body":"Aviso"}'),2,'team audience excludes pending member');
select is(public.create_manual_notifications('{"event_id":"99100000-0000-4000-8000-000000000001","audience":{"type":"event_role","role":"student"},"title":"Alunos","body":"Aviso"}'),2,'student audience is approved active participants');
select is(public.create_manual_notifications('{"event_id":"99100000-0000-4000-8000-000000000001","audience":{"type":"event_all"},"title":"Evento","body":"Aviso"}'),4,'event audience unions approved roles and active members');
select throws_ok($$select public.create_manual_notifications('{"audience":{"type":"users","user_ids":["99000000-0000-4000-8000-000000000003"]},"title":"x","body":"y"}')$$,'P0001','forbidden','professor cannot omit event for user audience');
select set_config('request.jwt.claim.sub','99000000-0000-4000-8000-000000000001',true);
select is(public.create_manual_notifications('{"audience":{"type":"users","user_ids":["99000000-0000-4000-8000-000000000003","99000000-0000-4000-8000-000000000003"]},"title":"Global","body":"Aviso"}'),1,'global admin targets users with deduplication');
select is(public.create_manual_notifications('{"audience":{"type":"users","user_ids":["99000000-0000-4000-8000-000000000007"]},"title":"Somente destinatário","body":"Permanece privada"}'),1,'eventless recipient-only notification is stored');
select set_config('request.jwt.claim.sub','99000000-0000-4000-8000-000000000002',true);
select is(public.create_manual_notifications('{"event_id":"99100000-0000-4000-8000-000000000001","audience":{"type":"event_role","role":"monitor"},"title":"Papel revogável","body":"Não vaza após revogação"}'),1,'event-role notification is stored before revocation');
reset role;
select set_config('test.team_notification_id', (select id::text from public.notifications where recipient_id='99000000-0000-4000-8000-000000000007' and title='Equipe'), true);
select set_config('test.role_notification_id', (select id::text from public.notifications where recipient_id='99000000-0000-4000-8000-000000000003' and title='Papel revogável'), true);
set local role authenticated;
select set_config('request.jwt.claim.sub','99000000-0000-4000-8000-000000000002',true);
select lives_ok($$select public.admin_remove_team_member((select id from public.team_members where team_id='99300000-0000-4000-8000-000000000001' and user_id='99000000-0000-4000-8000-000000000007'))$$,'professor can revoke active member before notification scope check');
select set_config('request.jwt.claim.sub','99000000-0000-4000-8000-000000000007',true);
select is((select count(*) from public.notifications where id=current_setting('test.team_notification_id')::uuid),0::bigint,'former member cannot SELECT team-scoped notification');
select is((select count(*) from public.get_notification_inbox() where id=current_setting('test.team_notification_id')),0::bigint,'former member cannot fetch team-scoped notification');
select is(public.mark_notifications_read(array[current_setting('test.team_notification_id')::uuid]),0,'former member cannot mark team-scoped notification');
select is((select count(*) from public.notifications where title='Somente destinatário'),1::bigint,'eventless recipient-only notification remains readable after team revocation');
reset role;
select ok((select read_at is null from public.notifications where id=current_setting('test.team_notification_id')::uuid),'former member cannot mutate stored team notification');
delete from public.event_roles where event_id='99100000-0000-4000-8000-000000000001' and user_id='99000000-0000-4000-8000-000000000003' and role='monitor';
set local role authenticated;
select set_config('request.jwt.claim.sub','99000000-0000-4000-8000-000000000003',true);
select is((select count(*) from public.notifications where id=current_setting('test.role_notification_id')::uuid),0::bigint,'revoked role cannot SELECT event-scoped notification');
select is((select count(*) from public.get_notification_inbox() where id=current_setting('test.role_notification_id')),0::bigint,'revoked role cannot fetch event-scoped notification');
select is(public.mark_notifications_read(array[current_setting('test.role_notification_id')::uuid]),0,'revoked role cannot mark event-scoped notification');
reset role;
select ok((select read_at is null from public.notifications where id=current_setting('test.role_notification_id')::uuid),'revoked role cannot mutate stored event notification');
set local role authenticated;
select set_config('request.jwt.claim.sub','99000000-0000-4000-8000-000000000002',true);
select lives_ok($$select public.admin_delete_team('99300000-0000-4000-8000-000000000001')$$,'team deletion succeeds after team notification exists');
reset role;
select is((select count(*) from public.notifications where team_id='99300000-0000-4000-8000-000000000001'),0::bigint,'team deletion cascades team-scoped notifications without historical leakage');
reset role;
select * from finish();
rollback;
