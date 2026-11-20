# Day of 20 Nov: two looks, two teams (common part of every arm's brief)

## The owner's words, verbatim (20 Nov, 10:20)
"hard to decide. Diorama looks better on first sight, but graphics seems blurry and quality/fidelity far below the art
concept. The original game does not look very good now, but there is clear the potential is there to evolve to create
beuatiful and sustainable world. Lets use this day still to work in parallel. 2 builders on Evolving crisp cell, 2
builders on diorama to see if we can improve the graphics quality further. Again 1 Astra + 1 Fable in team. No need to
focus on full game, the focus should be the world (surface, sky, nature) and the character. I would like to see from
both glimpses of full potential which would help me decide. Lets use 10 hours of time, and loop to perfect both
variants to use the time fully"

Also (10:10): "for Character the Opus + Astra looked better" than Fable's.

## What tonight decides
The owner chooses between two looks tonight, from glimpses of each one's full potential:
- **Crisp cel** (team `cel`): today's look evolved toward board 2, `docs/shifts/2026-11-20-night/target/2-crisp-cel.jpg`
  (rules: `target/NOTES.md` § 2).
- **Toy diorama** (team `dio`): last night's combined diorama pushed to the fidelity of board 4,
  `target/4-toy-diorama.jpg` (rules: `target/NOTES.md` § 4).

Show the best each look can be. **Quality is the goal**, not breadth: a village, its sky, its nature and its figure at
concept-art fidelity beat many half-done systems. Games (hockey, editor, HUD) are out of scope; they only must not break.

## A team, not a duel
Each team has two arms with **separate file scopes**. They build different parts of one picture:
- **Astra arm** (an Opus operator runs GPT 6.2 Astra through Codex): the **frame and the figure**: sky, clouds, sun,
  light, shadows, grade, post, lens and sharpness, and the character. Last night Astra led the frame, and the owner
  preferred Astra's figure.
- **Fable arm** (Fable 5.2 builds directly): **the world's surfaces and nature**: ground, terrain, road, bluffs, rocks,
  trees, bushes, grass, water, timber and props, the material model. Last night Fable led surfaces.

