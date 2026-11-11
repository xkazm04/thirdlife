<!-- N1: replacement text for section 12 of engine/kernel/API.md. The Director merges it; API.md itself was not edited. -->
## 12. Cameras (capability `camera`), reached as `ctx.cameras`

| Member | Meaning |
|---|---|
| `ctx.cameras.add_view(name, position, target, fov = 60.0) -> Camera3D` | a fixed named view; `capture --cam=<name>` renders it. List the names in pack.json `cameras` |
| `ctx.cameras.chase(target, opts = {}, view = &"chase") -> TLChaseCam` | follows from behind. Options `distance` (7), `height` (3), `look_height` (1), `stiffness` (0.12: how fast the heading turns), `follow` (0.3: how fast the place catches up), `aim` (0.5: how fast the point looked at catches up), `use_velocity`, `fov` (**58**) |
| `ctx.cameras.orbit(target, opts = {}, view = &"orbit") -> TLOrbitCam` | yaw free, **pitch held to 30..60 degrees**, distance to a range. Options `yaw`, `pitch`, `distance`, `distance_min`, `distance_max`, `look_height`, `yaw_rate`, `pitch_rate`, `zoom_rate`, `fov` (**50**), `smooth` (0.25: share of the remaining way the drawn camera covers each frame; 1 = rigid) |
| `ctx.cameras.activate(name) -> bool`, `views()`, `has_view(name)`, `view(name) -> Camera3D`, `active` | the first view registered is active until you say otherwise |
| `ctx.cameras.frame(subject, fill = 0.35, view = &"")` | places a view (default: the active one) so that `subject` covers `fill` of the frame height. A chase camera keeps its angle and changes `distance` and `height`; an orbit camera changes `distance` (and widens its range to hold it); a fixed view moves along its line of sight and looks at the subject's centre. Call it in `_pack_setup` after the camera was made and the subject is in the tree. It also names the subject as the view's main actor |
| `ctx.cameras.subject_px(subject) -> float` | how much of the frame height `subject` covers now in the active view: the height of the screen rectangle around its visible meshes, clipped to the frame; 0 when off screen or behind the camera. 0.08 is a small actor, 0.2 a clear one, 0.35 a portrait |
| `ctx.cameras.set_subject(view, subject)`, `subject_of(view) -> Node3D` | names the main actor of a view without moving it (a fixed view that must keep a whole court in sight) |
| `ctx.cameras.shake(amount, frames)` | impact shake on the active view: `amount` metres at the lens (0.05 a tap, 0.3 a crash), fading over `frames` physics frames. A stronger shake still running is kept |
| `TLOrbitCam.orbit_by(yaw_deg, pitch_deg)`, `zoom_by(metres)`, `bind_actions(input, {yaw_left, yaw_right, pitch_up, pitch_down, zoom_in, zoom_out})`, `yaw_basis() -> Basis` | in interactive play it also takes right-button mouse drag and the wheel |
| `TLChaseCam.snap()`, `TLOrbitCam.snap()` | puts the camera where it wants to be at once (after a teleport, a cut, or a change of `distance`) |

**Everything here is visual only.** `frame`, `shake`, `follow`, `aim` and `smooth` move or offset cameras; none of them
reads or writes simulation state, uses a clock or draws a random number, so a pack's state hash is the same with and
without them. `TLOrbitCam.yaw`, `pitch`, `distance` and `yaw_basis()` are the raw values the pack set: only the drawn
camera is eased, so camera-relative movement (`drive_from_input(..., cam.yaw_basis())`) is exactly what it was.
`shake` offsets the lens (`h_offset`, `v_offset`), not the camera's place.

**Lens.** A chase camera is 58 degrees and an orbit camera 50 by default (they were the engine's 75, which made every
actor small and bent the edges). Pass `fov` to change it. Frame the main actor of the play camera at 0.2 to 0.3 of the
frame height; a fixed view that shows a whole court should still keep its main actor at 0.08 or more.

**Measuring.** `TL_LOOK_PX=1` in the environment makes `TLCameras` print
`[look] px view=<name> frame=<n> h=<share of frame height> w=<width in frame heights>` every 30 frames for every view
that has a main actor. `bash engine/tools/look.sh px [frames]` runs each seed's bot and prints min / median / max.

Example (the three seeds):

```gdscript
cam = ctx.cameras.orbit(player, tune["camera"], &"player")
ctx.cameras.frame(player, 0.26)                       # seed_wall: the walker covers a quarter of the frame height
ctx.cameras.chase(car, {"distance": 8.5, "height": 3.0, "look_height": 1.1, "fov": 58.0})
ctx.cameras.frame(car, 0.2)                           # seed_drive
ctx.cameras.set_subject(&"court", paddles["player"])  # seed_paddle: a fixed view of the whole court
ctx.cameras.shake(0.12, 14)                           # when a block breaks
```


## P3
- `TLChaseCam` defaults: `follow` 0.18 (was 0.3), `aim` 0.3 (was 0.5), `stiffness` 0.07 (was 0.12). Measured on seed_drive with the TL_LOOK_CAM log
  (1800 frames of the lap bot): position jerk p95 116 -> 89 m/s3, max 239 -> 157; the car's size in the chase view 0.158 .. 0.254 of the frame height.
- `TL_LOOK_CAM=<file>`: the active camera's place and aim, one line per frame (`[cam] f= p=x,y,z d=x,y,z`), for motion review (`python` over the file: speed, jerk, turn rate).
