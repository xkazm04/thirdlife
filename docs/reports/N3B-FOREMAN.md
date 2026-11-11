# N3b Foreman follow-up from the live hockey job: builder report and Director verification

Sent by the Director at 01:57 on 2026-11-11 after the real hockey job exposed two defects. Builder wall time 12 min. No model was called.

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

N3b: FOREMAN FOLLOW-UP REPORT (builder; 2026-11-11, 01:57 to 02:09 CEST)

## Status

Both defects are fixed. `npx tsc --noEmit` exits 0. `npm test`, run once at the end with `TL_GODOT` and `TL_ENGINE_DIR=site/_engine_snapshot3`, gave 161 tests, 161 pass, 0 skipped: the 156 from before plus 5 new ones in `foreman/src/test/n3b.test.ts`. No model was called and no git command was run. The hockey job directory was only read: 0 files changed there, no lock file.

## Defect 1: cause and fix

- **Cause.** A workspace is a copy of the whole `pack/`, but the manifest it was verified with came from the package's dependency closure only.
- **In the hockey job.** `ws/hockey_core` held `scripts/fx/fx.gd` (from `hockey_fx`) while `ws/hockey_core/pack.json` listed only `hockey_core`'s capabilities and no assets. Lint then failed on `TLAudio` and `TLVfx`.
- **Why now.** The hole is older than N3 for a sibling cut after another sibling merged. My N3 refresh of workspaces before each round made a re-opened root hit it every time a dependant with its own capability had merged.
- **Fix.** The workspace manifest is now the dependency closure plus every package whose merged files the workspace holds. The list is written when the workspace is cut or refreshed (`ws/<pkg>.members.json`), so a resume composes the same manifest.
- **Old workspaces.** The paused hockey job has no such file. There the list is derived: every package of which a merged file is present in the workspace.
- **Test.** "N3b 1": a root re-opened after a dependant that registered `audio` has merged. With the fix switched off in `dist/` for one run it fails; with the fix it passes. The fake runner's lint now checks capabilities (marker `FAKE_USES(<cap>)`).
- **`hockey_ai` needs this too.** Its workspace will be refreshed with `fx.gd` on resume and would have failed the same way.

## Defect 2: what I built

The job's own figures decided the design. Under load the median frame does not move and only the tail does:

| | p50 | p99 |
|---|---|---|
| Calm runs | 0.55 to 0.75 ms | 1.0 to 1.25 ms |
| Loaded runs | 0.67 to 0.96 ms | 8 to 33 ms |

- **(a) Watchdog.** `tick_timeout` and the setup phase are one watchdog reason in the engine and were already treated as clock-based. I added `setup_timeout` to the pattern anyway.
- **(b) Measuring the machine.** A clock-based failure is run twice as before. If both fail:
  1. If only the frame budget failed and the median frame alone is over half the budget, it is slow code and goes to the builder.
  2. Otherwise `smoke` runs on the engine's reference pack `kernel/examples/pack_min`. The machine counts as busy when that run trips a time limit, or its frame p99 is 2 ms or more, or its slowest tick is 2 ms or more.
  3. If busy: a note "[foreman] inconclusive: machine busy ...", then wait 20 s, 40 s, 80 s, re-running the check and the gauge each time. If it clears, the round goes on and nothing is spent.
  4. If still busy after 3 tries: the package is `blocked` with the new cause `machine_busy`, the job is `paused` (exit 3), and `resume` verifies the same files again without running the builder.
  5. If not busy: the failure is the pack's. A note "[foreman] not machine load: ..." is written and the next round's prompt says the machine was measured.
- **Deviation from your proposal.** The gauge is `smoke`, not the failing verb, and it reads frame p99 and slowest tick, not only whether the budget broke. `pack_min` is tiny and would rarely break 8 ms itself, so "the reference also breaks its budget" alone would have blamed the hockey pack again.
- **Also changed:**
  - A failed run that a later run of the same check overruled is no longer handed to a builder as feedback.
  - An inconclusive final verification pauses the job; it does not fail it.
  - An inconclusive re-verification of a dependant re-opens nobody.
