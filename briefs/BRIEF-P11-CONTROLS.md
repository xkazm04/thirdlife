# P11: the world joins the contract, and a person can walk

You are a builder on **Third Life**: a single-player sandbox on Godot 4.7.2 (Jolt physics, 60 Hz fixed tick) in which
an LLM builds small games ("packs") over a law kernel, and the games all keep running in one world a visitor walks
through. The owner is spending a day and a night on perfecting the core before the project spreads into many games,
because every engine change gets more expensive after that. Two rounds have landed today (reports
`docs/reports/P1-*.md` to `P10-*.md`). You are one of three builders of round 3. Each of you owns files; the other two
are changing the engine at the same time in their own worktrees.

## Why this package
Round 2 froze the simulation contract for a pack that runs alone: recorded input, a hash that covers bodies, pack
state, the seeded generator and the input (`docs/reports/P7-CONTRACT.md`). The world has not followed: a pack in a
world is hashed by older code in `pack.gd`, its script's event handlers are not switched off there, and the visitor's
keys are read straight from the device in `view.gd`, outside any record. And the one thing the owner will do tomorrow
morning is start `ThirdLife.exe` and walk: today A and D turn him in a circle, there is no sidestep, no mouse look,
and after leaving a game he stands where he entered it (`engine/boot/PATCHES-P9.md` entry 4, measured).

## Read first
1. `docs/reports/P7-CONTRACT.md` and `engine/kernel/api/PATCHES-P7.md` (sections 1 to 6 and 9 are yours to apply).
2. `docs/reports/P9-EXE.md`, `engine/boot/PATCHES-P9.md`, `engine/boot/boot.gd`, `docs/EXE.md`.
3. `engine/kernel/world/draw/view.gd` (`_live_input`, the chase camera, stage enter and leave),
   `engine/kernel/world/visitor.gd`, `engine/kernel/world/WORLD.md`, `engine/kernel/api/tl_input.gd`,
   `engine/kernel/runner/session.gd`, `engine/kernel/host/statehash.gd`.
4. `engine/kernel/world/PATCHES-P5.md` entry 1, `engine/kernel/world/draw/PATCHES-P6.md` entry 2.

## Scope
Yours: `engine/kernel/world/draw/view.gd`, `engine/kernel/world/visitor.gd`, `engine/kernel/host/**`,
`engine/kernel/runner/**`, `engine/boot/**`, `engine/tools/world.sh`, `engine/tools/view.sh`, `engine/tools/tl.sh`,
`engine/tools/export.sh`, `engine/project.godot`, `engine/export_presets.cfg`, `docs/EXE.md`, every `pack.json` under
`engine/seeds` and `engine/kernel/examples` (the version key only), `devx/templates/**`, and in `foreman/` only the
three lines of PATCHES-P7 section 5. In `engine/kernel/world/pack.gd` you own ONLY `state_hash()` with its helpers
(`_q`, `_put_v3`, `_hash_node`) and one new function that switches a pack script's event handlers off; another builder
(P12) owns the rest of that file. `engine/tools/selftest.sh`: append your cases in one block at the end, marked
`# --- P11 ---`. Patches file: `engine/boot/PATCHES-P11.md`.
Not yours: `engine/kernel/world/world.gd`, `jobs.gd`, `tiers.*`, `engine/kernel/api/**` (P12);
`engine/kernel/world/draw/draw*.gd`, `landscape.gd`, `terrain/**`, `engine/kits/**` (P13).

## The work, in this order
1. **The world's hash is the contract's hash** (PATCHES-P7 section 1). A pack in a world is hashed by
   `kernel/host/statehash.gd` with its generator, its input and its origin. Then prove the stronger statement that
   was not provable before: for each of the seven games of the exe's village, the pack's hash after N of its own
   ticks in a world equals the hash `tl.sh smoke` (or the bot) gives for the same pack alone after N ticks. Table of
   old and new world hashes. Every world proof (`world.sh proof`, `tour`, the `world.*` selftest cases) passes.
2. **Event handlers of a pack script are off in a world too** (section 2), with a control case that fails when your
   line is removed. **`_input` in a pack is a fence error** (section 4: lint row, the `bad_bypass` example, the
   selftest cases). `kernelApi` 1.0 in seeds, examples, templates and the three Foreman lines (sections 5, 6).
