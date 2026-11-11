# P6 what a far game shows, and the land at a distance: builder report and Director verification

Brief `briefs/BRIEF-P6-FAR.md`. Builder wall time 13:22 to 15:01 on 2026-11-11 (99 min; harness: 489,433 subagent tokens, 181 tool uses). Work done in the worktree `.claude/worktrees/core-p6` (branch `core-p6-far`).

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

REPORT P6: what a far game shows, and the land at a distance
Builder: core-p6 (branch core-p6-far). Start 13:22:32, end 15:01 (99 minutes, from `date`).

## STATUS

All six items were worked in the brief's order. Items 1, 2, 5 and 6 are done and proven. Item 3 is done only through geometry (no shader was changed). Item 4 is four of its six points: soft ground patches and a more compact village were not done.

Final checks on the final files: full gate green, drawing check PASS, tour proof PASS (headless and windowed); seed hashes are N5b's and the hockey hash drawn equals its headless hash.

Three findings matter more than the code:

- **The kit scoreboard is a prop.** Every game showed "3 : 2" at every distance, in full or as a stand-in. Nobody could ever read who is winning. The draw layer now lays the pack's real score over it, at every distance, near included.
- **From 150 m on, full game and N5b's stand-in are the same picture at screen size.** What the stand-in lost is life (skaters, cars, smoke), not detail.
- **A size rule per instance saves nothing.** A venue is one merged mesh (paddle seed: 6 instances, 13,072 triangles, 784 of them terrain). My first far picture had 12,922 triangles. A rule per triangle brought it to 4,487.

