# K5 screen: thirdjam's HUD and match flow on our screen

Campaign night of 23-24 Nov 2026. Worktree `C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-hud` (branch `hk-hud`,
cut from the campaign branch `hokej`). Route: Opus solo. Rounds of 60-90 minutes.

## Goal
Step 5 of the stair in `docs/design/DIRECTIONS.md`, the screen. thirdjam's whole match already runs in our engine from
its own simulation (`engine/cores/rink`, the `RinkCore` class and `SNAPSHOT.md`) inside the thin pack
`engine/packs/hokej`, drawn with stand-in capsules under thirdjam's camera (look at
`docs/shifts/2026-11-24-night/lanes/K3-shell/r3_sbs_sheet_a.jpg`: thirdjam left, ours right). What a player reads the
game through is missing entirely. Port thirdjam's screen furniture and match flow **as it is**: same elements, same
places, same sizes, same words, same rules for when each shows. The owner ruled on much of this in thirdjam (see
`docs/research/hockey-teardown/RULINGS.md`: e.g. nothing technical is ever drawn on or in front of a skater); the shipped
HEAD state already obeys his rulings, so the shipped state is the target.

## What is known (scouted; verify; `S` = `Game/Source` in the thirdjam clone)
- Code: `S/JamGame/.../HUDWidget.cpp` / `.h` (2,042 / 1,191 lines) plus about 20 `HUD*.cpp` files, `RadarWidget.h`,
  `MenuWidget` (2,898 lines, the `Menu` map), the commentary captions (`CommentarySystem.cpp`;
  `Plugins/JamAssets/Content/Audio/VO/commentary.json`, 415 lines of text with their triggers).
- Elements: score plates with "FIRST TO 3" / period, TAKE n and a timer (`HUDWidget.cpp:431-451`); the net distance tag
  ("42 m", "OWN n M", `HUDWidget.h:1184`); rings on the ice: yours 1.1 m, the carrier's 0.8 m, x1.25 double ring while
  you carry, the loose puck's 0.42 m (`h:506-508, 789-790`); the YOU marker 48 px and the chevron over your skater; the
  radar 200 x 100 px bottom right; the controls panel bottom left (300 px wide, up to 8 rows) and the context hints
  ("LMB CROSS-CHECK  RMB CHECK", changing with possession); the shot line on the ice 1.5 -> 4.5 m (`h:636-637`), the
  charge bar under the skater, the pass meter; the faceoff countdown dial ("2 HOLD", "press shoot at the drop, not
  before"); the MATCH 1 card; caption lines of the commentator ("Orange playing keep-away."); the GOAL banner; the end
  card YOU WIN / BEATEN after 1.9 s; IN THE BOX n; the fade from black at the start.
- Match flow: first to 3 (or a timer mode in thirds), a 120-frame pause after each goal, R restarts, Esc pauses; the
  menu (level, mode) before a match.
- Our engine: `TLHud` has labels, score, clock, tags over 3D nodes, plates, instruments; **no** minimap, no graphical
  bar, no ground ring (the old hockey pack built rings in its `gen/`). Missing widgets are kernel gaps: add them to the
  kernel's HUD API (small, general: a ring / decal on the ground, a bar, a radar panel, a banner), with
  `engine/kernel/API.md`, rather than drawing around the API in the pack.
- The 15 Nov runnable build's HUD is older than HEAD (HEAD adds the controls panel, the one-look HUD, `HUDFaults`):
  HEAD's source is the target; the film is only a guide. The build can be run for pictures (campaign rules).

## Rounds
1. **The inventory and the in-play HUD.** `HUD.md` in your lane folder: every element (what, when it shows, where, size,
   colour, text, thirdjam file:line, the snapshot fields or events it reads). Then build the in-play set: score plates,
   rings, YOU marker and chevron, net distance tag, context hints and the controls panel, radar, shot line, charge bar,
   pass meter. Side-by-side stills with thirdjam at the same moments; LOOK and list what differs.
2. **The flow.** Fade in, the MATCH card, the faceoff dial and its rule, GOAL banner and the pause, the end card, pause
   and restart, IN THE BOX; the commentator's caption lines (text only; the voice is lane K6's) with their triggers.
3. **The menu** (level and mode before a match) and the first 30 seconds as a newcomer meets them, beside thirdjam's.

