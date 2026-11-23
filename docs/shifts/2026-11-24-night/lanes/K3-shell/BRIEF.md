# K3 shell: the gym. thirdjam's rink, camera and controls, one skater on empty ice

Campaign night of 23-24 Nov 2026. Worktree `C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-shell` (branch
`hk-shell`). Route: Opus solo. Rounds of 60-90 minutes.

## Goal
Direction 6 of `docs/design/DIRECTIONS.md`: character, camera, controls first, alone in a gym. A new thin pack
`engine/packs/hokej` in which one skater moves on thirdjam's regular rink under thirdjam's camera through thirdjam's
key and mouse mapping, so that the same scripted hand gives the same picture as thirdjam, frame for frame. Nothing else:
no puck play, no bots, no HUD beyond what the camera needs. This is step 1 of the stair; the whole game is built on it.

Our current hockey is another game (look at `docs/research/hockey-teardown/media/sheet_ours_pro_regular.jpg` beside
`sheet_thirdjam_pro_regular.jpg`): a camera high above 4.4 m toy figures on 60 m, against a camera 6 m behind a
life-size skater on 90 m. Nothing of `engine/packs/hockey` is reused or touched.

## What is known (scouted; verify as you go; `S` = `Game/Source` in the thirdjam clone)
- **Camera**: `UJamFollowCamera` (`S/JamGame/Public/CameraFollow.h:19-252, 332`; the per-frame step `StepThirdPerson`,
  `Private/CameraFollow.cpp:266`), stepped once per sim frame (60 Hz) and interpolated between frames. The rig comes
  from the cartridge (`Content/Cartridges/hockey.regular.cartridge.json:249-257`): distance 6 m, height 3.5 m,
  look-ahead 5 m, horizontal FOV 70 degrees, 0.7 m right of the skater's axis, pitch -atan(3.5/11) = -17.65 degrees
  (`cpp:167`), lag 4 frames (each frame 1 - e^(-1/4) = 0.221 of the way, `cpp:102-125`), other springs critically damped
  at 8 frames (`h:193`). Yaw follows the skater's facing through that lag; the mouse never turns the camera. Live
  defaults `cpp:39-77` (RigYaw 1, KeepHuman 0.31, KeepNoYaw 2, CornerLift 3 m, far-net bias 0.2, the boards view on:
  0.8 m inside the boards, down to 2 m near them, pitch cap 55 degrees). A jump over 5 m snaps. No change on sprint.
  Hit punch, knockdown kick and the 3-frame hit-stop exist (`h:414-430`; `JamPawns.cpp:144`) but belong to step 3.
- **Keys** are camera-relative: W = away from the camera (`S/JamGame/.../HokejGameMode.cpp:937-958`); while S is held
  its direction is locked to the camera yaw at the moment the pull began. **Mouse aim**: the cursor is projected onto
  the ice and the stick points from the skater to that point (`HokejGameMode.cpp:741-767`): dead zone 0.7 m entering,
  0.5 m leaving; stick size 0.5 -> 1 over 0.5-3 m. Full input map: `InputMapping.cpp:104-118`, `docs/PLAY-ME.md:72-90`
  (WASD skate, mouse aim, Shift sprint, Ctrl or S against your motion brake, ...).
- **Pawn**: `AJamSkater::ApplySimFrame` (`S/JamCore/Private/JamPawns.cpp:464`) turns a sim frame into the drawn skater
  (interpolation between 60 Hz frames; `UpdateMotion` :696, `SetStickAim` :723).
- **Rink**: built in code by `RinkActor` (`RinkActor.h:1-30, 59-170`; markings `RinkActor.cpp:599-646`): 90 x 45 m,
  corners 3.75 m, boards 1.2 m with 0.9 m glass, boards 0.2 m thick, kick plate 0.25 m, stanchions every 3.6 m; goals
  4 x 0.61 m, 1.5 m deep, at x = +-41 m; blue lines at +-L/6, 30 cm wide; centre circle r 4.5 m; faceoff circles r 4.5 m
  at x = +-(goal line - 6), y = +-min(7, 0.3 x width); dots 1.5 m inside the blue lines; crease a 1.8 m half disc.
