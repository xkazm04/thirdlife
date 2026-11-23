# K3 shell, round 3: the whole match, from the real core, with stand-ins

## What stands
- **thirdjam's match in our engine.** `engine/packs/hokej` opens lane K1's RinkCore through `ctx.cores.open("rink",
  "hockey.regular.cartridge.json")` (the regular cartridge: 5 v 5, first to 3, faceoffs, goal pause, thirdjam's bots at
  `data/match.json` `difficulty` = pro), drives the human's skater from the keys and the mouse, draws ten stand-ins, the
  puck and the nets, and follows the human with the round-2 camera. `tl play hokej` starts it in a window.
- **The input, all of it.** `scripts/human_input.gd`: the devices into K1's raw shape (Unreal key names, Down / Pressed,
  Axis, cursor pixel and ice point, camera yaw; the half that stays in the shell), then, **marked MOVES TO CORE GLUE**, the
  pack's port of ReadHumanInput + ApplyButtons + FJamButtonResolver: the camera-relative move with the S lock, the cursor
  stick with the aim anchor, Shift sprint, Ctrl brake, LMB shoot with the puck / cross-check without (held = the brace),
  RMB pass (held = saucer) / body check without, Q pass, MMB and mouse 4 cross-check, Space poke, wheel deke, E spin,
  F ability, the possession rule ("with the puck" includes our pass in flight), a button held across a change of
  possession going dead until released, the saucer and brace hold thresholds (13 frames), R restart. Signals 1-4 are NOT
  given: they reach the brain's world inside the core (GAMEMODE.md row 13), which RinkCore v1 here does not take.
- **Hit-stop** (presentation only; GAMEMODE.md row 20, "K3's camera"): `scripts/hit_stop.gd` ports HitStopRoute,
  HitStopPick and HitStopFramesFor; on a hit involving the human the camera (and the two stand-ins and the puck) hold the
  hit frame for 1-6 frames while the sim steps on.
- **State and determinism.** `_pack_state()["rink"]` = `ctx.cores.state()["rink"]` (the core's own hash, frame, score), so
  the run's state_hash covers the match. invariants PASS (idle twice: 79a699ba1b92ec17; bot_match_hand twice:
  19657a920ad7853a after 5,460 frames); a recorded match (`tl.sh bot --record`) replayed (`tl.sh replay`) gives the same
  state hash (19657a92...); `proof/core_replay.gd`: the FJamInput stream the pack sent, fed straight into a bare RinkCore,
  gives the pack's core hash on every one of 5,459 frames.
- **The button rules against thirdjam's own code.** `oracle/make_button_oracle.sh` copies thirdjam's FJamButtonResolver,
  its default bindings and the verb table VERBATIM (InputMapping.h:27-145, InputMapping.cpp:78-90, 98-120, 146-168,
  318-425) and builds them with clang; `proof/buttons_compare.py` feeds a seeded stream of the five two-role keys (presses,
  holds, taps inside a frame, releases) under a changing possession to it and to the pack's port: **20,000 of 20,000
  frames equal** (shoot held on 2,161 frames, pass held 4,224, check 206, cross-check press 1,022, brace 3,874).
- **A whole match played through the keys.** `tests/bot_match_hand.gd` (a scripted hand, not thirdjam's playtester:
  RinkCore v1 does not expose FJamPlayerBot's inputs): the match ran to its end, 3:1 for the human's team at pro in
  5,459 frames, 21 shots, 269 checks and pokes.
- **The hall light and the ice** (the Director's answer 1): `engine/style/tl_style_hall.gd` (new file; no shader, no
  style file touched): `TLStyleHall.apply(root, {color, energy, shadows})` turns the installed style's sun straight down
  (the roof light), sets the cel shader's sun colour, switches the fog off; the hall's own roof casts no shadow. The pack
  asks for it with `data/gym.json` `hall.light` (#a88b7e): the ice now measures median sRGB (162, 144, 169) against
  thirdjam's film (158, 140, 150) near and (182, 168, 180) far.

## Film (looked at): r3_sbs_film_20s.mp4, r3_sbs_sheet_a.jpg, r3_sbs_sheet_b.jpg
thirdjam's 20 s (its own measured hand, pro, regular) beside ours (the scripted hand, pro, regular), same seconds from the
opening faceoff. Not the same play (two different hands); the camera, the scale and the rink are compared.
What my eye rejects about motion and framing:
1. The very first rendered frame (1/60 s) shows the camera behind the spawn before the opening faceoff places the
   skaters; thirdjam hides that moment under its light-hold fade from black (HokejGameMode TickLightHold). One frame.
2. Our hand weaves: it re-decides eight-way keys every 12 frames, so the human zigzags and the camera, which follows
   his facing exactly as thirdjam's does, swings left and right more than in thirdjam's film. The hand's fault, not the
   game's; thirdjam's playtester steers smoothly. A smoother hand (or K1's playerbot inputs) is next.
3. The shadows under the figures are light-blue pools (the cel shade of the lit ice); thirdjam's are soft dark grey.
4. Same as thirdjam: the opening faceoff framing (behind the human on the centre dot, the far net at the top), the
   human low in the middle in open play, the far boards at about 15 % of the height, two or three skaters round the puck
   carrier at 2.5 s in both.
Fixed on sight this round: at frame 0 every stand-in stick ran to the centre dot (BladePos is (0, 0) before the first
step); the figures and the camera slid in from the origin on the first frames (interpolation reset after the first draw).

## Deviations (new this round; the full list is in REPORT.txt)
- The input rules are the pack's port until K1's core glue lands (human mode "raw"); signals 1-4 wait for it.
- R restart = `reset(seed)` (thirdjam: UJamSim::Restart, rules and zones reset, brain reset); K1's v1.1 has `restart()`.
- A key tapped and released inside one physics frame is not seen (the kernel samples key states per frame; thirdjam's
  Enhanced Input events are; K1's raw shape carries such a tap in `Pressed` without `Down`).
- The stand-in stick: when the sim has not placed the blade (more than 3 m from the skater) it is drawn ahead.
- `ctx.cores` (TLCores) is K1's file copied byte for byte from hk-core so the pack runs today (tl_cores.gd identical,
  tl_context.gd the same hunk); KERNEL_API 1.18 as K1's.
