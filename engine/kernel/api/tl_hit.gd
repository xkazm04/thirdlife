class_name TLHit
extends RefCounted
## K7 (21 Nov 2026, spark game-quality-bar): how a figure takes a hit. One place every pack calls, so the way a hit
## looks (a flinch, a fall away from the blow, a get-up) can change without changing a pack.
##
##   TLHit.react(victim, attacker.global_position - victim.global_position, 0.8)   # flinch or stumble by strength
##   TLHit.down(victim, 90, attacker.global_position - victim.global_position)      # floored, falling away from it
##
## `from_dir` is the direction FROM the victim TOWARD where the blow came from (world space; length ignored; zero =
## unknown). `strength` is the hit's size: about 0.3 a tap, 0.7 a solid hit, 1.2 and up a big one.
##
## K8 feel kit (lane N1, night of 22 Nov 2026; docs/research/DUEL-PLAYBOOK.md sections 2 and 6.3): every contact changes
## BOTH fighters. One call per contact; each freezes both bodies in hit-stop, then gives each his reaction:
##
##   TLHit.hit(att, vic, heavy)            # flinch 18 / stagger 40, knocked 0.25 / 0.6 m; into a wall: wall-splat
##   TLHit.blocked(att, def, heavy)        # def blockstun 14 / 18, pushed 0.35 / 0.5 m; att recoils (heavy: bounce 40)
##   TLHit.parried(att, def, heavy)        # att PARRIED 52 / 36, weapon knocked away; def recovers 8
##   TLHit.clash(a, b, a_heavy, b_heavy)   # same class: both rebound 20 (heavy-heavy 30); else the light one is hit
##   TLHit.guard_break(att, def)           # def GUARDBROKEN 30, shoved 1.0 m; a wall within 1.2 m behind: WALLSPLAT 60
##   TLHit.wall_splat(vic, wall_normal)    # back flat to the wall, WALLSPLAT 60
##   TLHit.impact(att, vic, frames)        # only the hit-stop (5 light, 9 heavy, cap 20)
##   TLHit.pushbox(body)                   # opt-in: bodies of one pack never end a frame overlapping
##
## Hit-stop: for `frames` physics frames the body does not move, its rig does not tick (the pose holds), its down,
## stumble and stun counters hold, and `move`/`brake`/`jump` are ignored; velocity is kept and resumes after. The rest of
## the world goes on. A pack holds its OWN counters of a frozen fighter (a move's windup, an AI timer) with
## `TLHit.stop_left(b) > 0`. Calls made in the same frame stack: `impact` then `react`/`down` freezes first, and the
## flinch or the fall plays when the freeze ends. A stun: no intent reaches the legs (brake on) until it ends; `down`
## ends a stun (a knockdown wins). Everything is in physics frames and in the state hash while it runs; a biped that
## never took a K8 contact hashes exactly as before.


const _AWAY := {"front": "back", "back": "front", "right": "left", "left": "right"}
const _State = preload("res://kernel/feel/hit_state.gd")
const _Box = preload("res://kernel/feel/pushbox.gd")
const STOP_CAP: int = 20             ## hit-stop never runs longer than this (frames)
const WALL_REACH: float = 1.2        ## guard_break: a wall this close behind the defender splats him (metres)
const _TUNE: Array = ["stop", "frames", "attacker_frames", "push", "recoil"]


## Recoil on the live gait. Solid contact also costs a few frames of control.
static func react(who: TLBiped, from_dir: Vector3, strength: float) -> void:
	if who == null or who.is_down() or strength <= 0.0:
		return
	var side_name := _side(who, from_dir)
	var clip := StringName("hit_" + side_name)
	if who._rig_has(clip):
		if who.rig.has_method("_size_hit"):
			who.rig.call("_size_hit", clip, strength, 0)
		who.rig.call("play", clip, 0.05)
	if strength < 0.4:
		return
	var lean := 0.7
	var basis: Basis = who.global_basis if who.is_inside_tree() else who.basis
	var side := from_dir - basis.y * from_dir.dot(basis.y)
	if side.length() > 0.001:
		var right := basis.x.dot(side.normalized())              # +1: the blow came from his right
		if absf(right) > 0.2:
			lean = -0.7 * signf(right)                              # a blow from his right leans him left (-1)
	who.stumble(int(round(8.0 + 10.0 * strength)), lean)


