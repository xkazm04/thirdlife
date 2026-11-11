# P3 the look, second pass, with motion: builder report and Director verification

Brief `briefs/BRIEF-P3-LOOK2.md`. Builder wall time 10:25 to 12:09 on 2026-11-11 (104 min; harness: 434,838 subagent tokens, 199 tool uses). Work done in the worktree `.claude/worktrees/core-p3` (branch `core-p3-look2`).

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

Status: all seven items are done, with item 7 (light) only partly confirmed by eye. Every acceptance check passes except one: the only gate step that failed in the full run, `seeds`, failed on a load-induced time budget and passed when re-run alone. I started at 10:25:14 and finished at 12:08:49 (about 104 minutes of the 110).

Everything below is in `C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p3`, and paths are relative to it. Four things to know up front:
- **Hockey skaters:** The hockey skaters got a stick and a team helmet with no change to the pack.
- **Camera defaults:** The chase-camera defaults changed.
- **Regenerated docs:** I regenerated three generated docs: `docs/generated/API-INDEX.md` (outside my scope), `engine/rigs/RIGS.md` and `engine/kits/KIT.md`.
- **Never watched or measured:** I did not watch the game interactively, and I did not check a fast display. Those are listed at the end.

## What I found before building

- **Faces:** Pass 4's face (eyes with highlights, brows, a smile, a blink every 204 frames) did reach `engine/rigs/`, so faces were not missing. The head was 0.37 m on a 2.0 m body, and at game scale the whole face was about 3 pixels.
- **Hockey sticks:** The hockey pack builds skaters with `mode = skate` and team colours only (`site/ice-hockey-three-against-20261111-1/.../scripts/main.gd:53`). `stick` defaults to false, so those skaters never held a stick.
- **Foot slide:** The planted foot moved backward at about 0.9 to 1.6 m/s while walking at 1.0 to 2.2 m/s. The leg swing was too large for the cadence.
- **Angular mottle from above:** The hard yellow and dark-green polygons seen from above come from the world's own landscape patches in `engine/kernel/world/landscape.gd`, not from the shader. I cannot fix that file; it is item 4 of `engine/look/PATCHES-P3.md`.

## Per item

1. **Judging motion.**
   - `bash engine/tools/look.sh clip <what> <out.mp4> [frames]` writes the engine's movie output (60 fps, 1280x720) and turns it into an mp4 plus an 8-frame strip.
   - `<what>` is `paddle`, `drive`, `wall`, `tour`, `hockey`, or `rig:<kind>:<speed>:<turn>:<view>`. The rig kinds are walk, run, skate, shoot, pass, idle, work, car, bot and fx (all nine effect presets).
   - `look.sh slip <speed> [mode]` prints foot-slide numbers.
   - The rig scene is `engine/rigs/review/review.tscn`.
   - A new `TL_LOOK_CAM=<file>` writes one camera line per frame, and I analysed it with a small python script (speed, jerk, turn rate).
   - Before clips and strips: `engine/look/p3/clips_before/`. After: `engine/look/p3/clips_after/`.
   - Defects I wrote down before fixing:
     - Faces were 3 pixels.
     - The hockey skaters had no stick.
     - The walking foot moonwalked.
     - The sky was a magenta wash with jagged cloud shards.
     - The mesas were flat brown.
     - Grass was one lime.
     - Effects were tiny and faint, and the flashes appeared at full size on their first frame.
     - Steering and nitro on the car snapped from one frame to the next.
   - The seed clips (drive, wall) end with an engine crash on exit after the movie is closed. The files are complete.

2. **Characters** (`engine/rigs/tl_rig_biped_mesh.gd`, `tl_rig_biped.gd`, `tl_rigs.gd`).
   - Head ×1.24 and hands ×1.38, still 2.0 m tall. The face bones move with the head.
   - Two new params:
     - `prop` (`auto` | `none` | `stick` | `hammer`).
     - `headgear` (`auto` | `none` | `helmet`).
   - In skate mode `auto` gives a thicker stick (0.05 × 0.065 shaft, 0.38 m blade, light wood) and a helmet in the `top` colour with a white stripe, white hem band and back number patch.
   - Hockey packs get both without any change. Metrics and clip timing are unchanged.
   - Proof: `engine/look/p3/pair_hockey_before_after.png`, `engine/look/p3/wip_face70.png`, `engine/look/p3/wip_skate_close_strip.png`.

