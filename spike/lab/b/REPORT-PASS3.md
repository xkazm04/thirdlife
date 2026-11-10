# Lane B, pass 3: builder report and Director verification

Builder: fresh agent `aecf508afdc9a7755` (no memory of passes 1-2), brief `spike/lab/BRIEF-B-PASS3.md`.
Wall time 15:56 to 17:19 CEST on 2026-11-10 (83 min). The builder cannot write report files; the text below is its
final message, saved by the Director. The Director's own verification is the last section.

---

## Builder report (verbatim)

**Status: pass 3 done.** Parts A, B, D and C are complete, and the journal is current. The final `tools/g.sh pass3` run
took 260 s with no error, leak or FAIL line; the play test passes 16 of 16 on main, alt and layout C. I stopped at 17:20
because the list was finished, not because of the time-box.

All paths below are under `C:/Users/kazda/kiro/third-life/spike/lab/b/`.

Four things to know first:
- **I ran one git command by mistake.** A read-only `git diff --stat` in the lane directory while counting lines. It
  printed nothing (the lane is not a repository) and changed nothing.
- **Layout C needed code.** The frozen run rendered, but its play test crashed and four of the brief's nouns could not be
  expressed. I then made seven edits (about 45 lines), listed in section 5.
- **GPU time went up slightly**, although draw calls fell 75 %.
- **Nobody has hand-played it.** I did not open an interactive window, to avoid grabbing the mouse on the owner's machine.

### 1. What Part A found

**Exit-time leaks: cause found and fixed, filter removed.**
- `world.gd` took `.mesh` from kit parts that return a `MeshInstance3D` (rink, stands, four scaffolds, house, frame: 8
  nodes) to feed the static merge, and never freed the nodes.
- Each orphan node kept its mesh, that mesh's materials and the toon and glass shaders alive until exit. That accounts for
  the 8 meshes, 23 materials, 2 shaders, 8 instances, 41 ObjectDB instances and 2 resources.
- It was not the style autoload or cached materials.
- Fix: `World._take()` returns the mesh and frees the node.
- `tools/g.sh` has no noise filter now; its pattern passes `leaked` and `still in use` lines, so a regression would show.

**Movie slowdown: not a pass-2 feature.**
- Inside a slow recording, script time is 3-5 ms and render CPU 1 ms per frame, while wall time is 400-550 ms per frame
  and Godot uses under half a core. It is waiting.
- Bisecting by feature was inconclusive: the same build ran at both speeds.
- It is not the disk (1.8 GB/s; same result writing to `%TEMP%`).
- It follows another session's exported Godot benchmark, `RTAI-bench.exe`, which runs in rounds. Over five runs of the
  same 2 s clip: 9 s, 9 s and 9 s with it absent or just starting, 69 s and 65 s with it running throughout.
- `tasklist | grep godot` never showed it, because the exe is not named Godot.
- This is a correlation plus the in-run profile. That the stall is the movie writer's per-frame GPU readback is my
  inference; I did not read Godot's source.
- `g.sh movie` now waits up to 150 s for that process to exit and prints the recording speed. A quiet recording takes
  56 s (35 % of real time); `g.sh all` took 190 s.

**Normal play is not affected, and the `gpu_ms` rise from 1.43 to 1.60 is a different thing.**
- On a quiet machine, turning off detail, hatch or window lights changes nothing measurable. The grade costs 0.055 ms and
  the ink pass about 0.3 ms, as in pass 1.
- The rise is geometry: about 96 k more primitives per frame through four shadow cascades, and 16 more bytes per vertex.

**Alt layout.** Play test 16 of 16 on the first run; all five cameras captured. Looking at them found two defects, both
fixed in data:
- the hero tree stood behind the avatar in the `avatar` frame;
- the house roof poked through the ridge grass, as on main.

**Map and overcast.** `b_map.png` is regenerated. The overcast hero is cool and misty with the ink intact; the mesas
reduce to outlines in the fog. Only the main-layout overcast hero was looked at; alt and C were not viewed in overcast.

### 2. Captures

All in `captures/`.

