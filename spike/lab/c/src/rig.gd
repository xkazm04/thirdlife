class_name Rig
extends RefCounted
## Standard-skeleton builder. Rigs (bone names, parents, rest joint positions) come from data/rigs.json, which
## gen/kit_chars.py writes next to the voxel parts, so the Godot side never hard-codes a character.
## Parts are rigid voxel meshes parented to BoneAttachment3D nodes.

static var _rigs: Dictionary = {}


static func rig_def(name: String) -> Array:
	if _rigs.is_empty():
		_rigs = JSON.parse_string(FileAccess.get_file_as_string("res://data/rigs.json"))
	return _rigs[name]


## Returns {root, skel, anim, bones} ; root is a Node3D holding Skeleton3D + AnimationPlayer.
static func build(rig_name: String, vxm_path: String, style: Style) -> Dictionary:
	var def := rig_def(rig_name)
	var root := Node3D.new()
	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	root.add_child(skel)
	var idx: Dictionary = {}
	var pos: Dictionary = {}
	for b: Array in def:
		pos[b[0]] = Vector3(b[2][0], b[2][1], b[2][2])
	for b: Array in def:
		var i := skel.get_bone_count()
		skel.add_bone(b[0])
		idx[b[0]] = i
		if b[1] != null:
			skel.set_bone_parent(i, idx[b[1]])
			skel.set_bone_rest(i, Transform3D(Basis.IDENTITY, pos[b[0]] - pos[b[1]]))
		else:
			skel.set_bone_rest(i, Transform3D(Basis.IDENTITY, pos[b[0]]))
	skel.reset_bone_poses()
	var chunks := Vxm.load_chunks(vxm_path, style)
	var vs := 0.1
	var names: PackedStringArray = []
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(vxm_path.get_basename() + ".json")) if FileAccess.file_exists(vxm_path.get_basename() + ".json") else {}
	var part_names: Array = info.get("parts", [])
	for c in chunks.size():
		var ch: Dictionary = chunks[c]
		var bone_name: String = part_names[c] if c < part_names.size() else "Root"
		var ba := BoneAttachment3D.new()
		ba.name = "att_" + bone_name
		skel.add_child(ba)
		ba.bone_name = bone_name
		var mi := MeshInstance3D.new()
		mi.mesh = ch["mesh"]
		mi.name = "part"
		ba.add_child(mi)
		vs = ch["vs"]
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	ap.root_node = ap.get_path_to(root)
	return {"root": root, "skel": skel, "anim": ap, "idx": idx, "pos": pos, "vs": vs}


static func bone_track(anim: Animation, bone: String, kind: int) -> int:
	var t := anim.add_track(kind)
	anim.track_set_path(t, NodePath("Skeleton3D:" + bone))
	return t


## Builds a looping clip. f(bone, t01) -> Quaternion (or null to skip). pos_f(bone,t01)->Vector3 or null.
static func make_clip(bones: Array, length: float, rot_f: Callable, pos_f: Callable = Callable(), steps: int = 16) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR
	for b: String in bones:
		var probe: Variant = rot_f.call(b, 0.0)
		if probe != null:
			var t := bone_track(a, b, Animation.TYPE_ROTATION_3D)
			for k in steps + 1:
				var u := float(k) / steps
				a.rotation_track_insert_key(t, u * length, rot_f.call(b, u if k < steps else 0.0))
		if pos_f.is_valid():
			var pp: Variant = pos_f.call(b, 0.0)
			if pp != null:
				var t2 := bone_track(a, b, Animation.TYPE_POSITION_3D)
				for k in steps + 1:
					var u2 := float(k) / steps
					a.position_track_insert_key(t2, u2 * length, pos_f.call(b, u2 if k < steps else 0.0))
	return a


static func add_clips(ap: AnimationPlayer, clips: Dictionary) -> void:
	var lib := AnimationLibrary.new()
	for k: String in clips:
		lib.add_animation(k, clips[k])
	ap.add_animation_library("", lib)
