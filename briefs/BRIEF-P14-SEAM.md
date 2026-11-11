# P14: the seam between the three, and the build the owner starts

You are a builder on **Third Life**: a single-player sandbox on Godot 4.7.2 (Jolt physics, 60 Hz fixed tick) in which
an LLM builds small games ("packs") over a law kernel, and the games all keep running in one world a visitor walks
through. The owner is spending a day and a night on perfecting the core before the project spreads into many games.
Three rounds have landed today (reports `docs/reports/P1-*.md` to `P13-*.md`). You are the ONLY builder of the last
package of the day: nobody else changes the engine while you work, and the whole engine is yours. What you leave is
what the owner starts tomorrow morning by double click.

## Why this package
Round 3 ran as three builders with separate files. Each closed its own part and each left the part that sits between
them in a patches file:
- **Arrivals (P12)** took the main-thread cost of a game's setup from 16 to 618 ms down to 2 to 31 ms, from the
  second arrival on a machine. What is left of the hitch (118 to 150 ms per arriving game in the tour, a worst frame
  of 161 to 204 ms) is the VIEW's work when a game arrives: a stand-in built in the frame and the copy of the game's
  colliders into the visitor's space (`engine/kernel/world/PATCHES-P12.md` entry 6).
- **Far pictures (P13)** now builds a game's far pictures on a worker and keeps them on disk, and builds the land's
  edges after the first frame. Whether an ARRIVING game uses that path was nobody's to check.
- **Controls (P11)** made the world's hash the contract's hash and gave the visitor real controls and a record.
The target of the whole run stands and has never been met: **in `walk30` and `tour6`, after the first two frames, no
frame over 16.7 ms and no world tick over 8 ms.** You are the first builder who owns every file it needs.

## Read first
1. `docs/reports/P12-ARRIVALS.md`, `P13-FAR2.md`, `P11-CONTROLS.md`, `P5-LOADING.md`: the status, the acceptance
   lists and the Director's verification sections. Then the three patches files in full:
   `engine/kernel/world/PATCHES-P12.md`, `engine/kernel/world/draw/PATCHES-P13.md`, `engine/boot/PATCHES-P11.md`.
2. `engine/kernel/world/draw/view.gd` (what happens on the events `built` and `rebuilt`), `draw/draw.gd`,
   `draw_pictures.gd`, `terrain/world_space.gd` (`add_pack`), `jobs.gd`, `engine/kernel/world/TIERS.md` (P5, P12),
   `draw/FAR.md` (section on pictures off the frame).
3. `engine/boot/boot.gd`, `engine/boot/village.json`, `engine/kernel/world/walks/compact_village.json`,
   `engine/tools/export.sh`, `docs/EXE.md`.

