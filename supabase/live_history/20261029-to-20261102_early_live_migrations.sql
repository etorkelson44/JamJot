-- JamJot: early live-database migrations, exported 2026-11-07 from
-- supabase_migrations.schema_migrations (project cedlqxhrqwqwkohioiqb).
-- HISTORY / REBUILD REFERENCE. Versions 20261029165414 .. 20261102010521, in order.
-- The first live migration (20261029165344 jamjot_init) corresponds to
-- supabase/migrations/0001_init.sql. Run this file AFTER 0001_init.sql when rebuilding
-- an empty database, then the files in supabase/migrations/ that carry a 2026-11-04+ timestamp.
-- Do NOT run on the live database (everything here is already applied).
-- No user data is contained here (only schema, policies and the seeded market items).

-- ##### 20261029165414_security_hardening
-- Views must respect the querying user's row-level security,
-- not bypass it (otherwise any user could read all balances)
alter view student_berry_balance set (security_invoker = true);
alter view student_fan_total set (security_invoker = true);

-- The signup trigger runs internally; nobody should call it over the API
revoke execute on function handle_new_user() from anon, authenticated, public;

-- Helper functions: signed-out visitors have no business calling them.
-- (authenticated keeps execute — the RLS policies themselves need it.)
revoke execute on function is_guardian(uuid) from anon, public;
revoke execute on function is_primary_guardian(uuid) from anon, public;
revoke execute on function is_self_student(uuid) from anon, public;
revoke execute on function is_student_teacher(uuid) from anon, public;
revoke execute on function can_see_student(uuid) from anon, public;
revoke execute on function has_guardians(uuid) from anon, public;
revoke execute on function is_enrollment_member(uuid) from anon, public;
revoke execute on function manages_lessons(uuid) from anon, public;

-- ##### 20261029165802_payments_phase3
-- JamJot phase 3: lesson payments (storage layer; Stripe runtime arrives with launch)

-- caregiver grant: may contribute payments
alter table guardianships add column can_pay boolean not null default false;

-- who bills each enrollment: follows the studio by default, can be delegated/overridden
alter table enrollments add column billing_owner text
  check (billing_owner in ('studio','teacher'));

-- future Stripe Connect account references + card-fee preference
alter table studios  add column stripe_account_id text;
alter table studios  add column fee_mode text not null default 'absorb'
  check (fee_mode in ('absorb','pass'));
alter table teachers add column stripe_account_id text;
alter table teachers add column fee_mode text not null default 'absorb'
  check (fee_mode in ('absorb','pass'));

-- a bill: amount + due date per student, lands on the calendar
create table payment_requests (
  id            uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references enrollments(id) on delete cascade,
  student_id    uuid not null references students(id) on delete cascade,
  created_by    uuid not null references profiles(id),
  amount_cents  int not null check (amount_cents > 0),
  currency      text not null default 'usd',
  due_at        timestamptz not null,
  note          text not null default '',
  status        text not null default 'open'
                check (status in ('open','paid','canceled')),
  created_at    timestamptz not null default now()
);

-- a payment against a bill: stripe auto-completes; check/cash is two-state
create table payments (
  id             uuid primary key default gen_random_uuid(),
  request_id     uuid not null references payment_requests(id) on delete cascade,
  payer_id       uuid not null references profiles(id),
  method         text not null check (method in ('stripe','check','cash')),
  state          text not null default 'initiated'
                 check (state in ('initiated','sent','received','complete')),
  amount_cents   int not null,
  stripe_ref     text,          -- payment intent id when method = stripe
  completed_at   timestamptz,
  created_at     timestamptz not null default now()
);

alter table payment_requests enable row level security;
alter table payments enable row level security;

-- bills: visible to the student's circle and the biller; created/managed by the
-- teacher of the enrollment or the studio owner
create policy payreq_select on payment_requests
  for select using (can_see_student(student_id) or created_by = auth.uid());
