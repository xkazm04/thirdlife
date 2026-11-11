# P5: a world that loads without a hitch

You are a builder on **Third Life**: a single-player sandbox on Godot 4.7.2 (Jolt physics, 60 Hz fixed tick) in which
an LLM builds small games ("packs") over a law kernel, and the games all keep running in one world a visitor walks
through. The owner spends this day and night on **perfecting the core before content spreads it**: every engine change
gets more expensive with each game built. Round 1 landed today: limits that count processor time and a performance
ledger (`docs/PERF.md`, `docs/reports/P1-MEASURE.md`); one contact pass per pack instead of a script per body
(`docs/reports/P2-HOTPATH.md`); a second pass on the look with characters, sky and motion (`docs/reports/P3-LOOK2.md`);
land with relief, plots as terraces and a visitor with a body (`docs/reports/P4-RELIEF.md`). You own one of five
packages of round 2. The night ends with a Windows executable built from the merged result, so leave your part green.

## Why this package exists
The owner asked for progressive loading as large shared worlds do it. Today nothing in the world loads progressively.
A pack is built in one blocking call (0.4 to 0.7 s without its own far scenery); a pack rebuilt from its seed costs one
frame of 855 to 921 ms in the windowed tour (`docs/reports/P4-RELIEF.md`, `N7-WORLD.md`); every pack of a world is
loaded before the first frame (six packs: seconds; sixty: half a minute). The simulation itself is cheap: a tour tick
is about 1.4 ms. The frame a player sees must never wait for a build.

## Read first
1. `docs/reports/N5A-TIERS.md` (loading: where the time goes), `docs/reports/N7-WORLD.md` (the rebuild inside a tick
   and the one-tick rest), `docs/reports/P2-HOTPATH.md` (its two patches and the asleep-pack question),
   `docs/PATCHES-P1.md` (entries 1, 2, 5, 6), `engine/kernel/world/PATCHES-P4.md` (entry 1).
2. `engine/kernel/world/world.gd`, `pack.gd`, `tiers.gd`, `tiers.json`, `draw/view.gd`, `engine/kernel/host/guard.gd`,
   `world_supervisor.gd`, `engine/kernel/world/WORLD.md`, `TIERS.md`.
3. The research on what Godot allows off the main thread: `reports/Living world layering for Third Life.md`, section
   "Godot streams by hand" (building node trees on a thread and attaching them later is allowed; attaching is where
   the hitch sits; forum figures only). Measure before you believe it.

## Scope
Yours: `engine/kernel/world/world.gd`, `pack.gd`, `tiers.gd`, `tiers.json`, `TIERS.md`, new `engine/kernel/world/jobs.gd`
(or a name of your choice under `kernel/world/`), `engine/kernel/world/draw/view.gd`, `engine/kernel/host/guard.gd`,
`world_supervisor.gd`, `engine/kernel/api/tl_contact.gd` and `tl_bodies.gd` only for the two P2 follow-ups below,
`engine/kits/**` only for build entry points that must become thread-safe or sliceable (no change to what a part looks
like), `engine/tools/world.sh`, `engine/tools/view.sh`, `engine/tools/selftest.sh` (new cases), `devx/lib/perf/**`
(the new scenario), `engine/kernel/world/walks/**` (new walks). Not yours: `engine/kernel/world/draw/draw.gd`,
`landscape.gd`, `terrain/**` and `visitor.gd` (the far-games builder), `engine/kernel/api/tl_input.gd`,
`tl_context.gd`, `engine/kernel/runner/**` (the contract builder), `engine/style/**`, `foreman/**`.

## Laws of this world that you must keep
A pack is simulated at its own origin in its own physics space and equals itself alone: after your work every world
proof still passes (`world.same`, `world.sliced_and_paused`, `world.walk_proof`, `world.tour`, `world.next_round`,
`p1.world_runaway`) and `bash engine/tools/view.sh check ...` (the command in `WORLD.md`) passes. Loading is not
simulation: when a pack becomes visible or ticked later because it was still loading, that must be an event in the
world log so that the replay does the same.

## The work, in this order
1. **Measure where a load goes, per frame.** For a seed, an example and the hockey pack: script loading, the kit's
   mesh building, body creation, the first physics step, the attach to the tree, the first draw (pipelines). Which
   parts can run on a worker thread in this engine, which must be on the main thread, which can be cut into slices.
   A table before you change anything.
2. **A build queue with a frame budget.** Packs are built in slices or off the main thread and attached within a
   budget per frame (a number in `tiers.json`), ordered by distance to the visitor and by tier. A world starts
   showing its first frame before every pack is built: near packs first. Until a pack is built its plot shows its
   pad (and its stand-in if one is cached); the scheduler treats it as not yet there, and the log says when it arrived.
3. **Rebuild and return from ledger without a hitch.** The same queue; the one-tick rest stays.
4. **Reload a pack inside a running world.** `world.sh`/the world host can replace one plot's pack by a freshly loaded
   copy of the same directory (after a tuned value or a change request) without restarting the world or touching the
   other packs. The kernel could not load a pack twice in one process before last night; find what still stands in
   the way (script and resource caches) and prove a changed `data/*.json` value takes effect.
5. **Warm-up.** First use of a material or effect must not cost a frame: warm the style's pipelines at world start
   (measure the first-use cost first; if it is under a millisecond say so and skip this).
