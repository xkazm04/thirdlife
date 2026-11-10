# Lane B report: inked low-poly with painterly atmosphere (pass 1)

Provenance: sections 1-9 are the builder's text, saved verbatim by the Director on 2026-11-10 because the harness blocked the builder from
writing this file. The Director's independent verification is the last section and is the only part not written by the builder.

## 1. Result in five lines
- **Runs:** yes. `tools/g.sh all` produces the five captures, the overcast hero, `--stats` and the movie in about 2 min 13 s. `crumble`, `nitro_pass`, `site_advance` and the chase camera were each checked by a capture; `reset` is implemented but was never exercised.
- **Looks good:** yes for a first pass. It reads as one coherent inked, golden-hour, low-poly world, but it does not reach the density or hand-drawn richness of the concept art.
- **Proud of:** the hologram ribs and the hologram-to-built dissolve, long violet shadows over warm ground, and an avatar and bots that read clearly from simple boxes.
- **Weak:** terrain and sky are plain, bots are about 10 px in the hero, the fracture pattern is a regular lattice, and the avatar does not collide with props.
- **Verdict:** lane B is achievable and cheap, and a plausible production look; character treatment and scene density are the open gaps.

## 2. Captures
| File | Caption |
|---|---|
| `captures/b_hero.png` | Avatar lower-left, arena with built ribs 3-5 and hologram ribs 6-8 upper-left, circuit and wall right, house lower-right, sun in frame. |
| `captures/b_site.png` | About 22 m from the rib line: scaffolds, a welding bot with sparks, idle bots facing camera, hologram ribs. **Best frame.** |
| `captures/b_track.png` | Car A (blue) and car B (red) at the bend, 8 of the 12 barrier blocks in frame. |
| `captures/b_crumble.png` | Same camera 1.5 s after `crumble`: 96 chunks flying and piling, inked dust puffs, far blocks intact. **Worst of the five** (rubble reads as bricks). |
| `captures/b_avatar.png` | Rear-left 3/4: hologram tablet, profile, backpack light, car and wall beyond. |
| `captures/b_hero_overcast.png` | Hero with `--style=overcast`, data only. |
| `captures/b_movie.mp4` | 20 s: hero (site_advance at 2 s), site (second at 6.5 s), track (nitro 11.6 s, crumble 12.6 s), avatar. |
| Extras | `b_site_adv.png` (rib 6 about 60% built, bots at its foot), `b_nitro.png`, `b_bot.png`, `b_avatar_front.png` (face), `b_avatar_back.png`, `b_map.png`. |

## 3. Performance
Measured with `--stats`: 15 s of the hero view, first 40 frames dropped, vsync off. RTX 4090, one run per configuration, other sessions on the machine, so all numbers are indicative. One run was a clear outlier (99.6 fps) while another project's tests were running. The p50 sits at 1.67 ms in almost every run, which looks like a cap or quantisation near 600 fps, so `gpu_ms` is the more trustworthy column.

| Config | fps_avg | p50 ms | p99 ms | draw calls | primitives | VRAM MB | gpu_ms | cpu_render_ms |
|---|---|---|---|---|---|---|---|---|
| 2560x1440 golden (final) | 575.4 | 1.67 | 1.85 | 796 | 1,268,772 | 780.1 | 1.432 | 0.751 |
| 2560x1440 overcast | 544.9 | 1.85 | 3.33 | 803 | 1,268,684 | 780.1 | 1.560 | 0.731 |
| 1920x1080 golden | 630.8 | 1.67 | 1.85 | 802 | 1,269,920 | 563.1 | 1.066 | 0.680 |
| 1440p ink on (A/B pair, earlier scene) | 568.9 | 1.75 | 1.86 | 758 | 1,460,600 | 784.1 | 1.478 | 0.753 |
| 1440p ink off | 579.4 | 1.67 | 1.85 | 787 | 1,463,106 | 693.8 | 1.183 | 0.749 |
| 1440p no shadows | 744.1 | 1.39 | 1.39 | 205 | 443,056 | 654.2 | 1.110 | 0.457 |
| 1440p, 10 s after crumble, 96 sleeping bodies | 485.4 | 2.08 | 2.38 | 1,563 | 1,469,868 | 784.1 | n/a | n/a |
| 1440p, 10 s after crumble, rubble baked | 602.1 | 1.67 | 1.85 | 803 | 1,469,868 | 784.3 | n/a | n/a |

