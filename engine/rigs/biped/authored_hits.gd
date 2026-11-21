extends RefCounted
## Authored in the figure's frame (-Z forward). Each phase names its support:
## heels to seat to back, palms to forearms, or outside boot to hip to shoulder.

const FALL_FRAMES := 24.0
const RISE_FRAMES := 24.0
const BUCKLE := {
	"_hips": Vector3(0, -.12, .13), "Hips": Vector3(15, 0, 0), "Spine": Vector3(5, -6, 0),
	"Head": Vector3(-14, 0, 0), "LeftUpperLeg": Vector3(24, 0, -5), "LeftLowerLeg": Vector3(-62, 0, 0),
	"LeftFoot": Vector3(23, 0, 0), "RightUpperLeg": Vector3(30, 0, 5), "RightLowerLeg": Vector3(-70, 0, 0),
	"RightFoot": Vector3(25, 0, 0), "LeftUpperArm": Vector3(73, 0, -28), "LeftLowerArm": Vector3(28, 0, 0),
	"RightUpperArm": Vector3(64, 0, 32), "RightLowerArm": Vector3(38, 0, 0)}
const SEAT := {
	"_hips": Vector3(0, -.72, .39), "Hips": Vector3(55, 0, -7), "Spine": Vector3(-14, -5, 3),
	"Head": Vector3(-19, 6, 0), "LeftUpperLeg": Vector3(54, 0, -12), "LeftLowerLeg": Vector3(-48, 0, 0),
	"LeftFoot": Vector3(-8, 0, 0), "RightUpperLeg": Vector3(53, 0, 10), "RightLowerLeg": Vector3(-31, 0, 0),
	"RightFoot": Vector3(-17, 0, 0), "LeftUpperArm": Vector3(104, 0, -36), "LeftLowerArm": Vector3(21, 0, 0),
	"RightUpperArm": Vector3(112, 0, 32), "RightLowerArm": Vector3(27, 0, 0)}
const SUPINE := {
	"_hips": Vector3(0, -.78, .43), "Hips": Vector3(84, 0, 0), "Spine": Vector3(1, 0, 0),
	"Neck": Vector3(-10, 0, 0), "Head": Vector3(-8, 17, 0),
	"LeftUpperLeg": Vector3(17, 0, -12), "LeftLowerLeg": Vector3(-35, 0, 0), "LeftFoot": Vector3(-15, 0, 0),
	"RightUpperLeg": Vector3(9, 0, 10), "RightLowerLeg": Vector3(-18, 0, 0), "RightFoot": Vector3(-20, 0, 0),
	"LeftUpperArm": Vector3(2, 0, -53), "LeftLowerArm": Vector3(16, 0, 0),
	"RightUpperArm": Vector3(7, 0, 66), "RightLowerArm": Vector3(24, 0, 0)}
const REACH := {
	"_hips": Vector3(0, -.12, -.14), "Hips": Vector3(-28, -4, 0), "Chest": Vector3(-12, 0, -4),
	"Head": Vector3(20, 0, 0), "LeftUpperLeg": Vector3(68, 0, -4), "LeftLowerLeg": Vector3(-61, 0, 0),
	"LeftFoot": Vector3(21, 0, 0), "RightUpperLeg": Vector3(34, 0, 8), "RightLowerLeg": Vector3(-42, 0, 0),
	"RightFoot": Vector3(30, 0, 0), "LeftUpperArm": Vector3(106, 0, -19), "LeftLowerArm": Vector3(23, 0, 0),
	"RightUpperArm": Vector3(92, 0, 19), "RightLowerArm": Vector3(30, 0, 0)}
const CATCH := {
	"_hips": Vector3(0, -.45, -.29), "Hips": Vector3(-72, 0, 0), "Chest": Vector3(-8, -5, 0),
	"Head": Vector3(22, 0, 0), "LeftUpperLeg": Vector3(47, 0, -10), "LeftLowerLeg": Vector3(-81, 0, 0),
	"LeftFoot": Vector3(-12, 0, 0), "RightUpperLeg": Vector3(24, 0, 11), "RightLowerLeg": Vector3(-59, 0, 0),
	"RightFoot": Vector3(-16, 0, 0), "LeftUpperArm": Vector3(88, 0, -18), "LeftLowerArm": Vector3(18, 0, 0),
	"RightUpperArm": Vector3(100, 0, 24), "RightLowerArm": Vector3(24, 0, 0)}
