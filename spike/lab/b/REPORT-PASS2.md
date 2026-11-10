# Lane B, pass 2 report

Provenance: everything down to "Director verification" is the builder's text, saved verbatim by the Director on 2026-11-10 (the harness
blocks the builder from writing report files). All paths are under `C:/Users/kazda/kiro/third-life/spike/lab/b/`.

**Status: pass 2 partial.** Every item on the work list got a first working round and the acceptance set passes, but several sub-items are
not done. The builder stopped at 15:51 because its context was nearly full, not because of the time-box.

Three things the builder flagged first:
- **Mouse orbit never worked in pass 1.** Writing the play test exposed it; it is fixed now.
- **`tools/g.sh` now hides Godot's exit-time "leaked at exit / still in use" errors.** They began appearing in pass 2 and were filtered without investigating the cause.
- **Movie recording runs at about 8% of real time now** (4 min 26 s for 20 s, against 36-38% in pass 1). The builder killed its own first run thinking it was hung; the rerun completed. Cause not established, and `g.sh all` now takes about 8 minutes.

Perf one-liner (builder's final `all` run, another project's Godot session active):
```
{"lane":"b","gpu":"NVIDIA GeForce RTX 4090","res":"2560x1440","fps_avg":467.4,"frame_ms_p50":2.08,"frame_ms_p99":3.03,"draw_calls":777,"primitives":1365042,"vram_mb":801.1,"gpu_ms":1.599,"cpu_render_ms":0.601,"style":"golden","ink":true,"frames":7009}
```

## 1. Captures
| File | What it shows |
|---|---|
| `captures/b_hero.png` | New composition: avatar about 45% of frame height, arena, circuit with marshal post and tyres, moved house with window glow, mesas behind, sun in frame. |
| `captures/b_site.png` | Bots at 1.15 m with hard hats and beacons, scoreboard, concrete and steel surface detail. |
| `captures/b_track.png` | Bevelled barrier blocks with painted top strip, marshal post, tyre stack. |
| `captures/b_crumble.png` | Irregular slabs with core faces and rebar, translucent dust. |
| `captures/b_avatar.png` | Reworked avatar, feet in frame. |
| `captures/b_alt_hero.png`, `captures/b_alt_site.png` | Second layout from the same kit. |
| `captures/b_pass2_compare.png` | Pass 1 (left) against pass 2 (right) for hero, site, avatar, crumble. |
| `captures/b_hero_overcast.png`, `captures/b_movie.mp4` | Overcast swap; 20.0 s movie at 1080p60. |
| Extras | `b_site_adv.png`, `b_nitro.png`, `b_bot.png`, `b_avatar_front.png`, `b_avatar_back.png`, `b_hero_2split.png`. `b_map.png` is still the pass-1 scene. |

I looked at most pass-2 frames as half-size contact sheets. The final hero I saw only inside the compare sheet, and I did not look at the pass-2 overcast frame or the movie.

## 2. What was done, by work-list item
1. **Material richness.** MeshKit now writes a part-local coordinate channel, so the toon shader can draw surface detail without UVs.
   - Nine classes: wood, concrete, steel, tarmac, ground, rock, roof, fabric, masonry.
   - A material's class is one field in `style.json`; a new material is a colour plus one entry.
   - Hatching is redrawn as wobbly strokes with cross-hatch in deep shade.
   - The grade has a paper grain.
   - Ink is 2.6 px on silhouettes and 0.9 px on creases.
2. **Characters.**
   - Avatar: 21 bones (added Shoulder, Toes, Backpack, Hair), larger chamfers, calm hair shapes, bigger eyes with a smile, hands with a thumb, and secondary-motion keys in all three clips.
   - Bots: scaled to about 1.15 m, with hard hat, pulsing beacon, weld flash, and two body colourways with three hat colours.
3. **Hero frame.**
   - House moved from (30, -10, -15) to **(19.6, -9, -19.7), yaw -70 degrees**, on a terrace pad at (20.8, -16.4).
   - Hero camera is now at (1.7, 2.7, 4.2), fov 55, about 5 m from the avatar.
   - Added three mesas, a waterfall, shaped clouds, warm lights at the house windows, and soft translucent smoke.
