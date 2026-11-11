# P11 the world joins the contract, and a person can walk: builder report and Director verification

Brief `briefs/BRIEF-P11-CONTROLS.md`. Builder wall time 16:39 to 18:02 on 2026-11-11 (83 min; harness: 397,308 subagent tokens, 169 tool uses). Work done in the worktree `.claude/worktrees/core-p11` (branch `core-p11-controls`).

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

# P11 REPORT: the world joins the contract, and a person can walk

Worktree `C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p11` (branch `core-p11-controls`). Started 16:38:59, finished 18:02 on 2026-11-11 (83 of 120 minutes).

## Status

- All seven items are built and proven. The second full gate (`node devx/bin/tl.mjs check --tier full`) passed at 18:01: exit 0, foreman.test 174, kernel.selftest 106.
- The first full gate at 17:39 failed two steps, both consequences of my own changes. Both are fixed and the second gate proves the fixes:
  - A fourth Foreman test line still expected `kernelApi` 0.1.
  - P7's handler case could no longer run, because `play` now refuses a pack that has a handler.
- One premise of the brief was incomplete. A recorded visit replays to the same pack hashes only on a fixed schedule (`--cost=model --load=block`). In a window, the measured cost and the build queue follow the wall clock. The visitor's path replays exactly either way.

## Per item

**1. The world's hash is the contract's hash.**
- What I built:
  - `pack.gd` `state_hash()` now calls `kernel/host/statehash.gd` with the pack's generator, input and origin. `_q`, `_put_v3` and `_hash_node` are gone; the file went from 626 to 608 lines.
  - New command `world.sh alone`: it runs the world, then runs each pack alone through `tl.sh smoke` or `tl.sh bot` for the same number of its own ticks.
- Proof: `bash engine/tools/world.sh alone --packs=seed_drive,seed_wall,ex_walker,seed_paddle,ex_kit,ex_car,<hockey> [--mode=bot --frames=20000 | --frames=1200]`.
- I ran it twice, at 16:44 and again at 17:21. Both times all 7 games had the same hash in the world as alone, in both modes. The old column comes from the main checkout, which still has the old `pack.gd`.

| game | smoke 1200: old world hash | new world hash = alone | bot ticks | bot: old world hash | new world hash = alone |
|---|---|---|---|---|---|
| seed.drive | c7da9d951fc6110d | 6a516bfbd1f5c989 | 3517 | 8cd7d7d8349bf1b8 | b912bc471e4967a9 |
| seed.wall | 458b09fd2c33eedb | cc441459b7e8a255 | 1221 | 9489b7fc31070d21 | cb75fb26a1e80254 |
| example.walker | 5327455f4c37a19d | a8177643d51ae9ae | 371 | 8d1831dc62dfe91a | f1c7b53757c34040 |
| seed.paddle | 22b0827088162ef5 | cadfbc7e135a8a76 | 4486 | c39a75d7c5724055 | dff1a390470352e7 |
| example.kit | 9fe0149a6d091f72 | 2e88828ee6abf843 | 332 | 34b19960cc4c5308 | 6b270cedbf59690d |
| example.car | 59304d9bcbfe5c4f | aea92ab96f500d24 | 1872 | 7983b4ce7b144296 | 3a459d0fe25e7853 |
| hockey 0.1.1 | 65ec20826c7a4ea4 | a1cbdb7eebf570ce | 8130 | e01e3cd7ccf6de31 | 7326d67aeb26ad7a |

- The bot hashes are exactly the hashes in P7's table.
- One finding: with `--at` set to the village offsets, all 7 hashes differ from the runner's. A pack simulated far from the origin moves differently (single-precision physics). Walks never set `at`: every plot runs at its own origin in its own physics space, so this does not affect the village.
- The world proofs `world.tour`, `world.proof`, `world.reload`, `world.queue` and `world.same` passed inside both gates.

**2. Event handlers are off in a world, `_input` is a fence error, and packs say `kernelApi` 1.0.**
- New `pack.gd` `_enter_tree()`: a `node_added` handler that switches off the event handlers of the pack's own scripts once each node is ready.
- Case `p11.world_handler_off`: the pack sends itself a device event, then checks whether its handler is still on.
  - Control: with that function renamed, the case FAILS with "a pack handler saw a device event; the handler is still switched on".
