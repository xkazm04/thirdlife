# P10: the Foreman after hockey: honest change requests, answers while it builds

You are a builder on **Third Life**: a single-player sandbox on Godot 4.7.2 (Jolt physics, 60 Hz fixed tick) in which
an LLM builds small games ("packs") over a law kernel, and the games all keep running in one world a visitor walks
through. The owner spends this day and night on **perfecting the core before content spreads it**: every engine change
gets more expensive with each game built. Round 1 landed today: limits that count processor time and a performance
ledger (`docs/PERF.md`, `docs/reports/P1-MEASURE.md`); one contact pass per pack instead of a script per body
(`docs/reports/P2-HOTPATH.md`); a second pass on the look with characters, sky and motion (`docs/reports/P3-LOOK2.md`);
land with relief, plots as terraces and a visitor with a body (`docs/reports/P4-RELIEF.md`). You own one of five
packages of round 2. The night ends with a Windows executable built from the merged result, so leave your part green.

## Why this package exists
The Foreman (`foreman/`, Node and TypeScript) turns a player's sentence into a verified game pack with CLI builder
agents. Last night's real hockey job found what is still wrong in its core loop (`docs/reports/JOB3-HOCKEY.md`,
findings 5 to 12; `docs/reports/N6-DESIGNER.md`, the builder's "what a player still cannot do"). These are core
because every game built from here on goes through them.

## Read first
1. `docs/reports/JOB3-HOCKEY.md` (the two change requests and findings 10 to 12), `docs/reports/N3-FOREMAN.md`,
   `N3B-FOREMAN.md`, `N3C-FOREMAN.md`, `contracts/JOB.md` (the sections added after N3 and N3b).
2. `docs/reports/P1-MEASURE.md` and `docs/PERF.md` sections 1 and 3: since today the engine itself tells a starved
   run from a runaway script and judges the frame budget on each frame's best time; `docs/PATCHES-P1.md` entry 4.
3. The real job as test input (read only):
   `C:\Users\kazda\kiro\third-life\site\ice-hockey-three-against-20261111-1\job.jsonl` (331 events).
4. `engine/ui/foreman_door.gd` and `engine/ui/PATCHES.md`: how the designer panel starts the Foreman and why it must
   wait for a pause before it can answer.

## Scope
`foreman/**` only. Everything else is read only. The engine your tests use: `TL_ENGINE_DIR` = the `engine` directory
of your own worktree (it has `kernel/runner/verbs.json`); `TL_GODOT` as below. **No model calls at all**: the fake
adapter and fixtures only (`foreman probe` spends no tokens and is allowed).

## The work, in this order
1. **A rebuilt dependant is checked against the whole pack.** After a change request the owner package merges, its
   dependants are verified again, and a dependant that fails is rebuilt. Last night that rebuild was checked against
   the dependant's own bot only; the pack's other bot (the owner's) was not run again until the final verification,
   which failed the whole job with the first promotion still in place. Every merge after a change is followed by
   every test of the pack, and a failure names the package whose test failed and the package that just merged.
2. **A failed final verification after a change goes back to a package.** It does not end the job as `failed`
   while rounds are left: the package that owns the failing test, or the one that merged last (decide by evidence and
   say how), is re-opened with the failure as its feedback. Only when the round limit is spent does the change end as
   "not made", the job ends `done` on the earlier promotion, and the event says so.
3. **A change request carries the present value.** "Make the puck bigger" came back with a puck nine times the
   size. When a request names something that has a declared tunable value (`params` in `pack.json`) or an obvious
   figure in `data/*.json`, the owner's prompt includes the current values, so "bigger" has a scale. Do not guess a
   mapping with a model call: include the pack's `params` table and the data files' small scalar values and let the
   builder see them.
4. **An inbox.** `foreman answer` and `foreman change` on a job that another Foreman process is running do not
   refuse: they write the request into the job directory (an inbox file, appended atomically) and the running Foreman
   picks it up at its next safe point (between rounds), logs it as the same event it would have been, and acts on it.
   The designer panel can then answer a builder's question while other packages are still building.
5. **The engine's new verdicts.** Read the runner's `starved` outcome (exit 2, error message beginning `starved:`)
   as "the machine", never as a pack failure; show `metrics.starved_stalls` in the round's detail when it is not zero.
   The Foreman's own different-frame rule and reference gauge stay as a second line of defence; say in your report
   whether any of it is now dead code and propose its removal, do not remove it tonight.
6. **The player's part.** The hockey AI passed its own bot while taking the puck from the player every time; only
   another package's bot caught it. The Planner prompt asks for a bot per game that fails when the human-controlled
   side has nothing to do (for example: the player's actions change the outcome; the player's side touches the ball),
   and the plan check refuses a plan for a game with player input whose tests do not name such a check. Fixtures
   only; say what you could not prove without a model.

## Acceptance (the Director will run these)
- `npx tsc --noEmit` clean; `npm test` passes with the new tests, none skipped without a stated reason.
- A fixture that replays last night's first change request: the dependant's rebuild is checked against both bots,
  the failure is found one step earlier and goes back to a package; the job does not end `failed`.
- A fixture change request on a pack with `params`: the owner's prompt shows the current values.
- Two processes on one job: a running fake-adapter job receives an answer and a change request through the inbox;
  the log shows both exactly once and in order; no lock error.
- A fixture run whose runner reports `starved`: nothing is sent to a builder and the round is not spent.
- A dry prompt file `foreman/dry/p10-prompts-racing.txt` for the sentence "A night street race: three laps against
  two rivals, nitro on a pad, the walls break" with the new Planner text.
- Proposed text for `contracts/JOB.md`.

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
- **You work only in your own git worktree: `C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p10`** (branch `core-p10-foreman`, cut from the merged round 1). Every path in
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
- Small verified steps. Journal each in ``foreman/JOURNAL.md` under a "P10" heading`.
- Contracts (`contracts/**`) are the Director's: write proposed contract text into your report.
- For anything outside your file scope, write the exact patch and its reason to ``foreman/PATCHES-P10.md`` instead of editing.
- **Your measurement outranks this brief.** Where a premise here is wrong, say so with the evidence and build the
  right thing; a fix that makes the measured result worse is withdrawn and documented, not tuned.

## Final message (your report, as text; the Director saves it to a file)
Status; per item what you built and the command, figure or picture that proves it (full paths); the acceptance
checks one by one with their result; the list of files changed with a line each; proposed contract text; the contents
of your patches file; what changed for a pack author; what you did not verify; questions; minutes spent from real
timestamps (`date`).

## Time-box
Until the list is done or **90 minutes after your start** (run `date` first and often). The first items proven
are worth more than all of them half done. Leave the last fifteen minutes for the full gate and the report. A usage
limit can cut you off without warning: keep the journal current, and if you are resumed, re-read this brief and your
journal and continue.
