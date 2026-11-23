extends SceneTree
## Builds the skater figure's baked assets from the Unreal export (engine/tools/skater/export_skater.py):
##   godot --headless --path engine -s res://tools/skater/build_skater.gd -- --src=<export folder> [--check=1]
## Reads   <src>/SK_SkaterTB1_P3.glb          the mesh and its 24-bone skeleton (Unreal's glTF exporter, metres, +X forward)
##         <src>/clips/AS_SkaterTB1_P3_*.glb  one clip each (the same skeleton, keys at 60 a second)
##         <src>/meta.json, clips.json        the material slot order, the sockets, the clip table
##         <src>/tracks/*.json                (--check) Unreal's own bone poses per key, the truth the import is held to
## Writes  res://rigs/skater/skater_body.scn  Node3D "SkaterBody" > Skeleton3D "Skeleton3D" > MeshInstance3D "Mesh"
##         res://rigs/skater/skater_clips.res AnimationLibrary, one Animation per clip, named without the AS_SkaterTB1_P3_ prefix
##         res://rigs/skater/skater_clips.json the clip table: name, keys, seconds (read by the rig and the tests)
## Nothing is resampled, compressed or retimed: the keys in the library are the exporter's keys. Dropped, and counted in
## the report line: scale tracks that are 1 on every key, and position tracks that equal the bone's rest on every key.
## Prints one line `tl.skater.build/1 {...}` last; exit 0 only if every clip found was built (and, with --check, every
## bone of every key lies within JOINT_TOL_M / AXES_TOL_M of Unreal's pose).

const PREFIX := "AS_SkaterTB1_P3_"
const OUT_DIR := "res://rigs/skater/"
const EPS := 1e-6
# --check holds the built clips to the per-key bone poses export_skater.py read with AnimationLibrary.get_bone_pose_for_frame.
# Those are the clip's RAW (authored) keys. The glTF exporter writes the clip's COMPRESSED data, which is what the game
# plays; Unreal's compression moves a bone by up to 0.2 degrees (measured in the editor by reference_capture.py, clip
# Board_Fall_Back key 19 bone foot_l, local quaternion: RAW and SOURCE (-0.517996, 0.78413, 0.028938, 0.340562), COMPRESSED
# (-0.517796, 0.783696, 0.02853, 0.341897), and the glTF holds the COMPRESSED one), so a point 37 cm out on a bone's
# axes lies up to 1.4 mm from the raw key. Joints must agree to JOINT_TOL_M, such points to AXES_TOL_M. Against the
# posed component in the running editor (the compressed data, as in the game) ours agrees to 0.08 mm (pair_sheets.py).
const JOINT_TOL_M := 0.002
const AXES_TOL_M := 0.003


