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
hit box is live in **Active**, a defender can read **Anticipation**, and from **Control returns** the pack may play the
next clip (a combo, a cancel) without cutting the move short. Each clip takes at most a 2 or 3 frame blend-in (taunt
0.15 s), so the wind-up always shows; when a one-shot ends, the rig blends back to locomotion over 12 frames.
The clips only animate: the pack moves the body (a roll travels, a dodge steps aside, a check lunges).

| Clip | Frames | Anticipation | Active | Recovery | Control returns | Ends | Upper | What it is |
|---|---|---|---|---|---|---|---|---|
| `strike` | 16 | 0-3 | 3-6 | 6-16 | 12 | returns | yes | a light one-handed swing: the right arm drawn back and out with the shoulders turned away, whipped flat across the front (fastest at f4-5), followed through past the left shoulder, back on guard |
| `strike_heavy` | 30 | 0-10 | 10-14 | 14-30 | 26 | returns | no | a two-handed overhead chop: a big coil (arms up behind the head, chest arched back, knees loaded) peaking at f8 and held to f10, the chop down through f14 as the body folds after it, the low follow-through held to f20 |
| `block` | 5 | 0-0 | 0-4 | on release | 4 | holds | yes | a raised guard: the left forearm up across the face, the right fist under the chin, chin tucked, a wide braced stance; holds like `fall` until another `play` (`play(&"")` drops it); he can walk behind it |
| `roll` | 24 | 0-4 | 4-20 | 20-24 | 20 | returns | no | a forward roll: a drop and reach (f0-4), one full turn over a tucked ball about a point 0.45 m over the floor (upside down at f12), opening into a crouch; low through f3-21 (i-frames, if the pack wants them) |
| `dodge` | 14 | 0-2 | 2-9 | 9-14 | 11 | returns | no | a quick side step: a dip and push off the far foot, the body leaning hard into the step, head ducked (to f9), back on guard. It goes to the side the body moves at the clip's first tick (`velocity_local.x`, + = right; standing still = right) |
| `body_check` | 30 | 0-7 | 7-15 | 15-30 | 24 | returns | no | a shoulder drive: loads low with the hip turned in and the left arm tucked across the chest, drives the left shoulder through (contact about f12), holds it to f19, back to the stance. On skates the hockey stance, the stick held low in both hands |
| `cross_check` | 14 | 0-6 | 6-11 | on release | 11 | holds | yes | both hands on the stick, the shaft turned level across the chest (butt at the left hand, blade hanging at the right), pulled in (f0-6), punched forward chest-high with straight arms (f6-11) and held: the cross-check reads by the figure, not by a marker. Holds until `play(&"")`; with `upper`, he skates in with it. Without a stick the arms make the same shove |
| `taunt` | 90 | 0-0 | 0-78 | 78-90 | 60 | returns | no | a cocky pose, not `cheer`: chest out, chin up, the right fist on the hip with the elbow out, the left hand held out beckoning twice (f20-80), the weight rocking back |

- The guard the fist clips start from and return to: left foot ahead, knees soft, the left shoulder leading, both fists
  up in front of the chin. On skates `body_check` and `cross_check` start from the hockey stance instead.
- Measured, not guessed: the selftest block 660 (`rig.fight.*`, `engine/rigs/review/fight_case.gd`) holds this table,
  `TLRigBipedFight.TIMING` and the registered clip lengths together, and checks each clip ends as the table says.
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

<!-- generated below: do not edit by hand -->

## `biped`
Standard biped on Godot humanoid bone names, 29 bones. Clips: idle, walk, run, skate, skate_stop, shoot, pass, cheer, fall, carry, work, jump, land, slide, slope_slide, air, fly, hang, mantle, swing; fight: strike, strike_heavy, block, roll, dodge, body_check, cross_check, taunt.

Metrics at scale 1: `{"bones":29,"eye_height":1.765,"height":2.0,"radius":0.3,"triangles":9292}`

Clips: idle, walk, run, skate, skate_stop, shoot, pass, cheer, fall, carry, work, jump, land, slide, slope_slide, air, fly, hang, mantle, swing, strike, strike_heavy, block, roll, dodge, body_check, cross_check, taunt

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