- **Ink pass:** about 0.30 ms GPU and about 90 MB VRAM at 1440p, from one A/B pair.
- **Shadows** are the main cost: four cascades on an 8192 atlas take draw calls from about 205 to about 800.
- **Crumble settling:** all chunks sleep within 2.9 s. Left as 96 separate meshes the frame stayed at 2.08 ms; the sim now bakes sleeping rubble into one mesh and the frame returns to the 1.67 ms baseline.
- **Scene size:** 404,534 triangles, of which 254,080 are instanced scatter. Generation at load takes 2.0 to 2.6 s.
- **Estimate, not measured, for 1080p on a GTX 1660 / RX 580 class GPU:** assuming it is 6 to 8 times slower than a 4090 here, about 6.5 to 8.5 ms GPU plus an assumed 2 to 3 ms CPU, so roughly 85 to 120 fps. I would halve the shadow atlas and merge static meshes for that class.

## 4. Authoring ledger
Minutes are reconstructed from file modification times, capture timestamps and the journal, good to about two minutes per row. Rows overlap, so treat them as upper bounds. A round is a capture I looked at and then changed something. Everything was written in GDScript and Godot shaders.

| Asset / system | Min | Rounds | Triangles | Hand-fixes |
|---|---|---|---|---|
| MeshKit core | 4 | 1 | n/a | cone winding; later additions for material override and fixed UV |
| Style data and loader | 5 | 7 | n/a | band thresholds for a low sun, sun azimuth, fog twice, greens |
| Toon shader | 4 | 3 | n/a | local-light branch, ice shine |
| Ink (from gtai), sky, grade, glass, water, fx shaders | 4 | 2 | n/a | haze-tinted ink and distance fades |
| Hologram shader and dissolve | 2 | 3 | n/a | purlin bars blown out twice |
| Path, terrain, road, river | 11 | 7 | 74,158 + 5,172 + 168 | road never carved the terrain (packed-array copy bug); ridge reshaped twice |
| Arena: rink, stands, ribs, footings | 4 | 3 | 2,496 + 19,688 + 9,192 + 1,408 | ribs shifted half a bay to clear crane B; seat chamfers removed (was 69,608) |
| Cranes, scaffolds, props | 4 | 3 | 6,336 + 4,564 + 5,904 | scaffolds moved to the rib feet |
| Nature and scatter | 6 | 6 | 256,432 | grass size, sight-line exclusions, hero tree moved 4 times |
| House, timber frame, yard | 3 | 2 | 2,236 + 1,316 + 1,960 | none |
| Rig, biped, three clips, tablet | 6 | 5 | 2,104 | arm yaw signs, hair redone, open tablet frame |
| Bot and three clips | 2 | 3 | 1,148 each, 7 bots | flash size, facing |
| Car and nitro | 3 | 3 | 826 + 4 x 88 | trail density, start offsets |
| Wall, crumble, rubble bake | 4 | 5 | 80 per intact block, 96 chunks | inked seams, partial break, bake |
| Particles | 3 | 3 | n/a | billboards replaced by inked puff meshes |
| Sim (cranes, cars, bots, site_advance, reset) | 4 | 2 | n/a | bot positions |
| Player and chase camera | 1 | 1 | n/a | verified by scripted walk only |
| Modes, cameras, `g.sh`, movie, stats | 6 | 9 | n/a | hero camera 6 times |
| Docs | 8 | n/a | n/a | n/a |

- **Total:** about 57 minutes of real work; the rows sum higher because they overlap.
- **Share:** about 40% first-time generation, 50% look-and-fix, 10% measurement and docs. About 43 captures looked at.
- **Not counted:** model tokens, which I cannot measure. Wall minutes understate a builder agent's cost.

