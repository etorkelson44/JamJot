-- NoteStar (2026-11-15, Erika): weekly albums (take choices), Superfans, shared albums, fan mail. Additive only.
-- Applied to the live project on 2026-11-15 as migration "notestar_albums_and_fans".
create table if not exists public.album_picks (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  album_key text not null,
  assignment_id uuid not null references public.assignments(id) on delete cascade,
  clip_path text not null,
  chosen_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  unique (student_id, album_key, assignment_id)
);
alter table public.album_picks enable row level security;
create policy album_picks_select on public.album_picks for select using (can_see_student(student_id));
create policy album_picks_cud on public.album_picks for all
  using (is_self_student(student_id) or is_guardian(student_id))
  with check (is_self_student(student_id) or is_guardian(student_id));
create table if not exists public.fans (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  email text not null check (char_length(email) between 3 and 200),
  added_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);
alter table public.fans enable row level security;
create policy fans_select on public.fans for select using (is_self_student(student_id) or is_guardian(student_id));
create policy fans_cud on public.fans for all using (is_guardian(student_id)) with check (is_guardian(student_id));
create table if not exists public.fan_shares (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  fan_id uuid not null references public.fans(id) on delete cascade,
  album_key text not null,
  album_title text,
  clips jsonb not null default '[]'::jsonb,
  token text not null unique default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
  emailed_at timestamptz,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);
alter table public.fan_shares enable row level security;
create policy fan_shares_select on public.fan_shares for select using (is_self_student(student_id) or is_guardian(student_id));
create policy fan_shares_insert on public.fan_shares for insert with check (is_self_student(student_id) or is_guardian(student_id));
create policy fan_shares_delete on public.fan_shares for delete using (is_guardian(student_id));
create table if not exists public.fan_mail (
  id uuid primary key default gen_random_uuid(),
  share_id uuid references public.fan_shares(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  fan_id uuid references public.fans(id) on delete set null,
  fan_name text not null,
  message text not null check (char_length(message) between 1 and 1000),
  status text not null default 'pending' check (status in ('pending','approved','hidden')),
  reviewed_by uuid,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.fan_mail enable row level security;
create policy fan_mail_select on public.fan_mail for select
  using (is_guardian(student_id) or (status = 'approved' and can_see_student(student_id)));
create policy fan_mail_review on public.fan_mail for update using (is_guardian(student_id)) with check (is_guardian(student_id));
create policy fan_mail_delete on public.fan_mail for delete using (is_guardian(student_id));
alter table public.students add column if not exists fan_mail_review boolean not null default true;