## Floors him for the same lie and rise windows as down(frames).
static func down(who: TLBiped, frames: int, from_dir: Vector3 = Vector3.ZERO) -> void:
	if who == null:
		return
	assert(from_dir.is_finite(), "TLHit.down: from_dir must be finite")
	_down(who, frames, from_dir)


# ---- K8 feel kit: hit-stop, the contacts of DUEL-PLAYBOOK 6.3, the pushbox ----------------------------------------

## Draw the weapon's path for this many unfrozen physics frames. A new swing replaces the previous ribbon.
static func swing_trail(who: TLBiped, weight: float = 0.5, frames: int = 30, opts: Dictionary = {}) -> Node3D:
	return preload("res://kernel/feel/swing_trail.gd").start(who, weight, frames, opts)


## Hit-stop on both bodies for `frames` (clamped to 0..STOP_CAP); either may be null (a wall, a prop). The struck body's
## rig shakes along the blow while it lasts (drawing only). A longer stop still running is kept. Returns the frames set.
static func impact(attacker: TLBiped, victim: TLBiped, frames: int) -> int:
	var n := clampi(frames, 0, STOP_CAP)
	if n == 0:
		return 0
	var along := Vector3.ZERO
	if attacker != null and victim != null:
		along = _flat(victim.global_position - attacker.global_position)
	if attacker != null and attacker != victim:
		_state(attacker).freeze(n, Vector3.ZERO, attacker)
	if victim != null:
		_state(victim).freeze(n, along, victim)
	return n


## A clean hit. The victim: hitstun 18 frames (light) or a stagger of 40 (heavy), knocked 0.25 / 0.6 m away from the
## attacker with the directional flinch; knocked into a wall he is wall-splatted (40). `counter`: a hit in his windup
## or roll recovery, +2 hit-stop and +10 hitstun. The attacker: the hit-stop only. A victim on the ground: no contact.
## `tune` overrides: stop, frames (the victim's), push (m). Every contact returns
## {contact, stop, attacker, attacker_frames, defender, defender_frames}: the state each is now in (&"" = none).
static func hit(attacker: TLBiped, victim: TLBiped, heavy: bool = false, counter: bool = false, tune: Dictionary = {}) -> Dictionary:
	if not _ok("hit", attacker, victim, tune) or victim.is_down():
		return _result(&"none", 0, attacker, victim)
	var stop: int = int(tune.get("stop", (9 if heavy else 5) + (2 if counter else 0)))
	var frames: int = int(tune.get("frames", (40 if heavy else 18) + (10 if counter else 0)))
	var away := _away(attacker, victim)
	var n := impact(attacker, victim, stop)
	var amount := (1.0 if heavy else 0.6) * (1.2 if counter else 1.0)
	_react(victim, &"hitstun", frames, away * float(tune.get("push", 0.6 if heavy else 0.25)),
		StringName("hit_" + _side(victim, -away)), amount, 40)
	return _result(&"hit", n, attacker, victim)


