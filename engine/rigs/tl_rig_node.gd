class_name TLRigNode
extends Node3D
## Base of every rig (kernelApi 0.1, contracts/KIT-RIG-STYLE.md). A rig is VISUAL ONLY: the kernel's controller owns the
## physics body and parents the rig under it. Animation is procedural and frame-driven: nothing here reads a clock or
## a global random function; `tick(frame)` advances exactly one physics frame (1/60 s).
##   family, metrics(), clips(), play(clip, blend), set_locomotion(velocity_local, grounded), set_param(name, value),
##   socket(name), tick(frame)
## A clip is a pose function `fn(t: float) -> {BoneName: Vector3(degrees), "_hips": Vector3(metres)}` plus a duration
## and a loop flag. Bones have identity rest rotations, so a pose is plain per-bone euler degrees:
##   +x swings a hanging limb forward (-Z) and tips an upright bone (spine, head) BACK; -x leans the torso forward,
##   +y turns left, +z rolls the top towards -X (left). Poses are blended as quaternions.

const DT: float = 1.0 / 60.0

var family: StringName = &""
var params: Dictionary = {}          # build params (with defaults) + runtime params set through set_param
var clip: StringName = &""           # the action clip being played ("" = locomotion decides)
var clip_t: float = 0.0
var frame: int = 0
var _metrics: Dictionary = {}
var _clips: Dictionary = {}          # name -> {"dur": float, "loop": bool, "fn": Callable, "upper": bool, "hold": bool}
var _order: PackedStringArray = PackedStringArray()
var _sockets: Dictionary = {}
var _sk: Skeleton3D
var _root_bone: int = -1
var _root_rest: Vector3 = Vector3.ZERO
var _upper: Dictionary = {}          # bone index -> true: bones an "upper" action clip owns while the legs keep moving
var _last: Dictionary = {}           # last applied pose {"q": {bone index: Quaternion}, "h": Vector3}
var _from: Dictionary = {}
var _blend_n: int = 0
var _blend_i: int = 0
var _vel: Vector3 = Vector3.ZERO
var _grounded: bool = true
var _loco_on: bool = false
var _phase: float = 0.0              # locomotion stride phase, in cycles


## A Skeleton3D only schedules its skin update while it is inside the tree, and a pose set outside the tree leaves
## its dirty flag set for good (later pose changes are then never drawn). So: outside the tree every tick flushes
## the dirty bones, and on entering the tree the last pose is applied again one deferred call later (when the
## Skeleton3D child is inside the tree too). A rig can therefore be posed before it is added (spawn at a frame).
func _enter_tree() -> void:
	_reapply.call_deferred()


func _reapply() -> void:
	if _sk == null or _last.is_empty() or not _sk.is_inside_tree():
		return
	_flush()
	_apply(_last)
	_post_pose()


func _flush() -> void:
	if _sk.has_method("force_update_all_dirty_bones"):
		_sk.call("force_update_all_dirty_bones")
	else:
		_sk.get_bone_global_pose(0)


func metrics() -> Dictionary:
	return _metrics.duplicate()


func clips() -> PackedStringArray:
	return _order


func socket(sname: StringName) -> Node3D:
	return _sockets.get(String(sname), null)


func add_clip(cname: String, dur: float, loop: bool, fn: Callable, upper: bool = false, hold: bool = false) -> void:
	_clips[cname] = {"dur": dur, "loop": loop, "fn": fn, "upper": upper, "hold": hold}
	_order.append(cname)


## Starts a clip. Looping is a property of the clip. A one-shot clip returns to locomotion (or idle) when it ends,
## except a `hold` clip (fall, skate_stop), which keeps its last pose until another play(). play(&"") = back to locomotion.
func play(cname: StringName, blend: float = 0.15) -> void:
	if String(cname) != "" and not _clips.has(String(cname)):
		push_warning("TLRig %s: no clip '%s' (clips: %s)" % [family, cname, ", ".join(_order)])
		return
	clip = cname
	clip_t = 0.0
	_start_blend(blend)


func _start_blend(blend: float) -> void:
	_from = _last
	_blend_n = maxi(0, roundi(blend * 60.0))
	_blend_i = 0


## Called every frame by the controller. velocity_local: metres per second in the rig's own space (forward is -Z).
func set_locomotion(velocity_local: Vector3, grounded: bool) -> void:
	_vel = velocity_local
	_grounded = grounded
	_loco_on = true


func set_param(pname: StringName, value: Variant) -> void:
	params[String(pname)] = value
	_param_changed(String(pname), value)


func _param_changed(_pname: String, _value: Variant) -> void:
	pass


## The pose locomotion asks for this frame (override). Returns a pose dictionary.
func _loco_pose() -> Dictionary:
	return _eval("idle", float(frame) * DT)


func _post_pose() -> void:
	pass


func _eval(cname: String, t: float) -> Dictionary:
	var c: Dictionary = _clips[cname]
	var tt: float = fposmod(t, float(c["dur"])) if bool(c["loop"]) else minf(t, float(c["dur"]))
	return (c["fn"] as Callable).call(tt)


