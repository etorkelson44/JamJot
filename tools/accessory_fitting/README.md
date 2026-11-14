# Accessory fitting tools

Working scripts used on 2026-11-13 to fit the Jazzy Joggers and Serenade Sandals to Keywi and to Señor Jalapresto's ten
poses. They are kept here so the method can be reused for other avatars and poses. They were written for a scratch
workspace: paths at the top of each file (`/home/claude/pp`, `/home/claude/kw`, `/home/claude/jamjot`) need pointing at
this folder, `sources/` and the repo before they run again.

## Method

**Pants (fit2.py `ribbon`, `joggers_two_legs`)**
- Erika's flat pants art is split at the crotch into two legs. Each leg is drawn as a ribbon along a centre line.
- The hips are one straight block (both centre lines vertical, a fixed distance apart) so the waistband and bow stay intact.
- Below the crotch each centre line runs to that leg's ankle. Cuffs stop a few pixels above the foot.
- Where the avatar's legs attach wider than the waistband, the joggers replace the legs layer with one trimmed above the
  cuffs (`trimmed_legs`), so no leg shows beside the pants.
- Crossed legs (fit.py, v3.py): the crossed leg's pant leg is drawn in front; the crossed foot is drawn again in front of
  the back pant leg (foot only, heel to toe).
- Where the body would show between the pant legs below the crotch, a plain fabric patch is merged under the pants (`gusset`).

**Sandals (fit2.py `sandal`, v3.py `kfit`)**
- Always Erika's layered Keywi sandal: sole, then foot, then straps.
- Mapped foot to foot: heel, toe and underside of the target foot are matched to Keywi's right foot, so the size ratio
  (sole about 1.3 x foot length) and position are the same on every avatar. Mirrored when the toes point the other way;
  rotated for a tiptoe foot.

**Pants over tall boots (boots.py `cuff_line`, `over_boots`; approved by Erika 2026-11-13 16:13 CT)**
- Pants stay full length and in front. A second version of each boot is made for when the pants are worn.
- Step 1, cut: the boot may show only directly under the flat bottom edge of that pant leg's cuff. Everywhere else
  (the rounded cuff corners, beside the pant leg, columns the pants do not reach) it is hidden down to the cuff's lowest
  point, so no boot shows beside the pants above their bottom edge.
- Step 2, grade: take the convex hull of what is left and keep the original boot inside it. This fills the notches the
  cut leaves, so the boot's edge runs in a straight slope from the cuff's bottom corner out to the curve of the boot.
- In the catalog the normal boot pieces get `unless_worn: [pants id]` and the graded ones `when_worn: [pants id]`.
- Not used: pants tucked into the boots; lowering or widening the cuffs.

**Seated legs (cello.py)**
- Each pant leg is a straight thigh piece and a straight shin piece, not a curve, so the plaid stays straight. The shin
  starts level with the top line of the thigh, overlaps it at the knee, has a rounded knee corner and a soft fold line.

**No body behind the pants (fit2.py `seat_fill`, `gusset`)**
- Where the body is wider or longer than the pants (Señor Jalapresto's pepper tip), every body pixel below the
  waistband is covered with plaid taken from the pants' own hip block, drawn under the pant legs.

**Using Erika's own layered PDF (std.py, wire_top.py)**
- Split the page into its top-level blocks, render each alone, and place them by matching her body layer to the app's
  body layer. Keep her layer order.

**Checking (sheet.py)**
- `render(avatar, pose, ids)` draws an outfit with the app's own rules (catalog, manifest slots, slot rank, replaces,
  when_worn / unless_worn, dress rule), ignoring the released switch. Use it for combination sheets before anything is
  switched on.

## Keywi's set on Señor Jalapresto's instrument poses (2026-11-13 and 14)

Scripts are in `keywi_set_on_presto/`. Rules Erika approved pose by pose:

- **Her layered PDF wins.** Regular pose, piano, violin and viola, flute and cello are built from her PDFs (presto_top_half,
  Piano, violin_blue_, Senor_flute, blue_shirt_and_cello): her tee, sleeves, arms and instrument, in her layer order.
- **Sleeves** are part of the shirt: joined at the shirt's top corners, their inner edge flat along the shirt's side and
  about 4px under the shirt body, so the only line at the join is the shirt's own outline. Triangles come to a real point.
- **Arms:** the shoulder-to-elbow part is hidden behind the sleeve (elbow just past the sleeve's edge); elbow to hand is
  on top of sleeve, shirt, bow and instrument. No arm joins on top of an instrument or clothing, no gaps, no stray marks.
  Arms are redrawn as clean even lines with the original hand attached where the fingers branch; always zoom in to check.
- **Violin and viola:** left arm under the instrument, hand behind the neck in first position (just below the nut, not at
  the scroll), three distinct fingers over the neck. Bow upper arm on its own layer under the instrument.
- **Cello and double bass:** one small sleeve on the bow-arm side, behind his body, at the same height on the shirt.
- **Guitars and ukulele:** strumming-side sleeve in front of the instrument where they overlap; fretting arm in front of
  the neck; the plain pose's strumming arm attaches on his body.
- **Piano pose** is scaled to the same size as his other poses.
- **Shoes:** legs run down into shoes with nothing showing through a heel gap. On crossed legs the Jazzy Joggers are
  shorter with the Bravura Boots, and the upright Legato Lace-Up goes in front of both pant legs.

## Bass guitar pose (2026-11-14)

`bass_guitar/` holds the scripts for Señor Jalapresto's bass guitar pose. `bass_pose2.py 40 648` builds the plain pose from the
electric guitar pose and Erika's bass picture (`sources/bass_guitar2.png`); `nudge.py` swings the upper fingertip around the lower one
so both hang just off the neck's edge (also applied to the electric guitar); `bass_sets.py` installs the pose and fits every accessory
by reusing the electric guitar fittings, rebuilding only the pieces that follow the fretting arm (tuxedo sleeve, tee arm). On the bass
the tee's fret-side sleeve stays wholly behind the instrument, because the bass's upper horn reaches it.
