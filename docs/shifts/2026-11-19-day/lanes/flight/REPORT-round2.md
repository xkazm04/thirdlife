Lane flight, round 2 (d19-flight2 from main ebeeb2b), day of 19 Nov 2026. Started 10:10 by the worktree clock.
Route: Opus directing Astra (Codex gpt-6.2-astra, session 01a1f313-086c-72f2-a7f7-ea6b899eeb6a) for the mechanics; rig
poses, the figure's grip pose, dust, cases 531, review and demo scenes by me.

== MOVES (for the parkour lane): KERNEL_API 1.10, opt-in, documented in engine/kernel/API.md "Ledges and bars (1.10)"

API
  var w := TLBiped.create({"feel": &"walker", "moves": [&"ledge", &"bar"]})   # each move optional; default none
  TLBiped.mark_bar(body: CollisionObject3D)    # sets meta `tl_bar` on a StaticBody3D whose CylinderShape3D or
                                               # CapsuleShape3D is the bar (its transformed local Y axis, bounded by
                                               # the shape's ends). Lay it horizontal. Mark before the plot is copied.
  w.jump()   while hanging = mantle; on a bar = release (tangential speed + 2 m/s up)
  w.slide()  while hanging = drop (1 m/s away from the wall); on a bar = drop (tangential speed, no hop)
  move toward the wall = mantle, away = drop; on a bar, move across the bar = pump
  drive_from_input: the existing jump / slide actions do all of this (no new keys)
  w.walker_motion() -> "hang" | "mantle" | "bar" (besides ground, air, slide, slope, fly)
  read-only rig hooks (TLBiped, the visitor, the shared body): ledge_top, wall_normal (world, during hang/mantle),
    mantle_progress (0..1), bar_point, bar_axis, bar_theta (rad), bar_omega (rad/s) (during bar)
  rig clips (kernel biped rig): hang (loops 2.0 s), mantle (0.47 s = 28 ticks, holds), swing (loops 1.3 s).
  TLBiped and the visitor pose the figure themselves: on a bar the rig turns about the bar by bar_theta with the hands
    on the bar, facing across it (not flipping each half swing); on a ledge it faces the wall and hangs 0.4 m (x body
    scale) lower so the raised hands meet the lip; after a release or drop it turns upright in about 12-16 ticks.
  The village visitor has both moves (Space = mantle / release, C = drop, W/S = mantle-drop / pump).
  A walker biped WITHOUT `moves` is unchanged: its 600-frame position sha256 equals the pre-change one.

NUMBERS (constants and what the cases measured)
  Ledge catch: in the air only (never from the ground), moving at the face; top 2.0 to 2.8 m over the feet, inclusive
    (HANDS_H 1.6 m + LEDGE_MIN 0.4 .. LEDGE_MAX 1.2). Measured at 1.99 / 2.00 / 2.01 / 2.79 / 2.80 / 2.81 m:
    no / yes / yes / yes / yes / no. Refused: steep or no standing room on top; walking into a 2.4 m wall without a jump.
    With the walker's jump (1.0 m), a standing jump reaches a top 3.8 m over the floor at most.
  Mantle: 28 ticks (0.47 s), height gained = top - hanging feet = 1.601 m, 0 capsule overlaps, ends in ground mode; an
    obstructed path ends in air at the last clear position.
  Drop: 1.000 m/s off the wall, lands below; the same edge cannot be caught again for 20 ticks (first re-catch tick 21).
  Bar catch: hands point 2.2 m over the feet within 0.35 m of the axis (0.35 catches, 0.36 does not), air only.
  Swing: pendulum L = 1.1 m (hands to body centre), g = 24 m/s^2, damping 0.23105 /s (amplitude halves in 6 s:
    measured ratio 0.498 after 360 ticks), pump up to 5 rad/s^2, |theta| <= 100 deg (omega -> 0 at
    the limit), fixed 1/60 s step. Small-amplitude period measured 1.344014 s vs 2*pi*sqrt(1.1/24) = 1.345150 s.
    From a dead hang, pumping reaches 30 deg at tick 68. A blocked swing keeps its last clear angle, omega = 0.
  Release: velocity = omega * 1.1 m along the swing tangent + 2.0 m/s up (jump) or + 0 (slide): error 0.000000000 m/s;
    two runs identical to the byte (936 bytes of positions). Same bar re-catch after 20 ticks.
  Replay: a recorded village visit (wf_feel, the ex_walker wall: jump, hang, mantle) replays to the same feet, 0.000 m.

CASES (permanent): blocks 523-moves-body.sh (ledge_reach, mantle, drop, bar_catch, bar_swing, bar_release,
  flight_unchanged, optin), 527-moves-replay.sh (replay), 531-moves-pose.sh (moves.pose: the visitor's figure: hang clip,
  faces the wall, sink 0.400 m, hands within 0.304 m of the lip every hang tick past the blend; mantle clip, ends on top
  upright; swing clip, hands within 0.273 m of the bar through a pumped swing to 100 deg; upright 16 ticks after release;
  two runs equal). Each Astra case failed on ebeeb2b (0 passed, 9 failed, .tl/before-moves/output.log).
  My run: moves. 10/10 PASS; moves.optin and flight.biped re-run after my TLBiped grip-pose edit: PASS (same hashes).

