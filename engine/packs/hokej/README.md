# Hokej: the gym (stair step 1)

The new hockey is a 1:1 port of thirdjam (`docs/design/DIRECTIONS.md`). This pack is step 1, the gym: one skater on
thirdjam's empty regular rink (90 x 45 m) under thirdjam's follow camera, through thirdjam's keys and mouse. Nothing of
`engine/packs/hockey` is used. Play it with `tl play hokej`.

| Key | Does (thirdjam `FJamBindings::Defaults`, InputMapping.cpp:98-119) |
|---|---|
| W A S D (or the arrows) | skate, camera-relative: W is away from the camera; while S is held its direction stays the camera's of the moment you pressed it (HokejGameMode.cpp:937-958) |
| Shift | sprint |
| Ctrl | brake |
| the mouse | the stick points at the cursor's spot on the ice (inside 0.7 m of the skater: held ahead; HokejGameMode.cpp:756-767); a still hand on a standing skater keeps its point (thirdjam's aim anchor, InputMapping.cpp:1113-1127) |

| File | What |
|---|---|
| `scripts/cam.gd` | `UJamFollowCamera::StepThirdPerson` ported line by line, as the shipped game runs it (boards view on); checked frame by frame against thirdjam's own code compiled from its source (`docs/shifts/2026-11-24-night/lanes/K3-shell/oracle/`) |
| `scripts/controls.gd` | the key and mouse mapping |
| `scripts/skate_standin.gd` | **STAND-IN** for lane K1's rink core: thirdjam's skating law (free skater) and its boards and nets |
| `gen/tj_rink.gd` | the rink (`RinkActor`'s outline, boards, kick plate, markings; the goals as thirdjam's arena meshes; `docs/shifts/2026-11-24-night/lanes/K3-shell/RINK.md`), a plain dark hall round it, and the **STAND-IN** 1.64 m capsule until lane K2's figure |
| `data/hockey.regular.cartridge.json` | thirdjam's regular cartridge, verbatim |
| `tests/bot_gym_hand.gd` | the scripted hand (`data/hand_gym.json`); its result carries the per-frame camera trace |
| `tests/bot_rule_*.gd` | one rule each: W away from the camera, the S lock, the aim's dead zone, hysteresis and size ramp, the aim anchor |
| `tests/bot_tj_replay.gd`, `data/tj_trace_regular_pro.json` | thirdjam's own rendered match (its JAMCAM log): its skater's path through our camera, every pose against thirdjam's |
