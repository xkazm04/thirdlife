# Patches outside the scope of P1 (the Director applies them or decides)

Each is the exact text and the reason. Nothing here was applied.

## 1. `engine/kernel/world/draw/view.gd`: the tour line carries the frame tail

Reason: the `tour6` scenario of `tl perf` must report `frame_ms_p99` and `worst_frame_ms` (brief, item 5). The viewer
keeps every frame time in `_frame_usec` but writes only the medians into its `"kind": "tour"` line, so the ledger has no
frame tail for the windowed world. `devx/lib/perf/scenarios.mjs` already reads the two new keys when they exist
(`frame_ms_p99_all`, `frame_ms_max_all`) and leaves the metrics out until then.

In `_on_world_ended`, before `var line: Dictionary = {...}` (line 403):

```gdscript
		var sorted_us: Array = Array(_frame_usec)
		sorted_us.sort()
		var p99_us: float = float(sorted_us[clampi(int(ceil(0.99 * float(sorted_us.size()))) - 1, 0, sorted_us.size() - 1)]) if not sorted_us.is_empty() else 0.0
		var max_us: float = float(sorted_us[sorted_us.size() - 1]) if not sorted_us.is_empty() else 0.0
```

and two more keys in the line, after `"frame_ms_p50_all"`:

```gdscript
			"frame_ms_p99_all": snappedf(p99_us / 1000.0, 0.001), "frame_ms_max_all": snappedf(max_us / 1000.0, 0.001),
```

## 2. `engine/tools/world.sh` `window_mode` and `engine/kernel/world/draw/view.gd`: a runaway pack in a WINDOWED world

Reason: the world host now has a guard (`kernel/host/guard.gd`, processor time, 250 ms per pack tick) and, for the
headless `world` mode, a supervisor in `host.gd` that runs the world again without the pack that ran away. The windowed
modes (`world-view`: `tour`, `visit`, `view.sh`) are NOT supervised: the guard ends the process (the window closes) and
writes `--trip=<file>` if that option is given; without it, it prints a `kind: event, e: runaway` line. Nothing hangs any
more, but the visitor's world does not continue in the same window.

A GDScript loop cannot be interrupted from outside its thread, so staying in the same process is not possible; the
options are (a) restart: `window_mode` in `world.sh` passes `--trip=$tmp/$tag.trip.json`, and when the window died and the
file exists, starts the window again with `--dead=<pack index>` (the same option the headless supervisor uses; the world
is rebuilt from its seeds, the visitor starts again at the beginning of the walk), (b) run the packs of a visitor world
in their own process (a much larger change). (a) is about fifteen lines of shell; I did not write it because
`engine/tools/world.sh` is not in my scope and (a) restarts the picture, which is a product decision.

## 3. `engine/kernel/runner/lint.gd`: refuse the obvious endless loop at lint time (optional)

Reason: a loop that never ends can only be stopped by killing a process (worker) or by restarting the world (world host).
Neither is cheap in a world with a visitor. A fence rule would catch the plain case before the game is ever played:
a `while true:` (or `while 1:`) whose body contains no `break` and no `return`. It cannot catch every loop; it only
makes the usual mistake a lint error with file and line instead of a stopped process. Not built: `lint.gd` is not in my
scope and the rule needs the Director's decision on what the fence may refuse.

## 4. `foreman/src` (verifier): what the Foreman does with the two new outcomes

Reason (information, no code): the runner now ends a run the machine starved for 90 s of wall time with processor time
under the limit as `exit 2`, outcome `not_run`, one error `{"kind": "engine", "message": "starved: ..."}` (after two
automatic re-runs by the runner itself). The Foreman must read that as "the machine's, no verdict on the pack", like its
own `machine_busy`: `stallOf()` returns `undefined` for it today (it looks for `outcome: watchdog`), so a `not_run`
with the engine error would be treated as an engine failure. In practice the case needs three consecutive runs that
each got nothing from the processor for 90 s. The `tick_timeout` reason now always means a runaway script (it used
its limit in processor time), so `classifyStalls()`'s "same frame twice = the pack" rule is now exact instead of a
heuristic, and its "different frames = the machine" branch can no longer be produced by the runner at all: those
stalls are not stops any more. Both messages keep their old shape (`tick_timeout: <callback> did not return within N ms
... (frame F)`), so the Foreman's regular expressions still read them.

## 5. `engine/kernel/world/bench.gd`: the bench's "V3 budget" constant

Reason: `BUDGET_VERIFY_MS: float = 8.0  # the V3 frame budget of one pack (host.gd BUDGET_FRAME_MS_P99)` and the column "inside the
8 ms V3 budget" of `BENCH.md` (and `bench.json`) now name a number the runner no longer uses: the stage budget is 4 ms and
the budget of one of many is 1 ms p50 (`kernel/host/invariants.gd`, `BUDGET_FRAME_MS_P99`, `BUDGET_MANY_MS_P50`). Change the
constant to `4.0` and the next `world.sh bench` writes the tables against the budget `invariants` actually enforces. Not applied:
`bench.gd` is not in my scope and the figures in `BENCH.md` are the previous run's.

## 6. `devx/arch.baseline.json` and `engine/kernel/world/world.gd` (information for the merge)

`world.gd` grew by 9 lines (the guard hooks: `_guard`, `_dead`, the two `_guard.call("tick", ...)` sites, one `stop` in the refused path,
one `tripped` key in a result line); the baseline was raised from 675 to 684 in this worktree. Another builder edits the visitor part of
the same file today: at merge the figure must be set again from the merged file (`node devx/bin/tl.mjs arch --update-baseline`
shows it). `host.gd` and `worker.gd` were brought down to 610 each (baseline 633 and 611) by moving code into new files
(`kernel/host/invariants.gd`, `world_supervisor.gd`, `statehash.gd`, `cpuclock.gd`, `guard.gd`).
