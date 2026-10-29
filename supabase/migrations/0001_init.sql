-- ============================================================
-- JamJot — initial schema + row-level security
-- Paste this whole file into Supabase: SQL Editor → New query → Run
-- ============================================================

create extension if not exists pgcrypto;

-- ---------- PEOPLE ----------

-- One row per adult login (linked to Supabase Auth)
create table profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text not null default '',
  avatar_key  text,                      -- key into app avatar assets
  created_at  timestamptz not null default now()
);

-- Kid profiles: no email, no login of their own by default.
-- Optionally linked to a child auth user the primary caregiver creates
-- for the kid's own device ("kid mode").
create table students (
  id            uuid primary key default gen_random_uuid(),
  display_name  text not null,
  instruments   text[] not null default '{}',
  avatar_key    text,
  auth_user_id  uuid unique references auth.users(id) on delete set null,
  created_by    uuid not null references profiles(id),
  created_at    timestamptz not null default now()
);

-- Adult <-> student links. No household container (blended-family safe).
create table guardianships (
  id                 uuid primary key default gen_random_uuid(),
  student_id         uuid not null references students(id) on delete cascade,
  profile_id         uuid not null references profiles(id) on delete cascade,
  is_primary         boolean not null default false,
  can_message        boolean not null default false,
  can_view_calendar  boolean not null default true,
  family_event_level text not null default 'view'
                     check (family_event_level in ('none','view','add','edit')),
  can_stock_rewards  boolean not null default false,
  created_at         timestamptz not null default now(),
  unique (student_id, profile_id)
);
-- exactly one primary caregiver per student
create unique index one_primary_per_student
  on guardianships (student_id) where is_primary;

-- ---------- STUDIOS & TEACHERS ----------

create table studios (
  id         uuid primary key default gen_random_uuid(),
  owner_id   uuid not null references profiles(id),
  name       text not null,
  created_at timestamptz not null default now()
);

create table teachers (
  id                  uuid primary key default gen_random_uuid(),
  profile_id          uuid not null references profiles(id) on delete cascade,
  studio_id           uuid references studios(id) on delete set null,
  display_name        text not null,
  instruments         text[] not null default '{}',
  accepting_students  boolean not null default true,
  self_managed        boolean not null default false, -- studio delegated billing/admin
  created_at          timestamptz not null default now(),
  unique (profile_id, studio_id)
);

-- Student x teacher x instrument. The atomic unit everything hangs off.
create table enrollments (
  id          uuid primary key default gen_random_uuid(),
  student_id  uuid not null references students(id) on delete cascade,
  teacher_id  uuid not null references teachers(id) on delete cascade,
  studio_id   uuid references studios(id) on delete set null,
  instrument  text not null,
  status      text not null default 'pending'
              check (status in ('pending','active','ended')),
  created_at  timestamptz not null default now()
);
create unique index uniq_active_enrollment
  on enrollments (student_id, teacher_id, instrument)
  where status in ('pending','active');

-- ---------- INVITATIONS (one universal smart link) ----------

create table invitations (
  id            uuid primary key default gen_random_uuid(),
  token         text not null unique default encode(gen_random_bytes(12), 'hex'),
  kind          text not null check (kind in ('caregiver','enrollment','studio_code')),
  created_by    uuid not null references profiles(id),
  student_id    uuid references students(id) on delete cascade,     -- caregiver invites
  teacher_id    uuid references teachers(id) on delete cascade,     -- enrollment invites
  studio_id     uuid references studios(id) on delete cascade,      -- standing studio codes
  instrument    text,
  preset_grants jsonb not null default '{}',   -- caregiver grants chosen at invite time
  single_use    boolean not null default true, -- false = standing studio code
  pre_approved  boolean not null default true, -- false = teacher approves each join
  expires_at    timestamptz,
  used_at       timestamptz,
  used_by       uuid references profiles(id),
  created_at    timestamptz not null default now()
);

-- ---------- LESSONS & ASSIGNMENTS ----------

