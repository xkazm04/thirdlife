# Rigs (`TLRigs`, kernelApi 0.1)

```gdscript
var rig: Node3D = TLRigs.build("biped", {"mode": "skate", "stick": true, "colors": {"top": "car_blue"}})
body.add_child(rig)                       # a rig is VISUAL ONLY: your controller owns the physics body
# every physics frame:
rig.set_locomotion(velocity_local, grounded)   # metres per second in the rig's space, forward is -Z
rig.tick(frame)                                # advances exactly one frame (1/60 s); never reads a clock
# events:
rig.play(&"shoot")                        # blend 0.15 s by default; looping is a property of the clip
rig.set_param(&"look_at", puck.global_position)
rig.socket(&"hand_r")                     # Node3D to parent things to; null if absent
rig.metrics()                             # sizes for the controller (+ "triangles", "bones")
TLRigs.spec("biped"); TLRigs.validate("biped", params); TLRigs.list()
```
`family` is a property (`&"biped"`, `&"vehicle"`, `&"bot"`). Rigs face -Z; anatomical left is -X.

## How animation works
- A clip is a **pose function** of time: `fn(t) -> {BoneName: Vector3(degrees), "_hips": Vector3(metres)}`, plus a
  duration and a loop flag. Bones have identity rest rotations, so a pose is plain per-bone euler degrees:
  `+x` swings a hanging limb forward (-Z) and tips an upright bone (spine, head) back, so a forward lean is negative x
  on Hips / Spine; `+y` turns left; `+z` rolls the top towards -X. A new clip is one function and one `add_clip` line.
- `tick(frame)` evaluates the current pose, blends from the pose that was showing when `play` was called (quaternion
  slerp, smoothstep over the blend time) and writes bone poses; a bone the pose does not name returns to its rest
  rotation (it never keeps what an earlier clip left on it), and `look_at` turns the head from that fresh pose each tick. Everything is a function of the number of ticks and
  of `frame`: the same calls give the same pose on every run (the self-test compares two runs).
- **Locomotion**: with no action clip playing, `set_locomotion` decides. `mode = walk`: one gait from standing to a
  sprint, read from the speed AND the direction of `velocity_local` (see "The walking gait" below); off the floor
  (`grounded = false`) the air pose, by `velocity_local.y`.
  `mode = skate`: a still hockey glide below 0.3 m/s blending to the full stride by 2.5 m/s; skate blades are shown
  and the body stands 5 cm higher.
- **Action clips**: a one-shot clip returns to locomotion when it ends. `shoot` and `pass` are **upper-body** clips:
  while the rig moves faster than 0.8 m/s the legs keep the locomotion pose and only spine, arms and head take the
  action. `fall` and `skate_stop` **hold** their last pose until another `play` (`play(&"")` returns to locomotion).
- A Skeleton3D that is posed outside the scene tree stops updating for good; the rig base works around it
  (`TLRigNode._flush` / `_reapply`), so a rig may be built, posed and ticked before it is added to the tree.

## Biped clips
| Clip | Loop | Seconds | What it is |
|---|---|---|---|
| `idle` | yes | 4.0 | breathing, small head and arm drift |
| `walk` | yes | 0.9 | lane-B walk, both arms swinging |
| `run` | yes | 0.6 | forward lean, high knees, bent arms pumping |
| `skate` | yes | 1.2 | hockey stride: deep knees, 36 degrees of forward lean, the pushing leg straightens out to the side and back |
| `skate_stop` | holds | 0.4 | hockey stop: body snaps sideways, both skates across the travel line, lean away, head still facing travel |
| `shoot` | no, upper | 0.85 | slap shot: wind-up to 0.30 s (stick back at shoulder height), contact at 0.42 s, high follow-through with the back leg lifting |
| `pass` | no, upper | 0.55 | short low sweep, blade on the ice, contact at about 0.30 s |
| `cheer` | yes | 1.2 | arms up in a V, two hops per cycle |
| `fall` | holds | 1.0 | stumble, knees, flat on the front with the arms thrown forward |
| `carry` | yes | 0.9 | both forearms held forward under a load (parent the load to `hand_r` or between the hands); with `set_locomotion` running the legs are the gait's (planted, at the real speed), without it the authored walk in place |
| `work` | yes | 0.8 | hammering with the right arm, leaning in |
| `jump` | no | 0.30 | take-off, played as the feet leave the floor: legs push straight, arms thrown up, ends in the rising air pose |
| `land` | no | 0.45 | landing: the gait's own legs (feet stay where they stand, he may run on) under a crouch that takes the fall: soft from 4 m/s of fall, deep and slow with the arms out at 14 m/s. The fall speed is the last `velocity_local.y` seen while `grounded` was false. Its blend is at most 4 frames |
| `slide` | holds | 0.30 | run slide: low on the left hip, right leg out ahead, left leg folded under with the foot on the floor (never under it: `rig.walker.slide_floor`), left arm trailing low behind (the hand about 0.3 m above the floor), right arm up |
| `slope_slide` | yes | 1.6 | sliding down steep ground: knees bent, weight back, turned a little across the fall line, arms out wide and working for balance. Loops until another `play` (`play(&"")` ends it) |
| `air` | yes | 1.0 | the air pose by name (locomotion shows it by itself when `grounded` is false): rising above +4 m/s, apex round 0, falling below -5 m/s |
| `fly` | yes | 1.6 | flight (lane flight, 19 Nov): body long and straight, legs together trailing with soft knees and pointed toes, arms back along the sides with the hands out, head lifted; a slow breath. The controller leans the whole figure into the flight; wings are not part of the rig |