const PRONE := {
	"_hips": Vector3(0, -.78, -.36), "Hips": Vector3(-88, 0, 1), "Spine": Vector3(3, 0, 0),
	"Neck": Vector3(7, 0, 0), "Head": Vector3(9, 38, 0),
	"LeftUpperLeg": Vector3(4, 0, -10), "LeftLowerLeg": Vector3(-13, 0, 0), "LeftFoot": Vector3(-48, 0, 0),
	"RightUpperLeg": Vector3(1, 0, 9), "RightLowerLeg": Vector3(-20, 0, 0), "RightFoot": Vector3(-43, 0, 0),
	"LeftUpperArm": Vector3(142, 0, -44), "LeftLowerArm": Vector3(59, 0, 0),
	"RightUpperArm": Vector3(146, 0, 36), "RightLowerArm": Vector3(46, 0, 0)}
const SLIP := {
	"_hips": Vector3(-.10, -.10, .02), "Hips": Vector3(-12, 5, 18), "Chest": Vector3(0, -8, 8),
	"Head": Vector3(0, 12, -12), "LeftUpperLeg": Vector3(46, 0, -12), "LeftLowerLeg": Vector3(-70, 0, 0),
	"LeftFoot": Vector3(32, 0, 0), "RightUpperLeg": Vector3(21, 0, 19), "RightLowerLeg": Vector3(-42, 0, 0),
	"RightFoot": Vector3(29, 0, 0), "LeftUpperArm": Vector3(53, 0, -26), "LeftLowerArm": Vector3(35, 0, 0),
	"RightUpperArm": Vector3(58, 0, 76), "RightLowerArm": Vector3(27, 0, 0)}
const HIP_LAND := {
	"_hips": Vector3(-.30, -.61, .03), "Hips": Vector3(-17, 13, 65), "Spine": Vector3(0, -8, -12),
	"Head": Vector3(0, 12, -19), "LeftUpperLeg": Vector3(49, 0, 6), "LeftLowerLeg": Vector3(-99, 0, 0),
	"LeftFoot": Vector3(20, 0, 0), "RightUpperLeg": Vector3(18, 0, 24), "RightLowerLeg": Vector3(-30, 0, 0),
	"LeftUpperArm": Vector3(82, 0, 10), "LeftLowerArm": Vector3(44, 0, 0),
	"RightUpperArm": Vector3(68, 0, 64), "RightLowerArm": Vector3(19, 0, 0)}
const ON_SIDE := {
	"_hips": Vector3(-.43, -.65, .02), "Hips": Vector3(-6, 16, 89), "Spine": Vector3(0, 22, 0),
	"Chest": Vector3(-4, 44, 11), "Head": Vector3(10, -58, 15),
	"LeftUpperLeg": Vector3(-13, 0, -4), "LeftLowerLeg": Vector3(-12, 0, 0),
	"RightUpperLeg": Vector3(101, 16, -6), "RightLowerLeg": Vector3(-48, 0, 0),
	"LeftUpperArm": Vector3(61, -47, 2), "LeftLowerArm": Vector3(22, 0, 0),
	"RightUpperArm": Vector3(119, -12, 7), "RightLowerArm": Vector3(22, 0, 0)}

## A tucked sit, hands under shoulders, then the same half-kneel under both recoveries.
const SIT_UP := {
	"_hips": Vector3(0, -.69, .36), "Hips": Vector3(32, 8, -11), "Spine": Vector3(-26, 9, 0),
	"Chest": Vector3(-12, 0, 0), "Head": Vector3(-10, 0, 0),
	"LeftUpperLeg": Vector3(87, 0, -19), "LeftLowerLeg": Vector3(-90, 0, 0), "LeftFoot": Vector3(-16, 0, 0),
	"RightUpperLeg": Vector3(90, 0, 9), "RightLowerLeg": Vector3(-62, 0, 0), "RightFoot": Vector3(-25, 0, 0),
	"LeftUpperArm": Vector3(73, 0, -15), "LeftLowerArm": Vector3(36, 0, 0),
	"RightUpperArm": Vector3(-66, 0, 34), "RightLowerArm": Vector3(38, 0, 0)}
