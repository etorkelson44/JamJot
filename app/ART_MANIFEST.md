# JamJot Art Manifest

Every piece of art in the app is a named placeholder. To replace one, give
Claude (or drop into the repo) a file with the exact name below — no code
changes needed. Static art: PNG (transparent, large) or SVG. Animations:
Rive (.riv, preferred) or Lottie (.json).

| Slot | File | What it is | Size guide |
| --- | --- | --- | --- |
| Jar hero | assets/mascot/jar_hero.svg | Title-screen jar + note mascot (currently drawn in code) | square-ish, ~1024px |
| Mascot idle | assets/mascot/idle.riv | The note, blinking/bobbing on home | — |
| Mascot celebrate | assets/mascot/celebrate.riv | Cheering after a song | — |
| Mascot listening | assets/mascot/listening.riv | Gentle bounce during practice | — |
| Blueberry | assets/berries/blueberry.svg | The currency icon (plum circle + calyx) | 256px |
| Berry burst | assets/berries/burst.riv | +5 berries celebration | — |
| Jar fill | assets/berries/jar_fill.riv | Berries raining into jar, fill level driven by app | — |
| Berry picking | assets/berries/picking.riv | "Assignments still being picked" placeholder | — |
| Fan (default) | assets/market/fan_default.svg | Crowd member w/ sunglasses + name sign | 512px |
| Stage crowd | assets/backgrounds/stage_crowd.riv | Fan-earned screen crowd, waving | — |
| Market awning | assets/market/awning.svg | Scalloped market header | wide strip |
| Cosmetics | assets/market/<item_key>.png | One per JamJot Stand item | 512px |
| Cheer sound | assets/sounds/cheer.mp3 | Crowd cheering | 2–4 s |
| Berry plinks | assets/sounds/plink.mp3 | Berries dropping in jar | <1 s |

Colors to design against (the locked palette):
cream #FAF6EE · ink #26323E · blueberry #4A5FAE · marigold #FFBE2E ·
plum #6C4A91 · leaf-green stems #3E7C4A. Font: Space Grotesk.

## Jam Jar art (assets/art/jar/)
Purple/white-label jar with the stamped JJ coin on the right of the label. `closed.webp`, `open.webp`, `lid_seated.webp`, `lid_hover.webp` (tilted lid), `coin.webp` (mini stamped coin), `d0–d9.webp` + `jam.webp` (painted count lettering). The count is composed from the digit images (see `lib/widgets/jam_jar_art.dart`); a jar with no count shows JAM. The older `jar_closed/jar_open/jar_lid.png` are no longer used.

Sound: `assets/audio/coin_retro.mp3` — Pixabay "Retro coin 4" by Driken5482 (replaces coin_drop.wav); one blip per coin with rising pitch.