3. **The visitor's input is a record.** The world gets one `TLInput` of its own with actions for the visitor (forward,
   back, left, right, run, enter, leave, and the pointer actions for looking). It is sampled once per world tick;
   `_live_input` reads it and no device. A visit can be recorded (`--record=<file>`, the P7 input record format, no
   new schema) and replayed: the replay puts the visitor on the same path, and every pack ends with the same hash.
   Proof: a scripted visit of at least 1,800 ticks with an enter and a leave, recorded, replayed twice, compared.
   This is the piece that later lets a second player's keys arrive from another machine: keep the device out of
   everything below the sampling line.
4. **Controls a person can use.** W and S move along where the camera looks, A and D sidestep, the mouse turns the
   view (yaw freely, pitch inside limits that keep the visitor in frame), Shift runs, E enters the game whose plot
   he stands in, Q leaves it, Esc quits when nobody is on stage. The mouse is captured while walking and released
   while a game is on stage (games read the pointer through their own input) and when the window loses focus. After
   Q he stands outside the plot at its gate, facing away from the venue, and the camera is behind him. The line of
   keys on screen says what is true. Measure as P9 did, with scripted keys and pointer movement in the exe and in the
   editor run: W 180 frames is a straight line; D 180 frames is a straight line at a right angle to it; a pointer
   movement of N pixels turns him by the angle you state; after Q his distance to the plot's edge. Take three
   pictures (walking, on stage, after leaving) and look at them.
5. **The door of the exe** (PATCHES-P9 entries 1, 2 for `manifest.gd`, 3a to 3c): the host does not start itself
   again in an exported build; `resolve_dir` keeps a `res://` path in an export; a live walk does not run the scripted
   shots and events; a user data folder of the exe's own. Then simplify `boot.gd` by what became unnecessary.
   `bash engine/tools/export.sh --commit test` and `bash engine/tools/export.sh check` pass: the exe's hashes equal
   the editor's for seven games.
6. **Options through the host** (PATCHES-P5 entry 1, PATCHES-P6 entry 2): `load`, `trip`, `dead`, `picture` are
   listed options; the environment variables that stood in for them go.
7. **Windowed test runs that do not fail for the machine's reasons.** Two findings of this afternoon's verification
   (`docs/reports/P5-LOADING.md` and `P6-FAR.md`, sections "What failed in the re-run"): (a) windows of several runs
   on the same spot of the screen throttle each other to about 270 ms a frame, and tours then run into the tool's
   600-second limit; (b) a windowed tour with correct hashes was counted failed for one engine error from the sound
   device (`WASAPI: GetBufferSize error`). Give the windowed modes of `world.sh` and `view.sh` a machine-wide lock
   (a lock file under the system's temporary folder, with the holder's process id, taken over when the holder is
   dead) so that two windowed runs wait their turn instead of overlapping, and start test windows with the engine's
   silent sound driver. The exe keeps the real driver. Prove the lock with two tours started at the same moment.

## Acceptance (the Director will have these re-run)
- The table of item 1: seven games, world hash = alone hash for the same ticks, twice in a row.
- `bash engine/tools/selftest.sh` world cases and your new cases pass; `tl.sh lint` passes on the three seeds, the
  examples and the hockey pack; `bad_bypass` fails lint on its `_input` handler.
- A recorded visit replays to the same visitor path (position at five named ticks) and the same pack hashes.
- The control measurements of item 4, from the exe.
- `export.sh` and `export.sh check` pass on your tree.
- `node devx/bin/tl.mjs check --tier full` green.

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
- **You work only in your own git worktree: `C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p11`** (branch `core-p11-controls`, cut from `main` after round 2 landed). Paths in
  this brief are relative to it unless written in full. Never edit the main checkout or another worktree.
- **No git command of any kind.** The Director stages and commits your files.
- **Stay inside your files** (section "Scope"). For anything outside: write the exact patch to your patches file and
  say so in the report. Two builders editing one function is the failure this rule exists for.
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
Until the list is done or **120 minutes after your start** (run `date` first and often). Work the list in its
order: the first items carry the package. Leave the last twelve minutes for `node devx/bin/tl.mjs check --tier full`
(start it early enough) and the report. A usage limit can cut you off without warning: keep the journal current, and
if you are resumed, re-read this brief and your journal and continue.
