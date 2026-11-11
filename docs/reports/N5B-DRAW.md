# N5b drawing many games in one landscape: builder report and Director verification

Brief `briefs/BRIEF-N5B-DRAW.md`. Builder wall time 01:55 to 03:00 on 2026-11-11 (65 min; harness: 458,287 subagent tokens, 137 tool uses). Work done in the engine copy `site/_work/n5b/engine/`.

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

N5B REPORT: drawing many games in one landscape

## Status

Items 1 to 4 and 6 are built and proven with pictures I looked at; item 5 is done as far as a flat ground with clean plot edges, and nothing more. All work is in my copy `C:\Users\kazda\kiro\third-life\site\_work\n5b\engine\`.

Final gates on the final files, each run alone: `tl.sh selftest` 73 passed, `k.sh selftest` 86 passed, `tl.sh seeds` 24 passed, 0 failed in each. Seed hashes are unchanged: bc93a9a4c892f2ab, b9adbb1967e36108, da4bdc3f65cc07ae. No git, no network; `world.gd` and `pack.gd` were not edited; none of my processes is left running.

Four things the Director should know first:

1. **Candidate A works and is kept.** An offset in the style shaders puts every pack at its plot, with shadows, ink lines, rigs, particles and multimesh forests, at no per-tick cost. Lights and foreign materials are mirrored with candidate B's code.
2. **The brief's "five plots 80 m apart" cannot hold.** Every seed brings its own 416 m terrain, forest and mesas, and the drive circuit alone is 114 m long. At 80 m the neighbours' trees stood on the paddle court. Each pack is now cut to a plot radius, and the world draws its own ground.
3. **Simulation is untouched.** Three runs of the hash check, the last on the final files: 5 of 5 packs hash as they do headless.
4. **I left an orphan window that spoiled timings for 43 minutes.** My first failed run (02:05) left an idle Godot window at 0,1440. It throttled every later window at that position to about 270 ms a frame whenever it lay above it. I found and stopped it at 02:48. It may have slowed other sessions' windows at 0,1440 in that time. Every timing below was taken after 02:48.

## The mechanism kept, and the evidence

Every style shader (toon, glass, water, holo, fx_add, fx_mix) has `instance uniform vec4 tl_plot` (xyz offset, w yaw). When it is not zero, `vertex()` uses `VIEW_MATRIX * plot * MODEL_MATRIX`. The draw layer sets it once per `GeometryInstance3D` when a pack is placed and again only when the stage changes. When it is zero, the engine's own matrices are used.

Two packs, 245 visuals in the non-stage pack, quiet window, median of 120 frames:

| set-up | draw calls | primitives | whole frame | draw layer per frame, one non-stage pack |
|---|---|---|---|---|
| A, kept (`--cull=auto`) | 169 | 1,865,342 | 1.551 ms | 0.023 ms |
| A, box refreshed every frame (`--cull=aabb`) | 163 | 1,863,454 | 1.591 ms | 0.111 ms |
| A, never culled (`--cull=margin`) | 181 | 1,941,518 | 1.547 ms | 0.008 ms |
| B, mirror instances | 165 | 1,971,454 | 1.664 ms | 0.149 ms |

- All four give the same picture.
- B costs 6.5 times A per frame, because a mirror must be followed by a GDScript loop over every visual. For 23 non-stage packs that is about 3.4 ms under B (extrapolated) against 0.4 ms measured under A. That is real but not decisive: B is affordable for a dozen near packs.
- What decides is the plot cut. It works in the pack's own coordinates, which A's shader still has. B puts the plot inside the mirror's model matrix, so B would need the plot passed to the shader anyway. `--mech=b` therefore draws whole packs, far scenery included.
- B does two things better: engine culling is exact with no help, and anything with a render instance moves.

Culling under A: the engine culls with the box where the pack is simulated, so each instance needs help.
- A still instance gets a `custom_aabb` around its drawn place, once.
- An instance under a moving body, a skeleton or a particle emitter is never culled.
- A slow watch (24 instances per pack per frame) moves any still instance that a script turned into the never-culled class. It promoted 30 in the five-plot world.

## Per item

All captures are in `C:\Users\kazda\kiro\third-life\site\_work\n5b\engine\kernel\world\draw\captures\`.

**1. The viewer.**
- `tools/view.sh shot` with the brief's options, plus `--radius`, `--yaw`, `--also`, `--crane`, `--standins`, `--far`, `--mech`, `--cull`, `--until=end`.
- It is its own main scene (`kernel/world/draw/view.tscn`, `view.gd`) because `host.gd` is not mine. It creates N2's world host and never passes `--at` to it.
- `view.sh` builds the class cache when `.godot/` is missing, and stops only its own processes after a timeout, found by a per-run tag.
- Proof: every picture below.

**2. The offset.** Three seeds plus `ex_kit` and `ex_walker` on five plots, radii 64/40/38/40/30 m, centres 100 to 110 m apart.
- `world_overview.png`: crane view, each pack at its plot.
- `world_from_seed_drive.png`: the car on its track, the paddle venue on the horizon over the rim.
- `world_from_seed_paddle.png`, `world_from_seed_wall.png`, `world_from_seed_wall_player.png`, `world_from_ex_walker.png`: the other stage packs, taken in the same process by re-basing. Only the stage pack's HUD shows.
- `t5_walker_close.png`: skinned rigs of a non-stage pack, with shadows.
- `rim_close.png`: a non-stage venue from 50 m, with lit windows, floodlight, chimney smoke and no step at the plot edge.
- `yaw_0_vs_90.png`: yaw of a non-stage pack is right.
- `foreign.png`: a `StandardMaterial3D` part of `bad_bypass` is counted and mirrored to its plot. That is one instance and one picture.
- `t3_overview.png`, `t3_from_paddle.png`: the wrong picture at 80 m with uncut packs.

**3. Hashes.** See the table below.

**4. Far games.**
- One merged mesh per far pack, built once when it first goes far. It keeps palette columns, vertex colours and part-local coordinates, so the same material and ink apply.
- Flat-colour kernel boxes go into surfaces of their own.
- Dropped: instances under 1.2 m, moving bodies, rigs, particles, lights, glass, foreign materials.
- Seed paddle goes from 86,446 to 13,072 triangles in 110 ms. Most of that is the plot cut; there is no decimation.
- `far_full_vs_standin_x3.png` (from `far_off.png`, `far_all.png`): ink lines are alike on full pack and stand-in at 200 m and at 500 m.
- `standin_full_vs_standin_near.png`: full against stand-in from 50 to 130 m.

**5. Landscape.**
- One `TLStyle.ground` sheet with the plots cut out of it.
- Each pack is lifted so the median height of its terrain at the plot edge meets the world's ground, and the last 9 m of its terrain are bent to that height.
- The drive seed lies in a hollow 7.6 m deep; the wall yard sits on a 2 m mound.
- Sky, sun and ground are drawn once. There are no hills, roads or forest between plots.

**6. Pictures for the owner.**
- `world_overview.png`, the `world_from_*.png` set, `world_12_packs.png`, `world_24_packs.png`.
- `world_vs_concept.png`: the concept beside `world_overview.png`.

**Single pack looks as it did.** One frame per seed through `tl.sh capture` against `look/after/`:
- paddle `court` f400: byte-identical.
- drive `chase` f110: PSNR 116 dB.
- wall `yard` f330: PSNR 54.6 dB. I looked at it and it is the same picture; my guess for the small difference is the shader clock driving dust and grass sway.

## Hash check

`bash tools/view.sh check` compares headless `world.sh run --mode=bot` with a windowed run to the end of every bot.

| pack | headless | drawn, run 1 (02:18) | run 2 (02:37) | run 3 (02:57, final files) |
|---|---|---|---|---|
| seed_drive | 36635c049bc6acd8 at 3516 | same | same | same |
| seed_paddle | cadd1cd9fffac7b1 at 6776 | same | same | same |
| seed_wall | 6366b88f838e3e78 at 1221 | same | same | same |
| ex_kit | 16db2bf1a53a1798 at 332 | same | same | same |
| ex_walker | 8d1831dc62dfe91a at 371 | same | same | same |

- All three runs: 0 gate leaks, 0 wrong-pack calls, 0 script errors, 0 engine errors, `PASS view.check`.
- Runs 2 and 3 had stand-ins on. Pictures: `check_from_paddle.png`, `check_from_wall.png`, `check_from_drive.png`.
- `check` runs without `--fixed-fps`, so a slow frame is followed by up to 8 ticks and the run stays bounded.

## Cost table

Packs on a 140 m grid cycling drive, paddle, wall, ex_kit, ex_walker, ex_car; every pack played by its bot; 1920x1080, Direct3D 12, RTX 4090. Stand-ins are `--standins=auto --far=200`. Frame time is the whole frame, simulation of every pack included. Taken 02:49 to 02:51 with nothing else of mine running.

| packs | camera | drawn | far packs | draw calls | primitives | objects | frame ms | render CPU ms | render GPU ms | draw layer ms |
|---|---|---|---|---|---|---|---|---|---|---|
| 6 | crane | full | 0 | 394 | 1,757,942 | 614 | 3.396 | 0.382 | 1.258 | 0.095 |
| 6 | crane | stand-ins | 3 | 202 | 788,680 | 393 | 3.356 | 0.335 | 0.903 | 0.039 |
| 6 | stage chase | full | 0 | 463 | 3,185,956 | 683 | 3.129 | 0.371 | 1.592 | 0.076 |
| 6 | stage chase | stand-ins | 3 | 266 | 2,213,734 | 459 | 2.975 | 0.303 | 1.385 | 0.045 |
| 12 | crane | full | 0 | 732 | 3,051,914 | 1,010 | 5.833 | 0.617 | 1.807 | 0.186 |
| 12 | crane | stand-ins | 11 | 65 | 524,434 | 238 | 4.697 | 0.270 | 0.879 | 0.009 |
| 12 | stage chase | full | 0 | 876 | 5,803,000 | 1,152 | 5.461 | 0.577 | 2.160 | 0.177 |
| 12 | stage chase | stand-ins | 9 | 206 | 2,225,128 | 384 | 5.216 | 0.356 | 1.395 | 0.039 |
| 24 | crane | full | 0 | 1,338 | 4,347,862 | 1,732 | 10.449 | 0.943 | 2.649 | 0.429 |
| 24 | crane | stand-ins | 23 | 62 | 418,358 | 235 | 9.141 | 0.365 | 0.906 | 0.016 |
| 24 | stage chase | full | 0 | 1,587 | 8,693,256 | 1,975 | 10.114 | 0.984 | 2.779 | 0.389 |
| 24 | stage chase | stand-ins | 21 | 262 | 2,325,614 | 467 | 9.654 | 0.498 | 1.460 | 0.058 |

- Stand-ins cut draw calls by 1.7 to 22 times and primitives by 1.4 to 10 times.
- The frame time barely moves, because most of it is the simulation of the packs, which a stand-in does not stop.

## What a pack author must know

- Nothing changes for a pack that follows API.md and takes every material from the style.
- Your pack is a venue, not a landscape. In a world it is cut to a circle; your terrain beyond it, your forest and your cliffs are not drawn. Keep what matters inside the radius and leave 9 m free at the edge.
- A material of your own is drawn at the right place, but it is not cut to the plot, is missing from the far stand-in, and costs work every frame.
- At a distance your pack is one still picture of itself: no moving parts, lights or particles.
- Do not use instance shader parameters or metas named `tl_plot`, `tl_clip`, `tl_draw`, and do not read `visible` of your nodes for game state: a far pack is hidden.
- Your HUD and cameras show only while the player is in your pack.

This is DRAW.md section 10. I did not edit `kernel/API.md`.

## Contents of PATCHES.md

None applied; the viewer works with the files as they are. Full text is in `kernel/world/draw/PATCHES.md`.

1. **`pack.gd` `load_pack` and `world.gd` `start`.** A pack is told whether it is on stage before its scripts load.
   ```
    	ctx.origin = options.get("at", Vector3.ZERO)
   +	ctx.on_stage = bool(options.get("on_stage", true))
   ```
   and in `world.gd`: `"on_stage": i == int(opts.get("stage", "0"))` added to the options of `load_pack`. Without it, every pack's first view takes the camera during the load; the viewer corrects it afterwards.

2. **`kernel/api/tl_hud.gd` `create`.**
   ```
    		TLContext.current.huds.append(h)
   +		h.visible = TLContext.current.on_stage
   ```
   The viewer polls every frame for HUDs a non-stage pack made late.

3. **`world.gd` `_end`.**
   ```
   +signal ended(bad: bool)
   +var quit_on_end: bool = true
   -	get_tree().quit(1 if bad else 0)
   +	ended.emit(bad)
   +	if quit_on_end:
   +		get_tree().quit(1 if bad else 0)
   ```
   A world with a player must outlive its bots.

4. **`host.gd` `MODE_OPTIONS` and `verbs.json`.** A `world-view` mode with the viewer's option list, so the viewer starts through the host. The host builds the class cache and retries a window that died; I had to repeat both in `view.sh`.

5. **`pack.gd` `at` and `ctx.origin` (proposal).** Keep `at` for the bench only; add a read-only `ctx.plot: Transform3D` set by the draw layer.

6. **`manifest.gd` and `pack.json` (proposal).** `"footprint": {"radius": 64}`. Tonight every radius is a number I chose by eye.

7. **`lint.gd` (proposal).** Count geometry whose material is not a style material as a composability finding.

## What is still wrong in the picture against the concept

- The plain between the venues is flat and empty: no hills, road, river, bridge or forest. Far scenery is not drawn at all.
- The venues sit as round discs. The edge is seamless in height, but still shows as a change of tone and as a mound or hollow.
- The concept puts rink, track and house in one view; my plots are 100 m and more apart, so from the crane they are small and the haze eats the far ones.
- The world ground shows large square mottle patches from the air.
- Seen from far at a grazing angle, small ink marks appear along the bent rim of a plot (`far_off.png`).
- The crane picture carries the stage pack's HUD (`--hud=off` removes it).
- There is no construction, holograms or working robots; that is content, not drawing.

## Limits and what I did not verify

- **Stage pack with yaw.** The sun rig is not turned with the world. Every picture uses yaw 0 on stage.
- **Glass, water and hologram shaders.** `tl_plot` was added to all three and `ex_kit` ran as a non-stage pack with no engine errors, but I do not know whether it draws any of them, and I looked at no close picture.
- **Untested node types.** `GPUParticles3D`, decals, fog volumes and reflection probes: no pack uses them.
- **Foreign materials.** One instance, one picture.
- **Primitives.** A pack's whole terrain and forest are still submitted and run through `vertex()`; only fragments are saved. The five-plot world draws 2.6 to 3.3 million primitives.
- **Merged meshes at the rim.** Something merged in pack coordinates that stands in the 9 m band floats or sinks by the bend. Bending it per vertex sheared a house and a crane, so it is left alone.
- **Stand-ins are never rebuilt.** A knocked-down wall stands again at a distance.
- **Not looked at.** Shadows beyond the style's 300 m distance; more than 32 plots with terrain; mouse and keys in a drawn world.
- **Earlier gate failure.** The first `tl.sh seeds` run failed 6 of 24, all 250 ms watchdog stalls in headless verbs while three of my jobs ran beside it. Alone it passed 24 of 24.
- **Side effects in the copy.** Godot created `.godot/` and `.uid` files for my two scripts.

## Files

- New: `kernel/world/draw/draw.gd`, `view.gd`, `view.tscn`, `DRAW.md`, `PATCHES.md`, `JOURNAL.md`, `captures/` (with a `.gdignore`); `tools/view.sh`.
- Changed: `style/shaders/toon.gdshader` (`tl_plot`, `tl_clip`, `tl_holes`); `glass`, `water`, `holo`, `fx_add`, `fx_mix` (`tl_plot`); `style/STYLE.md` (a note on the three parameters).
- Not touched: `kits/**`, everything else.

## Questions

1. Who declares a pack's plot radius: the pack (`footprint` in `pack.json`), or the world?
2. Should the kit build no far terrain sheet and no forest beyond the plot when a pack is built for a world, with the world owning the landscape between venues? That would remove most of the primitives and is the way to hills and roads.
3. Should the scheduler pause far packs? Stand-ins save drawing but the frame time is mostly simulation.
4. Is yaw on plots wanted now? If so the sun rig and `g_sun_dir` must be turned per stage.
5. `toon.gdshader` was changed by N1 tonight and by me; does the Director merge it three ways?

## Minutes

Started 01:55:24, finished 03:00 (from `date`): 65 minutes of the 90.

---

## Director verification

Done 03:01 to 03:22 on 2026-11-11, after the builder had stopped: in the builder's copy, then on the main tree after
merging its files and, separately, the scheduler builder's (N5a).

### What was re-run, and the result

| Check | Result |
|---|---|
| `view.sh check` in the copy: five packs (three seeds, `ex_kit`, `ex_walker`) drawn in one world, each played by its bot to the end | every pack's hash with drawing on equals its headless hash; 0 gate leaks, 0 wrong-pack calls, 0 script errors, 0 engine errors |
| the Director's own picture: `view.sh shot --packs=seed_wall,seed_drive,seed_paddle --stage=0 --cam=player --frame=700` | the wall yard as the stage pack, drawn as in a single-pack run, HUD of the stage pack only |
| after the merge, with N5a's scheduler in `world.gd` and `pack.gd`: `view.sh check` on the main tree | passes with the same five hashes: the drawing layer works on the new world host unchanged |
| after the merge: `tl.sh selftest`, `tl.sh seeds`, `item.sh selftest`, `k.sh selftest` | 77, 24, 91 and 86 passed, 0 failed |
| after the merge: `tl.sh capture` of `seed_paddle` `court` frame 400 | byte-identical to the frame taken before any world work |

**Looked at:** `captures/world_overview.png`, `world_from_seed_drive.png`, `world_12_packs.png` (builder's), and the
Director's own shot and overview.

### What the Director saw

- From inside a game the result is convincing: the car on its track, shadows and ink as in a single-pack run, another
  venue on the horizon beyond the rim.
- From above it is not yet a landscape. Venues are round discs on a flat, hazy plain, 100 m and more apart; there are
  no hills, roads, water or forest between them. Twelve games read as twelve small islands. The concept puts a rink, a
  track and a house in one composed view.
- The mechanism is the finding: an offset in the style's own shaders, set once per instance, costs 0.02 ms a frame for
  a pack of 245 visuals and leaves simulation untouched. The picture is now a content and layout problem.

### What is not verified

A stage pack with yaw; glass, water and hologram parts of a non-stage pack seen close; more than one foreign-material
instance; the cost table (taken by the builder after it removed its own orphan window; not re-measured); mouse and keys
in a drawn world.

### Director's decisions on the builder's questions

1. A pack declares its plot through `footprint` in `pack.json` (it exists since N4); the world may give it more room.
2. Yes: in a world a pack brings no far terrain and no forest of its own; the world owns the landscape between
   venues. N5a's `scenery = "plot"` already loads packs that way and becomes the default for worlds.
3. No: the owner ruled that far games run in slow motion and are never paused. The scheduler slices them; a stand-in
   only saves drawing.
4. Yaw on plots waits for the landscape work.
5. No three-way merge was needed: the copy was taken after N1's shader work.

Merged into the main tree by file: the six style shaders, `style/STYLE.md`, `kernel/world/draw/**` (without the 94 MB
of captures, which stay in the builder's copy), `tools/view.sh`. Not applied yet: the builder's patches 1 to 4
(`on_stage` at load, HUD visibility, a world that outlives its bots, a `world-view` mode in the host): they belong to
the step that joins scheduler, drawing and a walking player.