| File | What it shows |
|---|---|
| `b_hero.png` | Avatar at a real cliff edge; whole valley visible; butte with waterfall, river, stone bridge; house complete with its extension; two cars; sun in frame. |
| `b_site.png` | Same camera as pass 2; weld light pools; butte and bridge at the right edge. |
| `b_track.png`, `b_crumble.png` | Wall large in the foreground, both cars. At 1.5 s the slabs, core faces and rebar are readable through a thin warm haze. |
| `b_avatar.png`, `b_avatar_front.png`, `b_avatar_back.png` | 3/4, front, back. |
| `b_avatar_faces.png` | Happy, focused, blink. |
| `b_pass3_compare.png` | Pass 2 (left) against pass 3 (right): hero, site, avatar, crumble. |
| `b_pass3_material_crops.png` | Before and after crops at distance: roof, arena, track. |
| `b_alt_hero/site/track/crumble/avatar.png` | Alt layout, all five cameras. |
| `b_c_hero/site/track/crumble.png` | Layout C after the code edits. |
| `b_c_hero_frozen.png`, `b_c_site_frozen.png`, `b_c_track_frozen.png` | Layout C with the code frozen. |
| `b_hero_overcast.png`, `b_map.png`, `b_movie.mp4` | Overcast swap, top view, 20.0 s movie. |
| `b_site_adv.png`, `b_nitro.png`, `b_bot.png` | Regenerated extras. |
| `pass2_orig/` | The 16 pass-2 PNGs, copied before any change. |

`b_hero_2split.png` and `b_pass2_compare.png` are pass-2 leftovers.

Best frame: `b_hero.png`. Weakest: `b_track.png` (flat road, plain grass).

### 3. Performance

One-liner from the final run:
```
{"lane":"b","gpu":"NVIDIA GeForce RTX 4090","res":"2560x1440","fps_avg":547.4,"frame_ms_p50":1.85,"frame_ms_p99":1.85,"draw_calls":197,"primitives":1431152,"vram_mb":746.4,"gpu_ms":1.68,"cpu_render_ms":0.277,"style":"golden","ink":true,"frames":8208}
```

Measured at 2560x1440 with the other session's benchmark absent before and after each run in the table.

| Config | Draw calls | Primitives | gpu_ms | cpu_render_ms | VRAM MB | fps_avg |
|---|---|---|---|---|---|---|
| Pass 2, start of pass 3 | 778 | 1,365,044 | 1.595 | 0.58 | 801.1 | 560 |
| After Part B, one material per key | 839 | 1,383,640 | 1.621 / 1.637 | 0.55 | 807.9 | 559 / 543 |
| After Part B, one material | 197 | 1,383,640 | 1.559 / 1.567 | 0.28 | 743.2 | 582 / 580 |
| Final, one material (default) | 197 | 1,431,152 | 1.664 / 1.701 | 0.28 | 746.4 | 552 / 540 |
| Final, `--permat` | 849 | 1,431,152 | 1.714 | 0.55 | 810.2 | 536 |
| Final, `--noshadow` | 74 | 426,772 | 1.299 | 0.22 | 616.5 | 688 |
| Final, 1920x1080 | 197 | 1,431,152 | 1.201 | 0.28 | 529.4 | 743 |

- **One material:** draw calls down 77 %, CPU render time halved, VRAM down 65 MB, GPU down about 0.06 ms. The picture is
  unchanged (side-by-side looked at).
- **Net for pass 3:** draw calls down 75 %, but GPU up 0.07-0.10 ms. More primitives go through four cascades (rounded
  avatar and bots, bridge, butte, road markings), plus four spot lights and the bounce and pool terms. Run-to-run spread
  on `gpu_ms` is about 0.05.
- **What one material cost in flexibility:**
  - A per-material value must be one of 13 lookup scalars; a new kind of parameter is a lookup row plus a shader line,
    not a JSON key.
  - The rink markings exist once, so a scene cannot have two marked rinks.
  - Glass, water, hologram and particles still need their own materials.
  - The palette column is baked into vertices, so re-colouring one part means rebuilding its mesh.
- **Estimate, not measured:** a GTX 1660 / RX 580 class card at 1080p would land at roughly 8-10 ms GPU, assuming it is
  6.5-8.5 times slower than the 4090's 1.2 ms.
- Scene: 435,006 triangles (avatar 9,434, was 2,718; bots 1,908 each, ten of them); 29 scripts and shaders, 4,959 lines.

### 4. Rubric