## A blocked blow. The defender: blockstun 14 (light) / 18 (heavy), pushed 0.35 / 0.5 m on his guard (`block_stun`).
## The attacker: a light recoils 0.15 m; a heavy bounces off (`recoil`, 40 frames, 0.3 m back: a light is guaranteed
## against him). Hit-stop 3 / 6 (x0.67 of a hit). `tune`: stop, frames, attacker_frames, push, recoil (m).
static func blocked(attacker: TLBiped, defender: TLBiped, heavy: bool = false, tune: Dictionary = {}) -> Dictionary:
	if not _ok("blocked", attacker, defender, tune):
		return _result(&"none", 0, attacker, defender)
	var away := _away(attacker, defender)
	var n := impact(attacker, defender, int(tune.get("stop", 6 if heavy else 3)))
	_react(defender, &"blockstun", int(tune.get("frames", 18 if heavy else 14)), away * float(tune.get("push", 0.5 if heavy else 0.35)),
		&"block_stun", 1.0 if heavy else 0.6, 0)
	var back := -away * float(tune.get("recoil", 0.3 if heavy else 0.15))
	if heavy:
		_react(attacker, &"recoil", int(tune.get("attacker_frames", 40)), back, &"recoil", 1.0, 0)
	else:
		_react(attacker, &"", int(tune.get("attacker_frames", 0)), back, &"", 0.0, 0)
	return _result(&"blocked", n, attacker, defender)


## A parried (deflected) blow. The attacker: PARRIED 52 frames (light) / 36 (heavy), his weapon knocked away
## (`parried`), driven 0.2 m back. The defender: a short recovery of 8 and the initiative. Hit-stop 10.
## `tune`: stop, frames (the defender's), attacker_frames, recoil (m).
static func parried(attacker: TLBiped, defender: TLBiped, heavy: bool = false, tune: Dictionary = {}) -> Dictionary:
	if not _ok("parried", attacker, defender, tune):
		return _result(&"none", 0, attacker, defender)
	var away := _away(attacker, defender)
	var n := impact(attacker, defender, int(tune.get("stop", 10)))
	_react(attacker, &"parried", int(tune.get("attacker_frames", 36 if heavy else 52)), -away * float(tune.get("recoil", 0.2)),
		&"parried", 1.0, 0)
	_react(defender, &"recover", int(tune.get("frames", 8)), Vector3.ZERO, &"", 0.0, 0)
	return _result(&"parried", n, attacker, defender)


## Two blows meet. Same class: both rebound (`recoil`) 20 frames (heavy against heavy 30), each pushed 0.3 m apart,
## hit-stop 8. A heavy against a light: the heavy goes on and the light one takes the hit (TLHit.hit, hit-stop 9);
## the result then names the heavy one as the attacker. `tune`: stop, frames (both), push (m, each).
static func clash(a: TLBiped, b: TLBiped, a_heavy: bool = false, b_heavy: bool = false, tune: Dictionary = {}) -> Dictionary:
	if not _ok("clash", a, b, tune):
		return _result(&"none", 0, a, b)
	if a_heavy != b_heavy:
		var t := tune.duplicate()
		t.erase("push")
		var r := hit(a if a_heavy else b, b if a_heavy else a, true, false, t)
		r["contact"] = &"clash"
		return r
	var away := _away(a, b)
	var n := impact(a, b, int(tune.get("stop", 8)))
	var frames: int = int(tune.get("frames", 30 if a_heavy else 20))
	var push: float = float(tune.get("push", 0.3))
	_react(a, &"rebound", frames, -away * push, &"recoil", 0.8, 0)
	_react(b, &"rebound", frames, away * push, &"recoil", 0.8, 0)
	return _result(&"clash", n, a, b)