const PRESS := {
	"_hips": Vector3(0, -.57, -.28), "Hips": Vector3(-68, 0, 0), "Spine": Vector3(12, 0, 0),
	"Head": Vector3(23, 0, 0), "LeftUpperLeg": Vector3(36, 0, -12), "LeftLowerLeg": Vector3(-91, 0, 0),
	"LeftFoot": Vector3(-19, 0, 0), "RightUpperLeg": Vector3(28, 0, 8), "RightLowerLeg": Vector3(-82, 0, 0),
	"RightFoot": Vector3(-26, 0, 0), "LeftUpperArm": Vector3(39, 0, -13), "LeftLowerArm": Vector3(33, 0, 0),
	"RightUpperArm": Vector3(41, 0, 13), "RightLowerArm": Vector3(32, 0, 0)}
const KNEEL := {
	"_hips": Vector3(0, -.39, .03), "Hips": Vector3(-30, 7, 5), "Chest": Vector3(-13, -7, -3),
	"Head": Vector3(22, 0, 0), "LeftUpperLeg": Vector3(110, 0, -9), "LeftLowerLeg": Vector3(-98, 0, 0),
	"LeftFoot": Vector3(18, 0, 0), "RightUpperLeg": Vector3(23, 0, 10), "RightLowerLeg": Vector3(-104, 0, 0),
	"RightFoot": Vector3(-27, 0, 0), "LeftUpperArm": Vector3(21, 0, -9), "LeftLowerArm": Vector3(43, 0, 0),
	"RightUpperArm": Vector3(42, 0, 13), "RightLowerArm": Vector3(21, 0, 0)}
const TUCK := {
	"_hips": Vector3(.07, -.58, .22), "Hips": Vector3(1, 20, -17), "Spine": Vector3(-32, -7, 4),
	"Head": Vector3(8, -12, 0), "LeftUpperLeg": Vector3(102, 0, -8), "LeftLowerLeg": Vector3(-112, 0, 0),
	"LeftFoot": Vector3(12, 0, 0), "RightUpperLeg": Vector3(64, 33, 38), "RightLowerLeg": Vector3(-154, 0, 0),
	"RightFoot": Vector3(-17, 0, 0), "LeftUpperArm": Vector3(55, 0, -15), "LeftLowerArm": Vector3(40, 0, 0),
	"RightUpperArm": Vector3(-25, 0, 29), "RightLowerArm": Vector3(28, 0, 0)}
const PUSH_OFF := {
	"_hips": Vector3(0, -.19, -.06), "Hips": Vector3(-18, 3, 2), "Chest": Vector3(-8, -3, 0),
	"Head": Vector3(15, 0, 0), "LeftUpperLeg": Vector3(55, 0, -5), "LeftLowerLeg": Vector3(-74, 0, 0),
	"LeftFoot": Vector3(37, 0, 0), "RightUpperLeg": Vector3(14, 0, 8), "RightLowerLeg": Vector3(-56, 0, 0),
	"RightFoot": Vector3(7, 0, 0), "LeftUpperArm": Vector3(22, 0, -15), "LeftLowerArm": Vector3(19, 0, 0),
	"RightUpperArm": Vector3(13, 0, 20), "RightLowerArm": Vector3(23, 0, 0)}

var _strength := 0.7
var _impact := 0.0
const TRAVEL := {"back": Vector3.BACK, "front": Vector3.FORWARD,
	"left": Vector3.LEFT, "right": Vector3.RIGHT}
const REST_GRIP := {"front": Vector3(-32,-14,-32), "back": Vector3(-23,-4,-36),
	"left": Vector3(-46,-29,-14), "right": Vector3(-9,-8,2)}