6. **The ledger scenario `walk30`.** A visitor walks through a village of 30 games that load on approach. Metrics:
   `worst_frame_ms`, `frame_ms_p99`, `worst_tick_ms`, time to first frame, time until the nearest six are built.
   Apply `docs/PATCHES-P1.md` entry 1 (`view.gd` prints `frame_ms_p99_all` and `frame_ms_max_all`) so that `tour6`
   reports them too, and entry 2 (a windowed world is supervised: a runaway pack does not close the window for good).
7. **Two follow-ups from the hot-path package** (`engine/kernel/api/PATCHES-P2.md`): the pack's tick calls its
   tracker explicitly, so the order is written in code and not implied by a priority; an asleep pack is cheap again
   by letting the kernel's own wake paths (`TLBodies.push`, `drive`, `TLBall.shoot`, `place`, `release`) tell the
   tracker, without changing any hash (the first attempt changed the hockey game's hashes because a body woken inside
   `_pack_tick` was skipped: do not repeat it).
8. Apply `engine/kernel/world/PATCHES-P4.md` entry 1 (a walk states a pad's height once; `view.gd` reads it).

## Acceptance (the Director will run these)
- `node devx/bin/tl.mjs perf run --scenario walk30`: no frame over 16.7 ms and no tick over 8 ms of processor time
  after the first frame, or the honest figures and what stands in the way. `tour6`: `worst_frame_ms` under 16.7
  (it is 855 to 921 ms today).
- Time to first frame of the six-game village and of the thirty-game village, before and after.
- Every world proof and the drawing check pass; seed and hockey hashes unchanged.
- A selftest case that reloads one pack in a running world after a data value changed, with the other packs' hashes
  equal to an undisturbed run.
- 60 asleep packs cost no more than before the hot-path package (1.33 ms a tick in its side-by-side run), hashes
  unchanged.
- `node devx/bin/tl.mjs check --tier full` green in your worktree.

## The repository's laws (verbatim from `CLAUDE.md`; they bind you)

## Laws that bite (details in the contracts)

- **Time is physics frames** (60 Hz). Tests, bots, captures, watchdogs count frames, never wall clock.
- **Determinism**: same pack + seed + frames = same `state_hash`. Randomness only from the kernel's seeded generator.
- **Unknown keys are errors** in every JSON schema. **Absent value = omit the key** (never `null`, never `0`).
- **Lists, not singletons** for anything a game may have more than one of.
- **Class names**: `TL*` belongs to the kernel except `TLKit`, `TLRig`, `TLStyle`, `TLMesh` (kit/rigs/style). Packs never declare `class_name`.
- **Packs use only the `TL*` API.** No hand-made materials, lights, environments (the runner counts them as bypasses). Look in `engine/kits/KIT.md` before making a mesh.
- **kit, rigs, style reference nothing outside themselves.**
- **Reuse before building**: kit part, seed pack, `engine/kernel/API.md` (generated index: `docs/generated/API-INDEX.md`).
- Windows 11 + Git Bash. Godot console exe via `TL_GODOT` or `.tl/local.json` (`tl doctor` says what it found). Other sessions load this machine: never kill a process you did not start; prefer `--headless`.

## How to work
- **You work only in your own git worktree: `C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p5`** (branch `core-p5-loading`, cut from the merged round 1). Every path in
  this brief is relative to it unless it is written in full. Never edit anything under the main checkout
  `C:\Users\kazda\kiro\third-life` outside your worktree; you may read there (`site/` holds the real jobs' packs
  and is not in your worktree: the hockey game is at
  `C:\Users\kazda\kiro\third-life\site\ice-hockey-three-against-20261111-1\promoted\game.ice_hockey_three_against@0.1.1`).
- **No git command of any kind**, not even a read-only one. The Director stages and commits your files. The `tl` tool
  may call git for you. No test of yours runs git against anything but a temporary repository with `GIT_DIR` unset.
- Godot: `export TL_GODOT="C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe"`. Your
  worktree has no `.godot` cache yet: the first engine run builds it. `foreman/node_modules` is linked.
- Gates: `node devx/bin/tl.mjs check --tier fast --changed` while you work; `node devx/bin/tl.mjs check --tier full`
  once at the end. Four other builders run the engine on this machine tonight. Limits now count processor time, so a
  busy machine should no longer fail healthy code: if it still does, that is a finding for your report. Timing figures
  go through `node devx/bin/tl.mjs perf run` where a scenario exists, and you say whether the run was marked quiet.
- Kill every process you start; never kill others; never leave a window behind (windows go to `--position 0,1440`).
  No network. No model calls. Never read, use or print any `ANTHROPIC_KEY_*` variable.
- Small verified steps. Journal each in ``engine/JOURNAL.md` under a "P5" heading`.
- Contracts (`contracts/**`) are the Director's: write proposed contract text into your report.
- For anything outside your file scope, write the exact patch and its reason to ``engine/kernel/world/PATCHES-P5.md`` instead of editing.
- **Your measurement outranks this brief.** Where a premise here is wrong, say so with the evidence and build the
  right thing; a fix that makes the measured result worse is withdrawn and documented, not tuned.

## Final message (your report, as text; the Director saves it to a file)
Status; per item what you built and the command, figure or picture that proves it (full paths); the acceptance
checks one by one with their result; the list of files changed with a line each; proposed contract text; the contents
of your patches file; what changed for a pack author; what you did not verify; questions; minutes spent from real
timestamps (`date`).

## Time-box
Until the list is done or **110 minutes after your start** (run `date` first and often). The first items proven
are worth more than all of them half done. Leave the last fifteen minutes for the full gate and the report. A usage
limit can cut you off without warning: keep the journal current, and if you are resumed, re-read this brief and your
journal and continue.
