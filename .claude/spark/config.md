---
product: "Third Life"
stack: "Godot 4.7.2 (GDScript) engine + Node 24/TypeScript Foreman + Node ESM devx tool; Windows 11 + Git Bash"
vault: ["C:/Users/kazda/kiro/third-life/.spark"]
vault_subdir: Spark
context_map: context-map.json
base_branch: main
active_runs_ledger: ".claude/sessions.json"
locale_count: 1
---

## Gates
- always: `node devx/bin/tl.mjs check --tier fast`
- when engine/kernel, kits, rigs, style or seeds changed: `node devx/bin/tl.mjs check --tier full`
- builder: `node devx/bin/tl.mjs check --tier fast --changed`
- before a merge to `main`, on the merged tree: the full gate, `bash engine/tools/world.sh tour tour --headless`,
  the same tour in a window, `bash engine/tools/world.sh alone --packs=<the exe's games> --mode=bot --frames=20000`
  (a game in the world hashes as it does alone), `bash engine/tools/export.sh --commit <sha>` and
  `bash engine/tools/export.sh check`. In the main checkout only: `node devx/bin/tl.mjs check --tier full --only
  item.selftest,ui.selftest` (they need last night's job under `site/` and are skipped in a worktree).
- a performance figure counts only from `node devx/bin/tl.mjs perf run --quiet-only --wait <s>`; a figure taken
  while builders run is labelled busy and decides nothing.

## Rituals
- Phase 0: read `.claude/sessions.json`; add an entry for this spark's scope. Phase 6: remove it.
- Phase 5: after every package, `tl arch --index` if engine API changed (docs/generated/API-INDEX.md).

## Repo law
Read CLAUDE.md "Laws that bite" and paste it verbatim into every builder brief. Walls: contracts/* are Director-only;
other sessions' uncommitted files are never touched; worktree for multi-file work; stage per file.
Builders run no git command of any kind (the Director stages and commits); a test may run git only against a temporary
repository with `GIT_DIR` unset. Scripts and briefs with quoted passages are written to a file with the Write tool and
run from there, never as a bash heredoc (the trap was hit three times on 2026-11-11).
Dispatch by tier (owner's rule, 2026-11-11): development packages to `model: "opus"` builders, re-runs of checks to
`model: "sonnet"` verifiers given a fixed, numbered command list with expected values and the instruction to report
what was printed; the Director writes briefs, reads results, looks at the pictures and decides. A verifier is told:
one step at a time, one repeat on failure, never explain a failure away.
Parallel builders get disjoint FILES, named in each brief with who owns the neighbours; what sits between them goes
to a patches file, and a last single-builder package owns the seam (P14 of the core run closed what three parallel
builders each had to leave). Every builder appends its selftest cases as a closed block (`if ...; then ... fi`),
never relying on a `fi` that follows the file's last case: three merges of `engine/tools/selftest.sh` needed a hand
fix for that.
The kernel API is versioned (`tl arch` rule `api-v1`): a builder that adds a public member says so; the Director
settles the version on the merged tree. `tl.sh` takes the pack as `--pack=<dir>`.

## Wave defaults
One AskUserQuestion call of up to 4 questions.

## Question taste
- Operator wants tooling-scope questions asked as multi-select pillars, and answers extra wishes via "Other" (devx spark 2026-11-11 added a doctrine: player-facing content tooling ideas).
- Isolation and push policy: worktree + branch + push branch is the accepted default; do not re-ask.

## Skill improvement log
- 2026-11-11 devx-foundation: a bash heredoc with many quoted passages failed to parse as one command; write brief files with the Write tool, not heredocs.
- 2026-11-11 devx-foundation: a gate step that reports only the tail of a failing run loses the one fact needed (which test); every step must name the failing unit and keep the full output. `foreman.test` failed once in six full runs under load and passed five times; the test is still unidentified.
- 2026-11-11 devx-foundation: parallel builders on one branch worked with auto-discovered files (commands, gate steps) and no shared registry; keep that shape for any future fan-out.
- 2026-11-11 third-life night plan: the Director verifying, a real Foreman job and three builders on one machine made every
  wall-clock limit useless for an hour and cost the job two questions and four rounds. Do not run a real job while builders
  use the engine; a time-limit failure is re-run alone before it is believed.
- 2026-11-11 third-life night plan: a builder finished at 01:55 and its session stood still for seven hours without a report.
  Check a builder on disk when it is 15 minutes past its time-box.
- 2026-11-11 third-life night plan: five brief premises were wrong and each builder said so with evidence because the brief
  said its measurement outranks the brief; keep that line in every brief. Contract fields written before the code that
  validates them existed were met by nobody: name the validator with the field.
- 2026-11-11 core-perfection: the base moved under the spark between Phase 0 and the waves (another session's branch was
  merged, bringing this overlay). Fetch again and re-read the overlay right before the go-gate.
- 2026-11-11 core-perfection: per-package verification by Sonnet subagents with a fixed command list found four things
  no builder reported (windows of parallel runs throttling each other to 270 ms a frame, a proof failed by a sound-device
  error, a queue that left a game unbuilt, a drawing check that fails once in a while). Keep the second run; it costs
  50 to 100 thousand tokens a package.
- 2026-11-11 core-perfection: the builders' reports named a miss with its figure every time the brief asked for
  "met / not met / not done" per acceptance line. Round 2's loading package missed its target and said so; that
  sentence is what made rounds 3 and 4 possible. Keep the three-way acceptance form.
- 2026-11-11 core-perfection: the Director's reading of a failure went into the next brief as a reading "yours to
  prove or refute", with the case to reproduce. It was proven once (frame-rate-bound preparation) and refuted once
  (the remaining hitch was not the view's). Write causes that way, never as facts.
- 2026-11-11 core-perfection: looking at the pictures is the Director's and found what no check did (empty pads at
  the start, the road cut into patches, marks as boxes at 50 m). A builder's own guess at a visual cause was wrong
  (soft patches) and a 35-minute fix brief that said "switch candidates off one at a time" found the real one in 8.
- 2026-11-11 core-perfection: a worktree linked to the main checkout's `foreman/node_modules` by a junction must lose
  the junction (`cmd //c rmdir <link>`) BEFORE `git worktree remove`, and the main folder is counted before and after.
- 2026-11-11 core-perfection: the Director once typed `git commit --no-verify -m wip` while only meaning to stage, and
  amended it at once. Stage and commit are two commands; no flag that skips a hook is ever typed.
