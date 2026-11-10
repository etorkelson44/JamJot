-- Founder-approved 2026-11-05: assignments carry the method book and page
-- number(s), shown on practice cards and auto-filled by the sheet scanner.
alter table public.assignments
  add column if not exists book text,
  add column if not exists pages text;

create or replace function public.assign_library_lesson(p_lesson jsonb, p_assignments jsonb, p_request_id uuid)
 returns uuid
 language plpgsql
 set search_path to ''
as $function$
declare lesson_id uuid; song jsonb; ordinal bigint;
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
    insert into public.assignments(lesson_id,title,song_note,score_id,order_idx,suggested_minutes,book,pages)
      values(lesson_id,song->>'title',coalesce(song->>'note',''),(song->>'score_id')::uuid,ordinal-1,(song->>'suggested_minutes')::integer,
        nullif(trim(coalesce(song->>'book','')),''),nullif(trim(coalesce(song->>'pages','')),''));
  end loop;
  return lesson_id;
end;
$function$;
