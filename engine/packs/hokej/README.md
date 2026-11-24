# Hokej: thirdjam's match, ported (stair steps 1-2)

The new hockey is a 1:1 port of thirdjam (`docs/design/DIRECTIONS.md`). Round 3: thirdjam's whole match runs here: its own
simulation and bots (lane K1's core, `ctx.cores.open("rink")`), the regular cartridge (5 v 5, first to 3), its camera, its
keys and mouse, ten of thirdjam's own figures (lane K2: engine/rigs/skater through thirdjam's pawn, `ctx.cores.view_script("rink", "skater_pawn")`; shots, passes, checks and falls still play as skating). Nothing of `engine/packs/hockey` is used.
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
| 1-4 | team signals: defend, space, pass to me, praise (the brain reads them; one per second) |

| File | What |
|---|---|
| `scripts/cam.gd` | `UJamFollowCamera::StepThirdPerson` ported line by line, as the shipped game runs it (boards view on); checked frame by frame against thirdjam's own code compiled from its source (`docs/shifts/2026-11-24-night/lanes/K3-shell/oracle/`) |
| `scripts/human_input.gd` | the devices read into the core's raw shape; thirdjam's rules for them are the core's glue (engine/cores/rink/GAMEMODE.md) |
| `scripts/match_view.gd` | the snapshot drawn: one pawn and figure a skater fed its snapshot entry each frame, in thirdjam's order around lane K2's show object (`ctx.cores.view_script("rink", "skater_show")`: thirdjam's hit-stop picks and holds, the carrier the screen shows with the carried puck on the blade, the play calls) and its hit read (`hit_read`: the whiffs, the re-time of a check); the four bus events to every figure |
| `data/view.json` | `figures: false` draws the round-3 stand-ins instead (debugging; the match hash is the same) |
| `gen/tj_rink.gd` | the rink (`RinkActor`'s outline, boards, kick plate, markings; the goals as thirdjam's arena meshes; `docs/shifts/2026-11-24-night/lanes/K3-shell/RINK.md`), a plain dark hall round it (without lane K6's arena; with it only the marks the arena's ice does not paint, in thirdjam's colours, and the goals), thirdjam's puck (8 cm, AJamPuck) with its glowing disc on the ice (SM_PuckDisc's halo), and the round-3 **STAND-IN** (a 1.64 m capsule and a stick bar, `data/view.json` figures false) |
| `data/hockey.regular.cartridge.json` | thirdjam's regular cartridge, verbatim |
| `tests/bot_gym_hand.gd` | the scripted hand (`data/hand_gym.json`); its result carries the per-frame camera trace |
| `tests/bot_match_hand.gd` | a whole match through the keys (a scripted hand); its result carries the FJamInput stream and the core hash per frame |
| `tests/bot_first_match.gd` | the player's first match: PLAY NOW at ROOKIE (the level action on frame 0), the same hand to the final whistle, then the end card held 300 frames |
| `tests/bot_rule_*.gd` | one rule each: W away from the camera, the S lock, the aim's dead zone, hysteresis and size ramp, the aim anchor |
| `tests/bot_tj_replay.gd`, `data/tj_trace_regular_pro.json` | thirdjam's own rendered match (its JAMCAM log): its skater's path through our camera, every pose against thirdjam's |