- Lint: the `_input` handler row moved from BYPASS to FENCE, and `InputEvent\w+` became `InputEvent\w*`. `lint.gd` stays at 600 lines.
- `bad_bypass`: its handler is replaced by a 3-line comment, so every other case keeps its line numbers. `bad_fence` gets two one-line handlers.
- Case `p11.input_handler_fence`: a copy of `bad_bypass` with its handler put back fails lint on that line.
- `kernelApi` is now 1.0 in 33 `pack.json` files (seeds and examples) and in the three Foreman lines.

**3. The visitor's input is a record.**
- New file `engine/kernel/runner/visit.gd` (262 lines):
  - The world gets one `TLInput` of its own, with actions forward, back, left, right, run, enter, leave, quit and the pointer.
  - It is sampled once per world tick. Mouse motion and the device script are handled above the sampling line; nothing below it reads a device.
- Options:
  - `--record=<file>` writes the visit as `tl.input/1`: `pack` is the walk's name, `mode` is `"play"`.
  - A game played on stage is written as its own record, `<file>.<plot>.<n>.json`, in the same schema with that pack's own frame numbers.
  - `--input=<file>` replays the visit.
  - `--devices=<file>` is a device script for tests.
- `view.gd` now calls the visit and no longer reads keys; it went from 595 to 562 lines.
- Proof: `bash engine/tools/world.sh visit-proof` → PASS at 17:12. A scripted person (`boot/visit_proof.devices.json`) is recorded over 1,900 ticks of the tour's world, enters the track at tick 1440, plays it, presses Q at 1700 and Esc at 1900. The record is then replayed twice.
- Both replays were the same as the recording at every 300th tick:

| tick | feet x, y, z |
|---|---|
| 300 | -81.5, 0.12, 0.77 |
| 600 | -81.27, 2.9, 14.27 |
| 900 | -53.95, 2.22, 7.39 |
| 1200 | -22.78, 0.04, -3.48 |
| 1700 (after Q) | 0.0, -2.52, -21.0 |
| 1800 | 0.0, -2.52, -18.0 |
| 1900 | 0.0, -2.52, -16.5 |

- All 6 pack hashes were the same in all three runs: drive 51e7c714798e0976, wall 91d21fbfbd287c7d, walker f1c7b53757c34040, paddle 1f933bb41aa67f1f, kit 6b270cedbf59690d, car 03b291a2cf8b8241.
- Without `--cost=model --load=block`, the path was the same but the pack tick counts differed between runs (drive 1253, 1221, 1235). This is PATCHES-P11 entry 6.

**4. Controls a person can use.**
- What changed:
  - W and S move along where the camera looks; A and D sidestep.
  - The mouse turns the view at 0.15 degrees per pixel. Pitch stays between -10 and 60 degrees.
  - The camera sits behind him with no smoothing.
  - Shift runs, E enters, Q leaves.
  - Esc quits when nobody is on stage: the walk ends on the next tick, so every pack is hashed.
  - The mouse is captured while he walks, and released while a game is on stage or when the window loses focus.
  - After Q he stands 5 m outside the plot at its gate, facing away from it, with the camera snapped behind him.
  - The key line on screen now reads "W S walk / A D step aside / mouse look / Shift run / E enter … / Esc quit".
- Measured in the exe with scripted keys and mouse (`TL_EXE_KEYS` now also takes mouse moves, `<frame>:~dx,dy`; the trace includes yaw). The editor run gave identical figures:
  - W for 180 frames: 13.50 m, all points on one straight line.
  - D for 180 frames: 13.50 m, at exactly 90.0 degrees to the W line.
  - 600 px of mouse: 90.00 degrees, and -600 px turned him back.
  - 100 px up or down: 15.0 degrees of pitch (editor run).
  - After Q on the track: at (0, -21), 5.0 m outside the plot's edge, yaw 180, facing away from it.
