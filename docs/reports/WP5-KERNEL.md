# WP5 engine close-out fixes: builder report and Director verification

Brief `briefs/BRIEF-WP5-KERNEL.md`. Builder wall time 21:15 to 21:39 CEST on 2026-11-10 (25 min), plus a follow-up of 6 min (21:47 to 21:53) on the Director's request (harness: 343,801 subagent tokens, 134 tool uses in total).

The builder cannot write report files; the texts below are its final message and its follow-up message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

# WP5 report: close-out fixes in `engine/`

## Status
All five items are done and proven, and `engine/` is green. I worked 21:14:54 to 21:39:26 CEST (25 minutes by `date`). The last code edit was at 21:30:11; every result below is from a run after it, unless marked otherwise. `tasklist` showed no Godot process at the end.

## Item 1: pack-made geometry rendered almost black

**Cause.** The style's environment had black ambient light, because the toon shader is `ambient_light_disabled` and adds its own ambient. The style's sun sits 11.5 degrees above the horizon. A plain `StandardMaterial3D` (which `TLBodies.make` and `TLBall` used) therefore got no ambient and a grazing sun. The sun was installed; shadows show in the before image. The pack's own sun and environment never existed, because its `gen/look.gd` never ran (item 5).

**Changes.**
- **Kernel visuals:** `TLBodies.make`, `TLBall` and the stand-ins now wear a toon material in their colour (`TLStyle.flat_material`). It is the toon shader with a private one-column lookup texture, so no shader or palette change was needed.
- **Pack's own materials:** the environment ambient is now the mean of `toon.amb_sky` and `toon.amb_ground`. Every style shader ignores it, so only materials the style did not make are affected.
- **No venue:** a pack that built no layout and no `ground_patch` gets `TLStyle.ground`, a visual-only plane just under its lowest visual, in windowed runs. It has no collision and is added outside the pack's node tree, so it is not in the state.

**Proof (all looked at).**
- Before: `C:\Users\kazda\kiro\third-life\engine\seeds\captures\wp5\marble_before_f1000.png`. Near-black course and marbles on the painted sky, no ground. Same as the Director's copy.
- After: `...\wp5\marble_after_f1000.png` and `...\wp5\marble_after_f300.png`. Orange wood chute with ink lines and toon bands, pale ice plate, red, steel and wood marbles readable, long sun shadows on a grass ground to the horizon.
- Own `StandardMaterial3D`: `...\wp5\plain_standardmaterial_after.png` (a scratch copy of `pack_min` with four meshes carrying their own material). Orange, pale blue and red cubes with clear lit and shaded sides; the metallic sphere mirrors the sky. This capture was made at 21:21, before the last code edit, and not repeated.

**Seed hashes: none changed.**

| | `seed_paddle` | `seed_drive` | `seed_wall` |
|---|---|---|---|
| smoke, seed 1 | `bc93a9a4c892f2ab` | `b9adbb1967e36108` | `da4bdc3f65cc07ae` |
| bot, seed 1, three runs | one hash, `cadd1cd9fffac7b1` | one hash, `36635c049bc6acd8` | one hash, `6366b88f838e3e78` |
| bot, seed 2 | `944b605a62d5` | `f443d2e59a7f` | `0dd2cd09aec1` |

Smoke hashes equal the WP4 table. The seed-2 bot hashes and the wall seed-1 bot hash equal the WP4 journal. The paddle and drive seed-1 bot hashes have no earlier record to compare against. The marble bot hash `dda2bb9e488d2ac3` equals the Director's on the live engine.

## Item 2: `invariants` replays the first bot twice