The fight clips (`strike`, `strike_heavy`, `block`, `roll`, `dodge`, `body_check`, `cross_check`, `taunt`) are in
"Fight clips" below, with their frame timings.

With `stick = true` the arms of idle, walk, run, skate and skate_stop take the two-handed stick hold; `shoot` and
`pass` always use it. The stick is a child of the `hand_r` socket; `socket(&"stick_blade")` is the blade (for a
puck-contact test). The left hand is posed near the butt of the stick by hand-tuned angles: there is no IK.

## Fight clips (lane L2, 21 Nov 2026; `biped/tl_rig_biped_fight.gd`, internal to the rig)
The moves every action game needs, played by name as any clip: `rig.play(&"strike")`. Frames are physics frames at
60 Hz counted from the `play` call (the tick after it is frame 1). A pack reads the table to time its own rules: the
hit box is live in **Active** and is tested at **Hit** (for `block`: the frame the guard counts; `-` = the move hits
nothing), a defender can read **Anticipation**, and from **Control returns** the pack may play the next clip (a combo,
a cancel) without cutting the move short. Each clip takes at most a 2 or 3 frame blend-in (taunt 0.15 s), so the
wind-up always shows; when a one-shot ends, the rig blends back to locomotion over 12 frames.
The clips only animate: the pack moves the body (a roll travels, a dodge steps aside, a check lunges).

| Clip | Frames | Anticipation | Active | Hit | Recovery | Control returns | Ends | Upper | What it is |
|---|---|---|---|---|---|---|---|---|---|
| `strike` | 16 | 0-3 | 3-6 | 5 | 6-16 | 12 | returns | yes | a light one-handed swing: the right fist draws back past the ear over the rear foot. The hips start a short step before the shoulders whip the arm flat across (fastest at f4-5). The fist carries past the left shoulder before returning to guard |
| `strike_heavy` | 30 | 0-10 | 10-14 | 13 | 14-30 | 26 | returns | no | a two-handed overhead chop: both arms rise behind the head as the rear knee loads. The chest keeps arching from f8 to f10, then folds over a long step through f14. The hands stall at knee height to f20 before the body rises back to guard |
| `block` | 5 | 0-0 | 0-4 | 4 | on release | 4 | holds | yes | a covering guard: both forearms up in front of the face with the elbows thrown out wide (a W from the front, a wide ring from above), shoulders shrugged, turned a little side-on, crouched low on a wide stance; overshoots at f3, the pose from f4 holds until another `play` (`play(&"")` drops it); he can walk behind it |
| `roll` | 24 | 0-4 | 4-20 | - | 20-24 | 20 | returns | no | a forward roll: a drop and reach (f0-4), one full turn over a tucked ball about a point 0.45 m over the floor (upside down at f12), opening into a crouch; low through f3-21 (i-frames, if the pack wants them) |
| `dodge` | 14 | 0-2 | 2-9 | - | 9-14 | 11 | returns | no | a quick side step: a dip and push off the far foot, the body leaning hard into the step, head ducked (to f9), back on guard. The side: the param `dodge_side` (-1 left, +1 right), or with it 0 (the default) the side the body moves at the clip's first tick (`velocity_local.x`, + = right; standing still = right) |
| `body_check` | 30 | 0-7 | 7-15 | 12 | 15-30 | 24 | returns | no | a shoulder drive: loads low, turned away, the trailing arm swung back (f0-7); then side-on and pitched forward with the pelvis surging 0.35 m, the left elbow out ahead of the lead shoulder and the right arm flung back: that contact pose holds f11-15; back to the stance by f30. On skates the hockey stance, and the stick trails low in the right hand (out to the side) |
| `cross_check` | 14 | 0-6 | 6-11 | 10 | on release | 11 | holds | yes | both hands on the stick, the shaft turned level across the chest (butt at the left hand, blade hanging at the right), pulled in tight with the elbows out wide and the body rocked back (f0-6), then punched forward and up to face height with straight arms, a long step in and the whole body leaning into it; the punch pose holds from f10 until `play(&"")`: the cross-check reads by the figure, not by a marker. With `upper`, he skates in with it. Without a stick the arms make the same shove |
| `taunt` | 90 | 0-0 | 0-78 | - | 78-90 | 60 | returns | no | "come on", not `cheer`: the arms thrown open wide and up, chest out, chin up (in by f9, held to f28); then the right fist on the hip with the elbow out and the left hand raised high, beckoning twice (f40-80), the weight rocking back |