create policy payreq_insert on payment_requests
  for insert with check (
    created_by = auth.uid() and (
      is_student_teacher(student_id)
      or exists (select 1 from enrollments e join studios st on st.id = e.studio_id
                 where e.id = enrollment_id and st.owner_id = auth.uid())
    )
  );
create policy payreq_update on payment_requests
  for update using (created_by = auth.uid());

-- payments: paid by the primary caregiver or a caregiver with the can_pay grant;
-- the biller confirms received/complete
create policy payments_select on payments
  for select using (
    payer_id = auth.uid()
    or exists (select 1 from payment_requests pr
               where pr.id = request_id
                 and (can_see_student(pr.student_id) or pr.created_by = auth.uid()))
  );
create policy payments_insert on payments
  for insert with check (
    payer_id = auth.uid()
    and exists (select 1 from payment_requests pr
                join guardianships g on g.student_id = pr.student_id
                where pr.id = request_id and g.profile_id = auth.uid()
                  and (g.is_primary or g.can_pay))
  );
create policy payments_update on payments
  for update using (
    payer_id = auth.uid()
    or exists (select 1 from payment_requests pr
               where pr.id = request_id and pr.created_by = auth.uid())
  );

-- ##### 20261031003656_per_song_awards
-- Track which song a reward came from, so each song pays out exactly once
-- per session and kids get their celebration right after rating the song.
alter table public.berry_ledger add column if not exists assignment_id uuid references public.assignments(id) on delete set null;
alter table public.fan_ledger add column if not exists assignment_id uuid references public.assignments(id) on delete set null;

-- ##### 20261031004305_segment_linked_awards
-- Link rewards to the exact practice segment that earned them, so repeat
-- practice of a finished song can earn bonus fans exactly once per chunk.
alter table public.berry_ledger add column if not exists segment_id uuid references public.session_segments(id) on delete set null;
alter table public.fan_ledger add column if not exists segment_id uuid references public.session_segments(id) on delete set null;

-- ##### 20261031004930_recordings_storage_policies
-- Who may save and hear practice recordings. Files live at
-- recordings/{student_id}/{session_id}.webm — the first folder names the kid.
create policy "recordings_upload" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'recordings'
    and (public.is_guardian((storage.foldername(name))[1]::uuid)
         or public.is_self_student((storage.foldername(name))[1]::uuid))
  );

create policy "recordings_read" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'recordings'
    and public.can_see_student((storage.foldername(name))[1]::uuid)
  );

-- ##### 20261031005627_per_song_recordings
-- Each practiced song keeps its own recording clips (one per record→stop).
alter table public.session_segments add column if not exists audio_paths text[] not null default '{}';

-- ##### 20261031010145_teacher_finalize_hour
-- The evening hour (0-23, teacher-local) when practice closes the night
-- before a lesson, so lesson sheets can be finalized & printed. Default 9pm.
alter table public.teachers add column if not exists finalize_hour int not null default 21;

-- ##### 20261031010800_segment_wall_seconds
-- Total recorded time per song chunk, alongside the sound-only seconds.
alter table public.session_segments add column if not exists wall_seconds int not null default 0;

-- ##### 20261031011133_clip_metadata
-- Each saved clip's own stamp: when it started, how long it ran, and how
-- much of it was real sound. [{path, at, wall_seconds, sound_seconds}]
alter table public.session_segments add column if not exists audio_clips jsonb not null default '[]';

-- ##### 20261031021207_scores_storage_policies
-- Uploaded music files live at scores/{owner_id}/... — owners manage their
-- own; anyone who can open the score row can read the file via signed URL.
create policy "scores_upload" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'scores'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "scores_read_own" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'scores'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ##### 20261031032626_caregiver_labels
-- Who each caregiver is, in family words (profiles are private, so the
-- invite carries the name & relationship the primary caregiver typed).
alter table public.guardianships add column if not exists nickname text;
alter table public.guardianships add column if not exists relationship text;

