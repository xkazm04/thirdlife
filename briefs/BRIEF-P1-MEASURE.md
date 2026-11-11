# P1: honest measurement

You are a builder on **Third Life**: a single-player sandbox on Godot 4.7.2 (Jolt physics, 60 Hz fixed tick) in which
an LLM builds small games ("packs") over a law kernel, and the games all keep running in one world a visitor walks
through. Last night the kernel learned to hold many packs in one process, each in its own physics space and on its own
clock; a scheduler gives each pack ticks by tier (stage, sideline, backdrop, ledger); a drawing layer shows every pack
at its plot; a village landscape and a walking visitor exist; a real job built a hockey game from one sentence. The
owner now spends a day and a night on **perfecting the core before content spreads it**: every engine change gets more
expensive with each game built. You own one of four packages of round 1.

## Why this package exists
Every limit in the engine counts wall time. Last night, with ten to twelve engine processes on this machine, healthy
code failed the 250 ms watchdog and the 8 ms frame budget again and again: the hockey job lost about an hour, two
builder questions and four builder rounds to it (`docs/reports/JOB3-HOCKEY.md`, findings 5 and 6;
`docs/reports/N3B-FOREMAN.md`, `N3C-FOREMAN.md`). The other packages of this run promise numbers ("an active game at
a third of the cost", "no frame over 16.7 ms"); none of that can be proven or kept without a measurement that holds
on a busy machine and a record of it per commit.

## Read first
1. `docs/reports/JOB3-HOCKEY.md` (findings 5, 6), `docs/reports/N3C-FOREMAN.md` (the different-frame rule and its
   live result), `docs/reports/N2-MANY.md` ("What this settles": the 8 ms budget is from a world of one).
2. `engine/kernel/runner/worker.gd` (the watchdog, the frame statistics), `engine/kernel/host/host.gd` (budgets, how
   a worker is spawned and supervised), `engine/kernel/world/world.gd` (no watchdog at all), `contracts/RUNNER.md`.
3. `devx/` : how a command (`devx/lib/commands/*.mjs`) and a gate step (`devx/lib/gate/steps/*.mjs`) are added; both
   are discovered by file name. `engine/kernel/world/BENCH.md` and `TIERS.md` for the figures that exist.
4. The nine real stalled reports: `C:\Users\kazda\kiro\third-life\site\ice-hockey-three-against-20261111-1\reports\hockey_ai-r2-bot-s142.json`,
   `...-again-s143.json`, `hockey_ai-r3-invariants-s153.json`, `...-again-s154.json`, `hockey_ai-r4-bot-s169.json`,
   `...-again-s170.json`, `...-retry1-s172.json`, `...-retry2-s174.json`, `...-retry3-s176.json` (read only).

## Scope
Yours: `engine/kernel/runner/worker.gd`, `engine/kernel/runner/logger.gd`, `engine/kernel/host/**`,
`engine/kernel/runner/verbs.json`, the watchdog part of `engine/kernel/world/world.gd` (another builder changes the
visitor part of that file today: keep your edit small and in one place), `engine/tools/selftest.sh` (new cases only),
`devx/**`, new `perf/**`, `docs/PERF.md`. Not yours: `engine/kernel/api/**` (another builder rewrites the physics hot
path there today), `engine/style/**`, `engine/rigs/**`, `engine/kits/**`, the rest of `engine/kernel/world/**`,
`foreman/**`, `contracts/**`.

## The work, in this order
1. **Reproduce the lie.** A small load generator of your own (processor-bound processes, started and stopped by your
   script) under which `bot` and `invariants` on a healthy pack fail today as they did last night. Use a seed and the
   hockey pack at `C:\Users\kazda\kiro\third-life\site\ice-hockey-three-against-20261111-1\promoted\game.ice_hockey_three_against@0.1.1`.
2. **Limits that hold.** Godot gives a script no process-time clock, so "count processor time" is the aim and you
   choose the mechanism by measurement. Candidates: judge the frame budget on a statistic that does not move under
   load (last night the median stayed at 0.7 ms while the 99th percentile went from 1.2 to 33 ms); let the supervisor
   (`host.gd`), which already watches the worker from outside, ask the operating system for the worker's processor time
   when a stall is suspected, so that a starved process (no processor time used during the stall) is told from a
   runaway script (processor time used equals the stall); work counted in frames. A stall the machine caused is
   reported as `reason: starved`, is never the pack's failure, and the check is run again by the runner itself. A real
   endless loop in a pack is still stopped within about a quarter of a second of its own processor time.
3. **Budgets for a world of many.** The 8 ms per pack budget lets one game eat half a frame. Propose and implement
   budgets from data: what a pack may cost as a stage game and what it may cost as one of many, measured on the
   seeds, the examples and the hockey pack, with the figure each has today. A pack that passes today and would fail
   the new budget is listed, not silently failed.
4. **A watchdog for the world host.** Today a runaway `_pack_tick` hangs the whole world. The world must survive it:
   the pack is stopped and marked, the others go on, the event is in the world log.
5. **The ledger.** `node devx/bin/tl.mjs perf run [--scenario <id>] [--quiet-only]`, `perf compare <a> <b>`,
   `perf trend`. Scenarios, each a fixed, scripted, headless-or-windowed run with a fixed seed: `tour6` (the world
   tour: `engine/tools/world.sh tour tour`), `mix30` (one stage, four sideline, the rest far:
   `engine/kernel/world/walks/bench_mix_30.json`), `pile600` (one pack with 600 awake bodies:
   `engine/tools/world.sh run --packs=w_pile --seeds=600 --frames=400`), `hero1440` (the kit lab hero at 2560x1440:
   `engine/tools/k.sh stats`), `load6` (time to load six packs and the landscape). One line per run appended to
   `perf/ledger.jsonl`, schema `tl.perf/1`:
   `{schema, ts, commit, machine, quiet, scenarios: {<id>: {sim_tick_ms_p50, sim_tick_ms_p99, worst_tick_ms,
   frame_ms_p50, frame_ms_p99, worst_frame_ms, gpu_ms, render_cpu_ms, draw_calls, primitives, load_ms, bodies_awake}}}`.
   A metric a scenario does not measure is left out. `quiet` is measured, not assumed (say how). A run on a busy
   machine is recorded as such and never used as a baseline.
6. **The gate.** A gate step `perf` in the full tier: it compares against the last quiet baseline in the ledger and
   fails on a regression beyond a stated tolerance per metric; on a busy machine it says so and passes without
   judging. Also add the two selftests that exist and are not gate steps yet (`engine/tools/item.sh selftest`,
   `engine/tools/ui.sh selftest`) as full-tier steps.
7. If time remains: the full gate takes about 12 minutes serially; say where the time goes and what could run in
   parallel without making results untrustworthy.

## Acceptance (the Director will run these)
- Under your load generator, `bot` and `invariants` on `seed_drive` and on the hockey pack pass, five runs each; the
  same commands on the main checkout's engine fail at least once in five (the proof that the lie existed).
- A pack with a real endless loop is stopped and reported as the pack's failure, under load and without.
- The nine stalled reports of the hockey job, fed to whatever classifies a stall now, come out as the machine's.
- `tl perf run` twice on a quiet machine: every metric within your stated tolerance; the ledger has both lines; the
  first baseline is in the worktree. `tl perf compare` prints a table a person can read.
- A world with one runaway pack and three healthy ones runs to the end; the healthy packs' hashes equal their solo
  hashes.
- `node devx/bin/tl.mjs check --tier full` green in your worktree, with the new steps.
- Proposed text for `contracts/RUNNER.md` (limits, reasons, budgets) in your report.

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
- **You work only in your own git worktree: `C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p1`** (branch `core-p1-measure`, cut from `main` this morning). Every path in
  this brief is relative to it unless it is written in full. Never edit anything under the main checkout
  `C:\Users\kazda\kiro\third-life` outside your worktree; you may read there (`site/` holds the real jobs' packs
  and is not in your worktree).
- **No git command of any kind.** The Director stages and commits your files. The `tl` tool may call git for you;
  that is fine. Do not run git yourself, and make sure no test of yours runs git against anything but a temporary
  repository with `GIT_DIR` unset.
- Godot: `export TL_GODOT="C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe"`. Your
  worktree has no `.godot` cache yet: the first engine run builds it.
- Gates: `node devx/bin/tl.mjs check --tier fast --changed` while you work; `node devx/bin/tl.mjs check --tier full`
  once at the end. Three other builders and other sessions run Godot on this machine today: a failure that is only a
  time limit is re-run alone before you believe it, and you say which figures were taken under load.
- Kill every process you start; never kill others; never leave a window behind (windows go to `--position 0,1440`;
  an orphan window there slowed every later capture for 43 minutes last night). No network. No model calls. Never
  read, use or print any `ANTHROPIC_KEY_*` variable.
- Small verified steps. Journal each in ``devx/JOURNAL-P1.md``.
- Contracts (`contracts/**`) are the Director's: write proposed contract text into your report, do not edit them.
- For anything outside your file scope, write the exact patch and its reason to ``docs/PATCHES-P1.md`` instead of editing.
- **Your measurement outranks this brief.** Where a premise here is wrong, say so with the evidence and build the
  right thing; do not guess and do not tune a fix that makes the measured result worse: withdraw it and say so.

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
