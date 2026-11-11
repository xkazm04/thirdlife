# N2 many games alive in one process: builder report and Director verification

Brief `briefs/BRIEF-N2-MANY.md`. Builder wall time 00:04 to 01:09 CEST on 2026-11-11 (66 min; harness: 357,234 subagent tokens, 118 tool uses). Work done in the engine copy `site/_work/n2/engine/`.

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

N2 REPORT: many games alive in one process

## Status

All six items are built and proven in my copy, `C:\Users\kazda\kiro\third-life\site\_work\n2\engine\`. The final gates on a quiet machine: `tl.sh selftest` 66 passed, `k.sh selftest` 86 passed, `tl.sh seeds` 24 passed, 0 failed in each. No seed hash changed. Nothing outside my file scope was edited. The world host is headless only: it has no watchdog and no window yet.

Three things the Director should know first:

1. **One space per pack, pause and slicing all hold exactly.** A pack in the world host, in its own physics space, gives the single-pack worker's hash bit for bit. Paused or given one world tick in N, it runs the same game, later.
2. **A pack must be simulated at its own origin.** Standing 64 m away, a pack with no world coordinate in its code already hashes differently within 60 ticks. I found no built-in way to draw a pack away from where it is simulated.
3. **Asleep is not cheap in this kernel; switched off is free.** Sixty sleeping packs cost 13.8 ms per tick, against the research's pass line of 0.2 ms. The cost is the kernel's own per-body GDScript tick (`TLContact`), not Jolt.

## Per item: what was built and the proof

**1. A pack instance.**
- `TLContext` now owns what was static: `audio_events`, `huds`, `ball_group`, `_warned`, plus `instance`, `holder`, `origin`, `space`.
- `TLContext.current` means "the pack the kernel is calling right now". `TLContext.of(node)` finds a node's pack through its holder.
- `TLContact` and `TLTrigger` receive engine callbacks, so they name their pack (`TLContext.enter/leave`) before pack code hears the signal.
- `TLFracture` and `TLSpawner` take their own pack's seeded generator. Before, in a world, a fracture inside a physics callback would have drawn from an unseeded one.
- Proof: the together-equals-alone runs below, and the probe's count of 0 calls made with another pack as current.

**2. The kernel drives every tick.**
- Mechanism: the pack's holder node is set to `PROCESS_MODE_DISABLED` together with `space_set_active(false)` on any world tick the pack does not get.
- Every collision object of the pack is set to `DISABLE_MODE_KEEP_ACTIVE` when it enters the tree. The engine default would remove bodies from the space on disable and lose the contact cache.
- Proof (BENCH.md tests 6, 7, 8): switched off at world tick 300 mid-play for 1, 60 and 3600 ticks, and ticked one world tick in 2, 8 and 30, every pack ends with the same hash, the same tick count and the same number of sounds as the continuous run.
- Packs covered: the three seeds, `ex_bounce` (trigger, spawner, rules) and `ex_wall`, each played by its bot, plus a sleeping pile.
- A probe script in every pack ran 0 times on a tick its pack did not get, in 588,018 pack ticks.

**3. One physics space per pack.**
- `space_create()` per pack; bodies and areas are moved in as they enter the tree; the ray queries of `TLContact`, `TLVehicle` and `TLLaws.surface_under` go to the pack's space.
- Way (a), bodies at their world position in the pack's own space: built and measured, and it fails.
  - `w_pile` has no world coordinate in its code, so it shows the arithmetic alone. At 64 m it differs within 60 ticks. At 1000 m and beyond, the 300-box pile's starting positions already round to another millimetre.
  - The seeds also read `global_position` in `_pack_state`. At 64 m the bots of `seed_drive` and `seed_paddle` no longer finish.
- Way (b), bodies at the pack-local origin: the physics half is every other run in this report. All packs of a world stand at the origin of their own space, on top of each other, and never meet.
- Way (b), the picture half: no workable built-in mechanism found. A node's global transform is what the physics server receives, and a `World3D` ties one render scenario to one space with no setter for either.
- What remains is kernel-side drawing: draw the stage pack natively at the origin, and show other packs through mirror instances or the proxy mesh the tier model already wants. Not built, not measured.

**4. Several packs in one process.**
- `kernel/world/world.gd` is the host, `kernel/world/pack.gd` the holder of one pack, `tools/world.sh run|same|bench` the wrapper.
- `world.sh run --packs=<a>,<b>,... [--frames=N]` prints one `tl.world/1` line per pack with its state hash, plus one line for the world.
- `world.sh same` runs each pack alone, then all together three times, and compares.

**5. The measurements.**
- `world.sh bench` writes `kernel/world/BENCH.md` and `bench.json`: 73 world processes, 1393 s.
- Test 5 was run again with two `w_pile` columns and merged in.
- I added two hand-written sections at the end of BENCH.md; a re-run of the bench overwrites them.

**6. verbs.json.**
- `verbs.json` has a new `modes` block (`world`, `world-bench`), kept apart from `verbs` because the modes take no `--pack` and write no `tl.verify/1` report.
- `host.gd` has a matching `MODE_OPTIONS` table.
- New selftest case `verbs.json_matches_host` compares `OPTIONS` and `MODE_OPTIONS` with the file, both ways, as text.
- Two more new cases: `world.same` and `world.sliced_and_paused`.

## Hash table (solo against together)

Idle runs, 3600 ticks, seed 1:

| pack | `tl.sh smoke` (worker) | world host, alone | together, 3 runs |
|---|---|---|---|
| seed_paddle | bc93a9a4c892f2ab | bc93a9a4c892f2ab | same, same, same |
| seed_drive | b9adbb1967e36108 | b9adbb1967e36108 | same, same, same |
| seed_wall | da4bdc3f65cc07ae | da4bdc3f65cc07ae | same, same, same |
| seed_wall + seed_wall | | da4bdc3f65cc07ae each | both same, 3 runs |

Played by its bot to the bot's end:

| pack | `tl.sh bot` (worker) | world host, alone | together, 3 runs |
|---|---|---|---|
| seed_paddle | cadd1cd9fffac7b1 at 6776 | same | same |
| seed_drive | 36635c049bc6acd8 at 3516 | same | same |
| seed_wall (two copies) | 6366b88f838e3e78 at 1221 | same | same |

Commands:
- `bash tools/world.sh same --packs=seed_paddle,seed_drive,seed_wall`
- `bash tools/world.sh same --packs=seed_wall,seed_wall`
- add `--mode=bot --frames=36000` for the bot table

## Bench table and what it means

Machine: Ryzen 7 7800X3D, headless, shared with other sessions. Figures are the median of one whole loop iteration, lower of two runs.

| measurement | result |
|---|---|
| seed_paddle, per pack per tick (1 / 5 / 10 / 20 packs) | 0.273 / 0.229 / 0.194 / 0.189 ms |
| seed_wall | 0.410 / 0.325 / 0.328 / 0.363 ms |
| seed_drive | 0.821 / 0.648 / 0.597 / 0.675 ms |
| 20 mixed seeds | 10.1 ms in all, 0.505 ms each |
| awake bodies in one space (50 / 150 / 300 / 600) | 0.64 / 1.74 / 3.78 / 7.45 ms |
| packs asleep, spaces active (10 / 30 / 60 packs of 30 boxes) | 2.0 / 6.1 / 13.8 ms, about 0.2 ms per pack |
| the same packs switched off | 0.014 / 0.032 / 0.056 ms, about 0.001 ms per pack |
| hash against neighbours in other spaces | same, 3 orders, 3 runs each |
| hash with a neighbour 300 m away in one shared space | different (one run per order, cause not isolated) |
| pause of 1, 60, 3600 ticks | same |
| one world tick in 2, 8, 30 | same |
| probe calls on a tick the pack did not get | 0 of 588,018 pack ticks |
| engine warnings (dropped contacts or otherwise), errors | 0 |
| loading (by hand) | about 3 s per seed pack, 65 s for 20, in one blocking call |

How many games can run at full speed on this machine, with nothing drawn:
- Inside the 2 ms physics target: 3 mixed seeds (2 drives, or 5 walls, or 10 paddles).
- Inside 8 ms, leaving half a frame for drawing: 15.
- Inside a whole 16.7 ms frame: 33.
- One pack at the 600-body entity budget costs 7.5 ms by itself.

The timed tests ran while other sessions used the machine. The 20 x seed_drive row had a worst-of-two of 28 ms against a median of 13.5 ms.

An experiment I did not keep: three lines at the top of `TLContact._physics_process` (`if body.sleeping:` / `_prev_velocity = body.linear_velocity` / `return`). It took 300 sleeping boxes from 2.21 ms to 0.16 ms per tick. The 11 hashes I compared were unchanged. The file was restored byte for byte; the full gates were not run on the change.

## Files changed

All under `site/_work/n2/engine/`.

| file | change |
|---|---|
| `kernel/api/tl_context.gd` | per-pack state; `of`, `enter`, `leave`, `space_state_of`, `first_time` |
| `kernel/api/tl_audio.gd` | `events` reads the pack's record; warn-once per pack; `contact` and `_play` take a pack |
| `kernel/api/tl_hud.gd` | HUD list in the context; `hide_all(of_pack)` |
| `kernel/api/tl_trigger.gd` | per-pack ball group; names its pack around `entered` and `left` |
| `kernel/api/tl_ball.gd` | joins the pack's ball group |
| `kernel/api/tl_contact.gd` | caches its pack; ray query in the pack's space; names its pack around `hit` |
| `kernel/api/tl_biped.gd`, `tl_vehicle.gd` | rig tick uses the own pack's frame; vehicle rays in the pack's space |
| `kernel/api/tl_fracture.gd`, `tl_spawner.gd` | own pack's seeded generator |
| `kernel/api/tl_vfx.gd`, `tl_laws.gd` | warn-once per pack; `surface_under` in the pack's space |
| `kernel/runner/worker.gd` | tags itself as the holder; `TLHud.hide_all(ctx)` |
| `kernel/runner/logger.gd` | per-pack error counts; keeps warning texts |
| `kernel/runner/verbs.json` | `modes` block |
| `kernel/host/host.gd` | `MODE_OPTIONS`; routes `world` and `world-bench` |
| `kernel/world/pack.gd` (new) | the holder of one pack |
| `kernel/world/world.gd` (new) | the world host |
| `kernel/world/bench.gd` (new) | the bench |
| `kernel/world/packs/w_pile/` (new) | bench pack; the seed is the body count |
| `kernel/world/BENCH.md`, `bench.json`, `PATCHES.md` (new) | results and patches |
| `kernel/API.md` | section 19 (a world of several packs); one line of section 17 |
| `tools/world.sh` (new) | `run`, `same`, `bench` |
| `tools/selftest.sh` | three new cases |
| `JOURNAL.md` | N2 section |

## Contents of PATCHES.md

No file outside my scope was edited in the copy. Summarised here; the diffs for 1 and 2 are verbatim, and the full text is in `kernel/world/PATCHES.md`.

1. **`kernel/api/tl_orbit_cam.gd` line 61 (`_unhandled_input`).**
   ```
   -	var ctx: TLContext = TLContext.current
   +	var ctx: TLContext = TLContext.of(self)
   ```
   `_unhandled_input` is an engine callback, so in a world `current` is null there. Without the patch the mouse does not orbit a camera inside a world. Single-pack `play` is unaffected.

2. **`kernel/api/tl_cameras.gd` line 77 (`activate`).**
   ```
   -	cam.current = true
   +	var pack: TLContext = TLContext.of(self)
   +	if pack == null or pack.on_stage:
   +		cam.current = true
   ```
   Plus `var on_stage: bool = true` in `tl_context.gd` (mine; not added yet, so it does not sit unused). A viewport has one current camera, and in a world the last pack to activate a view wins. Not needed headless, so not measured.

3. **`kernel/runner/lint.gd`, proposal with no exact patch.** List `global_position`, `global_transform`, `global_basis`, `to_global(` and `look_at(` in `scripts/` and `tests/` under a new composability key. Reason: BENCH.md test 5.

4. **Seeds, kits, rigs, style: no patch.** The statics of `TLStyle`, `TLStyleFx` and `TLKitLayout._schema` are the shared look and a read-only schema. What a pack adds are cache entries whose content does not depend on the pack.

5. **`kernel/runner/lint.gd`, proposal with no exact patch.** Fence `get_tree().get_nodes_in_group`, `get_first_node_in_group` and `call_group`. Scene-tree groups are tree-wide. Nothing uses them today, and lint does not stop it.

## Statics left, and why

- `TLContext.current`: kernel-set, as the brief allows.
- `TLContext._loose_warned`, `TLAudio._loose_events`: used only when no pack is on the stack.
- `TLAudio._streams`: read-only once made, from a fixed seed.
- `TLLaws._materials`, `_pairs`, `_loaded`, `impulse_per_hardness`: the law tables.
- `TLStandin._ext_cache`, `_has_cache`, `_ext_said`: code lookups, and one print per process.
- `TLKitLayout._schema` and the `TLStyle` / `TLStyleFx` statics: the shared look.

Process-wide things that are not statics:
- `Engine.get_physics_frames()` in `TLBall.last_step`, used only as a "same engine frame" test; the slicing tests pass with it.
- Group names a pack passes to the kernel: only ever tested per body.
- The one logger, which tags errors per pack.
- The viewport's current camera (patch 2).

## What changed for a pack author

- Nothing, for a pack that follows API.md. Seeds and examples run unchanged with the same hashes.
- `frame` and `ctx.frame` are the pack's own tick count, which may run slower than the world's.
- `TLContext.current` is null in a world outside kernel calls, tree ticks and kernel-primitive signals. A static kernel call such as `TLAudio.play`, made from a signal the pack wired to a raw engine node, has no pack.
- `RayCast3D`, `ShapeCast3D`, `SpringArm3D` and `get_world_3d().direct_space_state` look into the default space, where a world keeps no pack. No seed, example, kit or rig uses them.
- Keep the default `process_physics_priority`.
- Stay in pack coordinates: build under `ctx.root`, place with `position`.

All of this is in API.md section 19.

## Not verified

- Anything with a window: camera and HUD ownership, drawing, way (b)'s picture half.
- The world host has no watchdog thread. A runaway `_pack_tick` hangs the whole world.
- Job-thread count was not varied. Hash tests ran 3 runs per case, not 20.
- Memory per space: only Godot's static allocator was read (18 to 24 MB per seed pack). Jolt's allocations, the OS working set and `max_bodies` at 1,024 were not measured.
- Why a neighbour in one shared space changed `ex_bounce`'s hash.
- The pause variant that restores transforms and velocities by hand.
- Joints in a world.
- Tests 10 to 18 of the research table.
- The sleeping-body change against the full gates.
- `worker.gd` and `pack.gd` each carry their own load and hash code. They agree today (equal hashes), but they are two copies.

## Questions

1. Should I apply the three-line sleeping-body change to `tl_contact.gd`? It cuts the cost of an asleep pack by about 14 times and left all 11 compared hashes unchanged. I held it back because it touches every pack's physics path and was not run through the full gates.
2. Way (b) needs the kernel to draw non-stage packs itself (mirror or proxy). Is that the direction, or should packs be made origin-free and the hash contract relaxed for way (a)? The measurement says way (a) cannot keep a pack comparable with its verified run.
3. Is `modes` the right place in verbs.json for `world` and `world-bench`, or does the Foreman want them under `verbs`?
4. Loading a seed pack blocks for about 3 s. Should the next step measure where that goes, before any work on tiers?

## Minutes

Started 00:03:40, finished 01:09:18 (from `date`): 66 minutes of the 90. No process of mine is left running.

---

## Director verification

Done 01:23 to 02:00 on 2026-11-11 (local time), after the builder had stopped: first in the builder's copy, then on the
main tree after merging its files. A real hockey job with its CLI builders, another builder and other sessions used the
machine throughout (up to ten Godot processes).

### What was re-run, and the result

| Check | Result |
|---|---|
| `world.sh same --packs=seed_paddle,seed_drive,seed_wall` (idle) in the copy | every pack hashes together as alone, three runs (`bc93a9a4...`, `b9adbb19...`, `da4bdc3f...`); 0 gate leaks, 0 wrong-pack calls, 0 engine errors, 0 limit warnings |
| the same with `--mode=bot --frames=36000` | same, three runs (`cadd1cd9...`, `36635c04...`, `6366b88f...`) |
| `world.sh same --packs=seed_wall,seed_wall` | same, three runs |
| `tl.sh selftest` in the copy | 66 passed, 0 failed, with `verbs.json_matches_host`, `world.same`, `world.sliced_and_paused` |
| `k.sh selftest`, `tl.sh seeds` in the copy | 86 and 24 passed, 0 failed |
| after the merge, on the main tree: `world.sh same` with bots | passes |
| after the merge: `item.sh selftest`, `k.sh selftest` | 91 and 86 passed, 0 failed |
| after the merge: `tl.sh selftest` (now 73 cases with the seven fence packs) | 68 passed; the 5 failures are all `invariants.frame_budget` (p99 8.3 to 15.3 ms against 8 ms) |
| after the merge: `tl.sh seeds` | 22 passed; `seed.drive.invariants` p99 16.5 ms, `seed.paddle.invariants` a 250 ms watchdog stall |
| the seven failed cases, each run again alone | all pass: p99 0.25 to 0.96 ms |
| old engine against merged engine, back to back under the same load (`invariants`) | `pack_min` 0.23 to 0.28 ms against 0.25 to 0.35 ms; `seed_drive` 0.92 to 0.93 ms against 0.94 to 0.96 ms: no slowdown from the merge |
| a capture of `seed_drive` on the merged engine | byte-identical to the frame taken before the kernel merge |
| `worker --mode=play` on `bad_reach_tree` | refused: "play refused: lint did not pass (12 finding(s))", exit 1 |

**Read:** `kernel/world/BENCH.md` in full. The Director did not re-run the bench (23 minutes); its hash tables agree with
every hash the Director did take.

### What this settles, and what it opens

- The layering model of the research holds on this engine: one space per pack isolates exactly; switching a pack off is
  an exact pause; one world tick in N is the same game, later.
- A pack cannot be simulated away from its own origin. So the picture of a world is a kernel job: every pack's nodes sit
  at the origin of its own space, and something else must draw them at their plots. Brief `briefs/BRIEF-N5B-DRAW.md`.
- Capacity with nothing drawn: about 15 mixed seed games inside 8 ms, 33 inside a frame; one pack at the 600-body limit
  costs 7.5 ms alone. The 8 ms per-pack budget of `invariants` was set for a world of one and is far too loose for a
  world of many.
- A sleeping pack costs 0.2 ms through the kernel's own per-body script; the fix is three lines and goes into N5a.

### What is not verified

Anything with a window in a world; the bench's timing figures; memory per space; why a neighbour in a shared space
changes a hash; joints in a world. The world host has no watchdog.

### Director's decisions on the builder's questions

1. The sleeping-body change: yes, as the first item of N5a, with every gate.
2. Way (b): the kernel draws the packs the player is not in. The hash contract is not relaxed.
3. `modes` beside `verbs` in `verbs.json` is right; the Foreman reads `verbs` only.
4. Where the 3 s of loading a seed pack goes: measured in N5a.

Merged into the main tree by file (the builder's 19 changed files, `kernel/world/**`, `tools/world.sh`); `kernel/API.md`
merged three ways without conflict. Applied by the Director: the builder's patches 1 and 2 (`tl_orbit_cam.gd`,
`tl_cameras.gd`, `on_stage` in `tl_context.gd`), N4's patch 4 (the worker lints before `play`) and patch 5 (the seven
fence packs in `tools/selftest.sh`). `foreman/fixtures/engine/kernel/runner/verbs.json` follows the engine's file.
