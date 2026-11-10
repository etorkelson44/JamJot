-- Founder-approved 2026-11-05: assignments can be instrument-play (default),
-- written, or both. Add-only columns; no reward/settlement code is touched.
alter table public.assignments
  add column if not exists kind text not null default 'play',
  add column if not exists written_uploads jsonb not null default '[]'::jsonb,
  add column if not exists written_done_at timestamptz,
  add column if not exists written_verified_at timestamptz,
  add column if not exists written_verified_by uuid;
do $$ begin
  alter table public.assignments
    add constraint assignments_kind_check check (kind in ('play','written','both'));
exception when duplicate_object then null; end $$;

-- assign_library_lesson now also stores kind (invalid/missing -> 'play')
create or replace function public.assign_library_lesson(p_lesson jsonb, p_assignments jsonb, p_request_id uuid)
 returns uuid language plpgsql set search_path to '' as $function$
declare lesson_id uuid; song jsonb; ordinal bigint; v_kind text;
begin
  if auth.uid() is null or p_request_id is null then raise exception 'Sign in before assigning a lesson'; end if;
  select id into lesson_id from public.lessons where created_by=auth.uid() and assignment_request=p_request_id;
  if found then return lesson_id; end if;
  if nullif(trim(p_lesson->>'title'),'') is null or jsonb_array_length(p_assignments)=0 then raise exception 'A title and at least one song are required'; end if;
  if (p_lesson->>'goal_days')::integer not between 1 and 7 or (p_lesson->>'goal_minutes')::integer not between 1 and 240 then raise exception 'Choose 1–7 days and 1–240 minutes'; end if;
  insert into public.lessons(student_id,enrollment_id,created_by,title,lesson_note,goal_days,goal_minutes,week_start,event_id,assignment_request)
    values((p_lesson->>'student_id')::uuid,(p_lesson->>'enrollment_id')::uuid,auth.uid(),p_lesson->>'title',coalesce(p_lesson->>'lesson_note',''),
      (p_lesson->>'goal_days')::integer,(p_lesson->>'goal_minutes')::integer,(p_lesson->>'week_start')::date,(p_lesson->>'event_id')::uuid,p_request_id)
    returning id into lesson_id;
  for song,ordinal in select value, ordinality from jsonb_array_elements(p_assignments) with ordinality loop
    if nullif(trim(song->>'title'),'') is null then raise exception 'Each song needs a title'; end if;
    v_kind := coalesce(nullif(song->>'kind',''),'play');
    if v_kind not in ('play','written','both') then v_kind := 'play'; end if;
    insert into public.assignments(lesson_id,title,song_note,score_id,order_idx,suggested_minutes,book,pages,kind)
      values(lesson_id,song->>'title',coalesce(song->>'note',''),(song->>'score_id')::uuid,ordinal-1,(song->>'suggested_minutes')::integer,
        nullif(trim(coalesce(song->>'book','')),''),nullif(trim(coalesce(song->>'pages','')),''),v_kind);
  end loop;
  return lesson_id;
end; $function$;

-- Student (or caregiver) marks written work done, with uploaded page proofs.
-- Stamps only; awards remain untouched.
create or replace function public.submit_written_assignment(p_assignment_id uuid, p_uploads jsonb)
returns void language plpgsql security definer set search_path to '' as $$
declare sid uuid;
begin
  select l.student_id into sid from public.assignments a join public.lessons l on l.id=a.lesson_id where a.id=p_assignment_id;
  if sid is null or auth.uid() is null or not (public.is_self_student(sid) or public.is_guardian(sid)) then
    raise exception 'Practice is not available to this account' using errcode='42501';
  end if;
  if jsonb_typeof(p_uploads) is distinct from 'array' or jsonb_array_length(p_uploads)=0 then
    raise exception 'Add at least one photo or PDF of the finished pages first';
  end if;
  update public.assignments set written_uploads=p_uploads, written_done_at=now()
    where id=p_assignment_id and kind in ('written','both');
  if not found then raise exception 'This assignment has no written part'; end if;
end; $$;

-- Caregiver confirms the written work. Stamps only; the app then settles
-- rewards through the existing, unchanged settle_practice_session path.
create or replace function public.verify_written_assignment(p_assignment_id uuid)
returns void language plpgsql security definer set search_path to '' as $$
declare sid uuid;
begin
  select l.student_id into sid from public.assignments a join public.lessons l on l.id=a.lesson_id where a.id=p_assignment_id;
  if sid is null or auth.uid() is null or not public.is_guardian(sid) then
    raise exception 'Only a caregiver can confirm written work' using errcode='42501';
  end if;
  update public.assignments set written_verified_at=now(), written_verified_by=auth.uid()
    where id=p_assignment_id and kind in ('written','both')
      and written_done_at is not null and jsonb_array_length(written_uploads)>0;
  if not found then raise exception 'Mark the written work done (with pages uploaded) first'; end if;
end; $$;
