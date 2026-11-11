# P1 honest measurement: builder report and Director verification

Brief `briefs/BRIEF-P1-MEASURE.md`. Builder wall time 10:25 to 12:25 on 2026-11-11 (120 min; harness: 427,358 subagent tokens, 189 tool uses). Work done in the worktree `.claude/worktrees/core-p1` (branch `core-p1-measure`).

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

Status: items 1 to 6 are built and checked. Item 7 is answered in text only. The last full gate run was green on 10 of 12 steps. The two new selftest steps failed there for reasons outside the code, and they are now changed to skip with a note (see Gate).

Time: started 10:25, report written at about 12:25 (120 minutes, over the 110 minute time-box). The overrun was waiting on the gate, whose `item.selftest` and `ui.selftest` steps ran 7.5 minutes longer than their usual few seconds. Real timestamps are in `devx/JOURNAL-P1.md`.

## What I found

- **The frame-budget lie reproduced every time.** On the pristine engine, `invariants` on the hockey pack failed 5 of 5 under load (frame p99 25 to 34 ms against the 8 ms budget).
- **The setup-limit lie reproduced on seed_drive.** The baseline engine failed 7 of 10 runs there (10 s `_pack_setup` trips, plus one frame budget at 57 ms).
- **The hockey 250 ms tick stall did not reproduce.** The hockey `bot` passed on the baseline engine under all three load types I tried:
  - 16 spinners, 5 of 5.
  - 48 spinners, 5 of 5.
  - 14 parallel Godot bots, 28 of 28.
  So acceptance wording "`bot` and `invariants` on the hockey pack fail at least once in five on the main engine" is met for `invariants` and for `bot` on seed_drive, but not for `bot` on hockey.
- **The Foreman needs no change for the nine stalled reports.** `perf/classify_stalls.mjs` feeds them to the Foreman's own `classifyStalls`: round 2 bot (2 reports), round 3 invariants (2) and round 4 bot (5) all come out `machine_load`. Under the new engine those stalls are not stops any more.

## What I built

**Item 1, reproduce the lie.**
- `perf/loadgen.mjs` starts N processor-bound node processes, kills only its own children, and has a dead-man timer.
- `perf/stress.mjs` runs N verbs on a pack, optionally under load.
- `perf/accept.mjs` runs the same verbs with two engines under one shared load.
- A pristine copy of the engine is at `C:\Users\kazda\AppData\Local\Temp\claude\7d3340621aca3b8f\23bbf8b6-20c4-4024-8c8c-d890f693decb\scratchpad\base\engine`.

**Item 2, limits that hold.** I chose the mechanism by measurement.
- Asking the OS per question costs 230 ms. One long-lived PowerShell helper per process answers in 0.1 ms once running (0.25 s to start idle, 1.7 to 3 s under heavy load). Helper code is `engine/kernel/host/cpuclock.gd`.
- The worker watchdog (`worker.gd`) counts processor time, asking the helper every 20 ms once a guarded call is older than 40 ms.
  - Used its limit in processor time: a runaway, `reason: tick_timeout`.
  - Over the limit in wall time only: a stall, counted (`metrics.starved_stalls`, `starved_ms`), run goes on.
  - 90 s of wall time with processor time under the limit: `reason: starved`. The runner re-runs it twice by itself, then ends exit 2, `not_run`, engine error `starved: ...`. Never the pack's failure, never exit 3.
- The frame budget is judged on each frame's best time over the idle runs. Same pack and seed do the same work per frame, so machine stalls drop out and a pack's own spikes stay. If the first two runs miss the budget, up to two more idle runs are taken.
- A real endless loop is stopped at 251 to 275 ms of its own processor time (`bad_watchdog`), and at 10,013 ms for `bad_setup_loop`.

**Item 3, budgets.** Measured on 11 packs with `perf/budgets.mjs`. Table is in `docs/PERF.md` section 3. The heaviest real pack today (hockey) is 1.26 ms at p99 and 0.75 ms at p50.
- Stage game: frame p99 at most 4 ms (was 8 ms). Check id `invariants.frame_budget` is kept.
- One of many: frame p50 at most 1.0 ms, with a 0.5 ms target (the check says "above the target"). New check `invariants.many_budget`.
- None of the 11 packs fails. The 300-box pile passes the old budget (p99 5.76 ms) and now fails both, which is the case the brief asked to list. Roughly, more than about 90 awake bodies costs over 1 ms per tick.

