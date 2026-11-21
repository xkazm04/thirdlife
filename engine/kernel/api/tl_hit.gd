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


const _AWAY := {"front": "back", "back": "front", "right": "left", "left": "right"}


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


static func _side(who: TLBiped, from_dir: Vector3) -> String:
	var basis := who.global_basis if who.is_inside_tree() else who.basis
	var local := basis.orthonormalized().inverse() * Vector3(from_dir.x, 0, from_dir.z)
	if absf(local.x) > absf(local.z):
		return "right" if local.x > 0.0 else "left"
	return "front" if local.z <= 0.0 else "back"


static func _down(who: TLBiped, frames: int, source: Vector3) -> void:
	if frames <= 0:
		return
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