4. **Site density.** Nine new kit parts placed by layout data: site fence, sign, flag, light mast, cabin, scoreboard, tyre stack, marshal post, entrance.
5. **Destruction.** Seeded Voronoi pre-fracture, eight irregular slabs per block, darker core faces, rebar on the larger slabs, translucent dust. Still pre-fractured at build time and baked after sleep.
6. **Second layout.** `--layout=alt` loads `data/layout_alt.json`; see section 5.
7. **Scaling debts.** Static site merged into one mesh, style values clamped to ranges, shadow options measured; see section 4.
8. **Play test.** `tools/g.sh play_test` injects real input and asserts by state: **16 of 16 PASS**.
   - Walk: 29.9 m into the valley, on the ground.
   - Orbit: pitch clamps at 60 and 30; yaw free.
   - `site_advance`: next rib built.
   - `nitro_pass`: car B at 30 m/s.
   - `crumble`: 48 bodies awake, then baked at 2.5 s.
   - `reset`: all of those back to initial values.
   - Collision: avatar stops 1.62 m from a boulder of radius 1.27 m.

## 3. Rubric re-scored
| Criterion | Pass 1 | Pass 2 | Evidence |
|---|---|---|---|
| Silhouette readability | 4 | 4 | Did not move; not targeted. Bots are larger but still small in the hero. |
| Material richness | 2 | 3 | `b_site.png`, `b_bot.png`: panel seams, tie holes and speckle on concrete, rivets on ribs, plank lines on lumber; shingle seams in `b_hero.png`. Patterns are regular and fade by design at hero distance. |
| Atmosphere / lighting | 4 | 4 | Did not move. Mesas, clouds and window glow help, but shade is still flat bands; no bounce term was added. |
| Character appeal | 3 | 4 for bots, 3 for the avatar | `b_site.png`: the crew reads as individuals. `b_avatar_front.png`: friendlier face and calmer hair, but still a static face and chamfered boxes. |
| Destruction readability | 3 | 4, weakly held | `b_crumble.png`: slabs are irregular with visible core and rebar. The dust is now a bright cloud that hides part of the break. |
| Cross-asset consistency | 5 | 5 | Did not move. |
| Reads as a shipped indie game | 3 | 4 on hero and site, 3 on track and crumble | `b_pass2_compare.png` top row: the hero is now a key-art composition. |

## 4. Performance and scaling
Measured at 2560x1440 on the RTX 4090, one run each, with another project's Godot session on the machine; indicative only.

| Config | draw calls | primitives | gpu_ms | cpu_render_ms |
|---|---|---|---|---|
| Pass 1 final | 796 | 1,268,772 | 1.432 | 0.751 |
| Pass 2, static site merged (default) | 777 | 1,365,042 | 1.595 | 0.586 |
| Pass 2, `--nomerge` | 913 | 1,325,524 | 1.606 | 0.642 |
| Pass 2, `--splits=2` (not adopted) | 498 | 887,212 | 1.510 | 0.530 |
| Pass 2, `--noshadow` | 213 | 408,052 | 1.217 | 0.348 |

- **Merging** saves 136 draw calls (15%). The gain is modest because a merged mesh still has one surface per palette material, and each surface is drawn again per shadow cascade.
- **Two shadow splits** cut draw calls by a third. I did not adopt it: a side-by-side crop showed a faint acne-like texture on the foreground grass.
- **Scene size:** 414,946 triangles, 32 scripts and shaders, 4,538 lines.
- **World generation** rose from about 2.3 s to 3.7-5.0 s.

## 5. What the alt layout proved
`layout_alt.json` builds a different scene with no code edits after the layout system first ran. It has a smaller rink (44 x 22) rotated 90 degrees, five ribs with two built, one crane, a different 245 m circuit on the other side, the house moved and rotated, and its own mesas, props and cameras. I wrote the main and alt files in the same step as the layout code, so this is not a test of a layout written later by someone else.

- **The file can express:** positions, sizes, counts, yaw, rink dimensions, rib count and built count, scaffolds and bots in arena-local coordinates, props by position or by distance along the circuit, tree exclusion boxes, cameras.
- **The file cannot express:**
  - Terrain: ridge shape beyond one segment, terrain noise, the circuit's elevation profile.
  - Arena: which side the stands are on.
  - Nature: densities.
  - Sim: car count, wall block count, bot behaviour, the movie shot list.
- **Not checked on alt:** track, crumble and avatar cameras, and the play test.

