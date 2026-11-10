-- JJ-043-C step 1b: keep students.instruments and student_instruments in step,
-- in both directions, so older screens and the new ones always agree.
-- Additive: two trigger functions + two triggers. No existing data changes.

create or replace function public.sync_student_instruments_from_student() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if pg_trigger_depth() > 1 then return new; end if;
  insert into public.student_instruments(student_id, instrument, instruction, created_by)
    select new.id, i, 'caregiver', auth.uid() from unnest(coalesce(new.instruments,'{}')) as i
    on conflict do nothing;
  delete from public.student_instruments si
    where si.student_id = new.id
      and not exists (select 1 from unnest(coalesce(new.instruments,'{}')) as i where lower(i) = lower(si.instrument));
  return new;
end;
$$;
create trigger students_sync_instruments after insert or update of instruments on public.students
  for each row execute function public.sync_student_instruments_from_student();

create or replace function public.sync_student_from_student_instruments() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if pg_trigger_depth() > 1 then return null; end if;
  if tg_op = 'INSERT' then
    update public.students s set instruments = array_append(coalesce(s.instruments,'{}'), new.instrument)
      where s.id = new.student_id
        and not exists (select 1 from unnest(coalesce(s.instruments,'{}')) as i where lower(i) = lower(new.instrument));
  else
    update public.students s set instruments = coalesce((select array_agg(i) from unnest(s.instruments) as i
                                                  where lower(i) <> lower(old.instrument)), '{}')
      where s.id = old.student_id;
  end if;
  return null;
end;
$$;
create trigger student_instruments_sync_student after insert or delete on public.student_instruments
  for each row execute function public.sync_student_from_student_instruments();

revoke execute on function public.sync_student_instruments_from_student() from public, anon, authenticated;
revoke execute on function public.sync_student_from_student_instruments() from public, anon, authenticated;

-- ROLLBACK: drop trigger students_sync_instruments on public.students;
--           drop trigger student_instruments_sync_student on public.student_instruments;
--           drop function public.sync_student_instruments_from_student(); drop function public.sync_student_from_student_instruments();