func _init() -> void:
	var args: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var src: String = String(args.get("src", "")).replace("\\", "/").trim_suffix("/")
	var rep: Dictionary = {"schema": "tl.skater.build/1", "ok": false}
	if src == "" or not FileAccess.file_exists(src + "/SK_SkaterTB1_P3.glb"):
		rep["error"] = "no export at --src (expected SK_SkaterTB1_P3.glb): '%s'" % src
		_finish(rep, 2)
		return
	var meta: Dictionary = _json(src + "/meta.json")
	var table: Dictionary = _json(src + "/clips.json")

	# ---------------------------------------------------------------- the body
	var body: Node3D = _load_gltf(src + "/SK_SkaterTB1_P3.glb")
	if body == null:
		rep["error"] = "the mesh did not load"
		_finish(rep, 1)
		return
	var sk: Skeleton3D = _first(body, "Skeleton3D") as Skeleton3D
	var mi: MeshInstance3D = _mesh_instance(body)
	if sk == null or mi == null:
		rep["error"] = "no Skeleton3D or no mesh in the export"
		_finish(rep, 1)
		return
	var ap: Node = _first(body, "AnimationPlayer")
	if ap != null:
		ap.get_parent().remove_child(ap)
		ap.free()
	# the exporter's mesh node sits between the scene root and the skeleton: an identity transform, taken out
	var mid: Node = sk.get_parent()
	if mid != body:
		if not (mid is Node3D) or not (mid as Node3D).transform.is_equal_approx(Transform3D.IDENTITY) or mid.get_parent() != body:
			rep["error"] = "the skeleton's parent is not an identity node under the scene root"
			_finish(rep, 1)
			return
		mid.remove_child(sk)
		sk.owner = null
		body.add_child(sk)
		body.remove_child(mid)
		mid.free()
	if not sk.transform.is_equal_approx(Transform3D.IDENTITY) or not mi.transform.is_equal_approx(Transform3D.IDENTITY) or mi.get_parent() != sk:
		rep["error"] = "the skeleton or the mesh carries a transform of its own"
		_finish(rep, 1)
		return
	body.name = "SkaterBody"
	sk.name = "Skeleton3D"
	mi.name = "Mesh"
	mi.skeleton = NodePath("..")
	var mesh: ArrayMesh = mi.mesh as ArrayMesh
	var slots: Array = []
	for m: Dictionary in meta.get("materials", []):
		slots.append(String(m["slot"]))
	var tris: int = 0
	var lo: Vector3 = Vector3(INF, INF, INF)
	var hi: Vector3 = -lo
	# The exporter's vertex colour is not a colour: thirdjam's jersey material reads it as data (red = the felt mask,
	# green = a per-panel number, blue = an edge mask). Left in COLOR our toon shader would multiply the albedo with
	# it, so it moves to CUSTOM1 (four bytes a vertex, for a later look to read) and COLOR is left out (white).
	var baked: ArrayMesh = ArrayMesh.new()
	for s: int in range(mesh.get_surface_count()):
		var arr: Array = mesh.surface_get_arrays(s)
		var fmt: int = mesh.surface_get_format(s)
		tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		for v: Vector3 in arr[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			lo = lo.min(v)
			hi = hi.max(v)
		var flags: int = fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		if arr[Mesh.ARRAY_COLOR] != null:
			var data: PackedByteArray = PackedByteArray()
			for c: Color in arr[Mesh.ARRAY_COLOR] as PackedColorArray:
				data.append(c.r8)
				data.append(c.g8)
				data.append(c.b8)
				data.append(c.a8)
			arr[Mesh.ARRAY_CUSTOM1] = data
			arr[Mesh.ARRAY_COLOR] = null
			flags |= Mesh.ARRAY_CUSTOM_RGBA8_UNORM << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT
		baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
		baked.surface_set_name(s, slots[s] if s < slots.size() else "slot%d" % s)
		mi.set_surface_override_material(s, null)
	mi.mesh = baked
	mesh = baked
	# fixed ids for the two resources inside the scene file, so a second bake writes the same bytes
	baked.resource_scene_unique_id = "skater_mesh"
	if mi.skin != null:
		mi.skin.resource_scene_unique_id = "skater_skin"
	_own(body, body)
	var bones: PackedStringArray = PackedStringArray()
	for b: int in range(sk.get_bone_count()):
		bones.append(sk.get_bone_name(b))
	rep["bones"] = sk.get_bone_count()
	rep["triangles"] = tris
	rep["surfaces"] = mesh.get_surface_count()
	rep["slots"] = slots
	rep["height_m"] = snappedf(hi.y, 0.0001)
	rep["bounds_min"] = [snappedf(lo.x, 0.0001), snappedf(lo.y, 0.0001), snappedf(lo.z, 0.0001)]
	rep["bounds_max"] = [snappedf(hi.x, 0.0001), snappedf(hi.y, 0.0001), snappedf(hi.z, 0.0001)]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var packed: PackedScene = PackedScene.new()
	var err: int = packed.pack(body)
	if err == OK:
		err = ResourceSaver.save(packed, OUT_DIR + "skater_body.scn", ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		rep["error"] = "skater_body.scn not saved (%d)" % err
		_finish(rep, 1)
		return

	# ---------------------------------------------------------------- the clips
	var names: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(src + "/clips")
	if dir != null:
		for f: String in dir.get_files():
			if f.begins_with(PREFIX) and f.ends_with(".glb"):
				names.append(f.trim_suffix(".glb"))
	names.sort()
	var keys_of: Dictionary = {}
	for c: Dictionary in table.get("clips", []):
		keys_of[String(c["name"])] = c
	var lib: AnimationLibrary = AnimationLibrary.new()
	var rows: Array = []
	var built: int = 0
	var dropped_scale: int = 0
	var kept_scale: Array = []
	var dropped_pos: int = 0
	var kept_pos: Dictionary = {}
	var key_mismatch: Array = []
	var total_keys: int = 0
	var check: bool = args.has("check")
	var worst: float = 0.0
	var worst_at: String = ""
	var worst_joint: float = 0.0
	var worst_joint_at: String = ""
	var checked_keys: int = 0
	var check_failed: Array = []
	var probe: Skeleton3D = sk.duplicate() as Skeleton3D
	for full: String in names:
		var short: String = full.trim_prefix(PREFIX)
		var scene: Node3D = _load_gltf(src + "/clips/" + full + ".glb")
		var player: AnimationPlayer = (_first(scene, "AnimationPlayer") as AnimationPlayer) if scene != null else null
		if player == null or player.get_animation_list().size() != 1:
			rows.append({"name": short, "error": "no single animation in the file"})
			if scene != null:
				scene.free()
			continue
		var csk: Skeleton3D = _first(scene, "Skeleton3D") as Skeleton3D
		var src_anim: Animation = player.get_animation(player.get_animation_list()[0])
		var anim: Animation = Animation.new()
		anim.length = src_anim.length
		anim.step = 1.0 / 60.0
		anim.loop_mode = Animation.LOOP_NONE
		var nkeys: int = 0
		for t: int in range(src_anim.get_track_count()):
			var path: NodePath = src_anim.track_get_path(t)
			var bone: String = path.get_concatenated_subnames()
			var bi: int = sk.find_bone(bone)
			var kind: int = src_anim.track_get_type(t)
			var n: int = src_anim.track_get_key_count(t)
			if bi < 0:
				rows.append({"name": short, "error": "track for an unknown bone '%s'" % bone})
				continue
			if kind == Animation.TYPE_SCALE_3D:
				var one: bool = true
				for k: int in range(n):
					if not (src_anim.track_get_key_value(t, k) as Vector3).is_equal_approx(Vector3.ONE):
						one = false
						break
				if one:
					dropped_scale += 1
					continue
				kept_scale.append(short + ":" + bone)
			elif kind == Animation.TYPE_POSITION_3D:
				var rest: Vector3 = sk.get_bone_rest(bi).origin
				var still: bool = true
				for k: int in range(n):
					if ((src_anim.track_get_key_value(t, k) as Vector3) - rest).length() > EPS:
						still = false
						break
				if still:
					dropped_pos += 1
					continue
				kept_pos[bone] = int(kept_pos.get(bone, 0)) + 1
			elif kind != Animation.TYPE_ROTATION_3D:
				rows.append({"name": short, "error": "track of an unexpected type %d" % kind})
				continue
			var nt: int = anim.add_track(kind)
			anim.track_set_path(nt, NodePath("Skeleton3D:" + bone))
			anim.track_set_interpolation_type(nt, Animation.INTERPOLATION_LINEAR)
			for k: int in range(n):
				var tm: float = src_anim.track_get_key_time(t, k)
				match kind:
					Animation.TYPE_ROTATION_3D: anim.rotation_track_insert_key(nt, tm, src_anim.track_get_key_value(t, k))
					Animation.TYPE_POSITION_3D: anim.position_track_insert_key(nt, tm, src_anim.track_get_key_value(t, k))
					_: anim.scale_track_insert_key(nt, tm, src_anim.track_get_key_value(t, k))
			nkeys = maxi(nkeys, n)
		var want: Dictionary = keys_of.get(full, {})
		if not want.is_empty() and int(want.get("keys", -1)) != nkeys:
			key_mismatch.append("%s: %d keys in Godot, %d in Unreal" % [short, nkeys, int(want.get("keys", -1))])
		lib.add_animation(StringName(short), anim)
		rows.append({"name": short, "keys": nkeys, "seconds": snappedf(anim.length, 0.000001)})
		total_keys += nkeys
		built += 1
		if check:
			var res: Dictionary = _check_clip(probe, anim, _json(src + "/tracks/" + full + ".json"))
			checked_keys += int(res["keys"])
			if float(res["worst"]) > worst:
				worst = float(res["worst"])
				worst_at = "%s %s" % [short, res["at"]]
			if float(res["worst_joint"]) > worst_joint:
				worst_joint = float(res["worst_joint"])
				worst_joint_at = "%s %s" % [short, res["joint_at"]]
			if float(res["worst"]) > AXES_TOL_M or float(res["worst_joint"]) > JOINT_TOL_M or int(res["keys"]) != nkeys:
				check_failed.append("%s: axes %.5f m at %s, joint %.5f m at %s (%d of %d keys)" % [short, float(res["worst"]), res["at"],
					float(res["worst_joint"]), res["joint_at"], int(res["keys"]), nkeys])
		if csk != null and csk.get_bone_count() != sk.get_bone_count():
			rows.append({"name": short, "error": "skeleton of %d bones, the body has %d" % [csk.get_bone_count(), sk.get_bone_count()]})
		scene.free()
	probe.free()
	err = ResourceSaver.save(lib, OUT_DIR + "skater_clips.res", ResourceSaver.FLAG_COMPRESS)
	var errors: Array = []
	for r: Dictionary in rows:
		if r.has("error"):
			errors.append("%s: %s" % [r["name"], r["error"]])
	var good: Array = []
	for r: Dictionary in rows:
		if not r.has("error"):
			good.append(r)
	var f: FileAccess = FileAccess.open(OUT_DIR + "skater_clips.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": "tl.skater.clips/1", "source": "thirdjam SK_SkaterTB1_P3, AS_SkaterTB1_P3_*", "fps": 60,
		"bones": Array(bones), "slots": slots, "sockets": meta.get("sockets", []), "clips": good}, " ") + "\n")
	f.close()
	rep["clips_found"] = names.size()
	rep["clips_built"] = built
	rep["clips_in_unreal_table"] = int(table.get("found", 0))
	rep["total_keys"] = total_keys
	rep["dropped_scale_tracks"] = dropped_scale
	rep["kept_scale_tracks"] = kept_scale
	rep["dropped_rest_position_tracks"] = dropped_pos
	rep["kept_position_tracks_by_bone"] = kept_pos
	rep["key_count_mismatch"] = key_mismatch
	rep["errors"] = errors
	if check:
		rep["check"] = {"keys": checked_keys, "bones": bones.size(), "worst_axes_m": snappedf(worst, 0.000001), "worst_axes_at": worst_at,
			"worst_joint_m": snappedf(worst_joint, 0.000001), "worst_joint_at": worst_joint_at,
			"joint_tolerance_m": JOINT_TOL_M, "axes_tolerance_m": AXES_TOL_M, "failed": check_failed}
	body.free()
	var ok: bool = err == OK and names.size() > 0 and built == names.size() and errors.is_empty() and key_mismatch.is_empty()
	if check:
		ok = ok and check_failed.is_empty() and checked_keys == total_keys
	rep["ok"] = ok
	_finish(rep, 0 if ok else 1)