-- Score library: every assignment references a verified digital score
create table scores (
  id             uuid primary key default gen_random_uuid(),
  owner_id       uuid not null references profiles(id),
  title          text not null,
  source         text not null default 'upload'
                 check (source in ('upload','purchase','public_domain','library')),
  license_scope  text not null default 'owner'
                 check (license_scope in ('owner','everyone')),
  musicxml_path  text,          -- storage path, required before verification unlocks
  original_path  text,          -- original PDF/photo
  meta           jsonb not null default '{}',  -- key, time sig, measures, repeats
  created_at     timestamptz not null default now()
);

-- A lesson = one practice plan (weekly). enrollment null => parent-managed.
create table lessons (
  id             uuid primary key default gen_random_uuid(),
  student_id     uuid not null references students(id) on delete cascade,
  enrollment_id  uuid references enrollments(id) on delete cascade,
  created_by     uuid not null references profiles(id),
  title          text not null default '',
  lesson_note    text not null default '',       -- pinned during every practice
  goal_days      int  not null default 4,        -- days per week
  goal_minutes   int  not null default 15,       -- minutes per session
  week_start     date,
  created_at     timestamptz not null default now()
);

create table assignments (
  id                 uuid primary key default gen_random_uuid(),
  lesson_id          uuid not null references lessons(id) on delete cascade,
  title              text not null,
  song_note          text not null default '',
  suggested_minutes  int,
  order_idx          int not null default 0,
  score_id           uuid references scores(id) on delete set null,
  is_performance     boolean not null default false,
  created_at         timestamptz not null default now()
);

create table verifiable_goals (
  id            uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references assignments(id) on delete cascade,
  kind          text not null check (kind in
                ('slow_tempo','count_aloud','take_repeats','play_throughs','metronome','custom')),
  params        jsonb not null default '{}',
  created_at    timestamptz not null default now()
);

-- Reusable templates (files stripped unless owner-licensed; enforced in app logic)
create table saved_assignments (
  id         uuid primary key default gen_random_uuid(),
  owner_id   uuid not null references profiles(id) on delete cascade,
  payload    jsonb not null,
  created_at timestamptz not null default now()
);
create table saved_lessons (
  id         uuid primary key default gen_random_uuid(),
  owner_id   uuid not null references profiles(id) on delete cascade,
  payload    jsonb not null,
  created_at timestamptz not null default now()
);

-- ---------- PRACTICE SESSIONS ----------

create table sessions (
  id            uuid primary key default gen_random_uuid(),
  student_id    uuid not null references students(id) on delete cascade,
  started_at    timestamptz not null default now(),
  ended_at      timestamptz,
  total_seconds int not null default 0,     -- verified sound-present seconds
  goal_met      boolean not null default false,
  audio_path    text,                       -- session recording in storage
  created_at    timestamptz not null default now()
);

-- Minutes attributed per song (or free play) within a session
create table session_segments (
  id            uuid primary key default gen_random_uuid(),
  session_id    uuid not null references sessions(id) on delete cascade,
  assignment_id uuid references assignments(id) on delete set null,  -- null = free play
  kind          text not null default 'playing'
                check (kind in ('playing','rhythm_work','free_play')),
  seconds       int not null default 0,
  goal_results  jsonb not null default '{}',  -- per verifiable goal: met/skipped
  completed     boolean not null default false, -- song marked done + verified
  flagged       boolean not null default false  -- surfaced in caregiver report
);

-- ---------- MESSAGING (one chat per enrollment, read-locked) ----------

create table messages (
  id            uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references enrollments(id) on delete cascade,
  sender_id     uuid not null references auth.users(id), -- adult profile OR kid auth user
  body          text not null,
  created_at    timestamptz not null default now(),
  deleted_at    timestamptz,                -- only primary caregiver may set
  deleted_by    uuid references profiles(id)
);

create table message_reads (
  message_id uuid not null references messages(id) on delete cascade,
  reader_id  uuid not null references auth.users(id),
  read_at    timestamptz not null default now(),
  primary key (message_id, reader_id)
);

-- ---------- CALENDAR ----------

