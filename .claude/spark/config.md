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

## Rituals
- Phase 0: read `.claude/sessions.json`; add an entry for this spark's scope. Phase 6: remove it.
- Phase 5: after every package, `tl arch --index` if engine API changed (docs/generated/API-INDEX.md).

## Repo law
Read CLAUDE.md "Laws that bite" and paste it verbatim into every builder brief. Walls: contracts/* are Director-only;
other sessions' uncommitted files are never touched; worktree for multi-file work; stage per file.
Builders run no git command of any kind (the Director stages and commits); a test may run git only against a temporary
repository with `GIT_DIR` unset. Scripts and briefs with quoted passages are written to a file with the Write tool and
run from there, never as a bash heredoc (the trap was hit three times on 2026-11-11).

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
