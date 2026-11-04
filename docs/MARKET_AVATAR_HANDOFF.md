# Musical avatar placeholders — 2026-11-04

Founder requested a cute music-related name for the supplied jalapeño and strawberry characters and their inclusion as placeholders in the earned-coin avatar market. The implementation names are **Pepper Presto** and **Berry Bebop**, open to founder review. The artwork remains temporary, intended to be replaced with similar final characters later.

## Local implementation
- Copied Desktop/Jalepeno.png and Desktop/strawberry.png unchanged into assets/art/avatar_jalapeno.png and avatar_strawberry.png; source and installed SHA-256 match.
- Stable avatar keys: jalapeno and strawberry. Existing strawberry ownership, purchase history, server row ID, and price are preserved.
- Featured illustrated cards in the existing JamJot stand, matching each profile theme; confirmation dialog and Shelf also use the actual images. Child Home now passes the worn avatar key to its profile button, so it displays the purchased character. Profile picker already used that renderer.
- Berry Bebop retains the current strawberry price of 25 coins. Pepper starts at 25 coins as a matching local review price, not a separately founder-approved economy decision.
- Owned avatars show Wearing or Wear it instead of encouraging another purchase. Server purchase/ownership authorization is retained; no coin accounting was moved into the production client.
- The original SVG strawberry and all earlier artwork remain available. Supplied PNGs are explicitly classified as placeholders, separate from finalPngArt.

## Review and release state
Main local app: http://localhost:8787/
Full fictional purchase preview: http://localhost:8787/market-preview/

The preview uses the real MarketScreen and a MockClient with 75 fictional starting coins; all purchases are isolated, reset on reload, and never contact Supabase. Child/grown-up theme and Home controls are provided for review.

Production catalog data was only read. The main app on loopback hosts displays missing new avatars as Coming soon, with no purchase action or usable server ID. Berry Bebop uses the existing strawberry row. Outside loopback hosts, no missing catalog entries are injected. Once the catalog is published, the real server row and server price are used automatically.

New unapplied migration: supabase/migrations/20261104184636_musical_avatar_placeholders.sql. It renames the existing JamJot strawberry listing without replacing it, adds Pepper if absent, preserves existing availability/prices, and is repeat-safe. It does not change access policies or student data. Normal purchasing still requires the earlier unpublished purchase_market_item / wear_owned_avatar release. Follow the prior coordinated backend-first release plan only after explicit founder authorization. Do not blanket push the incomplete local migration history.

## Verification
- 11 Flutter checks pass: seven avatar/catalog/layout/purchase/profile tests plus four child Practice regressions. Includes 375px/2x text, cancellation, insufficient coins, purchase failure, wear/re-wear, and preservation of authoritative IDs/prices.
- 14 synthetic Postgres scenario groups pass, including the actual new catalog migration plus existing purchase/wear functions: migration re-run, retained strawberry ownership and inactive state, Pepper charged once at 25 coins, wearing either avatar, and duplicate/unauthorized/insufficient-funds denials.
- Dart analysis: no errors; same 19 existing warning/info findings.
- Main and fictional market web builds pass. Main served JavaScript and both PNGs match current build bytes.
- Chrome visual check: both themes at desktop width, both cards at 375px, and fictional purchase from 75 to 50 coins with Shelf/profile update. Desktop viewport restored. Transient Flutter focus/layout errors were logged during initial automation focus/viewport transitions; the pages rendered normally afterward and no new errors appeared in the settled final check. Physical device/screen-reader verification is not claimed.
- The earlier full-suite theme smoke failure remains documented; the full suite is not claimed passing.

## Files and preservation
Changed existing files: app/lib/screens/market/market_screen.dart, app/lib/widgets/letter_avatar.dart, app/lib/screens/home/home_screen.dart, supabase/tests/practice-integrity.test.mjs.
New: app/lib/models/market_avatars.dart, the two PNGs, app/test/market_avatar_test.dart, app/tool/market_fixture.dart, app/tool/market_preview.dart, catalog migration, this handoff and validation evidence.
185-file pre-change checkpoint retained in the Codex mirror outputs/market-avatar-checkpoint. No prior files removed; all unrelated local changes, themes, backup/calendar/Practice fixes, and original mascot/logo preserved. No commits, pushes, deployments, real purchases, or production data changes.


## Gracie Grace Note addition — 2026-11-04

Founder extended JJ-014: “Name and add this grape(s) avatar and add her to the marketplace, too.” The implementation name is **Gracie Grace Note**, description **A whole bunch of harmony.**, open to founder review. Desktop/grapes.png is installed unchanged as app/assets/art/avatar_grape.png. SHA-256 of both source and installed image: 69d7433d222b1253db505627f2bb34e9a1cfa20b077dda60c50df8f3278bff7f. Artwork remains a placeholder. Existing grape key, server ID, 25-coin price and prior ownership are retained; the original SVG remains available.

The featured grid supports three columns on wide screens and one on narrow screens. Gracie uses the same market, confirmation, Shelf and profile rendering as the first two characters. The existing unapplied musical-avatar catalog migration now includes the grape title/description update and an insert-if-missing fallback. It preserves existing prices, IDs, active state and ownership. No production migration was applied.

