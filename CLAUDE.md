# Third Life: start here

A Godot 4.7.2 sandbox whose games are built by LLMs (and later by players) from a composable kernel. Three parts:
`engine/` (kernel, kit, rigs, style, seed packs), `foreman/` (TypeScript job runner that has Claude CLI builders make packs),
`devx/` (the developer tool `tl`). Contracts between them are in `contracts/`; read `contracts/README.md` first.

## The one command

```
node devx/bin/tl.mjs <command>        # alias it: tl
tl doctor        machine check (node, git, Godot, ffmpeg, foreman deps)
tl check         the gate: --tier fast (no Godot) | full, --changed, --only <step>, --trend
tl watch         re-run lint -> smoke -> bot on change for a pack
tl new           scaffold a pack / bot / kit-part recipe
tl play          play a seed interactively
tl arch          architecture rules + generated API index (docs/generated/API-INDEX.md)
tl assets        asset manifest: list | check | scan | add
tl ledger        what Foreman jobs cost and how they ended
tl hook install  pre-push gate
```
Every command prints PASS/FAIL lines and a `tl.devx/1` JSON line last; exit 0 pass, 1 fail, 2 could not run.
`tl check --tier fast` before every commit; `tl check --tier full` before every merge to `main`.
New command = new file in `devx/lib/commands/`; new gate step = new file in `devx/lib/gate/steps/`. No registry to edit.

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

## Working in parallel with other sessions

The checkout is shared with other Claude sessions (a visual-look session and the Foreman night plan have used it). Rules:
1. Run `git status` first; foreign uncommitted files are never yours: stage per file, never `git add -A`, never stash.
2. Claim a scope in `.claude/sessions.json` (see `docs/OWNERSHIP.md`) and keep inside it; `tl arch` fails on overlapping claims.
3. Multi-file work goes in a worktree: `git worktree add .claude/worktrees/<name> -b <branch> main`.
4. Never edit a contract (`contracts/*`) from a builder role; put the question in your report.

## Where things are

| Need | Look at |
|---|---|
| What a pack is, how it runs | `contracts/PACK.md`, `contracts/RUNNER.md`, `engine/seeds/README.md` |
| Kernel API | `engine/kernel/API.md`, `docs/generated/API-INDEX.md` |
| Kit parts, rigs, look | `engine/kits/KIT.md`, `engine/rigs/RIGS.md`, `engine/style/STYLE.md` |
| Foreman jobs | `contracts/JOB.md`, `foreman/` |
| Assets and budgets | `contracts/ASSETS.md`, `assets/` |
| Sharing, world layering | `docs/SHARING.md`, `reports/` |
| Player-facing content tooling ideas | `docs/PLAYER-CONTENT-IDEAS.md` |
| History and decisions | `engine/JOURNAL.md`, `foreman/JOURNAL.md`, `docs/reports/` |

`spike/` and `kitlab/` are frozen history; `site/` is gitignored job output. Do not build on them.