| Criterion | Pass 2 | Pass 3 | Evidence |
|---|---|---|---|
| Silhouette readability | 4 | 4 | Did not move. The cliff edge improves the hero's read, but bots are still about 25 px tall there. |
| Material richness | 3 | 4 close up, 3 at hero distance | `b_pass3_material_crops.png`: roof courses, chimney stone and steel plates gained; arena concrete and the road are still quiet. `b_avatar_front.png`: the jacket reads as quilted. |
| Atmosphere / lighting | 4 | 4, upper half; not a 5 | Hero: shade follows the normal, shaded walls take a warm bounce, visible light pools under the mast, at the welds and by the porch. Sky and haze are still simpler than the gouache reference, and the pools are hard-edged discs. |
| Character appeal | avatar 3, bots 4 | avatar 4, bots 4 | `b_avatar_front.png`, `b_avatar_faces.png`: moulded forms, round eyes, blink, two expressions. |
| Destruction readability | 4, weakly held | 4, solid | `b_crumble.png`: break fully readable at 1.5 s. Not 5: slabs are similar in size, no flying debris. |
| Cross-asset consistency | 5 | 5 | Did not move. |
| Reads as a shipped indie game | 4 hero/site, 3 track/crumble | 4 hero/site, 4 crumble, 3-4 track | `b_pass3_compare.png`. |

### 5. Layout C

**Frozen run.** Code was frozen at 16:44 (hash `ad5556f4b6076ec4`, unchanged after the run). The layout took 6 minutes
and one version to write.
- Hero, site and track rendered first time with no error: an open-air rink with bots on the ice, a 250 m oval, one house,
  no cranes.
- The play test passed 6 of 16, then crashed at the `site_advance` step (`look.gd:363`: it reads the first hologram rib
  and there is none) and repeated the error every frame.
- That version is kept as `data/layout_c_frozen.json`.

**What the file could not express:**
- three houses (the schema has one);
- a long wall (exactly 12 blocks in code);
- no stands (`rows: 0` still built the rear wall);
- a pond (no still-water or pond-ice part);
- a dense forest edge (scatter counts and thresholds are constants; the file can only remove trees);
- a speedway (road width, banking and height profile are fixed);
- car count;
- no river (the key was mandatory, so the layout carried one it did not ask for).

**Code edits made after the frozen run** (3 minutes, all optional keys; main and alt unchanged):

| # | File | Edit | Lines |
|---|---|---|---|
| 1 | `look.gd` | Play test handles a layout with no hologram rib | 5 |
| 2 | `world.gd` | `houses[]` list | 12 |
| 3 | `world.gd` | `rows: 0` builds no stands | 1 |
| 4 | `sim.gd` | `circuit.wall_blocks` | 5 |
| 5 | `world.gd` | `forest {density, edges}` | 7 |
| 6 | `world.gd` | `river` optional | 1 |
| 7 | `kit_site.gd` | `add_pond`, prop `pond`, palette key | 13 |

After them, `layout_c.json` has three houses, a 30-block wall, a frozen pond under the rink and a dense forest edge; play
test 16 of 16. Still code: stand side, road width and banking, car count, skating bots.

**What it proved.** The shape of a venue (what, where, how big, what is absent) is data and loaded first time. Every
quantity or variant the first two layouts had not needed was a constant in code. Each fix was 1-12 lines, so the schema is
cheap to widen. But an agent that could only write the layout file would have delivered one house, a 12-block wall and a
crashing test.

### 6. Still weaker than the references

- **Line work:** the references have drawn detail everywhere; ours is outlines plus sparse, regular procedural marks.
- **Terrain and foliage:** flat grass with tufts and cone-stack trees, against layered cliffs, paths and clumped painted
  foliage.
- **Sky:** simple cloud shapes and a blotchy paper grain, against painted cloud bands and haze layers.
- **Site:** bots are still small in the hero, and scaffolding density is below the concept.
- **Road and arena concrete:** quiet at hero distance.
- **River:** far and simple; the low-poly reference has it in the foreground.
- **Light pools:** flat discs.
- **Destruction:** no debris in flight.
- **Avatar:** still a block toy, with no cloth folds.
- **Walking:** terrain following has no slope limit, so the avatar can walk straight down the cliff. Main has one grass
  ramp at x = -26; alt and C have none.

### 7. Ledger

Minutes come from real timestamps. A round is a sheet I looked at and then changed something.

