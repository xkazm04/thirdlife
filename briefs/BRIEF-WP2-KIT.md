# WP2: kit, rigs and style

You are the builder of **WP2** in Phase 0 of the Third Life feasibility spike. Third Life is a single-player sandbox in
which an LLM designer and builder agents construct whole mini-games (hockey, racing) as verified **packs** over a frozen
**law kernel** in Godot. You turn the accepted look test (lane B) into the reusable **kit, rig and style layer** that
later agents assemble games from, with no help from you. Its documentation and validators are part of the product.

## Read first, in this order
1. `C:\Users\kazda\kiro\third-life\contracts\README.md` (ownership, global rules), then `KIT-RIG-STYLE.md` (your
   contract) and `PACK.md` (who will call you).
2. `C:\Users\kazda\kiro\third-life\spike\lab\b\README.md`, `KIT.md`, `LAYOUT.md`, then the **Director verification**
   sections at the end of `REPORT-PASS3.md` and `REPORT-PASS4.md` (known weak spots and flakes).
3. The lane-B source you are porting: `spike\lab\b\src\` (`mk.gd` mesh kit, `style.gd`, `kit_*.gd`, `rig.gd`,
   `terrain.gd`, `world.gd`, `stage.gd`, `fx.gd`), `shaders\`, `data\`, `tools\g.sh`, `tools\validate.gd`. Grep before
   you read; do not dump whole files you do not need.
4. Two images, to know the target: `spike\lab\b\captures\director\pass4_builder\b_hero.png` and `b_site.png`.

`spike/lab/b/` is read-only: copy what you need, never edit it.

## Your scope
`kitlab/**` only: a Godot 4.7.2 project (`kitlab/project.godot`) whose deliverables are `kitlab/kits/**`,
`kitlab/rigs/**`, `kitlab/style/**`, with `kitlab/lab/**` (test scenes), `kitlab/tools/**` and `kitlab/JOURNAL.md`
around them. The three deliverable directories must not reference anything outside themselves (no `res://lab/...`),
because they will be moved into another project unchanged.

## What to build, in priority order
1. **Style** as `KIT-RIG-STYLE.md`: static `TLStyle`, no autoload, the single palette material plus the special
   materials, both style files, range clamps, and a real headless mode.
2. **Kit**: `TLKit.list/spec/validate/build/hash` and the minimum part list. Port lane-B parts, re-cut to the node
   convention (visuals, static bodies tagged `tl_material`, `Intact`/`Pieces` for fracturable parts). Every part has
   params with types, defaults and ranges in `spec`, and builds from defaults.
3. **Rigs**: `TLRigs` with `biped`, `vehicle`, `bot`. The biped needs the full clip list, procedural and frame-driven
   (`tick(frame)`), blending, a `skate` locomotion mode, the stick option and sockets. Lane B had a rigid-part biped
   with a walk only: the clip library is the largest new piece of work here, and hockey depends on `skate`, `shoot`,
   `pass`, `skate_stop` reading clearly from a chase camera. Vehicle: wheels that steer and spin, suspension travel
   per wheel, nitro flame. Bot: the lane-B crew bot with its work and carry motions.
4. **Layout** `tl.layout/1`: `TLKit.validate_layout` and `build_layout` with lists everywhere, unknown keys as errors,
   `_` keys as comments, and `kitlab/kits/LAYOUT.md`. Port the four lane-B layouts to the new schema as test data in
   `kitlab/lab/layouts/` and add one that the old schema could not express: two rinks side by side and three houses.
5. **Tools and tests** (`kitlab/tools/k.sh`): `validate` (layouts and style), `selftest` (every part builds headless
   from defaults and from a random valid param set, twice, with equal hashes; every rig builds and plays every clip
   for 120 frames headless with no error; budgets checked), `sheet` (windowed: a contact sheet of all parts, a turntable
   of each rig, the clip strip described below), `cap <layout> <cam>`.

## Look at your output
This is visual work: render, look at the image with the Read tool, fix, repeat. Use half-size contact sheets to save
context. Owed images, all in `kitlab/captures/`:
- `parts_sheet.png`: every kit part from defaults, labelled.
- `biped_clips.png`: for each clip, 6 evenly spaced frames in a row, side view; and `biped_skate_chase.png`: `skate`,
  `shoot`, `pass` from a chase-camera angle (behind and above, 35 degrees).
- `vehicle_sheet.png` (steer left/right, suspension compressed, nitro), `bot_sheet.png`.
- `layout_two_rinks.png` and one capture of a ported lane-B layout beside the lane-B original
  (`spike/lab/b/captures/director/pass4_builder/b_hero.png`) to show nothing was lost in the port.
- `style_swap.png`: the same view in golden and overcast.

## Acceptance (the Director will run these)
- `bash kitlab/tools/k.sh selftest` passes headless with one PASS/FAIL line per case and no script error.
- `bash kitlab/tools/k.sh validate` passes on all layouts and fails with readable errors on a broken one.
- Nothing under `kits/`, `rigs/`, `style/` references a path outside those three directories.
- No global random call, no wall-clock read: animation and variation are driven by `tick(frame)` and `seed`.
- Budgets in the contract hold; the report gives triangles and bones per rig and triangles and draw calls for the
  largest layout at 2560x1440.
- The images above exist and you have looked at each one.

## How to work
Small verified steps; journal after each in `kitlab/JOURNAL.md`. Another builder is writing the kernel in `engine/` at
the same time: never read from or write to `engine/`, and do not assume any kernel class exists. Kill every process you
start; never kill others (other sessions run Godot and a GPU benchmark here, so treat timings as indicative). No git.
No network. Do not open an interactive window; captures use `--position 0,1440`.

## Final message (your report, as text)
Status; what exists and what does not, against the priority list; selftest and validate output; the part table (kind,
params count, triangles, fracturable); the clip table with a one-line honest judgement of each clip from the images;
budgets; what the layout schema still cannot express; what a pack author will find awkward; capture paths; questions;
minutes spent from real timestamps.

## Time-box
Until the list is done or **21:45 CEST today**, whichever comes first (check with `date`). Leave the last 20 minutes
for the selftest, the sheets and the report. A usage limit can cut you off without warning: keep the journal current.
