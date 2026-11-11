# P5 a world that loads without a hitch: builder report and Director verification

Brief `briefs/BRIEF-P5-LOADING.md`. Builder wall time 13:22 to 14:47 on 2026-11-11 (85 min; harness: 444,931 subagent tokens, 149 tool uses). Work done in the worktree `.claude/worktrees/core-p5` (branch `core-p5-loading`).

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

REPORT P5: a world that loads without a hitch (worktree core-p5, branch core-p5-loading)

## STATUS

Partly done. The build queue, the reload, the walk30 scenario, the supervised window and the two patch applications are built and proven, and `tl check --tier full` is green on the final code. The frame target is not met: an arriving pack still costs 17 to about 600 ms on the main thread (it was 762 to 921 ms for a seed). The asleep-pack follow-up and the warm-up were not done. No timing figure of mine was recorded as quiet; four other builders loaded the machine the whole time.

Evidence directory (all scratch files named below are in it):
`C:\Users\kazda\AppData\Local\Temp\claude\7d3340621aca3b8f\23bbf8b6-20c4-4024-8c8c-d890f693decb\scratchpad\p5\`

## THE WORK, ITEM BY ITEM

### 1. Where a load goes (measured before any change)

The table is in `C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p5\engine\kernel\world\TIERS.md`, section "P5: loading is not simulation".

| part | seed_drive | seed_wall | seed_paddle | hockey | where it can run |
|---|---|---|---|---|---|
| entry script, first time / later | 342 / 0.2 ms | 31 / 0.2 | 24 / 0.2 | 28 / 0.1 | worker thread |
| `_pack_setup`, whole | 358 | 371 | 413 | 771 | |
| of it `TLKit.build_layout` | 354 | 274 | 398 | 18 + 155 | worker thread |
| of it the rest (own bodies, rigs, parts) | 4 | 97 | 15 | about 600 | main thread only |
| attaching a built venue to the tree | 13 to 23 | 13 | 13 to 14 | 0.1 | main thread, one call |
| laws | 0.1 | 0.2 | 0.3 | 0.2 | main thread |
| first two physics steps | 0.1 | 0.15 | 0.13 | 0.03 | main thread |

- **Layout on a thread:** the same layout built on a worker gave the same node, body and mesh counts and the same `Static` mesh hash, with no error, 5 to 35 % slower (`exp1.gd` in the evidence directory).
- **First draw:** the first drawn frame of a world costs 52 to 78 ms. Nothing stood out above an arrival's own attach.
- **Premise corrected:** the tour's 700 to 850 ms frames at ticks 44, 104 and 434 were its `shot` events (a 1920x1080 PNG encoded inside the frame), not only the rebuild.

### 2. Build queue with a frame budget

New file `engine\kernel\world\jobs.gd`. A pack is built in two halves:
- **Prepare**, on one worker thread: scripts loaded, every `tl.layout/1` file under `data/` built ahead through the new `TLKit.build_layout_ahead`.
- **Attach**, on the main thread at a tick boundary: `_pack_setup` runs and its `build_layout` only attaches the venue built ahead.

How it behaves:
- **Order:** tier first, then distance to the visitor. Ledger plots are not built.
- **Until arrival:** the plot holds a stub (`pack.gd` `stub`) and the scheduler leaves it out of `due`.
- **Arrival:** the event `{"t": N, "e": "built", "plot": id}` in the world log; first tick N + 1. A replay attaches at the same tick.
- **Modes** (`tiers.json` `load: {mode: auto, budget_ms: 4}`):
  - `queue`: attach what is ready (a window).
  - `step`: one pack per tick, built whole on the main thread, so arrival ticks depend only on the walk (no window).
  - `wait`: step order, but prepared on the worker and waited for (tests).
  - `auto`: queue in a window, step without one.
  - `block`: no queue, as before.

Proofs:
- **Headless, final code:** kernel.selftest, 83 cases passed, including `world.walk_proof`, `world.tour`, `world.next_round`, `world.same`, `world.sliced_and_paused`, `p1.world_runaway` and the new `world.queue` (three seeds built ahead by the worker, walk = alone = replay).
- **Window, real arrivals:** `world.sh tour tour --out-dir=...` with its proof passed, six packs tour = alone = replay (`tourproof.txt`, run at 13:54, before the last three code changes).
- **Hockey built ahead:** 3600 smoke frames in a `wait` walk give b0ddd31f0f70beeb, the runner's hash.

### 3. Rebuild and return from ledger

Both go through the same queue; the one-tick rest stays. The pack that is over stays drawn until the new one is attached. `world.next_round` passes in the gate; `world.sh proof ledger` passed at 13:41 (`ledger1.txt`) and was not re-run on the final code.

### 4. Reload inside a running world

- **Walk event:** `{"t": N, "e": "reload", "plot": id}` replaces that plot's pack by a fresh copy of its directory.
- **Test instrument:** a walk's `edits` (`[[tick, file, replacement file]]`) copies a file at a tick, as a scripted "designer saved a value".
- **Proof:** new selftest case `world.reload` passes. `ex_slide` reloaded at tick 300 with `start_speed` 4.5 hashes 838ccf3eb20d3d6b, equal to the changed pack alone and not 53e7691203ce75fe. `pack_min` and `ex_wall` hash as in the undisturbed run, and the log replays.
- **What still stands in the way:** a changed `.gd` is not picked up, because `load()` returns the cached script (PATCHES-P5 entry 2b).

### 5. Warm-up

Not built. See item 1, first draw: no run was quiet enough to say "under a millisecond".

### 6. Scenario walk30, and PATCHES-P1 entries 1 and 2

- **walk30:** `engine\kernel\world\walks\walk30.json` is 30 games along 1.5 km of road; games beyond 200 m are in the ledger and are built on approach. `devx\lib\perf\scenarios.mjs` has the scenario; `ledger.mjs` has the metrics `first_frame_ms` and `six_built_ms`.
- **Entry 1, frame tail:** `view.gd` prints `frame_ms_p99_all`, `frame_ms_max_all`, `frames_over_16_7_ms`, `slow_frames` and `world_to_first_frame_ms`. The first two frames are the start itself and are reported apart.
- **PNG off the main thread:** the tour's pictures are now encoded on worker threads.
- **Entry 2, supervised window:** `world.sh` `window_mode` restarts the window without a runaway pack. Run once (`runaway.txt`): the guard tripped at world tick 21, the window started again without pack 1, the tour ran its 240 ticks, exit code 1, no window left.

### 7. Hot-path follow-ups

- **Tracker called by name: done.** `pack.gd` `contact_pass` is called from the closing mark, after every node of the pack and before its physics step. A/B on 13 packs x (smoke, bot) x 1500 frames: old order = new order, every hash (`ab_old_*.txt`, `ab_new_*.txt`).
- **Asleep packs cheap again: not done.** `tl_contact.gd` and `tl_bodies.gd` are untouched. The 60-asleep-packs figure was not measured.

### 8. PATCHES-P4 entry 1

Applied in `view.gd`: a walk's `landscape.pad_h` is the plot's height, and `rim_band` comes from the walk.

### Bugs found and fixed on the way

- **Worker waits for the main thread.** A worker's server calls that return a value are run by the main thread, so a main thread that only sleeps while waiting deadlocks. `attach` and `stop` now flush both servers while they wait.
- **Image freed under its task.** A Callable holds no reference, so the picture was freed while its PNG task ran (one exit code 139). The images are now kept until the tasks are waited for.
- **Visitor fell through late plots.** A pack arriving after the landscape was built had no collider copies in the visitor's space (he ended at y = -432 m). `view.gd` now copies them at first arrival; he ends at 6.49 m.
- **Step-mode builds counted as ticks.** They would have failed the perf gate on a quiet machine for a cost that only moved. That time is now taken out of the tick and added to `load_ms`.

## ACCEPTANCE, ONE BY ONE

**1. walk30: no frame over 16.7 ms, no tick over 8 ms.** NOT MET. Recorded as line 7 of `perf\ledger.jsonl`, machine BUSY (use 99 %), not quiet:
- worst frame 359 ms, frame p99 7.6 ms, tick p50 2.9 ms, worst tick 363 ms;
- an earlier manual run had 184 of 12,000 frames over 16.7 ms (`walk30_1.txt`), one block of them a machine stall.

What stands in the way:
- the main-thread half of a build: 17 to 37 ms for layout seeds, 75 to 120 ms for seed_wall, 165 to 310 ms for `ex_walker` and `ex_kit` (no layout), about 600 ms for hockey (six rigs);
- `TLContext.current` is one static, so the rest of `_pack_setup` cannot leave the main thread;
- the worker's value-returning server calls wait for the main thread's next frame.

**tour6: worst frame under 16.7 ms.** NOT MET: 286 ms (same BUSY ledger line), against 762 to 838 ms in the quiet baseline. Frame p99 is 10.4 ms.

**2. Time to first frame, before and after.** One run each, machine busy, measured from the world's start to the first drawn frame (`ff_*_2.txt`):

| village | before (`TL_WORLD_LOAD=block`) | after (queue) | of which landscape |
|---|---|---|---|
| six games | 5.83 s | 2.28 s | 2.08 s |
| thirty games | 15.69 s | 6.43 s | 6.1 s |

The landscape is now the time to the first frame. `load_ms` of the tour went from 1675–1937 ms to 18 ms.

**3. Every world proof and the drawing check pass; seed and hockey hashes unchanged.** MET.
- World proofs: in the green gate (see item 2).
- `view.sh check` on five packs: PASS (`viewcheck.txt`). Seed bot hashes 36635c049bc6acd8, cadd1cd9fffac7b1, 6366b88f838e3e78.
- Hockey: `tl.sh smoke` b0ddd31f0f70beeb, `tl.sh bot` 5af10fbc23df0d76, and the same smoke hash in a world run.

**4. Selftest case that reloads one pack after a data value changed.** MET: `world.reload`.

**5. 60 asleep packs at 1.33 ms or less.** NOT DONE, NOT MEASURED. Hashes are unchanged.

**6. `tl check --tier full` green.** MET, on the final code (`gate_full.txt`): arch, assets, cards, devx.test 123, foreman.typecheck, foreman.test 158, kernel.selftest 83, kit.selftest 87, seeds 24. The perf step measured but did not judge (machine BUSY). `item.selftest` and `ui.selftest` were skipped: they need the main checkout's `site/`.

**mix30, block against step, same minutes, busy, two runs each:**

| | `load_ms` | tick p50 | tick p99 | worst tick |
|---|---|---|---|---|
| block (as before) | 13.0 / 13.4 s | 3.8 / 3.9 ms | 11.4 / 12.2 ms | 25.5 / 26.9 ms |
| step | 13.5 / 14.0 s | 4.0 / 4.1 ms | 9.4 / 9.4 ms | 15.6 / 36.5 ms |

`tl perf run --quiet-only --wait 60` found no quiet minute; nothing was recorded.

## FILES CHANGED

All under `C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p5\`.

- `engine\kernel\world\jobs.gd` (new): the build queue.
- `engine\kernel\world\plotfile.gd` (new): the world-file writer and directory hash, moved out of `world.gd` and `pack.gd`, which may not grow.
- `engine\kernel\world\jobs.gd.uid`, `plotfile.gd.uid` (new, written by the engine).
- `engine\kernel\world\world.gd` (672 lines, was 684): queue hooks, `built` and `reload` events, `load` in the world line.
- `engine\kernel\world\pack.gd` (626): `stub`, `manifest`, `contact_pass`.
- `engine\kernel\world\tiers.gd`: `unbuilt`, events `built` and `reload`, `mark_built`.
- `engine\kernel\world\tiers.json`: `load` and `load_note`.
- `engine\kernel\world\TIERS.md`: the P5 section.
- `engine\kernel\world\PATCHES-P5.md` (new).
- `engine\kernel\world\draw\view.gd`: plots without a pack, rim cache, collider copies for late packs, frame tail, PNG off-thread, pad height.
- `engine\kernel\world\walks\walk30.json`, `queue.json` (new).
- `engine\kits\tl_kit_layout.gd`, `tl_kit.gd`: `build_ahead` / `take_ahead` / `drop_ahead` and the two `TLKit` wrappers. No change to what a part looks like.
- `engine\tools\world.sh`: supervised window, usage text.
- `engine\tools\selftest.sh`: cases `world.reload`, `world.queue`.
- `devx\lib\perf\scenarios.mjs`, `ledger.mjs`: scenario walk30, two metrics.
- `docs\generated\API-INDEX.md`: regenerated by `tl arch --index` (the gate demands it).
- `perf\ledger.jsonl`: line 7, written by `tl perf run`.
- `engine\JOURNAL.md`: section P5.
- `engine\kernel\world\WORLD.md`: edited at 14:04 and put back at 14:26 (not in scope); content unchanged.

## PROPOSED CONTRACT TEXT

- **tl.walk/1:**
  - `events` may hold `{"t": <world tick>, "e": "reload", "plot": "<plot id>"}`: the plot's pack is replaced by a freshly loaded copy of its directory; what `_pack_save` returns is handed to the new copy.
  - `edits`: `[[<world tick>, "<file>", "<replacement file>"]]`, a test instrument.
  - `tiers.load`: `{"mode": "auto" | "queue" | "step" | "wait" | "block", "budget_ms": <number>}`.
- **tl.world/1 and tl.worldlog/1:**
  - Event `{"t": N, "e": "built", "plot": id}`: the pack was attached at this tick boundary; its first tick is N + 1.
  - The log's `tiers.load.mode` is the mode the run used.
  - The world line has `load`: `mode`, `budget_ms`, `built`, `never_built`, `waited_ms`, `in_ticks_ms`, `first_built_ms`, `six_built_ms`, `all_built_ms`, `attach_ms_p50`, `attach_ms_max`, `prepare_ms_p50`, `prepare_ms_max`, and `arrivals` as `[plot, tick, ms since the world started, prepare ms, attach ms, layouts built ahead and not used]`.
  - `load_ms` includes `in_ticks_ms`.
- **tl.view/1, tour line:** `frame_ms_p99_all`, `frame_ms_max_all`, `frames`, `frames_over_16_7_ms`, `slow_frames` ([world tick, ms], at most 40), `first_frame_ms`, `view_ready_ms`, `world_to_first_frame_ms`, `first_two_frames_ms`, `rims_measured`.
- **tl.perf/1:** metrics `first_frame_ms` and `six_built_ms`; scenario `walk30`.
- **Kit:** `TLKit.build_layout_ahead(layout) -> String` and `TLKit.drop_layout_ahead(key) -> bool` belong to the kernel's loader; a pack has no use for them.
- **PACK.md:** the five sentences under "What changed for a pack author" below.

## CONTENTS OF `engine\kernel\world\PATCHES-P5.md`

None of the nine was applied; P5 works without them.

1. **`engine/kernel/host/host.gd`: let the loading options through.** `MODE_OPTIONS` refuses options it does not list. Append `"load"` to the `"world"` list (line 32) and `"load", "trip", "dead"` to the `"world-view"` list (line 37). Until then `tools/world.sh` hands `trip` and `dead` to the window through `TL_WORLD_TRIP` and `TL_WORLD_DEAD`, and `view.gd` reads `TL_WORLD_LOAD`. After the patch those three reads in `view.gd` `start` and the two variables in `world.sh` `window_mode` can go.

2. **`engine/kernel/api/tl_context.gd`: two things a loader needs.**
   - a. `TLContext.current` is one static for the whole process. That keeps the rest of `_pack_setup` (rigs, parts made with `TLKit.build`, bodies, HUD) on the main thread: 17 to 37 ms for a layout seed, 165 to 300 ms for `ex_walker` and `ex_kit`. Proposed: a thread-local lookup, with every read of `TLContext.current` in `kernel/api/**` (30 to 40 places) going through it:
     ```gdscript
     static var _by_thread: Dictionary = {}      # thread id -> TLContext, for threads other than the main one
     static var _lock: Mutex = Mutex.new()
     static func current_of_thread() -> TLContext:
     	if OS.get_thread_caller_id() == OS.get_main_thread_id():
     		return current
     	_lock.lock(); var c: TLContext = _by_thread.get(OS.get_thread_caller_id(), null); _lock.unlock()
     	return c
     ```
     Not enough by itself: a pack built off the tree enters it in tree order, not add order, and `_ready` runs at the attach. Both must be proven not to move any hash. Not attempted.
   - b. `ctx.load_script` keeps the engine's cached script, so a reload sees changed `data/*.json` but not a changed `.gd`. `pack.gd` `_load_script` has the same `load`. Both need `ResourceLoader.CACHE_MODE_IGNORE` when the file's modified time changed, with `_script_cache` keyed by path and time. Not done in `pack.gd` alone, because the entry script would be new and the scripts it loads old.

3. **`landscape.gd`, `terrain/world_space.gd`: packs that arrive after the landscape.** `view.gd` now calls `world_space.add_pack` at a plot's first arrival. Two things remain:
   - `add_pack` after `finish()` adds bodies to a space that was switched inactive. It worked in the tour, but nothing in `world_space.gd` says it may be called late.
   - The landscape of the 30-game village takes 3.8 s to build (terrain 0.85 s, colliders 0.8 s), all before the first frame. It needs the same treatment as the packs.

4. **`draw/draw.gd`: a plot without a pack, and the stand-in.**
   - `set_tier(i, "backdrop" | "ledger")` on a holder with no nodes builds an empty stand-in and keeps it for good. `view.gd` now holds a far tier back until a pack has stood there; `draw.gd` could refuse a holder that is not `loaded`.
   - The stand-in mesh is not cached between runs, so an unbuilt plot shows only its pad. `_build_standin` would write `user://tl_cache/standin_<pack directory hash>.res`. Not built.
   - `_build_standin` runs inside the frame in which a plot first goes far; not measured apart; it belongs on a worker.

5. **`engine/rigs/**`, `tl_biped.gd`: the rig is built on the main thread.** `ex_walker` has no layout; its 165 to 300 ms is the rig. A rig needs `TLRig.build_ahead(params)` like the kit's, or patch 2a.

6. **`engine/kernel/runner/worker.gd`: the contact pass by name.** In a world the holder calls the tracker's pass itself; a pack alone still has it ticked by the scene tree at priority 100. Same order, same hashes. For one written order everywhere, `worker.gd` would do what `pack.gd` `tick()` and `contact_pass()` do.

7. **`docs/PERF.md`: the new scenario and two metrics.** Row:
   ```
   | `walk30` | `world.sh tour walk30 --pictures-only`: a village of 30 games, the visitor runs its road, games are built by the queue as he approaches | world tick p50/p99/max, frame p50/p99/max, time to the first frame, time until six games are built, render cpu/gpu, draw calls, primitives |
   ```
   `first_frame_ms` (in the ledger this is the world's start to the first drawn frame; the engine's own start is not counted) and `six_built_ms` have tolerances 30 % + 300 ms and 50 % + 500 ms. `tour6` now reports `frame_ms_p99` and `worst_frame_ms`, both without the first two frames. The file's own wording of `first_frame_ms` still says "process start"; this line is the correct one.

8. **`devx/arch.baseline.json`.** `world.gd` went from 684 to 672 lines and `pack.gd` stays at 626. Both baselines may be lowered; nothing has to be raised.

9. **`engine/kernel/world/WORLD.md`: pack-author text.** `WORLD.md` is not in P5's scope. For its section "What a pack author must know", add a subsection "Loading (P5)" with the five points below.

## WHAT CHANGED FOR A PACK AUTHOR

- In a world your pack is built by a queue, nearest games first, and may arrive some ticks after the world started. Until then your plot shows its pad.
- You are not ticked before you are there, and your tick count starts at 0 when you arrive. Nothing in a pack may depend on the world's tick.
- The venue you build with `TLKit.build_layout(ctx.read_json(...), ctx.root)` is built ahead on another thread when the layout file lies under `data/` and you pass it on unchanged. A layout you change in code first is built in your `_pack_setup` as before, and costs the visitor a frame.
- Everything else in `_pack_setup` still runs on the main thread: keep it small.
- A world may replace your pack by a fresh copy of its directory at any tick (`reload`). What `_pack_save` returns is handed to `_pack_load`; nothing else survives. Keep no state in `static var`.

Nothing changed in any `TL*` call a pack makes.

## NOT VERIFIED

- **Quiet timing:** none. The only ledger line is BUSY.
- **Windowed proof on the final code:** the tour with its proof ran at 13:54, before the contact pass by name, the step-mode change and the stop/image fixes. After them the window ran the perf scenarios (14:17) and the runaway tour (14:24) without a proof.
- **`world.sh proof ledger`, `leave`, `tickets`:** ledger passed at 13:41 on earlier code; the other two were not run.
- **Thread safety of the style's lazy tables:** the worker and the main thread can both write `TLStyle._mats` / `_flat`. No crash was seen; nothing guards it.
- **Vertical sync:** with a 60 Hz present the worker's prepare would take seconds (see acceptance 1). Not run.
- **Jolt warning:** "Jolt Physics job system exceeded the maximum number of jobs" appeared three times in one walk30 run. Not investigated; I do not know whether it predates P5.
- **`world.sh visit`:** the live path with late packs was never opened.
- **Rim cache:** it lives at `user://tl_cache/rims.json`. A cold cache builds each distinct pack once before the first frame; that was seen once (six rims on the tour, three on walk30).
- **Pictures:** two were looked at (`walk30_a\03_half_way.png`, `tour_b\07_far_and_near.png`); the rest were not.
- **`item.selftest`, `ui.selftest`:** skipped by the gate in a worktree.

## QUESTIONS

1. Is `step` (main thread, arrival ticks fixed by the walk) the right default without a window? The worker's path is then covered only by `world.queue` and by windowed runs.
2. Who takes patch 2a (thread-local `TLContext.current`)? It is the only way the rest of `_pack_setup` leaves the main thread, and it changes the order in which a pack's nodes enter the tree.
3. On `reload` I hand on what `_pack_save` returns. After a tuned value, should the game instead start clean?
4. Asleep packs: telling the tracker from the kernel's wake paths still misses a pack that calls `apply_impulse` itself. Is a one-frame-late contact acceptable for such a pack, or must every body be read?
5. Several builders' windows at 0,1440 throttle each other to about 270 ms a frame. Should windowed perf scenarios get their own position or a lock?
6. The landscape (2.1 s for six games, 6.1 s for thirty) is now the time to the first frame. Whose package is that?

## MINUTES SPENT

Start: Wed Nov 11 13:22:27 CEST 2026. Last `date`: 14:46:40. About 85 minutes of the 110.

---

## Director verification

Done 14:48 to 15:50 on 2026-11-11 in the builder's worktree. The command runs were made by a Sonnet subagent and
read by the Director. Two other verification runs with windows of their own ran at the same time.

### What was re-run, and the result

| Check | Result |
|---|---|
| `bash engine/tools/world.sh tour tour --headless` | PASS: six games, tour = alone = replay, 0 script and 0 engine errors; world tick median 1.44 ms, 99th percentile 3.85 ms |
| the same tour in a window, with its proof, on the final code | PASS: six of six the same in the walk, alone and in the replay. The games arrived at world ticks 339, 637, 653, 654, 664 and 665. Worst frame 372 ms, 99th percentile 11.9 ms, landscape built in 1.6 s |
| `world.sh proof ledger`, `proof leave`, `proof tickets` | PASS, three of three |
| selftest cases `world.reload`, `world.queue`, `world.walk_proof`, `world.tour`, `world.next_round`, `world.same`, `world.sliced_and_paused`, `p1.world_runaway` | PASS, eight of eight |
| the three seeds (`bot`) and the hockey game (`smoke`, `bot`) alone | all five hashes unchanged from before the package |
| `world.sh tour walk30 --pictures-only` (30 games) | ran to its end: 30 games built, 5 of 5 pictures, frame median 2.4 ms, 99th percentile 5.8 ms, worst frame 350 ms, landscape built in 5.8 s; no error, no warning |
| tour, pictures only, old way (`TL_WORLD_LOAD=block`) against the queue, one run each | old: worst frame 925 ms, 99th percentile 550 ms. Queue: worst frame 266 ms, 99th percentile 8.5 ms |
| `node devx/bin/tl.mjs check --tier fast` | PASS |

### What failed in the re-run

The windowed tour in queue mode, pictures only, was run three times. The first ended well (the row above). The second
ended FAIL: the wall game was never built in the run's ticks, with one engine error from the sound device
(`WASAPI: GetBufferSize error`). The third did not end inside 600 seconds and was stopped. At the same minutes the
old way's rerun showed 277 ms a frame at the median (it is 2.4 ms alone) and the far-games verification, which has no
queue, also ran into its 600-second limit on a windowed tour: several windows on the same spot of the screen throttle
each other, as the builder had seen.

The Director's reading, not yet proven: under a throttled window a frame takes a quarter of a second, the worker's
calls that need the main thread wait one frame each, and so a game's preparation takes many seconds: long enough to
miss the end of a tour. If that is right, the queue's speed hangs on the frame rate, which is wrong for a build with
vertical sync, and "a game is not built by the tick something needs it" has no answer in the design yet. Both go to
round 3 (P12) as its first two items, with the 600-second run as the case to reproduce. The headless default (`step`)
does not have the problem: arrival ticks there depend only on the walk.

The tool does not print the first-frame figures the builder quotes (they are in the viewer's own line, which
`world.sh` does not pass on), so the time to the first frame was not re-measured. The landscape's own figure agrees
with the builder: 1.6 s for six games, 5.8 s for thirty.

### What this settles

- The cost of a game arriving left the tick: the tour's time inside ticks went from 1.7 to 1.9 s down to 18 ms, and
  the 99th-percentile frame from 550 ms to under 12 ms. Every proof still holds: a game that arrives late equals
  itself alone.
- The frame target (no frame over 16.7 ms) is NOT met: the worst frame is 270 to 370 ms, one per arriving game.
  The rest of a game's setup still runs on the main thread.
- A game can be replaced inside a running world after a value changed, and equals the changed game alone.
- The landscape is now the time to the first picture.

### What is not verified

Any figure on a quiet machine. The time to the first frame. The cheap asleep games and the warm-up (not built).
A person walking through late arrivals.

### Director's decisions on the builder's questions

1. `step` stays the default without a window: arrival ticks fixed by the walk.
2. The context per thread is round 3's (P12), with the proof that no hash moves.
3. On reload the game keeps what `_pack_save` returns, as built.
4. Asleep games: whatever rule is chosen must leave every existing hash as it is, alone and in a world. P12 decides
   by that measure.
5. Windowed measurements need a lock so that two never overlap: P12 (it owns the perf tool). Until then the Director
   runs windowed checks one at a time.
6. The landscape's cost is round 3's (P13).

The proposed contract texts are accepted in substance; the walk, world and view lines are documented in
`engine/kernel/world/WORLD.md` and `docs/PERF.md` with the round's merge.