Each arm works in its own worktree. The Director merges the team's two arms into one integration branch at
**13:30, 16:30 and 19:45**, exports a playable exe, takes the shot set, and sends both arms the integrated stills. After
each integration the Director merges the integration branch back into your branch: you then continue from the joined
tree (your partner's work is in it). Between integrations, what you need from your partner goes into
`lanes/<arm>/PATCHES.md` and the Director passes it on.

## The base you start from
- `dio` arms: branch `d20-dio` = last night's `diorama-combined` (frame Astra, surfaces Fable) with the character
  swapped to Astra's clay figure (`diorama-character-astra`). Style file: `engine/style/style_diorama.json`
  (`TL_STYLE` unset or `diorama`).
- `cel` arms: branch `d20-cel` = the same code plus `engine/style/style_crisp.json`, a copy of today's `style.json`.
  Run with `TL_STYLE=crisp`. Every diorama feature is behind style keys (an absent key means today's behaviour), so
  the cel team may switch on any of them (the seamless sky, contact shade, the material model, the clay figure) when
  it serves crisp cel, or build its own.
- `TL_STYLE=classic` is today's look and the comparison for both.

## Rules that keep new games as fast to make as today (hard; same as last night)
1. **No pack or seed changes.** No file under `engine/packs/**` or `engine/seeds/**` changes; the kernel keeps every v1
   signature (`tl arch` api-v1). A new palette key only in addition, never a rename or reorder (kit hashes depend on
   palette columns).
2. **Today's look stays exact:** `TL_STYLE=classic` renders as today (same shot before and after: identical or within
   1/255). Put your look behind keys in your team's style file, where an absent key means today's behaviour, or behind
   new shader files or variants.
3. **No game's state hash moves:** `node devx/bin/tl.mjs check --tier full --only world,packs` PASS, world 8/8, the
   hashes as on your base. The look is presentation only.
4. **Cache keys:** a change to a geometry generator (kit, terrain, crowns) bumps `PIC_VERSION`
   (`engine/kernel/world/draw/draw_base.gd`). Only the Fable arm bumps it.
5. **Performance:** report a windowed GPU figure (`node devx/bin/tl.mjs perf run`; say `busy` when other lanes load the
   machine). Today buys fidelity: a cost up to 2x today's GPU frame is acceptable if the picture earns it; say what
   each big feature costs. Name anything that costs per new game.
6. **Style file seams:** your team shares one style file. Add keys only inside the sections your scope owns (below);
   never reorder or reformat the other arm's sections. That keeps the Director's merge clean.

## Sharpness (both teams; the owner's first complaint)
The owner called the diorama "blurry". Before you add detail, make the picture crisp at 1920x1080:
- the subject, the near ground and the mid-distance read sharp; any lens blur is a gentle accent at the far edge;
- textures are not smeared (texture resolution, mipmaps and filtering, anisotropy);
- edges are clean (MSAA, a sharpening pass if it helps, render scale 1.0).
Measure it: a sharpness figure (e.g. the variance of a Laplacian over fixed crops of the same shot) before and after.

## The loop (10 hours): rounds, not one big build
Work in rounds of about 60-90 minutes. Each round:
1. Pick the biggest gap between your shots and the board.
2. Build it.
3. Take the shots, put them beside the board, and judge by eye.
4. Write a standup line. Then pick the next gap.

The integration notes from the Director carry the owner's own words when the owner plays the exe; act on them first.
Never stop early while time remains: the owner wants the time used fully. When the board's list is done, raise
fidelity further (geometry detail, materials, light quality, motion).

## The shot set (yours to take each round; the Director takes it at each integration)
Take each shot under your team's style, and once at the start and end under `classic` as well.
- **The village from the road and from above:**
  `bash engine/tools/world.sh tour docs/shifts/2026-11-19-day/lanes/blend/blend_views.walk.json --pictures-only --load=block --out-dir=<abs dir>`
  (the board shot is `07_parkour_road`; `01_walker_road` and `13_lot_river_road` show nature and the river).
- **The flight over the bluff:** `docs/shifts/2026-11-19-day/lanes/flight/wf_flight.json` with `clip.devices.json`
  (the flight lane's report says how).
- **A character close-up** from `engine/rigs/review/review.tscn`, front and back.
- **A clip** of 30 s or less, windowed: walking the village road to the river, then flying over the bluff.
Commit only JPG stills, a `contact-sheet.jpg` (your best frames beside the board) and `clip.mp4` in your lane folder.
Raw captures stay under `.tl/`.

## Deliverables (in `docs/shifts/2026-11-20-day/lanes/<arm>/`)
- `STANDUP.md` (lane rules below), stills, contact sheet, clip.
- `REPORT.txt` plus the same report as your final message at the hard stop: what you built and why it moves toward the
  board; the rules above, each with its evidence; the gates; the changed files; `PATCHES.md`; an honest "what still
  falls short of the board"; the cost per new game, if your scope changed it.

## Gates (before each integration and before `done`)
- `node devx/bin/tl.mjs check --tier fast`.
- `node devx/bin/tl.mjs check --tier full --only world,packs,kit.selftest`.
- `bash engine/tools/selftest.sh style.`, `bash engine/tools/selftest.sh rig.` (Astra arm), and your own block.
  The packs step's hockey `invariants.many_budget` is a wall-clock check that fails on a loaded machine: re-run it
  alone, or A/B it against your base, before calling it a regression. Perf may say NOT RUN when the machine is busy;
  say so, it is not a pass.

## Time
- Start about 10:50. Standups by the Director at :07 every hour.
- Integrations at 13:30, 16:30 and 19:45: by then your tree is in a clean, working state with a standup line that says
  `ready` and your gates' last lines. Send the Director a message `ready for integration` too.
- **Hard stop 19:45:** clean tree, gates, `REPORT.txt`, final message, last standup line `done`.
- Verdict at about 20:45: one page with both looks side by side, both exes, and the owner's choice.

## Machine
Four arms and the Director share one machine and **one window lock**: windowed captures wait for it. Do headless work
while you wait. Keep raw captures under `.tl/`. Never kill a process you did not start.
# Lane rules (pasted verbatim into every lane brief)

## Standups: you report, the Director reads
- Keep `docs/shifts/2026-11-20-day/lanes/<arm>/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
