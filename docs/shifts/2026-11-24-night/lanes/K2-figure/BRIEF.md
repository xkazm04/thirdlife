# K2 figure: thirdjam's skater, in our engine, without a visible defect

Campaign night of 23-24 Nov 2026. Worktree `C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-figure` (branch
`hk-figure`). Route: Fable solo (a figure is judged by eye). Rounds of 60-90 minutes.

## The owner's words about our figure (23 Nov)
"players are deformed, stick buggy flying everywhere and below surface ... animations look unnatural and horrible". Of
thirdjam he said it has "bugless graphics".

## Why ours is what he says (scouted)
Our hockey figure is the engine's 2 m walking figure with a big head and hands (`engine/rigs`, biped, cel model), scaled
by hand to 4.4 m, skating on a stride that is a speed-clamped phase with no planted feet. Its stick is a rigid mesh on the
right-hand socket: nothing keeps the blade on the ice, hit and fall clips carry it with the wrist, and the puck is held at
another point about 1 m from the drawn blade. None of that is repaired. It is replaced.

## Goal
Direction 7 of `docs/design/DIRECTIONS.md`: the figure is a product of its own. Bring **thirdjam's own skater** into our
engine: its mesh, its skeleton, its clips, and the logic that plays them, and make a defect the eye would reject a failed
test.

## What is known (scouted; verify as you go)
- The shipped figure: `Game/Plugins/JamAssets/Content/Skaters/` in the thirdjam clone: `SK_SkaterTB1_P3.uasset`
  (12.0k triangles, 24 bones, sockets `stick_socket` / `puck_socket` / `head_socket`, nine material slots: Jersey Trim
  Helmet Gloves Skin Pads Skate Blade Stick), the AnimBlueprint `ABP_SkaterTB1_P3`, blend spaces
  `BS_SkaterTB1_P3_Aim`, `_Skate`, `_SkateReady`, and 202 clips `AS_SkaterTB1_P3_*` (stride, sprint, glide, leans,
  crossovers, stops, about 20 checks, cross-check hold / wind / whiff, about 40 get-ups, falls, lie loops, board hit /
  pin, shots, passes, poke, lift, faceoff, goalie, celebrations). **The stick is skinned into the mesh** (1.40 m grip
  to heel, 0.34 m blade). The figure is 1.637 m at rest. It is the team's own original work (Apache-2.0).
- How it is driven: gameplay talks to the figure only through the interface `IJamSkaterVisual`
  (`S/JamCore/Public/JamSkaterVisual.h`; the contract `contracts/skater-visual.md` in the clone), called each frame
  from `AJamSkater::ApplySimFrame` (`S/JamCore/Private/JamPawns.cpp:464`; `UpdateMotion` :696, `SetStickAim` :723).
  The shipped driver is a Blueprint graph (not readable as text); its rules are in the ledger: `ASSETS.md:1183`,
  `status/B4-report.md:23-24`, `status/B-skater-skf.md`, `status/B36-report.md`. States: Idle, Skate, Fall,
  FallForward, GetUp; the Skate blend space is speed 0-8 m/s by turn rate +-3 rad/s (glide below 1 m/s, full stride
  at 8, lean or crossover at +-3); the stick is an aim blend space over angles -63 / -46 / -30 / 0 / +35 / +70 degrees
  and reaches 1.00 / 1.30 / 1.45 / 1.60 m, the aim clamped to +-70 degrees, turning at most 15 degrees a frame, up to
  12 degrees of overshoot as stick yaw; the sim's blade is at 0.4 m + aim x 1.6 m from the skater; the carried puck
  is drawn on `puck_socket`. A C++ driver that poses clips by sim frame exists for the older toy figure
  (`SkeletalSkaterVisual.cpp`, 817 lines): the template for driving clips from the sim without a Blueprint.
