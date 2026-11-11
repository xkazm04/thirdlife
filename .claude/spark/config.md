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

## Wave defaults
One AskUserQuestion call of up to 4 questions.

## Question taste
- Operator wants tooling-scope questions asked as multi-select pillars, and answers extra wishes via "Other" (devx spark 2026-11-11 added a doctrine: player-facing content tooling ideas).
- Isolation and push policy: worktree + branch + push branch is the accepted default; do not re-ask.

## Skill improvement log
- 2026-11-11 devx-foundation: a bash heredoc with many quoted passages failed to parse as one command; write brief files with the Write tool, not heredocs.
- 2026-11-11 devx-foundation: a gate step that reports only the tail of a failing run loses the one fact needed (which test); every step must name the failing unit and keep the full output. `foreman.test` failed once in six full runs under load and passed five times; the test is still unidentified.
- 2026-11-11 devx-foundation: parallel builders on one branch worked with auto-discovered files (commands, gate steps) and no shared registry; keep that shape for any future fan-out.
