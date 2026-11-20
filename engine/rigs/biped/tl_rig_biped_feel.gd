class_name TLRigBipedFeel
extends RefCounted
## Diorama night (20 Nov 2026): the toy feel of the diorama figure (TLRigBiped makes one when the style asks for the toy).
## Internal to the rig.
## Everything here is a function of the calls made so far (ticks, velocities, params): no clock, no random; two runs of
## the same calls give the same poses. The classic figure never makes one of these.
##   - secondary motion: the large head wobbles a little on its peg (a stiff spring, a few degrees), and the bun (the
##     `Hair` bone) is a damped spring that lags the head's own acceleration and the body's (start, stop, turn,
##     take-off, landing, every step of a run), on top of what the clip gives the bone; it squashes a little when the
##     head is pushed up under it;
##   - squash and stretch: the whole figure stretches as he leaves the floor and squashes as he lands (by the fall
##     speed), about his soles, and settles in two beats;
##   - hands that meet what they grab: with a `grip` (a line in the world: a ledge's edge, a bar) both arms are solved
##     so the palms lie on it above the shoulders.
## Who gets it: the bare-headed toy (the village walker, the parkour runner, any `mode = walk` figure). A helmeted skater
## has no bun to swing and does not jump or hang, and a hockey frame is held to 1.0 ms with ten of them in it (the classic
## figure meets that by under 1 %): TLRigBiped does not call this layer for him, so his tick costs what it did.
## Cost for the others: about 7 microseconds a tick. Nothing here asks the skeleton for a global pose unless a hand is
## being solved (the bun's push is read from the pose that was just applied), and a bone or the model's scale is written
## only when its value moved.

const DT: float = 1.0 / 60.0
const ARM_A: float = 0.27          # shoulder joint to elbow
const ARM_B: float = 0.25          # elbow to wrist
const PALM: float = 0.075          # wrist to the middle of the palm

var tuft: Vector2 = Vector2.ZERO   # x = pitch (deg, + = tips back), y = roll (deg, + = top towards -X)
var tuft_v: Vector2 = Vector2.ZERO
var nod: Vector2 = Vector2.ZERO    # the head's own small wobble on its peg (deg: x = pitch, y = roll), a stiffer spring on the same push
var nod_v: Vector2 = Vector2.ZERO
var puff: float = 0.0              # the bun's squash (+ = flatter)
var puff_v: float = 0.0
var sq: float = 0.0                # the figure's squash (+ = flatter and wider), 0 = at rest
var sq_v: float = 0.0
var grip_w: float = 0.0            # 0 = the clip's own arms .. 1 = the hands on the grip
var grip_at: Vector3 = Vector3.ZERO
var grip_along: Vector3 = Vector3.RIGHT
var _p1: Vector3 = Vector3.ZERO    # the bun's joint (skeleton space) at the last two ticks
var _p2: Vector3 = Vector3.ZERO
var _seen: int = 0
var _v1: Vector3 = Vector3.ZERO
var _stepped: bool = false         # one spring step per tick (a pose applied again on entering the tree steps nothing)
var _pose_seen: Dictionary = {}    # the rig's pose of the last step: a new one = a new tick
var _was_grounded: bool = true
var _b_hair: int = -2              # bone indices, looked up once
var _b_head: int = -1
var _scale_set: float = 0.0        # the squash the model's scale shows
var _puff_set: float = 0.0
var _host: Node = null             # the controller above the rig, and whether it can say what its hands hold
var _host_grips: bool = false


## An impulse on the squash spring: + = a landing (m/s of fall), - = a take-off.
func kick(v: float) -> void:
	sq_v += v


## The toy's layer on the finished pose (TLRigBiped._post_pose): squash impulses from take-off and landing, hands onto what
## they hold, then the springs (bun, head, squash). A pose applied again without a tick (the rig enters the tree) steps nothing.
func post(rig: TLRigBiped) -> void:
	var first: bool = not is_same(rig._last, _pose_seen)
	_pose_seen = rig._last
	_stepped = not first
	var sk: Skeleton3D = rig._sk
	if _b_hair == -2:
		_b_hair = sk.find_bone("Hair")
		_b_head = sk.find_bone("Head")
	if first:
		if rig.frame % 30 == 0 or _host == null:
			TLRigBipedToy.sync()
			var host: Node = rig.get_parent()      # the controller above the rig: can it say what its hands hold?
			if host != _host:
				_host = host
				_host_grips = host != null and host.get("ledge_top") is Vector3 and host.get("bar_point") is Vector3
		if rig._loco_on and _was_grounded and not rig._grounded and rig._air_vy > 2.0:
			kick(-2.6)                                              # he leaves the floor: a stretch
		elif rig._loco_on and not _was_grounded and rig._grounded:
			kick(clampf(rig._impact * 0.26, 0.6, 3.4))              # he lands: a squash by the fall speed
		_was_grounded = rig._grounded
	var grip: Variant = grip_of(rig) if (first and (_host_grips or rig.params.has("grip"))) else null
	if grip != null or grip_w > 0.0:
		hold(sk, grip, first)
	var sc: float = float(rig.params["scale"])
	apply(rig, sc)