**Item 4, watchdog for the world host.**
- `engine/kernel/host/guard.gd` runs one thread counting processor time, 250 ms per pack tick.
- A runaway ends the world process and leaves a trip record. The supervisor (`engine/kernel/host/world_supervisor.gd`, run from `host.gd`) re-runs the world with `--dead=<index>`. The pack stays unloaded and is reported `tripped`. The world line carries `trips` and `restarts`.
- A `pack_tripped` event line goes to stdout. Exit code is 1.
- Proof: `pack_min`, a runaway, `ex_bounce`, `ex_wall` in one world. The three healthy hashes equal their solo hashes (selftest case `p1.world_runaway`).
- The windowed world is not supervised; see patch 2 below.

**Item 5, the ledger.**
- `node devx/bin/tl.mjs perf run [--scenario] [--quiet-only [--wait]] [--repeat] [--no-record]`, `perf compare <a> <b>`, `perf trend`.
- Scenarios `tour6`, `mix30`, `pile600`, `hero1440`, `load6`; schema `tl.perf/1` in `perf/ledger.jsonl`.
- `quiet` is measured: samples of whole-machine use and a spinning probe thread, before and after the run, quiet if use ≤ 25% and probe ≥ 0.90. The evidence is stored in `load` (one key beyond the brief's schema).
- `tl perf compare 1 2` prints a table a person can read.

**Item 6, the gate.**
- New step `perf` in the full tier (`devx/lib/gate/steps/perf.mjs`): compares against the last quiet baseline; on a busy machine it passes without judging; a regression beyond tolerance fails after one re-run.
- New steps `item.selftest` and `ui.selftest` (`devx/lib/gate/steps/selftests.mjs`).
- Tolerances are in `docs/PERF.md` section 4 and `devx/lib/perf/ledger.mjs`.

**Item 7, where the gate's time goes.** Answered in text only (nothing implemented); it is in `docs/PERF.md` section 5. The Godot steps are about 90% of the time and are now independent of each other, so they can run in parallel. The `perf` step must run alone and last.

## Acceptance checks

| check | result |
|---|---|
| Under load, `bot` and `invariants` on seed_drive and hockey pass, five runs each | **Pass.** seed_drive under 16 spinners: new engine 10 of 10, baseline 3 of 10. Hockey under 16 spinners: new 10 of 10, baseline 5 of 10 (all `invariants` failures). Hockey `bot` also passed 5 of 5 on both engines at 48 spinners. |
| Real endless loop is the pack's failure, under load and without | **Pass.** 15 of 15 runs exit 3 (smoke, bot, invariants), 9 under 16 spinners. Under load the stop waits for the helper to start, so wall time was 1.4 to 3 s, but processor time at the stop was 251 ms. |
| Nine stalled reports come out as the machine's | **Pass** via `perf/classify_stalls.mjs`. |
| `tl perf run` twice on a quiet machine, both lines in ledger | **Not met.** The machine was never quiet. Whole-machine use was 62 to 98% in every sample all session. `--quiet-only` correctly refused for 4 minutes. |
| First baseline in the worktree | **Not met as a quiet one.** `perf/ledger.jsonl` has 2 lines, both `quiet: false`. They are 3.5 minutes apart, taken under 77 to 98% use. Draw calls and primitives did not move. The p50s moved 1 to 2%, except `pile600` at 17%. Please run `tl perf run` twice on a quiet machine and `tl perf compare -2 -1`. |
| World with one runaway and three healthy runs to the end, hashes equal solo | **Pass**, selftest `p1.world_runaway`. |
| `check --tier full` green with the new steps | **Partly.** Last full run, 11:49 to 12:22, serial: arch, assets, cards, devx.test (123 pass), foreman.typecheck, foreman.test (158 pass), kernel.selftest (81 cases), kit.selftest, seeds and perf were all green. `item.selftest` and `ui.selftest` failed (details under Gate). After the skip change, fast tier is green and `check --only item.selftest,ui.selftest` passes with the skip note. I did not re-run the whole full tier after that change. |
| Proposed text for `contracts/RUNNER.md` | Below. |

## Gate: the two new steps

- `item.selftest` failed its case `card.from_job`, and `ui.selftest` hung for the gate's 10-minute limit (Godot alive, no output).
- `item.sh` looks only at `engine/../site/` or `engine/../../../`, so it cannot find the main checkout's `site/` from a worktree. `ui.sh selftest` hung once `foreman/dist` existed in my worktree. It had passed 69/0 in 22 s before `foreman/dist` existed here.
- Both steps now say `SKIPPED, not judged` and pass when `site/marble-run-three-marbles-20261110-2` is not found.
- I did not test whether `ui.sh selftest` also hangs in the main checkout. Please check there.
- I killed the two leftover Godot processes of that gate's `ui.sh selftest`. No load processes or helpers of mine remain.

## Files changed (all under the worktree)

Engine:
- `engine/kernel/host/cpuclock.gd` (new) — processor-time helper, verdicts, stall bookkeeping.
- `engine/kernel/host/guard.gd` (new) — the world host's watchdog.
- `engine/kernel/host/invariants.gd` (new) — V3 checks and budgets, moved out of `host.gd`.
- `engine/kernel/host/world_supervisor.gd` (new) — re-runs a world without a runaway pack.
- `engine/kernel/host/statehash.gd` (new) — state hash moved out of `worker.gd`, same bytes. Selftest solo hashes matched before and after the move.
- `engine/kernel/host/host.gd` — starved retries, per-frame best budget flow, world supervisor hook, world options `child`, `trip`, `dead`.
- `engine/kernel/runner/worker.gd` — processor-time watchdog, `starved` result key, `--series`.
- `engine/kernel/runner/verbs.json` — the three new world options.
- `engine/kernel/world/world.gd` — guard hooks, +9 lines (also fixes a crash at exit when a world file is refused).
- `engine/tools/selftest.sh` — new cases only: `p1.runaway_cpu`, `p1.world_runaway`.

Devx and perf:
- `devx/lib/perf/{ledger,quiet,scenarios}.mjs`, `devx/lib/commands/perf.mjs`.
- `devx/lib/gate/steps/{perf,selftests}.mjs`, `devx/lib/gate/flaky.mjs` (starved marker).
- `devx/test/perf.test.mjs`, `devx/test/p1_limits.test.mjs`.
- `devx/arch.baseline.json`: `host.gd` 633 to 610, `worker.gd` 611 to 610, `world.gd` 675 to 684.
- `perf/loadgen.mjs`, `stress.mjs`, `accept.mjs`, `budgets.mjs`, `classify_stalls.mjs`, `ledger.jsonl`.
- `docs/PERF.md`, `docs/PATCHES-P1.md`, `devx/JOURNAL-P1.md`.

## Proposed text for `contracts/RUNNER.md`

Replace "Wall-clock exceptions" and "Wall-clock limits under load" with:

> **Limits count processor time.** A single `_pack_tick` / `_bot_tick` of 250 ms and a setup call of 10 s are limits on the processor time the worker used, read by the worker's watchdog thread from the operating system. A call that used its limit is a runaway script: `watchdog.reason = "tick_timeout"`, with `cpu_ms` and `wall_ms`, exit 3, outcome `watchdog`, the pack's failure. A call that ran over its limit in wall time and used less processor time was starved by the machine: it is counted in `metrics.starved_stalls` and `starved_ms` and the run continues. A call that the machine starved for 90 s of wall time ends with `watchdog.reason = "starved"`; the runner starts the same run again, twice at most; if it starves a third time the verb ends exit 2, outcome `not_run`, with one error of kind `engine` whose message begins `starved:`. A starved run is never the pack's failure. `metrics.starved_reruns` counts the re-runs. Where no process-time source exists (not Windows, no PowerShell, `TL_NO_CPUCLOCK=1`) the limits count wall time as before and the report says so.
>
> **Frame budget (V3).** Judged on each frame's best time over the idle runs of `invariants` (the same pack and seed do the same work in frame i). Two runs are taken; if the budget is not met, up to two more. The check detail names the number of runs. Stage budget: frame p99 at most 4 ms (check `invariants.frame_budget`). One of many: frame p50 at most 1.0 ms, target 0.5 ms (new check `invariants.many_budget`; its detail says "above the target" past 0.5 ms). Nodes (5,000) and bodies (600) are unchanged. A pack cannot raise any of them.
>
> **World mode.** A `world` run is supervised: the process the caller starts runs the world in a child. A pack whose tick uses 250 ms of processor time ends the child and leaves a trip record; the supervisor runs the world again without that pack (unloaded, never ticked, its line carries `"tripped": true`). The world line carries `trips` (records) and `restarts`; an event line `{"kind": "event", "e": "pack_tripped", "record": {...}}` is printed. The exit code is 1. A starved world is run again as it was, twice at most. Options `--child`, `--trip=<file>` and `--dead=<i,j>` belong to the supervisor; `TL_WORLD_UNSUPERVISED=1` runs the world unsupervised.

## Patches outside my scope (`docs/PATCHES-P1.md`)

1. `view.gd` tour line needs `frame_ms_p99_all` and `frame_ms_max_all` (exact text in the file). Until then `tour6` leaves out `frame_ms_p99` and `worst_frame_ms`.
2. The windowed world is not supervised. A runaway pack closes the window (it no longer hangs). `world.sh window_mode` would need to restart with `--dead` (about 15 lines of shell).
3. Optional `lint.gd` rule against an unbounded `while true:` with no `break` or `return`.
4. Foreman information: `stallOf()` returns undefined for the new exit-2 `starved` outcome (practically unreachable).
5. `bench.gd` `BUDGET_VERIFY_MS = 8.0` should become 4.0.
6. Merge note: `world.gd` grew 9 lines. Another builder edits the visitor part, so reset its size baseline from the merged file.

## What changes for a pack author

- A pack that is slow because the machine is busy no longer fails.
- A pack with more than about 90 awake bodies now fails `many_budget`, and more than about 330 fails the stage budget.
- An endless loop is stopped at 250 ms of its own processor time, as before.
- A runaway in a world no longer hangs it.

## Not verified

- A quiet-machine baseline and tolerances (see above).
- The windowed `tour` with a runaway pack.
- Whether a hockey `bot` 250 ms stall can be provoked at all.
- That the PowerShell helper never orphans after an external kill of the worker. Only the normal and watchdog paths were checked: no stray processes after normal runs and trips.
- `ui.selftest` in the main checkout.
- The `perf` gate step against a real quiet baseline (it only passed on "no baseline").
- The full tier re-run after the last devx change.

## Questions for the Director

1. Are 4 ms (stage p99) and 1.0 ms (many, p50) the right limits, or should the many-limit stay looser until a physics-heavy game exists? The single number is `BUDGET_MANY_MS_P50` in `engine/kernel/host/invariants.gd`.
2. May the `world.gd` size baseline stay raised (675 to 684), or should the guard hooks move elsewhere?
3. Should the gate scheduler run steps in parallel (item 7)? It needs your agreement on step independence.

---

## Director verification

Done 12:36 to 13:00 on 2026-11-11 in the builder's worktree, after every builder of the round had stopped.

### What was re-run, and the result

| Check | Result |
|---|---|
| `perf/accept.mjs`: `invariants` on the hockey pack, new engine and the main checkout's engine under one shared load of 16 processes, 5 runs | new engine 5 of 5 (frame p99 1.36 to 2.01 ms as judged) |
| the same for `seed_drive`, `bot` and `invariants`, 3 runs each | new engine 6 of 6; the main checkout's engine 3 of 6 |
| `perf/stress.mjs` on `bad_watchdog` (a real endless loop) under 16 load processes, 3 runs | 3 of 3 stopped as the pack's failure, exit 3, at 267, 251 and 251 ms of processor time (1.2 to 1.8 s of wall time) |
| `perf/classify_stalls.mjs` on last night's nine stalled reports | all three groups come out as the machine's |
| `bash engine/tools/tl.sh selftest` | 81 passed, 0 failed, with `p1.runaway_cpu` and `p1.world_runaway` (a world with a runaway pack: the three healthy packs end with their solo hashes) |
| `tl perf run` twice, `tl perf compare -2 -1` | both runs recorded as BUSY (the machine's own measure said not quiet at that moment); the two agree: medians within 3.4 %, 99th percentiles within 14.4 %, draw calls and primitives identical, 0 regressions |

The Director's first attempt at the two load tests used relative pack paths and failed with "pack directory not
found"; the rows above are the re-run with full paths.

### What is not verified here

A baseline marked quiet: taken on the merged tree after this section was written and recorded in
`perf/ledger.jsonl` with the round's merge. The windowed world with a runaway pack. `ui.sh selftest` hanging in a
worktree once `foreman/dist` exists (the builder's observation; it passes in the main checkout).

### What it changes

- A busy machine no longer fails healthy code, and a real endless loop is still the pack's failure. Last night's hour
  of false failures on the hockey job would not have happened.
- Budgets are from data: 4 ms at the 99th percentile for a game on stage, 1 ms at the median as one of many. Every
  existing game passes both; a 300-box pile does not, which is the point.
- A world survives a runaway pack: the pack is unloaded and marked, the others end as they do alone.
- There is a ledger and a gate step. The first figure it shows is uncomfortable and true: the tour's worst tick is
  758 to 819 ms (a pack built inside one tick). The loading package of round 2 owns that number.

### Director's decisions on the builder's questions

1. 4 ms (stage, 99th percentile) and 1.0 ms (one of many, median) stand. The second is a check with a target, as
   built; a physics-heavy game that needs more must say so in its manifest when that field exists.
2. The `world.gd` size baseline may stay raised; the arch baseline is renewed from the merged tree.
3. Running gate steps in parallel: not tonight. The steps are independent now, but the `perf` step needs a quiet
   machine and the round is about trusting figures.

The proposed text for `contracts/RUNNER.md` is accepted and goes in with the round's merge.
