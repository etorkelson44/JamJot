# JamJot practice reliability implementation

Prepared November 3, 2026. Branch: `fix/practice-reliability`, based on `f4b20c3`.
Changes are local. Nothing has been merged, published, or applied to production.
The separate Desktop **JamJot Studio.app** was moved to the Mac's Trash at Erika's
request. The JamJot Safari app, Flutter checkout, and backend were preserved.

## What changed and why

### Recording and finishing practice

- Meter the same microphone input used by `record`, eliminating the app's second
  microphone stream and the native fallback that counted silence as practice.
- Use a -40 dBFS gate and a monotonic clock, limiting the credit from any one
  delayed sample to 500 ms. This is sound detection, not instrument recognition.
  Actual piano sensitivity still needs a physical-device check.
- Record mono WAV at 22,050 Hz. File names and upload content types now agree.
  The recorder package documents WAV support across Safari, Chromium, iOS and
  Android. Resume a suspended recorder before counting sound.
- Capture each take's song when recording starts; navigating cannot reassign it
  to a different song. Pause before leaving and ask to save before switching tabs.
  Stop recording on background/hidden lifecycle events and warn before closing
  a page with unsaved practice.
- Keep failed uploads in memory for retry, with stable object paths. Retain clips
  until their segment is stored. Use stable segment IDs for retrying saves.
  A failed save no longer produces the saved celebration.
- Hide embedded sheet-music platform views while a practice dialog is open, so
  an iframe cannot intercept the dialog's touches. Dialog content scrolls.
- A song needs **60 seconds** of sound for completion/rewards. Below that, a child
  can continue, keep progress and return to songs, or discard the latest take.
  Discarding preserves earlier takes and subtracts only the discarded take.
- At or above one minute, show the teacher's song goal (or its share of the daily
  goal), encourage more practice if short, and allow saving and moving on.
- Reopening an existing session no longer doubles its contribution to the daily
  progress display. Recorded practice never reopens a manual or overridden entry.
- The practice home scrolls as a whole. Header statistics wrap, keeping songs and
  controls reachable with large text on narrow phones.

### Playback

- Web history plays recordings inside an audio control rather than relying on a
  popup tab opened after an asynchronous signed-link request.
- Native history uses an audio player with play/pause, position and seeking.
- Closing a player releases its playback resources. Reopening refreshes its
  signed link. Older malformed or unsupported recordings cannot be repaired
  merely by changing their player; check the existing files separately.

### Practice corrections and authoritative minutes

- Adult history has controls to change credited minutes, restore original
  minutes, delete a complete practice, delete one song-practice segment, and
  delete an individual stamped recording.
- Authorized adults are a primary caregiver or caregiver with
  `can_adjust_practice`, an active teacher, or the owner of a linked active studio.
  Kid-mode controls stay hidden. The backend checks the authenticated account;
  active profiles within a shared adult login still rely on the existing PIN UX.
- Manual minute overrides replace recorded minutes for goals and rewards while
  keeping the recordings and original minutes. An overridden session is excluded
  from automatic recording resumption. A database trigger protects its credited
  minutes from direct writes by older clients.
- Each correction records an audit entry privately and settles the student's
  remaining practice rewards in the same database transaction.
- Removing a recording subtracts its stamped sound time, removing a song subtracts
  that segment, and removing a session removes its session-linked earnings.
  Old clips without time metadata require deleting their song practice instead.
- Storage deletion follows the committed correction. Failed file deletions are
  queued privately, retried during later correction/discard requests, and have a
  Retry deletion action in the correction notice. No cleanup schedule was added.

### Rewards and store decisions

- One transactional settlement serves recorded awards, manual entries and
  corrections. A per-student transaction lock also coordinates purchases.
- Keep original ledger rows and store a deterministic session balancing entry,
  so retries do not pay twice. Corrections can adjust later song fan escalations.
- Preserve the manual-entry reward formula: rounded coins per two minutes, with
  the existing fan limits. Preserve first-song coins and the +5/+10/+15 fan
  escalator, and bonus fans for eligible extra practice.
- Apply the one-minute minimum to both the client and server. Bonus fans are
  limited by remaining sound time, so deleting an original take cannot turn one
  remaining minute into both a first completion and an extra reward.
- Daily goal markers combine recorded and manual sessions. Goals use the highest
  current lesson requirement across the student's connections, rather than an
  unconditional 15 minutes. A daily automatic bonus is paid once, with the
  existing extra-minute cap. The prior server-clock cap is retained for
  automatic session minutes.
- **Previously bought rewards remain owned after a correction.** A negative coin
  balance is allowed and future earnings cover it. Nothing is silently clawed back.
- Purchase validation, balance deduction, purchase creation and avatar selection
  are one transaction. Request IDs make a retried purchase idempotent.
  Teachers and studio owners do not gain spending rights simply by seeing a child.
- Avatar ownership is checked when wearing an avatar. Buying/wearing updates the
  active child in place instead of clearing the active profile.
- Weekly fan totals include corrections and use the practice's date rather than
  treating a historical correction as new practice this week.