-- ##### 20261031032828_caregiver_identity
-- Who each caregiver is, in the family's own words.
alter table public.guardianships add column if not exists display_name text not null default '';
alter table public.guardianships add column if not exists relationship text not null default '';

-- ##### 20261031033124_caregiver_self_edit
-- Caregivers may update their own row, but a trigger ensures a non-primary
-- can only change how they're shown (name/relationship), never permissions.
alter table public.profiles add column if not exists phone text not null default '';

create policy "guardianships_update_self" on public.guardianships
  for update to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

create or replace function public.guard_guardianship_self_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() = new.profile_id and not public.is_primary_guardian(new.student_id) then
    if new.can_message is distinct from old.can_message
       or new.can_view_calendar is distinct from old.can_view_calendar
       or new.family_event_level is distinct from old.family_event_level
       or new.can_stock_rewards is distinct from old.can_stock_rewards
       or new.can_adjust_practice is distinct from old.can_adjust_practice
       or new.can_pay is distinct from old.can_pay then
      raise exception 'Only the primary caregiver can change permissions';
    end if;
  end if;
  if new.is_primary and not old.is_primary then
    raise exception 'The primary role cannot be granted this way';
  end if;
  return new;
end;
$$;

create trigger guardianships_self_guard
  before update on public.guardianships
  for each row execute function public.guard_guardianship_self_update();

-- ##### 20261031034145_grants_change_tracking
-- Stamp permission changes so caregivers get an in-app notice.
alter table public.guardianships add column if not exists grants_updated_at timestamptz;

create or replace function public.guard_guardianship_self_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  grants_changed boolean;
begin
  grants_changed := new.can_message is distinct from old.can_message
     or new.can_view_calendar is distinct from old.can_view_calendar
     or new.family_event_level is distinct from old.family_event_level
     or new.can_stock_rewards is distinct from old.can_stock_rewards
     or new.can_adjust_practice is distinct from old.can_adjust_practice
     or new.can_pay is distinct from old.can_pay;
  if auth.uid() = new.profile_id and not public.is_primary_guardian(new.student_id) then
    if grants_changed then
      raise exception 'Only the primary caregiver can change permissions';
    end if;
  end if;
  if new.is_primary and not old.is_primary then
    raise exception 'The primary role cannot be granted this way';
  end if;
  if grants_changed then
    new.grants_updated_at := now();
  end if;
  return new;
end;
$$;

-- ##### 20261031035603_allow_server_primary_transfer
-- The primary role may only be granted by the server (the transfer function
-- verifies the current primary's intent); app users still can't self-grant.
create or replace function public.guard_guardianship_self_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  grants_changed boolean;
begin
  grants_changed := new.can_message is distinct from old.can_message
     or new.can_view_calendar is distinct from old.can_view_calendar
     or new.family_event_level is distinct from old.family_event_level
     or new.can_stock_rewards is distinct from old.can_stock_rewards
     or new.can_adjust_practice is distinct from old.can_adjust_practice
     or new.can_pay is distinct from old.can_pay;
  if auth.uid() = new.profile_id and not public.is_primary_guardian(new.student_id) then
    if grants_changed then
      raise exception 'Only the primary caregiver can change permissions';
    end if;
  end if;
  -- auth.uid() is null only for the server itself (service role).
  if new.is_primary and not old.is_primary and auth.uid() is not null then
    raise exception 'The primary role can only move via the official transfer';
  end if;
  if grants_changed or (new.is_primary is distinct from old.is_primary) then
    new.grants_updated_at := now();
  end if;
  return new;
end;
$$;

-- ##### 20261031041112_family_event_caregiver_visibility
-- Caregivers with family-event permission can see family events their
-- kids are part of (fixes a join slip in the original policy).
create policy "family_events_caregivers_see" on public.calendar_events
  for select to authenticated
  using (
    kind = 'family'
    and exists (
      select 1
      from public.event_students es
      join public.guardianships g on g.student_id = es.student_id
      where es.event_id = calendar_events.id
        and g.profile_id = auth.uid()
        and g.family_event_level in ('view','add','edit')
    )
  );

-- ##### 20261031180401_library_folders
-- Library organization: each file lives at a folder path like
-- 'Suzuki/Book 2' (empty = library root), mirroring the uploader's computer.
alter table public.scores add column if not exists folder_path text not null default '';

-- ##### 20261031180432_library_folders
-- Virtual folders for library files: "Suzuki Book 1/Unit 2" style paths.
alter table public.scores add column if not exists folder text not null default '';

-- ##### 20261101191315_enable_pg_net
-- Lets the database make outbound HTTP calls (used here for diagnostics;
-- later for webhooks/notifications).
create extension if not exists pg_net;

-- ##### 20261101191611_scores_delete_policy
-- Owners may delete their own uploaded music files.
create policy "scores_delete_own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'scores'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ##### 20261101212709_weekly_schedules_and_event_status
-- A set weekly lesson day/time per student per section (teacher connection
-- or family-run when enrollment_id is null).
create table if not exists lesson_schedules (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id) on delete cascade,
  enrollment_id uuid references enrollments(id) on delete cascade,
  weekday int not null check (weekday between 1 and 7), -- 1 = Monday
  at_minutes int not null check (at_minutes between 0 and 1439),
  duration_minutes int not null default 30,
  created_by uuid not null,
  created_at timestamptz not null default now()
);
alter table lesson_schedules enable row level security;

