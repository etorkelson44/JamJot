-- JJ-043-C step 2: caregiver-chosen rule for what counts as a shared practice day
-- when a student plays several instruments. 'any' (default) = a day counts when any
-- instrument's daily goal is met; 'all' = every instrument with a lesson must meet its goal.
alter table public.students add column if not exists streak_rule text not null default 'any'
  check (streak_rule in ('any','all'));
-- ROLLBACK: alter table public.students drop column streak_rule;
