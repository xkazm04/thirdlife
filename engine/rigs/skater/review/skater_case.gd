extends SceneTree
## Headless checks of thirdjam's skater in our engine (selftest block 810, engine/tools/selftest.d/810-skater.sh):
##   godot --headless --path engine --script res://rigs/skater/review/skater_case.gd
## One line per case: `SKATER <case> ok=true|false <what was measured>`.
##   body    the baked body: 24 bones, the nine slots by name, 12,040 triangles, 1.637 m tall at rest, no vertex colour
##   clips   the baked library against its table (skater_clips.json): every clip there, with its keys, keyed at 60 a second
##   ref     the figure posed from a clip at a key stands where thirdjam's own figure stands in the Unreal editor
##           (review/reference_poses.json: 27 poses, nine points each), within REF_TOL_M
##   play    play_clip + tick: one key a tick, the loop wraps at the clip's length, two runs give the same poses

const REF_TOL_M: float = 0.0005      # measured 0.00008 m (23 Nov 2026)
const BONES: Array = ["pelvis", "head", "hand_l", "hand_r", "foot_l", "foot_r", "stick_socket", "head_socket"]
const SLOTS: Array = ["Pads", "Jersey", "Trim", "Skin", "Helmet", "Gloves", "Skate", "Blade", "Stick"]


func _init() -> void:
	var sk: TLRigSkater = TLRigSkater.new()
	sk.setup({})
	_body(sk)
	_clips()
	_ref(sk)
	_play()
	sk.free()
	quit(0)


func _say(case: String, ok: bool, text: String) -> void:
	print("SKATER %s ok=%s %s" % [case, "true" if ok else "false", text])


func _body(sk: TLRigSkater) -> void:
	var mesh: Mesh = sk.mesh_instance().mesh
	var tris: int = 0
	var top: float = -INF
	var low: float = INF
	var colour: int = 0
	var names: Array = []
	for s: int in range(mesh.get_surface_count()):
		var arr: Array = mesh.surface_get_arrays(s)
		tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		for v: Vector3 in arr[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			top = maxf(top, v.y)
			low = minf(low, v.y)
		if arr[Mesh.ARRAY_COLOR] != null:
			colour += 1
		names.append(mesh.surface_get_name(s))
	var bones: int = sk.skeleton().get_bone_count()
	var ok: bool = bones == 24 and tris == 12040 and names == SLOTS and absf(top - TLRigSkater.HEIGHT_M) < 0.001 and low > 0.0 and low < 0.005 and colour == 0
	_say("body", ok, "bones=%d triangles=%d slots=%d top=%.4f low=%.4f surfaces_with_colour=%d" % [bones, tris, names.size(), top, low, colour])


func _clips() -> void:
	var table: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://rigs/skater/skater_clips.json"))
	var lib: AnimationLibrary = TLRigSkater.clip_library()
	var want: Array = (table as Dictionary).get("clips", []) if table is Dictionary else []
	var found: int = 0
	var keys: int = 0
	var bad: Array = []
	for row: Dictionary in want:
		var a: Animation = lib.get_animation(StringName(String(row["name"])))
		if a == null:
			bad.append("%s missing" % row["name"])
			continue
		found += 1
		var n: int = TLRigSkater.clip_keys(StringName(String(row["name"])))
		keys += n
		if n != int(row["keys"]):
			bad.append("%s has %d keys, the table says %d" % [row["name"], n, int(row["keys"])])
		for t: int in range(a.get_track_count()):
			var kind: int = a.track_get_type(t)
			if kind != Animation.TYPE_ROTATION_3D and kind != Animation.TYPE_POSITION_3D:
				bad.append("%s track %d is of type %d" % [row["name"], t, kind])
			elif a.track_get_key_count(t) != n or absf(a.track_get_key_time(t, n - 1) - float(n - 1) / 60.0) > 1e-4:
				bad.append("%s track %d is not keyed at 60 a second over the whole clip" % [row["name"], t])
	var ok: bool = want.size() == 202 and found == want.size() and lib.get_animation_list().size() == want.size() and keys == 6923 and bad.is_empty()
	_say("clips", ok, "table=%d found=%d library=%d keys=%d%s" % [want.size(), found, lib.get_animation_list().size(), keys, "" if bad.is_empty() else " bad: " + "; ".join(bad.slice(0, 4))])


## Unreal: centimetres, x forward, y right, z up. Ours: metres, forward -Z, right +X, up +Y.
func _from_ue(p: Array) -> Vector3:
	return Vector3(float(p[1]), float(p[2]), -float(p[0])) * 0.01


func _ref(sk: TLRigSkater) -> void:
	var ref: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://rigs/skater/review/reference_poses.json"))
	var shots: Array = (ref as Dictionary).get("shots", []) if ref is Dictionary else []
	var worst: float = 0.0
	var at: String = ""
	var points: int = 0
	var done: int = 0
	for s: Dictionary in shots:
		if String(s["clip"]) == "rest":
			sk.skeleton().reset_bone_poses()
		elif not sk.pose_at(StringName(String(s["clip"])), float(s["key"])):
			at = "no clip %s" % s["clip"]
			worst = INF
			continue
		done += 1
		for b: String in BONES + ["puck_socket"]:
			var ours: Vector3 = sk.socket_transform(&"puck_socket").origin if b == "puck_socket" else sk.bone_transform(StringName(b)).origin
			var d: float = (ours - _from_ue(s[b])).length()
			points += 1
			if d > worst:
				worst = d
				at = "%s key %d %s" % [s["clip"], int(s["key"]), b]
	var ok: bool = shots.size() >= 27 and done == shots.size() and points == shots.size() * 9 and worst <= REF_TOL_M
	_say("ref", ok, "poses=%d of %d points=%d worst_m=%.5f at=%s tolerance_m=%.4f" % [done, shots.size(), points, worst, at, REF_TOL_M])


func _run() -> Array:
	var sk: TLRigSkater = TLRigSkater.new()
	sk.setup({"team": 1})
	sk.play_clip(&"Stride", true)
	var out: Array = []
	for f: int in range(130):
		sk.tick()
		out.append([sk.clip_key(), sk.bone_transform(&"foot_l").origin, sk.socket_transform(&"puck_socket").origin])
	sk.free()
	return out


func _play() -> void:
	var a: Array = _run()
	var b: Array = _run()
	var same: bool = a == b
	var n: int = TLRigSkater.clip_keys(&"Stride")       # 60 keys: the loop is 59 frames long
	var first: bool = absf(float(a[0][0])) < 1e-6
	var step: bool = absf(float(a[1][0]) - 1.0) < 1e-4 and absf(float(a[10][0]) - 10.0) < 1e-3
	var wrap: bool = absf(float(a[n - 1][0])) < 1e-3 and ((a[n - 1][1] as Vector3) - (a[0][1] as Vector3)).length() < 1e-5
	# a one-shot holds its last key
	var sk: TLRigSkater = TLRigSkater.new()
	sk.setup({})
	sk.play_clip(&"Shot_Slap", false)
	for f: int in range(200):
		sk.tick()
	var held: bool = absf(sk.clip_key() - float(TLRigSkater.clip_keys(&"Shot_Slap") - 1)) < 1e-3
	sk.free()
	_say("play", same and first and step and wrap and held, "same_twice=%s first_key_0=%s one_key_a_tick=%s wraps_at=%d one_shot_holds=%s" % [same, first, step, n - 1, held])
