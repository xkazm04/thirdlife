# Look-test scene contract (shared by lane B and lane C)

Both lanes build the SAME scene so the results are comparable. This file is the wire contract: names,
inputs, outputs and composition are fixed; how things look and are made is the lane's job.

Purpose: answer "what does a Third Life frame cost to author and render, and does it look good?" The scene
is a stand-in for the world a player will see: a walking avatar, a construction site with builder agents,
a racing circuit with destruction, a house. It is NOT the game; there is no kernel yet.

## Units, axes, engine
- Godot **4.7.2** (console exe: `C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe`,
  windowed exe is the same name without `_console`). Metres. Y up, forward is -Z. Jolt physics.
- Blender 4.2 batch: `C:/Program Files/Blender Foundation/Blender 4.2/blender.exe -b -P <script.py>`. ffmpeg is on PATH.
- Each lane is its OWN Godot project at `spike/lab/<lane>/` (`project.godot` there), main scene `res://look.tscn`.

## Layout (world coordinates, metres)
| Element | Where | Notes |
|---|---|---|
| Ridge + avatar | avatar at (0,0,0) facing -Z; valley floor about y=-14 | grassy ridge top, a few rocks and a tree at the left edge |
| Hockey arena (under construction) | rink centre (-40,-14,-75), rink 60 (x) x 26 (z), long axis X | boards + glass, two goals, ice with markings, stands on one long side |
| Roof ribs | 8 arch ribs across Z, 8.5 m apart along X, apex 14 m | ribs 1-5 (from -X) BUILT, ribs 6-8 shown as a cyan holographic blueprint (translucent wireframe or emissive edges) |
| Scaffolding + cranes | 2 tower cranes: (-70,-14,-60) and (-10,-14,-85), 35 m tall | crane A carries a load that swings gently (animated) |
| Builder bots | 6 small bots (~0.8 m) around the arena | at least 2 animation states: idle, working (tool/weld with sparks); on a shared bot skeleton |
| Race circuit | closed loop, width 10 m, length >= 300 m, centred about (35,-12,-60) | red/white curbs, tarmac, a bend passing within ~25 m of the avatar's line of sight |
| Barrier wall | 12 blocks (each about 2.4 x 1.0 x 0.8 m) on the outside of a bend, near (30,-12,-40) | must break into pieces on `crumble` (see below), pieces are physical and settle |
| Cars | 2 cars driving the circuit | car A drives normally; car B has a nitro flame + trail when `nitro_pass` fires |
| House | about (30,-10,-15) | finished wooden house with chimney and a half-built timber-frame extension next to it |
| Nature | trees, rocks, river, grass | density is the lane's choice; report the counts |
| Light | golden hour | sun low, warm key, cool fill, haze/fog with depth, sky gradient, long shadows |

The reference compositions are in `ref/` (concept art, an upper bound on detail): lane B reads
`B_toon_ink.png`, `E_painterly_gouache.png`, `A_lowpoly.png`; lane C reads `C_voxel.png`.

## Avatar
Third-person player avatar, about 1.8 m, backpack with a small glowing light, holding a holographic tablet
(the "designer"). Skinned to a skeleton that uses **Godot humanoid bone names** (Hips, Spine, Chest, Neck,
Head, Left/Right UpperArm/LowerArm/Hand, UpperLeg/LowerLeg/Foot). Clips: `idle`, `walk`, `run`. This is the
"standard biped rig" the game will later reuse, so name things cleanly.

## Controls and camera (project input actions, exact names)
`move_forward`, `move_back`, `move_left`, `move_right` (WASD, camera-relative), `cam_orbit` (mouse motion, yaw
free, pitch clamped to 30..60 degrees looking down), `crumble` (key B: triggers the barrier wall to collapse),
`nitro_pass` (key N: car B fires nitro and passes car A), `site_advance` (key H: the next hologram rib
dissolves into a built rib over about 3 s, with builder bots going to work on it; this is the "live
construction" language), `reset` (key R: restores the scene).
Chase camera: orbit-limited around the avatar, distance 5-8 m. The avatar can walk on the ridge and descend into the valley.

## Fixed capture interface (exact CLI, user args after `--`)
`godot --path . [--resolution 1920x1080] res://look.tscn -- --capture=<cam> [--t=<seconds>] [--seed=<n>]`
writes `captures/<lane>_<cam>.png` and exits. `--movie=<name>` records 20 s via Godot `--write-movie` (use
`--fixed-fps 60`) to `captures/<lane>_<name>.mp4`. Named cameras (same names in both lanes):
- `hero`: the key-art composition: avatar lower-left, arena upper-left, circuit right, house lower-right, sun in frame (matches the references).
- `site`: close on the arena with the bots and the hologram ribs, ~25 m away.
- `track`: car A and car B at the bend, wall in frame.
- `crumble`: same as `track`, captured 1.5 s after `crumble` is fired (`--t=1.5 --fire=crumble`).
- `avatar`: avatar and tablet close up, 3/4 view.
Also required: `--stats` prints one JSON line to stdout and exits after 15 s of the `hero` view: `{"lane":..,"gpu":..,"res":..,"fps_avg":..,"frame_ms_p50":..,"frame_ms_p99":..,"draw_calls":..,"primitives":..,"vram_mb":..}`.

## Style as data (tests the claim "the style is global data")
All colours/light/post parameters that define the look live in ONE data file `data/style.json` (palette,
sun, fog, outline/post parameters, material ramps). Provide a second file `data/style_overcast.json`; running
with `--style=overcast` must change the look of the whole scene (morning, overcast, cool) with no code or
asset change. Capture `hero` in both.

## Required outputs (per lane, at `spike/lab/<lane>/`)
1. `captures/` (git-ignored) with the five named images for the default style plus `hero` for overcast, and one 20 s movie.
2. `tools/g.sh` wrapping import / capture / run / stats (pattern: `gtai-3d-spike/tools/g.sh`), and a `README.md` of how to run.
3. `JOURNAL.md` appended as you go (timestamped; what you tried, what failed, what you measured). It is the
   resume point if you are killed; re-read it first when restarted.
4. `REPORT.md` (see the brief) with an authoring ledger, perf table and an honest rubric.
5. Source only in git-visible files; no editor binaries, no downloaded assets (see the brief's limits).

## Perf and size budgets (to be measured, not assumed)
Report, do not hide: draw calls, primitives, VRAM, frame ms p50/p99 at 2560x1440 on this RTX 4090 (other
sessions may share the GPU, so mark numbers as indicative). Extrapolate in the report to a 1080p mid-range
GPU (GTX 1660 / RX 580 class) as an explicit estimate, labelled as such.
