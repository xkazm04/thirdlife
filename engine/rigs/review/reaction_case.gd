extends SceneTree
## Run by selftest block 711. Frames count from play(), including its blend.
const FightCase := preload("res://rigs/review/fight_case.gd")
const F := preload("res://rigs/biped/tl_rig_biped_fight.gd")
const LENGTHS := {"block_stun": 14, "recoil": 30, "parried": 52, "guard_broken": 30, "wall_splat": 60}
const BONES := {
	"block_stun": ["Chest"], "recoil": ["RightUpperArm"], "parried": ["RightUpperArm"],
	"guard_broken": ["LeftUpperArm", "RightUpperArm"], "wall_splat": ["LeftUpperArm", "RightUpperArm"]}
var clip_errors: PackedStringArray = []
var pose_errors: PackedStringArray = []
var checked := 0
var least_angle := 180.0
var least_drop := 1.0


func _initialize() -> void:
	for look: String in FightCase.LOOKS:
		TLStyle.load_style(look)
		for mode: String in ["walk", "skate"]:
			var params := {"mode": mode}
			for clip: String in LENGTHS:
				var label := "%s/%s/%s" % [look.get_file(), mode, clip]
				for frames: int in [int(LENGTHS[clip]), 40]:
					var first := _run(params, clip, frames, label)
					if first != _run(params, clip, frames, label):
						clip_errors.append("%s %df replay differed" % [label, frames])
					checked += 1
	print("REACT clips ok=%s checked=%d %s" % [clip_errors.is_empty(), checked, "; ".join(clip_errors).left(500)])
	print("REACT pose ok=%s checked=%d min_angle=%.1fdeg min_wall_drop=%.3fm %s" % [
			pose_errors.is_empty(), checked, least_angle, least_drop, "; ".join(pose_errors).left(500)])
	quit(0 if clip_errors.is_empty() and pose_errors.is_empty() else 1)


func _run(params: Dictionary, clip: String, frames: int, label: String) -> PackedStringArray:
	var rig: TLRigBiped = TLRigs.build("biped", params)
	root.add_child(rig)
	var hashes: PackedStringArray = []
	if not rig.clips().has(clip):
		clip_errors.append(label + " missing")
		rig.free()
		return hashes
	var held := clip == "block_stun"
	rig.set_locomotion(Vector3.ZERO, true)
	rig._apply(rig.to_q(F.guard()))
	var angles := {}
	for bone: String in BONES[clip]:
		angles[bone] = _rotation(rig._sk, bone)
	# Use the original clip as a reference for the held cover, including the
	# styled shoulders. Loose hair and backpack continue settling after impact.
	rig.play(&"block", 0)
	for tick: int in range(1, 16):
		rig.tick(tick)
	var cover := FightCase.pose_hash(rig, FightCase.SKIP)
	if frames == 40:
		rig._size_hit(clip, 1.0, frames)
	var seconds := (frames + (0.0 if held else 0.5)) / 60.0
	if not is_equal_approx(rig._clips[clip]["dur"], seconds):
		clip_errors.append("%s duration differs at %df" % [label, frames])
	if clip in ["recoil", "parried"]:
		rig.play(&"strike", 0)
		for f: int in range(1, 6):
			rig.tick(15 + f)
	rig.play(clip)
	if rig._blend_n > 2:
		clip_errors.append(label + " blends longer than two ticks")
	var high := 0.0
	for f: int in range(1, frames + (41 if held else 2)):
		rig.tick(20 + f)
		hashes.append(FightCase.pose_hash(rig))
		if f == 6:
			for bone: String in BONES[clip]:
				var angle := rad_to_deg(_rotation(rig._sk, bone).angle_to(angles[bone]))
				least_angle = minf(least_angle, angle)
				if angle <= 25:
					pose_errors.append("%s %s %.1fdeg at f6" % [label, bone, angle])
		if clip == "wall_splat":
			var y := rig._sk.get_bone_pose_position(rig._root_bone).y
			if f == 3:
				high = y
			if f == roundi(.60 * frames):
				least_drop = minf(least_drop, high - y)
				if high - y < .15:
					pose_errors.append("%s hips dropped %.3fm" % [label, high - y])
		if f == frames:
			if rig.clip != clip:
				clip_errors.append(label + " ended early")
			if not held and not _at_guard(rig):
				clip_errors.append(label + " missed the final fist guard")
		if held and f in [frames, frames + 40]:
			if rig.clip != clip or FightCase.pose_hash(rig, FightCase.SKIP) != cover:
				clip_errors.append("%s differs from block at f%d" % [label, f])
		elif not held and f == frames + 1 and rig.clip != &"":
			clip_errors.append(label + " did not return to locomotion")
	if frames == 40:
		_check_strength(rig, clip, label)
	rig.free()
	return hashes


func _check_strength(rig: TLRigBiped, clip: String, label: String) -> void:
	var key := 3 if clip in ["block_stun", "wall_splat"] else 5
	var t := key / 60.0
	var neutral := F.block(5 * F.DT) if clip == "block_stun" else F.guard()
	var full: Vector3 = rig._eval(clip, t)["_hips"] - neutral["_hips"]
	if full.length() < .04:
		pose_errors.append(label + " missing hip displacement at contact")
	for amount: float in [0.0, 0.5, 1.5]:
		rig._size_hit(clip, amount, LENGTHS[clip])
		var displacement: Vector3 = rig._eval(clip, t)["_hips"] - neutral["_hips"]
		if displacement.distance_to(full * amount) > .0001:
			pose_errors.append("%s strength %.1f or key timing changed" % [label, amount])
	rig._size_hit(clip, 1.0, key + 1)
	if (rig._eval(clip, t)["_hips"] as Vector3).distance_to(neutral["_hips"] + full) > .0001:
		pose_errors.append(label + " missed contact in a short stun")


static func _rotation(sk: Skeleton3D, bone: String) -> Quaternion:
	var index := sk.find_bone(bone)
	# The rock of the chest includes the spine and hips underneath it.
	var rotation := sk.get_bone_pose_rotation(index)
	if bone == "Chest":
		var parent := sk.get_bone_parent(index)
		while parent >= 0:
			rotation = sk.get_bone_pose_rotation(parent) * rotation
			parent = sk.get_bone_parent(parent)
	return rotation


static func _at_guard(rig: TLRigBiped) -> bool:
	var guard := rig.to_q(F.guard())
	if not (rig._last["h"] as Vector3).is_equal_approx(guard["h"]):
		return false
	for bone: int in guard["q"]:
		if not (rig._last["q"][bone] as Quaternion).is_equal_approx(guard["q"][bone]):
			return false
	return true