- `invariants` is now four runs: idle twice, then the manifest's first bot twice with the same seed.
- New check `invariants.bot_deterministic`: same `state_hash` after the same number of frames. A failure adds an error of kind `determinism` with the bot's file.
- New option `--bot-frames` (default 36000). A bot not done by then is still compared at that frame.
- New metrics `bot_state_hash`, `bot_frames`, and `bot_state_hash_b` when the two differ.
- New bad pack `C:\Users\kazda\kiro\third-life\engine\kernel\examples\bad_bot_nondeterminism`: the kick uses `randf()` only on input.
- New selftest case `bad.bot_nondeterminism` expects exit 1 with `invariants.determinism` true and `invariants.bot_deterministic` false. It passes. `min.invariants` now also requires `bot_deterministic` true.

## Item 3: `TLVfx` through the style layer

`TLVfx` now asks `TLStyleFx.preset(name, opts)` when the style is installed: soft round discs in palette colours, additive discs for sparks and flames, inked toon chips for debris. Lifetime in frames stays the kernel's, and headless runs still make no particles.

- Before: `...\wp5\wall_yard_f330_before.png` and `...\wp5\wall_player_f200_before.png`. Unlit white squares on the wall and beside the walker.
- After: `...\wp5\wall_yard_f330_after.png`, `...\wp5\wall_player_f200_after.png`, `...\wp5\wall_player_f186_after.png`. Small soft round puffs in the pack's tint and one inked grey chip; no squares.
- All nine presets at once in a scratch pack: `...\wp5\fx_presets_f112.png` and `...\wp5\fx_presets_f135.png`, 0 script and 0 engine errors. Round puffs and dots, inked debris chips, pastel confetti, a bright flame.
- `...\wp5\excar_nitro_f60_after.png`: a small additive streak at the left exhaust beside the rig's own flame cones.
- `C:\Users\kazda\kiro\third-life\engine\seeds\captures\seeds_sheet.png` was rebuilt with `tl.sh seeds sheet`; no squares are left.

The effects are subtle: dust puffs are small, and additive sparks wash out against a bright floor.

## Item 4: what a pack author reads

- `C:\Users\kazda\kiro\third-life\engine\kernel\API.md`:
  - New section "0. Start here" with seven points: copy a seed; venue by `TLKit.build_layout`; kit parts before boxes; never make a material, light or environment; `set_script` before `add_child`; the verbs in order; bot rules.
  - Look note under `TLBodies`, new `TLVfx` text, and a generator note in section 1.
  - Section 14 says kernel visuals are toon and the default ground is a picture, not a floor.
  - Section 16 covers the four runs of `invariants`, `--bot-frames` and warnings; section 17 is updated.
- `C:\Users\kazda\kiro\third-life\engine\seeds\README.md`: a "Kit first, boxes second, materials never" paragraph, mistakes 11 to 13 from the first real job, and the `invariants` line.
- `C:\Users\kazda\kiro\third-life\engine\kits\KIT.md`: an "In a pack" paragraph above the generated tables.
- `C:\Users\kazda\kiro\third-life\engine\style\STYLE.md`: `flat_material`, `ground`, the plain ambient, `TLStyleFx.preset`.
- `LAYOUT.md` and `RIGS.md` needed nothing.

## Item 5: `set_script` after `add_child`

**Found.** `gen/look.gd` adds the node to `ctx.root` and attaches the script afterwards. The script's `_physics_process` is never switched on, so it never runs and prints nothing. The new check confirms it on the marble pack.

**Built (small).** The worker lists pack scripts that define `_process` or `_physics_process` on a node that is not processing. The supervisor puts them in the `smoke.loads` detail and fails nothing. On the marble pack:

`pack loaded; WARNING: scripts/look_dress.gd on node 'World/LookDress' never runs (_physics_process is off): call set_script before add_child, or do the work in _pack_tick`

`seed_wall` gets no warning. Two limits: a script with only `_ready` cannot be detected, and a pack that switches its own processing off gets the warning too.

## Change list (`engine/kernel/` and `engine/style/`)

