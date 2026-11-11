-- JJ-046-C follow-up: "Delete for good" really removes the instrument AND its lessons, assignments and goals
-- (assignments and goals go with their lesson). Rewards already earned and past practice history stay,
-- because the ledgers only lose their link to the deleted assignment. Only the primary caregiver can do this,
-- and at least one other instrument must stay showing.
create or replace function public.delete_instrument(p_student_id uuid, p_instrument text)
returns void language plpgsql security definer set search_path='' as $$
declare k text := lower(trim(coalesce(p_instrument,''))); hid text[]; others integer; first_instr text;
begin
  if auth.uid() is null then raise exception 'Sign in first' using errcode='42501'; end if;
  if not public.is_primary_guardian(p_student_id) then
    raise exception 'Only the primary caregiver can delete an instrument' using errcode='42501'; end if;
  if not exists (select 1 from public.student_instruments where student_id=p_student_id and lower(instrument)=k) then
    raise exception 'That instrument is not on this student'; end if;
  select coalesce(hidden_instruments,'{}'), lower(coalesce(instruments[1],'music')) into hid, first_instr
    from public.students where id=p_student_id;
  select count(*) into others from public.student_instruments si
    where si.student_id=p_student_id and lower(si.instrument) <> k and not (lower(si.instrument) = any(hid));
  if others < 1 then
    raise exception 'At least one instrument has to stay showing. Add another instrument first.'; end if;
  delete from public.lessons
    where student_id=p_student_id and lower(coalesce(instrument, first_instr)) = k;
  delete from public.student_instruments where student_id=p_student_id and lower(instrument)=k;
end; $$;
revoke all on function public.delete_instrument(uuid,text) from public, anon;
grant execute on function public.delete_instrument(uuid,text) to authenticated;
-- ROLLBACK: drop function public.delete_instrument(uuid,text);  (deleted data cannot be restored)