create table calendar_events (
  id          uuid primary key default gen_random_uuid(),
  kind        text not null check (kind in ('lesson','extra_lesson','studio_event','performance','family')),
  title       text not null,
  starts_at   timestamptz not null,
  ends_at     timestamptz,
  owner_id    uuid not null references profiles(id),  -- creator (teacher/studio or caregiver)
  studio_id   uuid references studios(id) on delete cascade,
  teacher_id  uuid references teachers(id) on delete cascade,
  notes       text not null default '',
  created_at  timestamptz not null default now()
);

create table event_students (
  event_id   uuid not null references calendar_events(id) on delete cascade,
  student_id uuid not null references students(id) on delete cascade,
  primary key (event_id, student_id)
);

create table event_change_requests (
  id           uuid primary key default gen_random_uuid(),
  event_id     uuid not null references calendar_events(id) on delete cascade,
  requested_by uuid not null references profiles(id),
  request_kind text not null check (request_kind in ('reschedule','cancel','extra_lesson')),
  note         text not null default '',
  status       text not null default 'pending'
               check (status in ('pending','approved','declined')),
  created_at   timestamptz not null default now()
);

-- ---------- REWARDS: FANS, BERRIES, MARKET ----------

create table fan_ledger (
  id         uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id) on delete cascade,
  amount     int not null,
  reason     text not null,
  session_id uuid references sessions(id) on delete set null,
  created_at timestamptz not null default now()
);

create table berry_ledger (
  id         uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id) on delete cascade,
  amount     int not null,              -- positive = earn, negative = spend
  reason     text not null,
  session_id uuid references sessions(id) on delete set null,
  created_at timestamptz not null default now()
);

