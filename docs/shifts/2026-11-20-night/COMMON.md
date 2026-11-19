# Night of 20 Nov: the toy-diorama duel (common part of every arm's brief)

## The owner's words, verbatim (19 Nov, 22:35 and 23:05)
"in last 7 days we got 2 best models in the world for working with 3D, animations and gaming: GPT 6.2 Astra, Fable 5.2.
... plan how to let them teamwork to improve graphical engine of the app and character, without sacrificing our ability
to create quality new content fast as today."
"Lets chase 4 (Toy diorama) tonight, based on the output we will decide tomorrow: a) If 4 suprerior we will discuss
whether to replace current theming b) If we struggle we stay and chase 2 as natural evolution of the current graphics".

## The target
- **The image:** `docs/shifts/2026-11-20-night/target/4-toy-diorama.jpg`, the same village repainted as a miniature
  handmade world.
- **The look:** clay and painted-plastic surfaces, felt foliage, a glossy resin river, wood-grain timber, soft contact
  shadows, warm raking light, tilt-shift depth of field.
- **The rules:** `docs/shifts/2026-11-20-night/target/NOTES.md`, section 4.
- **The cost of each style:** `target/CONTENT-COST.md`.
- **Today's look, for comparison:** `target/ref/`.

## How tonight works: a duel
Each pillar (frame, surfaces, character) is built twice, by two arms in two worktrees, from the same brief:
- **Astra arm:** an Opus operator runs GPT 6.2 Astra through Codex, and Astra designs alone.
- **Fable arm:** Fable 5.2 builds directly.

Neither arm sees the other's work. In the morning the owner picks the better arm per pillar from stills, clips and the
exe. At about 06:00 the Director merges the leading arm of each pillar into one combined build. So **stay inside your
pillar's files**: what you need from another pillar goes into `PATCHES.md` in your lane folder, not into its files.

## The base you start from
Branch `diorama-base`, which is main 6e060d2 plus two commits:
- **The style switch:** the style file is chosen by the environment variable `TL_STYLE`.
  - Unset or `diorama` loads `engine/style/style_diorama.json`. That is this branch's default, including in the exe.
  - `classic` loads today's `style.json`.
- **The diorama file:** `style_diorama.json` starts as a copy of today's.
- **Two tests:** `blend.pigment` runs under classic, and case 560 `style.switch`.

## Rules that keep new games as fast to make as today (hard)
1. **No pack file changes.** No file under `engine/packs/**` or `engine/seeds/**` changes, and the kernel API keeps
   every v1 signature (`tl arch` api-v1).
   - Games keep naming palette keys.
   - A new palette key is allowed only in addition to the existing ones, never as a rename or reorder: kit hashes
     depend on palette columns.
2. **Today's look stays exact.** `TL_STYLE=classic` must render exactly as today. Put diorama behaviour behind keys in
   `style_diorama.json`, where an absent key means today's behaviour, or behind new shader files or variants. Never
   change classic output.
   - **Proof:** the same shot under classic, before and after your work, is identical or within 1/255.
3. **No game's state hash moves.**
   - `node devx/bin/tl.mjs check --tier full --only world,packs` must PASS, with world 8/8 and the hashes as on
     `diorama-base`.
   - The look is presentation only.
4. **Cache keys:** a change to geometry generators (kit, terrain, crowns) bumps `PIC_VERSION`
   (`engine/kernel/world/draw/draw_base.gd`).
5. **Performance:** report a windowed GPU figure (`node devx/bin/tl.mjs perf run`) and say `busy` when other lanes
   load the machine. It decides nothing tonight, but a doubling is a finding.

## Deliverables of every arm (in `docs/shifts/2026-11-20-night/lanes/<pillar>-<astra|fable>/`)
1. **The fixed shot set**, the same for all six arms, each shot taken twice: classic, then your diorama.
   - **The village from the road and from above**, through
     `bash engine/tools/world.sh tour docs/shifts/2026-11-19-day/lanes/blend/blend_views.walk.json --pictures-only --out-dir=<abs dir>`.
   - **The flight over the bluff**, through `docs/shifts/2026-11-19-day/lanes/flight/wf_flight.json` and
     `clip.devices.json` (the flight lane's report says how).
   - **A parkour run and the hockey rink**, as in `docs/shifts/2026-11-19-evening/lanes/hud/REPORT.md`.
   - **A character close-up** from `engine/rigs/review/review.tscn`.
   - Commit only JPG and a `contact-sheet.jpg`: the classic and diorama pairs, plus the target board beside your best
     village frame.
2. **A windowed clip** of 30 s or less (`clip.mp4`): walking the village road into the parkour yard, then flying over
   the bluff.
3. **An exe**, if your gates are green:
   `bash engine/tools/export.sh --commit <text> --out C:/Users/kazda/kiro/third-life/dist/arms/<pillar>-<arm>/ThirdLife`
   then `export.sh check --out <same>`.
4. **`REPORT.txt` plus the same report as your final message:**
   - what you built and why it reads as diorama;
   - the rules above, each with its evidence;
   - the gates;
   - the changed files;
   - `PATCHES.md` (what another pillar should do);
   - an honest "what still does not read as diorama";
   - the cost per new game, if your pillar changed it.

## Gates before `done`
- `node devx/bin/tl.mjs check --tier fast`.
- `node devx/bin/tl.mjs check --tier full --only world,packs,kit.selftest`.
- `bash engine/tools/selftest.sh style.` and your own block.
- `bash engine/tools/selftest.sh rig.` (character pillar), and the full tier if time allows. Note: `perf` and
  `item`/`ui` may report NOT RUN or skip in a worktree. Say so; it is not a pass.

## Time
- **Start:** about 23:45.
- **Standup lines:** at least hourly, in your `STANDUP.md`.
- **Hard stop:** 05:45. Then make sure your worktree is in a clean, working state, write the report, and send the
  Director `done` (or `cut` with what works).
- The Director combines at 06:00. The verdict is at 07:15.
# Lane rules (pasted verbatim into every lane brief)

## Standups: you report, the Director reads
- Keep `docs/shifts/<shift>/lanes/<lane>/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
