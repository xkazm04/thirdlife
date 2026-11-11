# P9: the executable: a build the owner starts by double click

You are a builder on **Third Life**: a single-player sandbox on Godot 4.7.2 (Jolt physics, 60 Hz fixed tick) in which
an LLM builds small games ("packs") over a law kernel, and the games all keep running in one world a visitor walks
through. The owner has never played any of it: everything so far is started from Git Bash with command lines nobody
has run with a person at the keys. The owner's standing rule since today: **every night run ends with a runnable exe
package.** Nothing has ever been exported from this project. You build the way to export it and prove the result
starts. Five other builders are changing the engine tonight; when they have landed, the Director runs your export
command once more on the merged tree to make the night's final build, so the command must work unattended.

## Read first
1. `engine/kernel/world/WORLD.md` (the village, the visitor, `world.sh visit`), `engine/tools/world.sh` and
   `engine/tools/view.sh` (how a windowed world is started and what arguments it gets), `engine/kernel/host/host.gd`
   and `host.tscn` (the one entry scene; modes come from command-line arguments), `engine/kernel/world/walks/tour.json`
   (the six-game village), `engine/project.godot`.
2. `engine/kernel/runner/worker.gd` (how a pack directory is loaded: scripts are loaded from a directory path at run
   time), `engine/kernel/world/pack.gd`, `engine/kernel/api/tl_context.gd` (`load_script`, `read_json`),
   `engine/kernel/host/cpuclock.gd` (it starts a PowerShell helper for processor time: check what an exported build
   does there).
3. `docs/reports/N7-WORLD.md` and `docs/reports/P4-RELIEF.md` ("not verified": nobody has walked it).

## What exists on this machine
Godot 4.7.2 console executable: `C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe`
(export it as `TL_GODOT`). Export templates for 4.7.2 are installed under
`%APPDATA%\Godot\export_templates\4.7.2.stable\`. There is no `export_presets.cfg` and no build has been made.

## Scope
Yours: new `engine/export_presets.cfg`, new `engine/tools/export.sh`, new `engine/boot/**` (a boot scene and script
of your own for the exported game), new `docs/EXE.md`, the output folder `dist/` at the repository root (ignored by
git). You may add one feature-tagged override to `engine/project.godot` if the export needs its own main scene; say
exactly what you added. Not yours: everything else (`engine/kernel/**`, `engine/tools/world.sh`, `view.sh` and so on
are being changed by other builders tonight: start the world through what exists; if you need a hook, write the exact
patch to `engine/boot/PATCHES-P9.md`).

## The work, in this order
1. **Find out what an export of this project needs.** The engine loads packs from directories at run time
   (`load(pack_dir + "/scripts/main.gd")`), reads JSON from them, builds every mesh in code, and starts helper
   processes. Which of that works from inside a packed build and which needs files on disk beside the exe? Do packs
   inside the packed project load by their `res://` path? Can an exported build still compile a `.gd` file from a
   folder outside the pack file (the product needs that: games arrive after the game shipped)? Measure, do not assume:
   a table in `docs/EXE.md`.
2. **`bash engine/tools/export.sh`** makes `dist/ThirdLife/` with `ThirdLife.exe` (and whatever files it needs
   beside it) from the current tree, unattended, and prints the full path. It refuses to overwrite a build it did not
   make, writes a `BUILD.txt` (the commit it was built from as given by an argument or read from a file the Director
   provides, the date, the engine version, the list of games inside), and exits non-zero with a readable reason when
   the export fails. You may not run git: take the commit name as an argument (`--commit <text>`), default "unknown".
3. **What the exe opens.** Double click, no arguments: a window (not a console), the village of `tour.json` with the
   visitor at its start, walking with WASD, E to enter the game whose plot he stands in, Q to leave, Esc to quit, as
   `world.sh visit tour` does today. A games folder beside the exe (`dist/ThirdLife/games/`) holds the packs the
   world uses as plain folders; put the hockey game there too
   (`C:\Users\kazda\kiro\third-life\site\ice-hockey-three-against-20261111-1\promoted\game.ice_hockey_three_against@0.1.1`)
   on a plot of its own if the walk format lets you add a seventh plot without editing files outside your scope
   (a walk file of your own under `engine/boot/` is yours). A short line on screen at start says the keys.
   Nothing about "how games start" is designed beyond this; do not invent menus.
4. **Proof that it starts and is the same game.** `bash engine/tools/export.sh check`: starts the built exe with
   arguments that make it run the scripted tour headless or windowed for a fixed number of ticks and print each
   pack's state hash, and compares with the same run from the editor binary. Equal hashes, or the exact difference
   and your best explanation (the research flagged editor against export determinism as never tested). Also: the exe
   started with no arguments produces a frame (take one capture through whatever the build offers, or have the boot
   script write one picture after 120 frames when an environment variable asks for it) and exits cleanly on request.
5. **What a person needs to know**, in `docs/EXE.md`: where the build is, how to start it, the keys, what is in it,
   what is known not to work, how big it is, how long the export takes.

## Acceptance (the Director will run these)
- `bash engine/tools/export.sh --commit test` on a clean tree makes `dist/ThirdLife/ThirdLife.exe`; a second run
  replaces the first build cleanly.
- `bash engine/tools/export.sh check` passes: the exe's hashes for the tour equal the editor run's, or the difference
  is stated and explained.
- The exe started with no arguments shows the village (one capture, looked at by you) and exits on Esc or on the
  check's request; no process of it is left behind.
- The exe runs when `dist/ThirdLife/` is copied to another folder (a path with a space in it), without the
  repository beside it.
- `node devx/bin/tl.mjs check --tier fast --changed` green in your worktree.

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
- **You work only in your own git worktree: `C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p9`** (branch
  `core-p9-exe`, cut from `main` after round 1 landed). Paths in this brief are relative to it unless written in
  full. `dist/` means the `dist` folder in your worktree. Never edit the main checkout.
- **No git command of any kind.** The Director stages and commits your files.
- Kill every process you start, the exe included; never kill others; never leave a window behind (give windows
  `--position 0,1440` where you can). No network. No model calls. Never read, use or print any `ANTHROPIC_KEY_*`
  variable. Five other builders run the engine tonight.
- Small verified steps. Journal each in `engine/boot/JOURNAL.md`.
- **Your measurement outranks this brief.** Where a premise here is wrong, say so with the evidence and build the
  right thing.

## Final message (your report, as text; the Director saves it to a file)
Status; the table of what an export needs; what `export.sh` does and its output; the check's result with the hashes;
the capture's full path and what you saw in it; the build's size and the export's duration; the list of files changed;
the contents of your patches file; what is known not to work in the exe; what you did not verify (no person has
started it); questions; minutes spent from real timestamps (`date`).

## Time-box
Until the list is done or **100 minutes after your start** (run `date` first and often). An exe that starts into the
village and passes the check is worth more than a seventh plot. Leave the last ten minutes for the report. A usage
limit can cut you off without warning: keep the journal current, and if you are resumed, re-read this brief and your
journal and continue.