- I looked at three pictures from the editor run in `C:\Users\kazda\AppData\Local\Temp\claude\7d3340621aca3b8f\23bbf8b6-20c4-4024-8c8c-d890f693decb\scratchpad\p11\rec\`:
  - `01_walking.png`: he is seen from behind on the road.
  - `02_on_stage.png`: the drive game with its own HUD.
  - `03_after_leave.png`: he stands between the gate's flags, facing the road, with the camera behind him.

**5. The door of the exe.**
- `host.gd` `_ensure_import` returns at once outside the editor binary, so the exe no longer starts itself again. The file stays at 605 lines.
- `Manifest.resolve_dir` keeps a `res://` path as it is in an export.
- A live walk runs none of the walk's scripted visits, and takes no pictures without `--out-dir`.
- The exe has its own user folder, `%APPDATA%\ThirdLife`, through a feature override in `project.godot`.
- `boot.gd` lost its own Esc reading and its removal of events for a live walk. It gained `--record`/`--input` pass-through and mouse moves in `TL_EXE_KEYS`.
- `export.sh check` changes:
  - The key route turns with the mouse instead of W+D.
  - The Esc test now looks for `[visit] the visitor quit at tick`.
- Proof: `bash engine/tools/export.sh --commit ...` and then `bash engine/tools/export.sh check` → PASS at 17:18.
  - The 7 games had identical hashes in the editor binary, the exe and the copied exe, e.g. drive 44fdc089a61f3ae3 and hockey 246a1489b2b1803d.
  - E was shown on the paddle court from frame 750 to 990; Esc ended the exe at tick 1101.

**6. Options through the host.**
- `world` now lists `load`.
- `world-view` now lists `load`, `trip`, `dead`, `picture`, `record`, `input` and `devices`. The table in `verbs.json` matches (case `verbs.json_matches_host` passes).
- The environment variables `TL_WORLD_LOAD`, `TL_WORLD_TRIP` and `TL_WORLD_DEAD` are gone from `view.gd` and `world.sh`.
- `--picture` sets `draw.force_picture`. `draw.gd`'s own read of `TL_DRAW_PICTURE` is P13's file and is still there (PATCHES-P11 entry 5).

**7. Windowed test runs.**
- `world.sh` (tour, visit-test, visit-proof) and `view.sh` now take a machine-wide lock: a folder `%TEMP%\thirdlife_window.lock` holding the holder's pid. A dead holder's lock is taken over. `TL_WINDOW_LOCK=off` skips it.
- Test windows start with `--audio-driver Dummy`. `world.sh visit` (a person) takes no lock and keeps the real sound; the exe keeps the real driver.
- Proof: I started two `world.sh tour tour --out-dir` runs in the same second.
  - A took the lock at once. B printed "waiting" and took the lock 14 s later, when A's window closed.
  - Both passed `world.tour`, with window frame p50 of 2.66 ms and 2.46 ms (no throttling).
  - A lock left with a dead pid (99999) was taken over.

## Acceptance

| criterion | result |
|---|---|
| Item-1 table: seven games, world hash = alone hash, twice | **met** (16:44 and 17:21, smoke and bot) |
| Selftest world cases and the new cases pass | **met** (106 cases in gate 2, including `p11.world_alone`, `p11.world_handler_off`, `p11.input_handler_fence`) |
| `tl.sh lint` passes on the three seeds, the examples and hockey | **met** (all 12 exit ok) |
| `bad_bypass` fails lint on its `_input` handler | **met in substance** (see below) |
| A recorded visit replays to the same path at five named ticks and the same pack hashes | **met with `--cost=model --load=block`** |
| Item-4 control measurements from the exe | **met** (figures in item 4) |
| `export.sh` and `export.sh check` pass | **met** |
| `tl check --tier full` green | **met** (18:01) |

- On `bad_bypass`: following PATCHES-P7 section 4, the example no longer carries the handler and stays a passing bypass example. Its copy with the handler put back fails lint on that line (`p11.input_handler_fence`), and `bad_fence` now fails on two handlers.
- On the replay: without a fixed schedule the path is the same but the pack hashes differ.

## Files changed

