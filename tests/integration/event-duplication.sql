begin;
create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;
select no_plan();
select has_function('public', 'create_event_draft', array['jsonb'], 'atomic draft RPC exists');
select has_function('public', 'duplicate_event_configuration', array['uuid', 'jsonb', 'jsonb'], 'configuration-only duplicate RPC exists');
insert into auth.users(id,email) values
 ('41000000-0000-4000-8000-000000000001','wizard-admin@test.local'),
 ('41000000-0000-4000-8000-000000000002','wizard-prof@test.local'),
 ('41000000-0000-4000-8000-000000000003','wizard-other@test.local');
update public.profiles set global_role='global_admin' where id='41000000-0000-4000-8000-000000000001';
-- The source configuration is seeded as the global admin because the
-- evaluation configuration trigger intentionally rejects unprivileged edits.
select set_config('request.jwt.claim.sub','41000000-0000-4000-8000-000000000001',true);
insert into public.events(id,name,slug,status,starts_at,ends_at,professor_id,created_by)
values ('42000000-0000-4000-8000-000000000001','Origem','wizard-source','in_progress','2027-01-01','2027-01-02','41000000-0000-4000-8000-000000000003','41000000-0000-4000-8000-000000000001');
insert into public.event_roles(event_id,user_id,role,approved_by) values
 ('42000000-0000-4000-8000-000000000001','41000000-0000-4000-8000-000000000003','professor','41000000-0000-4000-8000-000000000001');
insert into public.event_public_content(event_id,tagline,presentation,objectives,venue,date_label,registration_open)
values ('42000000-0000-4000-8000-000000000001','Conteúdo origem','Apresentação origem','["Objetivo"]','Campus','Janeiro',true);
insert into public.event_schedule_items(event_id,day_number,starts_at,activity,position)
values ('42000000-0000-4000-8000-000000000001',1,'09:00','Abertura',1);
insert into public.canvas_templates(id,event_id,name,instructions,created_by)
values ('43000000-0000-4000-8000-000000000001','42000000-0000-4000-8000-000000000001','Modelo origem','Instruções','41000000-0000-4000-8000-000000000001');
insert into public.canvas_template_blocks(template_id,key,title,prompt,position)
values ('43000000-0000-4000-8000-000000000001','teste','Bloco modelo','Modelo',1);
insert into public.canvas_template_blocks(template_id,key,title,prompt,position)
values ('43000000-0000-4000-8000-000000000001','second','Segundo','Segundo',2);
insert into public.canvas_activities(id,event_id,template_id,title,categories,opens_at,due_at,published,created_by)
values ('44000000-0000-4000-8000-000000000001','42000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000001','Atividade origem','{junior}','2027-01-01','2027-01-02',true,'41000000-0000-4000-8000-000000000001');
update public.canvas_blocks set prompt='Bloco personalizado' where activity_id='44000000-0000-4000-8000-000000000001';
-- Swap positions without ever violating source constraints, and rename a block.
update public.canvas_blocks set position=position+10 where activity_id='44000000-0000-4000-8000-000000000001';
update public.canvas_blocks set position=case key when 'teste' then 2 else 1 end,
 key=case key when 'second' then 'renamed' else key end
where activity_id='44000000-0000-4000-8000-000000000001';
select set_config('request.jwt.claim.sub','41000000-0000-4000-8000-000000000003',true);
update public.criterion_weights set weight=3.5 where event_id='42000000-0000-4000-8000-000000000001' and category='junior';
select set_config('request.jwt.claim.sub','41000000-0000-4000-8000-000000000001',true);
insert into public.workshops(event_id,title,starts_at,ends_at,capacity,created_by)
values ('42000000-0000-4000-8000-000000000001','Oficina origem','2027-01-01','2027-01-02',20,'41000000-0000-4000-8000-000000000001');
insert into public.teams(id,event_id,name,category,leader_id)
values ('45000000-0000-4000-8000-000000000001','42000000-0000-4000-8000-000000000001','Equipe privada','junior','41000000-0000-4000-8000-000000000003');
insert into public.team_members(event_id,team_id,name,email,enrollment) values
 ('42000000-0000-4000-8000-000000000001','45000000-0000-4000-8000-000000000001','Convite privado','invite@test.local','invite');
insert into public.audit_log(event_id,action,entity_type,entity_id) values
 ('42000000-0000-4000-8000-000000000001','source_secret','event','secret');
insert into public.notifications(event_id,recipient_id,created_by,title,body) values
 ('42000000-0000-4000-8000-000000000001','41000000-0000-4000-8000-000000000003','41000000-0000-4000-8000-000000000001','Privado','Não copiar');
