# Hokej: thirdjam's match, ported (stair steps 1-2)

The new hockey is a 1:1 port of thirdjam (`docs/design/DIRECTIONS.md`). Round 3: thirdjam's whole match runs here: its own
simulation and bots (lane K1's core, `ctx.cores.open("rink")`), the regular cartridge (5 v 5, first to 3), its camera, its
keys and mouse, ten stand-in figures (lane K2's figure to come). Nothing of `engine/packs/hockey` is used.
Play it with `tl play hokej` (the core must be built: `bash engine/tools/rink.sh build`; `engine/.godot/extension_list.cfg`
lists `res://cores/rink/rink_core.gdextension`). The level of the bots: `data/match.json`.

| Key | Does (thirdjam `FJamBindings::Defaults`, InputMapping.cpp:98-119; HokejGameMode.cpp:931-1000) |
|---|---|
| W A S D (or the arrows) | skate, camera-relative: W is away from the camera; while S is held its direction stays the camera's of the moment you pressed it |
| the mouse | the stick points at the cursor's spot on the ice (inside 0.7 m of the skater: held ahead); a still hand on a standing skater keeps its point |
| left button | with the puck: shoot (hold to charge, fires on release); without: cross-check (hold 13 frames: brace) |
| right button | with the puck: pass (hold: saucer); without: body check |
| Q | pass. Middle button, mouse 4: cross-check |
| Space, wheel, E, F | poke, deke, spin, ability |
| Shift, Ctrl | sprint, brake |
| R | a new match |
| 1-4 | team signals: not yet (they need the core's glue, lane K1) |

| File | What |
|---|---|
| `scripts/cam.gd` | `UJamFollowCamera::StepThirdPerson` ported line by line, as the shipped game runs it (boards view on); checked frame by frame against thirdjam's own code compiled from its source (`docs/shifts/2026-11-24-night/lanes/K3-shell/oracle/`) |
| `scripts/controls.gd` | the key and mouse mapping |
| `scripts/human_input.gd` | the devices in K1's raw shape, and (MOVES TO CORE GLUE) thirdjam's ReadHumanInput + button rules on them |
| `scripts/match_view.gd`, `scripts/hit_stop.gd` | the snapshot drawn with stand-ins; thirdjam's hit-stop (presentation) |
| `scripts/skate_standin.gd` | the gym's stand-in law (one skater, empty ice: the control rules' tests) |
| `gen/tj_rink.gd` | the rink (`RinkActor`'s outline, boards, kick plate, markings; the goals as thirdjam's arena meshes; `docs/shifts/2026-11-24-night/lanes/K3-shell/RINK.md`), a plain dark hall round it, and the **STAND-IN** 1.64 m capsule until lane K2's figure |
| `data/hockey.regular.cartridge.json` | thirdjam's regular cartridge, verbatim |
| `tests/bot_gym_hand.gd` | the scripted hand (`data/hand_gym.json`); its result carries the per-frame camera trace |
| `tests/bot_match_hand.gd` | a whole match through the keys (a scripted hand); its result carries the FJamInput stream and the core hash per frame |
| `tests/bot_rule_*.gd` | one rule each: W away from the camera, the S lock, the aim's dead zone, hysteresis and size ramp, the aim anchor |
| `tests/bot_tj_replay.gd`, `data/tj_trace_regular_pro.json` | thirdjam's own rendered match (its JAMCAM log): its skater's path through our camera, every pose against thirdjam's |
