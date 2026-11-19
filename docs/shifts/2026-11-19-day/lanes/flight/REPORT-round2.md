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
