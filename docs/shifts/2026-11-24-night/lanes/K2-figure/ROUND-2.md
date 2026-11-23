# K2 figure, round 2: thirdjam's driver, ported from its own graph and held to its own figure (23 Nov 2026, 18:57 to 20:45)

## What stands

- **The driver is a port of the shipped Blueprints, not a rebuild from notes.** `TLRigSkater` now takes thirdjam's
  `IJamSkaterVisual` calls by their own names (`UpdateMotion`, `SetStickAim`, `SetHasPuck`, `SetBraking`, ...), and
  inside it `BP_SkaterVisual_TB1_P3` is ported function by function and `ABP_SkaterTB1_P3` node by node, each
  citing the entry or node of the two listings now tracked in `engine/rigs/skater/driver-ref/` (1,997 and 220 lines).
  Unreal's own runtime rules (blend spaces, the state machine's cross-fades, blend lists, the layered blend, bone
  modifiers, the slot's takes) are written as UE 5.9 runs them, with the engine's file:line.
- **Ported this round:** skating (Idle / Skate, the Skate and SkateReady blend spaces with their smoothing and rate
  scales, the stop takes, `SetBraking`), the stick (`SetStickAim`, the Aim blend space at four reaches, the learned aim
  offsets, the blade held on the ice by `SK3Fix`), the look at the puck, the faceoff stance and draw, the foul reaction.
- **The pawn:** `engine/cores/rink/view/skater_pawn.gd` is `AJamSkater::ApplySimFrame` (JamPawns.cpp:464-746) and
  `ApplyRender` (:824-843) whole: one snapshot skater in, the figure's calls out, the aim smoothing, the hit-stop
  hold, the whiff and hold timers, the 60 Hz interpolation.
- **The gym on the real core:** `engine/cores/rink/view/figure_gym.tscn`. `RinkCore` steps a 2 v 2 of thirdjam's regular
  cartridge from a scripted hand of 940 frames (faceoff, start with a turn, top speed, sprint, reverse stop, rest,
  start back, two hard turns, Ctrl brake, idle, aim sweep standing, reach, aim sweep skating).
- **The oracle.** The same calls, frame by frame, were given to thirdjam's own figure (its Blueprint, its animation
  blueprint, its mesh) in an Unreal Simulate session at a fixed 60 Hz (`engine/tools/skater/driver_oracle.py`), and
  twelve points of the two figures compared on every frame (pelvis, head, hands, feet, shins, chest, stick bone, puck
  socket, head socket): **940 of 940 frames within 1 cm; the worst point of the worst frame 0.02 cm.**