- **Our engine** (scouted): a pack may place a free camera every frame through `ctx.cameras.add_view(name, pos, target,
  fov)` (the duel pack re-calls it each tick: `engine/packs/duel/scripts/show.gd:183-234`); a pack may run plain-data
  motion and write node transforms (all state in `_pack_state`); the cursor on the ground is `ctx.input.declare_aim` /
  `aim`; the kit has a `rink` part (length to 120, width to 60, boards, glass, shader markings, goals) and `stands`
  (`engine/kits/KIT.md:129-169`). The hokej pack is dungeon-only (not placed in the village: 90 m does not fit its plot).
- **The simulation** is lane K1's: thirdjam's own C++ compiled into the engine, reached through a core in
  `engine/cores/rink/`, its interface published as `engine/cores/rink/SNAPSHOT.md` during K1's second round. **Until it
  exists, drive the gym from the frame-exact port of thirdjam's skating law that already reproduces the build's own
  timings**: `docs/research/hockey-teardown/probes/hand_tj_skate.mjs` (a port of `UJamSim::StepSkater`,
  `JamSim.cpp:1266-1478`, free-skater path). Put it behind a small interface (`step(input) -> skater state`) shaped like
  thirdjam's input and skater structs, so K1's core replaces it by a swap. It is a stand-in, marked as such.
- **The figure** is lane K2's (thirdjam's own skater mesh and clips, in `engine/rigs/skater/`, driven through an entry
  that mirrors `IJamSkaterVisual`). Until it exists, draw the skater as a plain 1.64 m stand-in (a capsule with a facing
  mark and a line for the stick aim); do not use the engine's walking figure.

## Rounds
1. **The rink and the camera.** The pack, the rink at thirdjam's dimensions and markings (use the kit part where its
   geometry equals `RinkActor`'s; name every measure that differs), the stand-in skater on the stand-in law, the camera
   ported from `CameraFollow` line by line (third-person path, boards view, corner lift, snap), the key and mouse
   mapping ported from `HokejGameMode`. Runs from `tl play hokej`.
2. **Side by side.** A scripted hand (a fixed list of key and cursor states per frame: start, sprint, hard turns both
   ways, brake, a lap along the boards and through a corner, a stop near the boards) through both games: ours in a
   window with the movie writer; thirdjam's rendered build through its own script facility (`jam.ScriptHuman`,
   `jam.screen.StillEvery`, or what `S/JamGame` offers to feed fixed inputs; if thirdjam cannot be fed a fixed input
   list in the rendered game, say so, and compare the camera by feeding thirdjam's recorded skater path from its trace
   into our camera instead). Sheets of the same frames side by side; the camera's position, yaw and pitch per frame as
   numbers from both, with the first frame and size of any difference.
3. **Swap in the real things** as K1 and K2 publish them (the Director will tell you): the core for the stand-in law,
   the figure for the capsule.

## Acceptance (rounds 1-2)
- Rink measures equal thirdjam's (a table: measure, thirdjam file:line, ours).
- The camera's per-frame position, yaw and pitch through the scripted hand equal thirdjam's code path within 1 cm and
  0.1 degree (checked against a direct evaluation of thirdjam's formulas, and against its film by eye).
- Keys and aim behave as thirdjam's mapping says (each rule with its line; a headless test per rule: W away from the
  camera, the S lock, the aim dead zone and its hysteresis, the stick size ramp).
- Your eye's list of what differs from thirdjam's picture in the gym, with frames. The pack passes lint and smoke.

## Scope
Write: `engine/packs/hokej/**`, shared view code that belongs to the core under `engine/cores/rink/view/**` (camera,
pawn interpolation: K1 owns `engine/cores/rink/native/**` and `SNAPSHOT.md`), kit additions if `RinkActor`'s geometry
needs them (`engine/kits/**`, with KIT.md), rule-table edits per campaign rule 6, selftest block 820-829,
`docs/shifts/2026-11-24-night/lanes/K3-shell/`. Not yours: the simulation, the figure, `engine/packs/hockey`.

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
- Keep `docs/shifts/2026-11-24-night/lanes/K3-shell/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
