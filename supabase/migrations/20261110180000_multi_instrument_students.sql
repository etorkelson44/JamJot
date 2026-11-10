-- JJ-043-C step 1a: multiple instruments per student (additive only).
-- Nothing here drops, renames or rewrites existing data. The one data change is
-- a backfill of lessons.instrument, and every value it sets is logged in
-- lesson_instrument_backfill_log so it can be reversed with the statement at the bottom.

-- 1. Who teaches each of a student's instruments --------------------------------
create table if not exists public.student_instruments (
  id              uuid primary key default gen_random_uuid(),
  student_id      uuid not null references public.students(id) on delete cascade,
  instrument      text not null check (length(trim(instrument)) > 0),
  instruction     text not null default 'caregiver' check (instruction in ('caregiver','teacher')),
  enrollment_id   uuid references public.enrollments(id) on delete set null, -- teacher already on JamJot
  teacher_name    text,        -- "Teacher's name" (caregiver-entered, for teachers not on JamJot)
  teacher_known_as text,       -- "Known to my student as"
  invitation_id   uuid references public.invitations(id) on delete set null, -- pending invite to that teacher
  created_by      uuid references public.profiles(id),
  created_at      timestamptz not null default now()
);
create unique index if not exists uniq_student_instrument
  on public.student_instruments (student_id, lower(instrument));
create index if not exists student_instruments_student on public.student_instruments (student_id);

alter table public.student_instruments enable row level security;
create policy student_instruments_select on public.student_instruments
  for select using (public.can_see_student(student_id));
