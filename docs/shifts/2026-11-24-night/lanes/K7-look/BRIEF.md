# K7 look: thirdjam's skater material (felt, number, crest, face) on our figure

Campaign night of 23-24 Nov 2026. Worktree `C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-look` (branch `hk-look`,
cut from the campaign branch `hokej`). Route: Fable solo (a surface is judged by eye). Rounds of 60-90 minutes.

## Goal
Direction 7 of `docs/design/DIRECTIONS.md`. thirdjam's own skater stands in our engine in thirdjam's own poses (lane K2:
`engine/rigs/skater/`, mesh, 24 bones, 202 clips, the driver and pawn; proven within 0.02 cm of thirdjam's figure).
What differs is the surface. Look at `docs/shifts/2026-11-24-night/lanes/K2-figure/media/r1_pair_Stride_turn.jpg`
(thirdjam above, ours below): thirdjam's figure is felt and clay (mottled, soft rim light), its jersey carries a number
on the back patch and a round crest on the chest, its face is two dots and a soft smile; ours is flat cel with a blank
patch, a heavy ink line on the face that reads as a moustache from the front, cream trim that turns grey-brown in shade,
and a highlight on the cheek that reads as a tear. The owner knows the felt figure. Parity first: **make ours read as
thirdjam's**, as closely as our renderer allows; keep the flat cel as a second selectable variant so he can see both.

## What is known
- K2 already fetched the jersey material's text and its six textures from Unreal and drafted (uncompiled) a number and
  crest shader: under `C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-figure/.tl/` (read-only for you: copy what
  you need into your own tree; ask K2's notes in `docs/shifts/2026-11-24-night/lanes/K2-figure/ROUND-2.md` and
  `REPORT-r2.md` where things are). K2's export tooling is `engine/tools/skater/` (`export_skater.py`,
  `reference_capture.py`: thirdjam's own render of a pose from the gym's four cameras; `pair_sheets.py`): your method
  for side-by-side proof. The figure's nine material slots: Jersey Trim Helmet Gloves Skin Pads Skate Blade Stick.
  Team colours blue `#1D4ED8`, orange `#E8651A`; helmet = team colour x 0.75 (from the shipped Blueprint); numbers
  blue 7 / 13 / 42, orange 9 / 21 / 88, slots 4-5 team x 10 + slot + 1 (`HokejGameMode.cpp:439-444`); material
  parameters `TeamColour`, `NumberTens`, `NumberOnes` (`JamSkaterVisual.h:18-26`).
- The colour reference is the RUNNING game, not the editor's light: lane K3's stills of the rendered build are under
  `C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-shell/.tl/`, the film is
  `docs/research/hockey-teardown/media/thirdjam_pro_regular.mp4`; lane K6 is porting thirdjam's hall light
  (`TLStyleHall`, `TLStyleArena`) in `hk-arena`: the figure must read right under the hall rig, at the game camera's
  distance (6 m behind, 3.5 m up) and at the far end of the rink, not only in a close-up.
- Our style: `engine/style/STYLE.md`. Existing shaders are pinned byte for byte by tests (the classic look): add NEW
  shader files and a new `TLStyle` entry; change no existing shader's bytes. Run the style pin blocks of the kernel
  selftest before "landable".

## Rounds
1. Number and crest on the jersey (per team, per slot), thirdjam's face, the trim and skin colours right in shade, the
   tear highlight gone. Pairs against thirdjam's own render at four angles and at game-camera distance.
2. The felt and clay surface (mottling, the soft rim, the stitching if thirdjam has it), under the hall light; ten
   skaters at the game camera; cost per frame. Both variants selectable; a sheet with both for the owner.

## Acceptance
- Side-by-side pairs (thirdjam's render above, ours below) at four angles close and at game distance, for blue and
  orange: LOOKED at by you, your eye's list of what still differs.
- Numbers and crest correct for all ten skaters of a match (a sheet).
- No existing shader byte changed (pin tests pass); the figure's cost per frame for ten skaters stated, not above
  K2's 2.0 ms by more than 0.5 ms.
- `node devx/bin/tl.mjs check --tier fast` passes.

## Scope
Write: new files under `engine/style/**` (shader, textures, the TLStyle entry), the material assignment in
`engine/rigs/skater/tl_rig_skater.gd` (lane K2 owns that file and is working in it on the driver: touch only the
material set-up function and say exactly which lines), textures beside the figure in `engine/rigs/skater/look/`,
selftest block 850-859, `docs/shifts/2026-11-24-night/lanes/K7-look/`. Not yours: the driver, the pawn, the arena light.

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
- Keep `docs/shifts/2026-11-24-night/lanes/K7-look/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