func install(rig: TLRigBiped) -> void:
	for side: String in ["front", "back", "left", "right"]:
		rig.add_clip("hit_" + side, 24.0 / 60.0, false, _flinch.bind(rig, side), true)
		rig.add_clip("fall_" + side, FALL_FRAMES / 60.0, false, _fall.bind(rig, side), false, true)
		rig.add_clip("get_up_" + side, RISE_FRAMES / 60.0, false, _rise.bind(rig, side))


func size_clip(rig: TLRigBiped, action: StringName, amount: float, frames: int) -> void:
	var spec: Dictionary = rig._clips[action]
	if action.begins_with("hit_"):
		_strength = clampf(amount, 0.0, 1.4)
	elif action.begins_with("fall_"):
		# Horizontal speed after the shove in m/s. 2.16 is the lab's usual
		# knockdown; by 3.60 the figure is thrown clear and rebounds.
		_impact = smoothstep(2.16, 3.60, amount)
		var rate := 0.85 + 0.30 * clampf(amount / 4.0, 0.0, 1.5)
		spec["dur"] = clampf(FALL_FRAMES / rate, 1.0, maxi(1, frames - 1)) / 60.0
	else:
		# tick() retires a one-shot before sampling its end. Leave half a
		# tick after the last standing sample, including for a one-tick rise.
		spec["dur"] = (maxi(1, frames) + 0.5) / 60.0


func _flinch(t: float, rig: TLRigBiped, side: String) -> Dictionary:
	var pose := rig._loco_pose()
	var beat := t * 60.0
	var snap := smoothstep(0, 3, beat) * (1.0 - smoothstep(3, 19, beat)) * _strength
	var lag := smoothstep(1, 4, beat) * (1.0 - smoothstep(5, 22, beat)) * _strength
	var pitch := 1.0 if side == "front" else (-1.0 if side == "back" else 0.0)
	var roll := 1.0 if side == "right" else (-1.0 if side == "left" else 0.0)
	var recoil := {"Spine": Vector3(26*pitch, -5*roll, 26*roll) * snap,
		"Chest": Vector3(20*pitch, -8*roll, 18*roll) * snap,
		"Head": Vector3(13*pitch, 9*roll, 13*roll) * lag,
		"LeftUpperArm": Vector3(27 + 13*pitch, 0, -21 + 18*roll) * lag,
		"RightUpperArm": Vector3(21 + 13*pitch, 0, 23 + 18*roll) * lag,
		"LeftLowerArm": Vector3(20, 0, 0) * lag, "RightLowerArm": Vector3(23, 0, 0) * lag}
	if _strength >= 0.4 and rig._speed() <= 0.8:
		var knee := 20.0 * snap
		recoil["_hips"] = Vector3.DOWN * TLRigBiped.CROUCH * (1.0 - cos(deg_to_rad(knee)))
		for leg: String in ["Left", "Right"]:
			recoil[leg + "UpperLeg"] = Vector3(knee, 0, 0)
			recoil[leg + "LowerLeg"] = Vector3(-2*knee, 0, 0)
			recoil[leg + "Foot"] = Vector3(knee, 0, 0)
	return TLRigNode.add_pose(pose, recoil)


func _fall(t: float, rig: TLRigBiped, side: String) -> Dictionary:
	var phase := clampf(t / float(rig._clips["fall_" + side]["dur"]), 0.0, 1.0)
	var contact_phase := lerpf(1.0, .63, _impact)
	var u := minf(1.0, phase / contact_phase)
	var pose: Dictionary
	match side:
		"back":
			pose = TLRigBiped._keys(u, [[0, {}], [.22, BUCKLE], [.57, SEAT], [.88, SUPINE]])
		"front":
			pose = TLRigBiped._keys(u, [[0, {}], [.21, REACH], [.57, CATCH], [.94, PRONE]])
		_:
			pose = TLRigBiped._keys(u, [[0, {}], [.20, SLIP], [.58, HIP_LAND], [.94, ON_SIDE]])
			if side == "right":
				pose = _mirror(pose)
	if _impact > 0.0:
		var away: Vector3 = TRAVEL[side]
		var throw_arm := smoothstep(0, .22, u) * (1.0 - smoothstep(.27, .70, u)) * _impact
		var after_contact := (phase - contact_phase) / maxf(1.0 - contact_phase, .001)
		var rebound := smoothstep(0, .43, after_contact) * (1.0 - smoothstep(.43, 1, after_contact)) * _impact
		pose = TLRigNode.add_pose(pose, {
			"_hips": away * (.42 * _impact * smoothstep(0, .65, u)) + Vector3.UP * .19 * rebound,
			"Hips": Vector3(away.z, 0, -away.x) * (20.0 * throw_arm - 7.0 * rebound),
			"Head": Vector3(away.z, 0, -away.x) * (-12.0 * throw_arm - 7.0 * rebound),
			"LeftUpperArm": Vector3(10, 0, -40) * throw_arm, "RightUpperArm": Vector3(10, 0, 40) * throw_arm})
	return _rest_grip(pose, side, smoothstep(.35, .95, u)) if rig._stick_on else pose