## 5. Rubric (1-5)
| Criterion | Score | Evidence |
|---|---|---|
| Silhouette readability | 4 | `b_hero.png`: crane, ribs, pines, cars and house read at 60 to 100 m; bots do not. |
| Material richness | 2 | `b_site.png`: flat colour, three bands, faint mottle; wood, concrete and steel differ by hue only. |
| Atmosphere / lighting | 4 | `b_hero.png`, `b_site.png`: warm key, violet shade, long shadows, hazy faceted mountains; clouds are simple streaks. |
| Character appeal | 3 | `b_avatar.png`, `b_site.png`: friendly and consistent; faces static, hands are blocks. |
| Destruction readability | 3 | `b_crumble.png`: clearly a broken wall with darker fracture faces and puffs; chunks are near-uniform bricks. |
| Cross-asset consistency | 5 | Every frame: one shader, one palette, one primitive vocabulary. |
| Reads as a shipped indie game | 3 | `b_site.png` could pass; `b_hero.png` is a good vertical slice, not finished key art. |

**Weaker than the references, and why**
- The avatar is about 18% of frame height in the hero. The contract places the house about 50 degrees right of the arena, so the frame needs a 59-degree vertical FOV and the camera cannot come closer.
- Ink is uniform depth and normal edges: no drawn texture strokes, no line-weight variation, hatching is a faint accent.
- Terrain is rolling facets; the cliff is below the camera, the river is outside the hero frame, and there are no mesas, bridge or waterfall.
- Clouds are thresholded noise streaks.
- Lighting is three flat bands with no bounce gradients or window light spill.
- Bots at true scale are about 10 px at 90 m.
- Site and stadium density is low.
- Fracture is a jittered 4x2x2 lattice.

## 6. Reusability test
- **Parametric parts** (table in `KIT.md`): path spline, terrain, road and curbs, river, rink, stands, arch rib with purlins, lattice mast, crane, scaffold, props, house, timber frame, trees, rocks, grass, pre-fractured block, car, biped rig, bot rig, particles, scatter. I did not build a second arena to prove reuse.
- **One-offs:** hero tree, avatar face and hair, layout tables, tree exclusion boxes, shot list, cameras.
- **New average kit part:** 2 to 5 minutes to write plus 2 to 4 rounds at about 10 s per capture, so about 0.1 to 0.2 agent-hours. A rigged character with three clips takes about 0.15 to 0.25 agent-hours. This is far below gtai's 30 to 70 minutes because the bar is lower (rigid boxes, sine-based clips) and there is no export/import step.

## 7. Style as data
- **Data only:** every surface colour, the sun, toon bands, shade, ambient, rim, hatch, mottle, fog, sky, clouds, sun disc, ink, grade, hologram and water colours, and per-material flags.
- **Overcast swap:** `--style=overcast` loads a second JSON and nothing else changes.
- **Still code:** ice-marking and dissolve-edge colours, nitro trail end colours, glass streak, particle sizes, ink thresholds, the band count, terrain colour rules, and all geometry.
- **Risk found:** data can break the look. One height-fog setting turned the whole valley into pink line art, so style files need ranges.

## 8. Challenges, risks, recommendation
- **Avatar and bots:** inked low-poly holds up with the same treatment as the environment (`b_avatar.png`, `b_avatar_front.png`, `b_bot.png`). What is missing is shape detail and motion, not a different shader.
- **Overcast:** the look survives. It is not mud, ink stays crisp, and greens stay green; it is flatter and less attractive than golden hour.
- **Not reachable with simple shapes:** drawn surface texture, organic cliffs, characterful clouds, irregular fracture slabs, faces and hands.

| Edge issue | Fix | Status |
|---|---|---|
| Thin outlines aliasing at distance | interior lines fade 60 to 260 m, silhouettes to 900 m, ink blends to haze, MSAA 2x | fixed in captures; crane lattice and seats still busy at range |
| Ink noise on the road | coplanar strips differ by colour only | none seen |
| Shadow acne | bias 0.05, normal bias 1.4, 8192 atlas | none seen; smaller atlas untested |
| Haze banding | grade grain | none seen in PNGs; movie not inspected closely |
| Fracture seams inked on the intact wall | intact mesh from un-shrunk outer faces | fixed |
| Hatch moire on far slopes | strength 0.10, fades 25 to 90 m | fixed |
| Grass as black scribble | fewer, wider, shorter blades | acceptable |
| Billboards looked like bokeh | inked puff meshes for dust and smoke | fixed; sparks and nitro still additive quads |
| Sleeping chunks cost draw calls | rubble baked after sleep | fixed |

