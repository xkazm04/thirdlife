# Ownership and scope claims

Several sessions work in this repo at once (look, engine tooling, Foreman, devx). Collisions cost more than anything
else, so a session says what it owns before it edits.

## Scope map (stable owners of areas)

| Area | Path globs | Owner role | Change rule |
|---|---|---|---|
| Kernel | `engine/kernel/**`, `engine/project.godot` | engine | `engine/tools/selftest.sh` stays green; API additions update `engine/kernel/API.md` |
| Kit, rigs, style | `engine/kits/**`, `engine/rigs/**`, `engine/style/**` | look | reference nothing outside; `tl arch` module-walls |
| Seeds | `engine/seeds/**` | engine | every seed passes all verbs (`engine/tools/seeds.sh`) |
| Look captures | `engine/look/**` | look | stills and journal only |
| Designer panel | `engine/ui/**` | engine | `engine/tools/ui.sh selftest`; reads job directories as `contracts/JOB.md` defines them |
| Recipe cards | `engine/cards/**` | Director | `tl cards check`; a card names only what its seed shows (`contracts/CARDS.md`) |
| Foreman | `foreman/**` | foreman | typecheck + tests; JOB.md is the contract |
| Contracts | `contracts/**` | Director only | builders propose in reports |
| Dev tool | `devx/**`, `assets/**`, `.claude/**` | devx | `tl check --tier fast` |
| Docs | `docs/**`, `CLAUDE.md` | whoever changes the thing | docs in the same commit |

## Claims

`.claude/sessions.json`: `{"sessions":[{"id":"<short>","scope":["<glob>",...],"note":"<what and until when>"}]}`.
Add an entry when you start multi-file work, remove it when you land. `tl arch` (rule `scope-claims`) fails when two
claims overlap, so the collision shows up before the merge instead of after it. Claims are a convention among
cooperating sessions, not a lock: they do not stop an edit, they make the conflict visible.

## Landing

1. Work in a worktree branch when more than a couple of files are involved.
2. Before merging compute the overlap: `git diff --name-only main...<branch>` against `git status --short` of the landing checkout.
3. `tl check --tier full` green, then fast-forward or PR. The Director merges contracts.