func _rise(t: float, rig: TLRigBiped, side: String) -> Dictionary:
	var u := minf(1.0, t / (float(rig._clips["get_up_" + side]["dur"]) - 0.5 / 60.0))
	var pose: Dictionary
	match side:
		"back":
			pose = TLRigBiped._keys(u, [[0, SUPINE], [.26, SIT_UP], [.43, TUCK], [.60, KNEEL], [.81, PUSH_OFF]])
			if u > .26 and u < .43:
				pose["RightLowerLeg"].x -= 52.0 * sin(PI * (u - .26) / .17)
		"front":
			pose = TLRigBiped._keys(u, [[0, PRONE], [.27, PRESS], [.60, KNEEL], [.81, PUSH_OFF]])
			_gather_knee(pose, u, .27)
		_:
			# Roll over the grounded shoulder. Both the chin and the hips
			# stay low as he turns onto his palms, facing along the fall.
			var press := PRESS.duplicate()
			press["Hips"] = Vector3(-68, 76, 0)
			press["_hips"] = Vector3(-.34, -.57, .03)
			var kneel := KNEEL.duplicate()
			kneel["Hips"] = Vector3(-30, 36, 5)
			kneel["_hips"] = Vector3(-.15, -.39, .02)
			pose = TLRigBiped._keys(u, [[0, ON_SIDE], [.30, press], [.60, kneel], [.81, PUSH_OFF]])
			if u > 0.0 and u < .30:
				var start := Basis.from_euler(ON_SIDE["Hips"] * PI / 180.0)
				var end := Basis.from_euler(press["Hips"] * PI / 180.0)
				pose["Hips"] = start.slerp(end, smoothstep(0, .30, u)).get_euler() * 180.0 / PI
			_gather_knee(pose, u, .30)
			if side == "right":
				pose = _mirror(pose)
	if _impact > 0.0:
		# Keep the landed displacement as the recovery starts; draw the hips
		# over the new base of support as the knee comes underneath.
		pose = TLRigNode.add_pose(pose, {"_hips": TRAVEL[side] * (.42 * _impact * (1.0 - smoothstep(0, .60, u)))})
	if rig._stick_on:
		pose = _rest_grip(pose, side, 1.0 - smoothstep(.04, .33, u))
	return TLRigBiped._mixe(pose, rig._loco_pose(), smoothstep(.81, 1.0, u))


func _rest_grip(pose: Dictionary, side: String, weight: float) -> Dictionary:
	return TLRigNode.add_pose(pose, {"RightHand": REST_GRIP[side] * weight})


func _gather_knee(pose: Dictionary, u: float, start: float) -> void:
	# Draw the heel up before swinging the knee beneath the chest.
	if u > start and u < .60:
		pose["LeftLowerLeg"].x -= 51.0 * sin(PI * (u - start) / (.60 - start))


func _mirror(pose: Dictionary) -> Dictionary:
	var out := {}
	for bone: String in pose:
		var name := bone
		if bone.begins_with("Left"):
			name = "Right" + bone.trim_prefix("Left")
		elif bone.begins_with("Right"):
			name = "Left" + bone.trim_prefix("Right")
		out[name] = pose[bone] * (Vector3(-1, 1, 1) if bone == "_hips" else Vector3(1, -1, -1))
	return out
