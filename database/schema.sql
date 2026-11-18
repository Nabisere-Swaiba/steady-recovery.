-- SteadyRecovery schema. Paste ALL of this into Supabase > SQL Editor and click Run.
create type user_role as enum ('PATIENT','DOCTOR','ADMIN');
create type verify_status as enum ('PENDING','APPROVED','REJECTED');

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text not null default '',
  role user_role not null default 'PATIENT',
  verification_status verify_status,
  assigned_doctor_id uuid references profiles(id),
  recovery_start_date date,
  created_at timestamptz default now()
);

create function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare r user_role;
begin
  r := (case when new.raw_user_meta_data->>'role' = 'DOCTOR' then 'DOCTOR' else 'PATIENT' end)::user_role;
  insert into profiles (id, email, full_name, role, verification_status)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name',''), r,
          case when r = 'DOCTOR' then 'PENDING'::verify_status end);
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
for each row execute function handle_new_user();

create function is_admin() returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'ADMIN') $$;
create function is_approved_doctor() returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'DOCTOR' and verification_status = 'APPROVED') $$;
create function is_patient() returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'PATIENT') $$;
create function is_my_patient(pid uuid) returns boolean language sql security definer stable set search_path = public as $$
  select is_approved_doctor() and exists (select 1 from profiles where id = pid and assigned_doctor_id = auth.uid()) $$;

create table checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  checkin_date date not null default current_date,
  mood int check (mood between 1 and 10),
  stress int check (stress between 1 and 10),
  craving int check (craving between 1 and 10),
  halt text[] default '{}',
  created_at timestamptz default now(),
  unique (user_id, checkin_date)
);
create table sos_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  note text,
  created_at timestamptz default now()
);
create table habits (
  user_id uuid references profiles(id) on delete cascade,
  habit_date date default current_date,
  sleep_ok boolean default false, hydration_ok boolean default false,
  meeting_ok boolean default false, meds_ok boolean default false,
  primary key (user_id, habit_date)
);
create table journal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  body text not null,
  shared_with_doctor boolean default false,
  created_at timestamptz default now()
);
create table safety_blueprint (
  user_id uuid primary key references profiles(id) on delete cascade,
  triggers text, warning_signs text, coping_strategies text,
  contacts jsonb default '[]'
);
create table support_groups (
  id uuid primary key default gen_random_uuid(),
  name text not null, type text, schedule text,
  is_virtual boolean default true, join_link text, location text
);
create table doctor_messages (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references profiles(id),
  patient_id uuid not null references profiles(id),
  body text not null,
  created_at timestamptz default now()
);

alter table profiles enable row level security;
alter table checkins enable row level security;
alter table sos_events enable row level security;
alter table habits enable row level security;
alter table journal_entries enable row level security;
alter table safety_blueprint enable row level security;
alter table support_groups enable row level security;
alter table doctor_messages enable row level security;

create policy "own profile" on profiles for select using (id = auth.uid());
create policy "admin sees all profiles" on profiles for select using (is_admin());
create policy "approved doctors listable" on profiles for select using (role = 'DOCTOR' and verification_status = 'APPROVED');
create policy "doctor sees assigned patients" on profiles for select using (is_my_patient(id));
create policy "update own profile" on profiles for update using (id = auth.uid());
revoke update on profiles from authenticated;
grant update (full_name, assigned_doctor_id, recovery_start_date) on profiles to authenticated;

create function set_doctor_status(doctor uuid, new_status verify_status) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'forbidden'; end if;
  update profiles set verification_status = new_status where id = doctor and role = 'DOCTOR';
end $$;

create policy "own checkins" on checkins for all using (user_id = auth.uid() and is_patient()) with check (user_id = auth.uid() and is_patient());
create policy "doctor reads checkins" on checkins for select using (is_my_patient(user_id));
create policy "own sos" on sos_events for all using (user_id = auth.uid() and is_patient()) with check (user_id = auth.uid() and is_patient());
create policy "doctor reads sos" on sos_events for select using (is_my_patient(user_id));
create policy "own habits" on habits for all using (user_id = auth.uid() and is_patient()) with check (user_id = auth.uid() and is_patient());
create policy "own blueprint" on safety_blueprint for all using (user_id = auth.uid() and is_patient()) with check (user_id = auth.uid() and is_patient());
create policy "own journal" on journal_entries for all using (user_id = auth.uid() and is_patient()) with check (user_id = auth.uid() and is_patient());
create policy "doctor reads shared journal" on journal_entries for select using (shared_with_doctor and is_my_patient(user_id));
create policy "patients read groups" on support_groups for select using (is_patient());
create policy "doctor sends" on doctor_messages for insert with check (doctor_id = auth.uid() and is_my_patient(patient_id));
create policy "participants read" on doctor_messages for select using (doctor_id = auth.uid() or patient_id = auth.uid());

insert into support_groups (name, type, schedule, is_virtual, join_link) values
 ('Alcoholics Anonymous','AA','Mon/Wed/Fri 7:00 PM',true,'https://zoom.us/'),
 ('Narcotics Anonymous','NA','Tue/Thu 6:30 PM',true,'https://zoom.us/'),
 ('SMART Recovery','SMART','Saturdays 10:00 AM',true,'https://zoom.us/');
