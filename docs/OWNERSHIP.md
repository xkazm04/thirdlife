# Ownership and scope claims

Several sessions work in this repo at once (look, engine tooling, Foreman, devx). Collisions cost more than anything
else, so a session says what it owns before it edits.

## Scope map (stable owners of areas)

`context-map.json` is the one partition of the repo: the skills (spark, scan-sweep, lens-scan) target by it and the
table below is generated from it. To change an owner, a rule or a glob, edit `context-map.json` and run `tl arch --index`.
`tl arch` fails when a tracked file lies in no context or in two (rule `context-map-cover`) and when this table is stale
(rule `ownership-fresh`).

<!-- generated:scope-map -->
Generated from `context-map.json` by `tl arch --index`; do not edit between the markers (rule `ownership-fresh`).

| Context | Group | Path globs | Owner role | Change rule |
|---|---|---|---|---|
| kernel | engine | `engine/kernel/**`, `engine/project.godot`, `engine/*.md` | engine | `engine/tools/selftest.sh` stays green; API additions update `engine/kernel/API.md`; `engine/JOURNAL.md` is the engine's history |
| kit | engine | `engine/kits/**`, `engine/kits_lab/**` | look | references nothing outside itself; `tl arch` module-walls; `engine/kits_lab` is the kit's layout lab |
| rigs | engine | `engine/rigs/**` | look | references nothing outside itself; `tl arch` module-walls |
| style | engine | `engine/style/**` | look | references nothing outside itself; `tl arch` module-walls |
| cores | engine | `engine/cores/**`, `engine/templates/**` | engine | a game core (docs/design/DIRECTIONS.md, direction 10): may use the kernel API, kits, rigs and style; packs reach it through one kernel entry; `engine/cores/rink/native/thirdjam*` is thirdjam's source byte for byte (patches listed in native/PATCHES.md); `engine/tools/selftest.sh rink` stays green |
| seeds | engine | `engine/seeds/**` | engine | every seed passes all verbs (`engine/tools/seeds.sh`) |
| packs | engine | `engine/packs/**` | engine | every house game passes all verbs (`tl check --tier full --only packs`); `engine/packs/README.md` |
| look | engine | `engine/look/**` | look | stills and journal only |
| ui | engine | `engine/ui/**` | engine | `engine/tools/ui.sh selftest`; reads job directories as `contracts/JOB.md` defines them |
| cards | engine | `engine/cards/**` | Director | `tl cards check`; a card names only what its seed shows (`contracts/CARDS.md`) |
| engine-tools | engine | `engine/tools/**` | engine | usage headers agree with verbs.json (`tl arch` verbs-contract); `tl check --tier full` |
| foreman | foreman | `foreman/**` | foreman | typecheck + tests; `contracts/JOB.md` is the contract |
| contracts | docs | `contracts/**` | Director only | builders propose in reports |
| devx | devx | `devx/**`, `assets/**`, `.claude/**`, `CLAUDE.md`, `perf/**`, `context-map.json`, `.gitignore` | devx | `tl check --tier fast`; `perf/` measures under load and starts only processes it ends |
| docs | docs | `docs/**`, `reports/**`, `research_notes/**`, `briefs/**` | whoever changes the thing | docs in the same commit; `docs/generated/**` only from its generator |
| frozen | history | `spike/**`, `kitlab/**` | nobody | frozen history: do not build on it |
| boot | engine | `engine/boot/**`, `engine/export_presets.cfg` | engine | `tl check --tier full --only world`: every game of `engine/boot/games.json` hashes in one world as it does alone; the exe exports (`docs/EXE.md`) |
<!-- /generated:scope-map -->

## Claims

`.claude/sessions.json`: `{"sessions":[{"id":"<short>","scope":["<glob>",...],"note":"<what and until when>"}]}`.
Add an entry when you start multi-file work, remove it when you land. `tl arch` (rule `scope-claims`) fails when two
claims overlap, so the collision shows up before the merge instead of after it. Claims are a convention among
cooperating sessions, not a lock: they do not stop an edit, they make the conflict visible.

## Landing

1. Work in a worktree branch when more than a couple of files are involved.
2. Before merging compute the overlap: `git diff --name-only main...<branch>` against `git status --short` of the landing checkout.
3. `tl check --tier full` green, then fast-forward or PR. The Director merges contracts.