## What the hands hold this tick, as a line in the world: the `grip` param when a controller set one, else what the
## controller above the rig says about itself (the village visitor and TLBiped both answer `ledge_top`, `wall_normal`,
## `mantle_progress`, `bar_point`, `bar_axis`; the body's move is `walker_motion()` or `mode`). Null = nothing held.
func grip_of(rig: TLRigBiped) -> Variant:
	var g: Variant = rig.params.get("grip", null)
	if g is Dictionary:
		return g
	var host: Node = _host
	if not _host_grips or not is_instance_valid(host):
		return null
	var m: String = str(host.call("walker_motion")) if host.has_method("walker_motion") else str(host.get("mode"))
	if m == "bar" and host.get("bar_axis") is Vector3:
		return {"at": host.get("bar_point"), "along": host.get("bar_axis")}
	if (m == "hang" or m == "mantle") and host.get("wall_normal") is Vector3:
		var k: float = 1.0 if m == "hang" else 1.0 - smoothstep(0.3, 0.62, float(host.get("mantle_progress")))
		return {"at": host.get("ledge_top"), "along": (host.get("wall_normal") as Vector3).cross(Vector3.UP), "k": k}
	return null


## Walking and running, the head rolls with each step and the arms swing wider and a little out: a toy walks with his whole body.
## `up` = the gait's upper-body pose (changed in place); s = the stride's swing (+ = left leg ahead), sw = the arm swing in degrees.
func upper(up: Dictionary, s: float, sw: float, run_w: float, stick_on: bool) -> void:
	up["Head"] = (up["Head"] as Vector3) + Vector3(0, 0, -lerpf(3.2, 2.0, run_w) * s)
	up["Chest"] = (up["Chest"] as Vector3) + Vector3(0, 0, lerpf(2.0, 1.2, run_w) * s)
	if not stick_on:
		up["LeftUpperArm"] = (up["LeftUpperArm"] as Vector3) + Vector3(-0.16 * sw, 0, -lerpf(5.0, 3.0, run_w))
		up["RightUpperArm"] = (up["RightUpperArm"] as Vector3) + Vector3(0.16 * sw, 0, lerpf(5.0, 3.0, run_w))


## The toy's standing upper body over the classic idle pose `out` (locomotion at rest; the `idle` clip by name is the classic
## one): breath, a slow sway of the trunk over the standing legs, and every six seconds a look to one side and then the
## other. The legs are not touched: they are the classic gait's, bone for bone. t = seconds.
func idle(out: Dictionary, t: float, stick_on: bool) -> Dictionary:
	var ws: float = sin(TAU * t / 5.6)
	var br: float = sin(TAU * t / 3.2)
	# a look round: a smooth bump of 1.3 s, alternating sides, starting 2.2 s into every 6 s
	var u: float = fposmod(t, 6.0)
	var lk: float = smoothstep(2.2, 2.65, u) * (1.0 - smoothstep(3.1, 3.5, u))
	var side: float = 1.0 if int(floor(t / 6.0)) % 2 == 0 else -1.0
	out["Spine"] = (out["Spine"] as Vector3) + Vector3(0, 0, -1.4 * ws)
	out["Chest"] = (out["Chest"] as Vector3) + Vector3(-1.2 * br, 6.0 * lk * side, -1.6 * ws)
	out["Neck"] = (out["Neck"] as Vector3) + Vector3(0, 10.0 * lk * side, 0)
	out["Head"] = (out["Head"] as Vector3) + Vector3(-2.0 * lk, 24.0 * lk * side - 4.0 * lk, 2.2 * ws)
	out["LeftShoulder"] = Vector3(0, 0, -2.0 - 2.0 * br)
	out["RightShoulder"] = Vector3(0, 0, 2.0 + 2.0 * br)
	if not stick_on:
		out["LeftUpperArm"] = (out["LeftUpperArm"] as Vector3) + Vector3(3.0 * ws, 0, -4.0 - 1.5 * br)
		out["RightUpperArm"] = (out["RightUpperArm"] as Vector3) + Vector3(-3.0 * ws, 0, 4.0 + 1.5 * br)
	return out


