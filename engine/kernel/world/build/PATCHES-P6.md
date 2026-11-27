# PATCHES-P6: lane P (M6 play) edits outside the files it owns, and asks

Lane P, 27 Nov 2026 day shift, branch d27-m6-p from the seam 6690ad32. LANES.md "P: play" allows `visitor.gd` only for
launch (its `vel`) and teleport (`put(at, yaw)`), each edit listed here. The world gate stays 9/9 (see the report).

## E1 `engine/kernel/world/visitor.gd`: `put(at, yaw, from_sky := true)` (teleport and respawn)

```gdscript
func put(at: Vector3, yaw: float, from_sky := true) -> void:
	if space != null:
		var g: float = space.call("ground_at", at.x, at.z, 200.0 if from_sky else at.y + 0.6)
		at.y = g if not is_nan(g) and (from_sky or g >= at.y - 1.5) else (feet.y if from_sky else at.y)
		space.call("place", at)
	...                                   # the rest of put, unchanged
```

Why: `put` finds the ground looking down from 200 m, so a respawn to a zone's floor under a roof or a bridge, or on a
tower's lower floor, landed on top of whatever was highest. A rule's teleport passes `from_sky = false`: the floor just
under `at` (from 0.6 m above it, at most 1.5 m down), else `at` itself (a teleport out of the world stays out: the
out-of-world respawn then brings him back). Every existing caller passes two arguments: `from_sky` is true and the
expression reduces to the old one (`g if not is_nan(g) else feet.y`), so nothing else changes.

## E2 `engine/kernel/world/visitor.gd`: `launch(v: Vector3) -> bool` (a jump pad)

```gdscript
func launch(v: Vector3) -> bool:
	if space == null or not steer or not visible:
		return false
	var m: RefCounted = space.call("ensure_mover")
	(m.get("grips") as RefCounted).call("reset")
	for kv: Array in [["vel", v], ["mode", "air"], ["grounded", false], ["air_ticks", 0], ["_jumped", true], ["_buffer", 0]]:
		m.set(kv[0], kv[1])
	vel = v
	mode = "air"
	if rig != null:
		_clip(&"jump")
	return true
```

Why: the body's velocity lives in the space's mover (`terrain/world_body.gd`), which `visitor.gd` reads back each
frame (`vel = res["vel"]`). A launch sets it there (and the visitor's copy, and the jump clip), in the air, with
`_jumped` true so a key pressed during the rise is not a coyote jump. Nothing calls it but play_facade.gd. NOTE for the
Director: it writes two underscore fields of world_body.gd (`_jumped`, `_buffer`) through `set`; a public
`world_body.gd` `launch(v)` would be cleaner (world_body.gd is not P's file).

File length: visitor.gd is 599 lines with both (the law: 600).

## Asks (nothing blocked on them)

- A1 (E rule, Director decided 27 Nov): rules_play.gd takes the visit's "enter" request of the frame back from
  `kernel/world/tiers.gd` `_requests` when E fires `use` (tiers answers requests at the next world tick, and build
  mode ticks between). It reads a private array of tiers.gd. A cleaner hook would be in `kernel/runner/visit.gd`
  `steer`: `if input.just_pressed(&"enter") and ... and not _rules_claim_use():` asking build mode's `play`
  (`uses_here(feet cell)`) before it requests. visit.gd is not P's file: proposed, not made.
- A2 (records' place): the contract names `user://home/records.json`; rules_play.gd writes `records.json` into build
  mode's `dir` (the Home's folder: `user://home`, or TL_HOME_BUILD_DIR). Same file for a person; a fixture Home keeps
  its own records.

## Round 2 (27 Nov, day): no new edit outside P's files; one more private reach, named

- E3 (asks for a hook, nothing edited): during a run rules_play.gd eases the visitor's camera arm back and up by
  writing `visitor.gd` `_cam_dist` and `_cam_look_h` through `set` (its `_place_cam` reads them each tick; restored
  when the run ends or build mode comes on), and scales the visitor node for 14 frames on a launch (a stretch).
  visitor.gd is at 599 lines; a public `cam_scale(arm_k: float, lift_m: float)` there would be cleaner.
- The ghost key is G, read from the keyboard (`Input.is_physical_key_pressed`), not the visit's TLInput: it changes
  only what is drawn (no rule, no hash), and visit.gd's ACTIONS is not P's file. G is also a build tool key (rules and
  stamp tools); in build mode the rules are off, so the two never meet.
- Selftest 791-home-run-ghost.sh (the Director's new range 791-793).