create policy schedules_select on lesson_schedules for select
  using (can_see_student(student_id));
create policy schedules_insert on lesson_schedules for insert
  with check (created_by = auth.uid()
    and (is_guardian(student_id) or is_student_teacher(student_id)));
create policy schedules_update on lesson_schedules for update
  using (created_by = auth.uid());
create policy schedules_delete on lesson_schedules for delete
  using (created_by = auth.uid());

-- Cancellations & rescheduling with notes, and linking events to the
-- weekly schedule that generated them.
alter table calendar_events add column if not exists status text not null default 'scheduled';
alter table calendar_events add column if not exists status_note text;
alter table calendar_events add column if not exists schedule_id uuid;

-- A practice lesson can be pinned to the calendar lesson it was given at.
alter table lessons add column if not exists event_id uuid;

-- ##### 20261101222654_break_calendar_policy_recursion
-- Security-definer helpers so calendar_events and event_students policies
-- can look at each other without re-triggering each other (42P17 loop).
create or replace function event_owned_by_me(eid uuid)
returns boolean language sql stable security definer set search_path = public as
$$ select exists(select 1 from calendar_events ce where ce.id = eid and ce.owner_id = auth.uid()) $$;

create or replace function event_in_my_studio(eid uuid)
returns boolean language sql stable security definer set search_path = public as
$$ select exists(
     select 1 from calendar_events ce
     join teachers t on t.studio_id = ce.studio_id
     where ce.id = eid and t.profile_id = auth.uid()) $$;

create or replace function event_has_visible_student(eid uuid)
returns boolean language sql stable security definer set search_path = public as
$$ select exists(
     select 1 from event_students es
     where es.event_id = eid and can_see_student(es.student_id)) $$;

create or replace function event_has_self_student(eid uuid)
returns boolean language sql stable security definer set search_path = public as
$$ select exists(
     select 1 from event_students es
     where es.event_id = eid and is_self_student(es.student_id)) $$;

create or replace function family_event_visible(eid uuid)
returns boolean language sql stable security definer set search_path = public as
$$ select exists(
     select 1 from event_students es
     join guardianships g on g.student_id = es.student_id
     where es.event_id = eid and g.profile_id = auth.uid()
       and g.family_event_level in ('view','add','edit')) $$;

create or replace function family_event_editable(eid uuid)
returns boolean language sql stable security definer set search_path = public as
$$ select exists(
     select 1 from event_students es
     join guardianships g on g.student_id = es.student_id
     where es.event_id = eid and g.profile_id = auth.uid()
       and g.family_event_level = 'edit') $$;

