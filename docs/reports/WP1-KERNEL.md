# WP1 law kernel, host and runner: builder report and Director verification

Brief `briefs/BRIEF-WP1-KERNEL.md`. Builder wall time 18:53 to 19:54 CEST on 2026-11-10 (61 min; harness: 435,836 subagent tokens, 126 tool uses).

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

# WP1 report: law kernel, host and runner

## Status
The whole priority list (items 1 to 7) is built, and `bash engine/tools/tl.sh selftest` passes 52 of 52 cases. I stopped at 19:54 CEST because the list was done, about 61 minutes after starting at 18:53 (both from `date`). Nothing of mine is left running.

## What exists, against the priority list

| # | Item | State |
|---|---|---|
| 1 | Host, five verbs, exit codes, `tl.verify/1`, `tl.sh` | Done. Report goes to `--report` and is the last stdout line. Also works when spawned directly as in RUNNER.md, on a cold start with no `.godot`, and with four runs at once. |
| 2 | Pack loader and `ctx` | Done. Loads from an absolute directory (tested outside the project, in a path with spaces) or `res://`. |
| 3 | Lint V0 + V1 | Done. Text only, comments and strings blanked, file and line on every finding, plus the composability figures. |
| 4 | Determinism and watchdog | Done. Seeded rng, quantised SHA-256 `state_hash`, frame-counted run, V3 budgets. |
| 5 | Law tables and surface rules | Done, and measured (see below). |
| 6 | Primitives | Done: bodies, triggers, contact, damage, ball/puck, biped (walk, run, skate), vehicle, input, rules, spawner, fracture, cameras. |
| 7 | Steering, HUD, VFX, audio | Done as stand-ins: `TLSteer`, `TLHud`, `TLVfx`, `TLAudio`. |

Docs and examples: `engine/kernel/API.md` (18 sections, including "what the kernel does not do yet"), `pack_min`, six neutral example packs with bots, and 14 deliberately bad packs under `engine/kernel/examples/`.

## Selftest output (final run, 19:53)
```
PASS min.lint | min.smoke | min.smoke_again | min.smoke_seed2
PASS min.determinism  (seed 1: 21b9fc200e0187d4 twice; seed 2: c7985aa370e85559)
PASS min.invariants | min.bot | min.capture | min.capture_file (149584 bytes) | min.res_path | min.res_path_smoke
PASS bad.schema | bad.schema_smoke | bad.layout | bad.fence
PASS bad.fence_each_line  (36 fenced patterns, each reported once with its line; comments and strings ignored)
PASS bad.capability | bad.capability_run | bad.bypass | bad.bypass_kit_part | bad.size | bad.nondeterminism_lint
PASS bad.script_error | bad.parse_error | bad.watchdog | bad.watchdog_bot | bad.error_storm | bad.setup_loop
PASS bad.bot_never_done | bad.nondeterminism | bad.budget
PASS norun.missing_pack | norun.bad_verb | norun.bad_option
PASS ex.{slide,bounce,shuffle,wall,walker,car}.lint   (zero bypasses each)
PASS ex.{slide,bounce,shuffle,wall,walker,car}.bot
PASS ex.{car,wall,walker,bounce,shuffle,slide}.invariants
selftest: 52 passed, 0 failed
```
(Condensed; the real output is one PASS line per case.)

Numbers the example bots measured:
- **Friction (`ex_slide`, from 3 m/s):** rubber on ice 4.57 m (law 4.59), rubber on asphalt 0.43 m, wood on ice 15.28 m, wood on asphalt 0.89 m.
- **Restitution (`ex_bounce`, first rebound):** 0.65 / 0.60 / 0.30 / 0.55 measured against 0.65 / 0.60 / 0.30 / 0.55 in the table, pairwise overrides included.
- **Vehicle (`ex_car`):** braking from 14 m/s takes 10.1 m on asphalt and 96.0 m on ice (grip 0.99 and 0.104; law 1.0 and 0.1). The AI pace car stayed within 1.27 m of its line for 143 of 147 m.
- **Puck (`ex_shuffle`):** at 30 m/s it bounces off a 0.2 m rail, stays flat, and is seen twice by a 0.3 m trigger.
- **Fracture (`ex_wall`):** a 31.6 N·s hit leaves the wall intact (threshold 260 N·s); a 17,661 N·s hit breaks it into 18 pieces that settle in 201 frames.
- **Biped (`ex_walker`):** walks at 2.30 m/s, stops in 6 frames on concrete, runs at 6.00 m/s; the skater keeps 9.2 of 9.5 m/s after 2 s coasting on ice.