| Work | Min | Rounds |
|---|---|---|
| Orientation | 6 | 2 sheets |
| A1 leaks | 2 | 2 runs |
| A2 movie slowdown | 19 | 13 timed runs |
| A3 + A4 alt, map, overcast | 4 | 2 |
| B visible defects | 15 | 5 |
| D1 one material | 6 | 1 + 4 stats runs |
| D2 frozen layout / edits and data | 6 / 3 | 1 / 3 |
| C2 avatar | 6 | 3 |
| C1 lighting | 3 | 3 |
| C3 material at distance | 2 | 2 |
| Late additions (car rewind for timed captures, road markings, ramp) | 2 | 1 |
| Verification, acceptance runs, stats, docs | 23 | n/a |

Total: 83 minutes of wall time (15:56 to 17:19), about 30 sheets looked at, 24 rounds. Token cost is not measurable from
inside. (Harness figures for the builder agent: 486,387 subagent tokens, 151 tool uses.)

Other changes worth knowing: `README.md` and `KIT.md` are updated; `tools/g.sh` gained `altfull`, `c`, `faces` and
`pass3`. Arena, circuit, wall, crane and house positions are unchanged. What moved is layout data: the ridge (1.8 m
forward, now a cliff), the river, the house extension (to the far end), the hero, track and avatar cameras, and the bot
count (now ten).

### 8. Questions for the Director

1. `tools/g.sh movie` names another project's exe (`RTAI-bench.exe`) as the default of `BUSY_EXE`. Keep it, or make the
   default empty and document the variable?
2. Is the cliff acceptable for the owner's hand-play as it is (one ramp on main, free walking down the face), or do you
   want a slope limit and ramps on alt and C?
3. Site light pools are a taste call: energy 1.7 with hard two-band edges. Keep the bands or soften them?
4. After layout C, the next useful step looks like a schema with a validator and a stated list of what a layout can
   express, rather than more parts. Do you want that in this spike?
5. The rounded forms cost triangles (avatar 2.7 k to 9.4 k, ten bots at 1.9 k). Accept, or should bots get a cheaper far
   version?

---

## Director verification

Done 17:21 to 17:30 CEST, after the builder had stopped. The builder's frames were first copied to
`captures/director/pass3_builder/` (29 PNGs), then the Director ran everything again from a clean start.

### What was re-run, and the result

| Check | Result |
|---|---|
| `bash tools/g.sh pass3` (all + altfull + c + faces + avatar front/back + map) | 293 s, 117 log lines, no `ERROR`, `leaked`, `still in use` or `FAIL` line |
| Play test, main layout | 16 of 16 PASS |
| Play test, `--layout=alt` | 16 of 16 PASS |
| Play test, `--layout=c` | 16 of 16 PASS (see the caveat below) |
| Raw, unfiltered capture run (Godot called directly, no `grep`) | banner, `[world]` line, `captured` line, nothing else: the exit-time leak lines are gone |
| Raw, unfiltered `--play-test --layout=c` | ends on `RESULT PASS`, no exit errors |
| Movie | 20.000 s (ffprobe), recorded in 49 s = 40 % of real time, `RTAI-bench.exe` not running |
| Stats, default (single material) | `draw_calls 196, primitives 1,431,150, gpu_ms 1.66, cpu_render_ms 0.314, vram_mb 746.4, fps_avg 550.6` |
| Stats, `--permat` | `draw_calls 849, gpu_ms 1.702, cpu_render_ms 0.76, vram_mb 810.2` |
| Stats, default, second run | `draw_calls 196, gpu_ms 1.711, cpu_render_ms 0.389, fps_avg 421.6` (noisier machine) |

So the claims that can be checked hold: the leak fix, the filter removal (`FILTER` is now an allow-list that passes
`ERROR`, `leaked` and `still in use`), the movie speed on a quiet machine, the three play tests, and the draw-call cut from
849 to 196. `gpu_ms` did not fall with the draw calls: 1.66 to 1.71 against 1.62 at the end of pass 2. The single
material is a CPU and VRAM saving on this GPU, not a GPU-time saving.

### What could not be re-checked

- **The frozen-code crash of layout C.** Code edit 1 changed the play test so that a layout without a hologram rib no
  longer crashes, so the 6-of-16-then-crash result cannot be reproduced from the current tree, and the lane has no git
  history. The freeze hash is also the builder's word. What is checkable: `data/layout_c_frozen.json` exists (69 lines,
  only pre-freeze keys), `captures/b_c_*_frozen.png` exist with 16:49 timestamps, and the seven edits are in the source
  with `layout C edit` comments (`world.gd:64, 229, 396`, `sim.gd:53`, `kit_site.gd:385`).