- Team colours blue `#1D4ED8`, orange `#E8651A`; helmet tinted x0.5; jersey numbers (blue 7 / 13 / 42, orange 9 / 21 /
  88, slots 4-5 team x 10 + slot + 1; `HokejGameMode.cpp:439-444`).
- Export path (feasible, not yet tried): a COPY of the runnable build under your `.tl/`, with HEAD's
  `Plugins/JamAssets/Content/Skaters` put over it if it opens (HEAD has about 10 changed clips and adds
  `CrossCheck_Whiff`), `UnrealEditor-Cmd.exe` with `-EnablePlugins=PythonScriptPlugin,GLTFExporter` (both are in the
  engine install; the project has them off) and a Python script that exports the skeletal mesh and every clip. FBX is
  built in and keeps animation more reliably; Godot 4.7 imports glTF natively and FBX through its own importer.
  The Blender sources of this figure are not on this machine.
- Our engine: no skinned-glTF path for packs; a rig lives in `engine/rigs` and may reference nothing outside itself. So
  the mesh, skeleton and clips live in `engine/rigs/skater/` and are loaded by engine code (Godot's own importer,
  `AnimationTree` / `AnimationPlayer` are allowed in the engine, fenced only in packs). The look: our crisp cel style
  through `TLStyle` materials on the nine slots (ask `engine/style/STYLE.md`); if cel on this mesh looks wrong to your
  eye beside thirdjam's clay look, say so with both pictures rather than settling.

## Rounds
1. **Get it out and in (time box 2 hours).** Export mesh + skeleton + all clips; import in Godot; one skater standing
   on a flat ice plane in a gym scene, at 1.637 m, with a clip playing, filmed beside the same clip in thirdjam.
   If the export is blocked, STOP and report what blocks it (the fallback is the Director's decision).
2. **The driver.** `engine/rigs/skater/`: a `skater` figure with one entry that mirrors `IJamSkaterVisual` call for call
   (same names, same arguments, same units) so the game shell (lane K3) calls it exactly as thirdjam's pawn does. Inside:
   the state machine and blend spaces rebuilt from the ledger notes and from what the clips themselves show. A gym
   harness that drives it from scripted motion (speed ramps, turns at +-3 rad/s, stops, aim sweeps, every action clip,
   falls and get-ups) with no simulation needed. Lane K1 will publish `engine/cores/rink/SNAPSHOT.md` (the simulation's
   per-skater fields); when it exists, check that your entry can be fed from it and name what is missing.
3. **Defects as tests.** Per frame, on the posed skeleton, over the whole gym run: the blade's lowest point never under
   the ice and never more than a set height above it while the stick is "on ice"; skate blades on the ice in stride and
   glide; no bone length changes; no pose pop above a threshold between frames (angular velocity per joint); the stick
   never through its owner's legs or body; the puck socket on the blade. These run headless in the gate
   (selftest block 810-819). Then your eye: sheets at every 3rd frame for every state and transition, beside thirdjam's.
4. **Ten on the ice.** Ten skaters in two colours with numbers, cost per frame measured (posing counts toward the frame
   budget), a level-of-detail answer only if the cost needs it.

## Acceptance
- The figure in our engine is thirdjam's figure: same proportions and silhouette side by side at three angles, same
  clips at the same frames.
- Every driver rule cites its source (interface line, ledger line, or "read from clip <name>"); deviations listed.
- The defect tests are green on the gym run and red when you break the thing they guard (show one red each).
- Your own eye's list of what is still wrong, with frames. You judge it as the owner would: "bugless" is the bar.

## Scope
Write: `engine/rigs/skater/**` (asset files included; say their size; keep under 30 MB or say why not),
`engine/tools/` gym and export scripts, rule-table edits per campaign rule 6, selftest block 810-819,
`docs/shifts/2026-11-24-night/lanes/K2-figure/`. Not yours: the simulation (K1), camera / input / rink / HUD / pack (K3).

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
- Keep `docs/shifts/2026-11-24-night/lanes/K2-figure/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
