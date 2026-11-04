# Coin pot and earned-coin feedback

2026-11-04 · CODEX-01a1a793-20261104-COIN-POT · JJ-015

## Result and review

Implemented in the existing `/Users/erikatorkelson/Documents/JamJot` checkout. The purse is replaced by the founder's black coin pot, with the three detached coins removed from the resting illustration. Positive confirmed child-balance changes show individual coins falling into a pot and play a short metallic clink/jingle. Individual supplied coin artwork appears alongside prices and earned amounts. Tap a balance pot to open a persistent device-level Coin sounds switch. Reduced-motion users receive the still pot and reward amount.

Main local app: http://localhost:8787/

Fictional review: http://localhost:8787/market-preview/ — click **Earn 5 coins**. This button exists only in the preview and changes its in-memory fictional balance. Reload resets that balance. Sound is enabled at the end of browser verification. No real purchase or reward was made.

No commit, push, deployment, database migration, production-data change, desktop shortcut creation, security-setting change, or publication was performed. Existing Claude work, themes, original purple JJ logo, Maestro artwork, backup/calendar/Practice changes, and all three musical avatars remain.

## Behavior

- A single reward observer above the router compares successful balance readings for the active child. Initial load, navigation, spending, repeated readings, errors/retries, and switching profiles do not replay rewards. Rapid gains merge their displayed amount and restart the visual sequence.
- Feedback lasts four seconds, is dismissible, and announces the actual earned amount. Six representative coins fall during a 1.5-second sequence; the illustrated pile stays still afterward.
- Browser audio uses the bundled local WAV and is prepared by a normal pointer/key interaction. Muted, suspended, unavailable, or late audio fails quietly without blocking reward credit or replaying it unexpectedly later. No external sound service is used.
- Remote credits are checked every 45 seconds while the child view is active/visible and upon resume. Existing immediate balance invalidations handle local practice/manual-entry rewards. The observer never grants coins.
- Extra practice now refreshes the confirmed coin balance and includes returned extra-practice coins in the displayed earned total. Server accounting, prices and ownership are unchanged.

## Artwork and audio provenance

Original Desktop source files were left untouched. Checkpoint copies and SHA-256 records are preserved.

- Resting pot: `app/assets/art/coin_pot.png`, transparent 1280×1280 edit of Desktop/Coin pot.png. Both handle holes are transparent; no airborne coins remain.
- Individual coin: `app/assets/art/jam_coin.png`, byte-for-byte copy of Desktop/Coinsss.png, SHA-256 `ce2366220d2962e836413a6d1199d7865179df6393650a8db91d926bd1030875`. Widget layout crops only its transparent padding; source bytes are unmodified.
- Jingle: `app/assets/audio/coin_drop.wav`, original procedural synthesis, 1.95 seconds, mono 16-bit PCM at 44.1 kHz. Six staggered clink clusters with secondary impacts; no third-party sample.
- Pot generation mode: image edit, `transparent_background: true`, referenced local source `/Users/erikatorkelson/Desktop/Coin pot.png`. Generated source `/Users/erikatorkelson/.codex/generated_images/01a1a793-f14c-7e42-83bf-03f7f2289559/exec-54eb143b-e498-4184-acfe-cb3a8559bcb3.png`.

Exact edit prompt:

> Use case: precise-object-edit. Edit target: supplied image Coin pot.png. Create the resting-state asset for JamJot: remove ONLY the three separate floating gold coins above the pile, leaving the black pot, both handles, and the complete pile of musical-note gold coins in the pot. Preserve the exact pot shape, original black/gold materials, lighting, and the musical-note engravings as closely as possible. Remove the pale background to true transparency, including the holes inside both handles. Center the remaining pot and coin pile, with a tight but safe crop and a small transparent margin; the resting pot fills the image, with no large empty area above it. No coins in midair, no falling coins, no text, no added decorations or shadow outside the object. This is a faithful cutout/edit of the provided art, not a redesign.

## Files

Existing app files changed:

- `lib/main.dart`
- `lib/screens/home/home_screen.dart`
- `lib/screens/family/kid_detail_screen.dart`
- `lib/screens/history/practice_history_screen.dart`
- `lib/screens/market/market_screen.dart`
- `lib/screens/practice/practice_session_screen.dart`
- `lib/services/sound_effects_stub.dart`
- `lib/widgets/coin_pouch.dart` (filename retained; now defines CoinPot, FallingCoinPot, JamCoin and CoinLabel)
- `lib/widgets/log_practice.dart`
- `web/index.html`
- `test/market_avatar_test.dart`
- `tool/market_preview.dart`
- `pubspec.yaml`

New app files: `lib/state/coin_rewards.dart`, `lib/widgets/coin_reward_host.dart`, `assets/art/coin_pot.png`, `assets/art/jam_coin.png`, `assets/audio/coin_drop.wav`, `web/coin_drop.js`, `test/coin_reward_test.dart`, `tool/coin_sound_test.mjs`.

This handoff and `docs/validation/coin-pot/` contain documentation/evidence. Old purse artwork remains available but is no longer used by the coin components.

## Verification

- 17 focused Flutter tests pass: 6 coin-reward checks, 7 avatar-market checks, and 4 Practice checks. Coverage includes first load/spending/navigation/profile changes, retry, rapid rewards, persisted mute, reduced motion, 375px/2× text, purchases and Practice compatibility.
- Four Node audio checks pass: WAV format/duration/clipping, local cached playback/overlap prevention, suspended browser behavior, and missing audio handling.
- Full analysis found no errors, the 19 existing warnings/info findings, and one new style lint. That style lint was fixed; the targeted coin-component analysis then reported no issues.
- Main and fictional market web builds pass. Existing CupertinoIcons font warning remains.
- Served JavaScript, coin script, both PNGs and WAV match rebuilt files at both local URLs (10 successful hash comparisons).
- Chrome verified the resting illustration, fictional 75→80 earnings with +5 banner and falling coins, and browser audio-start logging. Muting produced 80→85 plus visual feedback without another audio-start log. Sound was restored to enabled.
- Saved screenshot `coin-pot-earned.jpg` captures coins falling into the pot; `coin-pot-preview.jpg` shows the resting pot.
- Before documentation, the 148-file source checkpoint comparison found precisely 13 intended existing-file changes and no missing files.

## Limits and existing release dependencies

This is locally implemented and reviewable, not a production release. Real practice settlement/manual-entry/purchase/wear/export flows still depend on the previously documented unpublished backend work. No backend change was made for this coin presentation task. Do not imply full production end-to-end reward verification.

Physical native-device audio and actual speaker output were not recorded; the browser confirmed the audio source started. The native implementation uses the same WAV through the existing audio library. The full historical test suite was not rerun; its earlier theme-smoke limitation remains separate. Chrome logged the previously observed startup RenderBox and missing-font diagnostics; settled rendering and the tested coin interactions worked.

macOS cloud-only source/SDK files interrupted initial tools. Required files were hydrated, and 80 unchanged app files were restored byte-for-byte from the pre-change checkpoint after matching original metadata. Exact SDK/tool copies under `/private/tmp` allowed tests/builds to finish. Temporary package-root substitutions were restored after each run, and all five pre-existing preview symlinks are intact. No cloud or security settings were changed. See `restored-cloud-only-files.json` and `served-build-check.json`.

Shared project records have the JJ-015 requirement and this implementation receipt. Earlier decision IDs, including the separate starter-avatar entry, were preserved. Native topic filing and independent private Drive copies of newer source images remain pending; local originals/checkpoints are retained.