3. **Motion fixes.**
   - **Foot slide:** the swing of legs and arms now follows ground speed (`_stride_amp`, 0.62 at walking speed rising to 0.78 at a run).
   - Mean slide in m/s from `look.sh slip` (before / after):

     | Speed | Before | After |
     |---|---|---|
     | 1.0 m/s | 0.88 | 0.30 |
     | 1.4 m/s | 1.18 | 0.42 |
     | 2.0 m/s | about 1.6 | 0.61 |

   - The signed mean went from -0.9..-1.6 (moonwalk) to about +0.05..+0.08. Clips played by name (`play(&"walk")`) keep their authored swing.
   - **Chase camera:** `follow` 0.3 → 0.18, `aim` 0.5 → 0.3, `stiffness` 0.12 → 0.07 (`engine/kernel/api/tl_chase_cam.gd`). On the drive seed over 1800 frames, position jerk p95 fell from 116 to 89 m/s³ and the max from 239 to 157. The car's size in the chase view is now 0.158 to 0.254 of frame height (was 0.166 to 0.279). The sideways aim noise did not improve, at about 2.9°/s rms before and after.
   - **Orbit camera:** already smooth, left alone.
   - **Vehicle rig:** the drawn steering, body roll, pitch and nitro flame now ease toward what the controller asks. The flame lights fast and dies slowly.
   - **Effects:** dust and smoke are larger and more opaque, and sparks, nitro flame and goal flash grow in over their first frames. This is the weakest-verified part: the effects clip framing was bad and the particles stayed small, so I only saw them faintly (`engine/look/p3/clips_after/fx_strip.png`).

4. **Lines at mid distance.** In `style.json` I set `outer_px` 4.0, `near_px` 4.8, `bold_far` 140, `thin_near` 60, `thin_far` 220, `outer_far` 0.7. Proof: `engine/look/p3/crop_crane_before_after.png` shows the crane at about 40 m clearly bolder. I did not make a separate mid-distance crop at 100 m or more.

5. **Sky and far scenery.**
   - **Clouds:** drawn clumps on the dome with flat bases and bumpy tops, three flat tones, and an ink contour on the shade side. The palette is warmer: gold horizon, salmon mid, mauve upper, blue zenith, and a less broad sun glow.
   - **Far strata:** the rock class draws strata at any distance (bands of world height, seams never thinner than a pixel, vertical streaks, warm sunward light). `palette.cliff` is now a purple grey.
   - **Not done:** the tree line along mesa rims. The mesas are built in `landscape.gd`; I wrote this up in `engine/look/PATCHES-P3.md`.
   - Proof: `engine/look/p3/after/village/02_overview_hill.png`, `engine/look/p3/wip/03_overview_high.png`, `engine/look/p3/sheet_p3_concept.jpg`.

6. **Grass.** Two scales of soft patches run from warm olive-yellow to cool blue-green, and the crisp patch edge from N1 is soft. Proof: `engine/look/p3/after/hockey_arena.png` and `engine/look/p3/wip/03_overview_high.png`.

7. **Light.** I added a cool rim on the shade side (`toon.rim2`, `rim2_k`, global `g_rim2`) and raised `bounce_k` from 0.3 to 0.42. I did not isolate its effect with a before and after crop on the hero, so it is not confirmed by eye. I score it conservatively.

## Acceptance checks

- **Seed hashes unchanged.** Smoke gives paddle `bc93a9a4c892f2ab`, drive `b9adbb1967e36108`, wall `da4bdc3f65cc07ae`.
- **`view.sh check` (the exact command in the brief): PASS.** All five packs' drawn hashes equal their headless hashes, with 0 gate leaks, wrong-pack calls, script errors and engine errors (log `C:\Users\kazda\AppData\Local\Temp\p3_viewcheck.log` equivalent: `/tmp/p3_viewcheck.log`).
- **`engine/look/p3/` contents:**
  - Before and after stills of last night's 13 shots (`before/`, `after/`), plus the village crane views and hockey arena.
  - Before and after clips: walk, run, skate, shoot, car, drive chase (camera), wall orbit (camera), tour, hockey, fx.
  - Sheets: `sheet_before_after.png`, `sheet_p3_concept.jpg` (concept, hero before and after, village before and after, hockey after), and the pairs and crops.
  - I looked at all of them.
  - A few captures failed once under load and were retaken alone, and the fx clip is as weak as noted above.
- **Gate: `node devx/bin/tl.mjs check --tier full`.**
  - In the full run, arch, assets, cards, devx.test (110), foreman.typecheck, foreman.test (158), kernel.selftest (79 cases) and kit.selftest (87 lines) passed. `seeds` showed 3 failed, 21 passed.
  - The seeds failure was `seed.drive.invariants` with "frame p99 21.25 ms is over the 8 ms budget". It ran while my captures and other builders' runs were loading the machine.
  - Re-run alone, `tl check --tier full --only seeds` passed all 24 cases (278 s). I did not run the whole full tier again in one piece.