- **Defects as tests** (`engine/rigs/skater/review/skater_defects.gd`): per frame the blade's lowest vertex, the skates'
  lowest vertices, every bone's length, the largest turn of a joint and move of a joint centre, the shaft's distance
  to the leg bones, the puck socket's height. Shown red four ways: the body sunk 3 cm (blade, skates, puck), one
  foreign pose every 150 frames (pop: 179 degrees), a forearm 2 cm longer (lengths: 940 frames), the stick turned 20
  degrees (the shaft near a leg on 297 frames against thirdjam's 275, the blade 5.3 cm under against 4.25).
- **Ten on the ice:** all ten skaters of the regular cartridge through pawn and figure. Calls and ticks of ten
  figures: about 2.0 ms a frame (5.4 ms before three cuts: the aim's poses kept, the blend-space tables unpacked,
  unused aim players not weighed). No numbers on the jerseys: the look was not started.
- **Gate:** selftest block 811: `rig.skater.driver`, `rig.skater.oracle`, `rig.skater.red`; block 810 still 4 of 4.

## What the tests found in thirdjam's own figure (ours does the same, to 0.2 mm)

The defect tests were written for what an eye wants. The ported figure does not pass them on this run, and it stands
within 0.02 cm of thirdjam's own at twelve bone points on every frame. The counts below are taken on our mesh; that
thirdjam's vertices do the same is an inference from that parity (nothing measured them in Unreal), checked by eye
on one pair of crops:

| Check | Ideal band | The figure on the gym run as it was compared with thirdjam's in Unreal |
|---|---|---|
| blade under the ice | 4 mm | 42 frames; the toe 4.9 cm under at the far ends of the aim |
| a skate under the ice | 4 mm | 158 of 782 skating frames; 10.7 cm under in hard turns at speed (the crossover blend) |
| pop | 40 degrees a frame | 8 frames; the stick arm 94 degrees in one frame as the aim crosses the body at its fastest |
| shaft against a leg | 4.5 cm between axes | 322 of 645 frames with the stick on the ice; 0.09 cm (through the shin) in the full stride with the stick at rest |
| puck socket height | 2 to 11 cm | 1 frame at 1.3 cm |
| bone lengths | 0.5 mm | none |

I looked: `media/r2_thirdjam_shaft_at_knee_f147_f168.jpg` (thirdjam left, ours middle and right): the shaft comes out
of the knee, one skate's blade is in the ice. At the game's camera these are a few pixels; the owner called thirdjam's
figure "bugless" from there. We port before we change, so the gate is **parity**: on the gym run ours may break no
more frames than thirdjam's breaks, and none worse. The ideal bands are in the report of every run. Fixing them is
a change from thirdjam (the stair's step 7) and the Director's call.

## What my eye rejects (looked at: six of the thirty segment sheets, the stop take's sheet, the crops)

1. The three in the table that an eye can see up close: the shaft through the knee in the stride, the skate in the
   ice in a hard turn, the blade's toe in the ice at the aim's far end. thirdjam's, and now ours.
2. **A braking skater keeps striding where the stop take does not play.** In the oracle's world it never plays (no
   thirdjam game mode there), and the sheets `r2_reverse_stop_*.jpg` show a figure pumping its legs while it slows
   from 14 to 0 m/s. In the game the stop take covers it; ours plays it (`r2_stop_take_ours_three.jpg`: he turns
   side-on, low, for 45 frames) but that path is **not** compared with thirdjam's.
3. Ours still has no number, no crest, flat cel instead of felt: unchanged from round 1. In the game's own clip the
   white number on the back is the first thing that tells two skaters apart.
4. The stick arm's snap as the aim crosses the body (94 degrees in a frame): thirdjam's own; at speed it reads as a
   flick, on a sheet of every third frame as a jump.
5. The gym's low sun and its glare wedge on the ice; the oracle's stand-in ice. Neither is the game's arena.

In the six sheets I looked at (the start with its turn, both hard turns, both aim sweeps, the reverse stop: about
ninety pairs, every sixth frame) no pair shows the two figures in different poses. The other twenty-four sheets and
the two films I did not look through: for them the numbers stand alone (940 of 940 frames, 0.02 cm).

## What went wrong on the way (and what now guards it)

- **The first oracle run compared nothing**: thirdjam's figure stood in one pose for 940 frames (its pose is not
  ticked unless it was rendered, and a scene capture set to "every frame" after BeginPlay captures nothing: black
  stills). The numbers showed it at once (a pelvis at 40.8 cm on every frame). The oracle now captures by hand every
  tick and sets the figure's tick option before the session.
- Setting that option after BeginPlay rebuilt the Blueprint's components and threw away what its BeginPlay had set
  (a later `SetBoost` failed on a missing material instance): it is set on the editor world's actor now.
- **Two things about Unreal the first reading had wrong**, both found as a difference of one tick against the oracle:
  a blend is complete when its eased VALUE reaches the target in single precision (one tick before its lerp does);
  and what the Blueprint's own Tick writes to the animation (bReady, the look) is seen by the graph one tick later.
