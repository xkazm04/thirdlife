# D1 home: land the Home arm A (day of 22 Nov 2026)

**Owner (verbatim, ~10:30, on the night verdict):** "3. Home - A". **And (~10:40):** "run next shift now with all three
steps as daily shift, I will play the game after before major directions for night shift"

Worktree: `C:/Users/kazda/kiro/third-life/.claude/worktrees/d22-home` (branch d22-home, from main 45f108d). Route: Opus solo.

## Goal
Arm A ("Wren Valley": one continuous 6.5 km land around the village, with a river valley, farmland, woods and a ridge) lives
on branch `n22-world-a` (71e80bf). It adds new files only: `engine/kernel/world/home/**`,
`engine/tools/selftest.d/750-home-a.sh` and the arm's lane folder. Last night it ran as a visual growth in its own tour; it
is not hooked into the game. Make it the Home a person walks in the normal game:
1. Bring arm A's code into your tree. Use `git -C <your tree> checkout n22-world-a -- engine/kernel/world/home
   engine/tools/selftest.d/750-home-a.sh`, which only writes files into the tree and is allowed, or copy the files. Keep any
   arm-A notes you need under `docs/shifts/2026-11-22-day/lanes/D1-home/`.
2. Hook it in at boot. The World entry of the menu should build the village plus arm A's growth (arm A's PATCHES.md: "after
   Landscape.build returns the village terrain and before the first draw"), and the flat far plain and its mesas go. Keep a
   switch (an env var or a boot option) for the old landscape while the owner judges, and say its name.
3. Make it walkable. A visitor who walks or flies out of the village must land on arm A's ground, the bridge deck included.
   Build the colliders through N5's land/ chunk colliders (`engine/kernel/world/land/chunk_collider.gd`). Today the grown
   terrain has no collision faces.
4. Chunk it through N5's land/ format where that is cheap. Arm A's chunks are 96 m: 33x33 u16 heights at 3 m, 32x32 palette
   ids and sparse water. If the format needs a contract (`tl.land/1`), write the proposal in your report; do not edit
   contracts.

## Acceptance
- **Arm A in the normal World:** the World (`bash engine/tools/world.sh`, the `tl play` world entry and the exported exe's
  World) shows arm A, and the far plain is gone.
  - Stills from the play camera at the village edge and out in the valley: JPG, in your lane folder.
  - One window clip of 20 s or less: a visitor walks from the village gate into the valley and across the bridge.
- **Walkable:** a scripted visitor walk (a selftest in 750-759) leaves the village, crosses the bridge and stays on the
  ground for a stated distance: no fall-through, no floating.
- **World = alone holds:** `tl check --tier full` world 8/8, and every pack verb hash unchanged (arm A touches no pack).
- **Frame cost, read honestly:** first-frame build time and walking frame p50/p99 against main's, each labelled busy or
  quiet.
- **Gates:** the fast tier and the full tier green in your tree.

## Scope (your claim)
- **Yours:**
  - `engine/kernel/world/home/**`
  - `engine/kernel/world/landscape.gd`
  - `engine/kernel/world/land/**`
  - `engine/boot/**`
  - `engine/tools/selftest.d/75*`
  - your lane folder
- **Not yours:** `engine/kernel/world/pack.gd` and `world.gd` belong to D2. If the hook needs them, SendMessage the Director
  first.
- **Size cap:** a file over 600 lines fails arch; split it instead.

## Read first
- The arm A tree: `C:/Users/kazda/kiro/third-life/.claude/worktrees/n22-world-a`. In it, REPORT.txt, PATCHES.md and LOG.md
  under `docs/shifts/2026-11-22-night/lanes/N6-world/arm-a/`.
- On main:
  - `docs/shifts/2026-11-22-night/lanes/N6-world/REPORT.md` and its COMPARE.md;
  - `docs/shifts/2026-11-22-night/lanes/N5-chunks/REPORT.md` (the land/ format);
  - `engine/kernel/world/WORLD.md`;
  - CLAUDE.md.

## Time and rounds
Time box: until 17:15. Land in three rounds:
1. the boot hook, the far plain gone, stills;
2. walkable, with the selftest;
3. chunks and frame cost.

## Shift-wide rules for this day
- Absolute paths only; never `cd` inside a backgrounded command line.
- After you send "landable round k" (SendMessage to the Director), make NO edits in your tree until the Director answers
  "landed" (or "rejected").
- Stamp STANDUP lines from `date`, never from memory. A STANDUP line at least every 60 minutes; no line for 60 minutes
  gets a status ask, a second miss gets a stop.
- Lanes stop at 17:15 (CEST): report written, last STANDUP line `done` or `cut`.
- Other sessions load this machine: wall-clock checks (hockey many_budget, perf, the kernel suite's cap) are not evidence
  on a busy machine; say so instead of tuning to them.
- The full tier in a worktree needs `npm ci` in its `foreman/` and plain copies (no links) of
  `site/marble-run-three-marbles-20261110-1` and `-2` from the main checkout into its `site/`.

# Lane rules (pasted verbatim into every lane brief)

## Standups: you report, the Director reads
- Keep `docs/shifts/2026-11-22-day/lanes/<lane>/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
  when the lane lands).
- Append one line at each milestone and at least every 60 minutes of work:
  `HH:MM | state: working|blocked|done|cut | did: <one line> | next: <one line> | gates: <last PASS/FAIL line or ->`
- `blocked` names the question in the same line. Then keep working on whatever the block does not touch.
- When you finish, write `REPORT.txt` beside it (the harness refuses agent writes to files named REPORT.md), return the
  full report as your final message too, and set the last standup line to `done`.

## Honesty
- Evidence or it is not done: a gate line, a test count, a still, a video, a repro before and after.
- A stopped run is never a pass. NOT RUN is not PASS. Fewer tests completed than on main is a stopped run.
- Unmeasured is not zero. Never fake a frame, a figure or a hash.
- A behaviour change that moves a test expectation is named, with why. Never loosen a test to make it pass.
- What the player sees or feels is judged as a person meets it (a window, the exported game), not only headless.

## Laws (CLAUDE.md)
- Work only in your worktree. No git that writes (read-only `git diff`/`git status` are fine). The Director lands.
- Never kill a process you did not start. Prefer `--headless`. Build the class cache once: `"$G" --headless --path engine --import`.
- Time is physics frames; determinism (same pack + seed + frames = same state_hash); unknown keys are errors; packs use only
  the TL* API and never declare class_name; kit, rigs, style reference nothing outside themselves.
- Contracts (`contracts/*`) are Director-only: put the question in your report.
- New selftest cases go in your own `engine/tools/selftest.d/NNN-<name>.sh` files, numbered inside the block range your brief
  assigns (two lanes once collided on 360).
- Raw captures (frame folders, long or uncompressed clips, mkv/avi) stay under `.tl/` in your worktree. The lane folder
  gets only sheets, notes, JPG stills and mp4 clips of 30 s or less.
- A kernel API addition updates `engine/kernel/API.md`; the Director regenerates docs on main (`tl arch --index`).
- Gates before `done`: `node devx/bin/tl.mjs check --tier fast`; when kernel, kits, rigs, style or seeds changed, also
  `node devx/bin/tl.mjs check --tier full` (perf alone if it says NOT RUN).

## REPORT.md
- Outcome against each acceptance criterion: met / not met, with its evidence.
- Gates with PASS/FAIL lines and counts.
- Changed files; behaviour changes; anything the owner should look at, and how.
- Questions for the Director; the next three things this lane would do.