## API surface

| Class | Capability | Purpose |
|---|---|---|
| `TLContext` (`ctx`) | none | root, rng, seed, frame, `read_json`, `load_script`, `pack_state`, `pick`, `shuffle`, `info` |
| `TLLaws` + `materials.json`, `surfaces.json` | physics | material rows, `pair`, `apply`, `surface_under`, `impact_threshold` |
| `TLBodies`, `TLTrigger`, `TLContact`, `TLDamage` | physics | `make`, `ground`, `trigger`, `push`, `from_part`; signals `entered`/`left`, `hit`, `damaged`/`broken` |
| `TLBall` | ball | `create`, `shoot`, `shoot_at`, `place`, `hold`/`release` |
| `TLBiped` | biped | `create`, `move`, `brake`, `jump`, `set_mode`, `drive_from_input` |
| `TLVehicle` | vehicle | `create`, `set_controls`, `drive_from_input`, nitro, per-wheel surface |
| `TLInput` (`ctx.input`) | input | `declare`, read, and inject (`press`, `release`, `tap`, `set_axis`) |
| `TLRules` | rules | score, clock, periods, checkpoints, laps, `standings`, `snapshot`, seven signals |
| `TLSpawner` | spawn | factory, points, limits, lifetime |
| `TLFracture` | fracture | `attach` to an `Intact`/`Pieces` part, `break_now`, bake |
| `TLCameras`, `TLChaseCam`, `TLOrbitCam` | camera | named views, chase, orbit with pitch held to 30–60° |
| `TLSteer`, `TLHud`, `TLVfx`, `TLAudio` | ai, ui, vfx, audio | steering functions, widgets, effect and sound presets |
| `TLStandin`, `TLStandinRig` | none | stand-in rig, look, fracturable wall, dynamic part; finds `TLKit`/`TLRigs`/`TLStyle` at run time |

## How script errors are detected
- **Custom `Logger`, primary.** Godot 4.7.2 has the class; a subclass registered with `OS.add_logger()` in the sim process receives every error with file, line, type and GDScript backtrace. An engine error or `push_error` is attributed to the pack line on the stack. Any error fails V2; warnings do not.
- **Child process, second net.** The process you start is a supervisor; pack code runs in a fresh worker process. The supervisor reads the worker's engine log and fails the run on a `SCRIPT ERROR` the Logger never counted (for example, one raised before the Logger was registered).
- **Why both.** The child process is needed anyway: a runaway loop cannot be interrupted in its own thread. A watchdog thread in the worker writes the result and ends the process, and the supervisor still reports exit 3.

## Determinism evidence
- `pack_min`, 3,600 frames: seed 1 gives `21b9fc20…9ec8d1` in two separate processes; seed 2 gives `c7985aa3…508b57`.
- `invariants` passes on all seven good packs.
- Four `invariants` runs of `ex_car` at once (8 workers) gave one hash.
- `bad_nondeterminism` (uses `randf()`) fails `invariants.determinism`, and lint also rejects it.

## Lines of code
- Runner and host: 1,716
- `kernel/api`: 2,962
- Stand-ins: 343
- Tools: 211
- Good example packs: 892
- Bad packs: 1,167 (650 of them the generated oversize file)
- `API.md`: 458

## Director's amendments
- **Lint level:** was already `"V1"`.
- **Dynamic props:** built. `TLBall.create({part = ...})` and `TLBodies.from_part()` accept `tl_dynamic` parts; `TLStandin.dynamic_part()` makes one for tests; `ex_shuffle` checks both (0.17 kg puck and 1.5 kg paddle from the mass hint).
- **Unknown sockets:** `TLVfx.attach(preset, null)` returns null. `TLBall.hold()` is not guarded: given a null holder it freezes the ball and lets go on the next tick, so pack code should check the socket first.
- **Rig in tree:** `TLBiped` now sends the rig its mode in `_ready`; `tick` and `set_locomotion` only run from the physics frame.
- **`--position` for capture:** the supervisor passes `0,1440` to the worker window itself, so a headless supervisor works too.

