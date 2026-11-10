# Lane B, pass 4: builder report and Director verification

Builder: fresh agent (no memory of passes 1-3), brief `spike/lab/BRIEF-B-PASS4.md`.
Wall time 17:30 to 18:17 CEST on 2026-11-10 (47 min; harness figures: 349,234 subagent tokens, 119 tool uses).
The builder cannot write report files; the text below is its final message, saved by the Director. The Director's own
verification is the last section.

---

## Builder report (verbatim)

**Status: done, inside the time-box (17:30:43 to 18:17 CEST by `date`).** One of three full acceptance runs failed; the
cause is diagnosed and patched, but the patch is not verified against a real moving pointer.

### Acceptance
`tools/g.sh pass4` runs the validator on all four layouts, everything `pass3` runs, then layout D.

| Run | Time | Result |
|---|---|---|
| 1 | 317 s | clean; play tests main, alt, c, d all 16/16 |
| 2 | 315 s | **FAIL**: layout C play test 14/16 (`orbit: yaw is free yaw -54.8`, `reset: camera back… pitch 35.0 yaw 6.0`) |
| 3 (final code and data) | 303 s | clean; 16/16 on all four; movie 20.000 s recorded in 48 s |

- **Run 2 failure:** two immediate reruns passed, so it is not deterministic. In test mode `player.gd` accepted every
  mouse-motion event, so real pointer motion over the test window would add to the injected motion. That cause is
  inferred from the code and the odd error amounts, not observed.
- **Patch:** injected motion now carries device id 77 and the test ignores any other device (6 lines in `player.gd` and
  `look.gd`). The weakness existed in passes 2 and 3 too.
- Layout C still has the 2 vacuous assertions you noted.
- No Godot or ffmpeg process was alive at 18:16. No git command was run.

### Part 1: layout contract
- **`LAYOUT.md`** (221 lines): every key with type, default, range and meaning, the prop kinds with their arguments, what
  the validator does and does not check, and about 30 things a layout cannot express.
- **Validator** (`tools/validate.gd`, 417 lines; `tools/g.sh validate <name|path>…`, exit 1 on failure): passes on main,
  alt, c and d.
- **What it catches:** on a broken copy of C with 12 planted faults it printed 16 readable errors and caught all of them:
  - unknown keys at three levels (`sead`, `ridge.fal`, `props[].yaws`), with the allowed keys listed
  - wrong type, out of range, bad enum, wrong vector length
  - prop kind `gazebo` ("is not a kit part"), palette key `flag_z`, missing prop arguments
  - a prop outside the terrain, `built > ribs`, a wall longer than the loop, a missing camera
  - a missing file and invalid JSON also fail cleanly
- **One real catch:** `data/layout_c_frozen.json` (the pass-3 archive) fails on an undocumented `_note` key. I left it as
  it is.
- **Undocumented rules found while writing the contract:**
  - `hero_rocks` needs 2 entries or the play test crashes (`look.gd:401`).
  - `rib_dx` is read even with 0 ribs.
  - A mesa is applied after the road and pads, so it buries them (validator rule added).
  - Cameras missing from a layout silently fall back to the main layout's views.

**Layout D, frozen run** (hash `360ab69c50827087`, re-checked after each run; frozen from 17:35:45 until Part 2 code work
began at about 17:46):
- Version 1 is kept as `data/layout_d_frozen.json`. It passed the validator, rendered hero, site, track, crumble and map
  first time, and passed the play test 16/16. Nothing crashed.
- **The validator caught nothing.** I wrote the file with the contract open, and I am also the validator's author. I had
  read `world.gd` minutes earlier, so "only `LAYOUT.md`" was not a clean-room test.
- Looking at the frames found three placement faults no validator sees: a light mast 2 m in front of the site camera,
  the rink and lake outside the hero frame, and an empty track frame. Two further data rounds fixed them.

What the brief asked and the file could not say:

| Asked | What the file could do | Code it needs |
|---|---|---|
| Two rinks | One `arena` only; the second is a flat `ice` sheet with no boards or goals, and stray lines from the one global set of rink markings | `arenas[]` plus per-rink markings: about 60-90 lines across `world.gd`, `sim.gd`, shader. Not done |
| Rink without boards or goals | Not expressible | about 6 lines. Not done |
| Lake / shore | A flat pale `pond` sheet, no shoreline | Real basin with a water level: about 35-45 lines. Not done; cheap version below |
| Watch tower | No such part; a 3.75 m marshal post stood in | Done after the freeze, below |
| Kart track | Road width, kerbs and two full-size cars are fixed | Width key about 12 lines; kart part about 40 lines (or car scale, 3). Not done |
| Loop around a hill | Works only as a small wide-blend mesa; the road cannot climb | Not estimated |

**After the freeze, as a separate step:**
- Prop kind `watch_tower`: 31-line kit part plus 5 lines of wiring, worked first run in about 1.5 min.
- A `pond` with the `water` key is now still water with a sand rim: 17 lines in kit and shader, about 1.5 min.
- D's layout file then swapped the marshal post for the tower.

### Part 2
1. **Contrast and saturation:** `style.json` only. Fog halved and no longer pink, grade contrast 1.10 to 1.22,
   saturation 1.20 to 1.34, darker and bluer shade, darker ink, greener grass. The violet haze is gone.
2. **Density:** mostly layout data.

   | | Pass 3 | Pass 4 |
   |---|---|---|
   | Bots | 10 | 18 |
   | Cranes | 2 | 3 (two now in the hero) |
   | Scaffolds | 4 | 8 |
   | Props | 42 | 86 |
   | Placed rocks | 4 | 17 |

   - A near work terrace sits 35 m from the camera, with fence lines and rocks along the track.
   - Code: drawn strata on steep terrain (shader plus 4 style keys).
   - Cranes and scaffolds were yellow in the palette but rendered black, because the 2.8 px outline covered members
     1-2.5 px wide. Members are now thicker and the outline narrows with distance.
3. **Light pools:** three soft bands starting at zero light, no disc edge; checked on the main, alt and overcast heroes.
4. **Face:** parts were flat shapes floating off a curved head. They now sit on the surface, mirrored: round eyes, blush
   discs, capsule brows, a one-piece smile with teeth. A new bone `Glints` lets the blink close fully; the rig has 26
   bones, humanoid names unchanged.
5. **Track frame:** camera raised; skid marks on every bend, a kerb apron with drain slots, gravel traps, plus fence,
   sign and marshal post in frame, and the trees that cast the shadows.
6. **Small items:** `BUSY_EXE` is empty by default and documented. Layout C's hero camera and one house were moved in
   data; the rink and all three houses are whole, but the avatar now overlaps the left house.

### Captures (`C:\Users\kazda\kiro\third-life\spike\lab\b\captures\`)
- `b_pass4_compare.png`: pass 3 against pass 4 for hero, site, track, avatar front.
- `b_pass4_ref.png`: concept beside the new hero.
- Main set: `b_hero.png`, `b_site.png`, `b_track.png`, `b_crumble.png`, `b_avatar.png`, `b_avatar_faces.png`,
  `b_hero_overcast.png`, `b_movie.mp4`.
- Layout D: `b_d_{hero,site,track,crumble,map}.png`, and the frozen versions `b_d_*_frozen.png`.
- Layouts alt and C: `b_alt_*.png`, `b_c_*.png`.
- Before state: `pass3_orig/` (29 PNGs plus the pass-3 style, layout and camera files).
- Stale, not regenerated: `b_nitro`, `b_site_adv`, `b_bot`, `b_hero_2split`, `b_c_*_frozen`, `b_pass2_compare`,
  `b_pass3_compare`, `b_pass3_material_crops`.
- `g.sh compare` now builds the pass-4 sheets instead of `b_pass3_compare.png`.

### Performance (2560x1440, hero, RTX 4090, `RTAI-bench.exe` not in the process list)

| | Before | After |
|---|---|---|
| Draw calls | 196 | 261 |
| Primitives per frame | 1,431,150 | 1,646,782 |
| gpu_ms | 1.653 | 1.75-1.78 |
| VRAM | 746 MB | 768 MB |
| fps_avg | 554 | 505-528 |
| Scene triangles (`--kitstats`) | 435,006 | 482,990 |

Code is 29 scripts and shaders, 5,081 lines, plus the validator.