## Acceptance
- Every element of `HUD.md` is built or listed as not yet, none invented, each citing its source.
- Positions and sizes at 1280 x 720 and 1920 x 1080 match thirdjam's layout rules (a table: element, thirdjam, ours).
- The rules for showing (possession-dependent hints, the dial, banners) are tested headless from recorded snapshots.
- Your eye's list from side-by-side stills at six moments (faceoff, carrying, defending, a goal, the end card, pause).
- hokej lint, smoke, bots pass; `node devx/bin/tl.mjs check --tier fast` passes.

## Scope
Write: `engine/packs/hokej/scripts/hud/**` and its data, the pack's wiring lines for it (`main.gd` belongs to lane K3:
add one call site and say where), kernel HUD API additions (`engine/kernel/api/tl_hud*.gd`, `engine/style/hud/**` new
entries, `engine/kernel/API.md` as an appended section; do not regenerate `docs/generated`), selftest block 830-839,
`docs/shifts/2026-11-24-night/lanes/K5-hud/`. Not yours: the simulation, the camera, the figure, the arena, sound.

---

# Campaign rules (the hockey port; pasted into every lane brief, above the lane rules)

Read `docs/design/DIRECTIONS.md` first: the owner's words, what went wrong three times, the ten directions, the stair.

1. **Port, do not reinterpret.** thirdjam is the reference and we own its source. Every number and every rule you write
   cites its thirdjam file:line. You do not tune, simplify, "improve" or re-derive anything. Where our engine cannot carry
   a thing as thirdjam has it, the engine gains the missing piece (say which); the game is not bent. Every deviation from
   thirdjam, however small, goes in a `DEVIATIONS` list in your report with its reason.
2. **Sources.** thirdjam's final submitted source (HEAD 8dc713c6, the game the owner knows):
   `C:/Users/kazda/kiro/third-life/.claude/worktrees/n23-teardown/.tl/thirdjam` (read-only; `Game/Source` is "S" below).
   The older 15 Nov source tree that the runnable editor build was made from: `C:/t/t5` (read-only). The runnable build
   (UE 5.9 editor binaries + content, 4.5 GB): `C:/Users/kazda/kiro/third-life/.claude/worktrees/n23-teardown/.tl/tj-run/Game`
   (read-only: run it in place with `-Multiprocess` and your own `-abslog=` and output folders, or copy it into your
   tree's `.tl/` if you must change it). UE 5.9 is at `C:/Program Files/Epic Games/UE_5.9`. How earlier lanes ran it:
   `docs/research/hockey-teardown/TEARDOWN.md` section 1 and `BEHAVIOUR-HAND.md` "How it was measured".
3. **Look, every round.** Before each standup line, put your own rendered frames beside the reference's frames of the
   same moment (same camera, same scene), LOOK at them yourself (read the image files), and write what your eye rejects.
   A defect you can see is not landable. Film is not the judge of play (the owner: "the pictures will not uncover core
   problem which is the gameplay itself in speed and balancing of skill mechanisms"); it is the judge of defects.
4. **Play is judged by play.** Where your lane touches how the game answers a hand, the proof is the same scripted hand
   through the same inputs in both games, compared frame by frame, never a number chosen by you.
5. **The machine is shared and tight** (about 15 GB of RAM free, other sessions run Godot). One Unreal process at a time
   per lane, closed as soon as it has done its job; never kill a process you did not start; Godot `--headless` unless you
   need a picture. Raw captures stay under your tree's `.tl/` and are deleted when their sheets exist.
6. **Module homes** (Director's ruling for this campaign; contracts follow at landing): the game core lives in
   `engine/cores/rink/` (a new engine module: a core may use the kernel API, kits, rigs and style; packs reach it through
   one kernel entry); the skater figure lives in `engine/rigs/skater/` with its imported mesh and clips beside it; the
   new game's pack is `engine/packs/hokej/` (thin: a cartridge and glue). The old `engine/packs/hockey` is not touched.
   If `tl arch`, the lint or the asset rules reject these homes, change the rule tables under `devx/` or
   `engine/kernel/runner/lint.gd` minimally, and list every such edit in your report (the Director words the contracts).
7. **Rounds.** Work in rounds of 60-90 minutes. At the end of each: standup line, your frames looked at, a short
   `ROUND-<n>.md` in your lane folder (what stands, what your eye rejects, deviations, next). When a round is worth
   landing, write "landable round n" in STANDUP.md, stop editing, and return your report as your final message; the
   Director lands it on the campaign branch `hokej` and sends you on.

---

# Lane rules (pasted verbatim into every lane brief)

## Standups: you report, the Director reads
- Keep `docs/shifts/2026-11-24-night/lanes/K5-hud/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
