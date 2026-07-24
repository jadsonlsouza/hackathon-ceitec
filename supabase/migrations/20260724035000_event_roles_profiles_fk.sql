alter table public.event_roles
add constraint event_roles_profile_id_fkey foreign key (user_id) references public.profiles (id) on delete cascade;
