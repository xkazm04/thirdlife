# N1 look toward the concept without a model: builder report and Director verification

Brief `briefs/BRIEF-N1-LOOK.md`. Builder wall time 00:04 to 00:57 CEST on 2026-11-11 (54 min; harness: 369,158 subagent tokens, 116 tool uses). Work done in the main tree.

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

N1 LOOK: REPORT

STATUS
All seven items of the work list are done, and every picture named below was looked at. All three gates pass on the final state and no seed hash changed. Start 00:03:32, end 00:57 (clock of this machine, `date`): 54 minutes of the 80.

All paths below are under C:\Users\kazda\kiro\third-life\engine\ unless written in full.

PER ITEM

1. No way to compare
- Found: no tool put engine frames beside the concept.
- Changed: new `tools\look.sh` with four verbs:
  - `shots <dir>`: the 12 seed frames with their bots, plus the lab hero through `k.sh cap`; 1 min 45 s per set.
  - `sheet <before> <after> <out.png>`: concept and both lab heroes on top, then every seed shot as a before | after pair (red band = before, green = after).
  - `px [frames]`: `subject_px` of each seed's main actor, min / median / max.
  - `one <pack> <cam> <frame> <out>`: a single capture.
- Also added `look\.gdignore`, because Godot was importing every capture in that folder as a project resource.
- Proof: `look\before\` (13 frames, taken before any change), `look\after\` (13 frames), `look\sheet_before_after.png`.

2. Lines
- Found: the contour is drawn inside the nearer object at one width, so any member thinner than the line turned fully black. Nothing smoothed the edge. Crease lines lasted to 340 m.
- Changed: `style\shaders\ink_post.gdshader` rewritten around four opposite tap pairs on two rings; the line detection uses the same 26 texture reads as before.
  - Width by distance: `near_px` 4.4 up close, falling to `outer_px` 3.4 at `bold_far` 80 m, thinner past 110 m.
  - Width noise damped (`even`).
  - Soft flank: a pixel reached only by the outer ring gets a part tone.
  - Thin-member rule: when both opposite taps see background, the contour becomes a hairline on the lower right and no crease line is drawn.
  - Crease distance rule: full to 22 m, gone at 120 m.
  - SMAA is set on the host viewport by `TLStyle.install` (`env.line_aa`), because the ink quad is not multisampled.
- Proof: `look\wip\crop_hero_a.png` and `look\wip\crop_wall_a.png` (before | after at 100 %): scaffolds, crane lattices and the fence are coloured bars again instead of black wire, and the hero's contour is bold and smooth. `look\wip\crop_yard_n.png` shows the last width step.

3. Colour
- Found: the orange came from the light, not mainly the grade.
  - Sun `#ffc488` × 1.25 at 11.5 degrees: at that height the forest and hills shadowed whole seed venues.
  - Shade `#34306e` at 0.78: this crushed the greens and turned ice and tarmac purple.
  - Grade sat 1.34 and contrast 1.22 then amplified both.
- Changed in `style\style.json`:
  - Sun `#ffd9a0` × 1.12 at 21 degrees.
  - Shade `#5a60c0` k 0.70; bounce 0.3.
  - Grade sat 1.24, contrast 1.14, split 0.06.
  - Fog `#d9b6a8`.
  - Tarmac `#5c6478` (a blue grey that reads neutral under warm light).
  - The sun is painted at 8 degrees while the light stands at 21 (`sky.sun_draw_elev`, `sky.gdshader`).
- `style_overcast.json` got the new ink keys only and still works: `look\wip\hero_overcast.png`; `k.sh validate` 7 files, 0 failed.
- Proof: `look\wip\quad_b.png`, `look\after\paddle_court_f400.png` (white ice with a cool shadow), `look\after\drive_chase_f1560.png` (grey tarmac, green grass, violet shadows on warm light).

4. Scale and framing
- Found: chase and orbit cameras ran at the engine's 75 degrees, and nothing measured size.
- Changed in `kernel\api\tl_cameras.gd`:
  - `frame(subject, fill = 0.35, view = &"")`
  - `subject_px(subject) -> float`: height of the on-screen rectangle around the visible meshes, clipped, as a share of frame height.
  - `shake(amount, frames)`: lens offset only, a fixed function of the frame count.
  - `set_subject(view, subject)` and `subject_of(view)`.
  - `TL_LOOK_PX=1` prints the size every 30 frames.