-- caregivers (and the student's own login) manage the list; a teacher can add the
-- instrument they teach through their enrollment.
create policy student_instruments_cud on public.student_instruments
  for all using (public.is_guardian(student_id) or public.is_self_student(student_id))
  with check (public.is_guardian(student_id) or public.is_self_student(student_id));
create policy student_instruments_teacher_insert on public.student_instruments
  for insert with check (public.is_student_teacher(student_id));

-- 2. Every lesson belongs to one instrument --------------------------------------
-- Nullable for now so older app versions keep working; the app will require it.
alter table public.lessons add column if not exists instrument text;

create table if not exists public.lesson_instrument_backfill_log (
  lesson_id   uuid primary key,
  instrument  text not null,
  source      text not null,   -- 'enrollment' | 'student_first_instrument' | 'default'
  done_at     timestamptz not null default now()
);
alter table public.lesson_instrument_backfill_log enable row level security; -- no policies: service role only

with filled as (
  select l.id,
         coalesce(e.instrument, s.instruments[1], 'Music') as instrument,
         case when e.instrument is not null then 'enrollment'
              when s.instruments[1] is not null then 'student_first_instrument'
              else 'default' end as source
  from public.lessons l
  left join public.enrollments e on e.id = l.enrollment_id
  left join public.students s on s.id = l.student_id
  where l.instrument is null
), logged as (
  insert into public.lesson_instrument_backfill_log(lesson_id, instrument, source)
  select id, instrument, source from filled
  on conflict do nothing
  returning lesson_id, instrument
)
update public.lessons l set instrument = g.instrument
from logged g where l.id = g.lesson_id;

-- 3. Seed the new table from what students already have ---------------------------
insert into public.student_instruments (student_id, instrument, instruction, enrollment_id)
select s.id, i.instrument,
       case when e.id is not null then 'teacher' else 'caregiver' end,
       e.id
from public.students s
cross join lateral unnest(s.instruments) as i(instrument)
left join lateral (select id from public.enrollments e
                   where e.student_id = s.id and lower(e.instrument) = lower(i.instrument)
                     and e.status in ('pending','active') limit 1) e on true
on conflict do nothing;

-- 4. Lesson-creating RPC: accept an optional instrument (same signature) -----------
create or replace function public.assign_library_lesson(p_lesson jsonb,p_assignments jsonb,p_request_id uuid)
returns uuid language plpgsql security invoker set search_path='' as $$
declare lesson_id uuid; song jsonb; ordinal bigint;
begin
  if auth.uid() is null or p_request_id is null then raise exception 'Sign in before assigning a lesson'; end if;
  select id into lesson_id from public.lessons where created_by=auth.uid() and assignment_request=p_request_id;
  if found then return lesson_id; end if;
  if nullif(trim(p_lesson->>'title'),'') is null or jsonb_array_length(p_assignments)=0 then raise exception 'A title and at least one song are required'; end if;
  if (p_lesson->>'goal_days')::integer not between 1 and 7 or (p_lesson->>'goal_minutes')::integer not between 1 and 240 then raise exception 'Choose 1–7 days and 1–240 minutes'; end if;
  insert into public.lessons(student_id,enrollment_id,created_by,title,lesson_note,goal_days,goal_minutes,week_start,event_id,assignment_request,instrument)
    values((p_lesson->>'student_id')::uuid,(p_lesson->>'enrollment_id')::uuid,auth.uid(),p_lesson->>'title',coalesce(p_lesson->>'lesson_note',''),
      (p_lesson->>'goal_days')::integer,(p_lesson->>'goal_minutes')::integer,(p_lesson->>'week_start')::date,(p_lesson->>'event_id')::uuid,p_request_id,
      nullif(trim(p_lesson->>'instrument'),''))
    returning id into lesson_id;
  for song,ordinal in select value, ordinality from jsonb_array_elements(p_assignments) with ordinality loop
    if nullif(trim(song->>'title'),'') is null then raise exception 'Each song needs a title'; end if;
    insert into public.assignments(lesson_id,title,song_note,score_id,order_idx,suggested_minutes)
      values(lesson_id,song->>'title',coalesce(song->>'note',''),(song->>'score_id')::uuid,ordinal-1,(song->>'suggested_minutes')::integer);
  end loop;
  return lesson_id;
end;
$$;

-- 5. Permanent teacher codes (JJ-044-C) -----------------------------------------------
-- One permanent code per teacher. The teacher sees it and hands it out at their own
-- discretion; caregivers of students assigned to that teacher can view it too.
-- Kept apart from `teachers` because that table is readable by every signed-in user.
create or replace function public.new_teacher_code() returns text
language plpgsql volatile set search_path='' as $$
declare alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; cand text; i int;
begin
  loop
    cand := '';
    for i in 1..8 loop
      cand := cand || substr(alphabet, 1 + floor(random()*length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.teacher_codes tc where tc.code = cand);
  end loop;
  return cand;
end;
$$;

create table if not exists public.teacher_codes (
  teacher_id uuid primary key references public.teachers(id) on delete cascade,
  code       text not null unique default public.new_teacher_code(),
  created_at timestamptz not null default now()
);
alter table public.teacher_codes enable row level security;
create policy teacher_codes_owner on public.teacher_codes
  for select using (exists (select 1 from public.teachers t where t.id = teacher_id and t.profile_id = auth.uid()));
create policy teacher_codes_caregiver on public.teacher_codes
  for select using (exists (select 1 from public.enrollments e
                            where e.teacher_id = teacher_codes.teacher_id and e.status = 'active'
                              and public.is_guardian(e.student_id)));
-- no insert/update/delete policies: codes are created by the trigger below and never edited.

insert into public.teacher_codes(teacher_id) select id from public.teachers on conflict do nothing;

create or replace function public.teacher_code_on_new_teacher() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  insert into public.teacher_codes(teacher_id) values (new.id) on conflict do nothing;
  return new;
end;
$$;
create trigger teachers_make_code after insert on public.teachers
  for each row execute function public.teacher_code_on_new_teacher();

revoke execute on function public.teacher_code_on_new_teacher() from public, anon, authenticated;
revoke execute on function public.new_teacher_code() from public, anon, authenticated;

-- ROLLBACK (run by hand if ever needed):
--   alter table public.lessons drop column instrument;
--   drop trigger teachers_make_code on public.teachers; drop table public.teacher_codes; drop function public.new_teacher_code(); drop function public.teacher_code_on_new_teacher();
--   drop table public.student_instruments; drop table public.lesson_instrument_backfill_log;
--   (then re-create assign_library_lesson from 20261103200554_practice_integrity.sql)