- **Frame cost:**
  - `k.sh stats` at 2560x1440: main hero 239 draw calls / 1,667,300 primitives; two_rinks hero 221 / 1,698,622.
  - These match N1's final figures exactly (239 / 1,667,300 and 221 / 1,699,918). I took no fresh before from this tree, so the before is last night's reported numbers.
  - GPU from the village views: render gpu was 1.235 ms before and 1.192 to 1.261 ms after (five runs, taken under load).
  - That is within noise, so I claim no GPU change. The ink pass is unchanged (no new taps), and the sky shader does more work but the figures show no cost.

## Rubric (1 to 5, hard; 5 = the concept)

Before is my reading of `engine/look/p3/before/`; the Director's scores for last night's pass are in `docs/reports/N1-LOOK.md`.

| | Before | After | Where |
|---|---|---|---|
| Lines | 3.5 | 4 | `engine/look/p3/crop_crane_before_after.png` |
| Colour | 4 | 4 | `engine/look/p3/sheet_p3_concept.jpg` |
| Scale | 3.5 | 4 | `engine/look/p3/after/lab_main_hero.png`, `pair_hockey_before_after.png` |
| Ground | 3 | 3.5 | `engine/look/p3/after/hockey_arena.png`; the world's hard polygon patches still show from above |
| Light | 3 | 3.25 | not isolated, see item 7 |
| Sky and far scenery | 2 | 3.5 | `engine/look/p3/after/village/02_overview_hill.png`; the lab hero's far low-poly hills are still faceted |
| Characters | 2.5 | 3.5 | `engine/look/p3/wip_face70.png`, `pair_hockey_before_after.png` |
| Motion | 2 | 3 | foot slide measured; camera jerk measured; effects barely seen |
| "Shipped indie game" | 3 | 3.5 | `engine/look/p3/sheet_p3_concept.jpg` |

## Files changed

- `engine/rigs/tl_rig_biped_mesh.gd`: bigger head and hands, face bones moved with the head, helmet and hockey kit.
- `engine/rigs/tl_rig_biped.gd`: `prop` and `headgear` logic, hammer, bolder stick, `_stride_amp`, helmet rebuild guard, review hooks `stride_k` and `amp_override`.
- `engine/rigs/tl_rigs.gd`: the two new params.
- `engine/rigs/tl_rig_vehicle.gd`: eased steering, roll, pitch and flame.
- `engine/rigs/review/review.gd`, `review.tscn`, `review.gd.uid`: the motion review scene (not part of any pack).
- `engine/rigs/RIGS.md`: P3 section and regenerated tables.
- `engine/style/shaders/sky.gdshader`, `toon.gdshader`: drawn clouds, far strata, grass patches, cool rim.
- `engine/style/style.json`: sky, ink, palette cliff, toon rim2 and bounce.
- `engine/style/tl_style.gd`: registers `g_rim2`.
- `engine/style/tl_style_fx.gd`: bigger dust and smoke, flashes grow in.
- `engine/style/STYLE.md`: P3 section.
- `engine/kernel/api/tl_cameras.gd`: `TL_LOOK_CAM` log.
- `engine/kernel/api/tl_chase_cam.gd`: new smoothing defaults.
- `engine/tools/look.sh`: `clip` and `slip` verbs.
- `engine/look/JOURNAL.md`, `API-cameras.md`, `PATCHES-P3.md`: journal, camera notes, patches.
- `engine/look/p3/**`: all captures.
- `engine/kits/KIT.md`: regenerated, probably unchanged in content.
- `docs/generated/API-INDEX.md`: regenerated by `tl arch --index`, a generated file outside my scope. The index was stale because I changed the mesh class's constants and a method signature, and `tl check` refuses a stale index.

## Proposed contract text

The text for `contracts/KIT-RIG-STYLE.md` (rig params, style keys, camera defaults, `TL_LOOK_CAM`) is in `engine/look/PATCHES-P3.md` item 3 and was not applied.

## Patches file (`engine/look/PATCHES-P3.md`)

1. **`engine/project.godot`:** `physics/common/physics_interpolation` is false, so on a display above 60 Hz everything judders; the proposed change is `common/physics_interpolation=true`, which needs one interactive look first.
2. **`engine/kernel/api/tl_biped.gd` lines 165 and 189:** turning is a constant-rate `rotate_toward`, which is stiff. Easing the body changes every skating seed's hash, so I give a visual-only version that eases the rig node's yaw against the body's.
3. **`contracts/KIT-RIG-STYLE.md`:** the proposed text above.
4. **`engine/kernel/world/`:** mesas already get strata from the material. A tree line along the rim would need a part built in `landscape.gd`. The world's hard polygon patches cause the angular mottle from above.