- The guard the fist clips start from and return to: left foot ahead, knees soft, the left shoulder leading, both fists
  up in front of the chin. On skates `body_check` and `cross_check` start from the hockey stance instead.
- Measured, not guessed: the selftest block 660 (`rig.fight.*`, `engine/rigs/review/fight_case.gd`) holds this table,
  `TLRigBipedFight.TIMING` and the registered clip lengths together, checks each clip ends as the table says, that each
  Hit lies in Anticipation..Active, that the key pose of `block`, `body_check` and `cross_check` holds 3 frames from the
  hit (round L2b: readable at game scale), and that `dodge_side` picks the side.
- `dodge_side` (runtime param): `rig.set_param(&"dodge_side", -1 | 0 | 1)`. Read at the dodge's first tick.
- See them: `engine/rigs/review/move_lab.tscn` (stills sheets at game scale and a clip of all of them; its header has
  the command lines).

### `stick_yaw` (runtime param, radians; hockey)
`rig.set_param(&"stick_yaw", a)`: + turns the stick to the left, - to the right; clamped to -1.2..+2.0 rad; 0 is the
pose without it, bit for bit. The upper body turns about the vertical (Chest 0.45 and UpperChest 0.55 of `a`, the Neck
back by 0.55 so the head stays on the play), so both hands and the blade sweep round the body at the same height (the
blade's height changes by 0.00 m): the blade follows a cursor within the stick's reach. Only with a stick in hand. It
costs one comparison per tick at 0 and nine bone reads at most otherwise: set it every frame. `socket(&"stick_blade")`
moves with it. Layered on every clip, before `look_at`.
- `a` is relative to where the blade rests, and it rests out to the right: bearing -0.46 rad (26 degrees right of
  straight ahead) on the classic figure, -0.98 rad (56 degrees right) on the cel (crisp) and clay figures, 1.38 m from
  the body's axis on both. So the reach across to the left is the longer one (+2.0). To put the blade on a cursor at
  bearing `b` (+ = left, rig space): `a = b - rest`, where `rest` is the bearing of `socket(&"stick_blade")` in the
  rig's space read once with `stick_yaw` 0 (`atan2(-x, -z)`). Measured: +1 rad turns the bearing by +0.86 (classic) /
  +0.88 (cel), -1 rad by -0.87 / -0.96 (block 660, `rig.fight.yaw`).
- During `cross_check` the right hand turns the shaft level across the chest and the stick slides 0.47 m up through the
  hand (its middle between the two hands); the stick's position is zero again 6 ticks after the clip ends.
## Directional hits (falls arm A)

| Clips | What the figure does |
|---|---|
| `hit_front`, `hit_back`, `hit_left`, `hit_right` | The suffix names the source of the blow. The chest snaps away in three ticks and the head and arms follow a tick later. Recoil fades over the next 18 ticks. Legs keep their stride on a moving figure. |
| `fall_back`, `fall_front`, `fall_left`, `fall_right` | The suffix names where the figure lands. Knees fold before the seat meets the ground, hands catch a forward fall, and a side fall lands on the hip then shoulder. Each holds its last pose. |
| `get_up_back`, `get_up_front`, `get_up_left`, `get_up_right` | Start from the matching landing pose. Sit up from the back, press up from the front, or roll onto the hands from one side. Gather a knee, push off the boot, and return to the live gait. |

These clips work with ordinary `play`. A controller can call the optional rig method `_size_hit(clip, amount, frames)`
before playback. For recoil, `amount` is hit strength. For a fall it is horizontal speed in m/s and `frames` is the
available lie window. Between 2.16 and 3.60 m/s the arms throw wider, the body travels farther before contact, and
the head and hips rebound once. A side landing leaves the upper arm outstretched and one knee across the body.
For a rise, `frames` is its exact length in physics ticks. Direct playback defaults to a
0.7-strength flinch and a 24-frame fall or rise. The held stick follows the right wrist throughout.

## Reaction clips (feel kit, N1)

| Clip | Frames | Key frame | Ends | What it is |
|---|---|---|---|---|
| `block_stun` | 14 | 3 | holds | The blow drives both forearms toward the face. The knees give and the head ducks, then the fighter settles into the held `block` pose. |
| `recoil` | 30 | 5 | returns | The weapon arm bounces up behind the shoulder. The hips shift back and the free arm balances the fighter through 60% of the clip. |
| `parried` | 52 | 5 | returns | The weapon arm flies wide with the elbow extended. The chest twists open and wobbles until recovery begins at 75%. |
| `guard_broken` | 30 | 5 | returns | Both arms fly low and apart as the fighter stumbles back onto bent knees. The guard reforms in the last quarter. |
| `wall_splat` | 60 | 3 | returns | The back hits the wall with both arms at shoulder height. The hips slide down and the chin drops by 60%. The fighter rises in the last 20%. |

Frames count from `play` at 60 Hz. All five blend in over at most two ticks. The four returning clips reach the fist
guard on their last tick and resume locomotion on the next. Call `_size_hit(clip, amount, frames)` before playback
to set that clip's throw strength (0 to 1.5, initially 1.0) and length in physics frames. Contact keeps its early
frame when the window allows, while the hold and recovery scale with the window.

## Sockets
- biped: `hand_r`, `hand_l` (palms), `head` (top of the head), `back` (between the shoulder blades), `foot_r`,
  `foot_l` (soles), `stick_blade`.
- vehicle: `exhaust_l`, `exhaust_r`, `driver`.
- bot: `tool` (tip of the right forearm: sparks, a tool), `head` (top of the hat: the beacon), `carry` (in front of the chest).

## Vehicle
`set_param` every frame from the controller: `steer` (-1..1, + = left, 32 degrees at 1), `wheel_spin` (rad/s),
`suspension` ([FL, FR, RL, RR] metres of compression: the wheel moves up relative to the body, clamped -0.12..0.16),
`throttle`, `brake` (brake lights; both pitch the chassis a little), `nitro` (0..1: flame size, flicker keyed to
the frame, light). Node tree: `Chassis` (Body mesh, Nitro, BrakeLights, sockets), `WheelFL|FR|RL|RR` / `Spin`.

## P3: what a rig looks like at game scale
- The biped's head is 1.24 times larger and its hands 1.38 times (same 2.0 m of height; `TLRigBipedMesh.HEAD_K`, `HAND_K`). The face of pass 4 (eyes with
  highlights, brows, a smile, a blink every 204 frames) is unchanged; it is simply larger on the screen.
