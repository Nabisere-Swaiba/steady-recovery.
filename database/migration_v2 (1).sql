-- Run ONCE in Supabase > SQL Editor (after schema.sql)
alter table profiles alter column recovery_start_date type timestamptz using recovery_start_date::timestamptz;
alter table profiles add column if not exists recovery_goal text;
alter table profiles add column if not exists daily_saving numeric default 0;
grant update (recovery_goal, daily_saving) on profiles to authenticated;
alter table checkins add column if not exists inside text[] default '{}';
alter table checkins add column if not exists around text[] default '{}';
alter table checkins add column if not exists helped text[] default '{}';
alter table checkins add column if not exists note text;
notify pgrst, 'reload schema';