| File | What | Why | Lines |
|---|---|---|---|
| `style/tl_style.gd` | `_flat` cache; `flat_material(color, metal)` | item 1: toon material for kernel-made visuals | 46, 220-240 |
| `style/tl_style.gd` | `ground(y, key, half)` | item 1: default ground, visual only | 245-273 |
| `style/tl_style.gd` | `_apply_world` ambient from the toon hemisphere, times optional `env.plain_ambient` | item 1: own `StandardMaterial3D` lit | 473-479 |
| `style/tl_style_fx.gd` | `_disc`, `_pk`, `_fade`, `preset_names`, `preset`, `_shape` | item 3 | 224-344 |
| `kernel/standin/tl_standin.gd` | `material(color, material_id)` asks `TLStyle.flat_material`; `material_for` passes the id | item 1 | 107-129 |
| `kernel/standin/tl_standin.gd` | `script_has` with a cache | duck-typed seam check | 8, 133-142 |
| `kernel/standin/tl_standin.gd` | `install_default_ground`, `_scan_world` | item 1 | 148-175 |
| `kernel/api/tl_bodies.gd` | passes the material id with `color` | item 1 (steel highlight) | 74 |
| `kernel/api/tl_ball.gd` | the same | item 1 | 96 |
| `kernel/api/tl_vfx.gd` | header; `_make` tries `_style_particles` first; `_style_particles` | item 3 | 3-4, 71-76, 105-112 |
| `kernel/runner/worker.gd` | `warnings`; calls `install_default_ground` and `_find_idle_scripts` after `_pack_setup`; `_find_idle_scripts`; `warnings` in the result | items 1 and 5 | 38, 161-163, 189-206, 586-587 |
| `kernel/host/host.gd` | option `bot-frames` and its integer check | item 2 | 23, 79 |
| `kernel/host/host.gd` | bot replays in `invariants` | item 2 | 132-147 |
| `kernel/host/host.gd` | `_smoke_checks` gets `second_tag` and `list_errors`; warning text in `smoke.loads` | items 2 and 5 | 451-491 |
| `kernel/host/host.gd` | `_bot_determinism_check` | item 2 | 568-594 |
| `kernel/examples/bad_bot_nondeterminism/` | new: `pack.json`, `scripts/main.gd`, `tests/bot.gd` | item 2 | new files |
| `kernel/API.md` | see item 4 | item 4 | 8-33, 67-69, 156-159, 450, 466-473 and others |

Outside those two directories: `engine/tools/selftest.sh` (lines 69 and 110-111), `engine/seeds/README.md`, `engine/kits/KIT.md`, `engine/style/STYLE.md`, `engine/JOURNAL.md` ("WP5" section), `engine/seeds/captures/wp5/*.png`, and `engine/seeds/captures/seeds_sheet.png`.

## Counts from my last runs
- `bash engine/tools/tl.sh selftest`: **61 passed, 0 failed** (60 old plus `bad.bot_nondeterminism`), 101 s.
- `bash engine/tools/k.sh selftest`: **86 passed, 0 failed**. `k.sh validate`: 7 files, 0 failed.
- `bash engine/tools/tl.sh seeds`: **24 passed, 0 failed**.
- Marble pack: lint exit 0 (`bypasses: []`), smoke exit 0, invariants exit 0 with `bot_deterministic` true, `bot_race` exit 0 (ranking steel, wood, rubber), `bot_audio` exit 0.

## Not verified
- The kernel without `TLStyle` or `TLStyleFx` installed: the fallbacks for material, effects and ground are untested.
- `style_overcast.json` in a capture; `tl.sh play`; the HUD.
- A `broke` burst at its peak frame in a seed (I only saw the debris chips in the scratch pack).
- The selftests ran on a machine that was quiet at the time; I did not test under load.
- `flat_material` ignores alpha, so a `color` with alpha below 1 is drawn opaque. `glass` bodies from `TLBodies.make` are opaque toon.