## Scope
Everything under `engine/`, `devx/`, `perf/`, `docs/` except `docs/reports/` (the Director's). Not yours:
`contracts/**` (write proposed text in your report), `foreman/**` unless an item below names a line, `briefs/**`.
Patches file for what you leave: `engine/PATCHES-P14.md`.

## The work, in this order
1. **Measure the seam first.** On this merged tree, for `tour6` and `walk30` in a window: every frame over 16.7 ms
   with its world tick and what ran in it (arrival attach, stand-in or far-picture build, collider copy, landscape
   arrival, first draw of new meshes, shot encode). One table. Twice: with empty caches (delete only the game's own
   cache folders under its user data folder, `tl_cache`) and with warm caches. This table decides the rest.
2. **Take the view's arrival work off the frame** (PATCHES-P12 entry 6, PATCHES-P13 entries 4 and 5). A game that
   arrives far gets its picture from the worker or the disk cache, never built in the frame. The copy of its
   colliders into the visitor's space is prepared off the main thread or sliced under a budget of 2 ms a frame; the
   visitor must never be able to reach ground or a wall that has no collider yet (state the rule that guarantees
   it: for example nearest plots first and always before he is within N metres). Whatever else your table shows.
   Every world proof still passes; no hash moves (the 26 hashes of `docs/reports/P7-CONTRACT.md`).
3. **The first start on a machine.** P12's gain needs a recipe cache that a fresh machine does not have, and P13's
   pictures need a cache too. Measure the exe's first start against its second (delete the exe's user data folder
   `%APPDATA%\ThirdLife` between runs; it is the exe's own): time to the first frame, time until all games stand,
   worst frame. Then close the gap as far as is cheap: the export may ship the caches it can compute at build time
   (recipes and pictures for the games in `games/`), keyed so that a changed game is not served a stale one. State
   what a first start still costs.
4. **One lock for windows.** P11 gave `world.sh` and `view.sh` a machine-wide lock (`thirdlife_window.lock`) and
   P12 gave the perf scenarios another (`tl_window.lock`). Make them one. Prove with a windowed tour and a windowed
   perf scenario started in the same second.
5. **API version 1.1** (the Director's decision): `TLKitSite.bind_scoreboard` from P13 is an addition. Set the
   kernel's version to 1.1 the way the rule's message says, make the P7 selftest cases that hold the text "1.0"
   read the version from the manifest code instead, regenerate with `node devx/bin/tl.mjs arch --index`. A pack
   that says 1.0 still runs; one that says 1.2 is refused readably (a case for each). Also `engine/tools/item.sh`
   line 303 as `engine/boot/PATCHES-P11.md` entry 1 says, and the leftover small patches you agree with from the
   three files (say which you applied and which you left, with the reason).
6. **The exe opens the compact village.** `engine/kernel/world/walks/compact_village.json` reads as a place from
   the visitor's eye (`docs/reports/img/p13_compact_vs_concept.jpg` and the eye-level frame described in
   `docs/reports/P13-FAR2.md`). Make it the village the exe opens, with all seven games (the hockey game on its
   lot), the visitor starting on the road facing the village. `bash engine/tools/export.sh --commit test` and
   `bash engine/tools/export.sh check` pass: hashes equal in editor, exe and copied exe; the scripted person walks,
   turns with the mouse, enters with E, leaves with Q to the gate, quits with Esc. Take four pictures from the exe
   (first frame, on the road after 10 seconds, on stage, after leaving) and look at them. Update `docs/EXE.md`:
   what a person sees and does in the first minute, and what is known not to work.
7. **A quiet line.** You are alone on the machine apart from other sessions' idle load:
   `node devx/bin/tl.mjs perf run --quiet-only --wait 900` after your last change, then
   `node devx/bin/tl.mjs perf compare 8 -1` (line 8 is the quiet line of round 2). Report the table.

## Acceptance (the Director will have these re-run)
- The table of item 1, before and after, cold and warm.
- `walk30` and `tour6`, quiet: worst frame, frames over 16.7 ms, worst tick, time to the first frame. The target or
  the exact figure and what is in the frames that remain.
- The 26 hashes unchanged; `world.sh alone` (world hash = alone hash) passes for the seven games; world proofs pass
  headless and in a window; the drawing check passes.
- The exe: first start against second start (item 3); `export.sh check` passes; the four pictures.
- `node devx/bin/tl.mjs check --tier full` green, with rule `api-v1` passing at version 1.1.

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

## Lessons of this run that bind you too
- **Every state hash changed once today (P7)** and the kernel API is frozen as version 1.0: `tl arch` rule `api-v1`
  fails when a public member of `kernel/api`, kit, rigs or style is removed or changed, and when one is added without
  a new minor version. If your work adds a public member, regenerate with `node devx/bin/tl.mjs arch --index` as the
  rule's message says and list every added member in your report; the Director settles the version at the merge.
  Do not remove or change a member of version 1.
- Limits count processor time, not wall time (P1). A busy machine does not fail a run; a figure taken on a busy
  machine is still not a quiet figure: say which of your figures are which.
- `captures/` folders are ignored by git. A picture you want kept as evidence: say its full path in the report.
- A file over 600 lines may not grow (`tl arch` size ratchet); new files stay under 600. Split, do not ask for more.
- Windows Git Bash: do not write files through heredocs that contain quotes; use your file-writing tool.
- Schema names of the form `tl.<name>/<n>` in any tracked file, Markdown included, must be declared ones.

## How to work
- **You work only in your own git worktree: `C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p14`** (branch `core-p14-seam`, cut from `main` after round 3 landed). Paths in
  this brief are relative to it unless written in full. Never edit the main checkout or another worktree.
- **No git command of any kind.** The Director stages and commits your files.
- You are alone on the engine: change what the work needs, and keep every change as small as it can be.
- Godot console executable: `export TL_GODOT="C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe"`.
  The hockey game built by an LLM last night, used as the real-world test pack (read only):
  `C:/Users/kazda/kiro/third-life/site/ice-hockey-three-against-20261111-1/promoted/game.ice_hockey_three_against@0.1.1`.
- Kill every process you start; never kill others; never leave a window behind (give windows `--position 0,1440`
  where the tool allows). No network. No model calls. Never read, use or print any `ANTHROPIC_KEY_*` variable.
- Never run two engine suites at once. The full gate takes 15 to 25 minutes on this machine tonight.
- Small verified steps. Journal each in `engine/JOURNAL.md` under a section of your package's name (append only).
- **Your measurement outranks this brief.** Where a premise here is wrong, say so with the evidence and build the
  right thing. Round 2's builders each found one such premise.

## Final message (your report, as text; the Director saves it to a file)
Status in three lines; per item: what was built, the command that proves it, the result; the acceptance list one by
one (met / not met / not done, with figures); files changed; proposed contract text; the contents of your patches
file; what changed for a pack author; what you did NOT verify; questions; minutes spent from real timestamps (`date`).
Plain sentences. A miss stated with its figure is worth more than a claim.

## Time-box
Until the list is done or **110 minutes after your start** (run `date` first and often). Work the list in its
order: the first items carry the package. Leave the last twelve minutes for `node devx/bin/tl.mjs check --tier full`
(start it early enough) and the report. A usage limit can cut you off without warning: keep the journal current, and
if you are resumed, re-read this brief and your journal and continue.