## After the pose is on the bones: one step of the springs (once per tick), then the bun, the head and the squash.
## The push on the bun is read from the pose that was just applied (the hips' offset and turn, the head's turn: where the
## crown is, near enough) and from the body's velocity in the rig's axes: no global pose is asked of the skeleton.
func apply(rig: TLRigBiped, base_scale: float) -> void:
	if _b_hair < 0:
		return
	var sk: Skeleton3D = rig._sk
	if not _stepped:
		_stepped = true
		var q: Dictionary = rig._last["q"]
		var qh: Quaternion = q.get(rig._root_bone, Quaternion.IDENTITY)
		var qc: Quaternion = q.get(_b_head, Quaternion.IDENTITY)
		var p: Vector3 = (rig._last["h"] as Vector3) + qh * (Vector3(0.0, 0.58, 0.0) + qc * Vector3(0.06, 0.44, 0.1))
		var vel: Vector3 = rig._vel / base_scale
		var acc: Vector3 = Vector3.ZERO
		if _seen >= 2:
			acc = (p - 2.0 * _p1 + _p2) / (DT * DT)
			if rig._loco_on:
				acc += (vel - _v1) / DT
		_seen += 1
		_p2 = _p1
		_p1 = p
		_v1 = vel
		acc = acc.limit_length(42.0)
		# the bun leans away from the push (its weight sits behind the crown: a push up tips it back too)
		# six damped springs, stepped in place (velocity first, then the value): the bun's pitch and roll, the head's,
		# the bun's squash, the figure's squash
		var tvx: float = tuft_v.x + (520.0 * (clampf(-0.5 * acc.z + 0.3 * acc.y, -20.0, 20.0) - tuft.x) - 12.5 * tuft_v.x) * DT
		var tvz: float = tuft_v.y + (520.0 * (clampf(0.55 * acc.x, -18.0, 18.0) - tuft.y) - 12.5 * tuft_v.y) * DT
		tuft = Vector2(clampf(tuft.x + tvx * DT, -24.0, 24.0), clampf(tuft.y + tvz * DT, -22.0, 22.0))
		tuft_v = Vector2(tvx, tvz)
		var nvx: float = nod_v.x + (760.0 * (clampf(-0.16 * acc.z + 0.1 * acc.y, -5.0, 5.0) - nod.x) - 21.0 * nod_v.x) * DT
		var nvz: float = nod_v.y + (760.0 * (clampf(0.2 * acc.x, -5.0, 5.0) - nod.y) - 21.0 * nod_v.y) * DT
		nod = Vector2(clampf(nod.x + nvx * DT, -6.0, 6.0), clampf(nod.y + nvz * DT, -6.0, 6.0))
		nod_v = Vector2(nvx, nvz)
		puff_v += (620.0 * (clampf(acc.y * 0.0026, -0.07, 0.1) - puff) - 17.0 * puff_v) * DT
		puff = clampf(puff + puff_v * DT, -0.09, 0.12)
		sq_v += (300.0 * (0.0 - sq) - 13.0 * sq_v) * DT
		sq = clampf(sq + sq_v * DT, -0.12, 0.16)
	# a spring at rest writes nothing: the clip's own pose stands (it was applied fresh this tick)
	if absf(tuft.x) + absf(tuft.y) > 0.01:
		sk.set_bone_pose_rotation(_b_hair, Quaternion.from_euler(Vector3(deg_to_rad(tuft.x), 0.0, deg_to_rad(tuft.y))) * sk.get_bone_pose_rotation(_b_hair))
	if absf(nod.x) + absf(nod.y) > 0.01:
		sk.set_bone_pose_rotation(_b_head, sk.get_bone_pose_rotation(_b_head) * Quaternion.from_euler(Vector3(deg_to_rad(nod.x), 0.0, deg_to_rad(nod.y))))
	var pf: float = puff if absf(puff) > 0.0005 else 0.0
	if pf != _puff_set:
		_puff_set = pf
		sk.set_bone_pose_scale(_b_hair, Vector3(1.0 + pf * 0.5, 1.0 - pf, 1.0 + pf * 0.5))
	var sqs: float = sq if absf(sq) > 0.0003 else 0.0
	if sqs != _scale_set or rig._model.scale.y != (1.0 - sqs) * base_scale:
		_scale_set = sqs
		rig._model.scale = Vector3(1.0 + sqs * 0.5, 1.0 - sqs, 1.0 + sqs * 0.5) * base_scale