Changed existing files for this addition: app/lib/models/market_avatars.dart; app/lib/widgets/letter_avatar.dart; app/lib/screens/market/market_screen.dart; app/tool/market_fixture.dart; app/test/market_avatar_test.dart; supabase/migrations/20261104184636_musical_avatar_placeholders.sql; supabase/tests/practice-integrity.test.mjs. New artwork: app/assets/art/avatar_grape.png. Documentation/evidence updated here and in docs/validation/grape-avatar.

Verification: all seven updated avatar Flutter tests pass, including all three purchases, re-wear without spending, failures, cancellation, 375px/2x text and grape Home profile artwork. All 14 synthetic Postgres scenario groups pass; the added grape fixture preserves a pre-existing 37-coin price and ownership after repeated catalog migration, and wearing it succeeds. Analysis has no errors and the same 19 existing warning/info findings. Main and market-preview web builds pass; both served JavaScript files and grape PNGs match the builds. Existing CupertinoIcons font warning remains. The full Flutter suite was not rerun; the historical theme smoke limitation remains.

Chrome visual verification: three supplied characters display in the child market. A fictional Gracie purchase changes the balance from 75 to 50, adds Gracie to the Shelf and shows Wearing with her picture in the profile control. Screenshot evidence is in this validation folder. No real purchases occurred. Real purchases still depend on the previously documented unpublished purchase/wear backend. Nothing was committed, pushed, deployed or changed in production.

Build recovery: macOS had offloaded project artwork and Flutter SDK files to iCloud-only storage, causing failed/stalled verification attempts. The required cloud files were downloaded through macOS without changing cloud settings; 25 asset files were restored byte-for-byte from the pre-change checkpoint. Final tests/builds passed after recovery. The 199-file pre-change checkpoint comparison found only the seven intended source/test/migration changes and no removed files or unrelated changes, before this documentation addendum. Source artwork checksum verified after download. Native topic filing and independent Drive image preservation remain pending.


## Lenny Legato addition — 2026-11-04

Founder extends JJ-014: “Name this lemon avatar and do the same as the other characters you've added.” The implementation name is **Lenny Legato**, description **A little zest. A smooth melody.**, open to founder review. Desktop/lemon.png is copied unchanged to app/assets/art/avatar_lemon.png as placeholder art. Source/installed SHA-256: `86d5f14f374a5a78de701a13f52366391378c4bc28d0456e1d922bd2e76b8e6f`. The existing lemon identity, prior ownership and server-controlled price remain. New missing catalog entries and the fictional preview use 25 coins.

The shared avatar renderer uses the new image in Market, purchase confirmation, Shelf and profile. The responsive market grid now permits four columns when width allows; it still stacks at narrow widths. Existing Pepper Presto, Berry Bebop, Gracie Grace Note, coin-pot feedback, themes, calendar, backup and Practice work are preserved.

Existing files changed: app/lib/models/market_avatars.dart; app/lib/widgets/letter_avatar.dart; app/lib/screens/market/market_screen.dart; app/tool/market_fixture.dart; app/test/market_avatar_test.dart; supabase/migrations/20261104184636_musical_avatar_placeholders.sql; supabase/tests/practice-integrity.test.mjs. New art: app/assets/art/avatar_lemon.png. The existing unapplied catalog migration now updates lemon's display text and inserts only if absent; no existing row, availability, price or ownership is replaced. Nothing was applied to production.

Verification: 13 focused Flutter checks pass (7 avatar/catalog/layout/purchase/profile checks and 6 coin-reward checks). Includes all four purchases, re-wear without spending, cancellation/failure/insufficient balance, 375px/2× text and Lenny on Home. All 14 synthetic Postgres groups pass; an existing owned lemon with a nondefault 43-coin price retains its ID, price and ownership across repeated catalog migration, and can still be worn. Targeted analysis has no new findings: only the pre-existing unused teacherId warning in Market remains. The historical full-suite theme-smoke limitation remains separate; the full suite was not rerun.

Main and fictional market web builds pass; served JavaScript and lemon PNGs match both builds. Original SDK package roots and all five preview links were restored. Chrome verified the four supplied characters and a fictional Lenny purchase, including balance 75→50, Shelf entry, Wearing state and the lemon profile image. Evidence: docs/validation/lemon-avatar/. Existing transient Chrome startup RenderBox and missing-font diagnostics remain; settled Lenny rendering and purchase interactions passed. Review http://localhost:8787/market-preview/.

Original Desktop image was hydrated from its existing iCloud location and left unmodified. Cloud-only Flutter analysis tools were also made available locally after the first analysis process exited; analysis then completed. A further 62 existing source/artwork/web files were hydrated for the rebuild. The first market-preview build then timed out reading its old cloud-only JavaScript cache; 202 cached build files were requested locally before retrying. No app file was restored or replaced from an old checkpoint during this task. The temporary build helper now hydrates cloud-only Dart runtimes immediately before running because macOS offloaded one again between steps. No cloud/security settings were changed. The 13-file checkpoint comparison found exactly seven intended source/test/migration changes, none missing; inspected coin-pot and main-app files were untouched by this task.

No commit, push, deployment, real purchase or production-data change. Real purchase/wear still depends on the previously documented unpublished backend release. Native topic filing and independent private Drive preservation of the newer source images remain pending; local originals and checkpoints are retained.