**Not done or not verified**
- Interactive play was started without errors but never driven by hand.
- `reset` was never fired in any run.
- The avatar does not collide with props, and cars do not collide with rubble.
- There is no LOD.
- The biped has no Shoulder or Toes bones.
- The mid-range figure is an estimate.
- Blender was not used, so this lane says nothing about that route.

**Recommendation**
- **Do:** adopt this look and pipeline shape, and treat the kit API as the builder agents' vocabulary. Use the shared-geometry `build` uniform as the live-construction language. Pre-fracture at build time and bake rubble after sleep.
- **Do first when scaling:** merge static meshes per site, add forest LOD, cache generated meshes, clamp style ranges, and give the avatar a dedicated pass.
- **Do not:** add a Blender round trip for kit parts, slice at runtime, author bespoke rigs, use billboards for anything that should look drawn, or rely on screen-space hatching for richness.

## 9. Open questions (builder to Director)
1. `REPORT.md` is blocked for the builder: who saves it?
2. With the contract coordinates the hero cannot hold both arena and house with a large avatar (about 18% of frame height, references about 45%). Accept, or move the house or avatar for pass 2?
3. Bots at 0.8 m are about 10 px in the hero. May they be scaled up or given a beacon?
4. Everything is GDScript and the biped is a rigid-part rig; Blender was not used. Is that acceptable as the standard biped?
5. Extra keys were added to the `--stats` JSON (`gpu_ms`, `cpu_render_ms`, `style`, `ink`, `frames`). Acceptable for comparison?
6. Interactive play was only started and checked by a scripted walk, never driven by hand. Is a hand-driven check wanted before sign-off?

---

## Director verification (2026-11-10 15:06-15:12 CEST; not the builder's text)

What was checked, by the Director running the lane's own tooling:
- `bash tools/g.sh all` ran clean in **151 s** and regenerated all seven acceptance files (new timestamps 15:06-15:09); the builder's originals are kept in `captures/builder_orig/`. No script errors in the filtered output.
- Looked at the regenerated `b_site.png`, `b_crumble.png`, `b_avatar.png`, `b_hero_overcast.png` (and the builder's `b_hero.png` of 14:27, same composition). They match their composition descriptions.
- Three frames pulled from the Director's own movie run (`captures/tmp/dir_movie_strip.png`) show: rib 6 converted from hologram to built with bots gathered at its foot (`site_advance`), car B's nitro flame and trail (`nitro_pass`), and the wall collapsed into rubble (`crumble`). The log line `rubble baked to 1 mesh at t=2.9 s` confirms settling.
- `--style=overcast` changes the whole frame (grey sky, cool greens, no long shadows) with the same geometry.
- Director's `--stats` run: `fps_avg 436.8, p50 2.21 ms, p99 2.78 ms, 802 draw calls, 1,270,580 primitives, 780.1 MB VRAM, gpu_ms 1.487`. Draw calls, primitives, VRAM and `gpu_ms` agree with the builder; fps and frame times are worse than the builder's 575 fps / 1.67 ms because another session's Godot test run (gtai) was active on the machine. Both sets are indicative only.

Not verified by anyone: hand-driven interactive play, the `reset` action, avatar/prop collisions, the mid-range GPU estimate, token cost. The ledger's minutes are the builder's own reconstruction.

Director's own reading of the frames (a judgement, not a measurement):
- Agrees with the builder's rubric on consistency (5), atmosphere (4) and material richness (2). `b_site.png` is the strongest frame and already reads as a game.
- `b_avatar.png`: the avatar is cropped at the knees, the hair is a spiky cone cluster that reads harsh, and the house chimney smoke behind the rock reads as floating stones rather than smoke.
- `b_crumble.png`: dust puffs read as solid boulders of the same colour as the rubble; the pieces are near-identical bricks.
- `b_hero_overcast.png`: the look survives but most of the appeal is gone; the mountains vanish in fog.
- Acceptance for pass 1 is **met** with the exceptions listed under "Not verified".
