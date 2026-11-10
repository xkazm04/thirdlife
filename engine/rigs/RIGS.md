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
  slerp, smoothstep over the blend time) and writes bone poses. Everything is a function of the number of ticks and
  of `frame`: the same calls give the same pose on every run (the self-test compares two runs).
- **Locomotion**: with no action clip playing, `set_locomotion` decides. `mode = walk`: idle, walk and run blended by
  speed (walk from 0.15 m/s, run from 2.6 to 4.2 m/s), stride rate follows speed; in the air a tucked pose.
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
| `carry` | yes | 0.9 | walk with both forearms held forward under a load (parent the load to `hand_r` or between the hands) |
| `work` | yes | 0.8 | hammering with the right arm, leaning in |

With `stick = true` the arms of idle, walk, run, skate and skate_stop take the two-handed stick hold; `shoot` and
`pass` always use it. The stick is a child of the `hand_r` socket; `socket(&"stick_blade")` is the blade (for a
puck-contact test). The left hand is posed near the butt of the stick by hand-tuned angles: there is no IK.

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

<!-- generated below: do not edit by hand -->

## `biped`
Standard biped on Godot humanoid bone names, 29 bones. Clips: idle, walk, run, skate, skate_stop, shoot, pass, cheer, fall, carry, work.

Metrics at scale 1: `{"bones":29,"eye_height":1.765,"height":2.0,"radius":0.3,"triangles":9652}`

Clips: idle, walk, run, skate, skate_stop, shoot, pass, cheer, fall, carry, work

Build params (also the initial values of the runtime params of the same name):
| Param | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `seed` | int | `1` | 0..1000000 | reserved for variation (no effect in v0.1) |
| `scale` | float | `1.0` | 0.5..2.0 | uniform scale (1 = 2.0 m tall with hair) |
| `colors` | dict | `{}` | keys: skin, hair, top, trim, legs, boots, pack, strap, stick | palette key per part; absent parts keep the default look |
| `mode` | string | `"walk"` | walk, skate | locomotion mode: walk = idle / walk / run by speed; skate = glide / stride by speed, skate blades shown |
| `stick` | bool | `false` |  | show a hockey stick in hand_r; arms take the two-handed hold |
| `backpack` | bool | `true` |  | the lane-B backpack (build time only) |
| `expression` | string | `"happy"` | happy, focus, blink | face |
| `lean` | float | `0.0` | -1.0..1.0 | side lean of the locomotion pose, + = right |

Runtime only: `look_at`: Vector3 in world space, or null to clear: neck and head turn towards it (clamped)

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