- `tl_chase_cam.gd`: fov 58, `follow` 0.3 for place split from `stiffness` for heading, smoothed aim, `snap()`.
- `tl_orbit_cam.gd`: fov 50, eased focus / yaw / pitch / distance (`smooth` 0.25), `snap()`. `yaw`, `pitch`, `distance` and `yaw_basis()` stay raw, because seed_wall walks relative to `yaw_basis()`; the mouse code is untouched.
- Seeds (camera lines and camera data only):
  - Wall frames the walker at 0.26.
  - Drive frames the car at 0.2.
  - Paddle's court view is steeper and tighter, with `set_subject`.
  - A shake line was added in each seed: block breaks, a goal, nitro start.
- Result of `look.sh px 3000` (min / median / max):

  | Seed, view | min | median | max |
  |---|---|---|---|
  | paddle, court | 0.094 | 0.109 | 0.128 |
  | drive, chase | 0.166 | 0.184 | 0.279 |
  | wall, player | 0.259 | 0.276 | 0.289 |

  All are at or above 0.08. No before figure exists, because the measure was added by this change.
- Proof: `look\after\wall_player_f700.png`, `look\after\drive_chase_f1560.png`.
- New camera section text: `look\API-cameras.md` (API.md was not edited).

5. Ground and surfaces
- Found: the terrain gave one colour and one normal per 4 m triangle, plus a 6 % brightness wobble per facet. Those were the flat triangles.
- Changed in `kits\tl_kit_terrain.gd`: near and far ground that is not steep gets one colour and one normal per grid vertex; steep faces stay faceted. Positions, triangle count and collision are unchanged.
- Changed in `toon.gdshader`, class ground:
  - Two-tone patches with a crisp wobbly edge.
  - Tufts on grass only, standing upright on screen.
  - Pebbles anywhere.
  - Scratches and grit on dirt only.
  - One drawn edge where grass meets dirt.
