# JamJot: changes made after this Mac copy (Nov 5, 2026, ~4:18 PM CT)

Written Nov 7, 2026 while GitHub (etorkelson44) is suspended. This Mac folder is the
newest code we can reach. If GitHub is reinstated, the real repo replaces all of this.

Note: this folder lives in iCloud with "Optimize Mac Storage", so many files are
cloud-only. Right-click the JamJot folder in Finder and choose "Download Now"
(or "Keep Downloaded") before backing it up or building from it.

## Front-end changes pushed to GitHub only (not in this folder)

| Change | Decision | Commits | Needs to rebuild |
|---|---|---|---|
| Delete 169 retired accessory art files (acc_*.png) | JJ-022-C | a6559d6 | Delete same files; remove stale acc_mustache listing |
| Smart Ears: on-device YAMNet sound classifier, web/smart/, "Smart ears" toggle | JJ-023-C | 41ae990, 675e5d2, 61cb338 | YAMNet TF.js bundle + classifier logic (hard) |
| Book + page fields in assignment forms, practice cards, scanner auto-fill | JJ-024-C | 583e457, 96a6a8c | Front-end fields; backend already live |
| Written assignments: 3 types, page uploads, caregiver-PIN confirm | JJ-025-C | 651dcc3, 5256a34, 8f0b4f8 | Front-end flows; backend already live |
| Auto-file lessons into library, merged search, Re-assign button | JJ-026-C | 92430dd, 785e1de, ebea6db | Front-end; backfill already done |
| Flexible goals, weekly setlist stars + bonus, lesson-day nudge | JJ-027-C | ebe504f | Front-end; backend already live |
| Keywi (kiwi) freebie with piano scene | JJ-030-C | a67f3de | Founder's layered kiwi art + 48-frame music WebP |
| Jam Jar art, coin flight animation, retro coin sound | JJ-030-C | 389cf25 | Jar art, Pixabay "Retro coin 4" sound |
| Per-student sound preferences (students.sound_prefs) | (none filed) | unknown | Front-end use of sound_prefs |

Unknown smaller fixes may exist; check HANDOFF / chat records before rebuilding.

## Backend: safe in Supabase (project cedlqxhrqwqwkohioiqb)

Supabase keeps exact copies, independent of GitHub. Migrations newer than this folder:

| Version | Name | md5 of SQL |
|---|---|---|
| 20261105003714 | uniform_avatar_pricing | a1ba6c0e7e195b465aca50bb429609f5 |
| 20261105161432 | tour2_interim_reset | f7fc2c95fc669e73e2487bed3743fb6f |
| 20261106022807 | assignments_book_and_pages | 0af36e34b57092196c1ad446d768121d |
| 20261106031923 | written_assignments_columns_and_rpcs | 2cf6d98567490bbf08ea3d7c0247cf9b |
| 20261106033018 | written_only_confirmation_bonus | b5d261bee8f730dbdb80187e6431f071 |
| 20261106033157 | verify_written_settles_v2 | 5fe07318f7b562542050408ba712a201 |
| 20261106041327 | full_setlist_weekly_bonus | 5dc270dc308b14e2ca93956b1981bcb3 |
| 20261106195433 | student_sound_prefs | f33b77c424ee180a2e7f56730c52ed45 |

Edge function changed after this copy: scan-lesson (version 10, Nov 5 ~9:20 PM CT).
Export exact copies with the Supabase CLI ("supabase migration fetch",
"supabase functions download scan-lesson") rather than retyping.