All paths below are under `C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p6\`.

## PER ITEM

### 1. The study
- **Deliverable:** `engine\kernel\world\draw\FAR.md` section 1: the table (3 games x 4 distances: reads, noise, missed) and a pixel-size table.
- **Method:** three games on a flat study ground with the village's haze; eye (1.7 m) and rise at 50, 150, 300, 600 m from the plot edge; 24 crane shots per process.
- **Tool:** `engine\kernel\world\draw\far_study.mjs` (`walk` writes the walk, `sheet` builds a sheet with ffmpeg).
- **Before sheets (looked at):** `engine\kernel\world\captures\p6\study\before_drive.jpg`, `before_paddle.jpg`, `before_hockey.jpg`. Frames are in `before_full\` and `before_still\`.
- **Support:** cfg key `relief` (0 = flat ground) in `landscape.gd` and `terrain\village_terrain.gd`.

### 2. Three pictures instead of two
- **Near:** all of it, as before.
- **Middle:** merged mesh of instances of 2.5 m and more, plus:
  - one mark per moving body (a box in its colour; figures are slim upright boxes; one multimesh per pack; moved when the pack has ticked);
  - a copy of up to 2 smoke emitters;
  - the 4 strongest lights;
  - the real score.
- **Far:** instances of 5 m and more; no triangle narrower than 0.1 m and none with longest edge under 0.4 m; kit terrain on a 6 m grid; normals leaning half-way up; no shadow; marks 1.6 times larger; smoke; score.
- **Threshold:** camera to plot edge 240 m, margin 30 m. Defaults live in the draw layer, which reads `picture_far_m` and `margin_m.picture` from the world's `cfg` when present (patch 1).
- **Forcing a picture:** `TL_DRAW_PICTURE=still|mid|far`; "still" is N5b's stand-in, kept for comparison.
- **After sheets:** `captures\p6\study\after_<drive|paddle|hockey>_<eye|rise>.jpg`.
  - Looked at in final form: all three `_rise` sheets and `after_hockey_eye.jpg`.
  - Not opened: `after_drive_eye.jpg`, `after_paddle_eye.jpg`.
- **Seen in them:** hockey middle picture shows 0 : 0 on the board and blue and red marks on the ice; marks are still visible at 600 m.
- **Code:** one class in four files because `tl arch` caps file size: `draw_base.gd` (166 lines), `draw_pictures.gd` (304), `draw_life.gd` (411), `draw.gd` (420), all in `engine\kernel\world\draw\`.

### 3. Lines, haze, tone
- Done through the far picture only: thin and small triangles dropped whole, normals flattened so the ink pass leaves the outline.
- `engine\style\**` is untouched. The ink pass already thins with distance; haze is unchanged.
- A venue reads at 300 m and 600 m in the sheets.
- Shimmer was not judged: every picture is a still.

### 4. The land
- **Pads:** worn ring 2 to 8 m wide by noise; a rock edge replaces the fence on the side away from the gate (337 rocks in the tour's world; fence 1,888 m down to 1,390 m; the visitor's wall is kept); irregular lots.
- **Mesas:** a grass foot under each, pines at foot and cap, 16 pine clumps on the far plain (472 far trees).
- **Roads:** 44 trees and 70 bushes along them.
- A generator of its own, so P4's scatter stands where it stood.
- **Pictures (looked at):** `captures\p6\land_before\`, `land_after\`, `overview_high_before_after.jpg`, `far_and_near_before_after.jpg` (first take; the final take, after the rock shadows went off, was not opened).
- **Not done:** soft ground patches, compact village.

### 5. Cost
Command: `bash engine/kernel/world/draw/far_cost.sh <abs dir>`. Raw lines: `captures\p6\cost\cost_run1.txt` and `cost_run2_far.txt` (the far rows, taken after the triangle rule). Pack 0 is always drawn in full; the other N-1 show the named picture.

| packs | picture | draw calls | primitives | draw layer ms per frame |
|---|---|---|---|---|
| 6 | near | 493 | 644,790 | 0.168 |
| 6 | before (still) | 53 | 170,490 | 0.035 |
| 6 | middle | 80 | 171,938 | 0.129 |
| 6 | far | 54 | 124,635 | 0.108 |
| 12 | near | 953 | 1,099,198 | 0.457 |
| 12 | before (still) | 50 | 179,036 | 0.063 |
| 12 | middle | 111 | 182,492 | 0.262 |
| 12 | far | 59 | 97,357 | 0.220 |
| 30 | near | 2,344 | 2,344,020 | 1.166 |
| 30 | before (still) | 62 | 263,578 | 0.199 |
| 30 | middle | 225 | 273,394 | 0.730 |
| 30 | far | 109 | 130,065 | 0.643 |

- **Triangles per picture:** paddle seed 13,072 (middle) to 4,487 (far); wall seed 13,704 to 3,592.
- **Build time:** both pictures of a seed are built in one walk in about 160 ms, once, in the frame the pack first goes far.
- **GPU and frame times:** recorded in FAR.md section 4 but not separable tonight. No run was quiet, one was throttled to 270 ms a frame, and the 30-pack far run reads 3.7 ms against 0.74 at 6 packs.
- **Ledger scenario `tour6`** (`tl perf run --scenario tour6 --no-record`): machine BUSY, not recorded. 280 draw calls and 1,977,056 primitives, against the last quiet line's 249 and 1,911,582 (+3.4 %). With shadows on the pad rocks it was 288 and 2,237,536, so their shadow is off.

### 6. Pictures
- **Sheets:** as listed under items 1 and 2.
- **Overview beside the concept:** `captures\p6\overview_vs_concept.jpg` (concept, before, after). I looked at the first take; the final take after the rock shadows went off was rebuilt but not opened.
- **Eye-level frame:** `captures\p6\eye\01_eye_near_mid_far.jpg`. From the visitor's eye the far games are hidden behind near things, as the study predicts.
- **Same world from a rise:** `eye\02_rise_near_mid_far.jpg`, `eye\03_rise_far_side.jpg`. These show walker near, drive and paddle middle, wall and car far.
- **Format:** frames were converted to JPEG; the folder is 35 MB.
- **Not opened:** 10 of the 12 cost pictures (only `cost_30_mid.jpg` and `cost_30_far.jpg` were looked at).

## ACCEPTANCE

1. **`draw/FAR.md` with table and rules:** yes (sections 1 and 2, eleven rules).
2. **Paired sheets before and after, overview beside the concept, list of what is still wrong:** yes (FAR.md section 5).
3. **Drawing check:** PASS on the final files (14:27).
   - Command: `bash engine/tools/view.sh check --packs=seed_drive,seed_paddle,seed_wall,<hockey> --standins=auto --far=60 ...`
   - drive 36635c049bc6acd8 at 3516, paddle cadd1cd9fffac7b1 at 6776, wall 6366b88f838e3e78 at 1221: N5b's values.
   - hockey 5af10fbc23df0d76 at 4888, drawn equals headless.
   - 0 gate leaks, 0 script errors, 0 engine errors.
4. **Tour proof:** PASS on the final files.
   - `bash engine/tools/world.sh tour tour --headless` (14:30): six of six "same".
   - Windowed tour with proof (14:32): 10 of 10 pictures, 4 stage changes, PASS.
   - `world.sh tour ledger` in a window (a pack unloaded while its pictures stay): PASS.
5. **Cost table; middle clearly less than near, far less again:** yes in draw calls and primitives at every size. Not shown in milliseconds.
6. **`node devx/bin/tl.mjs check --tier full`:** green at 15:00 (`ok: true`).
   - PASS: arch, assets, cards, devx.test 123, foreman.typecheck, foreman.test 158, kernel.selftest 81 cases, kit.selftest 87, seeds 24 cases.
   - perf: measured, not judged (machine BUSY, use 100 %).
   - item.selftest and ui.selftest: SKIPPED (they need the main checkout's `site/`).
   - An earlier full run (14:20 to 14:40) failed arch and two devx tests because `landscape.gd` had grown to 634 lines. Fixed by moving three loops to `village_parts.gd`; it is now 597.

**Finding on the gate:** a full gate took 20 minutes with three other full gates running. No healthy step failed from load.

## FILES CHANGED

All under `engine\kernel\world\`.

| file | change |
|---|---|
| `draw\draw.gd` | now layer 4 of 4: stage rule, placing, mirrors, per-frame loop, report; calls the new layers |
| `draw\draw_base.gd` (new, + .uid) | constants, variables, helpers |
| `draw\draw_pictures.gd` (new, + .uid) | merged pictures still / mid / far in one walk; triangle rule; terrain grid |
| `draw\draw_life.gd` (new, + .uid) | which picture, marks, smoke, lights, score boards |
| `draw\FAR.md` (new) | study, rules, what is built, cost, still wrong |
| `draw\far_study.mjs` (new) | study walks and sheets |
| `draw\far_cost.sh` (new) | cost runs |
| `draw\PATCHES-P6.md` (new) | four patches, none applied |
| `draw\DRAW.md` | head note, file table, sections 9 and 10 |
| `draw\JOURNAL.md` | section "P6" |
| `landscape.gd` | `relief`, uneven pad rings, rock edge, irregular lots, road trees, mesa pines |
| `terrain\village_terrain.gd` | `relief` |
| `terrain\village_parts.gd` | mesa foot and trees; `road_side`, `plain_clumps`, `edge_rocks` |
| `captures\p6\**` (new) | pictures, walks, cost lines, `.gdignore` |

Not touched: `world.gd`, `pack.gd`, `tiers.gd`, `tiers.json`, `view.gd`, `kernel/api`, rigs, kits, style, contracts.

## PROPOSED CONTRACT TEXT

**PACK.md, on a pack in a world:**
"Beyond the sideline a pack is drawn as a merged picture of its static venue plus signs of life. Every body that is not static and not frozen, and every rig, is drawn as a box in its main colour, moved when the pack ticks. Up to two standing smoke emitters and four lights are kept. Anything shorter than 2.5 m is not drawn from the sideline on, anything shorter than 5 m or thinner than 0.1 m from about 270 m on. What a far visitor must see has to be tall, large or moving."

**PACK.md or KIT:**
"A kit `scoreboard` shows fixed digits. In a world, when the pack has a `TLRules`, the world draws the first two sides of `rules.scores` (0 to 9) over it at every distance."

**tiers schema:** optional `picture_far_m` (number > 0) and `margin_m.picture` (number >= 0); drawing only, never read by `decide()`.

**Walk schema, block `landscape`:** optional `relief`, `pad_rocks`, `road_trees`, `road_bushes`, `plain_clumps`.

## PATCHES FILE

Contents of `engine\kernel\world\draw\PATCHES-P6.md`; none applied, the draw layer works without all of them.

1. **`tiers.json`, `tiers.gd`:** add `"picture_far_m": 240` with a note, and `"picture": 30` in `margin_m`; `load_config` accepts both as optional; they must not enter `decide()`. Reason: the threshold is a threshold of the world and a walk should be able to override it. The draw layer already reads both from `cfg`.
2. **`view.gd`, `runner/verbs.json`:** option `--picture=still|mid|far`. In `start()` after `draw.set("rim_band", ...)` add `draw.set("force_picture", str(opts.get("picture", "")))`; list the option in verbs.json. Reason: the study uses an env variable because the viewer's options are not mine.
3. **`kits/tl_kit_site.gd` `add_scoreboard`, `KIT.md`:** say the digits are decoration. Later, for the kit's owner: a parameter that leaves the face black, and a helper that binds a board to a `TLRules` in a single-pack run (`_refresh_boards` and `_digit` are 30 lines and can move to the kit).
4. **`WORLD.md` (the walk's `landscape` block):** document the new optional keys: `relief` [1.0], `pad_rocks` [true], `road_trees` [44], `road_bushes` [70], `plain_clumps` [16].

## WHAT CHANGED FOR A PACK AUTHOR

- Nothing to do for a pack that follows API.md.
- At a distance your moving bodies and rigs are still seen, as boxes in their main colour. What must be seen from far has to be tall, large or moving.
- Place the kit `scoreboard` and use `TLRules`, and a world shows your real score on it. In a single-pack run it is still the prop.
- Up to two standing smoke emitters (no script, no children) are copied into your far pictures.
- DRAW.md section 10 has the wording.

## NOT VERIFIED

- Shimmer or popping in motion: every picture is a still. The change between middle and far was never watched happening.
- Milliseconds per tier (see item 5).
- The cost of the four mirrored lights alone.
- Whether those lights behave after a ledger return, beyond "no error".
- The middle picture at 30 m, which is possible when a walk's `sideline_m` is small; marks as boxes are crude there.
- Marks of more than 96 bodies (they update in a round-robin): no pack in the runs had that many.
- Yaw on a plot with marks or boards.
- A person walking (`world.sh visit`).
- Whether the built Windows executable sees `TL_DRAW_PICTURE` (it should be unset there).
- The two `_eye` sheets, the final takes of the overview and far-and-near sheets, and 10 cost pictures were not opened (see items 2, 4 and 6).

**One incident:** my first tour run at 13:26 left an idle window because the worktree had no class cache. I stopped my own two processes by their tag and built the cache; four minutes lost. No process of mine is left (checked 15:01).

## QUESTIONS

1. **Score at near distance.** The live score over the prop is drawn on near packs too, so it is the same at every distance. Is that wanted, or should near stay the pack's own business until the kit part is fixed (patch 3)?
2. **Pace of the marks.** Marks step at the pack's tick rate (four times a second at one tick in sixteen). That is the truth about the game's pace and it looks like stutter. Smooth them between ticks, or keep it honest?
3. **Middle to far threshold.** It is the camera's distance, so the high crane sees silhouettes everywhere while the scheduler decides near. Should the scheduler own this too (patch 1 keeps it drawing-only)?
4. **Road trees in an existing shot.** Trees along the road now stand in front of the fixed crane camera of `tour_views` shot `far_and_near` (`captures\p6\far_and_near_before_after.jpg`). Move that camera (the walk is not mine) or thin the trees there?
5. **Pads are still circles.** The plot cut is a circle and the fence follows it. A non-round plot is a change to the plot contract. Is it wanted?

---

## Director verification

Done 15:02 to 15:52 on 2026-11-11 in the builder's worktree. The command runs were made by a Sonnet subagent and
read by the Director; the pictures were looked at by the Director. The loading package's verification ran windows of
its own at the same time.

### What was re-run, and the result

| Check | Result |
|---|---|
| the drawing check on the three seeds and the hockey game (`view.sh check ... --standins=auto --far=60`) | PASS: four hashes as before the package, drawn equal to headless; 0 gate leaks, 0 calls into a wrong pack, 0 script errors, 0 engine errors |
| `bash engine/tools/world.sh tour tour --headless` | PASS: six of six the same in the walk, alone and in the replay |
| `far_cost.sh <dir> 6` | near 493 draw calls and 644,790 primitives; the old stand-in 53 and 170,490; middle 80 and 171,938; far 54 and 124,635: the builder's figures to the digit. Frames of 3.7 to 4.2 ms, so this run was not throttled |
| the tour with every far game forced to the far picture (`TL_DRAW_PICTURE=far`) | ran to its end, 10 of 10 pictures, no error |
| the same forced to the middle picture | first run stopped at the 600-second limit after 7 pictures; the repeat alone ran to its end, 10 of 10, no error |
| `node devx/bin/tl.mjs check --tier fast` | PASS |

### What failed in the re-run

The tour in a window with its proof did not pass in two attempts. The first was stopped at the 600-second limit:
its frames went from 3 ms to about 275 ms in the middle of the run. The second ran to its end with the six hashes of
the headless tour and 10 of 10 pictures, and was counted failed for one engine error that has nothing to do with
drawing: `WASAPI: GetBufferSize error`, the sound device going away under the window.

Both causes are the machine's and both are faults of the tools, not of this package: windows of several runs on the
same spot of the screen throttle each other to a quarter of a second a frame (the loading verification saw the same
at the same minutes), and a test window has no reason to open a sound device at all. Round 3 (P11, which owns the
tools) gives windowed runs a lock so that two never overlap and a silent sound driver. The windowed tour is run
again, alone, on the merged tree.

### Looked at (Director)

- `docs/reports/img/p6_overview_vs_concept.jpg`: concept, before, after. After: pines on the mesa caps, trees along
  the roads, a far plain that is no longer bare. Against the concept the village is still thin: wide grass between
  small venues, nothing built up around the road, no water in this view.
- `docs/reports/img/p6_rise_near_mid_far.jpg`: from a rise, the walker's plot near, track and court in the middle
  picture, wall and car far. It reads as one landscape; the far venues are recognisable by their tall parts.
- `docs/reports/img/p6_study_hockey_rise.jpg`: the hockey arena at 50, 150, 300 and 600 m, full, old stand-in and
  new. The new column shows the real score (0 : 0, where the others show the prop's 3 : 2) and the blue and red marks
  on the ice down to 600 m. At 50 m the marks are plainly boxes.

### What this settles

- A far game is no longer a dead model: it shows that somebody plays, and who leads.
- The scoreboard was a prop from the first night on. No picture taken so far showed a real score.
- A rule per mesh instance saves nothing, because a venue is one merged mesh; the rule per triangle is the one that
  cuts the far picture to a third.

### What is not verified

Anything in motion. Milliseconds per picture. The tour in a window with its proof (see above).

### Director's decisions on the builder's questions

1. The real score is drawn at every distance, near included, until the kit's scoreboard can be bound to the rules
   itself (round 3, P13).
2. Marks are smoothed between the game's ticks: a far picture is a picture, drawn every frame from the last two
   known positions, and never feeds back into the game.
3. The threshold between the middle and the far picture stays a matter of drawing; the scheduler does not own it.
4. Trees do not stand in front of a fixed camera of an existing walk: the trees give way.
5. Plots stay round for now.

The proposed contract texts are accepted and go in with the round's merge.