-- Rewrite the policies to use the helpers (no table references that loop).
alter policy event_students_select on event_students
  using (can_see_student(student_id) or event_owned_by_me(event_id));

alter policy event_students_cud on event_students
  using (event_owned_by_me(event_id))
  with check (event_owned_by_me(event_id)
    and (is_guardian(student_id) or is_student_teacher(student_id)
         or event_in_my_studio(event_id)));

alter policy events_select on calendar_events
  using (
    owner_id = auth.uid()
    or (kind <> 'family' and (
         event_has_visible_student(id)
         or exists(select 1 from teachers t
                   where t.studio_id = calendar_events.studio_id
                     and t.profile_id = auth.uid())))
    or (kind = 'family' and (family_event_visible(id)
                             or event_has_self_student(id)))
  );

alter policy events_update on calendar_events
  using (owner_id = auth.uid()
         or (kind = 'family' and family_event_editable(id)));

alter policy family_events_caregivers_see on calendar_events
  using (kind = 'family' and family_event_visible(id));

-- ##### 20261101233626_market_open
-- Open the Farmer's Market: display fields, buying, avatars, seeded stand.
alter table market_items add column if not exists emoji text not null default '🎁';
alter table market_items add column if not exists kind text not null default 'treat';

-- Kids (and their grown-ups) can buy.
create policy purchases_insert on purchases for insert
  with check (is_guardian(student_id) or is_self_student(student_id));

-- Caregivers can also mark their family's purchases as given.
create policy purchases_update_family on purchases for update
  using (is_guardian(student_id));

-- The avatar a student currently wears (an asset_key they own).
alter table students add column if not exists avatar_key text;

-- Seed the JamJot stand: berry characters to wear as avatars.
insert into market_items (stand, title, emoji, description, price, kind, asset_key) values
  ('jamjot', 'Classic Blueberry', '🫐', 'The original. Cool shades included.', 10, 'avatar', 'blueberry'),
  ('jamjot', 'Rockstar Strawberry', '🍓', 'Shreds. Absolutely shreds.', 25, 'avatar', 'strawberry'),
  ('jamjot', 'Maestro Grape', '🍇', 'Conducts everything, even dinner.', 25, 'avatar', 'grape'),
  ('jamjot', 'Sunny Lemon', '🍋', 'Brightens every scale.', 25, 'avatar', 'lemon'),
  ('jamjot', 'Ninja Blackberry', '🥷', 'You never hear the page turns.', 40, 'avatar', 'blackberry'),
  ('jamjot', 'Royal Raspberry', '👑', 'Practices only on a velvet bench.', 40, 'avatar', 'raspberry'),
  ('jamjot', 'Robo-Melon', '🤖', 'Beep boop. Metronome built in.', 60, 'avatar', 'melon'),
  ('jamjot', 'Dragonfruit Legend', '🐉', 'Mythical. Appears only after real practice.', 80, 'avatar', 'dragonfruit'),
  ('jamjot', 'Golden Berry', '⭐', 'Shines brighter with every session.', 150, 'avatar', 'golden');

-- ##### 20261101234205_manual_practice_entries
-- Practices logged by hand (happened away from the app).
alter table sessions add column if not exists entered_by uuid;
alter table sessions add column if not exists entry_note text;

-- ##### 20261102003937_manual_practice_entries
-- Practices that happened away from the app, logged by a grown-up.
alter table sessions add column if not exists source text not null default 'app';
alter table sessions add column if not exists entered_by uuid;
alter table sessions add column if not exists entry_note text;

-- ##### 20261102010521_calendar_feed_tokens
-- A private link per person for subscribing from outside calendar apps
-- (Google/Apple/Skylight/Cozi). The token is the secret.
create table if not exists calendar_feeds (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null,
  token uuid not null default gen_random_uuid(),
  created_at timestamptz not null default now()
);
alter table calendar_feeds enable row level security;
create policy feeds_own on calendar_feeds for all
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());