create temporary table wizard_result(id uuid, kind text);
grant all on wizard_result to authenticated;
update public.events
set status = 'archived', archived_at = now()
where id = '42000000-0000-4000-8000-000000000001';
select throws_ok($$delete from public.team_members where team_id='45000000-0000-4000-8000-000000000001'$$,
 'P0001','event_not_available','archived membership cannot be deleted by privileged workflow');
set local role authenticated;
select throws_ok($$select public.admin_delete_team('45000000-0000-4000-8000-000000000001')$$,
 'P0001','event_not_available','archived team without submissions cannot be deleted by admin');
select throws_ok(
  $$insert into public.canvas_templates(event_id,name,created_by) values ('42000000-0000-4000-8000-000000000001','Bloqueado','41000000-0000-4000-8000-000000000001')$$,
  '42501', null, 'global admin cannot create Canvas templates on archived events'
);
select results_eq(
  $$with attempted as (
      update public.canvas_activities
      set title = 'Não editar'
      where id = '44000000-0000-4000-8000-000000000001'
      returning id
    ) select count(*)::bigint from attempted$$,
  array[0::bigint],
  'global admin cannot update Canvas activities on archived events'
);
reset role;
select set_config('request.jwt.claim.sub','41000000-0000-4000-8000-000000000003',true);
set local role authenticated;
select throws_ok($$select public.create_event_draft('{}')$$,'42501','forbidden','non-admin cannot create');
select throws_ok($$select public.duplicate_event_configuration('42000000-0000-4000-8000-000000000001','{}','{}')$$,'42501','forbidden','event professor cannot duplicate');
select set_config('request.jwt.claim.sub','41000000-0000-4000-8000-000000000001',true);
select throws_ok($$select public.create_event_draft('{"name":" ","slug":"bad","professor_id":"41000000-0000-4000-8000-000000000002"}')$$,'22023','invalid_name','blank name rejected');
select throws_ok($$select public.create_event_draft('{"name":"Nome","slug":"BAD slug","professor_id":"41000000-0000-4000-8000-000000000002"}')$$,'22023','invalid_slug','invalid slug rejected');
select throws_ok($$select public.create_event_draft('{"name":"Nome","slug":"bad-prof","professor_id":"41000000-0000-4000-8000-000000000099"}')$$,'22023','invalid_professor','missing responsible rejected');
select throws_ok($$select public.duplicate_event_configuration('42000000-0000-4000-8000-000000000001','{}','{"teams":true}')$$,'22023','invalid_copy_options','unknown copy group rejected');
select throws_ok($$select public.duplicate_event_configuration('42000000-0000-4000-8000-000000000001','{}','{"canvas":"true"}')$$,'22023','invalid_copy_options','non-boolean copy group rejected');
select throws_ok($$select public.create_event_draft('{"name":"Nome","slug":"wizard-source","professor_id":"41000000-0000-4000-8000-000000000002"}')$$,'23505',null,'slug conflict aborts creation');
select throws_ok($$select public.create_event_draft('{"name":"Nome","slug":"escape","professor_id":"41000000-0000-4000-8000-000000000002","status":"in_progress"}')$$,'22023','invalid_draft','cannot smuggle publication state');
insert into wizard_result select event_id,'copy' from public.duplicate_event_configuration(
 '42000000-0000-4000-8000-000000000001',
 '{"name":"Cópia","slug":"wizard-copy","professor_id":"41000000-0000-4000-8000-000000000002"}',
 '{"public_content":true,"evaluation":true,"canvas":true,"workshops":true,"general":true}');
insert into wizard_result select event_id,'empty' from public.duplicate_event_configuration(
 '42000000-0000-4000-8000-000000000001',
 '{"name":"Vazio","slug":"wizard-empty","professor_id":"41000000-0000-4000-8000-000000000002"}','{}');
insert into wizard_result select event_id,'fresh' from public.create_event_draft(
 '{"name":"Novo","slug":"wizard-fresh","professor_id":"41000000-0000-4000-8000-000000000002"}');
reset role;
select is((select status::text from public.events where slug='wizard-copy'),'draft','copy remains draft');
select is((select professor_id from public.events where slug='wizard-copy'),'41000000-0000-4000-8000-000000000002'::uuid,'selected professor replaces source');
select is((select count(*) from public.event_roles where event_id=(select id from wizard_result where kind='copy')),1::bigint,'only selected professor role exists');
select is((select user_id from public.event_roles where event_id=(select id from wizard_result where kind='copy')),'41000000-0000-4000-8000-000000000002'::uuid,'role belongs to selected professor');
select is((select registration_open from public.event_public_content where event_id=(select id from wizard_result where kind='copy')),false,'registration stays closed');
select is((select count(*) from public.get_public_event_content('wizard-copy')),0::bigint,'public API hides draft');
select lives_ok(
  $$select * from public.get_event_public_content_for_edit((select id from wizard_result where kind='copy'))$$,
  'global admin can enter the new responsible professor configuration workspace'
);
select is((select count(*) from public.canvas_templates where event_id=(select id from wizard_result where kind='copy')),1::bigint,'one selected template copied');
select is((select count(*) from public.canvas_activities where event_id=(select id from wizard_result where kind='copy')),
 (select count(*) from public.canvas_activities where event_id='42000000-0000-4000-8000-000000000001'),'activities copied without extra seeded defaults');