## A bash (body check, shoulder) that lands: the defender's guard is broken, GUARDBROKEN 30, shoved 1.0 m
## (`guard_broken`); with a wall (a StaticBody3D) within WALL_REACH behind him he is wall-splatted instead (hit-stop 12,
## WALLSPLAT 60: he is slammed back onto it over the 3 frames after the hit-stop), and a wall met during the shove
## splats him too. The attacker: the hit-stop (6) only.
## `tune`: stop, frames, push (m).
static func guard_break(attacker: TLBiped, defender: TLBiped, tune: Dictionary = {}) -> Dictionary:
	if not _ok("guard_break", attacker, defender, tune) or defender.is_down():
		return _result(&"none", 0, attacker, defender)
	var away := _away(attacker, defender)
	var wall := _wall_behind(defender, away, WALL_REACH, attacker)
	if not wall.is_empty():
		var w := wall_splat(defender, wall["normal"], attacker, 60, {"stop": int(tune.get("stop", 12))} if tune.has("stop") else {})
		w["contact"] = &"guard_break"
		# slammed back onto the wall over the 3 frames after the hit-stop (the clip's back meets the wall at its f3)
		var gap: float = (wall["position"] as Vector3 - defender.global_position - Vector3.UP * defender.body_radius() * 3.0).length() - defender.body_radius() - 0.01
		if gap > 0.01:
			_state(defender).set_push(away * gap, 0, 3)
		return w
	var n := impact(attacker, defender, int(tune.get("stop", 6)))
	_react(defender, &"guardbroken", int(tune.get("frames", 30)), away * float(tune.get("push", 1.0)), &"guard_broken", 1.0, 60)
	return _result(&"guard_break", n, attacker, defender)


## Back flat against a wall (`wall_normal` points out of the wall): turned to face away from it, WALLSPLAT `frames`
## (`wall_splat`), any push-back ends. Hit-stop 12 with an attacker, 8 without (knocked into it). `tune`: stop.
static func wall_splat(victim: TLBiped, wall_normal: Vector3, attacker: TLBiped = null, frames: int = 60, tune: Dictionary = {}) -> Dictionary:
	if victim == null or not _tune_ok("wall_splat", tune):
		return _result(&"none", 0, attacker, victim)
	var n := impact(attacker, victim, int(tune.get("stop", 12 if attacker != null else 8)))
	var out := _flat(wall_normal)
	if out.length() > 0.001:
		victim.rotation.y = atan2(-out.x, -out.z)       # forward() = the wall's normal: his back is to the wall
	_react(victim, &"wallsplat", frames, Vector3.ZERO, &"wall_splat", 1.0, 0)
	return _result(&"wall_splat", n, attacker, victim)


## Frames of hit-stop still to run (0 = moving).
static func stop_left(who: TLBiped) -> int:
	return who._feel.stop_left if who != null and who._feel != null else 0


## The stun he is in: &"" (none), &"hitstun", &"blockstun", &"recoil", &"parried", &"recover", &"rebound",
## &"guardbroken" or &"wallsplat". A stun counts from the frame its hit-stop ends.
static func stun_of(who: TLBiped) -> StringName:
	return who._feel.stun if who != null and who._feel != null and who._feel.stun_left > 0 else &""


static func stun_left(who: TLBiped) -> int:
	return who._feel.stun_left if who != null and who._feel != null else 0


## Frames until he can act again: hit-stop + stun + lying and rising (0 = free now). The frame advantage of a contact is
## busy_left(defender) - busy_left(attacker) (minus the attacker's own recovery, which the pack knows).
static func busy_left(who: TLBiped) -> int:
	if who == null:
		return 0
	return (who._feel.busy() if who._feel != null else 0) + who.down_frames_left()


## Ends hit-stop, stun and push-back at once (a round restart, a cut).
static func clear(who: TLBiped) -> void:
	if who != null and who._feel != null:
		who._feel.clear(who)


