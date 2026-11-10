-- JJ-011: every student starts as Sonatina Sprout, the free starter avatar.
-- New students get it by default; existing students with no worn avatar are
-- backfilled. Students already wearing a purchased avatar are untouched.
alter table public.students alter column avatar_key set default 'sonatina';
update public.students set avatar_key = 'sonatina' where avatar_key is null;
