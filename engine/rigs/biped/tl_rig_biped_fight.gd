class_name TLRigBipedFight
extends RefCounted
## The biped's fight clips (lane L2 fight-clips, 21 Nov 2026): strike, strike_heavy, block, roll, dodge, body_check,
## cross_check, taunt, and the `stick_yaw` turn of the upper body and stick. Pose functions as every biped clip
## (`{BoneName: Vector3(degrees), "_hips": Vector3(metres)}`; +x swings a hanging limb forward and tips an upright bone
## back, +y turns left, +z rolls the top towards -X). One instance per biped (TLRigBiped._fight) keeps the little state
## the clips need: the side a dodge goes, the weight of the cross-check grip, the stick turn. Internal to the rig, not
## pack API: packs play the clips by name (`rig.play(&"strike")`) and set `rig.set_param(&"stick_yaw", radians)`.
## TIMING is the table of RIGS.md "Fight clips" (frames at 60 Hz); the selftest block 660 holds the two together.

const DT: float = 1.0 / 60.0
const Z: Vector3 = Vector3.ZERO
## clip -> frames (the clip's length), anticipation (frames 0..a: the wind-up a defender can read), active (a..b: the
## blow or the move itself), control (the frame from which the pack may play the next clip), end ("returns" to
## locomotion after `frames`, or "holds" its last pose until another play), upper (the legs keep the locomotion while
## the rig moves faster than 0.8 m/s), blend (the most blend-in it takes, seconds: the wind-up must show at once),
## hit (the frame a pack tests its hit box, or for block the frame the guard counts; absent for a move that hits nothing).
const TIMING: Dictionary = {
	"strike": {"frames": 16, "anticipation": 3, "active": 6, "hit": 5, "control": 12, "end": "returns", "upper": true, "blend": 0.034},
	"strike_heavy": {"frames": 30, "anticipation": 10, "active": 14, "hit": 13, "control": 26, "end": "returns", "upper": false, "blend": 0.05},
	"block": {"frames": 5, "anticipation": 0, "active": 4, "hit": 4, "control": 4, "end": "holds", "upper": true, "blend": 0.034},
	"roll": {"frames": 24, "anticipation": 4, "active": 20, "control": 20, "end": "returns", "upper": false, "blend": 0.034},
	"dodge": {"frames": 14, "anticipation": 2, "active": 9, "control": 11, "end": "returns", "upper": false, "blend": 0.034},
	"body_check": {"frames": 30, "anticipation": 7, "active": 15, "hit": 12, "control": 24, "end": "returns", "upper": false, "blend": 0.05},
	"cross_check": {"frames": 14, "anticipation": 6, "active": 11, "hit": 10, "control": 11, "end": "holds", "upper": true, "blend": 0.05},
	"taunt": {"frames": 90, "anticipation": 0, "active": 78, "control": 60, "end": "returns", "upper": false, "blend": 0.15},
}
## Clips whose left hand the cel and clay figures put on the shaft when the biped holds a stick (clay_rig._post_pose).
## (body_check is not one: there the stick trails in the right hand while the left arm drives.)
const STICK_CLIPS: Array[StringName] = [&"cross_check"]
const SLIDE: float = 0.47           # cross_check: the stick slides this far up through the right hand (the shaft centred between the hands)
const YAW_MIN: float = -1.2          # stick_yaw is clamped to -1.2 .. +2.0 rad: the blade rests out to the right (bearing
const YAW_MAX: float = 2.0           # -0.46 rad classic, -0.98 rad cel / clay), so the reach across to the left is the longer
const YAW_SHARE: Vector3 = Vector3(0.45, 0.55, -0.55)   # of stick_yaw: Chest, UpperChest about the vertical; the Neck turns back

var yaw: float = 0.0                 # stick_yaw (radians, + = left), set through set_param
var side: float = 1.0                # the dodge: +1 = to the right, -1 = to the left (latched on the clip's first tick)
var dodge_side: float = 0.0          # set_param dodge_side: -1 left, +1 right, 0 = the side the body moves
var grip: float = 0.0                # 0..1: how far the right hand has turned the shaft across the chest (cross_check)
var _frame: int = -1
var _bones: PackedInt32Array = PackedInt32Array()


## Adds the eight clips to a biped (TLRigBiped.setup). The lambdas read the rig's state at the tick they run.
func add_clips(rig: TLRigBiped) -> void:
	var fns: Dictionary = {
		"strike": func(t: float) -> Dictionary: return strike(t),
		"strike_heavy": func(t: float) -> Dictionary: return strike_heavy(t),
		"block": func(t: float) -> Dictionary: return block(t),
		"roll": func(t: float) -> Dictionary: return roll(t),
		"dodge": func(t: float) -> Dictionary: return dodge(t, rig),
		"body_check": func(t: float) -> Dictionary: return body_check(t, rig),
		"cross_check": func(t: float) -> Dictionary: return cross_check(t, rig),
		"taunt": func(t: float) -> Dictionary: return taunt(t),
	}
	for cname: String in TIMING:
		var tm: Dictionary = TIMING[cname]
		rig.add_clip(cname, float(tm["frames"]) * DT, false, fns[cname], bool(tm["upper"]), String(tm["end"]) == "holds")