## Advances the animation by one physics frame. `frame_no` is the kernel's frame counter (kept for frame-keyed
## details such as blinking and flame flicker); every call is one step of 1/60 s.
func tick(frame_no: int) -> void:
	frame = frame_no
	_advance()
	if _sk == null:
		return
	var target: Dictionary
	if String(clip) != "":
		var c: Dictionary = _clips[String(clip)]
		clip_t += DT
		if not bool(c["loop"]) and not bool(c["hold"]) and clip_t >= float(c["dur"]):
			clip = &""
			_start_blend(0.2)
			target = to_q(_loco_pose())
		else:
			target = to_q(_eval(String(clip), clip_t))
			if bool(c["upper"]) and _loco_on and _vel.length() > 0.8:
				var legs: Dictionary = to_q(_loco_pose())
				for bi: int in (target["q"] as Dictionary):
					if _upper.has(bi):
						legs["q"][bi] = target["q"][bi]
				target = legs
	else:
		target = to_q(_loco_pose())
	if _blend_i < _blend_n and not _from.is_empty():
		_blend_i += 1
		var k: float = float(_blend_i) / float(_blend_n)
		target = mix(_from, target, k * k * (3.0 - 2.0 * k))
	_apply(target)
	_last = target
	_post_pose()
	if not _sk.is_inside_tree():
		_flush()


func _advance() -> void:
	pass


## {BoneName: Vector3 degrees, "_hips": Vector3} -> {"q": {bone index: Quaternion}, "h": Vector3}
func to_q(pose: Dictionary) -> Dictionary:
	var q: Dictionary = {}
	var h: Vector3 = Vector3.ZERO
	for key: String in pose:
		if key == "_hips":
			h = pose[key]
			continue
		var bi: int = _sk.find_bone(key)
		if bi < 0:
			continue
		var e: Vector3 = pose[key]
		q[bi] = Quaternion.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)))
	return {"q": q, "h": h}


static func mix(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var q: Dictionary = {}
	var aq: Dictionary = a["q"]
	var bq: Dictionary = b["q"]
	for bi: int in bq:
		q[bi] = (aq.get(bi, Quaternion.IDENTITY) as Quaternion).slerp(bq[bi], k)
	for bi: int in aq:
		if not bq.has(bi):
			q[bi] = (aq[bi] as Quaternion).slerp(Quaternion.IDENTITY, k)
	return {"q": q, "h": (a["h"] as Vector3).lerp(b["h"], k)}


func _apply(pose: Dictionary) -> void:
	var q: Dictionary = pose["q"]
	for bi: int in q:
		_sk.set_bone_pose_rotation(bi, q[bi])
	if _root_bone >= 0:
		_sk.set_bone_pose_position(_root_bone, _root_rest + (pose["h"] as Vector3))


# ------------------------------------------------------------------ helpers for the family scripts
static func make_skeleton(bones: Array) -> Skeleton3D:
	# bones: [name, parent name or "", global rest position]; identity rest rotations
	var sk: Skeleton3D = Skeleton3D.new()
	sk.name = "Skeleton3D"
	var gpos: Dictionary = {}
	for b: Array in bones:
		var i: int = sk.add_bone(String(b[0]))
		var parent: String = String(b[1])
		var p: Vector3 = b[2]
		gpos[b[0]] = p
		if parent != "":
			sk.set_bone_parent(i, sk.find_bone(parent))
			sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, p - (gpos[parent] as Vector3)))
		else:
			sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, p))
	sk.reset_bone_poses()
	return sk


func attach_skinned(model: Node3D, sk: Skeleton3D, mk: TLMesh, mesh_name: String) -> MeshInstance3D:
	_sk = sk
	_root_bone = sk.find_bone("Hips")
	_root_rest = sk.get_bone_rest(_root_bone).origin
	if sk.get_parent() == null:
		model.add_child(sk)
	var mi: MeshInstance3D = sk.get_node_or_null("Mesh")
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = "Mesh"
		sk.add_child(mi)
		mi.skin = sk.create_skin_from_rest_transforms()
		mi.skeleton = NodePath("..")
		mi.extra_cull_margin = 2.0
	mi.mesh = mk.build(mesh_name)
	return mi


func add_socket(sname: String, bone: String, offset: Vector3, euler_deg: Vector3 = Vector3.ZERO) -> Node3D:
	var ba: BoneAttachment3D = BoneAttachment3D.new()
	ba.name = "At_" + sname
	_sk.add_child(ba)
	ba.bone_name = bone
	var s: Node3D = Node3D.new()
	s.name = sname
	# the attachment sits at the bone's joint: `offset` is given in model space at rest, so subtract the joint position
	s.position = offset - _sk.get_bone_global_rest(_sk.find_bone(bone)).origin
	s.rotation_degrees = euler_deg
	ba.add_child(s)
	_sockets[sname] = s
	return s


func look_angles(target_world: Vector3, eye_local: Vector3) -> Vector2:
	# yaw (+ = left) and pitch (+ = up) in degrees from the rig's forward (-Z) to a world point
	var d: Vector3 = to_local(target_world) - eye_local if is_inside_tree() else target_world - eye_local
	if d.length() < 0.001:
		return Vector2.ZERO
	return Vector2(rad_to_deg(atan2(-d.x, -d.z)), rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length())))


static func add_pose(a: Dictionary, b: Dictionary) -> Dictionary:
	# adds euler degrees of b onto a (for layering a small correction on a pose)
	var out: Dictionary = a.duplicate()
	for k: String in b:
		out[k] = (out.get(k, Vector3.ZERO) as Vector3) + (b[k] as Vector3)
	return out
