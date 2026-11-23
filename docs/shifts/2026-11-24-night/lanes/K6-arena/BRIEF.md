# K6 arena and sound: thirdjam's hall, crowd, ice and audio in our engine

Campaign night of 23-24 Nov 2026. Worktree `C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-arena` (branch
`hk-arena`, cut from the campaign branch `hokej`). Route: Fable solo (a place is judged by eye and ear). Rounds of 60-90 min.

## Goal
Step 5 of the stair in `docs/design/DIRECTIONS.md`: the arena and the sound. thirdjam's whole match already runs in our
engine (the pack `engine/packs/hokej` on the core `engine/cores/rink`), on thirdjam's rink measures under its camera, in
a plain dark box with capsules (see `docs/shifts/2026-11-24-night/lanes/K3-shell/r3_sbs_sheet_a.jpg`: thirdjam left,
ours right). What stands around the ice and what a player hears decide how fast and how alive the game feels; both are
missing. Bring **thirdjam's own** arena and audio across, as lane K2 brought its skater (read
`docs/shifts/2026-11-24-night/lanes/K2-figure/ROUND-1.md` and `engine/tools/skater/`: one Unreal commandlet run of a
Python export on a copy of the runnable build with `PythonScriptPlugin` and `GLTFExporter` enabled, then a bake into
engine files, then thirdjam's own render side by side from the same cameras, numbers and eyes both).

## What is known (scouted; verify; paths in the thirdjam clone)
- The rink shell is built in code by `RinkActor` (`Game/Source/JamGame/.../RinkActor.h:1-30, 59-170`,
  `RinkActor.cpp:599-646`): boards 1.2 m with a 0.25 m kick plate, glass 0.9 m, stanchions every 3.6 m, goals, markings;
  lane K3 already built these measures in `engine/packs/hokej/gen/tj_rink.gd` (white boards, yellow kick plate, the
  goal from the arena script; no glass yet: the kit has no glass that does not glare).
- Assets: stands and crowd `BP_ArenaCrowd`; lights: the streamed rig levels `Rigs/LR_*.umap`; ice `M_Ice` /
  `MI_Ice_*` (under `Game/Plugins/JamAssets/Content/Arena`, `Rigs`, `Look`); benches and penalty boxes
  `Game/Content/Arena/SM_*`; the arena mesh comes from a Blender script in the repo (`tools/blender/arena.py`, which K3
  read for the goal). Reactions: the goal lamp flashes 108 frames, the net shakes 54, board caps rock 26 degrees on hard
  hits. thirdjam's own film: `docs/research/hockey-teardown/media/thirdjam_pro_regular.mp4`; lane K3's stills of the
  rendered build are under `C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-shell/.tl/`.
- Audio: `EffectsBinder` (`EffectsBinder.h:1-12`) plays `/JamAssets/Audio/MS_<event>` per game event (53 MetaSounds);
  music, the crowd bed and the skate loop start in `CommentarySystem.cpp:67-70, 922-938` (music 0.35 in play, 0.6 in
  pauses); sources: 81 effects, 22 crowd clips, one music loop, 415 commentator voice lines
  (`Plugins/JamAssets/Content/Audio/VO/commentary.json` holds their text and triggers). All generated with ElevenLabs
  on a paid plan with commercial use; the MetaSound graphs are the team's own. Unreal can export a `SoundWave` to wav
  from Python.
- Our engine: `TLAudio.play(preset, pos, db)` plays **synthesised presets only**, no audio files, no loops, no music,
  no bus volumes: a kernel gap. Add what is needed to the kernel's audio API (files owned by a core, one-shots at a
  position, loops with a volume the game sets, a music and a voice channel), documented in `engine/kernel/API.md` as an
  appended section. Lights: lane K3 added `TLStyleHall` (`engine/style/tl_style_hall.gd`), a style entry that turns the
  sun into a light from the roof; build on it for thirdjam's rig. Imported files live with the core:
  `engine/cores/rink/arena/` and `engine/cores/rink/audio/` (campaign rule 6).

## Rounds
1. **The hall (time box 2 hours to the first side-by-side).** Export the stands, the crowd, the benches and boxes, the
   glass and the light rig's numbers; bake; place them round K3's rink; thirdjam's ice material as closely as our
   renderer allows (colour, the sheen, the scratches), its lights. Side by side from the game camera at six spots
   (centre faceoff, both ends, a corner, along the boards, the far net from the neutral zone), thirdjam's film or stills
   beside ours. LOOK; write what your eye rejects. Cost per frame measured (the crowd especially).
2. **The sound.** Export every sound source to files (say total size; ogg where long), the event-to-sound table from
   `EffectsBinder` and the MetaSound graphs (which clip, variation, pitch and volume rules, distance), the crowd bed and
   its reactions, the skate loop and how speed drives it, music levels. The kernel audio additions. Wire the events from
   the core's snapshot events (`engine/cores/rink/SNAPSHOT.md`). A recording of a minute of our game's sound beside a
   minute of thirdjam's (it runs with sound if `-nosound` is left off); listen through the numbers you can take
   (loudness per second, event timing against frames) and say plainly that no ear but a person's has heard it.
3. **The voice and the reactions.** The commentator's lines with their triggers (text captions are lane K5's), the goal
   lamp, the net shake, the rocking board caps.

## Acceptance
- The hall in our engine is thirdjam's: same pieces in the same places (a table: piece, thirdjam source, ours), six
  side-by-side views looked at, your eye's list of what still differs.
- Every game event that makes a sound in thirdjam makes the same sound here at the same frame (a table from a recorded
  match: event, frame, clip), tested headless from recorded snapshots.
- Frame cost of the arena and crowd stated; files' total size stated (keep the arena under 40 MB and audio under 60 MB
  or say why not).
- The style's existing shaders are byte for byte unchanged (their pin tests pass); new files only.
- hokej lint, smoke, bots pass; `node devx/bin/tl.mjs check --tier fast` passes.

## Scope
Write: `engine/cores/rink/arena/**`, `engine/cores/rink/audio/**`, `engine/tools/arena/**`, kernel audio API additions
(`engine/kernel/api/tl_audio*.gd`, API.md appended section; do not regenerate `docs/generated`), style additions as new
files, the pack's wiring lines for the arena and sound (`engine/packs/hokej/scripts/main.gd` and `gen/tj_rink.gd` belong
to lane K3: add call sites only and say where), selftest block 840-849, `docs/shifts/2026-11-24-night/lanes/K6-arena/`.
Not yours: the simulation, the camera, the figure, the HUD and captions.

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
- Keep `docs/shifts/2026-11-24-night/lanes/K6-arena/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