NOTE FOR PACK AUTHORS
  A bar shape must stay alive: a Shape3D you create in a function and hand to the world space by hand is freed when the
  function returns (world_space keeps shapes it copies itself; my demo scene hit this and keeps its own reference).
  Through TLBiped in a pack's own space this does not arise (the pack's CollisionShape3D holds the shape).

== AFTER THE MOVES LANDED (12:15 on): main-red fix, dust, media

MAIN-RED FIX (flight.collide trunk=-inf after the blend lane's regrade moved the scattered trees)
  engine/kernel/runner/flight_case.gd: the collide case FINDS a trunk: the tree-tagged cylinders on layer 1 (crowns are
    layer 4), nearest the origin first (ties by position), approached at cruise from 4 sides, 0.25 m over the trunk's
    foot so the capsule passes under the crown; the first clear line counts (up to 40 trunks). On main's terrain: found
    at [26.0, 14.9] on the 2nd try, stops 0.351 m short. It also prints `FLIGHT done` when its run completed.
    (Why the old one failed besides the moved tree: a trunk body sits at 0 with its place in its shape transform, and a
    flying capsule meets the crown (layer 4) before the trunk unless it comes in low.)
  engine/tools/selftest.d/520-flight-body.sh: once `FLIGHT done` is printed, each case is judged by its own line, so
    one failing measurement no longer fails the others; a run that stops before `FLIGHT done` still fails every case.
    Measured: with the old collide line failing, ratio/accel/ceiling/sweep/land/gate printed PASS individually.
  Verified on a tree with main's files copied in read-only (identical to main at 12:10: engine/, devx/, foreman/ changes
  since ebeeb2b, then docs/generated/ from cc6b8d3): flight. 11/11, moves. 10/10, walker. 8/8, fast PASS, world 8/8,
  packs 2/2 (44/44 verb runs), kit.selftest 95/95. Standup line `landable:` at that time.

DUST (take-off and landing)
  engine/kernel/world/flight_wings.gd `dust(parent, at, scale)`: the style's own `dust` preset (TLStyleFx, palette discs,
    one shot, 40 frames), freed by a frame counter (DUST_FRAMES + 10); nothing headless or without the style.
  engine/kernel/world/visitor.gd: a puff (scale 1.3) on `fly_start`, one (1.0) on `fly_land` (not on `fly_end`: he is
    in the air then).
  Case flight.dust (engine/kernel/world/flight_dust_case.gd, block 532, WINDOWED under the machine-wide window lock):
    take-off tick 30 and landing tick 201 each get exactly one puff, at the feet, emitting, freed in time; PASS.
  Seen in a window: clip-moves.mp4 (take-off and landing at the end), stills-moves/j_, k_.

MEDIA (lane folder)
  clip-moves.mp4: 15.1 s, 1280x720, windowed, kernel/world/moves_demo.tscn (the visitor with its body, rig, wings and
    camera in a course of its own: a 2.4 m wall, a bar 2.8 m up): run and jump at the wall, hang, mantle, turn, run off,
    jump under the bar, catch, pump (the view swings to the side), release at a forward peak, land, F take-off with dust,
    hover, C down, land with dust. The village has no bar (a pack marks its own), so the bar is shown in this course; the
    ledge also works in the village (moves.replay: the ex_walker wall in wf_feel).
  sheet_moves.jpg + stills-moves/ (11 frames of that clip), sheet_poses.jpg (kernel/world/moves_review.tscn: hang side /
    back, mantle 25/50/75/100 %, swing at 0 / -40 / +60 deg, three-quarter).

BEHAVIOUR NOTES / FOR THE DIRECTOR
  - A pumped swing hits the 100 deg limit and stops dead there (omega = 0): visibly abrupt if a player pumps hard. A soft
    limit (damping near the end) would read better; not changed (a move's number, measured in moves.bar_swing).
  - The rig poses for pack bipeds (kernel/world/terrain/grip_pose.gd, used by TLBiped) are not covered by a case of their
    own; the visitor's are (moves.pose). The same math; a TLBiped pose case is next.
  - The camera's crown/terrain avoid treats a bar as a solid: walking under a bar toward the camera's side lifts the
    camera over it (seen in the first demo run). The village has no bars yet; worth a look when the parkour lane adds one.
  - Every tree file I copied from main is identical to main; only my own files differ (list in the `landable:` line).

GATES (final, this tree): see the last STANDUP line (full gate and windowed tour run after this was written).

CODEX TOKENS (round 2, session 01a1f313-086c-72f2-a7f7-ea6b899eeb6a): round 3 of the lane (moves): 198,786. No further
  Codex rounds (the collide fix, the grip poses, dust and the cases are mine).

NEXT THREE
  1. A TLBiped grip-pose case (hands on the bar / the lip for a pack biped, body_scale 1 and 2).
  2. A soft end to the swing (no dead stop at 100 deg) and A/D shuffle along a ledge, if the parkour lane wants them.
  3. Camera: ignore marked bars in the avoid cast (they are thin), so swinging under the camera's line does not lift it.