- Proof: `look\after\wall_player_f200.png` against `look\before\wall_player_f200.png` (the yard's triangles are gone), `look\wip\wall_i.png`, `look\wip\paddle_k.png`.

6. Light
- SSAO: tried at intensity 2 with light_affect 1. PSNR against the same frame without it was 57 dB on the cabin crop, so it has no visible effect on the toon shader. It is removed, and the reason is stated in `tl_style.gd`. Proof: `look\wip\crop_hero_e.png`, `look\wip\crop_wall_e.png`.
- Contact shade: drawn by the ink pass instead (`ink.ao_k` 0.42, radius 0.7 m), which adds 8 depth taps. Proof: `look\wip\crop_wall_f.png` (the violet foot under the barrier blocks).
- Depth of field: far blur tried at 0.06 and 0.02. It softens far contours the concept keeps crisp, so it ships off (`env.dof_far` 0); the option stays. Proof: `look\wip\crop_hero_h.png`, `look\wip\crop_hero_i.png`.
- Volumetric light: not attempted.

7. Motion
- Changed: `ctx.cameras.shake` is wired into the three seeds. `style\tl_style_fx.gd` got `TLStyleFx.squash(visual, amount, frames, axis)` and `TLStyleFx.trail(target, opts)`; both are frame-counted and visual only.
- Proof: a scratch probe outside the project, `look\wip\motion_probe.png`. The ball squashed to 1.10 × 0.82, its scale was back at 1 and the helper node gone at the end, and the trail was drawn.
- No seed uses squash or trail: a pack has no seam to reach them, and seed scripts were mine for cameras only.

RUBRIC (1 to 5, scored hard; 5 = the concept)

| | Before | After | Frame that shows it |
|---|---|---|---|
| Lines | 2 | 3.5 | `look\wip\crop_hero_a.png`, `look\after\wall_yard_f330.png` |
| Colour | 2 | 4 | `look\after\drive_chase_f1560.png`, `look\after\paddle_baseline_f520.png` |
| Scale | 2 | 3.5 | `look\after\wall_player_f700.png` |
| Ground | 1.5 | 3 | `look\after\wall_player_f200.png` |
| Light | 2.5 | 3 | `look\wip\crop_wall_f.png` |
| Motion | 1.5 | 2 | `look\wip\motion_probe.png` (stills cannot show shake or easing) |
| "Shipped indie game" | 2 | 3 | `look\sheet_before_after.png`; best single frames `look\after\wall_player_f700.png` and `look\after\drive_chase_f1560.png` |

GATES (last run, 00:49:37 to 00:57:07, on the final state; nothing edited after)
- `bash engine/tools/tl.sh selftest`: 63 passed, 0 failed.
- `bash engine/tools/tl.sh seeds`: 24 passed, 0 failed.
- `bash engine/tools/k.sh selftest`: 86 passed, 0 failed.
- Lint bypasses `[]` on all three seeds.

HASHES
No seed hash changed. Seed 1 smoke: paddle `bc93a9a4c892f2ab`, drive `b9adbb1967e36108`, wall `da4bdc3f65cc07ae`. They were checked after the camera work, after the shake lines, and in both full gate runs.

FRAME COST (`k.sh stats`, 2560x1440)

| Layout, camera | Before: draw calls / primitives | After: draw calls / primitives |
|---|---|---|
| main, hero | 245 / 1,670,668 | 239 / 1,667,300 |
| two_rinks, hero | 222 / 1,700,366 | 221 / 1,699,918 |

The after figures are 0.98 and 1.00 times the before figures. GPU time was not measured: the ink pass now makes 34 texture reads per pixel instead of 26, SMAA is on, and another GPU benchmark shares the machine.

STILL WEAKER THAN THE CONCEPT
- Line weight is roughly two thirds of the concept's on mid-distance objects, and a thin member gets one dark side rather than a full even outline.
- The ground has marks, but none of the concept's real rocks, bushes, grass clumps or paths. It is still a flat plane with drawings on it.
- Far mountains are faceted low-poly shapes and the clouds are jagged streaks; the concept has drawn cliffs and soft cloud forms.
- Characters and cars are small and simple next to the concept's hero, with no faces, props or smoke plumes.
- There are no light shafts, and no glow from the nitro or sparks in the seed frames.
- The paddle court view is clean but plain.
- In the game, motion is only the shake and camera easing.

NOT VERIFIED
- Interactive play (`tl.sh play`): no window was opened. That leaves unchecked the feel of the eased orbit camera, of the faster chase follow, and of the shake amounts.
- GPU frame time.
- The run-time style swap (`k.sh swaptest`) and the other lab layouts and sheets (`k.sh sheet`, `k.sh owed`) were not re-captured. Only the main hero in golden and overcast was looked at.
- Tufts turn with the camera's yaw, since they stand upright on screen. I have not watched this in motion.
- The trail is pale on bright ground, because it is additive.
- `frame()` on a fixed view is implemented but no seed uses it.
- The first background gate log (`gates1.log` in the session scratchpad) contained lines in another date format, so some other writer used the same file name. That run was discarded and both later runs went to uniquely named files.

QUESTIONS
1. `subject_px` is the height of the screen rectangle. A long, low actor such as the paddle seen side-on from the baseline scores low on it. Should the gate use the larger of height and width instead?
2. Should squash and trail get a `TLVfx` seam so packs can call them? That is a kernel file, so it is not mine to add.
3. Paddle's play camera is still "court", where A / D move the paddle up and down the screen. "baseline" sits behind the player's paddle and frames it far larger. Switching the default is a one-line camera change; do you want it?
4. Sun elevation moved from 11.5 to 21 degrees for every venue, with the painted sun at 8. Is the shorter-shadow look accepted for the lab hero as well, or should the hero layout keep the long shadows through its own style file?

FILES
- New:
  - `tools\look.sh`
  - `look\.gdignore`
  - `look\JOURNAL.md`
  - `look\API-cameras.md`
  - `look\sheet_before_after.png`
  - `look\before\`
  - `look\after\`
  - `look\wip\`
- Edited, style:
  - `style\style.json`
  - `style\style_overcast.json`
  - `style\tl_style.gd`
  - `style\tl_style_fx.gd`
  - `style\STYLE.md`
  - `style\shaders\ink_post.gdshader`
  - `style\shaders\toon.gdshader`
  - `style\shaders\sky.gdshader`
- Edited, kit: `kits\tl_kit_terrain.gd`
- Edited, cameras:
  - `kernel\api\tl_cameras.gd`
  - `kernel\api\tl_chase_cam.gd`
  - `kernel\api\tl_orbit_cam.gd`
- Edited, seeds:
  - `seeds\seed_wall\scripts\main.gd`
  - `seeds\seed_wall\data\tuning.json`
  - `seeds\seed_drive\scripts\main.gd`
  - `seeds\seed_paddle\scripts\main.gd`
  - `seeds\seed_paddle\data\court.json`
- Not touched: `engine\rigs\`, `grade.gdshader`, `engine\kernel\API.md`, `tools\tl.sh`, and every kernel file other than the three camera files.

---

## Director verification

Done 00:58 to 01:20 CEST on 2026-11-11, after the builder had stopped. Two other verification runs and the kernel
builder's bench shared the machine for the first pass.

### What was re-run, and the result

| Check | Result |
|---|---|
| `bash engine/tools/tl.sh selftest` | 63 passed, 0 failed (twice: alone, and after the N4 merge) |
| `bash engine/tools/k.sh selftest` | 86 passed, 0 failed (twice) |
| `bash engine/tools/tl.sh seeds` | first run 23 of 24: `seed.wall.invariants` failed the frame budget at p99 26 ms under load; the Director's direct run of the same check gave p99 0.65 ms, and the second full run on a quieter machine gave 24 of 24 |
| seed state hashes (`seedtest.py`, direct runs) | unchanged: smoke `b9adbb19...` drive, `da4bdc3f...` wall; bot hashes `cadd1cd9...` paddle, `36635c04...` drive, `6366b88f...` wall, each the same three times; seeds 2 and 7 differ |
| `bash engine/tools/look.sh px 3000` | paddle court 0.094 / 0.109 / 0.128, drive chase 0.166 / 0.184 / 0.279, wall player 0.259 / 0.276 / 0.289 (min / median / max): all at or above 0.08, as reported |

**Looked at:** `engine/look/sheet_before_after.png` (whole sheet), `engine/look/after/wall_player_f700.png` and
`engine/look/after/drive_chase_f1560.png` at full size.

### What the Director saw

- Colour is the largest gain. Ice is white with a cool shadow, tarmac is grey, grass is a clean green, and shadows are
  violet against warm light. The purple tint and the crushed greens of the seed frames are gone.
- Lines: the site fence reads as bars and posts instead of wire; outlines near the camera are bold and smooth. Mid-distance
  objects still carry a thinner line than the concept.
- Scale: the walker and the car now fill a clear share of the frame. The paddle court is clean but its actors are still
  small.
- Ground: the yard's large triangles are gone; marks, pebbles and tufts are drawn. It is still a flat plane with drawings
  on it, without the concept's rocks, bushes and paths.
- Still plainly low-poly: far mountains, the streaky clouds, a strongly magenta sky, and characters without faces or
  props.

Director's scores on the same sheet: lines 3.5, colour 4, scale 3.5, ground 3, light 3, motion not judged (stills),
"shipped indie game" 3 to 3.5. The builder's scores stand.

### What is not verified

GPU frame time (the ink pass reads 34 samples a pixel instead of 26 and SMAA is on; draw calls and primitives are
unchanged); anything in motion (camera easing, shake, tufts turning with the camera); the other lab layouts; interactive
play.

### Director's decisions on the builder's questions

1. `subject_px` stays the height measure; a long low actor is a known blind spot, noted for the capture gate.
2. Squash and trail get a `TLVfx` seam in the next kernel pass.
3. Paddle's play camera stays `court` until a person has played both.
4. The sun at 21 degrees with the painted sun at 8 is accepted for every venue, the lab hero included.

Merged: the builder worked in the main tree; its camera text is now section 12 of `engine/kernel/API.md`. The 127 MB of
frames under `engine/look/before`, `after` and `wip` are ignored by git; the sheet, the tool and the journal are tracked.
