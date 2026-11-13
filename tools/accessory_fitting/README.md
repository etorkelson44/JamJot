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