## Not verified, and known limits
- **WP2 integration is unexercised.** `TLKit`, `TLRigs` and `TLStyle` were absent and I did not read `kitlab/`. The paths that call them are written to the contract but have never run.
- **Three checks read a clock:** the 250 ms tick limit, a 10 s limit I added for setup-type calls, and the contract's 8 ms frame p99 (I judge the better of two runs). Everything else counts frames.
- **Capture is flaky under Vulkan on this machine.** About 70 % of windowed workers died at engine start inside `amdxc64.dll` while another Godot process was running. The supervisor restarts a worker that died before its first line, falling back to `d3d12` (12 of 12 succeeded). The driver used is named in the `capture.written` detail.
- **Written but not exercised by any example:**
  - Rules: periods, intermission, sudden death, `standings`, pause/resume.
  - Biped: `jump`.
  - Vehicle: reverse, front and all-wheel drive.
  - Spawner: `order = "random"`.
  - Steering: every function except `keep_lane`, `steer_toward` and `seek`.
  - Fracture: `bake = "remove"`.
  - Damage: `hurt`.
  - Orbit camera: mouse control.
- **HUD and audio are checked by state only.** The HUD is hidden in captures, so I verified its text values but never looked at it. Audio is checked through its event log; I have not confirmed any sound plays in a windowed run. `tl.sh play` ran for 7 s with no keys pressed.
- **Trigger sweep covers `TLBall` only.** Other small fast bodies can still skip a thin trigger, and a vertical near-miss edge case remains.
- **Not built:** merged-mesh bake, pairwise restitution between two tracked dynamic bodies, loading `requires`. The full list is in `API.md` section 17.
- **Stray files:** Godot wrote `engine/.godot/` and `*.gd.uid` files next to kernel scripts.

## What a pack author will find awkward
- A solid body's default mass is density × volume, so a 0.8 m wooden crate weighs 333 kg; pass `mass` for hollow things. This bit my own example.
- Triggers also report overlapping static bodies at start; handlers must filter.
- Do not free or re-parent bodies inside a contact or trigger handler; set a flag and act in `_pack_tick`.
- Option dictionaries use string keys, and unknown keys are errors.
- Linear damping is 0 project-wide, so nothing slows down except by the laws.
- The capability lint treats any `.input` or `.cameras` as use of that capability.
- A game script that reads the game through `get_parent()` works but is ugly; `ctx.pack_state()` is the door.

## Questions for the Director
1. **Bot not done within `--frames`.** I report `bot.completed` false with outcome `watchdog`, exit 3, reading RUNNER's "frame budget exceeded". Is that right, or should it be `failed`, exit 1?
2. **Additive report fields.** I added check `smoke.no_engine_errors`, `metrics.tick_ms_max`, `metrics.state_hash_b`, and the `smoke.*` checks inside `invariants`, `bot` and `capture` reports. Will WP3 validate `tl.verify/1` strictly? If so, bless or strike these.
3. **Fence extensions.** I added `randf_range(`, `randi_range(`, `randfn(`, `.shuffle(`, `.pick_random(` and `WorkerThreadPool`. Proposed wording for PACK.md: "…`randf(`, `randi(`, `randomize(` and every other door to the global generator (`randf_range(`, `randi_range(`, `randfn(`, `.shuffle(`, `.pick_random(`)".
4. **`capture --test=<bot>`.** I added it so V5 can show the game being played rather than idle. Keep it?
5. **Capture driver.** Should captures be pinned to one rendering driver (`TL_RENDER_DRIVERS=d3d12`) so every V5 image comes from the same backend, given the Vulkan crashes?
6. **Wall-clock limits.** Are the 250 ms tick limit and 8 ms p99 meant as written? A frame-counted watchdog cannot stop a loop that never yields a frame.
7. **Bypass heuristic for "hand-rolled score or clock".** It matches variables named `score`, `clock`, `timer`, `lap` and similar. Is that enough?