## Questions
1. **Lint figures.** The marble pack still reports `bypasses: []` and `kit_parts_added: 0`, although it makes its own `BoxMesh`, `StandardMaterial3D`, sun and environment. Should lint count `StandardMaterial3D.new()`, `BoxMesh.new()`, `DirectionalLight3D.new()` and `WorldEnvironment.new()` as bypasses? It is a small change in `kernel/runner/lint.gd`; I did not build it because it changes what the Foreman reads.
2. **Contract wording.** I added `--bot-frames`, the three bot metrics, the `WARNING:` text in the `smoke.loads` detail, and the optional style keys `env.plain_ambient` and `env.ground_key`. Proposed lines for `RUNNER.md`:
   - "`invariants` takes `--bot-frames=<max>` (default 36000)."
   - "A `smoke.loads` detail may end with `; WARNING: ...`; a warning fails nothing."
3. **Default ground.** It is grass and sits just under the pack's lowest visual. A course built in the air floats above it, and a body that falls off passes through it. Is that the wanted behaviour, or should it be a neutral colour?
4. **A fixed marble pack.** If a later job attaches `look_dress.gd` correctly, it will add its own sun, environment and `StandardMaterial3D`s on top of the style. The documents now say not to; nothing stops it.

---

## Builder follow-up: lint counts hand-made looks and geometry (verbatim)

Lint now lists hand-made looks and geometry as bypasses, and the engine is still green (21:47:04 to 21:52:59 CEST, about 6 minutes of the 12).

## What changed

| File | What | Lines |
|---|---|---|
| `C:\Users\kazda\kiro\third-life\engine\kernel\runner\lint.gd` | `BYPASS_STYLE` and `BYPASS_GEOMETRY` tables | 75-86 |
| same | appended to the pattern list; geometry rows skipped under `gen/`; the label is the matched text | 274-277, 311-319 |
| `C:\Users\kazda\kiro\third-life\engine\kernel\examples\bad_bypass\scripts\main.gd` | `_dress()`: one material, one light, one mesh, one `MeshInstance3D` | 28-35 |
| `C:\Users\kazda\kiro\third-life\engine\kernel\examples\bad_bypass\gen\part.gd` | a `ShaderMaterial.new()` in a generator | 9 |
| `C:\Users\kazda\kiro\third-life\engine\tools\selftest.sh` | cases `bad.bypass_look` and `bad.bypass_gen_not_double_counted` | 96-103 |
| `C:\Users\kazda\kiro\third-life\engine\kernel\API.md` | bypass list in section 16; one line in "Start here" point 4 | 483-490, 25 |
| `C:\Users\kazda\kiro\third-life\engine\JOURNAL.md` | two entries under "WP5" | end |

- **Primitive `style`**, counted in `scripts/`, `gen/` and `tests/`: the three material classes and the five light and environment classes you listed, each with `.new()`.
- **Primitive `kit`**, counted in `scripts/` and `tests/` only: `MeshInstance3D.new()` and `Mesh.new()` for Box, Sphere, Cylinder, Capsule, Plane, Prism, Quad, Array, Immediate. I added Torus, Text and Point.
- `TLMesh.new()` is deliberately not matched.
- The patterns run on the same text, with comments and strings blanked, as the existing ones, and never affect pass or fail.

## Counts (all after the last edit)
- `bash engine/tools/tl.sh selftest`: **63 passed, 0 failed** (61 plus the two new cases).
- `bash engine/tools/tl.sh seeds`: **24 passed, 0 failed**.
- Lint by hand on `seed_paddle`, `seed_drive`, `seed_wall`, `pack_min`, `ex_slide`, `ex_bounce`, `ex_shuffle`, `ex_wall`, `ex_walker`, `ex_car`, `ex_kit`: all exit 0 with `bypasses: []`. No seed or example trips a new pattern.
- `bad_bypass`: 10 bypasses, `kit_parts_added` 1. The `ArrayMesh` and `MeshInstance3D` in `gen/part.gd` are not listed as bypasses.

## Marble pack `composability` block, verbatim (lint exit 0, all five lint checks true)

