-- JJ-046-C follow-up: `authenticated` holds a table-wide UPDATE grant on students, so a column grant
-- cannot protect students.hidden_instruments. Only hide_instrument / unhide_instrument (which run as the
-- function owner) may change it; a direct write from a signed-in client is refused.
create or replace function public.guard_hidden_instruments() returns trigger
language plpgsql set search_path='' as $$
begin
  if current_user in ('authenticated','anon') then
    if tg_op = 'INSERT' then
      new.hidden_instruments := '{}';
    elsif new.hidden_instruments is distinct from old.hidden_instruments then
      raise exception 'Use Hide instrument to change this' using errcode='42501';
    end if;
  end if;
  return new;
end; $$;
create trigger students_guard_hidden_instruments before insert or update on public.students
  for each row execute function public.guard_hidden_instruments();
-- ROLLBACK: drop trigger students_guard_hidden_instruments on public.students; drop function public.guard_hidden_instruments();