## Opt-in, per body: bodies of one pack that are in its pushbox never end a physics frame overlapping. Each frame, after
## every other node, each overlapping pair is pushed apart by half the penetration each (fixed order: the order they
## joined; walls still stop them); a body in hit-stop does not move, a stunned or downed body does not push back.
## `radius` -1 = body_radius() + 0.02 (just outside the capsule, so the pushbox decides before the capsules touch).
## Call it after the body is in the pack's tree (or before, while TLContext.current is the pack). on = false leaves.
static func pushbox(who: TLBiped, on: bool = true, radius: float = -1.0) -> void:
	if who == null:
		return
	var s := _state(who)
	s.box = on
	s.box_radius = radius
	var host := _box_host(who)
	if host == null:
		push_error("TLHit.pushbox: %s belongs to no pack (add it under ctx.root first)" % who.name)
		return
	var box: Node = host.get_meta(&"tl_pushbox") as Node if host.has_meta(&"tl_pushbox") else null
	if box == null or not is_instance_valid(box):
		if not on:
			return
		box = _Box.new()
		host.set_meta(&"tl_pushbox", box)
		host.add_child(box)
	if on:
		box.call("add", who)
	else:
		box.call("remove", who)


## The pack's pushbox gap now: the smallest centre distance minus the sum of radii over its pairs (>= 0: no overlap;
## INF with fewer than two bodies). For labs and bots.
static func pushbox_gap(who: TLBiped) -> float:
	var host := _box_host(who) if who != null else null
	if host == null or not host.has_meta(&"tl_pushbox"):
		return INF
	return float((host.get_meta(&"tl_pushbox") as Node).call("worst_gap"))


static func _box_host(who: TLBiped) -> Node:
	var c := TLContext.of(who)
	if c != null and c.root != null:
		return c.root
	return who.get_parent()


static func _state(who: TLBiped) -> _State:
	if who._feel == null:
		who._feel = _State.new()
	return who._feel


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Unit vector on the ground from the attacker to the victim (where a push sends the victim); the victim's back when
## they stand on one spot.
static func _away(attacker: TLBiped, victim: TLBiped) -> Vector3:
	var d := _flat(victim.global_position - attacker.global_position)
	if d.length() > 0.001:
		return d.normalized()
	var back := _flat(-victim.forward())
	return back.normalized() if back.length() > 0.001 else Vector3.BACK


static func _tune_ok(what: String, tune: Dictionary) -> bool:
	for k: Variant in tune.keys():
		if not _TUNE.has(str(k)):
			push_error("TLHit.%s: unknown tune key '%s' (keys: %s)" % [what, k, ", ".join(PackedStringArray(_TUNE))])
			return false
	return true


static func _ok(what: String, a: TLBiped, b: TLBiped, tune: Dictionary) -> bool:
	if a == null or b == null or a == b:
		push_error("TLHit.%s: needs two different bipeds" % what)
		return false
	return _tune_ok(what, tune)


## One side's reaction: the stun (frames 0 = none), the push-back (world vector), the clip sized to the stun.
## `splat` > 0: the push is a knock, and a wall in its way splats him for that long.
static func _react(who: TLBiped, kind: StringName, frames: int, push: Vector3, clip: StringName, amount: float, splat: int) -> void:
	if who.is_down():
		return
	var s := _state(who)
	if frames > 0 and kind != &"":
		s.set_stun(kind, frames)
		who.velocity.x = 0.0
		who.velocity.z = 0.0
		if who._stumble_left > 0:
			who._stumble_left = 0
			who._rig_param(&"lean", 0.0)
	s.set_push(push, splat)
	if clip != &"" and who._rig_has(clip):
		if who.rig.has_method("_size_hit"):
			who.rig.call("_size_hit", clip, amount, maxi(frames, 1) if not String(clip).begins_with("hit_") else 0)
		who.rig.call("play", clip, 0.034)


## A push that met a wall (kernel/feel/hit_state.gd): hit-stop 8 on him alone, then WALLSPLAT.
static func _splat(who: TLBiped, normal: Vector3, frames: int) -> void:
	wall_splat(who, normal, null, frames)