- **(c) Builder prompt.** New rule "A time limit can fail because the machine is busy": run the self-check once more, do not ask a `QUESTION:` about it, do not blame another package, do not restructure working code.
- **Options, with defaults:**
  - `--clock-retries 3`
  - `--clock-pause-ms 20000` (doubles twice)
  - `--reference-pack <engine>/kernel/examples/pack_min`
  - `--reference-busy-p99-ms 2`
  - `--reference-busy-tick-ms 2`
- **Tests.** Four named "N3b 2: ...". They cover: clears on retry; persists while the reference also fails (blocked, paused, resume without the builder); persists while the reference passes (real failure, builder told); and the median rule on the hockey figures.

## Command lines to continue the hockey job

Run from `C:\Users\kazda\kiro\third-life\foreman` in Git Bash; `dist/` is current. The run flags match what the job's log shows you used (15-minute limit, round 4 of 4, budget 4,000,000, sonnet).

```
export TL_GODOT="C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe"
export TL_ENGINE_DIR="C:/Users/kazda/kiro/third-life/site/_engine_snapshot4"

node dist/cli.js answer ice-hockey-three-against-20261111-1 hockey_ai "The frame-time failure was machine load, not your package and not main.gd or fx: twelve other Godot processes were running. The same workspace pack measured frame p99 1.2 ms a few minutes later, against the 8 ms budget. Change nothing for it: no restructuring, no performance work. Finish the package as your contract says."

node dist/cli.js resume ice-hockey-three-against-20261111-1 --adapter claude-cli --allow-edit --model sonnet --round-limit 4 --timeout-ms 900000 --max-replans 1 --max-packages 4 --parallel 2 --budget tokens_per_hour:4000000
```

- Do not add `--change` to the answer; nothing else needs re-opening.
- If `resume` exits 3 with "machine busy" in the pause reason, run the same `resume` again when the machine is quieter. No builder run is repeated.
- Expect the greybox milestone and its critic after `hockey_ai` merges. If the critic names `hockey_core` again, that round is now verified with the full manifest.
- `hockey_core`'s round 5 was thrown away by defect 1. Its files are still in `ws/hockey_core`. To recover them: `foreman change <job> "<the critic's point>" --package hockey_core`; the builder continues from those files.

## Not verified

- Nothing of N3b has run with a real model or on the real job.
- The machine gauge has never seen the load that broke `hockey_ai`. Its two 2 ms limits come from three real runs of `pack_min` at 02:04 under tonight's ordinary load (p99 0.38, 0.43, 0.81 ms; slowest tick 0.10, 0.10, 4.46 ms) and from the hockey job's figures.
- A sensitive gauge can pause a job as "machine busy" when a pack has periodic spikes of its own on a loaded machine. The Foreman cannot tell those apart; it asks for a `resume`.
- The derived list for old workspaces was not run against the real `ws/` directories, only against fixtures.
- `contracts/JOB.md` is read-only for me: the cause `machine_busy` and the file `ws/<pkg>.members.json` need adding there.

## One slip

I started the full suite and then changed code. I stopped that task and killed its own process tree (pid 96608, `node --test`, with its test children and their Godot capture children on snapshot3, all started by me between 02:03 and 02:05). No other process was touched and nothing of mine is left running.

## Minutes spent

01:57:11 to 02:09:01 CEST by `date`: 12 of the 30 minutes. The record is in `C:\Users\kazda\kiro\third-life\foreman\JOURNAL.md`, section "N3b".

---

## Director verification

Done 02:10 to 02:15 on 2026-11-11, after the builder had stopped, with three other builders running.

| Check | Result |
|---|---|
| `npx tsc --noEmit` in `foreman/` | exit 0 |
| `npm test` with `TL_GODOT` and `TL_ENGINE_DIR=site/_engine_snapshot3` | 161 tests, 161 pass, 0 skipped, 159 s |

Not verified by the Director before use: the fixes on the real job. The hockey job's `resume` at 02:16 is their first
live run, and its outcome is recorded in `docs/reports/JOB3-HOCKEY.md`.

Decisions: the gauge on `smoke` of the reference pack, with the median rule before it, is accepted as built; it is
better than the Director's proposal, which would have blamed the pack again. `contracts/JOB.md` gets the cause
`machine_busy` and the file `ws/<pkg>.members.json`.