```
"composability":{"gdscript_lines":{"scripts":551,"gen":18,"tests":91},"kit_parts_added":0,"bypasses":[{"primitive":"style","file":"scripts/course_build.gd","line":14,"pattern":"StandardMaterial3D.new()"},{"primitive":"kit","file":"scripts/course_build.gd","line":11,"pattern":"BoxMesh.new()"},{"primitive":"kit","file":"scripts/course_build.gd","line":9,"pattern":"MeshInstance3D.new()"},{"primitive":"style","file":"scripts/look_dress.gd","line":38,"pattern":"StandardMaterial3D.new()"},{"primitive":"style","file":"scripts/look_dress.gd","line":57,"pattern":"DirectionalLight3D.new()"},{"primitive":"style","file":"scripts/look_dress.gd","line":64,"pattern":"Environment.new()"},{"primitive":"style","file":"scripts/look_dress.gd","line":70,"pattern":"WorldEnvironment.new()"}]}
```

## Not verified
- `bash engine/tools/k.sh selftest`, the captures and the seeds' three-run hashes were not re-run after this edit. The change is in lint only, which reads text in the supervisor; no worker, kit, rig or style code changed.
- No test covers a new pattern in `tests/`, or the classes `ORMMaterial3D`, `OmniLight3D`, `SpotLight3D`, or any mesh class other than `BoxMesh`. The cases cover one hit per group plus `Environment` and `WorldEnvironment` through the marble pack.
- `CSG*`, `SurfaceTool` and `MeshDataTool` in `scripts/` are not counted as `kit` bypasses, since your list did not name them. They are still counted for generators through `kit_parts_added`.

---

## Director verification

Done 21:40 to 21:55 CEST on 2026-11-10, in two steps, each after the builder had stopped.

### What was re-run, and the result

| Check | Result |
|---|---|
| `bash engine/tools/tl.sh selftest` after the main pass | 61 passed, 0 failed, including `bad.bot_nondeterminism` |
| the same after the follow-up | 63 passed, 0 failed |
| `bash engine/tools/k.sh selftest` (after the main pass only) | 86 passed, 0 failed |
| `bash engine/tools/tl.sh seeds` (after the main pass only) | 24 passed, 0 failed |
| the Director's direct runs of each seed (`seedtest.py`) | every verb exit 0; smoke hashes unchanged from WP4 (`bc93a9a4...`, `b9adbb19...`, `da4bdc3f...`); one bot hash for seed 1 three times; seed 2 and seed 7 differ |
| the marble pack of the first job on this engine | lint, smoke, invariants, bot exit 0; `invariants.bot_deterministic` true (`dda2bb9e...` after 1,207 frames); `smoke.loads` carries the new warning that `scripts/look_dress.gd` never runs |

**Looked at:** `engine/seeds/captures/wp5/marble_after_f1000.png`. The course is lit: orange wood with ink lines, a pale
ice plate with tick marks, readable marbles and shadows on a grass ground. Compare
`docs/reports/img/marble_on_live_engine_f1000.png` (before: near-black).

The engine was then copied to `site/_engine_snapshot2/` (21:54) for the second real job; a seed bot and a lint ran on
the copy and passed.

### What is not verified

- The Director looked at one of the builder's eleven captures. The effect captures (`wall_*_after.png`,
  `fx_presets_*.png`) and the rebuilt `seeds_sheet.png` were not looked at by the Director.
- After the follow-up only the kernel selftest was re-run by the Director; the change is in lint, which reads text.
- The kernel without the style installed (the fallbacks), as the builder says.

### Director's decisions on the builder's questions

1. Lint counts hand-made materials, lights, environments and meshes as bypasses: yes, built in the follow-up. The first
   job's pack now reports 7 bypasses where it reported none. This is the figure the second job is compared on.
2. `--bot-frames`, the bot metrics and the `WARNING:` text: accepted, `RUNNER.md` amended.
3. The default grass ground stays as it is for the spike.
4. A pack adding its own sun and environment on top of the style is now visible as bypasses; nothing forbids it.