select is((select count(*) from public.canvas_activities where event_id in(select id from wizard_result) and published),0::bigint,'all new activities unpublished including defaults');
select is((select b.prompt from public.canvas_blocks b join public.canvas_activities a on a.id=b.activity_id where a.event_id=(select id from wizard_result where kind='copy') and a.title='Atividade origem' and b.key='teste'),'Bloco personalizado','activity block overrides preserved');
select results_eq(
 $$select b.key,b.position from public.canvas_blocks b join public.canvas_activities a on a.id=b.activity_id where a.event_id=(select id from wizard_result where kind='copy') and a.title='Atividade origem' order by b.position$$,
 $$values ('renamed'::text,1),('teste'::text,2)$$,
 'activity block set exactly preserves renames and reordered positions');
select ok((select a.template_id<> '43000000-0000-4000-8000-000000000001'::uuid and t.event_id=a.event_id from public.canvas_activities a join public.canvas_templates t on t.id=a.template_id where a.event_id=(select id from wizard_result where kind='copy') and a.title='Atividade origem'),'template references remapped');
select is((select count(*) from public.criterion_weights where event_id=(select id from wizard_result where kind='copy') and category='junior' and weight=3.5),5::bigint,'non-default weights preserved without defaults collision');
select is((select count(*) from public.event_schedule_items where event_id=(select id from wizard_result where kind='copy')),1::bigint,'schedule copied');
select is((select count(*) from public.workshops where event_id=(select id from wizard_result where kind='copy')),1::bigint,'workshops copied');
select is((select starts_at from public.events where slug='wizard-copy'),'2027-01-01'::timestamptz,'allowed general dates copied');
select is((select count(*) from public.canvas_templates where event_id=(select id from wizard_result where kind='empty')),0::bigint,'unchecked templates excluded');
select is((select count(*) from public.workshops where event_id=(select id from wizard_result where kind='empty')),0::bigint,'unchecked workshops excluded');
select is((select count(*) from public.event_public_content where event_id=(select id from wizard_result where kind='empty')),0::bigint,'unchecked public content excluded');
select is((select starts_at from public.events where slug='wizard-empty'),null::timestamptz,'unchecked general config excluded');
select is((select count(*) from public.teams where event_id in(select id from wizard_result)),0::bigint,'no teams copied');
select is((select count(*) from public.team_members where event_id in(select id from wizard_result)),0::bigint,'no members or invitations copied');
select is((select count(*) from public.submissions where event_id in(select id from wizard_result)),0::bigint,'no submissions copied');
select is((select count(*) from public.evaluations where event_id in(select id from wizard_result)),0::bigint,'no evaluations copied');
select is((select count(*) from public.published_results where event_id in(select id from wizard_result)),0::bigint,'no results copied');
select is((select count(*) from public.audit_log where event_id in(select id from wizard_result)),0::bigint,'no audit data copied or synthesized by weight updates');
select is((select count(*) from public.notifications where event_id in(select id from wizard_result)),0::bigint,'no notifications copied');
select is((select count(*) from public.profiles where email like 'wizard-%@test.local'),3::bigint,'no users copied');
select is((select status::text from public.events where slug='wizard-source'),'archived','archived source remains archived after copying');
-- Force failure after the new event and configuration writes; the entire RPC must roll back.
create function pg_temp.fail_wizard_workshop() returns trigger language plpgsql as $$
begin raise exception 'forced_workshop_failure'; end $$;
create trigger fail_wizard_workshop before insert on public.workshops for each row execute function pg_temp.fail_wizard_workshop();
set local role authenticated;
select throws_ok($$select public.duplicate_event_configuration('42000000-0000-4000-8000-000000000001','{"name":"Rollback","slug":"wizard-rollback","professor_id":"41000000-0000-4000-8000-000000000002"}','{"canvas":true,"workshops":true}')$$,'P0001','forced_workshop_failure','late copy failure aborts atomic RPC');
reset role;
select is((select count(*) from public.events where slug='wizard-rollback'),0::bigint,'no partial event on copy failure');
select ok(not has_function_privilege('anon','public.create_event_draft(jsonb)','execute'),'anonymous create denied');
select ok(not has_function_privilege('anon','public.duplicate_event_configuration(uuid,jsonb,jsonb)','execute'),'anonymous copy denied');
select is((select bool_or(prosecdef) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and proname in ('create_event_draft','duplicate_event_configuration')),false,'public entry points are invoker');
select * from finish();
rollback;
