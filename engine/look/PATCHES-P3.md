# P3 patches for files outside the look scope (proposed, not applied)

Nothing here was applied. Each item says what was seen, the exact change, and what it costs.

## 1. `engine/project.godot`: physics interpolation is off
Seen: `physics/common/physics_interpolation=false`. Everything that moves (bodies, rigs, the chase and orbit cameras) is updated
at the 60 Hz tick, so on a display faster than 60 Hz every frame between two ticks repeats the previous picture (judder) and
nothing is eased between ticks. The clips of P3 are written at a fixed 60 fps, so they cannot show this; it was NOT measured on a
fast display.
Patch (section `[physics]` of `engine/project.godot`):
```
common/physics_interpolation=true
```
Risk: with interpolation on, a node whose transform is set outside the physics tick, or teleported, smears over one tick
(`reset_physics_interpolation()` after a teleport). Rig bones are posed in `tick()` which runs in the physics step, so they interpolate
with the mesh node. Determinism is untouched (rendering only). Needs one interactive look (`tl.sh play`) before it is trusted.

## 2. `engine/kernel/api/tl_biped.gd` lines 165 and 189: turning is a constant-rate `rotate_toward`
Seen (code, not clip): `rotation.y = rotate_toward(rotation.y, want, turn_rate * delta)` starts and stops a turn at full speed: a stiff,
mechanical turn. Applying an easing to the BODY changes the facing the thrust uses, hence the state hash of every seed that skates or walks.
The visual-only version eases the rig node's yaw against the body's yaw and leaves the body as it is:
```gdscript
# in TLBiped._physics_process, after the body's rotation is final for this frame:
var lag: float = wrapf(rotation.y - _rig_yaw, -PI, PI)
_rig_yaw += lag * 0.35              # share of the remaining turn drawn each frame
rig.rotation.y = _rig_yaw - rotation.y   # the rig is a child: its own yaw is the difference
```
(`_rig_yaw` starts at the body's yaw; reset it in `place()`.) Not built here because the file is the kernel's and the rig's `set_locomotion`
velocity is expressed in the body's frame: a rig that is drawn a few degrees behind the body needs that velocity rotated by the same
amount, which is a decision for the owner of the kernel.

## 3. `contracts/KIT-RIG-STYLE.md`: proposed text (the Director's file)
Rigs, section "biped":
> Params added in P3: `prop` (`auto` | `none` | `stick` | `hammer`, default `auto`: the hockey stick in skate mode, nothing in walk mode; `stick = true` is the
> same as `prop = stick`) and `headgear` (`auto` | `none` | `helmet`, default `auto`: in skate mode a helmet in the `top` colour with a white stripe, a white hem band
> and a white number patch on the back; hair in walk mode). Metrics (`height`, `radius`, `eye_height`) and clip durations are unchanged;
> `triangles` grows by about 350 in skate mode.
> The walk and run locomotion blend scales the swing of legs and arms with the ground speed (0.62 at walking speed to 0.78 at a run) so that a planted foot
> stands still on the floor; the named clips `walk`, `run` and `carry` played with `play()` keep their authored swing.
Style, section "toon": optional `rim2` (colour) and `rim2_k` (0..1): a cool rim on the side facing away from the sun (global `g_rim2`).
Style, section "sky": optional `cloud_puff` (size of a cloud clump, 1), `cloud_line` (0..1, contour on the shade side) and `cloud_ink` (colour); `cloud`, `cloud_shade`,
`cloud_cover`, `cloud_scale`, `cloud_high` keep their names and now drive drawn clumps on the dome instead of streaks.
Cameras: `TLChaseCam` defaults are now `follow` 0.18, `aim` 0.3, `stiffness` 0.07 (were 0.3, 0.5, 0.12). `TL_LOOK_CAM=<file>` writes one line per frame
(`[cam] f= p= d=`) of the active camera for motion review.

## 4. `engine/kernel/world/` (the world builder's): mesas and the visitor
- Mesas (`landscape.gd` ~ line 357): the material now draws strata at any distance (class rock, `toon.gdshader`), so the mesas keep their `cliff` key and
  gain drawn bands without a change there. A tree line along a mesa's rim would be a second `mk_far` part of small dark `tree`-green blobs at the cap's edge:
  not drawn here because the part is built in `landscape.gd`.
- The visitor is built with `TLRigs.build("biped", ...)`: it can pass `{"prop": "hammer"}` or a future `tablet` prop; nothing is needed from the kernel.