- The existing backend uses UTC day boundaries for reward escalation; these are
  preserved. The practice UI/report use viewer-local dates. A broader timezone
  model needs a separate coordinated migration and boundary tests before expansion.

### Printable sheets

- Load saved practice and song details along with the lesson. Manual entries
  contribute to the total, even when no song was specified; they are never
  invented as practice of a particular song.
- The lesson window starts on its `week_start` and spans seven local calendar
  days. Include finished practices only.
- A student without an assigned lesson gets a practice record for the week of
  their latest saved practice, instead of an empty/unprintable screen.
- The generated HTML prints all rows and page-breaks separate lesson blocks,
  independent of the Flutter viewport. Contents are escaped before insertion.
- Stamp the snapshot with the next local midnight or an earlier upcoming teacher
  cutoff. **A downloaded or paper PDF does not self-update or self-destruct.**
  This is a freshness deadline, not an implemented expiring download service.
- The existing teacher practice-cutoff policy is preserved. No scheduled lesson,
  teacher finalize time, or historical student practice was changed.
- Manual logging and corrections invalidate history, sheet and progress caches.
- The narrow-screen print action is a labelled/tooltip print icon in the app bar.
  Native PDF printing remains unsupported; this release's printable flow is web.

### Library and artwork

- Assign a lesson and all of its songs in one transaction per student. A failed
  song insert rolls back that student's assignment; retries reuse its request ID.
  Already-assigned students and the saved template are not duplicated on retry.
- Template edits still leave previously assigned lessons unchanged.
- Choose arrived lessons by effective week/date, then creation date, so a newly
  created backdated lesson does not displace a later effective lesson. Remove
  the small look-back caps that could hide a current lesson behind future plans.
- Preserve the existing transparent 512×512 blueberry PNG and shared artwork
  loader. No art was redrawn or replaced. Final approval against the original
  artist reference remains unverified.
- Bundle the existing Space Grotesk font and license locally, preserving the
  family while removing its runtime network dependency.
- Add an idempotent microphone-permission setup script for generated native
  platform folders. CI runs it, executes Flutter tests and backend contract tests,
  and pins Flutter 3.47.9. Dependency lockfiles are included.

## Evidence and limits

- Flutter 3.47.9 / Dart 3.13.7.
- Eight Flutter tests cover theme construction, lesson date boundaries, manual
  report rows, escaping, a long printed report, manual practice without a lesson,
  one-minute completion with goal encouragement, large-text stop choices, and a
  failed song save that must not celebrate. Some tests contain several assertions.
- Thirteen isolated Postgres scenario groups cover correction roles, manual logs,
  overrides/restoration, song/repeat awards, deletions/cleanup, purchase retries,
  insufficient funds, preserved purchases/negative balance, private audit access,
  assignment rollback, teacher/daily goals, 59/60 seconds and denied actions.
- The Postgres tests use PGlite and a synthetic schema contract, not live records.
  They do not prove hosted RLS parity, Storage behavior or races across independent
  network connections. Exercise those in a staging project before release.
- Six Edge Function entry points were type-checked. Impeccable's mechanical check
  returned no findings for the changed practice/history/sheet/market screens;
  that check does not replace native accessibility testing.
- A sample-data browser preview was used to inspect the practice screen, completion
  dialogs and manual practice on a lesson sheet. Its microphone is disabled and
  its backend is mocked. It is not a real recording/playback or production test.
  Browser access became unavailable before rechecking the final print-icon change;
  that last visual check remains outstanding, though the final web build passed.
- Physical piano detection, Safari/iOS audio interruptions, Android permissions,
  old recording decoding, real multi-page printer output, actual independent
  concurrent purchases/edits, and tablet layouts still require staging/device QA.
- Analyzer warnings in older unrelated code remain; consult the final validation
  receipt. No claim of a warning-free project is made.

## Coordinated release requirement

Production has 27 migrations through `20261102010521_calendar_feed_tokens`; this
checkout originally had only two old migrations. The new additive migration is
written against the inspected live columns. **Do not run a blanket database push
or rebuild production from this incomplete migration directory.**

1. Recover/reconcile the existing backend migration baseline, then test this
   additive migration against that schema in staging with synthetic data.
2. Review roles and the reward decisions above; test independent simultaneous
   purchase/correction/save requests and the hosted Storage cleanup paths.
3. Apply only the reviewed additive migration through the normal migration
   workflow; deploy its six matching Edge Functions. The legacy award, log and
   purchase endpoints must be replaced by the included adapters, so older clients
   share the new transaction logic.
4. Run a permission matrix and Supabase advisors after staging changes. Confirm
   helper grants, private tables and cleanup APIs are inaccessible to unrelated users.
5. Build and release the matching Flutter web app. The new client expects these
   RPCs and must not be published before the matching backend is ready.
6. Reconcile historical rewards only as an explicitly reviewed release operation:
   settlement now recomputes a student's existing sessions, so historical totals
   can change under the one-minute and teacher-goal rules.

No live schema, function, student row, reward or recording was changed by this work.
