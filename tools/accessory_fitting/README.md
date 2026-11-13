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

**Pants over tall boots (boots.py `over_boots`, option B approved by Erika)**
- Pants stay full length and in front. A second version of each boot is made for when the pants are worn: the boot is
  hidden above the bottom edge of that pant leg's cuff (the cuff line is carried sideways past both ends of the cuff at
  the cuff's lowest point), so the boot shows only below the cuff.
- In the catalog the normal boot pieces get `unless_worn: [pants id]` and the trimmed ones `when_worn: [pants id]`.
- Not used: option A (pants tucked in: pant legs re-aimed at the boot tops and cut there).

**Checking (sheet.py)**
- `render(avatar, pose, ids)` draws an outfit with the app's own rules (catalog, manifest slots, slot rank, replaces,
  when_worn / unless_worn, dress rule), ignoring the released switch. Use it for combination sheets before anything is
  switched on.