static func _wall_behind(who: TLBiped, away: Vector3, reach: float, attacker: TLBiped) -> Dictionary:
	if not who.is_inside_tree():
		return {}
	var from := who.global_position + Vector3.UP * who.body_radius() * 3.0
	var q := PhysicsRayQueryParameters3D.create(from, from + away * (reach + who.body_radius()))
	q.exclude = [who.get_rid(), attacker.get_rid()]
	var hit_: Dictionary = TLContext.space_state_of(who).intersect_ray(q)
	if hit_.is_empty() or not hit_.get("collider") is StaticBody3D:
		return {}
	return hit_


static func _result(contact: StringName, stop: int, attacker: TLBiped, defender: TLBiped) -> Dictionary:
	return {"contact": contact, "stop": stop,
		"attacker": stun_of(attacker), "attacker_frames": stun_left(attacker),
		"defender": stun_of(defender), "defender_frames": stun_left(defender)}


static func _side(who: TLBiped, from_dir: Vector3) -> String:
	var basis := who.global_basis if who.is_inside_tree() else who.basis
	var local := basis.orthonormalized().inverse() * Vector3(from_dir.x, 0, from_dir.z)
	if absf(local.x) > absf(local.z):
		return "right" if local.x > 0.0 else "left"
	return "front" if local.z <= 0.0 else "back"


static func _down(who: TLBiped, frames: int, source: Vector3) -> void:
	if frames <= 0:
		return
	if who._feel != null:
		who._feel.knocked_down()          # K8: a knockdown ends a stun and its push-back (a hit-stop keeps running)
	var standing := not who.is_down()
	var rising := who._rise_left > 0
	who._down_left = maxi(who._down_left, frames)
	who._rise_left = 0
	if who._stumble_left > 0:
		who._stumble_left = 0
		who._rig_param(&"lean", 0.0)
	if standing or rising:
		_fall(who, source, frames)
	if standing:
		who.downed.emit()


static func _fall(who: TLBiped, source: Vector3, frames: int) -> void:
	var speed := who.speed()
	var direction := "front"
	if source.x != 0.0 or source.z != 0.0:
		direction = _AWAY[_side(who, source)]
	elif speed > 0.5:
		direction = _AWAY[_side(who, -who.velocity)]
	var fall := StringName("fall_" + direction)
	who._get_up_clip = &""
	if who._rig_has(fall):
		who._get_up_clip = StringName("get_up_" + direction)
		# down() has no strength argument. The speed just after the shove
		# determines how quickly the hip hits the floor.
		if who.rig.has_method("_size_hit"):
			who.rig.call("_size_hit", fall, speed, frames)
		who.rig.call("play", fall, minf(0.067, frames / 60.0))
	elif who._rig_has(&"fall"):
		who.rig.call("play", &"fall", 0.15)
	elif who.rig != null:
		who._lying_by_tip = true
		who.rig.rotation.x = -PI * 0.5


static func _step_down(who: TLBiped) -> void:
	if who._down_left > 0:
		who._down_left -= 1
		if who._down_left == 0:
			who._rise_left = maxi(who.get_up_frames, 1)
			if who._get_up_clip != &"" and who._rig_has(who._get_up_clip):
				if who.rig.has_method("_size_hit"):
					who.rig.call("_size_hit", who._get_up_clip, 1.0, who._rise_left)
				who.rig.call("play", who._get_up_clip, minf(2.0, who._rise_left) / 60.0)
			elif who.rig != null and (who._get_up_clip != &"" or who._rig_has(&"fall")):
				who.rig.call("play", &"", who._rise_left / 60.0)
	elif who._rise_left > 0:
		who._rise_left -= 1
		if who._lying_by_tip and who.rig != null:
			who.rig.rotation.x = -PI * 0.5 * who._rise_left / float(maxi(who.get_up_frames, 1))
		if who._rise_left == 0:
			who._lying_by_tip = false
			who._get_up_clip = &""
			who.got_up.emit()
	if who._stumble_left > 0:
		who._stumble_left -= 1
		who._rig_param(&"lean", who._stumble_lean * float(who._stumble_left) / float(maxi(who._stumble_frames, 1)))
