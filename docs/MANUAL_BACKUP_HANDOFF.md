# Free manual backup — local handoff, 2026-11-04

## State
Implemented in the existing Mac working tree. Not committed, pushed, migrated, or deployed. Production data was not changed. Root local preview: http://localhost:8787. Fictional review page: http://localhost:8787/backup-preview/ (adult PIN 1234). The fictional page uses mock HTTP, not real accounts; its sample ZIP has synthetic student/lesson/practice/reward/message records, a PCM WAV recording and a MusicXML score.

## Behavior
Adult Settings → Your data → Download my data. Caregiver, teacher and studio-owner scope is derived server-side. Child mode hides both export and reminders. Real export requires the current sign-in password as well as a valid bearer session; the profile PIN is not server authorization. No password or private export is logged or persisted by this feature.

Prepare creates a complete ZIP in memory; Save ZIP asks the device/browser to save it. Only the explicit “I saved the ZIP” confirmation changes the local reminder date. Preparation, cancellation, failure and reminder dismissal never count as a successful backup. Reminder design is PROPOSED: off by default; 7/30/90-day choices; account/device-local; dismiss snoozes one day; main profile-selection entry retains the adult PIN gate.

Readable JSON and CSV tables cover account/student/instrument details, linked lessons, assignments, goals, practices (including manual/corrected durations), song practices, reward ledgers and purchases, owned saved templates, authorized messages/private notes, and score metadata. Actual authorized recording/document bytes are stored under files/. README and manifest v1 include stable record IDs, row hashes, available record timestamps, export timestamp, per-file size/hash and clear snapshot semantics. A repeated export writes no records or rewards. Edited/deleted/revoked records affect the next snapshot only; absence must not be treated as proof of deletion by a future restore tool. Restoration is not implemented.

## Authorization and limits
- SQL is STABLE/read-only, SECURITY INVOKER, service_role EXECUTE only; anonymous/authenticated direct calls are denied. Endpoint derives p_user only from verified Auth.
- Caregivers: linked students. Teachers/studio owners: active enrollment scope. There is no separate studio-admin membership table in the current schema; studio-owner role is the supported administrator mapping.
- Messages require the teacher relation or primary/can_message guardian permission. Studio ownership alone never grants messages. Private notes are author-only. Secret/PIN/token fields are excluded explicitly.
- Current storage policies allow downloading score files only for their owner. Assigned shared scores without that permission are metadata-only and listed in the manifest. The export does not use a service key to bypass that restriction.
- Exact file references are validated to the authorized student or account path. Invalid, unavailable, empty or oversized required files fail the whole export; no partial ZIP is returned.
- Current in-memory implementation is capped at 64 MiB uncompressed total and 2,000 media files. Larger accounts need a separately implemented streaming/background export before this can be a universal production backup feature.
- A second snapshot comparison aborts if records or permissions change while downloading. Storage bytes are not versioned; overwrites during an export cannot be made transactionally atomic with database records.
- Calendar/billing/internal security audit tables are outside this initial export scope. Existing malformed audio is preserved as bytes, not repaired. MFA/SSO-only account verification has not been implemented/tested; current password verification is for password accounts.

## Files changed by this task
Existing integration points only:
- app/lib/screens/profile/my_profile_screen.dart
- app/lib/screens/profile/profile_picker_screen.dart
New feature files:
- app/lib/services/backup_service.dart
- app/lib/services/backup_file.dart
- app/lib/services/backup_file_web.dart
- app/lib/services/backup_file_native.dart
- app/lib/widgets/backup_settings.dart
- app/test/backup_test.dart
- app/tool/backup_preview.dart
- app/tool/backup_fixture.dart
- supabase/migrations/20261104172909_manual_data_backup.sql
- supabase/functions/export-data/archive.ts
- supabase/functions/export-data/handler.ts
- supabase/functions/export-data/index.ts
- supabase/functions/export-data/archive_test.ts
- supabase/tests/backup-schema-fixture.sql
- supabase/tests/manual-backup.test.mjs
- docs/MANUAL_BACKUP_HANDOFF.md and docs/validation/manual-backup/*

## Validation
- Five focused Flutter tests PASS, including hidden child/unauthorized controls, 375px layout with 2x text, reminder isolation/boundaries, cancel/failure handling, explicit confirmation and dismiss semantics.
- Three Deno archive/HTTP groups PASS: complete archive and exact real-format bytes, stable repeat identities, invalid/missing/changed scope and authentication denial paths.
- PGlite backup authorization/integrity suite PASS: fictional two-family isolation, teacher/studio/guardian/child/stranger scopes, messages and secret exclusions, service-only invocation, stable IDs, edits/deletes/revoked enrollment and unchanged source-data checksum.
- Existing practice-integrity suite: 13 scenario groups PASS.
- Independent Python ZIP CRC and WAV/MusicXML decode PASS: 44 entries, 11,025 PCM audio frames at 22,050 Hz, valid score-partwise XML. Manifest SHA checks are also covered by the Deno suite.
- Flutter analysis: 19 pre-existing warnings/info, no new findings and no errors.
- Main Flutter web build PASS. Existing Cupertino icon-font warning remains.
- Earlier complete Flutter suite: 11 pass, 1 existing theme smoke test fails because it expects the old cream palette; Google Fonts fetch errors also appear in that offline test. The approved theme was preserved. This is not a claim that the full suite is green.
- Existing source checkpoint compared 162 files: only the two intended profile integration screens changed; no old files missing. Original JJ, Maestro, themes, existing practice code, dependencies, functions and migrations stayed byte-identical to the start-of-task snapshot.

## Review and remaining verification
Open the fictional preview, choose Download my data → Save ZIP, open the ZIP and its README/audio, then confirm only if actually saved. Choose a reminder interval, then Account selection to inspect the reminder; Check child mode demonstrates that controls disappear. All data in this review page is fictional.
The browser UI reached Save ZIP and explicit confirmation; automated browser download completion was not independently confirmed. Native iOS/Android/macOS save dialogs and production-auth/storage runtime are unverified. Local SQL/HTTP/ZIP tests use synthetic accounts and injected services; these are not hosted Edge runtime tests.
No backend release is authorized. Before any future release, reconcile the incomplete migration history (local 0001/0002 plus unpublished practice-integrity vs the 27 remote migrations), review/grant the new RPC deliberately, deploy the matching Edge Function, test real nonproduction Auth and storage, then coordinate frontend publication only after explicit founder approval. Never blanket push/reset this local migration folder. Existing correct-practice/discard-recording backend gaps remain separate.

## Calendar next
Founder explicitly said finish backup work first. Calendar requirements captured, but no calendar code changed. First workshop the empty-calendar Maestro Marmelade quote and show a magnifying-glass illustration for review; then implement Day/Week/Month/All across profiles. Week is Sun–Sat including empty days; Month uses day boxes; today is subtly highlighted; events chronological; typography/colors inherit the relevant approved profile theme.