- **thirdjam's own figure is not deterministic there**: in one oracle run the same `SetHasPuck` moved the blend on
  the second tick after the call at frame 101 and on the first at frame 541 (Unreal updates the animation on a
  worker thread while the Blueprint ticks). Ours always takes the later tick. On a run with the puck won and lost
  within frames this is up to 3.1 cm for a few frames; the gate's tolerance (6 cm, 97 % of frames within 1 cm) is
  set for it, and the tracked run (seed 5) has no such moment.
- A world without thirdjam's game mode ends two Blueprint functions early (a failed cast ends the execution): the
  oracle's figure never plays a stop take. `set_no_game_mode` mirrors that for the comparison only.
- The first cost figure was 5.4 ms for ten figures; a profile showed the blend-space lookup, not the posing.

## Deviations (this round's, on top of round 1's)

1. Time is ticks / 60 where the Blueprint reads `GetTimeSeconds` (law: time is physics frames).
2. `WasRecentlyRendered` (SK3Fix) is taken as true: a figure nobody sees keeps its stick correction.
3. What the Blueprint's Tick writes to the animation is always seen one tick later (thirdjam: that tick or the next).
4. The sounds and the brake's particle effect of `StopTick` are not played (visual only; the shell's).
5. The puck to look at and "is this the human's figure" are given to the figure (`set_puck`, `set_human`); the
   Blueprint finds the puck actor and asks the game mode.
6. `YawCorr` and `RadCorr` of SK3Fix are not computed: the Blueprint computes both and uses neither.
7. Between two keys a clip is read by Godot's slerp, Unreal blends by a normalised lerp (under 1e-5 rad at 60 keys a second).
8. On an edge of a blend space's triangulation the triangle with the largest smallest weight is taken (Unreal: the
   one it visited last; the weights then differ by up to about 1e-3).
9. The pawn passes typed arguments on the by-name calls (thirdjam passes doubles and converts at the call).
10. The pawn writes no JAMVIS / JAMAIM log lines (it can record the calls instead).
11. The gym plays 2 v 2 with the bots playing: the core has no mode without them (the schema wants two a side, and
    goals at least 2 m wide). The human was bumped on 2 of 940 frames; those two `PlayHitReaction` calls were left
    out of what both figures were given.

## Not ported yet (the figure counts every such call in `not_ported`)

Shots (`PlayShoot`, `SetShotCharge` above 0), passes, poke, lift, the checks and their wind-ups, the cross-check and
its hold and whiff, hit reactions and stumbles, knockdowns, lie and get-ups, board hit and pin, the stick hit, the
whip, take grace and stick lock, the boost glow; and last: weapons and abilities, dash, dive, celebrations.
(The goalie's stance and blocks are in, as part of the stance blend.)

## Not done this round

- **The look**: the felt and clay material, the number, the crest, the face (the Director's answer 3). Not started in the
  engine. Fetched for round 3, in `.tl/` only: thirdjam's jersey material as text (19 custom HLSL nodes) and its six
  textures as PNG (the number atlas, two crests, felt fibre, two clay normals); an unbuilt draft of the number shader.
- The colour reference from the running game: one frame of the teardown's clip was looked at (deep blue jerseys,
  white numbers); at 854 x 480 it is no reference for a colour.
- The film is beside thirdjam's own figure driven in the editor, not beside the packaged game: the game's own
  scripted run (its acceptance drill) needs a driver that moves the real mouse, which this shared machine forbids.
- A byte-stable bake of `skater_body.scn` (Godot's scene node ids).
- The stop take and the look at the puck against thirdjam (see above): both need a world with its game mode and puck.

## Next (round 3)

1. The puck verbs from the listing: shots (tap, charged, the charge pose), passes, poke, lift, with the oracle given a
   puck and, if it can be had, thirdjam's game mode around the figure so that the stop take and the look are compared too.
2. The look: the number and the crest first (they tell skaters apart), then felt; flat cel kept as the second variant.
3. Contact: checks, cross-check hold / wind / whiff, stumbles, falls, lie, get-ups, board hit and pin.