## The fight params of TLRigBiped.set_param: stick_yaw (radians), dodge_side (-1, 0, +1).
func set_param(pname: String, value: Variant) -> void:
	if pname == "stick_yaw":
		yaw = float(value)
	else:
		dodge_side = signf(float(value))


## The blend-in a clip really gets (TLRigBiped._blend_of): a fight clip's wind-up is never hidden in a long blend.
static func blend_of(cname: StringName, blend: float) -> float:
	var tm: Dictionary = TIMING.get(String(cname), {})
	return minf(blend, float(tm["blend"])) if not tm.is_empty() else blend


# ------------------------------------------------------------------ helpers
static func _over(base: Dictionary, b: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate()
	out.merge(b, true)
	return out


## Keyed poses with an easing per segment: keys = [[seconds, pose, ease], ...]; the ease of a key shapes the segment
## that ends on it: 0 smooth in and out, 1 accelerating (a blow that is fastest at the hit), 2 decelerating, 3 linear.
static func _ease_keys(t: float, keys: Array) -> Dictionary:
	if t <= float(keys[0][0]):
		return keys[0][1]
	for i: int in range(1, keys.size()):
		var t1: float = float(keys[i][0])
		if t <= t1:
			var t0: float = float(keys[i - 1][0])
			var k: float = clampf((t - t0) / maxf(t1 - t0, 0.0001), 0.0, 1.0)
			match int(keys[i][2]):
				1: k = k * k
				2: k = 1.0 - (1.0 - k) * (1.0 - k)
				3: pass
				_: k = k * k * (3.0 - 2.0 * k)
			return TLRigBiped._mixe(keys[i - 1][1], keys[i][1], k)
	return keys[keys.size() - 1][1]


## The hips' drop for two legs of knee half-angle a, swung +-s degrees and spread `spread` degrees out (feet flat).
static func _drop(a: float, s: float, spread: float) -> float:
	return -TLRigBiped.CROUCH * (1.0 - cos(deg_to_rad(a)) * cos(deg_to_rad(s)) * cos(deg_to_rad(spread)))


## Both legs under a pelvis pitched `pitch`: knee half-angle a, the left leg swung +s (forward), the right -s.
static func _legs(a: float, pitch: float, s: float, spread: float) -> Dictionary:
	var l: Array = TLRigBiped._leg(a, pitch, s)
	var r: Array = TLRigBiped._leg(a, pitch, -s)
	return {
		"LeftUpperLeg": Vector3(float(l[0]), 0, -spread), "LeftLowerLeg": Vector3(float(l[1]), 0, 0), "LeftFoot": Vector3(float(l[2]), 0, spread), "LeftToes": Z,
		"RightUpperLeg": Vector3(float(r[0]), 0, spread), "RightLowerLeg": Vector3(float(r[1]), 0, 0), "RightFoot": Vector3(float(r[2]), 0, -spread), "RightToes": Z,
	}


## The fighting guard every fist clip starts from and returns to: left foot ahead, knees soft, the body turned a little
## so the left shoulder leads, both fists up in front of the chin.
static func guard() -> Dictionary:
	var p: Dictionary = {
		"_hips": Vector3(0, _drop(18.0, 12.0, 7.0), 0), "Hips": Vector3(-6.0, -16.0, 0),
		"Spine": Vector3(-3.0, 4.0, 0), "Chest": Vector3(-4.0, 6.0, 0), "UpperChest": Z, "Neck": Vector3(3.0, 2.0, 0), "Head": Vector3(6.0, 4.0, 0),
		"LeftShoulder": Z, "RightShoulder": Z, "Backpack": Z, "Hair": Z,
		"LeftUpperArm": Vector3(44.0, -14.0, -16.0), "LeftLowerArm": Vector3(112.0, 0, 0), "LeftHand": Vector3(-10.0, 0, 0),
		"RightUpperArm": Vector3(32.0, 12.0, 18.0), "RightLowerArm": Vector3(120.0, 0, 0), "RightHand": Vector3(-10.0, 0, 0),
	}
	p.merge(_legs(18.0, -6.0, 12.0, 7.0))
	return p


# ------------------------------------------------------------------ the clips
## The left foot leads. Each leg has its own [knee half-angle, swing from vertical] in degrees.
## Lower the pelvis to the longer leg's standing height, so the shorter leg can unweight its foot.
static func _swing_stance(p: Dictionary, shift: Vector2, lead: Vector2, rear: Vector2, spread: float) -> void:
	var pitch: float = p["Hips"].x
	var l := TLRigBiped._leg(lead.x, pitch, lead.y)
	var r := TLRigBiped._leg(rear.x, pitch, rear.y)
	p["LeftUpperLeg"] = Vector3(l[0], 0, -spread)
	p["LeftLowerLeg"] = Vector3(l[1], 0, 0)
	p["LeftFoot"] = Vector3(l[2], 0, spread)
	p["RightUpperLeg"] = Vector3(r[0], 0, spread)
	p["RightLowerLeg"] = Vector3(r[1], 0, 0)
	p["RightFoot"] = Vector3(r[2], 0, -spread)
	p["_hips"] = Vector3(shift.x, maxf(_drop(lead.x, lead.y, spread), _drop(rear.x, rear.y, spread)), shift.y)


## Light swing. The fist stays at the ear while the hips start the step, then cuts across at shoulder height.
static func strike(t: float) -> Dictionary:
	var g := guard()
	var wind := _over(g, {
		"Hips": Vector3(-5, -22, 0), "Spine": Vector3(1, -12, -2), "Chest": Vector3(1, -18, -2),
		"Neck": Vector3(1, 17, 0), "Head": Vector3(3, 24, 0),
		"RightUpperArm": Vector3(109, -28, 49), "RightLowerArm": Vector3(109, 0, -40),
		"LeftUpperArm": Vector3(48, 0, -16), "LeftLowerArm": Vector3(104, 0, 0)})
	_swing_stance(wind, Vector2(.055, .075), Vector2(18, 23), Vector2(27, -6), 7)
	# Counterturn the chest for one frame as the pelvis comes through underneath it.
	var step := _over(wind, {"Hips": Vector3(-8, 2, 1), "Spine": Vector3(-1, -29, -1),
		"Chest": Vector3(1, -22, -2), "RightUpperArm": Vector3(111, -30, 52)})
	_swing_stance(step, Vector2(.01, -.035), Vector2(23, 23), Vector2(20, -19), 7)
	# Recoil and parried start from this exact contact key.
	var hit: Dictionary = _over(g, {
		"Hips": Vector3(-12.0, 8.0, 0), "Spine": Vector3(-6.0, 10.0, 0), "Chest": Vector3(-6.0, 18.0, 0), "Neck": Vector3(4.0, -10.0, 0), "Head": Vector3(8.0, -16.0, 0),
		"RightUpperArm": Vector3(0, 84.0, 86.0), "RightLowerArm": Vector3(0, 0, 0), "RightHand": Vector3(8.0, 0, 0),
		"LeftUpperArm": Vector3(14.0, -10.0, -30.0), "LeftLowerArm": Vector3(110.0, 0, 0)})
	hit.merge(_legs(22.0, -12.0, 16.0, 7.0), true)
	hit["_hips"] = Vector3(-0.02, _drop(22.0, 16.0, 7.0), -0.10)
	var follow := _over(hit, {
		"Hips": Vector3(-8, 16, 2), "Spine": Vector3(-3, 18, 2), "Chest": Vector3(1, 28, 0),
		"Neck": Vector3(1, -18, 0), "Head": Vector3(6, -26, 0),
		"RightUpperArm": Vector3(32, 128, 100), "RightLowerArm": Vector3(32, 0, -1),
		"LeftUpperArm": Vector3(12, -18, -26)})
	_swing_stance(follow, Vector2(-.065, -.17), Vector2(26, 19), Vector2(18, -25), 7)
	return _ease_keys(t, [[0, g, 0], [3 * DT, wind, 2], [4 * DT, step, 3], [5 * DT, hit, 1],
		[8 * DT, follow, 2], [12 * DT, follow, 3], [16 * DT, g, 0]])


## Overhead chop. Sink onto the rear leg under the raised hands, then catch the fall on the bent lead knee.
static func strike_heavy(t: float) -> Dictionary:
	var g := guard()
	var coil := _over(g, {
		"Hips": Vector3(7, -12, 0), "Spine": Vector3(11, -4, -2), "Chest": Vector3(12, -5, -2),
		"RightShoulder": Vector3(0, 0, 34), "LeftShoulder": Vector3(0, 0, -34),
		"Neck": Vector3(-11, 6, 0), "Head": Vector3(-24, 10, 0),
		"RightUpperArm": Vector3(156, -8, 55), "RightLowerArm": Vector3(34, 0, -33), "RightHand": Vector3(-24, 0, 0),
		"LeftUpperArm": Vector3(158, 12, -52), "LeftLowerArm": Vector3(34, 0, 41), "LeftHand": Vector3(-25, 0, 0)})
	_swing_stance(coil, Vector2(.09, .14), Vector2(23, 30), Vector2(34, -4), 10)
	var peak := TLRigNode.add_pose(coil, {
		"Spine": Vector3(3, -2, 0), "Chest": Vector3(4, -2, 0),
		"RightUpperArm": Vector3(-8, 9, -5), "LeftUpperArm": Vector3(-8, -9, 5),
		"RightLowerArm": Vector3(-10, 0, 5), "LeftLowerArm": Vector3(-10, 0, -5)})
	_swing_stance(peak, Vector2(.105, .16), Vector2(24, 31), Vector2(35, -3), 10)
	var hit := _over(g, {
		"Hips": Vector3(-22, 1, 0), "Spine": Vector3(-10, 1, 0), "Chest": Vector3(-8, 2, 0),
		"Neck": Vector3(8, 0, 0), "Head": Vector3(16, -2, 0),
		"RightUpperArm": Vector3(98, 4, -13), "RightLowerArm": Vector3(9, 0, -5), "RightHand": Vector3(4, 0, 0),
		"LeftUpperArm": Vector3(100, -4, 12), "LeftLowerArm": Vector3(12, 0, 5), "LeftHand": Vector3(4, 0, 0)})
	_swing_stance(hit, Vector2(-.08, -.25), Vector2(41, 21), Vector2(21, -40), 9)
	var low := _over(hit, {
		"Hips": Vector3(-25, 3, 0), "Spine": Vector3(-12, 1, 0), "Chest": Vector3(-8, 2, 0),
		"RightHand": Vector3(38, 0, 0), "LeftHand": Vector3(30, 0, 0),
		"Head": Vector3(12, -3, 0), "RightUpperArm": Vector3(55, 2, -15), "LeftUpperArm": Vector3(58, -2, 15)})
	_swing_stance(low, Vector2(-.105, -.32), Vector2(46, 19), Vector2(22, -44), 9)
	# Recover the weight first. The hands still hang low when control returns.
	var rise := _over(low, {
		"Hips": Vector3(-14, -3, 0), "Spine": Vector3(-9, 0, 0), "Chest": Vector3(-6, 2, 0),
		"RightUpperArm": Vector3(33, 2, -6), "LeftUpperArm": Vector3(38, -3, 8),
		"RightHand": Vector3(18, 0, 0), "LeftHand": Vector3(14, 0, 0),
		"RightLowerArm": Vector3(32, 0, 0), "LeftLowerArm": Vector3(38, 0, 0)})
	_swing_stance(rise, Vector2(-.04, -.14), Vector2(33, 12), Vector2(20, -29), 8)
	return _ease_keys(t, [[0, g, 0], [8 * DT, coil, 2], [10 * DT, peak, 3], [13 * DT, hit, 1],
		[16 * DT, low, 2], [20 * DT, low, 3], [26 * DT, rise, 1], [30 * DT, g, 0]])


## A covering guard that holds (5 f, then holds until another play): both forearms up in front of the face with the
## elbows thrown out wide (a W from the front, a wide ring from above), shoulders shrugged, the body turned a little
## side-on and crouched low on a wide braced stance. Overshoots at f3; the guard counts from f4 (hit). With `upper`,
## he can walk behind it. (Round L2b: of five tries the wide elbows were the one that read at both game cameras.)
static func block(t: float) -> Dictionary:
	var g: Dictionary = guard()
	var b: Dictionary = _over(g, {
		"_hips": Vector3(0, _drop(40.0, 12.0, 13.0), 0.05), "Hips": Vector3(-16.0, -30.0, 0),
		"Spine": Vector3(-10.0, 8.0, 0), "Chest": Vector3(-10.0, 6.0, 0), "UpperChest": Vector3(-4.0, 0, 0), "Neck": Vector3(-4.0, 4.0, 0), "Head": Vector3(2.0, 10.0, 0),
		"LeftShoulder": Vector3(0, 0, -14.0), "RightShoulder": Vector3(0, 0, 14.0),
		"LeftUpperArm": Vector3(96.0, -10.0, -62.0), "LeftLowerArm": Vector3(84.0, 0, 0), "LeftHand": Vector3(-10.0, 0, 0),
		"RightUpperArm": Vector3(96.0, 10.0, 62.0), "RightLowerArm": Vector3(84.0, 0, 0), "RightHand": Vector3(-10.0, 0, 0)})
	b.merge(_legs(40.0, -16.0, 12.0, 13.0), true)
	var over: Dictionary = TLRigNode.add_pose(b, {"LeftUpperArm": Vector3(10.0, 0, -6.0), "RightUpperArm": Vector3(10.0, 0, 6.0), "Chest": Vector3(-4.0, 0, 0), "_hips": Vector3(0, -0.03, 0)})
	return _ease_keys(t, [[0.0, g, 0], [3 * DT, over, 2], [4 * DT, b, 0], [5 * DT, b, 3]])


## A forward roll (24 f): he drops and reaches (f0-4), turns once over a tucked ball (thighs to the chest, chin down,
## hands on the shins) about a point 0.45 m over the floor, and opens out into a crouch by f24. The clip only turns the
## figure about its own root: the pack moves the body.
static func roll(t: float) -> Dictionary:
	var f: float = t / DT
	var th: float
	if f < 4.0:
		th = -35.0 * (f / 4.0) * (f / 4.0)
	elif f < 20.0:
		th = -35.0 - 300.0 * (f - 4.0) / 16.0
	else:
		var k: float = clampf((f - 20.0) / 4.0, 0.0, 1.0)
		th = -335.0 - 25.0 * (1.0 - (1.0 - k) * (1.0 - k))
	var w: float = smoothstep(0.0, 5.0, f) * (1.0 - smoothstep(17.0, 24.0, f))
	var crouch: Dictionary = {
		"_hips": Vector3(0, _drop(40.0, 6.0, 6.0), 0), "Hips": Vector3(-24.0, 0, 0), "Spine": Vector3(-8.0, 0, 0), "Chest": Vector3(-6.0, 0, 0), "UpperChest": Z,
		"Neck": Vector3(8.0, 0, 0), "Head": Vector3(16.0, 0, 0), "LeftShoulder": Z, "RightShoulder": Z, "Backpack": Z, "Hair": Z,
		"LeftUpperArm": Vector3(50.0, 0, -16.0), "LeftLowerArm": Vector3(40.0, 0, 0), "LeftHand": Z,
		"RightUpperArm": Vector3(50.0, 0, 16.0), "RightLowerArm": Vector3(40.0, 0, 0), "RightHand": Z,
	}
	crouch.merge(_legs(40.0, -24.0, 6.0, 6.0))
	var tuck: Dictionary = {
		"Spine": Vector3(-26.0, 0, 0), "Chest": Vector3(-22.0, 0, 0), "UpperChest": Vector3(-8.0, 0, 0), "Neck": Vector3(-24.0, 0, 0), "Head": Vector3(-30.0, 0, 0),
		"LeftShoulder": Z, "RightShoulder": Z, "Backpack": Z, "Hair": Vector3(10.0, 0, 0),
		"LeftUpperArm": Vector3(62.0, 0, -14.0), "LeftLowerArm": Vector3(84.0, 0, 0), "LeftHand": Z,
		"RightUpperArm": Vector3(62.0, 0, 14.0), "RightLowerArm": Vector3(84.0, 0, 0), "RightHand": Z,
		"LeftUpperLeg": Vector3(124.0, 0, -6.0), "LeftLowerLeg": Vector3(-148.0, 0, 0), "LeftFoot": Vector3(36.0, 0, 6.0), "LeftToes": Z,
		"RightUpperLeg": Vector3(124.0, 0, 6.0), "RightLowerLeg": Vector3(-148.0, 0, 0), "RightFoot": Vector3(36.0, 0, -6.0), "RightToes": Z,
	}
	var stand_w: float = 1.0 - smoothstep(0.0, 4.0, f) * (1.0 - smoothstep(20.0, 24.0, f))
	var pose: Dictionary = TLRigBiped._mixe(_over(crouch, {"Hips": Z, "_hips": Z}), tuck, w)
	pose["Hips"] = Vector3(th + (crouch["Hips"] as Vector3).x * stand_w * (1.0 - w), 0, 0)
	# the hips go round the ball's centre c (hips-local, tucked) held at 0.45 m over the floor
	var r: float = deg_to_rad(th)
	var c: Vector3 = Vector3(0, 0.20, -0.16)
	var ball: Vector3 = Vector3(0, 0.45 - 0.98 - (c.y * cos(r) - c.z * sin(r)), -(c.y * sin(r) + c.z * cos(r)))
	pose["_hips"] = (crouch["_hips"] as Vector3).lerp(ball, w)
	return pose


## A quick side step with a lean (14 f): a dip and push off the far foot (f0-2), the body leaning hard into the step
## with the pelvis out over the near foot and the head ducked (to f9), back on guard by f14. The side is the side the
## body is moving at the clip's first tick (`velocity_local.x`: + = right; standing still = right), unless the param
## `dodge_side` names it (-1 left, +1 right).
func dodge(t: float, rig: TLRigBiped) -> Dictionary:
	if rig.clip_t <= DT * 1.5:
		side = dodge_side if dodge_side != 0.0 else (-1.0 if rig._vel.x < 0.0 else 1.0)
	var s: float = side
	var g: Dictionary = guard()
	var dip: Dictionary = _over(g, {"_hips": Vector3(0, _drop(28.0, 12.0, 7.0), 0)})
	dip.merge(_legs(28.0, -6.0, 12.0, 7.0), true)
	var roll_z: float = -28.0 * s      # the top of the body leans towards the step
	var lean: Dictionary = _over(g, {
		"_hips": Vector3(0.2 * s, -0.14, 0), "Hips": Vector3(-10.0, -10.0 * s, roll_z),
		"Spine": Vector3(-8.0, 0, -8.0 * s), "Chest": Vector3(-6.0, 0, -6.0 * s), "Neck": Vector3(-10.0, 0, 10.0 * s), "Head": Vector3(-6.0, 0, 14.0 * s),
		"LeftUpperArm": Vector3(30.0, 0, -30.0 - 26.0 * maxf(s, 0.0)), "LeftLowerArm": Vector3(80.0, 0, 0),
		"RightUpperArm": Vector3(30.0, 0, 30.0 + 26.0 * maxf(-s, 0.0)), "RightLowerArm": Vector3(80.0, 0, 0),
	})
	# the near leg (on the side of the step) bends under the pelvis, the far one reaches long and pushes
	var near: String = "Right" if s > 0.0 else "Left"
	var far: String = "Left" if s > 0.0 else "Right"
	var ln: Array = TLRigBiped._leg(34.0, -10.0)
	var lf: Array = TLRigBiped._leg(14.0, -10.0)
	lean[near + "UpperLeg"] = Vector3(float(ln[0]), 0, -roll_z + 4.0 * s)
	lean[near + "LowerLeg"] = Vector3(float(ln[1]), 0, 0)
	lean[near + "Foot"] = Vector3(float(ln[2]), 0, -4.0 * s)
	lean[far + "UpperLeg"] = Vector3(float(lf[0]), 0, -roll_z - 30.0 * s)
	lean[far + "LowerLeg"] = Vector3(float(lf[1]), 0, 0)
	lean[far + "Foot"] = Vector3(float(lf[2]), 0, 30.0 * s)
	return _ease_keys(t, [[0.0, g, 0], [2 * DT, dip, 2], [5 * DT, lean, 2], [9 * DT, lean, 3], [14 * DT, g, 0]])


## A shoulder drive (30 f): he loads low and turned away with the trailing arm swung back (f0-7), then drives the left
## shoulder through the target: the body turned side-on and pitched forward, the pelvis surging 0.35 m, the left arm
## tucked with its elbow out ahead of the shoulder, the right arm flung back (f7-11). The contact pose holds f11-15 (hit
## f12); back to his stance by f30. With a stick it trails low in the right hand instead of being flung back.
func body_check(t: float, rig: TLRigBiped) -> Dictionary:
	var skate: bool = String(rig.params.get("mode", "walk")) == "skate"
	var base: Dictionary = rig._stance(-26.0) if skate else guard()
	var load: Dictionary = _over(base, {
		"_hips": Vector3(0.04, _drop(42.0, 10.0, 9.0), 0.10), "Hips": Vector3(-26.0, -24.0, 0),
		"Spine": Vector3(-8.0, -12.0, 0), "Chest": Vector3(-8.0, -16.0, 0), "UpperChest": Z, "Neck": Vector3(8.0, 20.0, 0), "Head": Vector3(18.0, 28.0, 0),
		"LeftShoulder": Z, "RightShoulder": Z,
		"LeftUpperArm": Vector3(30.0, 0, -24.0), "LeftLowerArm": Vector3(118.0, 0, 0), "LeftHand": Z,
		"RightUpperArm": Vector3(-40.0, 0, 44.0), "RightLowerArm": Vector3(40.0, 0, 0), "RightHand": Z})
	load.merge(_legs(42.0, -26.0, 10.0, 9.0), true)
	var drive: Dictionary = _over(load, {
		"_hips": Vector3(0.06, _drop(30.0, 30.0, 9.0), -0.35), "Hips": Vector3(-46.0, -44.0, 0),
		"Spine": Vector3(-10.0, -18.0, 4.0), "Chest": Vector3(-8.0, -22.0, 10.0), "UpperChest": Vector3(-4.0, -6.0, 0),
		"Neck": Vector3(16.0, 34.0, -6.0), "Head": Vector3(30.0, 40.0, -8.0),
		"LeftShoulder": Vector3(0, 16.0, 0), "LeftUpperArm": Vector3(44.0, 0, -36.0), "LeftLowerArm": Vector3(124.0, 0, 0),
		"RightUpperArm": Vector3(-14.0, 0, 78.0), "RightLowerArm": Vector3(16.0, 0, 0)})
	drive.merge(_legs(30.0, -46.0, 30.0, 9.0), true)
	if rig._stick_on:      # the stick trails low in the right hand
		load["RightUpperArm"] = Vector3(-20.0, 0, 46.0)
		load["RightLowerArm"] = Vector3(16.0, 0, 0)
		drive["RightUpperArm"] = Vector3(-30.0, 0, 62.0)
		drive["RightLowerArm"] = Vector3(10.0, 0, 0)
	var rise: Dictionary = TLRigNode.add_pose(drive, {"_hips": Vector3(0, 0.03, 0.05)})
	return _ease_keys(t, [[0.0, base, 0], [7 * DT, load, 2], [11 * DT, drive, 1], [15 * DT, drive, 3], [19 * DT, rise, 2], [30 * DT, base, 0]])


## A cross-check (14 f, then holds until another play): both hands on the stick, the shaft turned level across the
## chest (the butt at the left hand, the blade hanging at the right), pulled in tight with the elbows out wide and the
## body rocked back (f0-6), then punched forward and up to the opponent's face with the arms straight, a long step in
## and the whole body leaning into it (f6-10). The punch pose holds from f10 (hit). Without a stick the arms make the
## same shove. End it with play(&"") (or the next clip).
func cross_check(t: float, rig: TLRigBiped) -> Dictionary:
	var skate: bool = String(rig.params.get("mode", "walk")) == "skate"
	var base: Dictionary = rig._stance(-24.0) if skate else guard()
	var a: float = 32.0 if skate else 26.0
	var pull: Dictionary = _over(base, {
		"_hips": Vector3(0, _drop(a, 10.0, 9.0), 0.08), "Hips": Vector3(-8.0, 0, 0), "Spine": Vector3(8.0, 0, 0), "Chest": Vector3(8.0, 0, 0), "UpperChest": Vector3(4.0, 0, 0),
		"Neck": Vector3(-2.0, 0, 0), "Head": Vector3(4.0, 0, 0), "LeftShoulder": Vector3(0, 0, -8.0), "RightShoulder": Vector3(0, 0, 8.0),
		"RightUpperArm": Vector3(44.0, 0, 46.0), "RightLowerArm": Vector3(112.0, 0, 0), "RightHand": Z,
		"LeftUpperArm": Vector3(44.0, 0, -46.0), "LeftLowerArm": Vector3(112.0, 0, 0), "LeftHand": Z})
	pull.merge(_legs(a, -8.0, 10.0, 9.0), true)
	var push: Dictionary = _over(pull, {
		"_hips": Vector3(0, _drop(a, 24.0, 9.0), -0.18), "Hips": Vector3(-30.0, 0, 0), "Spine": Vector3(-2.0, 0, 0), "Chest": Vector3(2.0, 0, 0), "UpperChest": Z,
		"Neck": Vector3(10.0, 0, 0), "Head": Vector3(22.0, 0, 0), "LeftShoulder": Vector3(0, 8.0, 0), "RightShoulder": Vector3(0, -8.0, 0),
		"RightUpperArm": Vector3(122.0, 0, -12.0), "RightLowerArm": Vector3(6.0, 0, 0), "RightHand": Z,
		"LeftUpperArm": Vector3(120.0, 0, 8.0), "LeftLowerArm": Vector3(8.0, 0, 0), "LeftHand": Z})
	push.merge(_legs(a, -30.0, 24.0, 9.0), true)
	return _ease_keys(t, [[0.0, base, 0], [6 * DT, pull, 2], [10 * DT, push, 1], [14 * DT, push, 3]])


## A taunt (90 f, then back to locomotion): "come on": the arms thrown open wide and up with the chest pushed out and
## the chin up (in by f9 with the blend-in, held to f28), then the right fist on the hip with the elbow out and the left
## hand raised high, beckoning twice (f40-80), the weight rocking back; settles by f90.
static func taunt(t: float) -> Dictionary:
	var f: float = t / DT
	var beck: float = 0.0
	if f > 40.0 and f < 80.0:
		beck = pow(sin(PI * (f - 40.0) / 20.0), 2.0)
	var rock: float = sin(PI * clampf((f - 30.0) / 50.0, 0.0, 1.0))
	var open: Dictionary = {
		"_hips": Vector3(0, _drop(10.0, 6.0, 14.0), -0.04), "Hips": Vector3(6.0, 0, 0),
		"Spine": Vector3(8.0, 0, 0), "Chest": Vector3(14.0, 0, 0), "UpperChest": Vector3(4.0, 0, 0), "Neck": Vector3(2.0, 0, 0), "Head": Vector3(16.0, 0, 0),
		"LeftShoulder": Vector3(0, 0, -10.0), "RightShoulder": Vector3(0, 0, 10.0), "Backpack": Z, "Hair": Z,
		"LeftUpperArm": Vector3(24.0, 0, -112.0), "LeftLowerArm": Vector3(14.0, 0, 0), "LeftHand": Vector3(0, 0, -20.0),
		"RightUpperArm": Vector3(24.0, 0, 112.0), "RightLowerArm": Vector3(14.0, 0, 0), "RightHand": Vector3(0, 0, 20.0),
	}
	open.merge(_legs(10.0, 6.0, 6.0, 14.0))
	if f <= 28.0:
		return open
	var beckon: Dictionary = {
		"_hips": Vector3(0.03 * rock, _drop(8.0, 8.0, 12.0), 0.03 * rock - 0.03), "Hips": Vector3(6.0, -14.0, -4.0 * rock),
		"Spine": Vector3(6.0, 2.0, 0), "Chest": Vector3(12.0, 8.0, 2.0 * rock), "UpperChest": Z, "Neck": Vector3(2.0, 0, 0), "Head": Vector3(14.0 - 4.0 * beck, 8.0, 9.0),
		"LeftShoulder": Z, "RightShoulder": Z, "Backpack": Z, "Hair": Z,
		"RightUpperArm": Vector3(-14.0, 0, 62.0), "RightLowerArm": Vector3(10.0, 0, -96.0), "RightHand": Vector3(0, 0, -20.0),
		"LeftUpperArm": Vector3(118.0, 14.0, -14.0), "LeftLowerArm": Vector3(10.0 + 80.0 * beck, 0, 0), "LeftHand": Vector3(-10.0 + 50.0 * beck, 0, 0),
	}
	beckon.merge(_legs(8.0, 6.0, 8.0, 12.0))
	return TLRigBiped._mixe(open, beckon, smoothstep(28.0, 40.0, f))


# ------------------------------------------------------------------ after the pose: the stick turn and the cross-check grip
## Called by TLRigBiped._post_pose every tick, before look_at. Free when stick_yaw is 0 and no cross-check is showing.
func post_pose(rig: TLRigBiped) -> void:
	if rig.frame != _frame:
		_frame = rig.frame
		var want: float = 1.0 if rig.clip == &"cross_check" and rig._stick_on else 0.0
		if grip != want:
			grip = move_toward(grip, want, 1.0 / 6.0)
			if grip == 0.0:
				rig._stick.position = Vector3.ZERO
	if not rig._stick_on or (yaw == 0.0 and grip == 0.0):
		return
	var sk: Skeleton3D = rig._sk
	if _bones.is_empty():
		for b: String in ["Hips", "Spine", "Chest", "UpperChest", "Neck", "RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand"]:
			_bones.append(sk.find_bone(b))
	var g: Quaternion = sk.get_bone_pose_rotation(_bones[0]) * sk.get_bone_pose_rotation(_bones[1])   # Spine, as seen from the model
	var a: float = clampf(yaw, YAW_MIN, YAW_MAX)
	var uc: Quaternion = g
	for i: int in 3:     # Chest, UpperChest, Neck turn about the model's vertical
		var bi: int = _bones[2 + i]
		var lq: Quaternion = sk.get_bone_pose_rotation(bi)
		if a != 0.0:
			lq = g.inverse() * Quaternion(Vector3.UP, a * YAW_SHARE[i]) * g * lq
			sk.set_bone_pose_rotation(bi, lq)
		g = g * lq
		if i == 1:
			uc = g
	if grip > 0.0:
		_grip(sk, rig, uc)


## The cross-check grip: the right hand turns so that the shaft lies level across the chest (local +Y of the stick, the
## butt, to the chest's left; the blade end down at the right), by `grip`. uc = the UpperChest seen from the model.
## The stick node's own rotation is never changed; its position is, by SLIDE * grip, and is zero again at grip 0.
func _grip(sk: Skeleton3D, rig: TLRigBiped, uc: Quaternion) -> void:
	var fwd: Vector3 = uc * Vector3.FORWARD
	var facing: Quaternion = Quaternion(Vector3.UP, atan2(-fwd.x, -fwd.z))
	var want: Quaternion = facing * Quaternion(Vector3.BACK, PI * 0.5)
	var p: Quaternion = uc
	for i: int in [5, 6, 7]:
		p = p * sk.get_bone_pose_rotation(_bones[i])
	var hand: int = _bones[8]
	var local: Quaternion = p.inverse() * want * rig._stick.quaternion.inverse()
	sk.set_bone_pose_rotation(hand, sk.get_bone_pose_rotation(hand).slerp(local, grip))
	# the grip is at the shaft's lower third: slide the stick up through the hand so that its middle lies between the
	# two hands and the bar reads across the chest, not out to one side
	rig._stick.position = rig._stick.basis.y * (SLIDE * grip)
