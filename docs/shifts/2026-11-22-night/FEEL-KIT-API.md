# Feel kit API: final names (N1, 21 Nov ~20:00; kernel API 1.13 when it lands)

N1 sent these names; they are final. N2 and N3 code against them behind one adapter file each. The kernel lands later
tonight; the Director then merges main into your tree and tells you.

## Hit-stop
While it runs, both bodies freeze:
- no movement, and the rig does not tick;
- down, stumble and stun counters hold;
- move, brake and jump are ignored;
- velocity is kept and resumed afterwards.

The rest of the world goes on. The hit-stop is in the state hash only while it runs.

```
TLHit.impact(attacker: TLBiped, victim: TLBiped, frames: int) -> int   # clamped 0..TLHit.STOP_CAP (20); either may be null; the victim's rig shakes along the blow (drawing only)
TLHit.stop_left(who) -> int     # a pack HOLDS ITS OWN counters (windup, AI timers) while > 0
```

## Contacts (DUEL-PLAYBOOK §6.3)
Each contact freezes both fighters, then gives each his reaction. A stun counts from the frame the freeze ends.

Each call returns `{contact, stop, attacker, attacker_frames, defender, defender_frames}`: the stun each side is now in
(`&""` = none).

```
TLHit.hit(attacker, victim, heavy := false, counter := false, tune := {})
TLHit.blocked(attacker, defender, heavy := false, tune := {})
TLHit.parried(attacker, defender, heavy := false, tune := {})
TLHit.clash(a, b, a_heavy := false, b_heavy := false, tune := {})
TLHit.guard_break(attacker, defender, tune := {})
TLHit.wall_splat(victim, wall_normal: Vector3, attacker: TLBiped = null, frames := 60, tune := {})
```

What each contact does:
- **`hit`:**
  - stop 5 light, 9 heavy (+2 on a counter-hit);
  - hitstun 18 / 40 (+10 on a counter-hit), knocked back 0.25 / 0.6 m, with a directional `hit_<side>` flinch;
  - a knock into a StaticBody3D wall becomes a wallsplat 40 (stop 8);
  - a victim on the ground gives contact `&"none"`.
- **`blocked`:**
  - stop 3 light, 6 heavy;
  - the defender gets blockstun 14 / 18 and is pushed 0.35 / 0.5 m (clip `block_stun`);
  - the attacker recoils 0.15 m on a light; on a heavy he recoils for 40 frames, 0.3 m back (clip `recoil`).
- **`parried`:**
  - stop 10;
  - the attacker is parried for 52 frames (light) or 36 (heavy), 0.2 m back (clip `parried`);
  - the defender recovers in 8.
- **`clash`:**
  - same class: stop 8, and both rebound 20 frames (30 for heavy against heavy), 0.3 m apart each (clip `recoil`);
  - heavy against light: the light one is hit (`TLHit.hit`, stop 9), and the result names the heavy one as attacker.
- **`guard_break`:**
  - stop 6;
  - the defender is guard-broken for 30 frames and shoved 1.0 m (clip `guard_broken`);
  - a StaticBody3D within `TLHit.WALL_REACH` (1.2 m) behind him gives wallsplat 60 (stop 12);
  - a wall met during the shove splats too.
- **`wall_splat`:** the victim is turned back to the wall, in wallsplat; stop 12 with an attacker, 8 without.

`tune` keys: `stop`, `frames` (the defender's), `attacker_frames`, `push` (m), `recoil` (m). An unknown key is a
`push_error`.

## State queries
```
TLHit.stun_of(who) -> StringName   # &"" | hitstun | blockstun | recoil | parried | recover | rebound | guardbroken | wallsplat
TLHit.stun_left(who) -> int
TLHit.busy_left(who) -> int        # hit-stop + stun + lying/rising: frames until he can act
TLHit.clear(who)                   # ends hit-stop, stun and push (round restart)
```
- During a stun no intent reaches the legs (brake on), and horizontal velocity is zeroed when the stun starts.
- `TLHit.down` ends a stun: a knockdown wins.
- `impact` followed by `react`/`down` in the same frame: the flinch or fall plays when the freeze ends.

## Pushbox (opt-in per body, so no existing hash moves)
```
TLHit.pushbox(who: TLBiped, on := true, radius := -1.0)   # -1 = body_radius() + 0.02; call once the body is under ctx.root
TLHit.pushbox_gap(who) -> float    # smallest centre distance minus radii of the pack's pushbox pairs (>= 0 = no overlap)
```
- Each frame, after every other node, overlapping pairs are pushed apart by half the penetration each, in join order.
  Walls still stop them.
- A body in hit-stop does not move. A stunned or downed body does not push back.

## Camera
```
ctx.cameras.fade_occluders(on := true, opts := {})   # opts: view (default active), subjects (a LIST: give both duellists), alpha 0.3, frames 8, max_size 12 m
ctx.cameras.faded() -> Array                         # occluding bodies found last frame
```
- Drawing only; off unless turned on.
- Known limit: props that a `tl.layout` merged into its static mesh cannot fade one by one. A pillar that should fade must
  be `TLKit.build` / `TLBodies.make`, not a merged layout prop.

## Ball
```
TLBall.set_radius(r: float)   # shape and drawn ball/puck resized; height, mass, material and motion kept
```

## Reaction clips the kernel plays
`block_stun` (holds the guard), `recoil`, `parried`, `guard_broken`, `wall_splat`. They live in
`engine/rigs/biped/reaction_poses.gd`, are being authored, and are sized to the stun. The kernel skips a clip the rig lacks.

**For hockey:** `guard_break` and `hit` zero the victim's velocity. For a skating body check that should carry momentum, use
`TLHit.impact` + `TLHit.react`/`down` + `biped.shove`, or tune `{"push": ...}`.