func _finish(rep: Dictionary, code: int) -> void:
	print("%s %s" % ["PASS" if code == 0 else "FAIL", "skater build"])
	print("tl.skater.build/1 " + JSON.stringify(rep))
	quit(code)


func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}


func _load_gltf(path: String) -> Node3D:
	var doc: GLTFDocument = GLTFDocument.new()
	var st: GLTFState = GLTFState.new()
	st.bake_fps = 60.0
	if doc.append_from_file(path, st) != OK:
		return null
	return doc.generate_scene(st, 60.0) as Node3D


func _first(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c: Node in n.get_children():
		var r: Node = _first(c, cls)
		if r != null:
			return r
	return null


## The export's mesh as a MeshInstance3D with an ArrayMesh (the glTF module hands back an ImporterMeshInstance3D in
## some call paths: convert it in place, keeping the skin and the skeleton path).
func _mesh_instance(root: Node) -> MeshInstance3D:
	var m: MeshInstance3D = _first(root, "MeshInstance3D") as MeshInstance3D
	if m != null:
		return m
	var im: ImporterMeshInstance3D = _first(root, "ImporterMeshInstance3D") as ImporterMeshInstance3D
	if im == null:
		return null
	m = MeshInstance3D.new()
	m.mesh = im.mesh.get_mesh()
	m.skin = im.skin
	m.transform = im.transform
	var parent: Node = im.get_parent()
	parent.add_child(m)
	m.skeleton = m.get_path_to(_first(root, "Skeleton3D"))
	parent.remove_child(im)
	im.free()
	return m


func _own(n: Node, owner: Node) -> void:
	for c: Node in n.get_children():
		c.owner = owner
		_own(c, owner)


# ------------------------------------------------------------------ the check against Unreal's own poses
## Unreal's local bone transforms (centimetres, its own axes) are chained to component space with Unreal's own rule
## (child position = parent rotation x child translation + parent position; rotations multiply parent first), then the
## position goes through the exporter's axis change (x, y, z) cm -> (x, z, y) m. Per bone two points are compared with
## the Godot skeleton posed from the built clip at the same key: the joint, and a point 10 / 20 / 30 cm out along the
## bone's own axes (so a wrong rotation of a leaf bone, the stick's for one, cannot hide).
func _check_clip(sk: Skeleton3D, anim: Animation, tr: Dictionary) -> Dictionary:
	var out: Dictionary = {"keys": 0, "worst": 0.0, "at": "", "worst_joint": 0.0, "joint_at": ""}
	if tr.is_empty():
		out["worst"] = INF
		out["at"] = "no track file"
		return out
	var names: Array = tr["bones"]
	var n: int = int(tr["keys"])
	var parent: Array = []
	var gd: Array = []
	for bn: String in names:
		var bi: int = sk.find_bone(bn)
		gd.append(bi)
		var pi: int = sk.get_bone_parent(bi) if bi >= 0 else -1
		parent.append(names.find(sk.get_bone_name(pi)) if pi >= 0 else -1)
	var track_of: Dictionary = {}
	for t: int in range(anim.get_track_count()):
		track_of["%d:%s" % [anim.track_get_type(t), anim.track_get_path(t).get_concatenated_subnames()]] = t
	var probe_ue: Vector3 = Vector3(10.0, 20.0, 30.0)
	for k: int in range(n):
		var tm: float = float(k) / 60.0
		for i: int in range(names.size()):
			var bi: int = gd[i]
			var rt: int = int(track_of.get("%d:%s" % [Animation.TYPE_ROTATION_3D, names[i]], -1))
			var pt: int = int(track_of.get("%d:%s" % [Animation.TYPE_POSITION_3D, names[i]], -1))
			sk.set_bone_pose_rotation(bi, anim.track_get_key_value(rt, k) if rt >= 0 else sk.get_bone_rest(bi).basis.get_rotation_quaternion())
			sk.set_bone_pose_position(bi, anim.track_get_key_value(pt, k) if pt >= 0 else sk.get_bone_rest(bi).origin)
			sk.set_bone_pose_scale(bi, Vector3.ONE)
			if rt >= 0 and absf(anim.track_get_key_time(rt, k) - tm) > 1e-4:
				out["worst"] = INF
				out["at"] = "key %d of %s is at %.5f s, not %.5f" % [k, names[i], anim.track_get_key_time(rt, k), tm]
				return out
		var gq: Array = []
		var gp: Array = []
		var gg: Dictionary = {}
		for i: int in range(names.size()):
			var q: Array = tr["q"][names[i]][k]
			var p: Array = tr["t"][names[i]][k]
			var lq: Quaternion = Quaternion(q[0], q[1], q[2], q[3])
			var lp: Vector3 = Vector3(p[0], p[1], p[2])
			if int(parent[i]) < 0:
				gq.append(lq)
				gp.append(lp)
			else:
				var pq: Quaternion = gq[parent[i]]
				gq.append(pq * lq)
				gp.append((gp[parent[i]] as Vector3) + pq * lp)
			var ue_joint: Vector3 = gp[i]
			var ue_probe: Vector3 = ue_joint + (gq[i] as Quaternion) * probe_ue
			# chained by hand: a Skeleton3D outside the tree keeps its global poses at rest
			var gpi: int = sk.get_bone_parent(gd[i])
			var g: Transform3D = sk.get_bone_pose(gd[i]) if gpi < 0 else (gg[gpi] as Transform3D) * sk.get_bone_pose(gd[i])
			gg[gd[i]] = g
			var e1: float = (g.origin - _ue_to_gltf(ue_joint)).length()
			# the exporter maps a bone-local Unreal offset (x, y, z) cm to (x, z, y) m as well
			var e2: float = (g * (Vector3(probe_ue.x, probe_ue.z, probe_ue.y) * 0.01) - _ue_to_gltf(ue_probe)).length()
			if e2 > float(out["worst"]):
				out["worst"] = e2
				out["at"] = "key %d bone %s" % [k, names[i]]
			if e1 > float(out["worst_joint"]):
				out["worst_joint"] = e1
				out["joint_at"] = "key %d bone %s" % [k, names[i]]
		out["keys"] = k + 1
	return out


func _ue_to_gltf(v: Vector3) -> Vector3:
	return Vector3(v.x, v.z, v.y) * 0.01
