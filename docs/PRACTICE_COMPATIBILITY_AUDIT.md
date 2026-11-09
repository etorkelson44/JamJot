# Child Practice startup and local integration audit — 2026-11-04

## Founder report and scope
The child Practice tab showed an error, and Home still showed the old music-note mascot after opening localhost:8787 from a desktop shortcut. The founder subsequently deleted the shortcut. No shortcut was recreated. Work remained in the existing Mac checkout; no commits, pushes, migrations, functions, live data, or deployed website were changed.

## Confirmed cause and local fixes
Read-only inspection of the live schema confirmed sessions.source exists but sessions.manual_override_seconds does not. The integrated Practice startup query required that missing field and therefore failed before displaying lessons. The integrity migration that adds it is still unpublished.

The new latestResumablePracticeSession reader selects existing session fields and checks the optional correction field in the returned data. This works before and after that migration. It keeps the child/source/local-day filters, skips corrected sessions (including a zero-minute correction), and reads additional ordered pages when necessary. Real errors still reach the existing retry screen. An unmounted screen no longer attempts a startup error update.

DancingNote (renamed DancingMaestro on 2026-11-09, when the Note mascot was retired) now defaults to the existing general-purpose assets/mascot/maestro.png. This updates child Home, Practice, and invitation screens while preserving their animation. The sign-in Maestro and loaders remain intact. The founder's magnifying-glass image stays on the calendar; its exact bytes and quote were preserved.

## Integration findings
| Area | Independently checked status |
| --- | --- |
| Jam Stand / Calm Studio | Both approved palettes, font families, shapes, and automatic profile switching are present. Theme source was unchanged by backup/calendar work and this fix. |
| Original JJ and Maestro artwork | Original assets present and unchanged. Nine loader placements remain. The earlier Claude record only claimed a sign-in mascot replacement; Home and Practice had retained the default note. |
| Child Home / Practice | Old mascot default and missing-column startup incompatibility fixed locally. Real Home -> AppShell -> PracticeScreen navigation verified in a fictional child browser preview and widget test. |
| Recording reliability, printable lesson sheet, playback | Integrated source remains present. Existing practice regression checks still pass. Physical microphone/audio/device QA is not claimed. |
| Corrections, recording deletion, reward settlement, manual practice, atomic purchases/avatar wearing, library assignment | New client/server source is present locally. New backend dependencies are still unpublished, so these must not be described as fully operational against production. |
| Backup and calendar | Prior implementation preserved, including JJ-013 supplied calendar PNG. Backup server release is pending. Calendar display needs no backend migration. |
| Release pipeline | Earlier handoff reported the CI workflow integration was not completed. This audit did not change it or authorize publication. |
| Venue renaming | Claude's archived record explicitly says proposed parody venue names were not implemented. No replacement names were invented here. |

The available Claude record reports a 47-file integration but contains no reproducible commit/tag manifest. This audit confirms the listed areas in the actual working tree; it does not certify every historical idea as implemented or every flow as tested.

## Backend release dependencies (read-only verified)
The live schema lacks manual_override_seconds and the new settlement/authorization/assignment/purchase/avatar RPCs queried in this audit. Existing Edge Functions were listed; correct-practice, discard-recording, and export-data are absent. The pending local migrations are 20261103200554_practice_integrity.sql and 20261104172909_manual_data_backup.sql. Follow the coordinated backend-first release procedure in PRACTICE_RELIABILITY_HANDOFF.md and MANUAL_BACKUP_HANDOFF.md only after explicit founder authorization. Do not blanket-push the incomplete local migration history.

Opening Practice is fixed; finishing recordings and granting new rewards are not verified against the live service and still require that release. No live records were created to test them.

## Verification
- Nine Practice tests passed, including reproduction of the former missing-column failure, old/new schema reads, zero-valued corrections, pagination, real error propagation, actual child Home/Practice tab navigation, song completion, large text, and failed-save behavior.
- Dart analysis: no errors; the same 19 pre-existing warnings/informational findings.
- Main web build and separate fictional child-navigation preview build passed. Existing Practice QA preview rebuilt from its original preserved source.
- localhost:8787 served main.dart.js and both Maestro PNGs with hashes identical to the current build.
- Chrome: Home showed the original Maestro; Practice tab opened schedule, goals, timer, and assigned song. Error console was empty. Preview rejects all writes and microphone access.
- The historical full-suite theme smoke test remains stale (expects the superseded single cream theme and attempts font network loading). The full suite was not rerun or claimed passing for this fix.

## Review and changed files
Main app: http://localhost:8787/
Fictional child flow: http://localhost:8787/practice-review/
The latter uses the real Home, PracticeScreen, and AppShell with an older-schema mock. It is not a production account or a complete app simulation.

Changed existing files:
- app/lib/screens/practice/practice_session_screen.dart
- app/lib/widgets/dancing_note.dart
- app/test/practice_session_test.dart
- app/test/support/practice_fixture.dart

New files:
- app/lib/services/practice_sessions.dart
- app/test/practice_sessions_test.dart
- app/tool/practice_route_preview.dart
- this audit and docs/validation/practice-compatibility evidence

A 175-file pre-change archive/hash checkpoint lives in the Codex project mirror at outputs/practice-route-audit. Only the four existing files above changed; original app/tool/practice_preview.dart was preserved byte-for-byte. Themes, calendar, backup, artwork, other practice work, and server functions were preserved.
