extends RefCounted
## Contact poses in the biped's frame. A positive pitch tips the chest back.
const F := preload("res://rigs/biped/tl_rig_biped_fight.gd")
const FRAMES := {"block_stun": 14, "recoil": 30, "parried": 52, "guard_broken": 30, "wall_splat": 60}

# All angles below are local joint rotations. The stance supplies the pelvis
# height and leg rotations together so a deeper knee bend keeps the boots down.
const COVER := {
	"Hips": Vector3(-12, -35, 0), "Spine": Vector3(5, 4, 4), "Chest": Vector3(6, -19, 2),
	"Neck": Vector3(-19, 12, -4), "Head": Vector3(-15, 16, 0),
	"LeftUpperArm": Vector3(82, 8, -62), "LeftLowerArm": Vector3(113, 0, 30),
	"RightUpperArm": Vector3(78, 28, 34), "RightLowerArm": Vector3(81, 0, -42)}
const BOUNCE := {
	"Hips": Vector3(3, -15, -4), "Spine": Vector3(9, -6, 0), "Chest": Vector3(14, -8, 0),
	"Head": Vector3(15, 20, 3), "RightUpperArm": Vector3(166, -17, 37),
	"RightLowerArm": Vector3(44, 0, 0), "RightHand": Vector3(-29, -10, 8),
	"LeftUpperArm": Vector3(29, -12, -58), "LeftLowerArm": Vector3(31, 0, 0)}
const OPEN := {
	"Hips": Vector3(1, -20, 6), "Spine": Vector3(6, -12, 0), "Chest": Vector3(8, -18, 2),
	"Neck": Vector3(5, 16, 0), "Head": Vector3(15, 22, -6),
	"RightUpperArm": Vector3(-18, -12, 78), "RightLowerArm": Vector3(5, 0, 0),
	"RightHand": Vector3(-15, -22, 5), "LeftUpperArm": Vector3(18, -5, -32), "LeftLowerArm": Vector3(39, 0, 0)}
const BROKEN := {
	"Hips": Vector3(6, -8, -5), "Spine": Vector3(12, 2, -3), "Chest": Vector3(16, 1, 0),
	"Head": Vector3(7, -4, 6), "LeftUpperArm": Vector3(-24, -16, -57), "RightUpperArm": Vector3(-17, 12, 54),
	"LeftLowerArm": Vector3(17, 0, 0), "RightLowerArm": Vector3(11, 0, 0)}
const FLAT := {
	"Hips": Vector3(6, 0, 0), "Spine": Vector3(2, 0, 0), "Chest": Vector3(2, 0, 0),
	"Neck": Vector3(0, 0, 0), "Head": Vector3(14, 0, 0),
	"LeftUpperArm": Vector3(0, 0, -92), "RightUpperArm": Vector3(0, 0, 92),
	"LeftLowerArm": Vector3(5, 0, 0), "RightLowerArm": Vector3(5, 0, 0),
	"LeftHand": Vector3(10, -66, 0), "RightHand": Vector3(10, 66, 0)}
const SAG := {
	"Hips": Vector3(6, 0, 0), "Spine": Vector3(-4, 0, 0), "Chest": Vector3(-11, 0, -2),
	"Neck": Vector3(-15, 0, 0), "Head": Vector3(-27, 5, 3),
	"LeftUpperArm": Vector3(-8, 0, -66), "RightUpperArm": Vector3(-8, 0, 64),
	"LeftLowerArm": Vector3(16, 0, 0), "RightLowerArm": Vector3(12, 0, 0)}

var _guard := F.guard()
var _block := F.block(5 * F.DT)
var _strike := F.strike(5 * F.DT)


func install(rig: TLRigBiped) -> void:
	for clip: String in FRAMES:
		var held := clip == "block_stun"
		rig.add_clip(clip, 0.0, false, _pose.bind(rig, clip), held, held)
		size_clip(rig, clip, 1.0, FRAMES[clip])


func size_clip(rig: TLRigBiped, clip: StringName, amount: float, frames: int) -> void:
	var spec: Dictionary = rig._clips[clip]
	spec["frames"] = maxi(1, frames)
	spec["max_blend"] = mini(2, spec["frames"]) / 60.0
	spec["amount"] = clampf(amount, 0.0, 1.5)
	spec["dur"] = (float(spec["frames"]) + (0.0 if clip == &"block_stun" else 0.5)) / 60.0


static func _stance(bones: Dictionary, knee: float, stride: float, spread: float, shift: Vector3) -> Dictionary:
	var pose := bones.duplicate()
	pose.merge(F._legs(knee, bones["Hips"].x, stride, spread))
	pose["_hips"] = shift + Vector3.UP * F._drop(knee, stride, spread)
	return pose


func _pose(t: float, rig: TLRigBiped, clip: String) -> Dictionary:
	var spec: Dictionary = rig._clips[clip]
	var end: float = spec["frames"]
	var f := minf(t * 60.0, end)
	var start := _guard
	var rest := _guard
	if f >= end:
		return _block if clip == "block_stun" else _guard
	var peak: Dictionary
	var hit := 5.0
	var release := 0.75
	match clip:
		"block_stun":
			rest = _block
			start = rest
			peak = _stance(COVER, 49, 12, 13, Vector3(0, 0, .08))
			hit = 3.0
			release = .36
		"recoil":
			start = _strike
			peak = _stance(BOUNCE, 24, 19, 9, Vector3(.02, 0, .10))
			if rig._stick_on:
				peak["RightHand"] = Vector3(-65, 25, -70)
			release = .60
		"parried":
			start = _strike
			peak = _stance(OPEN, 29, 12, 10, Vector3(.04, 0, .11))
			var wobble := sin(TAU * 1.5 * clampf((f - hit) / maxf(1, release * end - hit), 0, 1))
			peak["Chest"] += Vector3(3, 9, 5) * wobble
			peak["RightUpperArm"] += Vector3(0, 3, 8) * wobble
		"guard_broken":
			start = _block
			peak = _stance(BROKEN, 34, 27, 11, Vector3(.06, 0, .18))
		_: # wall_splat: slide down the wall and bow the head before standing.
			hit = 3.0
			release = .80
			peak = _stance(FLAT, 16, 8, 9, Vector3(0, 0, .17))
			var sag := _stance(SAG, 49, 8, 9, Vector3(0, 0, .17))
			peak = TLRigBiped._mixe(peak, F._over(peak, sag), smoothstep(hit, maxf(hit + 1, .60 * end), f))
	# Even a short stun keeps its contact frame if there is one tick left to recover.
	var reach := minf(hit, maxf(.5, end - 1))
	var attack := smoothstep(0, reach, f)
	var recover := smoothstep(maxf(reach, release * end), end, f)
	var pose := TLRigBiped._mixe(start, rest, attack).duplicate()
	var weight: float = attack * (1.0 - recover) * float(spec["amount"])
	for bone: String in peak:
		var neutral: Vector3 = rest[bone]
		pose[bone] = (pose[bone] as Vector3) + (peak[bone] - neutral) * weight
	# A stronger throw carries the body farther, but the elbows stop at extension.
	for elbow: String in ["LeftLowerArm", "RightLowerArm"]:
		pose[elbow].x = clampf(pose[elbow].x, 0.0, 145.0)
	return pose