- `prop`: what `hand_r` holds. `auto` = the hockey stick in `skate` mode, nothing in `walk` mode; `stick = true` is the same as `prop = stick`; `hammer` goes with `work`.
  A pack that built skaters with `mode = skate` and nothing else now gets a stick without any change. `headgear`: `auto` = in `skate` mode a helmet in the `top` colour
  with a white stripe, plus a white hem band and a number patch on the jersey (the team reads from above and from behind); `none` keeps the hair; `helmet` forces it.
- Foot slide (P3 state, replaced on 18 Nov by the gait above): in locomotion the swing of legs and arms followed the ground speed (`_stride_amp`: 0.62 at walking speed, 0.78 at a run) so that a planted foot stands
  still on the floor. Measured with `bash engine/tools/look.sh slip <speed> walk` (planted foot's ground speed along travel, m/s): mean 0.30 / 0.42 / 0.61 at 1.0 / 1.4 / 2.0 m/s
  (was 0.88 / 1.18 / 1.64). Clips played by name (`play(&"walk")`) keep their authored swing; clip durations and `metrics()` are unchanged.
- The vehicle's drawn steering, body roll, throttle and brake pitch and nitro flame ease toward the controller's values (frame-counted).
- Review a rig in motion: `bash engine/tools/look.sh clip rig:<walk|run|skate|shoot|pass|idle|work|car|bot|fx>:<speed>:<turn deg/s>:<side|three|front|high|close|face|top> <out.mp4>`
  (`engine/rigs/review/review.gd`, a scene that is not part of any pack).

## The walking gait (walker-feel, 18 Nov 2026; `biped/tl_rig_biped_gait.gd`, moves in `biped/tl_rig_biped_moves.gd`: internal to the rig, not pack API)
- **The feet are planted by construction.** The gait is foot paths and the legs are solved (two bones, exact). A foot that
  stands has an anchor on the floor; each tick the anchor moves by exactly minus `velocity_local`, so the sole stands
  still at any speed, direction and acceleration. Feet land and lift at their exact phase part way through a tick (at
  9 m/s a tick is 15 cm of floor). When the rig is in the tree and its yaw changes, a standing foot keeps its place and
  heading in the world: turning on the spot, he steps round.
- **Speed decides the gait** (m/s at scale 1; `velocity_local` is divided by `scale`):

  | speed | reads as | cadence (cycles/s, two steps each) | duty | stride on the floor |
  |---|---|---|---|---|
  | 1.0 | stroll | 1.00 | 0.64 | 0.64 m |
  | 1.4 | walk | 1.18 | 0.62 | 0.74 m |
  | 2.0 | brisk walk | 1.45 | 0.56 | 0.77 m |
  | 2.6 | jog (first flight phase: duty under 0.5) | 1.50 | 0.44 | 0.76 m |
  | 4.5 | easy run | 1.52 | 0.30 | 0.89 m |
  | 9.0 | sprint | 2.35 | 0.215 | 0.82 m |

  A walk at 4.5 m/s is not possible with 0.84 m legs (it would take 7.6 steps a second): 4.5 is a run with a flight phase.
- **Direction**: the feet travel along the real direction. The pelvis turns 0.6 of the way towards it and the chest
  turns back, so he keeps facing forward: a sidestep is a side run under a forward-facing body. Past 100 degrees he
  backpedals (back to forward-style under 80 degrees).
- **Standing**: the idle upper body over planted feet; stopping, he stands where the feet are and takes one or two
  settling steps.
- **Pelvis height**: as high as the style asks (crouch and bounce by speed) and never higher than both legs reach, so a
  walk vaults over the standing leg and no leg is ever pulled off its foot.
- Measure: `bash engine/tools/look.sh slip <speed> walk` prints `contact` (six sole points; a point on the floor two
  frames running should not have moved: mean / max m/s over the floor; frames with nothing on the floor; the lowest
  point) and the P3 `slip` line. 18 Nov: contact mean 0.03 to 0.10 m/s at 1 / 2 / 4.5 / 6 / 9 m/s, sidestep and
  backward at 4.5 (before: 0.94 to 9.2). The P3 meter samples the landing frame of a gait with a flight phase and reads
  high from 4.5 m/s up; trust `contact`. `RIG_ARGS="--dir=90"` sidestep, `--dir=180` backward, `--turn=60` a curve.
- Clips of the moves: `bash engine/tools/look.sh clip rig:<jump|air|land|slide|slope_slide>:<speed>:0:<view> out.mp4`;
  views `behind` (the visitor's camera), `vclose`, `vfront` were added.
- `stride_k` (cadence multiplier) still works; `amp_override` is kept for API v1 and has no effect (there is no swing
  amplitude to tune: the stride follows from the speed).

## A rig's shading travels with it (walker-feel)
`TLRigs.build` sets the toon shader's instance parameter `tl_body` on every mesh of a rig (`engine/style/STYLE.md`, "Bodies
that move"): mottle and hatching are anchored to the body, rim lights are drawn only on curved surfaces, a biped or a bot
casts no shadow on itself (its shadow on the ground is unchanged), and the ink pass draws a body's contour at
`ink.body_k` of the width. A mesh added to a rig after `build` (a prop parented to a socket by a pack) is a kit part and is
shaded as the world is.

## The skater (`TLRigSkater`, hockey campaign lane K2, 23 Nov 2026; `skater/`)
thirdjam's own skater, not a member of `TLRigs`: its shipped figure `SK_SkaterTB1_P3` (12,040 triangles, 24 bones, nine
material slots, the stick skinned into the mesh on the bone `stick_socket`), 1.637 m tall at rest, its 202 clips
(6,923 keys at 60 a second), and **its driver, ported from thirdjam's shipped Blueprints**.

| File | What |
|---|---|
| `skater/tl_rig_skater.gd` | `TLRigSkater`: the figure. Its entry is thirdjam's `IJamSkaterVisual` (same names, arguments, units) and the by-name calls of thirdjam's pawn; inside, `BP_SkaterVisual_TB1_P3` function by function |
| `skater/tl_rig_skater_puck.gd`, `_whip.gd`, `_falls.gd`, `_contact.gd` | the figure's `takes`, one chain (`TLRigSkaterPuck` <- `Whip` <- `Falls` <- `Contact`), the same Blueprint's takes: the puck verbs (shots and the charge, passes and the held pass, receive, call for pass, poke, stick lift, stick hits, the deke); the whip of a hit and the rink's walls; knockdowns, board falls, lie loops, get-ups, board hit and pin; body checks with their wind-ups, the cross-check (wind, hold, release, whiff), hit reactions, stumbles, the event bus |
| `skater/tl_rig_skater_anim.gd`, `tl_rig_skater_slot.gd` | `TLRigSkaterAnim`: `ABP_SkaterTB1_P3` node by node, run as Unreal 5.9 runs it at 1/60 s (state machine, blend lists, layered blends, bone modifiers, the shot charge's blend); `TLRigSkaterSlot`: the slot's takes (dynamic montages) and Unreal's blend arithmetic |
| `skater/tl_rig_skater_blendspace.gd`, `tl_rig_skater_pose.gd` | Unreal's blend-space player and pose arithmetic; `skater_blendspaces.json`: thirdjam's three blend spaces (samples, triangulation, smoothing) |
| `skater/skater_body.scn`, `skater_clips.res`, `skater_clips.json` | the baked mesh + skeleton, the 202 clips, the clip table |
| `skater/driver-ref/*.txt` | the two listings of thirdjam's shipped driver (event graph 1,997 lines, animation graph 220) that the port cites by entry and node name |
| `skater/review/` | `skater_case.gd` (block 810), `skater_defects.gd` (the per-frame defect measures), `reference_poses.json`, `oracle_gym.json` and `oracle_verbs.json` (where thirdjam's own figure stands: 27 poses; 940 frames of the gym run; 1,800 frames of the verb run for the human and one bot) |

```gdscript
var sk := TLRigSkater.new()
sk.setup({"team": 0})
pawn.add_child(sk)                        # VISUAL ONLY; faces -Z, right is +X
# every sim frame, thirdjam's calls (engine/cores/rink/view/skater_pawn.gd makes them from the rink core's snapshot):
sk.UpdateMotion(speed_mps, turn_rate_rad_s, facing_yaw_deg)   # turn rate + = turning left seen from above
sk.SetStickAim(angle_deg, reach_m)                            # 0 = forward, + = to his left; centre to blade
sk.SetHasPuck(true); sk.SetBraking(true, decel); sk.SetFaceoff(true); sk.PlayFaceoffDraw(true)   # on their frames
sk.SetShotCharge(0.5); sk.PlayShoot(0.5); sk.PlayPass(1.0); sk.PlayPoke(true); sk.PlayLift(); sk.PlayStickHit(false)
sk.SetPassCharge(0.4); sk.PlayReceive(); sk.PlayCallForPass(); sk.SetLookAtPuck(false)    # by name from the puck show
sk.OnBusEvent(&"deke", true, where_cm, 0.0, &"left")          # thirdjam's event bus: lift and deke are ported
sk.set_rivals(all_figures)                # the other figures on the ice (the lift's size reads the nearest opponent)
sk.tick()                                 # one world tick of 1/60 s; never reads a clock
sk.socket_transform(&"puck_socket")       # where a carried puck is drawn (on the blade), the figure's space
sk.not_ported                             # interface calls that arrived and are not shown yet: name -> count
```
- **Ported (round 2):** skating (`UpdateMotion`, the Idle / Skate states, the Skate and SkateReady blend spaces, the
  stop takes, `SetBraking`), the stick (`SetStickAim`, the Aim blend space, the blade held on the ice, the learned
  offsets), the look at the puck, the faceoff stance and draw, the foul reaction. **Round 3:** the puck verbs (tap and
  charged shots with the wind-up pose, tap and held passes with the charge layer, receive, call for pass, poke and the
  stumble after a missed one, the stick lift in its three sizes with the lifter's turn, the carrier's reaction to a
  poke or a lift, the deke). The spin has no take (the pawn turns the figure); a one-timer is a shot. **Round 4:**
  the contact (body check with its three sizes and wind-up takes, the cross-check's wind, hold layer, release and
  whiff, hit reactions, stumbles, knockdowns in their kinds and sizes, board falls, lie loops, get-ups, board hit and
  pin, the whip of a hit, the mesh's turn and slide while down). **Not yet:** weapons and abilities, dash, dive, slide
  tackle, celebrations, the boost glow; the trip has no caller in thirdjam. The goalie's stance is in.
- **Held to thirdjam's own figure:** the same calls given to thirdjam's Blueprint in Unreal (`tools/skater/driver_oracle.py`)
  and to ours. Skating and stick: 940 of 940 frames within 1 cm, worst 0.02 cm (block 811, `rig.skater.oracle`). The
  verbs and the contact: a 1,800-frame match segment of the real core, ten figures, thirdjam's bus, hit-stops, puck
  actor and rink: 17,997 of 18,000 rows within 1 cm, worst 4.23 cm (block 812, `rig.skater.verbs.oracle` holds the
  human and two bots of them; `rig.skater.verbs.pin` a second, 720-frame segment with a board pin). thirdjam's own
  figure is not the same twice: two Unreal runs given the same calls differ on 11 rows by over 1 cm (worst 5.01 cm,
  single frames of a stick), which is where ours differs from either.
- Engine-side inputs that are not thirdjam's: `set_human(bool)`, `set_puck(Vector2(forward, right) or null)`,
  `set_rivals(Array)`, `set_rink(Vector3(half length, half width, corner radius) cm)`, `set_time_dilation(float)` (the
  hit-stop and the check's re-time: the actor's CustomTimeDilation), `set_no_game_mode(bool)` (the oracle's world).
- Sockets: `socket_transform(&"puck_socket" | &"stick_socket" | &"head_socket")`; the head socket carries thirdjam's
  mesh socket's own turn (a roll of -90 degrees on the bone of that name), its place is the bone's.
- Review tools keep plain playback: `play_clip`, `pose_at`, `pose_rest`, `clip_names`, `clip_keys`.
- Cost: ten figures' calls and ticks take about 2.0 ms a frame in GDScript (0.2 ms each; measured headless on a loaded
  machine, the skinning on the GPU is not in it); with thirdjam's pawns, bus and puck show around them about 2.5 ms.
- Around the pawns (`cores/rink/view/`): `skater_pawn.gd` (thirdjam's pawn), `skater_show.gd` (its game mode's part:
  the hit-stop picks, the shown carrier and where the puck is drawn, the play calls by name), `hit_read.gd` (its hit
  read: the whiff calls of a miss, the re-time of a check).
- See it: `cores/rink/view/verb_gym.tscn` (a five-a-side match segment from a recorded raw hand, every skater a pawn
  and a figure), `cores/rink/view/figure_gym.tscn` (the real core, a scripted hand; its header has the command lines) and
  `rigs/skater/gym/skater_gym.tscn` (single clips). Rebuild the assets: `tools/skater/export_skater.py` (inside Unreal),
  `tools/skater/build_skater.gd`, `tools/skater/blendspace_table.py`; the listings: `export_driver_text.py`,
  `t3d_digest.py`, `abp_digest.py`.
- Gate: selftest blocks 810 (`rig.skater.body`, `.clips`, `.ref`, `.play`), 811 (`.driver`, `.oracle`, `.red`) and
  812 (`rig.skater.verbs`, `rig.skater.verbs.oracle`, `rig.skater.verbs.pin`, `rink.view.show`, `rink.view.hits`).
- **The look (lane K7, `skater/look/`):** `TLRigSkaterLook`, two surfaces to choose from. `felt` (the default): thirdjam's
  own nine material instances on the clay tier through `TLStyleFelt`, the number on the back patch ([SetNumber]) and
  the team's crest on the chest ([SetTeam]), no ink line. `cel`: the engine's flat cel in thirdjam's slot colours, as
  round 1 had it (no number, no crest). One skater: `sk.set_look("cel")`; every skater built after:
  `TLRigSkaterLook.default_variant = "cel"`; a whole run: the environment variable `TL_SKATER_LOOK=cel`.
  Under the felt figure lies thirdjam's contact shade (`TLRigSkaterLook.ContactShade`, a child of the skeleton): standing
  0.5 x 0.7 m under the mesh, Darkest 0.45; lying (the driver's `bShade`, kept by the falls) 2.2 x 0.95 m at the pelvis,
  turned along the body, Darkest 0.75, Flat 0.7. In a hall the figure's cast shadows are the key lights' (STYLE.md).
  See both: `rigs/skater/look/look_gym.tscn` (its header has the command lines; `--mode=ten` is the ten skaters of a
  match). Gate: selftest block 850 (`look.skater.numbers`, `.instances`, `.shader`, `.variants`, `.render`,
  `.shadow`, `.shadow_red`, `.shaders_kept`).

<!-- generated below: do not edit by hand -->

## `biped`
Standard biped on Godot humanoid bone names, 29 bones. Clips: idle, walk, run, skate, skate_stop, shoot, pass, cheer, fall, carry, work, jump, land, slide, slope_slide, air, fly, hang, mantle, swing; fight: strike, strike_heavy, block, roll, dodge, body_check, cross_check, taunt.

Metrics at scale 1: `{"bones":29,"eye_height":1.765,"height":2.0,"radius":0.3,"triangles":9292}`

Clips: idle, walk, run, skate, skate_stop, shoot, pass, cheer, fall, carry, work, jump, land, slide, slope_slide, air, fly, hang, mantle, swing, strike, strike_heavy, block, roll, dodge, body_check, cross_check, taunt, hit_front, fall_front, get_up_front, hit_back, fall_back, get_up_back, hit_left, fall_left, get_up_left, hit_right, fall_right, get_up_right, block_stun, recoil, parried, guard_broken, wall_splat

Build params (also the initial values of the runtime params of the same name):
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `seed` | int | `1` | 0..1000000 | reserved for variation (no effect in v0.1) |
| `scale` | float | `1.0` | 0.5..2.0 | uniform scale (1 = 2.0 m tall with hair) |
| `colors` | dict | `{}` | keys: skin, hair, top, trim, legs, boots, pack, strap, stick | palette key per part; absent parts keep the default look |
| `mode` | string | `"walk"` | walk, skate | locomotion mode: walk = one planted gait from standing to a sprint, read from the speed and direction; skate = glide / stride by speed, skate blades shown |
| `stick` | bool | `false` |  | show a hockey stick in hand_r; arms take the two-handed hold (same as prop = stick) |
| `prop` | string | `"auto"` | auto, none, stick, hammer | what hand_r holds: auto = the stick in skate mode, nothing in walk mode; hammer goes with the work clip |
| `headgear` | string | `"auto"` | auto, none, helmet | auto = a team helmet in the top colour and the hockey kit (white hem band, number patch) in skate mode, hair in walk mode |
| `backpack` | bool | `true` |  | the lane-B backpack (build time only) |
| `expression` | string | `"happy"` | happy, focus, blink | face |
| `lean` | float | `0.0` | -1.0..1.0 | side lean of the locomotion pose, + = right |

Runtime only: `look_at`: Vector3 in world space, or null to clear: neck and head turn towards it (clamped)

Runtime only: `stick_yaw`: radians, + = left, clamped to -1.2..2.0; 0 = no turn: with a stick in hand the upper body, both hands and the blade turn about the vertical (set it every frame)

Runtime only: `dodge_side`: -1 = the dodge clip steps left, +1 = right, 0 (default) = the side the body moves at the play

## `vehicle`
Coupe. Clips: idle. Wheels steer and spin, each wheel moves with its suspension value, nitro flame, brake lights.

Metrics at scale 1: `{"bones":0,"length":4.4,"mass_hint":1150.0,"ride_height":0.2,"track":1.68,"triangles":1740,"wheel_radius":0.34,"wheelbase":2.7,"width":1.86}`

Clips: idle

Build params (also the initial values of the runtime params of the same name):
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `seed` | int | `1` | 0..1000000 | reserved for variation (no effect in v0.1) |
| `scale` | float | `1.0` | 0.5..2.0 | uniform scale |
| `colors` | dict | `{}` | keys: body, stripe | palette key per part |
| `spoiler` | bool | `true` |  | rear wing (build time only) |
| `steer` | float | `0.0` | -1.0..1.0 | + = left |
| `throttle` | float | `0.0` | 0.0..1.0 |  |
| `brake` | float | `0.0` | 0.0..1.0 | shows the brake lights |
| `wheel_spin` | float | `0.0` | -400.0..400.0 | rad/s, + = rolling forward |
| `suspension` | floats | `[0.0,0.0,0.0,0.0]` | 4 numbers | metres of compression, order FL FR RL RR |
| `nitro` | float | `0.0` | 0.0..1.0 | flame size |

## `bot`
Crew bot, 11 bones. Clips: idle, walk, work, carry, weld.

Metrics at scale 1: `{"bones":11,"eye_height":1.0295,"height":1.537,"radius":0.348,"triangles":1908}`

Clips: idle, walk, work, carry, weld

Build params (also the initial values of the runtime params of the same name):
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `seed` | int | `1` | 0..1000000 | reserved for variation (no effect in v0.1) |
| `scale` | float | `1.0` | 0.3..3.0 | uniform scale (1 = about 1.5 m with hat and beacon, the lane-B site size) |
| `colors` | dict | `{}` | keys: body, hat | palette key per part |
| `beacon` | bool | `true` |  | the lamp on the hat glows |

Runtime only: `look_at`: Vector3 in world space, or null to clear: the head turns towards it