Everything is under `C:\Users\kazda\kiro\third-life\engine\`; start with `kernel\API.md`, and `JOURNAL.md` has the timeline.

---

## Director verification

Done 19:55 to 20:00 CEST on 2026-11-10, after the builder had stopped.

### What was re-run, and the result

| Check | Result |
|---|---|
| `bash engine/tools/tl.sh selftest` | exit 0, `52 passed, 0 failed`, 69 s; no Godot process left behind |

Then the Director's own checks, on copies of `pack_min` placed **outside the project** and broken by hand, spawned
directly as `RUNNER.md` says (no shell wrapper), comparing exit code, the report file and the last stdout line:

| Case | Exit | Outcome | Detail |
|---|---|---|---|
| good pack, `lint` | 0 | passed | level V1 |
| good pack, `smoke` 3,600 frames, seed 1, twice | 0 | passed | `state_hash 21b9fc200e01...` both times |
| good pack, `smoke`, seed 2 | 0 | passed | `state_hash c7985aa370e8...`: differs, as it must |
| good pack, `invariants` and `bot` | 0 | passed | |
| `OS.get_name()` added to the tick | 1 | failed | `fence scripts/main.gd:36 'OS.' is outside the fence` |
| `"author"` added to the manifest | 1 | failed | `schema pack.json:5 unknown key 'author'` |
| `while true: pass` at frame 30 | 3 | watchdog | `tick_timeout: _pack_tick did not return within 250 ms`; ended in 0.7 s, no hang |
| pack directory that does not exist | 2 | not_run | `pack directory not found` |

In all eleven runs the last stdout line and the report file parsed to the same value, and `outcome` agreed with the
exit code. The acceptance list in the brief holds.

### What is not verified

- **Kit, rig and style integration has never run.** The kernel was built against stand-ins; the paths that call
  `TLKit`, `TLRigs` and `TLStyle` are written to the contract and untested. First step of WP4.
- **The measured law numbers** (slide distances, restitution, braking on ice against asphalt, fracture thresholds) come
  from the example bots inside the selftest. The Director saw them printed by the re-run and did not re-derive them.
- **Capture** was exercised once by the selftest (a 149,603-byte PNG). The Director did not look at a kernel capture,
  and the builder reports that about 70 % of windowed workers crashed in the AMD Vulkan driver while another Godot
  process ran, with a fallback to Direct3D 12 that worked 12 times of 12.
- The primitives the builder lists as written but exercised by no example (rule periods and sudden death, jump,
  reverse and all-wheel drive, most steering functions, HUD and audio beyond state checks).

### Director's decisions on the builder's questions (contracts amended on 2026-11-10)

1. **A bot that does not finish within its frame budget is `failed`, exit 1**, with `bot.completed` false. Exit 3 is
   reserved for a run the watchdog had to stop. To change in the kernel (WP4).
2. **Additive report fields are allowed.** Readers of `tl.verify/1` accept unknown `checks[].id` values and unknown keys
   inside `metrics`; the top-level keys stay fixed. The builder's additions are accepted.
3. **Fence extensions accepted** (`randf_range(`, `randi_range(`, `randfn(`, `.shuffle(`, `.pick_random(`,
   `WorkerThreadPool`).
4. **`capture --test=<bot>` is kept**: V5 should judge the game being played, not an idle scene.
5. **Captures are pinned to Direct3D 12** (`TL_RENDER_DRIVERS=d3d12` as the default), so every V5 image comes from one
   backend. Lane B's look test also ran on Direct3D 12.
6. **Three wall-clock limits are the stated exception** to "time is physics frames": the 250 ms tick limit, the 10 s
   setup limit and the 8 ms physics p99 (judged on the better of two runs). They guard the machine, not game logic.
7. **The score-or-clock bypass heuristic** is enough for the spike; its false positives will show in Phase 1 reports.

### Size

Runner and host 1,716 lines, kernel API 2,962, stand-ins 343, tools 211, example packs 892 good and 1,167 bad,
`API.md` 458 lines. 61 minutes of builder time, 435,836 tokens.