- **The movie-slowdown cause.** The Director's run was fast with the other benchmark absent, which is consistent with the
  builder's finding but does not prove it. The cause stays "correlated with another GPU process", as the builder said.
- **Hand play.** Nobody has driven it by hand in any of the three passes.

### Caveat on the layout-C play test

Two of its sixteen assertions are vacuous on a layout with no hologram rib: `site_advance: nothing to build in this
layout, no error` and `reset: rib is a hologram again`. The honest count for layout C is 14 real assertions and 2 that
only prove nothing crashed.

### What the Director saw in the frames

Sheets: `captures/director/p3_main.png`, `p3_c.png`, `p3_alt.png`, `p3_avatar.png`, `p3_cfrozen_over.png`,
`pass3_ref_vs_hero.png`, and the builder's `captures/b_pass3_compare.png`.

- **All five pass-2 defects are fixed.** The waterfall reads as falling water on a butte with a river and a stone bridge
  below it. At 1.5 s the collapse shows slabs, core faces and rebar with only a thin haze. The house and its timber
  extension are whole in the hero. The roof no longer pokes through the ridge. The dashes on foreground grass are gone.
- **Hero** is the best frame of the three passes: avatar on a cliff edge, the whole valley readable, two cars, long warm
  shadows.
- **Layout C** is recognisably a different place made from the same kit: three lit houses, an open rink on a pale pond, a
  dense forest wall, no cranes, a longer barrier wall. The frozen version already had the open rink, the oval and no
  cranes; it lacked the pond, the second and third house and the forest density.
- **Overcast** works as a mood swap from one style file: cool, misty, ink intact.

Defects the Director sees that remain:

1. **Light pools are hard-edged yellow discs**, most visible on grass by the house porch and around the avatar in the alt
   hero. They read as a decal, not as light.
2. **The face is the weakest thing on screen** (`b_avatar_faces.png`): blocky mouth, eyes slightly skewed, cheeks
   uneven, and the blink leaves a white sliver. From behind and in three-quarter view the avatar is good. The Director
   scores the avatar 3.5, not the builder's 4.
3. **Against the reference** (`pass3_ref_vs_hero.png`) the frame is lower in contrast and saturation (a violet haze over
   everything) and far lower in density: the concept has two cranes, a dozen bots at readable size, scaffolds, stacks,
   fences and cliffs with drawn detail. Composition and mood match; density and line detail do not.
4. **Bots are still tiny in the hero**, although they read well in the site frame.
5. **The track frame is plain**: flat road, flat grass, shadows of unseen trees across the foreground.
6. **In the layout-C hero the avatar stands in front of the rink**, and the right-hand house sits partly below the ridge
   lip. Both are camera and placement choices in the layout file.

### Director's reading of the scores

The builder's rubric is fair except for the avatar. Where it stands after three passes: silhouette 4, material 3 to 4,
atmosphere 4, avatar 3.5, bots 4, destruction 4, consistency 5, "shipped indie game" 4 on hero, site and crumble.
Nothing reached 5 except consistency. The gap to the concept art is now mostly **content density and drawn detail**, not
technique.

### Answers to the builder's questions

1. `BUSY_EXE` should default to empty and be documented: a lane script should not name another project's executable.
   Not changed yet.
2. The cliff is acceptable for a look test. A slope limit belongs to the kernel work, not to this lane.
3. Soften the light pools: the hard discs are defect 1 above.
4. Yes, and it is the main finding of this pass: a layout schema with a validator and a stated list of what it can
   express. It belongs in the spike plan (Phase 0), not in the art lane.
5. Accept the triangle cost for now; 435 k triangles is far inside budget.

### Totals across the three passes (lane B)

| Pass | Builder wall time | Scripts and shaders | Lines | Triangles | Draw calls | gpu_ms at 1440p |
|---|---|---|---|---|---|---|
| 1 | about 57 min | 28 | 3,876 | 404,534 | 802 | 1.49 |
| 2 | about 38 min | 32 | 4,538 | 414,946 | 778 | 1.62 |
| 3 | 83 min | 29 | 4,959 | 435,006 | 196 | 1.66 to 1.71 |

About three hours of builder time in total, all GDScript generated at load time, no Blender and no hand-made asset.