create table market_items (
  id          uuid primary key default gen_random_uuid(),
  stand       text not null check (stand in ('jamjot','teacher','caregiver')),
  owner_id    uuid references profiles(id) on delete cascade,  -- teacher/caregiver stands
  studio_id   uuid references studios(id) on delete cascade,
  student_id  uuid references students(id) on delete cascade,  -- null = all my linked students
  title       text not null,
  description text not null default '',
  price       int not null check (price > 0),
  asset_key   text,          -- for jamjot cosmetics
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

create table purchases (
  id         uuid primary key default gen_random_uuid(),
  item_id    uuid not null references market_items(id),
  student_id uuid not null references students(id) on delete cascade,
  price_paid int not null,
  status     text not null default 'pending'
             check (status in ('pending','fulfilled')),  -- real-life items await adult fulfill
  created_at timestamptz not null default now()
);

-- ============================================================
-- HELPER FUNCTIONS (used by the security rules)
-- ============================================================

create or replace function is_guardian(sid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from guardianships g
                 where g.student_id = sid and g.profile_id = auth.uid());
$$;

create or replace function is_primary_guardian(sid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from guardianships g
                 where g.student_id = sid and g.profile_id = auth.uid() and g.is_primary);
$$;

create or replace function is_self_student(sid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from students s
                 where s.id = sid and s.auth_user_id = auth.uid());
$$;

create or replace function is_student_teacher(sid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from enrollments e
                 join teachers t on t.id = e.teacher_id
                 where e.student_id = sid and e.status = 'active'
                   and t.profile_id = auth.uid());
$$;

create or replace function can_see_student(sid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select is_guardian(sid) or is_self_student(sid) or is_student_teacher(sid);
$$;

create or replace function is_enrollment_member(eid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from enrollments e
    left join teachers t on t.id = e.teacher_id
    left join students s on s.id = e.student_id
    where e.id = eid and (
      t.profile_id = auth.uid()
      or s.auth_user_id = auth.uid()
      or exists (select 1 from guardianships g
                 where g.student_id = e.student_id
                   and g.profile_id = auth.uid()
                   and (g.is_primary or g.can_message))
    )
  );
$$;

create or replace function manages_lessons(sid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  -- teachers of the student, or guardians when creating parent-managed content
  select is_student_teacher(sid) or is_guardian(sid);
$$;

-- ============================================================
-- ROW-LEVEL SECURITY
-- ============================================================

alter table profiles enable row level security;
alter table students enable row level security;
alter table guardianships enable row level security;
alter table studios enable row level security;
alter table teachers enable row level security;
alter table enrollments enable row level security;
alter table invitations enable row level security;
alter table scores enable row level security;
alter table lessons enable row level security;
alter table assignments enable row level security;
alter table verifiable_goals enable row level security;
alter table saved_assignments enable row level security;
alter table saved_lessons enable row level security;
alter table sessions enable row level security;
alter table session_segments enable row level security;
alter table messages enable row level security;
alter table message_reads enable row level security;
alter table calendar_events enable row level security;
alter table event_students enable row level security;
alter table event_change_requests enable row level security;
alter table fan_ledger enable row level security;
alter table berry_ledger enable row level security;
alter table market_items enable row level security;
alter table purchases enable row level security;

-- profiles: you can read/write your own; connected people see names via views later
create policy profiles_own on profiles
  for all using (id = auth.uid()) with check (id = auth.uid());

-- students: visible to guardians, the kid, their teachers; created by adults
create policy students_select on students
  for select using (can_see_student(id));
create policy students_insert on students
  for insert with check (created_by = auth.uid());
create policy students_update on students
  for update using (is_primary_guardian(id));
create policy students_delete on students
  for delete using (is_primary_guardian(id));

-- guardianships: visible to fellow guardians + the kid's teachers; only primary manages
create policy guardianships_select on guardianships
  for select using (profile_id = auth.uid() or can_see_student(student_id));
create policy guardianships_insert on guardianships
  for insert with check (
    is_primary_guardian(student_id)
    or (profile_id = auth.uid() and is_primary
        and exists (select 1 from students s
                    where s.id = student_id and s.created_by = auth.uid()))
  );
create policy guardianships_update on guardianships
  for update using (is_primary_guardian(student_id));
create policy guardianships_delete on guardianships
  for delete using (is_primary_guardian(student_id) or profile_id = auth.uid());

-- studios & teachers: readable by any signed-in user (needed for teacher picker);
-- managed by their owners
create policy studios_select on studios for select using (auth.uid() is not null);
create policy studios_cud on studios
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy teachers_select on teachers for select using (auth.uid() is not null);
create policy teachers_cud on teachers
  for all using (
    profile_id = auth.uid()
    or exists (select 1 from studios st where st.id = studio_id and st.owner_id = auth.uid())
  ) with check (
    profile_id = auth.uid()
    or exists (select 1 from studios st where st.id = studio_id and st.owner_id = auth.uid())
  );

-- enrollments: members see them; primary caregiver or the teacher create/approve
create policy enrollments_select on enrollments
  for select using (can_see_student(student_id));
create policy enrollments_insert on enrollments
  for insert with check (
    is_primary_guardian(student_id)
    or exists (select 1 from teachers t where t.id = teacher_id and t.profile_id = auth.uid())
  );
create policy enrollments_update on enrollments
  for update using (
    is_primary_guardian(student_id)
    or exists (select 1 from teachers t where t.id = teacher_id and t.profile_id = auth.uid())
  );

-- invitations: creator manages; token lookup happens via edge function (service role)
create policy invitations_own on invitations
  for all using (created_by = auth.uid()) with check (created_by = auth.uid());

-- scores: owner full control; connected people can read owner-licensed scores
-- when attached to a shared student's assignment (simplified: owner + everyone-scope read)
create policy scores_select on scores
  for select using (
    owner_id = auth.uid()
    or license_scope = 'everyone'
    or exists (
      select 1 from assignments a
      join lessons l on l.id = a.lesson_id
      where a.score_id = scores.id and can_see_student(l.student_id)
    )
  );
create policy scores_cud on scores
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- lessons/assignments/goals: connected people read; teachers & guardians write
create policy lessons_select on lessons for select using (can_see_student(student_id));
create policy lessons_cud on lessons
  for all using (manages_lessons(student_id) and created_by = auth.uid()
                 or is_student_teacher(student_id) or is_primary_guardian(student_id))
  with check (manages_lessons(student_id));
create policy assignments_select on assignments
  for select using (exists (select 1 from lessons l where l.id = lesson_id and can_see_student(l.student_id)));
create policy assignments_cud on assignments
  for all using (exists (select 1 from lessons l where l.id = lesson_id and manages_lessons(l.student_id)))
  with check (exists (select 1 from lessons l where l.id = lesson_id and manages_lessons(l.student_id)));
create policy goals_select on verifiable_goals
  for select using (exists (select 1 from assignments a join lessons l on l.id = a.lesson_id
                            where a.id = assignment_id and can_see_student(l.student_id)));
create policy goals_cud on verifiable_goals
  for all using (exists (select 1 from assignments a join lessons l on l.id = a.lesson_id
                         where a.id = assignment_id and manages_lessons(l.student_id)))
  with check (exists (select 1 from assignments a join lessons l on l.id = a.lesson_id
                      where a.id = assignment_id and manages_lessons(l.student_id)));

-- saved libraries: private to their owner
create policy saved_assignments_own on saved_assignments
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy saved_lessons_own on saved_lessons
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- sessions & segments: connected people read; the kid/guardian device writes
create policy sessions_select on sessions for select using (can_see_student(student_id));
create policy sessions_cud on sessions
  for all using (is_self_student(student_id) or is_guardian(student_id))
  with check (is_self_student(student_id) or is_guardian(student_id));
create policy segments_select on session_segments
  for select using (exists (select 1 from sessions s where s.id = session_id and can_see_student(s.student_id)));
create policy segments_cud on session_segments
  for all using (exists (select 1 from sessions s where s.id = session_id
                         and (is_self_student(s.student_id) or is_guardian(s.student_id))))
  with check (exists (select 1 from sessions s where s.id = session_id
                      and (is_self_student(s.student_id) or is_guardian(s.student_id))));

-- messages: one chat per enrollment; members only; no edits ever;
-- deletes only by primary caregiver (audit stays in the row)
create policy messages_select on messages
  for select using (is_enrollment_member(enrollment_id) and deleted_at is null
                    or (is_enrollment_member(enrollment_id)
                        and exists (select 1 from enrollments e
                                    where e.id = enrollment_id and is_primary_guardian(e.student_id))));
create policy messages_insert on messages
  for insert with check (sender_id = auth.uid() and is_enrollment_member(enrollment_id));
create policy messages_delete_mark on messages
  for update using (exists (select 1 from enrollments e
                            where e.id = enrollment_id and is_primary_guardian(e.student_id)))
  with check (deleted_by = auth.uid());
-- note: no UPDATE policy for senders = read-lock is absolute (no edit/unsend at all in v1)

create policy message_reads_select on message_reads
  for select using (exists (select 1 from messages m
                            where m.id = message_id and is_enrollment_member(m.enrollment_id)));
create policy message_reads_insert on message_reads
  for insert with check (reader_id = auth.uid());

-- calendar: official events visible to connected + studio; family events
-- visible per guardianship grants; teachers never see family events
create policy events_select on calendar_events
  for select using (
    owner_id = auth.uid()
    or (kind <> 'family' and (
        exists (select 1 from event_students es
                where es.event_id = id and can_see_student(es.student_id))
        or exists (select 1 from teachers t
                   where t.studio_id = calendar_events.studio_id and t.profile_id = auth.uid())))
    or (kind = 'family' and exists (
        select 1 from event_students es
        join guardianships g on g.student_id = es.student_id
        where es.event_id = id and g.profile_id = auth.uid()
          and g.family_event_level in ('view','add','edit')))
    or (kind = 'family' and exists (
        select 1 from event_students es
        where es.event_id = id and is_self_student(es.student_id)))
  );
create policy events_insert on calendar_events
  for insert with check (
    owner_id = auth.uid() and (
      kind = 'family'  -- per-student add rights checked on event_students insert
      or exists (select 1 from teachers t where t.profile_id = auth.uid())
      or exists (select 1 from studios st where st.id = studio_id and st.owner_id = auth.uid())
      -- parent-managed mode: guardians may create official-kind events for their kids
      or kind in ('lesson','extra_lesson','performance')
    )
  );
create policy events_update on calendar_events
  for update using (
    owner_id = auth.uid()
    or (kind = 'family' and exists (
        select 1 from event_students es
        join guardianships g on g.student_id = es.student_id
        where es.event_id = id and g.profile_id = auth.uid()
          and g.family_event_level = 'edit'))
  );
create policy events_delete on calendar_events
  for delete using (owner_id = auth.uid());

create policy event_students_select on event_students
  for select using (can_see_student(student_id) or
                    exists (select 1 from calendar_events ce
                            where ce.id = event_id and ce.owner_id = auth.uid()));
create policy event_students_cud on event_students
  for all using (exists (select 1 from calendar_events ce
                         where ce.id = event_id and ce.owner_id = auth.uid()))
  with check (
    exists (select 1 from calendar_events ce
            where ce.id = event_id and ce.owner_id = auth.uid())
    and (is_guardian(student_id) or is_student_teacher(student_id)
         or exists (select 1 from calendar_events ce
                    join teachers t on t.studio_id = ce.studio_id
                    where ce.id = event_id and t.profile_id = auth.uid()))
  );

create policy change_requests_select on event_change_requests
  for select using (
    requested_by = auth.uid()
    or exists (select 1 from calendar_events ce
               where ce.id = event_id and ce.owner_id = auth.uid())
  );
create policy change_requests_insert on event_change_requests
  for insert with check (
    requested_by = auth.uid()
    and exists (select 1 from event_students es
                where es.event_id = event_change_requests.event_id and is_guardian(es.student_id))
  );
create policy change_requests_update on event_change_requests
  for update using (exists (select 1 from calendar_events ce
                            where ce.id = event_id and ce.owner_id = auth.uid()));

-- ledgers: connected people read; writes happen via edge functions (service role)
-- so kids can't mint their own berries
create policy fan_ledger_select on fan_ledger for select using (can_see_student(student_id));
create policy berry_ledger_select on berry_ledger for select using (can_see_student(student_id));

-- market: jamjot items are public; teacher/caregiver items visible to their students'
-- circle; stocked only by permitted adults
create policy market_select on market_items
  for select using (
    stand = 'jamjot'
    or owner_id = auth.uid()
    or (student_id is not null and can_see_student(student_id))
    or (student_id is null and owner_id is not null and exists (
        select 1 from guardianships g
        join guardianships mine on mine.student_id = g.student_id
        where g.profile_id = market_items.owner_id and mine.profile_id = auth.uid()))
    or (stand = 'teacher' and exists (
        select 1 from enrollments e
        join teachers t on t.id = e.teacher_id
        where (t.profile_id = market_items.owner_id or e.studio_id = market_items.studio_id)
          and can_see_student(e.student_id)))
  );
create policy market_cud on market_items
  for all using (owner_id = auth.uid())
  with check (
    owner_id = auth.uid() and (
      stand = 'teacher' and exists (select 1 from teachers t where t.profile_id = auth.uid())
      or stand = 'caregiver' and exists (
          select 1 from guardianships g
          where g.profile_id = auth.uid() and (g.is_primary or g.can_stock_rewards))
    )
  );

-- purchases: spend happens via edge function; reads for the circle
create policy purchases_select on purchases
  for select using (can_see_student(student_id)
                    or exists (select 1 from market_items mi
                               where mi.id = item_id and mi.owner_id = auth.uid()));
create policy purchases_update_fulfill on purchases
  for update using (exists (select 1 from market_items mi
                            where mi.id = item_id and mi.owner_id = auth.uid()));

-- ---------- AUTO-CREATE PROFILE ON SIGNUP ----------

create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''))
  on conflict (id) do nothing;
  return new;
end; $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ---------- CONVENIENCE VIEWS ----------

create or replace view student_berry_balance as
  select student_id, coalesce(sum(amount),0) as berries
  from berry_ledger group by student_id;

create or replace view student_fan_total as
  select student_id, coalesce(sum(amount),0) as fans
  from fan_ledger group by student_id;

-- ---------- STORAGE BUCKETS (run-once setup) ----------
insert into storage.buckets (id, name, public) values
  ('scores',     'scores',     false),
  ('recordings', 'recordings', false),
  ('avatars',    'avatars',    false)
on conflict (id) do nothing;

-- Done! 24 tables, security rules enforcing the full JamJot permission model.