## 6. Still weaker than the references, and not done
- **Terrain:** no bridge, the river is not in the hero frame, the ridge cliff is not in frame, and the waterfall reads as a pale rectangle on the mesa.
- **Lighting:** no bounce or gradient term; shade is still one flat colour per band.
- **Avatar:** rounded only by larger chamfers; static face; the fabric class is barely visible.
- **Hero framing:** the timber-frame extension is cut by the right edge, and bots are still small.
- **Dust:** too bright and opaque at 1.5 s.
- **Scaling:** no single-material palette (the real fix for draw calls) and no LOD.
- **Overcast:** the old file had fog values outside the new clamp ranges, so its look changed slightly and I did not view it.

## 7. Pass-2 ledger
Minutes are from journal timestamps; a round is an image I looked at and then changed something.

| Work | Min | Rounds |
|---|---|---|
| Material classes, part-local channel, hatch, paper grain | 5 | 2 |
| Avatar rework, bot hat / beacon / scale / colourways | 4 | 2 |
| Layout-as-data rewrite, nine site parts, mesas, waterfall, clouds, lights, two layout files | 10 | 3 |
| Voronoi fracture, rebar, translucent dust and smoke | 3 | 3 |
| Play test, collision, orbit fix | 3 | 3 runs |
| Merge, shadow and clamp measurements | 4 | 1 |
| Acceptance runs, including waiting on the slow movie | 12 | n/a |

Total: about 38 minutes of wall time (15:12 to 15:50), about 10 images looked at. Token cost not measurable.

## 8. Problems found
- **Rubble bake crash:** the bake failed on the new rebar material and repeated every frame; one such run also produced D3D12 device-removed errors. Fixed by using the shared merge function.
- **Packed-array copy bug again:** the new merge function at first appended to copies, the same class of bug as in pass 1.

## 9. Recommendation
Unchanged in direction, with two additions:
- **Treat the layout file as the builder agents' output format:** a scene is a layout plus a style, and both are data.
- **Move to one material for the whole palette** before scaling up, since draw calls are driven by palette keys times shadow cascades.

## 10. Questions for the Director
1. Should I continue pass 2 on the unfinished items (bridge and river in frame, bounce term, dust, avatar rounding), or is this enough for the decision?
2. The exit-time errors are filtered rather than fixed. Do you want the cause found?
3. Do you want two shadow splits adopted with a bias fix, or left at four?

---

## Director verification (2026-11-10 15:52-15:58 CEST; not the builder's text)

Run by the Director with the lane's own tooling:
- `tools/g.sh play_test`: **16 of 16 PASS** in 21 s, same assertions and values as the builder reported (29.9 m walk, pitch 60/30, rib built, car B 30 m/s, 48 bodies then baked at 2.5 s, reset restores all, 1.62 m from the boulder).
- The five captures, the overcast hero and both alt-layout captures regenerated without script errors; `g.sh compare` rebuilt the sheet. The movie was **not** re-run in pass 2 (the builder reports it now takes about 4.5 minutes).
- `--stats`: `gpu_ms 1.619, 778 draw calls, 1,365,044 primitives, 801.1 MB VRAM, fps_avg 428.4` (another session's Godot tests active). Agrees with the builder.
- The filtered exit-time output, read raw: resource leaks at process exit only (8 meshes, 23 materials, 2 shaders, 8 scene instances, 41 ObjectDB instances, "2 resources still in use"), no script errors during the run. Cause still unknown; it is hidden by the wrapper, not fixed.
- The overcast style now logs two values clamped (`fog.density`, `fog.height_density`), so the clamp works and the overcast look is not the pass-1 one.

Director's reading of the frames (judgement, not measurement):
- `b_hero.png` is clearly better than pass 1: the avatar carries the frame, the house glows, the mesas give depth, the site has dressing. It now resembles the concept composition. Agrees with "4 on hero and site".
- `b_site.png`: bots with hard hats and beacons read as a crew; concrete footings and ribs carry surface detail. Strongest frame again.
- Defects seen: the "waterfall" is a pale pixelated rectangle on the mesa; the dust in `b_crumble.png` is a bright white cloud that hides the break (worse for readability than pass 1's, though the slabs are better); the timber-frame extension is cut by the frame edge; ground hatching shows as dark dashes on the foreground grass; in `b_avatar.png` the moved house's roof pokes up through the ridge grass behind the avatar; only one car is visible in the hero.
- `b_alt_hero.png`: a visibly different place (rotated smaller rink, house on the left, other mesas) from the same kit. It supports "layout as data" but, as the builder says, both layouts were written together with the layout code.
- Material richness: 3 is fair. The surface language exists and is data-driven, but it is subtle at hero distance.