## Two-bone arm: the palm of `side` ("Left" / "Right") goes to `target` (skeleton space), blended by w over the clip's arm.
## `pole` = where the elbow points (skeleton space, any length).
static func arm_to(sk: Skeleton3D, side: String, target: Vector3, pole: Vector3, w: float) -> void:
	if w <= 0.0:
		return
	var iu: int = sk.find_bone(side + "UpperArm")
	var il: int = sk.find_bone(side + "LowerArm")
	var ih: int = sk.find_bone(side + "Hand")
	var par: Transform3D = sk.get_bone_global_pose(sk.get_bone_parent(iu))
	var s: Vector3 = sk.get_bone_global_pose(iu).origin
	var b: float = ARM_B + PALM
	var d: Vector3 = target - s
	var dl: float = clampf(d.length(), 0.12, ARM_A + b - 0.004)
	var n: Vector3 = d.normalized() if d.length() > 0.0001 else Vector3.DOWN
	var cos_a: float = clampf((ARM_A * ARM_A + dl * dl - b * b) / (2.0 * ARM_A * dl), -1.0, 1.0)
	var sin_a: float = sqrt(maxf(0.0, 1.0 - cos_a * cos_a))
	var m: Vector3 = pole - n * pole.dot(n)
	m = m.normalized() if m.length() > 0.0001 else n.cross(Vector3.RIGHT).normalized()
	var u: Vector3 = (n * cos_a + m * sin_a).normalized()            # shoulder to elbow
	var f: Vector3 = (n * dl - u * ARM_A).normalized()               # elbow to palm
	var x: Vector3 = u.cross(f)
	x = x.normalized() if x.length() > 0.0005 else u.cross(m).normalized()
	var qu: Quaternion = Basis(x, -u, x.cross(-u)).orthonormalized().get_rotation_quaternion()
	var ql: Quaternion = Basis(x, -f, x.cross(-f)).orthonormalized().get_rotation_quaternion()
	var pq: Quaternion = par.basis.orthonormalized().get_rotation_quaternion()
	sk.set_bone_pose_rotation(iu, sk.get_bone_pose_rotation(iu).slerp(pq.inverse() * qu, w))
	sk.set_bone_pose_rotation(il, sk.get_bone_pose_rotation(il).slerp(qu.inverse() * ql, w))
	sk.set_bone_pose_rotation(ih, sk.get_bone_pose_rotation(ih).slerp(Quaternion.IDENTITY, w))


## Both palms onto a line in the world (the edge of a ledge, a bar), each at the point of the line nearest its shoulder.
## `grip` = {"at": Vector3, "along": Vector3} in the world, or null: the hands ease on over 8 ticks and off over 5.
func hold(sk: Skeleton3D, grip: Variant, first: bool) -> void:
	var on: bool = grip is Dictionary and (grip as Dictionary).get("at") is Vector3 and sk.is_inside_tree()
	if first:
		if on:
			var g: Dictionary = grip
			var inv: Transform3D = sk.global_transform.affine_inverse()
			grip_at = inv * (g["at"] as Vector3)
			var al: Vector3 = inv.basis * (g.get("along", Vector3.RIGHT) as Vector3)
			grip_along = al.normalized() if al.length() > 0.0001 else Vector3.RIGHT
			grip_w = move_toward(grip_w, clampf(float(g.get("k", 1.0)), 0.0, 1.0), 0.125)
		else:
			grip_w = move_toward(grip_w, 0.0, 0.2)
	if grip_w <= 0.0:
		return
	var w: float = grip_w * grip_w * (3.0 - 2.0 * grip_w)
	# the body hangs from its hands: when the line is further than the arms reach, the whole figure is drawn towards it
	# (the controller hangs the capsule by a fixed sink; the arms are 0.6 m)
	var reach: float = ARM_A + ARM_B + PALM - 0.012
	var pull: Vector3 = Vector3.ZERO
	for name: String in ["Left", "Right"]:
		var s0: Vector3 = sk.get_bone_global_pose(sk.find_bone(name + "UpperArm")).origin
		var d0: Vector3 = grip_at + grip_along * (s0 - grip_at).dot(grip_along) - s0
		if d0.length() > reach:
			pull += d0.normalized() * (d0.length() - reach) * 0.5
	if pull.length() > 0.0005:
		var root: int = sk.find_bone("Hips")
		sk.set_bone_pose_position(root, sk.get_bone_pose_position(root) + pull.limit_length(0.3) * w)
	for side: Array in [["Left", -1.0], ["Right", 1.0]]:
		var s: Vector3 = sk.get_bone_global_pose(sk.find_bone(String(side[0]) + "UpperArm")).origin
		var t: Vector3 = grip_at + grip_along * (s - grip_at).dot(grip_along)
		arm_to(sk, String(side[0]), t, Vector3(float(side[1]) * 0.9, -0.5, -0.35), w)