### Rubric (self-scored, against the Director's pass-3 reading)

| Item | Pass 3 | Pass 4 | Evidence |
|---|---|---|---|
| Silhouette | 4 | 4, did not move | cranes now read as yellow cranes, bots still small in `b_hero.png` |
| Material | 3-4 | 4 | strata on buttes, road marks and apron in `b_track.png`; arena concrete still quiet |
| Atmosphere | 4 | 4, did not move | haze gone and pools soft, but the frame is warmer and less varied in hue than the concept |
| Avatar | 3.5 | 4 | `b_avatar_faces.png` |
| Bots | 4 | 4, did not move | more of them and closer, same model |
| Destruction | 4 | 4, did not move | not worked on |
| Consistency | 5 | 5 | |
| "Shipped indie game" | 4 | 4 | the track frame went from weakest to on par; the hero is denser |

### Still weaker than the concept
- Bots are about 30 px tall at best in the hero; the concept draws them oversized.
- No rock outcrops or guard rails between track sections, and the track is small in the hero.
- Scaffolds at the rink are still mostly dark.
- Hue range is narrower: orange dominates where the concept has cool purple cliffs.
- Distant outlines are thinner now, which is the price of the yellow cranes.
- The second rink in D is a white slab.

### Ledger
About 47 min wall, 19 look-and-fix rounds, about 26 sheets looked at; 15.5 min of that was the three acceptance runs.
Per-step minutes are in the pass-4 ledger at the end of `JOURNAL.md`.

### Questions
1. Should the validator allow comment keys (for example any key starting with `_`)? Today `_note` is an error.
2. SCENE.md fixes two cranes. I added a third so two stand in the hero. Accept that, or move the hero camera instead?
3. `arenas[]` (two rinks) is the largest remaining layout gap, at about 60-90 lines. Do it in this lane, or leave it to
   the Phase 0 schema work?
4. Is it acceptable that `g.sh compare` now writes the pass-4 sheets and no longer rebuilds `b_pass3_compare.png`?

---

## Director verification

Done 18:18 to 18:40 CEST, after the builder had stopped. The builder's frames were first copied to
`captures/director/pass4_builder/` (41 PNGs). Another session's GPU benchmark (`RTAI-bench.exe`) was running for the
whole of this verification, so timings and `gpu_ms` here are taken under load.

### What was re-run, and the result

| Check | Result |
|---|---|
| `bash tools/g.sh pass4` | 922 s (494 s of it the movie), 152 log lines, no `ERROR`, `leaked`, `still in use` or `FAIL` line |
| Validator on main, alt, c, d | all four `OK` |
| Play test on main, alt, c, d | 16 of 16 on each (68 PASS lines = 4 x 16 + 4 result lines) |
| Validator on the Director's own broken copy of layout C (4 planted faults) | 4 readable errors (`sead`, `ridge.fal`, `wall_blocks` type, prop kind `gazebo`), exit code 1 |
| Validator on `layout_c_frozen.json` | fails on `_note`, as the builder said |
| Movie | 20.000 s; recorded at 4 % of real time with the other benchmark running throughout |
| Stats under load | `draw_calls 261, primitives 1,646,782, gpu_ms 1.884, cpu_render_ms 0.39, vram_mb 768.0, fps_avg 459` |
| Code size | 5,081 lines in `src/` and `shaders/`, matching the report |

### Two things the re-run adds to the builder's account

1. **The movie-slowdown cause is now seen twice from the Director's side.** Pass-3 verification with the benchmark absent:
   40 % of real time. This run with it present throughout: 4 %. Same code path. With `BUSY_EXE` now empty by default,
   `g.sh pass4` no longer waits for the other process, so a full run can take 15 minutes instead of 5.
2. **A second timing flake.** In this run the layout-C collapse capture logged `chunks awake 0 of 48 at t=1.5`, so that
   frame showed an intact wall. Three immediate repeats each gave 43 of 48. The builder saw a different one-off (the
   layout-C play test at 14 of 16 in one run of three). Both happened on layout C under load. Neither is explained; the
   builder's mouse-device patch does not cover this one. Treat timed captures and the play test as occasionally flaky
   when another GPU process is running.

### What could not be re-checked

