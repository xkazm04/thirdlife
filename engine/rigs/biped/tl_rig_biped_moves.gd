class_name TLRigBipedMoves
extends RefCounted
## The biped's moves off the walking gait (walker-feel, 18 Nov 2026): the pose in the air, the take-off, the slides.
## Pose functions only (no state): `{BoneName: Vector3(degrees), "_hips": Vector3(metres)}`, as every biped clip.
## +x swings a hanging limb forward and tips an upright bone back; left is -X.


static func _mix(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	if k <= 0.0:
		return a
	if k >= 1.0:
		return b
	var out: Dictionary = {}
	for key: String in a:
		out[key] = (a[key] as Vector3).lerp(b.get(key, Vector3.ZERO), k)
	for key: String in b:
		if not a.has(key):
			out[key] = Vector3.ZERO.lerp(b[key], k)
	return out


## Rising: one knee driven up, the other leg trailing with the toes pointed, arms thrown up, chest open.
static func rise() -> Dictionary:
	return {
		"_hips": Vector3(0, 0, 0), "Hips": Vector3(-6.0, 0, 0), "Spine": Vector3(-2.0, 0, 0), "Chest": Vector3(5.0, 0, 0), "Neck": Vector3(4.0, 0, 0), "Head": Vector3(6.0, 0, 0),
		"LeftUpperLeg": Vector3(58.0, 0, -3.0), "LeftLowerLeg": Vector3(-80.0, 0, 0), "LeftFoot": Vector3(8.0, 0, 0), "LeftToes": Vector3(0, 0, 0),
		"RightUpperLeg": Vector3(-14.0, 0, 3.0), "RightLowerLeg": Vector3(-20.0, 0, 0), "RightFoot": Vector3(-34.0, 0, 0), "RightToes": Vector3(0, 0, 0),
		"LeftUpperArm": Vector3(128.0, 0, -30.0), "LeftLowerArm": Vector3(24.0, 0, 0), "LeftHand": Vector3(0, 0, 0),
		"RightUpperArm": Vector3(92.0, 0, 36.0), "RightLowerArm": Vector3(40.0, 0, 0), "RightHand": Vector3(0, 0, 0),
		"Backpack": Vector3(-5.0, 0, 0), "Hair": Vector3(-8.0, 0, 0),
	}


## The top of a jump: both knees tucked, arms out to the sides.
static func apex() -> Dictionary:
	return {
		"_hips": Vector3(0, 0, 0), "Hips": Vector3(-10.0, 0, 0), "Spine": Vector3(-4.0, 0, 0), "Chest": Vector3(-2.0, 0, 0), "Neck": Vector3(2.0, 0, 0), "Head": Vector3(4.0, 0, 0),
		"LeftUpperLeg": Vector3(64.0, 0, -5.0), "LeftLowerLeg": Vector3(-94.0, 0, 0), "LeftFoot": Vector3(8.0, 0, 0), "LeftToes": Vector3(0, 0, 0),
		"RightUpperLeg": Vector3(32.0, 0, 5.0), "RightLowerLeg": Vector3(-72.0, 0, 0), "RightFoot": Vector3(-10.0, 0, 0), "RightToes": Vector3(0, 0, 0),
		"LeftUpperArm": Vector3(42.0, 0, -72.0), "LeftLowerArm": Vector3(30.0, 0, 0), "LeftHand": Vector3(0, 0, 0),
		"RightUpperArm": Vector3(30.0, 0, 70.0), "RightLowerArm": Vector3(36.0, 0, 0), "RightHand": Vector3(0, 0, 0),
		"Backpack": Vector3(0, 0, 0), "Hair": Vector3(0, 0, 0),
	}


## Falling: the legs reach down for the ground, a little bent, arms up and wide, eyes on the landing.
static func fall() -> Dictionary:
	return {
		"_hips": Vector3(0, 0, 0), "Hips": Vector3(-4.0, 0, 0), "Spine": Vector3(-2.0, 0, 0), "Chest": Vector3(2.0, 0, 0), "Neck": Vector3(-2.0, 0, 0), "Head": Vector3(-8.0, 0, 0),
		"LeftUpperLeg": Vector3(30.0, 0, -7.0), "LeftLowerLeg": Vector3(-50.0, 0, 0), "LeftFoot": Vector3(8.0, 0, 0), "LeftToes": Vector3(0, 0, 0),
		"RightUpperLeg": Vector3(10.0, 0, 7.0), "RightLowerLeg": Vector3(-36.0, 0, 0), "RightFoot": Vector3(4.0, 0, 0), "RightToes": Vector3(0, 0, 0),
		"LeftUpperArm": Vector3(22.0, 0, -108.0), "LeftLowerArm": Vector3(24.0, 0, 0), "LeftHand": Vector3(0, 0, 0),
		"RightUpperArm": Vector3(12.0, 0, 102.0), "RightLowerArm": Vector3(28.0, 0, 0), "RightHand": Vector3(0, 0, 0),
		"Backpack": Vector3(9.0, 0, 0), "Hair": Vector3(14.0, 0, 0),
	}


## The pose in the air from the vertical speed (m/s at scale 1, + = up): rising above +4, the apex round 0, falling below -5.
static func air(vy: float) -> Dictionary:
	return _mix(_mix(apex(), rise(), clampf(vy / 4.0, 0.0, 1.0)), fall(), clampf(-vy / 5.0, 0.0, 1.0))


## Take-off (one shot, 0.30 s, played as the feet leave the floor): the legs push straight with the toes pointed and the
## arms low behind, then the arms are thrown up, and it ends in the rising pose.
static func jump(t: float) -> Dictionary:
	var push: Dictionary = {
		"_hips": Vector3(0, 0, 0), "Hips": Vector3(-9.0, 0, 0), "Spine": Vector3(-4.0, 0, 0), "Chest": Vector3(0, 0, 0), "Neck": Vector3(2.0, 0, 0), "Head": Vector3(5.0, 0, 0),
		"LeftUpperLeg": Vector3(8.0, 0, -3.0), "LeftLowerLeg": Vector3(-10.0, 0, 0), "LeftFoot": Vector3(-40.0, 0, 0), "LeftToes": Vector3(0, 0, 0),
		"RightUpperLeg": Vector3(4.0, 0, 3.0), "RightLowerLeg": Vector3(-8.0, 0, 0), "RightFoot": Vector3(-40.0, 0, 0), "RightToes": Vector3(0, 0, 0),
		"LeftUpperArm": Vector3(-34.0, 0, -14.0), "LeftLowerArm": Vector3(22.0, 0, 0), "LeftHand": Vector3(0, 0, 0),
		"RightUpperArm": Vector3(-30.0, 0, 14.0), "RightLowerArm": Vector3(22.0, 0, 0), "RightHand": Vector3(0, 0, 0),
		"Backpack": Vector3(4.0, 0, 0), "Hair": Vector3(4.0, 0, 0),
	}
	var reach: Dictionary = rise().duplicate()
	reach.merge({"Chest": Vector3(8.0, 0, 0), "Head": Vector3(9.0, 0, 0),
		"LeftUpperLeg": Vector3(34.0, 0, -3.0), "LeftLowerLeg": Vector3(-46.0, 0, 0), "RightUpperLeg": Vector3(-6.0, 0, 3.0), "RightLowerLeg": Vector3(-10.0, 0, 0),
		"LeftUpperArm": Vector3(156.0, 0, -18.0), "LeftLowerArm": Vector3(10.0, 0, 0), "RightUpperArm": Vector3(140.0, 0, 22.0), "RightLowerArm": Vector3(14.0, 0, 0)}, true)
	if t <= 0.12:
		return _mix(push, reach, smoothstep(0.0, 0.12, t))
	return _mix(reach, rise(), smoothstep(0.12, 0.30, t))


## Run slide (holds): low on the left hip, the right leg out ahead with the heel on the floor, the left leg folded under,
## the left arm trailing low and back (the hand about 0.3 m above the floor: it does not reach it), the right arm up for
## balance, eyes ahead. The folded left foot rests ON the floor (lane walker, 19 Nov: it was 0.151 m under it).
static func slide(t: float) -> Dictionary:
	var k: float = smoothstep(0.0, 0.22, t)
	var settle: float = 1.0 - smoothstep(0.1, 0.3, t)      # the first bump as the hip meets the floor
	var low: Dictionary = {
		"_hips": Vector3(-0.03, -0.585 - 0.03 * settle, 0.12), "Hips": Vector3(34.0, 0, 9.0),
		"Spine": Vector3(-10.0, 0, -5.0), "Chest": Vector3(-12.0, 4.0, -5.0), "Neck": Vector3(-8.0, 0, 0), "Head": Vector3(-12.0, 0, 0),
		"RightUpperLeg": Vector3(46.0, 0, 6.0), "RightLowerLeg": Vector3(-12.0, 0, 0), "RightFoot": Vector3(26.0, 0, 0), "RightToes": Vector3(0, 0, 0),
		"LeftUpperLeg": Vector3(78.0, 0, -26.0), "LeftLowerLeg": Vector3(-142.0, 0, 0), "LeftFoot": Vector3(34.0, 0, 0), "LeftToes": Vector3(0, 0, 0),
		"LeftUpperArm": Vector3(-64.0, 0, -26.0), "LeftLowerArm": Vector3(10.0, 0, 0), "LeftHand": Vector3(-20.0, 0, 0),
		"RightUpperArm": Vector3(64.0, 0, 56.0), "RightLowerArm": Vector3(50.0, 0, 0), "RightHand": Vector3(0, 0, 0),
		"Backpack": Vector3(-6.0 * settle, 0, 0), "Hair": Vector3(12.0 - 8.0 * settle, 0, 0),
	}
	var enter: Dictionary = {
		"_hips": Vector3(0, -0.16, 0), "Hips": Vector3(-6.0, 0, 0), "Spine": Vector3(-6.0, 0, 0), "Chest": Vector3(-4.0, 0, 0), "Head": Vector3(6.0, 0, 0),
		"RightUpperLeg": Vector3(52.0, 0, 4.0), "RightLowerLeg": Vector3(-40.0, 0, 0), "RightFoot": Vector3(-6.0, 0, 0),
		"LeftUpperLeg": Vector3(20.0, 0, -8.0), "LeftLowerLeg": Vector3(-78.0, 0, 0), "LeftFoot": Vector3(40.0, 0, 0),
		"LeftUpperArm": Vector3(-30.0, 0, -20.0), "LeftLowerArm": Vector3(30.0, 0, 0), "RightUpperArm": Vector3(40.0, 0, 30.0), "RightLowerArm": Vector3(60.0, 0, 0),
	}
	return _mix(enter, low, k)


## Sliding down steep ground (loops until another play): knees bent, weight back, the left foot ahead, the body turned a
## little across the fall line, arms out wide and working for balance.
static func slope_slide(t: float) -> Dictionary:
	var w1: float = sin(TAU * t / 1.6)
	var w2: float = sin(TAU * t / 0.8 + 1.0)
	var a: float = 34.0
	return {
		"_hips": Vector3(0.02 * w1, -0.84 * (1.0 - cos(deg_to_rad(a))) - 0.01 * w2, 0.05), "Hips": Vector3(11.0 + 2.0 * w1, -20.0, 3.0 * w2),
		"Spine": Vector3(-7.0, 9.0, -2.0 * w2), "Chest": Vector3(-7.0, 9.0, -2.0 * w2), "Neck": Vector3(2.0, 2.0, 0), "Head": Vector3(-8.0 + 2.0 * w2, 0, 0),
		"LeftUpperLeg": Vector3(a + 8.0, 0, -9.0), "LeftLowerLeg": Vector3(-2.0 * a + 4.0, 0, 0), "LeftFoot": Vector3(-(11.0 + a + 8.0 - 2.0 * a + 4.0), 16.0, 4.0), "LeftToes": Vector3(0, 0, 0),
		"RightUpperLeg": Vector3(a - 30.0, 0, 13.0), "RightLowerLeg": Vector3(-2.0 * a + 12.0, 0, 0), "RightFoot": Vector3(-(11.0 + a - 30.0 - 2.0 * a + 12.0), 16.0, -4.0), "RightToes": Vector3(0, 0, 0),
		"LeftUpperArm": Vector3(14.0 + 9.0 * w1, 0, -80.0 - 10.0 * w2), "LeftLowerArm": Vector3(18.0 + 6.0 * w2, 0, 0), "LeftHand": Vector3(0, 0, 0),
		"RightUpperArm": Vector3(-8.0 - 9.0 * w1, 0, 82.0 - 10.0 * w2), "RightLowerArm": Vector3(24.0 - 6.0 * w2, 0, 0), "RightHand": Vector3(0, 0, 0),
		"Backpack": Vector3(3.0 * w2, 0, 0), "Hair": Vector3(8.0 + 3.0 * w1, 0, 0),
	}


## Fall, one-shot that holds (1.0 s): stumble, knees, then flat on the front with the arms thrown forward.
static func fall_down(t: float) -> Dictionary:
	var stand: Dictionary = {"_hips": Vector3.ZERO, "Hips": Vector3.ZERO}
	var lg: Array = TLRigBiped._leg(34.0, -30.0)
	var stumble: Dictionary = {
		"_hips": Vector3(0, -0.16, -0.08), "Hips": Vector3(-30.0, 0, 8.0), "Spine": Vector3(-10.0, 0, 0), "Chest": Vector3(-8.0, 0, 0), "Head": Vector3(24.0, 0, 0),
		"LeftUpperArm": Vector3(120.0, 0, -40.0), "LeftLowerArm": Vector3(30.0, 0, 0), "RightUpperArm": Vector3(96.0, 0, 50.0), "RightLowerArm": Vector3(40.0, 0, 0),
		"LeftUpperLeg": Vector3(float(lg[0]) + 20.0, 0, 0), "LeftLowerLeg": Vector3(float(lg[1]), 0, 0), "LeftFoot": Vector3(float(lg[2]), 0, 0),
		"RightUpperLeg": Vector3(float(lg[0]) - 40.0, 0, 0), "RightLowerLeg": Vector3(-20.0, 0, 0), "RightFoot": Vector3(30.0, 0, 0)}
	var knees: Dictionary = {
		"_hips": Vector3(0, -0.52, -0.3), "Hips": Vector3(-62.0, 0, 0), "Spine": Vector3(-8.0, 0, 0), "Chest": Vector3(-6.0, 0, 0), "Head": Vector3(34.0, 0, 0),
		"LeftUpperArm": Vector3(150.0, 0, -18.0), "LeftLowerArm": Vector3(24.0, 0, 0), "RightUpperArm": Vector3(150.0, 0, 18.0), "RightLowerArm": Vector3(24.0, 0, 0),
		"LeftUpperLeg": Vector3(70.0, 0, 0), "LeftLowerLeg": Vector3(-96.0, 0, 0), "LeftFoot": Vector3(40.0, 0, 0),
		"RightUpperLeg": Vector3(56.0, 0, 0), "RightLowerLeg": Vector3(-84.0, 0, 0), "RightFoot": Vector3(40.0, 0, 0)}
	var prone: Dictionary = {
		"_hips": Vector3(0, -0.82, -0.55), "Hips": Vector3(-88.0, 0, 0), "Spine": Vector3(2.0, 0, 0), "Chest": Vector3(4.0, 0, 0), "Neck": Vector3(14.0, 0, 0), "Head": Vector3(22.0, 12.0, 0),
		"LeftUpperArm": Vector3(170.0, 0, -22.0), "LeftLowerArm": Vector3(14.0, 0, 0), "RightUpperArm": Vector3(164.0, 0, 30.0), "RightLowerArm": Vector3(30.0, 0, 0),
		"LeftUpperLeg": Vector3(2.0, 0, -8.0), "LeftLowerLeg": Vector3(-6.0, 0, 0), "LeftFoot": Vector3(-50.0, 0, 0),
		"RightUpperLeg": Vector3(4.0, 0, 10.0), "RightLowerLeg": Vector3(-14.0, 0, 0), "RightFoot": Vector3(-50.0, 0, 0),
		"Backpack": Vector3(0, 0, 0), "Hair": Vector3(10.0, 0, 0)}
	var bounce: Dictionary = TLRigNode.add_pose(prone, {"_hips": Vector3(0, 0.05, 0), "Head": Vector3(10.0, 0, 0), "LeftUpperLeg": Vector3(-12.0, 0, 0), "RightUpperLeg": Vector3(-8.0, 0, 0)})
	return TLRigBiped._keys(t, [[0.0, stand], [0.22, stumble], [0.5, knees], [0.72, prone], [0.82, bounce], [1.0, prone]])


## Hammering with the right arm, leaning in (loops, 0.8 s).
static func work(t: float) -> Dictionary:
	var p: float = TAU * t / 0.8
	var hit: float = pow(maxf(0.0, sin(p)), 2.0)        # the hammer comes down fast
	var lift: float = maxf(0.0, -sin(p))
	var lg: Array = TLRigBiped._leg(16.0, -16.0)
	return {
		"_hips": Vector3(0, -TLRigBiped.CROUCH * (1.0 - cos(deg_to_rad(16.0))) - 0.01 * hit, 0), "Hips": Vector3(-16.0, -6.0, 0),
		"Spine": Vector3(-8.0 - 3.0 * hit, 0, 0), "Chest": Vector3(-6.0 - 3.0 * hit, -6.0 + 8.0 * lift, 0), "Neck": Vector3(4.0, 0, 0), "Head": Vector3(-4.0 - 4.0 * hit, 4.0, 0),
		"LeftUpperArm": Vector3(66.0, 0, 14.0), "LeftLowerArm": Vector3(34.0, 0, 0), "LeftHand": Vector3(0, 0, 0),
		"RightUpperArm": Vector3(84.0 + 46.0 * lift - 22.0 * hit, 0, 8.0), "RightLowerArm": Vector3(40.0 + 62.0 * lift - 26.0 * hit, 0, 0), "RightHand": Vector3(20.0 * lift - 20.0 * hit, 0, 0),
		"LeftUpperLeg": Vector3(float(lg[0]) + 14.0, 0, -6.0), "LeftLowerLeg": Vector3(float(lg[1]), 0, 0), "LeftFoot": Vector3(float(lg[2]) - 14.0, 0, 0),
		"RightUpperLeg": Vector3(float(lg[0]) - 14.0, 0, 6.0), "RightLowerLeg": Vector3(float(lg[1]), 0, 0), "RightFoot": Vector3(float(lg[2]) + 14.0, 0, 0),
		"Backpack": Vector3(2.0 * hit, 0, 0), "Hair": Vector3(-4.0 * hit, 0, 0),
	}
