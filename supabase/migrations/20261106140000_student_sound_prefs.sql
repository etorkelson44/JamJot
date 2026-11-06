-- Caregiver-controlled sound effects, per student profile (add-only).
-- Shape: {"enabled": bool, "coins": bool, "cheer": bool, "fanfare": bool, "pop": bool}
-- A missing key means "on", so every existing profile keeps today's behavior.
-- Only the primary caregiver can change it: the existing students_update
-- policy already limits updates to is_primary_guardian(id).
alter table public.students
  add column if not exists sound_prefs jsonb not null default '{}'::jsonb;
