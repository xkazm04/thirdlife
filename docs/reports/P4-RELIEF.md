# P4 land with relief and a visitor with a body: builder report and Director verification

Brief `briefs/BRIEF-P4-RELIEF.md`. Builder wall time 10:25 to 11:47 on 2026-11-11 (82 min; harness: 474,527 subagent tokens, 136 tool uses). Work done in the worktree `.claude/worktrees/core-p4` (branch `core-p4-relief`).

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

# P4 report: land with relief, and a visitor with a body

Status: all seven items were built and checked in the window, and I looked at every picture. The tour proof passes, `view.sh check` passes, and `node devx/bin/tl.mjs check --tier full` is green in `core-p4`.

Time: started 10:25 by `date`, finished 11:47, so 82 of 110 minutes. I ran no git command. I started two Godot processes of my own that I killed, and I left no window behind.

## Per item, with the proof

Pictures are in `C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p4\engine\kernel\world\captures\p4\`.

**1. Ground with height.**
- `engine/kernel/world/terrain/village_terrain.gd` builds one heightfield: 696 x 612 m, 3 m cell, 47,765 vertices, one indexed mesh.
- Contents: rolling land, a ring of hills up to 32 m, a 9.5 m bluff with a cliff face behind the northern venues, and a valley 5 m under the land with a river and a pond at each end.
- It uses the palette key `terrain`, so it gets the style's tufts and the strata on steep faces. I did not change the kit's own terrain.
- Roads and river are stamped into the grid. The kit's way, a path query per vertex, would have cost about 18 s.
- Cost: terrain 0.19 to 0.5 s, total landscape build 1.0 to 1.4 s once. The old landscape took 0.9 s.
- Proof: `views/bridge_close.jpg`, `views/stage_looking_out.jpg` (cliff strata) and `overview.jpg`.

**2. Plots as terraces.**
- Each plot stands on a flat pad of its own height, from -2.5 up to +7 m in the tour.
- A bank runs round the pad, and a stone kerb sits at the lip wherever the bank falls or rises more than 0.9 m.
- Last night's black rim line was a step. The world's ground lay 6 cm under the pack's rim and the dirt ring 3.6 cm over it, and ink draws a heavy line on a step like that at a grazing angle. Ground and rim are now at the same height and the line is gone.
- What remains is a real crest at the lip of the drive's hollow (`views/rim_venue_below.jpg`).
- I needed no change to `draw.gd` or `view.gd`. The walk's plot `origin` y already goes through view's existing lift.

**3. Roads on the ground.**
- The main road follows the land. A spur climbs from the pad height at each gate to the road.
- I moved the plots about 100 m apart in two rows, so every pad has a margin from the road. This is in `tour.json`.
- Proof: `tour/03_walking_past.jpg` and `views/slope_down_to_road.jpg`.

**4. Water.**
- The river is the style's water material, and a bridge stands where the road crosses it (deck, rails, three piers).
- Proof: `views/bridge_close.jpg`, `views/valley_from_bridge.jpg`.

**5. A body for the visitor.**
- What I chose: the world owns a `PhysicsServer3D` space, built once with the landscape. It holds only static things:
  - the terrain triangles, left out where a plot's own ground carries him;
  - a wall along every fence with the gate open, tree and rock trunks, the lots' machinery, and the bridge;
  - a **copy of every pack's static colliders**, clipped to the plot circle and bent at the rim the way the draw layer bends the ground.
- The pack's shapes are shared (a shape belongs to no space), but the bodies are new ones in the world's space. Pack bodies are never touched.
- His body is a kinematic capsule moved with `test_motion`. It steps up 0.55 m, slides along obstacles, and refuses slopes over 55°.
- The scheduler still reads the scripted `player_pos`, so the proof is unchanged. The body only decides where he is drawn. When a person walks (`--live`), the body sets `player_pos`.
- Probes (`walks/visitor_walk.json`, `world.sh tour visitor_walk ...`): 8 of 8 behave as expected.

| Probe | Result |
|---|---|
| fence from outside | stops at z 107.94 (fence at 107.6, plus his radius) |
| fence from inside | stops |
| gate | passes |
| bluff cliff | stopped by slope, 34 m short |
| tree | stopped by the tree |
| tall rock | stopped by the rock |
| bridge rail | stopped by the bridge |
| road verge | passes |

- Rocks lower than a knee are walk-over by design. My first rock collider was a sphere, and he climbed it like a hill, so rocks now use cylinders.
- In the final tour: `blocked_ticks` 0, and he ends exactly at the script's last position (`end_dev_m` 0.0).
- I had to adjust the script twice. The wall yard's gate is at x 126, not 118. The drive entry now stops at the rim, (0, -26).
- A visitor cannot walk down into the drive's hollow. Its own ground is a 7.6 m bowl bent over 9 m, which is 40 to 60° at the steepest. This is the pack's ground, not mine to change. `PATCHES-P4.md` has two options.

**6. Scatter.**
- Trees stand on convex ground (tree lines on ridges). Rocks stand on steep ground. None stand on a road, in the river, inside a pad, or on ground steeper than about 17 to 19°.
- Counts are lower than N7's: 120 pines, 40 broadleaf, 46 rocks, 90 bushes, 180 belt trees. N7 had 150, 46, 60, 110 and 260.

**7. Pictures** (all looked at).
- `overview.jpg`, and `vs_concept.jpg` with the concept beside it.
- `tour/01` to `10_*.jpg`, the tour's ten frames again, from the run whose proof passed.
- `views/`: `slope_venue_above`, `slope_down_to_road`, `rim_venue_below`, `stage_looking_out`, `bridge_close`, `valley_from_bridge`, `overview_high`, `standing_on_the_road`.
- I deleted one picture. `stage_looking_east` had a camera under the ground and showed garbage.
- On the slope pictures: `slope_venue_above` looks nearly flat, because the spur is gentle and the chase camera tilts with it. `slope_down_to_road` is the better one, with the kerbed pad beside him.

## Acceptance checks

- **Windowed tour.** `world.sh tour tour --out-dir=...` passed. Every pack's hash in the tour equals the pack alone and the replay:

| Pack | Own ticks | Hash |
|---|---|---|
| drive | 2419 | 59366015 |
| wall | 439 | bb9ec8af |
| walker | 371 | 8d1831dc |
| paddle | 1894 | c3b7779c |
| kit | 332 | 16db2bf1 |
| car | 1573 | 9a0c139b |

- **Headless tour.** It runs inside `kernel.selftest` as `world.tour`, which passed within 79 of 79 cases. I did not run `--headless` by hand after the final edits.
- **`view.sh check`** passed on the five seeds with stage `seed_paddle`. The hashes are the same as in `DRAW.md` section 6: 36635c04 at 3516, cadd1cd9 at 6776, 6366b88f at 1221, 16db2bf1 at 332, 8d1831dc at 371. Gate leaks 0, wrong-pack calls 0.
- **Gate.** `tl check --tier full` is green. Results from the gate output:

| Step | Result |
|---|---|
| arch | pass |
| assets | pass |
| cards | pass |
| devx.test | 110 pass |
| foreman.typecheck | clean |
| foreman.test | 158 pass |
| kernel.selftest | 79 cases |
| kit.selftest | 87 PASS lines |
| seeds | 24 cases |

- **World cost.** Same machine, same half hour, under load:

| | Before (main's engine, this morning's tour) | After |
|---|---|---|
| Headless tick p50 / mean / p99 / worst | 1.29 / 1.47 / 2.34 / 389 ms | 1.35 / 1.56 / 2.69 / 513 ms |
| Window frame, median | 3.13 ms | 2.45 ms (p99 9.3 ms, worst 921 ms) |
| Render CPU / GPU medians | 0.45 / 1.18 ms | 0.34 / 1.23 ms |
| Draw calls at the 10 pictures | 159 to 454 | 99 to 245 |
| Primitives at the 10 pictures | 0.9 to 1.6 M | 1.3 to 1.9 M |
| Landscape build (once) | 0.88 s | 1.38 s |

The simulation is untouched. The build is about 0.5 s more than before, once. The 921 ms frame is a pack rebuilt from its seed inside one frame, as in N7. The "before" window run was throttled to about 270 ms a frame for its last 1400 frames by another builder's window at the same screen position, so only its median is comparable.

## Still wrong against the concept

- Plots are still discs. A bank is a smooth slope with a kerb at its lip, not a retaining wall or a cut rock face. The only real cliffs are the bluff and the valley walls.
- Beyond the heightfield the far plain is flat, and the mesas still stand on it like stacked prisms. Seen from a crane they float.
- No cabin on a rise, and one plain river with no falls.
- The `ex_car` floor is still a big brown disc, and the drive's bowl is still the pack's.
- The strata shader draws faint polygon outlines on grassy slopes.
- The overview is much sparser than the concept: no density of props, rock faces, or warm light.

## Files changed

All under `C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p4\`.

- `engine/kernel/world/terrain/village_terrain.gd` (new): heightfield, pads, stamps, mesh, collision faces.
- `engine/kernel/world/terrain/world_space.gd` (new): world space, static colliders, pack static copies, capsule, `walk()`.
- `engine/kernel/world/terrain/village_parts.gd` (new): far plain, road strip, bridge, mesas, scatter helpers.
- The three `.gd.uid` files for those.
- `engine/kernel/world/landscape.gd`: rewritten around the terrain; flat `ground()` kept for single shots at -0.06.
- `engine/kernel/world/visitor.gd`: body, probes, per-walk report line.
- `engine/kernel/world/walks/tour.json`: plots moved, `pad_h`, river, lots, new player route.
- `engine/kernel/world/walks/visitor_walk.json` (new): the probe walk.
- `engine/kernel/world/walks/p4_views.json` (new): the picture walk.
- `engine/tools/world.sh`: `tl.view/1` lines of kind `visitor*` are passed through and printed (probe lines are RAW-only), plus landscape and terrain figures.
- `engine/kernel/world/WORLD.md`: P4 sections, keys, cost, pictures, limits.
- `engine/kernel/world/PATCHES-P4.md` (new).
- `engine/JOURNAL.md`: "P4" heading.
- `engine/kernel/world/captures/p4/`: the pictures above.

## Patches for files outside my scope

The full text is in `engine/kernel/world/PATCHES-P4.md`. None was applied, and P4 works without them.

1. **`draw/view.gd`: state a pad height once.** The walk currently writes a plot's height twice, as the plot `origin` y and in `landscape.pad_h`. The patch reads `pad_h` in view's tour branch and sets the plot's y from it. It also lets a walk set `rim_band` (default 9), so the drive's hollow can be widened to about 18 m and become walkable (about 25 to 35°). The landscape's collider and the draw layer must use the same band until then.
2. **`draw/view.gd`: print the worst frame.** Add `frame_ms_max_all` to the tour line. Meanwhile my visitor line carries `frame_ms_p50`, `frame_ms_p99` and `frame_ms_max`.
3. **`world.gd`: world owns the visitor space.** Move the space to the world host so a headless world can have a visitor and `_end` frees it. Not needed today.
4. **Seed / kit: a way down into a dipped plot.** Either the pack declares an entry ramp (`footprint.entry`), or patch 1 widens the band.

## Proposed contract text (contracts are the Director's)

`tl.view/1` gains three kinds:

- `visitor`: `{"ticks","blocked_ticks","max_dev_m","end_dev_m","frame_ms_p50","frame_ms_p99","frame_ms_max","end":[x,y,z],"space":{...}}`, one line at the end of a scripted walk that has a landscape.
- `visitor_probe`: `{"name","expect":"stop|pass","ok","from","to","end","short_of_target_m","stopped_by","ticks"}`.
- `visitor_blocked`: `{"world_tick","feet","want","hit","at","normal"}`, at most 6 per walk.

I first used a new schema name `tl.visitor/1`. The arch gate rejected it because no contract declares it, so I switched to these kinds of `tl.view/1`.

`tl.walk/1` gains:

- `landscape.pad_h` (list of floats, the pad height per plot, equal to the plot's `origin` y)
- `landscape.river`
- `landscape.lots[].h`
- `landscape.margin_m`, `landscape.cell_m`, `landscape.rim_band`
- top-level `visitor_probe`

## What changes for a pack author

- Your plot stands on a flat pad at the plot's height. The world's ground meets your rim at the same height, so there is no seam.
- If your own ground is a hollow, the visitor stops at its top.
- A copy of your static colliders is made when the world is built. A wall you remove later is still there for the visitor.
- Nothing in your pack or your state hash changes.

## Not verified

- Nobody has walked it live (`world.sh visit`).
- Rebuilt or ledger plots do not refresh their copied colliders; documented as a limit.
- I did not test `ledger` unloads with the new landscape, and I did not run `tour_next_round` windowed. `tour_views` windowed did build and draw.
- I did not look at the pictures at a second resolution or in a second window position.
- Frame figures were taken under heavy load from other builders.
- The one-off Jolt warning "job system exceeded the maximum number of jobs" appeared once in a windowed run. I made the visitor space inactive after the build, and the later runs I looked at (some of them with `TL_RAW`) showed no warning. I cannot say it is gone.

## Questions

1. May the walk state heights once (patch 1), so the landscape can later place plots itself?
2. Should `ex_car`'s floor, and any pack whose ground is a hollow, declare a footprint or entry so the world can ramp to it?
3. Do you want the lot at (205, -34) and the dropped lot at (-62, -21)? I removed the second small lot between the walker room and the track because its pad overlapped its neighbours; one lot remains at (-146, 64), and a new small one is at (205, -34).

---

## Director verification

Done 11:48 to 11:56 on 2026-11-11 in the builder's worktree, after the builder had stopped. Three other builders were
running the engine at the time.

### What was re-run, and the result

| Check | Result |
|---|---|
| `world.sh tour tour --headless` | six packs, each: in the tour = alone for the same ticks = replay of the log (`59366015...` drive 2419 ticks, `bb9ec8af...` wall 439, `8d1831dc...` walker 371, `c3b7779c...` paddle 1894, `16db2bf1...` kit 332, `9a0c139b...` car 1573): the builder's six hashes |
| `world.sh tour tour --out-dir=<scratch>` in a window | PASS, 10 of 10 pictures, 4 stage changes; the visitor's line: 0 blocked ticks, ends 0.0 m from the script's last position |
| `world.sh tour visitor_walk` | 8 of 8 probes as expected: stopped by a fence from outside and from inside, by the bluff's slope, a tree, a rock and the bridge rail; passes the gate and the road verge |
| `view.sh check` (five packs, stage paddle) | PASS: drawing leaves every pack's hash unchanged |

Hashes of drive, paddle and car differ from last night's tour because the walk changed (plots moved, the visitor's
route is new), not because simulation changed: the drawing check gives last night's five hashes.

**Looked at:** `captures/p4/vs_concept.jpg`, `captures/p4/views/bridge_close.jpg`.

### What the Director saw

- At eye level it is a different place: a river in a valley, a timber bridge on stone piers, a cliff with drawn strata,
  rolling ground with soft tone patches, trees placed along ridges. The water material and the bridge are in the look.
- From the high overview it is still far from the concept and in one way weaker than last night's low-hill view: the
  plots are 100 m apart on their pads, the haze washes the far half, the mesas float on a flat plain beyond the
  heightfield, and the pads still read as discs with banks. Density and composition, not relief, are now what is missing.
- A dipped plot (the track) has a real crest at its lip; the visitor cannot walk down into it.

### What is not verified

A person walking it; `node devx/bin/tl.mjs check --tier full` by the Director in this worktree (run on the merged
branch instead); frame cost on a quiet machine (the windowed tour showed GPU 2.65 ms against 1.2 ms last night, with
other builders drawing at the same time; worst frame 855 ms, a pack built inside one frame, which the loading package
of round 2 owns); the ledger tier and the next-round walk with the new land.

### Director's decisions on the builder's questions

1. A walk states a pad's height once: yes, with the far-games package of round 2, which owns `draw/view.gd`.
2. A pack whose ground is a hollow should declare a way in; recorded for the footprint work.
3. The lots as placed are accepted.

The three `tl.view/1` kinds and the `tl.walk/1` keys the builder proposes are accepted and go into the contracts with
the round's merge.
