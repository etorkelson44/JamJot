-- JamJot migration 0002 — profile switching (Netflix-style, one family login)
-- Run AFTER 0001_init.sql, same way: SQL Editor -> New query -> paste -> Run.

-- Parent's app passcode (hashed; gates kid -> parent switching and
-- sensitive actions like caregiver settings, message deletion, market stocking)
alter table profiles add column if not exists app_pin_hash text;

-- Each kid's own PIN (hashed; gates switching INTO their profile from
-- another kid's view, so siblings can't open each other's profiles)
alter table students add column if not exists pin_hash text;

-- Which profile view a device was last using (quality-of-life on reopen)
alter table profiles add column if not exists last_active_student uuid
  references students(id) on delete set null;