- **Engine code:**
  - `kernel/world/pack.gd` (only `state_hash` and the new `_enter_tree`)
  - `kernel/world/visitor.gd`
  - `kernel/world/draw/view.gd`
  - `kernel/runner/visit.gd` and `visit.gd.uid` (new)
  - `kernel/runner/lint.gd`, `manifest.gd`, `verbs.json`
  - `kernel/host/host.gd`
  - `boot/boot.gd`, `boot/visit_proof.devices.json` (new), `boot/PATCHES-P11.md` (new)
  - `project.godot`
- **Tools:** `tools/world.sh`, `tools/view.sh`, `tools/export.sh`, `tools/selftest.sh`.
- **Packs:** `kernel/examples/bad_bypass/scripts/main.gd`, `kernel/examples/bad_fence/scripts/fence.gd`, and 33 `pack.json` files under `seeds/` and `kernel/examples/`.
- **Docs:** `docs/EXE.md`, `engine/JOURNAL.md`.
- **Foreman:** `foreman/src/manifest.ts`, `src/test/engine.test.ts`, `src/testing/fake-runner-core.ts`, plus **`src/test/wp3b.test.ts` line 45**. That fourth line is outside my scope: the test expected the composed `kernelApi` to be "0.1" and failed the gate once the Foreman wrote 1.0.
- **Lines of P7's selftest cases I had to touch** because of the move to 1.0 and the new fence error:
  - `bad.bypass`: its line-24 pattern is dropped.
  - `p7_pack`: resets `kernelApi` to 0.1 before its own edit.
  - `p7.api_0_1_is_1_0`: now runs on a copy that says 0.1.
  - `p7.fence_handler_switched_off`: now proven in a smoke run, because play refuses the pack. Its control (the worker's switch-off line removed) FAILS, and it passes with the line restored.
- No public kernel API member was added; `api-v1` passes.

## Proposed contract text

**PACK.md:**
> `func _input` / `_unhandled_input` in a pack is a fence error (P11), not a counted bypass. The kernel still switches any pack script's event handlers off, in a single run and in a world. Packs and the Foreman write `"kernelApi": "1.0"`; "0.1" is still read as 1.0.

**RUNNER.md, world modes:**
> A pack's state hash in a world is the runner's hash (`kernel/host/statehash.gd`: bodies relative to its origin, `_pack_state`, generator, input). A pack in a world at its own origin hashes as `tl.sh smoke` / `bot` hashes it alone after the same number of its own ticks.
>
> `world-view` options: `load`, `trip`, `dead`, `picture`, `record`, `input`, `devices`.
>
> A person's visit is a `tl.input/1` record: `pack` is the walk's name, `mode` is "play", and a game played on stage is `<record>.<plot>.<n>.json`.

## Patches file

`engine/boot/PATCHES-P11.md`. None of it is applied or run.

1. **Needed at the merge:** `tools/item.sh` line 303 must read `s#"kernelApi": "1.0"#"kernelApi": "2.0"#`. Otherwise `manifest.kernel_api_patch_level` fails, because `pack_min` is now 1.0. I read this in the code and did not run it: item.selftest is skipped in a worktree.
2. `world.gd`: do not hand the walk's events to the scheduler when a person walks. This would replace my reach into `tiers._visits` from `view.gd`.
3. `world.gd`: with two packs, the world line's `script_errors` was 0 although both errors were printed (measured).
4. `landscape.gd`: publish the gate directions as `tl_gates`. Today `visit.gd` recomputes them from the walk's road.
5. `draw.gd`: drop the `TL_DRAW_PICTURE` environment read now that `--picture` exists.
6. A person's real visit (measured cost, build queue) needs its world log in the replay as well: proposal for `--replay` plus `--input`.
7. `w_pile` and `w_pile_x` `pack.json`: `kernelApi` 1.0 (optional).
8. `WORLD.md`: its text about the person's keys is stale.
9. `TLInput`: a captured mode for the pointer. It is not proposed for tonight; `visit.gd` injects the mouse look with `press()` instead.
10. PATCHES-P9 entry 1, second half (the worker command lines in the exe): not done.

## What changed for a pack author

- Write `"kernelApi": "1.0"`.
- A `func _input` or `_unhandled_input` is now a lint error, and `play` refuses the pack.
- A pack's hash in a world is now the hash `tl.sh` prints for it alone.
- Every world hash changed once; the old and new values are in the table above.

## What I did not verify

- A real person at keyboard and mouse: the feel of the controls, the mouse sensitivity, and capture and focus behaviour.
- `--input` replay of a visit that ended by closing the window: the replay has no end tick then and runs until closed.
- `item.selftest` and `ui.selftest` (skipped in the worktree).
- No figure was taken on a quiet machine: perf was "busy", and all timings are busy-machine figures.

## Questions

1. Should a person's visit write a world log by default (`--log`), so that a measured-cost visit replays exactly?
2. Is the Director content with the fourth Foreman line (`wp3b.test.ts:45`) and the edited P7 selftest lines?

The Godot processes still running at the end (four of them) are not mine. Every run I started has ended.

---

## Director verification

Done 18:03 to 18:20 on 2026-11-11 in the builder's worktree. The command runs were made by a Sonnet subagent and
read by the Director; the pictures were looked at by the Director. No step needed a second run.

### What was re-run, and the result

| Check | Result |
|---|---|
| `world.sh alone --packs=<seven games> --mode=bot --frames=20000` | PASS: seven of seven, the hash in the world equals the hash alone, and each is the hash of P7's table (drive `b912bc471e4967a9` at 3,517 ticks ... hockey `7326d67aeb26ad7a` at 8,130) |
| the same as smoke, 1,200 ticks | PASS, seven of seven |
| `world.sh visit-proof` (a scripted person recorded over 1,900 ticks with an enter and a leave, replayed twice) | PASS: both replays "the same path and the same hashes". After leaving he stands 5.0 m outside the plot's edge, turned away from it |
| selftest cases `p11.`, `p7.`, `bad.` | 3, 20 and 30 passed; 0 failed |
| lint on the three seeds and hockey | clean, four of four |
| lint on `bad_fence` | fails as it should, naming the `_input` handler twice: "is outside the fence: input goes through ctx.input (P7; an error since P11)" |
| `export.sh --commit p11-check`, `export.sh check` | PASS: seven games, the same hash from the editor binary, the exe and the copied exe; 0 errors. Shift+W: 31.50 m in 210 frames. E put a game on stage from frame 750 to 990, Q had him walking again at 1080, Esc ended the process at tick 1101 with exit code 0 |
| two windowed tours started in the same second | both PASS. The first took the lock at once; the second printed "another test window is open (process ...): waiting for it" and took it 14 s later. The lock folder was gone afterwards |
| `node devx/bin/tl.mjs check --tier fast` | PASS |

The check prints no line for the angle the mouse turns him by; the builder's figures for it (600 pixels = 90
degrees) are from its own traced runs and were not re-measured. The second of the two tours had frame spikes late in
its run (99th percentile 547 ms) while other verification runs used the machine; its proof passed.