- The frozen-code claim for layout D (hash and timing are the builder's word; no git history). `layout_d_frozen.json`
  and its captures exist. The builder's own caveat stands and matters more: it wrote the layout minutes after reading the
  source and is the validator's author, so **layout D was not a clean-room test of the contract**.
- The pointer-interference diagnosis for the play-test flake is an inference, and the patch is untested against real
  pointer motion.
- `gpu_ms` on a quiet machine (builder: 1.75 to 1.78). Under load the Director measured 1.88.

### What the Director saw in the frames

Sheets: `captures/director/p4_main.png`, `p4_d.png`, `p4_misc.png`, and the builder's `captures/b_pass4_compare.png` and
`b_pass4_ref.png`.

- **Hero:** the largest single-pass improvement of the four. The violet haze is gone, colours are saturated, two yellow
  cranes and yellow scaffolds read at distance, a near work terrace fills the mid-ground, strata are drawn on the buttes.
- **Face:** fixed. Round eyes with highlights, a real smile, a blink that closes. The avatar is now a 4.
- **Track:** no longer the weakest frame: fence, sign, kerb apron, tyre marks, the trees that cast the shadows.
- **Light pools:** soft; no disc edge on the porch grass.
- **Layout D:** a recognisably new place (watch tower, hill inside the track loop, shore, one hologram rink), with the
  second rink a plain white slab as the builder said.
- **Overcast** still works with the new density.

Remaining defects the Director sees:

1. The hero now leans hot: orange and yellow dominate, where the concept keeps cool purple cliffs for contrast.
2. Bots are still small in the hero (about 30 px).
3. In the layout-C hero the avatar stands in front of the left house.
4. In layout D the second rink is a white slab with stray marking lines, and the lake is only an edge at the frame border.
5. The front avatar frame stands on plain spiky grass with a flat brown patch: it shows the face well and the world badly.

### Director's reading of the scores

Agrees with the builder: silhouette 4, material 4, atmosphere 4, avatar 4, bots 4, destruction 4, consistency 5,
"shipped indie game" 4 across hero, site, track and collapse. The look is now even: no frame is clearly worse than the
others. It is still a notch below the concept in drawn detail and character scale, and a fifth polish pass would move
those slowly. The lane has answered its question.

### Answers to the builder's questions

1. Yes: allow keys starting with `_` as comments. Not changed yet.
2. Accept the third crane; `SCENE.md` should be amended when the contract moves into the kernel work.
3. Leave `arenas[]` to the Phase 0 schema work. It is the first concrete requirement for that schema: lists, not
   singletons, for every venue part.
4. Yes.

### Lane B after four passes

| Pass | Builder wall time | Lines | Triangles | Draw calls | gpu_ms at 1440p |
|---|---|---|---|---|---|
| 1 | about 57 min | 3,876 | 404,534 | 802 | 1.49 |
| 2 | about 38 min | 4,538 | 414,946 | 778 | 1.62 |
| 3 | 83 min | 4,959 | 435,006 | 196 | 1.66 to 1.71 |
| 4 | 47 min | 5,081 + 417 validator | 482,990 | 261 | 1.75 to 1.78 (builder, quiet), 1.88 (Director, under load) |

About 3 h 45 min of builder time in total. Four layouts from one kit, a written layout contract (`LAYOUT.md`) and a
validator. No Blender and no hand-made asset.

### What the lane says about the product

- **Look:** an inked low-poly style is reachable at shipped-indie level by an agent in hours, entirely from code, at a
  render cost far inside budget.
- **Builder output format:** a validated layout file is workable for placement and absence, and it failed for every new
  quantity or new kind of thing (three houses, two rinks, a lake, a tower, a kart). Each gap cost 1 to 90 lines of code.
  A builder restricted to data would under-deliver on every new brief; a builder allowed to add kit parts (the watch
  tower: 36 lines, first run) closes most gaps in minutes. That supports the earlier ruling of GDScript freedom inside a
  fence, with data as the default and code as the escape hatch.
- **What a validator cannot see:** placement faults (a mast in front of the camera, the subject outside the frame). Those
  were only caught by looking at frames, so the build loop needs a look-at-the-capture step, not only schema checks.
