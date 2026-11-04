# Calendar update — local review, November 4, 2026

The founder approved quote #1 and a magnifying-glass Maestro placeholder, then authorized all calendar changes. The founder subsequently supplied “Looking? toast.png” and explicitly requested it replace the generated calendar image. The supplied PNG is now installed byte-for-byte as the calendar placeholder; the prior generated version is retained in the local checkpoint. The original JJ and Maestro assets remain unchanged. Nothing was committed, pushed, deployed, or written to production data.

## Review
Main existing app: http://localhost:8787 → Calendar.
Fictional review page: http://localhost:8787/calendar-preview/.
Use Caregiver / Teacher / Studio / Student, the four calendar views, Empty calendar, and Load error. This page uses mocked HTTP; write requests are rejected. Teacher/studio fictional examples exclude family-only events; Student shows only Melody. Event detail cards are read-only in the fictional page. Normal app scheduling, printable lesson links, change requests, cancellation, restore and removal retain their existing behavior and authorization.

## What changed
- Day: full weekday and date, the profile's typography/colors, a subtle Today treatment, current-day default and date navigation.
- Week: Sunday–Saturday, all seven dated days present even when empty. Wide displays use seven columns; narrow/large-text layouts stack all seven day sections. Today is subtly tinted and explicitly labeled.
- Month: a bordered Sunday-first calendar grid. Every loaded event/assigned lesson appears in its proper day with readable wrapping labels/time. Busy rows expand instead of dropping events. Event taps open details; date taps open Day. Narrow screens scroll the calendar horizontally to preserve readable text (112px minimum day width, larger with text scaling). Adjacent-month dates are muted. Today has a subtle fill/outline and text label.
- All: all accessible entries sorted by local date/time, date headings include year; untimed practice lessons are first on their assigned date. When empty, show the approved placeholder and exact quote: “I’ve searched every measure… no jams on the calendar yet!” Supporting text: “When you, your teacher, or your studio adds an event, it’ll show up here.”
- The existing two profile themes supply fonts, colors, card shapes/fills and typography. The calendar does not create a new palette or font system.
- Removed the old 62-day / 14-day lookback cutoffs and 500-event / 200-lesson truncation. Fetches use ordered 500-row pages under the existing Supabase RLS policies. No role permissions or backend schema were changed.
- Local civil-day arithmetic handles Sunday boundaries, month/year transitions and daylight-saving changes. Overnight events appear on each occupied date, with midnight end exclusive. All lists a spanning event once, on its starting date. Assigned lessons linked to an event are not duplicated.
- Loading and errors have separate states; failures do not show the empty-calendar joke. Retry is available. Today refreshes on day rollover/resume. Successful provider refreshes retain the selected view.

## Changed files
Existing: app/lib/screens/calendar/calendar_screen.dart.
Added: app/lib/models/calendar_entry.dart; app/lib/widgets/calendar_views.dart; app/assets/mascot/maestro_calendar_search.png; app/test/calendar_test.dart; app/test/calendar_screen_test.dart; app/tool/calendar_preview.dart; this handoff and docs/validation/calendar/*.
The approved image is copied as a sibling asset; app/assets/mascot/maestro.png and jj_logo.png are untouched. Calendar preview is a separate local entrypoint, not the production main entrypoint. Both local preview symlinks are restored after main builds.

## Verification
20 focused tests PASS: 15 calendar/model/screen cases plus all five backup regression tests. Coverage includes Sunday and year/leap/DST boundaries, chronological ordering and local-time conversion, child filtering, no duplicate linked lessons, overnight/exclusive-midnight dates, pagination beyond previous limits, all seven daily panels, month placement and detail opening, previous/next month, approved empty state, loading/error/retry, dense nine-event dates, 375px with 1x/2x text, 844px and desktop layouts, and actual event-card controls at double text size.
Flutter analysis: the same 19 baseline warnings/info; no errors or new findings. Main and fictional calendar web builds PASS. The pre-existing Cupertino icon-font warning remains. The known old-theme full-suite smoke-test failure from the previous backup task was not changed or rerun; this report does not claim the entire project suite is green.
Chrome review at desktop and 375×812: chronological All; Sunday–Saturday week including empty days; populated month and detail sheet; horizontal phone month navigation through Saturday; student filtering and theme; approved empty state. Additional final screenshots are stored with this checkpoint. Existing design detector reports [] for the Dart targets, which is not evidence of native accessibility conformance; Flutter widget/visual checks provide the relevant evidence. No physical-device or screen-reader certification is claimed.
Preservation: 180 pre-existing source/reference files compared to the pre-calendar checkpoint. Only calendar_screen.dart changed; no prior files missing. Backup, practice code, themes and original artwork remained byte-identical.

## Remaining scope
This is a local review build. Existing server policies remain responsible for actual account/family permissions; no new production events were created to test it. No Supabase migration or Edge Function is needed for this display change. The previously documented backup/practice backend publication gaps remain separate. Maestro remains placeholder artwork pending a future artist-created asset. Native topic filing and older historical archive gaps remain pending; no source chats were deleted.

## Calendar image replacement — November 4, 2026
The founder-supplied /Users/erikatorkelson/Desktop/Looking? toast.png replaces only app/assets/mascot/maestro_calendar_search.png. The 2000×2000 transparent PNG is copied without alteration; SHA-256 matches the supplied original. Quote, calendar layout and original general-purpose Maestro/JJ assets are unchanged. The replacement retains placeholder status. Main and fictional calendar previews are rebuilt locally; no publication.
