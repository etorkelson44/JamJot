# Edge function settings (exported 2026-11-07 from the live project)

Source for all 15 deployed functions is in this folder. Deployed settings that the code alone does not show:

- verify_jwt = true for every function EXCEPT `calendar-feed` (verify_jwt = false: calendar apps cannot send headers; its secret token in the URL is the auth).
- `manage-caregivers` (2026-11-11): verify_jwt = true; cancels unused caregiver invites and removes caregivers (primary caregiver only), emailing the person through Resend (`RESEND_API_KEY`).
- Secrets the functions read from the environment (create these in Supabase > Edge Functions > Secrets; never commit values):
  - `ANTHROPIC_API_KEY` (used by `scan-lesson`)
  - `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_DB_URL` are provided automatically by Supabase.
- Storage buckets the functions and policies expect: `recordings` and `scores` (private).
- `scan-diag` is retired (does nothing) and `storage-diag` is a diagnostic; both can be skipped on a rebuild.
- `fan-share` (2026-11-15, NoteStar): verify_jwt = true; sends a weekly album to a kid's Superfans (Resend when `RESEND_API_KEY` is set, otherwise returns links for the app's mail fallback).
- `fan-page` (2026-11-15, NoteStar): verify_jwt = false; the album link's secret token is the key. Shows the album and accepts fan mail (pending until a grown-up approves unless review is off).