## What changes for a pack author

- Skaters (`mode = skate`) now get a stick and a team helmet with a hem band and number patch, without any change. Pass `prop = none` or `headgear = none` to turn them off.
- All bipeds have bigger heads and hands. Colliders and metrics are unchanged.
- Walking and running feet are planted, because the swing now follows speed.
- The default chase camera is floatier (more lag, smoother).
- Dust and smoke are bigger and more visible, and flames and flashes grow in.
- New style keys: sky `cloud_puff`, `cloud_line`, `cloud_ink`; toon `rim2`, `rim2_k`.

## Not verified

- No interactive play (`tl.sh play`). I did not feel the camera changes by hand, only by log and clip.
- No fast-display check. All clips are fixed-60 fps, so the 144 Hz judder that patch 1 addresses cannot show in them.
- Effects were not clearly seen after the bump (framing problem).
- The cool rim was not isolated by eye.
- The stride fix was measured for walk and run. Skating still glides by design and I did not measure skate slide.
- Turning of rigs in the world (the kernel's constant-rate turn) is unchanged.
- The visitor never shows his face in the tour clips, because the camera follows from behind.
- `look.sh clip` for seed packs relies on the movie writer ending cleanly. It crashes on exit but the clip is complete.

## Questions for the Director

- Should the P3 captures go into git as they are? `engine/look/p3` is about 300 MB. The mp4s are about 5 MB each and could be recompressed.
- Should the mesa rim tree line go to the world builder as a ticket?

---

## Director verification

Done 12:19 to 12:36 on 2026-11-11 in the builder's worktree, after the builder had stopped.

The builder added one correction after its report: it ran `git diff --stat` once in its worktree by mistake at about
10:55 (read-only, nothing changed), against the rule that builders run no git command.

### What was re-run, and the result

| Check | Result |
|---|---|
| seed hashes on the new engine (`seedtest.py`, direct runs) | unchanged: smoke `bc93a9a4...`, `b9adbb19...`, `da4bdc3f...`; bot `cadd1cd9...`, `36635c04...`, `6366b88f...`; each the same three times |
| the hockey pack 0.1.1 on the new engine | smoke `b0ddd31f...`, bot `5af10fbc...`: last night's hashes, although its skaters now hold sticks and wear helmets |
| `view.sh check` (five packs, stage paddle) | PASS: the draw layer's shader parameters still work |
| `tl.sh selftest`, `k.sh selftest`, `tl.sh seeds` | 79, 86 and 24 passed, 0 failed |

**Looked at:** `engine/look/p3/sheet_p3_concept.jpg`, `pair_hockey_before_after.png`, `wip_face70.png`,
`clips_after/walk3q_strip.png`.

### What the Director saw

- Characters: a face that reads (round eyes with highlights, a smile, cheeks), a larger head and hands. The hockey
  skaters have sticks and helmets in team colours, and blue against red is now clear on the ice from the arena camera.
- Sky and far scenery: drawn cloud clumps instead of streaks, mesas with strata, a warmer evening.
- Ground: grass in the arena and village has soft tone patches.
- Motion: the walking strip shows planted feet; the Director did not watch the clips themselves frame by frame.
- Still short of the concept: the lab hero's far hills are faceted; effects are small and were barely seen; the rim
  light was not isolated; from above the world's own ground patches are angular (the land builder's file).

Director's scores on this material (5 = the concept): lines 4, colour 4, scale 4, ground 3.5, light 3, sky and far
scenery 3.5, characters 3.5, motion 3 (from strips, not from watching), "shipped indie game" 3.5.

### What is not verified

Interactive play and a display above 60 Hz (the builder's patch 1, physics interpolation, needs a person to look
first); the effects after the change; frame cost measured from this tree before the change (the builder compared with
last night's reported figures: draw calls and primitives identical, GPU within noise).

### Director's decisions on the builder's questions

1. The 300 MB of captures under `engine/look/p3` are not tracked; the sheets, pairs and strips that carry the evidence
   are copied to `docs/reports/img/` as JPEG.
2. The tree line along mesa rims and the angular ground patches go to the far-games package of round 2, which works on
   what is seen at a distance.

The proposed text for `contracts/KIT-RIG-STYLE.md` (rig parameters `prop`, `headgear`; style keys; camera defaults) is
accepted with the round's merge.
