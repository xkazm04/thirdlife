# K3 shell, round 2: side by side with thirdjam's film

## The film run (one Unreal process, closed by its timeout)
`film/run_tj.sh 220`: the t5 build in place (`n23-teardown/.tl/tj-run`, H39-H44), `/Game/Maps/Rink?level=pro`, cut
`hockey.regular`, 1280 x 720, `-ExecCmds="jam.ScriptHuman 2, jam.screen.StillEvery 30, jam.camera.Log 1"` (its own measured
hand), own `-abslog`. 9,465 JAMCAM lines (sim frames 1 to 9,513; the 48 frames missing are hit-stops, during which
thirdjam holds the presentation frame, HokejGameMode.cpp:1708), 317 stills (moved out of its Saved/Screenshots into my
`.tl/tj/stills`), 18 JAMKICK lines. thirdjam has no way to feed its rendered game a fixed input list (only its scripts and
drills), so this is the brief's fallback: its skater's path, logged per frame, fed to our camera.
`film/jamcam_to_trace.py` turns the log into `engine/packs/hokej/data/tj_trace_regular_pro.json`.

## Numbers: our camera = thirdjam's rendered camera
`tests/bot_tj_replay.gd` (in the pack's tests: the gate runs it): the pack, given the action `replay` on frame 0, sets
the skater from each logged row and steps our camera once a row. **9,329 of 9,465 camera steps checked, 1,672 of them
with the boards view acting: worst 0.54 cm of position, 0.22 cm of height, 0.097 degree of pitch, 0.004 of yaw; none over
1 cm / 0.1 degree.** The other 136 rows are inside thirdjam's contact kicks (the log's JAMKICK lines: camera kick and
stumble kick, CameraFollow.cpp:1269-1287, stair step 3, not ported), counted apart. The residue is the log's own
rounding (positions to 1 cm, yaws to 0.01 degree). The same path through the oracle (thirdjam's code compiled) agrees with
the log likewise (9,273 rows outside hit-stop windows, over 1 cm only on 11 rows, the two stumble kicks at 4507 and 8791 that hold no hit-stop; else within 1 cm and 0.1 degree).
So the shipped build's live camera settings are the ones ported (no ini or code override exists; `grep` of its Config).

## Sheets (looked at)
`r2_sbs_film.jpg`: eight film frames, thirdjam's still left, ours (same frame, same path, our camera) right.
- **The two poses my eye questioned in round 1 stand.** The S pull-back's skater huge at the bottom (our gym frame 500):
  thirdjam frame 5970 is the same, his #7 filling the lower middle 1.6 m from the camera's foot. The back to the end
  boards with the skater at the frame's edge (our 480 / 840): thirdjam frames 1800 and 6420, the skater at the right
  edge against the boards, the camera dropped and tilted (pitch -41 and -35 degrees). Thirdjam's numbers and ours agree
  on those frames to the millimetre (above).
- Framing, horizon, where the boards and the far net sit: the same in all eight pairs.
- **The goal**: thirdjam's film shows a low, wide red cage with white cords (frames 6480, 8670): it draws exactly the
  sim's 4 x 0.61 m opening (arena.py goal_build; RinkActor picks the 4 x 0.61 variant). Ours is now built from arena.py's
  numbers (16 cm posts and crossbar, 11 cm low bars and braces, 1.5 m deep, 0.37 m back frame, 3 cm cords in 25 cm cells).
  The low cage is thirdjam's own goal.

## The look (the Director's order, no art)
A plain dark hall round the rink (walls and a ceiling, `data/gym.json` `hall`), white boards with the yellow kick plate
(RinkActor's own outline and measures, drawn by us now), the ice without sun glare and without the warm cream: cool and even.
`r2_sheet_gym_hand.jpg` is the scripted hand in it.
What my eye still rejects against the film:
1. The ice is light blue (median sRGB 129, 169, 209); thirdjam's is a mauve grey (158, 140, 150). Under the ceiling the
   style's sun is in shadow and the style's cel shade colours the ice; a pack may not make a light (law), and a light of a
   kit part over the ice (tried in `.tl/exp`, a downward directional light) turns the toon ice white at any energy. The
   overhead rig of thirdjam's levels is binary (`LR_P3_Clay`). Needs the style: an indoor light setting (question 1).
2. No glass, rail, stanchions or emissive trim on the boards; no arena (stands, roof lights): stair step 5.
3. The figure is the capsule (K2's to come); thirdjam's #7 skates crouched and reads a little smaller than the 1.64 m
   upright capsule.
4. No HUD (by design of the gym).

## Kernel API 1.17 (the Director's answer 2)
- `ctx.input.aim_pixel(action)`, `TLInput.NO_PIXEL`, `set_aim(action, point, pixel = NO_PIXEL)`: the cursor's pixel latched
  with the aim, recorded (`<aim>@p`, `@px`, `@py`), hashed from the first pixel. With it the aim anchor is ported as
  thirdjam has it (`controls.gd` anchor_step = FJamAimAnchor::Step, jam.ctrl.AimAnchor 1, speed 0.3), test
  `bot_rule_aim_anchor` (still pixel holds the offset through a "camera turn"; a moved pixel, a skating skater, no pixel
  re-project).
- `ctx.cameras.aspect()`: the window's width over height (16:9 headless); `main.gd` feeds it to the camera every frame as
  StepSimFrame does.
- The move's camera yaw of the last DRAWN frame: not given. The drawn pose depends on render timing; reading it would make
  a run's sim depend on the frame rate and break replay determinism (a record holds keys, not yaws). Kept: the last sim
  frame's yaw (thirdjam's own ScriptHumanCam reads the same), the one-frame deviation stays listed.
