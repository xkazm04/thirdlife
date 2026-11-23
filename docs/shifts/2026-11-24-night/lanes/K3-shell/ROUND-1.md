# K3 shell, round 1: the rink and the camera

## What stands
- `engine/packs/hokej` (new house pack `game.hokej` 0.1.0, kernelApi 1.16): thirdjam's regular rink, one stand-in skater on
  the stand-in law, thirdjam's camera and controls. `tl play hokej` opens it (launched, no errors; not played by a person).
- The camera (`scripts/cam.gd`) is `StepThirdPerson` line by line in the shipped game's settings (boards view, rig yaw,
  far-net lead, every spring). **Checked against thirdjam's own code**: `oracle/make_oracle.sh` copies the camera's lines
  verbatim from thirdjam's source (CameraFollow.h:11-330, 355-403; CameraFollow.cpp:80-134, 167-871, 934-958, 978-985;
  HUDFeed.cpp:8-12) and compiles them with clang against a 150-line Unreal shim; `oracle/compare_trace.mjs` feeds it the
  skater path of our scripted hand and compares frame by frame. Result over the 1561 frames of `bot_gym_hand` (the boards
  view acting on 730 of them): max 0.09 mm of position, 0.06 mm of height, 0.0003 degree of pitch, 0.0001 of yaw (the
  acceptance: 1 cm, 0.1 degree). Negative control: the same oracle on a 120 x 60 rink differs on 991 frames (first 272).
  Numbers: `r1_camera_vs_thirdjam.csv`.
- Controls: four headless tests, all PASS: W away from the camera (300 frames, error 0), the S lock (move on the lock to 0
  while the camera turned 180 degrees; a new pull relocks), the aim (12 of 12 steps: enter 0.7, hold to 0.5, size ramp).
- Rink: `RINK.md`, every measure with its thirdjam line; markings and nets from RinkActor's numbers.

## What my eye rejects (r1_sheet_gym_hand.jpg against docs/research/hockey-teardown/media/sheet_thirdjam_pro_regular.jpg)
1. The world beyond the boards is the style's sky and grass: thirdjam is an indoor arena (stands, roof, dark). It reads as
   an outdoor pond. Stair step 5 (the arena); every still.
2. The ice is warm cream with a sun glare (f300, f1300, f1500); thirdjam's is cool blue-white and even. The look's.
3. Boards: grey cap, red kick plate; thirdjam white boards, a yellow kick plate, a dark rail and glass. No glass (DEVIATION 1).
4. The figure is a capsule (stand-in until K2).
5. f500 (the S pull-back) the skater fills the lower left close to the lens; at the end boards (frame 480 of the first
   set) he sits at the frame's left edge. thirdjam's own code gives the same poses (oracle), so this is its camera on this
   path; to be held against its film in round 2.
Fixed this round on sight: a glass sheen stripe across the skater at the end boards (frame 1380: glass taken out); the
nets read as solid crates (frames 920, 1380: netting now cords).

## Deviations
See REPORT.txt (DEVIATIONS 1-12).

## Next
Round 2: the same hand side by side with thirdjam's rendered build (its `jam.camera.Log` trace fed to our camera, same
frames, sheets, numbers). Round 3: K1's core for the stand-in law, K2's figure for the capsule.