### Looked at (Director)

`scratchpad/p11/rec/01_walking.png` and `03_after_leave.png`: on the road seen from behind, and after Q between the
gate's two flags, facing the road, the camera behind him, the fence and a sign at the sides. He is where a person
expects to be after walking out of a venue.

### What this settles

- The world joined the contract. A game in a world is hashed by the same code as a game alone, and the two agree
  for all seven games: "every game equals itself alone" is now checked against the runner, not against another world.
- The visitor's input is a record like a game's. A visit can be replayed to the same path; this is the form a
  second player's keys will arrive in.
- A person can steer: forward and back along the view, sidestep, mouse look, and a sensible place after leaving.
- Test windows wait their turn and open no sound device: this afternoon's two false failures cannot repeat.
- The exe no longer has to work round the host: it has its own user folder and its door is the kernel's.

### What is not verified

A person at keyboard and mouse: how the controls feel, the mouse's sensitivity, what capture does on a second
screen. A recorded visit in a live window replays to the same path but not to the same game results, because the
measured cost and the build queue follow the wall clock (the builder's entry 6).

### Director's decisions on the builder's questions

1. Yes: a person's visit should write its world log with the record, so that it replays exactly. Not in this run;
   it is the first item of the next kernel pass, together with `TLInput`'s captured pointer mode.
2. The fourth Foreman line and the edited selftest cases of P7 are accepted: both follow from decisions already made.

The proposed contract texts are accepted and go in with the round's merge.
