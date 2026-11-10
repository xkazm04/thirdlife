extends SceneTree
## Headless self-test of the kit, the rigs and the style layer (tools/k.sh selftest). One PASS/FAIL line per case.
##   style      both style files load with no error; a broken style is rejected; out-of-range values are clamped
##   part       every kit part: builds from defaults and from a random valid param set, each twice with equal hashes;
##              node convention (tl_kind, tl_params, tl_material on every body, Intact / Pieces for fracturable parts);
##              unknown and out-of-range params are rejected
##   rig        every rig builds; every clip plays 120 frames (tick + set_locomotion) with finite bone poses; the same
##              clip run twice gives the same pose hash (determinism); sockets; budgets (triangles, bones)
##   layout     every layout in kits_lab/layouts validates and builds; two builds give the same hash; triangle budget
##   refs       nothing under kits/, rigs/, style/ references a path outside those three directories; no global random
##              call, no wall-clock read
## Exit code 1 when any case fails. Everything is counted in frames; nothing depends on wall time.

const BUDGET: Dictionary = {"biped": [12000, 30], "bot": [3000, 30], "vehicle": [8000, 0]}
const LAYOUT_TRIS: int = 600000
var fails: int = 0
var passes: int = 0


func ok(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		passes += 1
		print("PASS %s%s" % [name, ("  " + detail) if detail != "" else ""])
	else:
		fails += 1
		print("FAIL %s%s" % [name, ("  " + detail) if detail != "" else ""])


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var only: String = args[0] if args.size() > 0 else ""
	print("[selftest] headless=%s" % str(TLStyle.headless()))
	if only == "" or only == "style":
		_style()
	if only == "" or only == "part":
		_parts()
	if only == "" or only == "rig":
		_rigs()
	if only == "" or only == "layout":
		_layouts()
	if only == "" or only == "refs":
		_refs()
	print("[selftest] %d passed, %d failed: %s" % [passes, fails, "RESULT PASS" if fails == 0 else "RESULT FAIL"])
	quit(1 if fails > 0 else 0)


func _style() -> void:
	for f: String in ["res://style/style_overcast.json", "res://style/style.json"]:
		var e: PackedStringArray = TLStyle.load_style(f)
		ok(e.is_empty(), "style load " + f.get_file(), "; ".join(e))
	ok(TLStyle.palette().size() > 50 and TLStyle.material(&"grass") != null and TLStyle.material(&"glass") != null, "style palette + materials", "%d palette keys" % TLStyle.palette().size())
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://style/style.json"))
	d["sun"]["elev"] = 500.0
	d["bogus"] = {}
	var e2: PackedStringArray = TLStyle.check(d)
	ok(e2.size() == 1 and e2[0].contains("unknown section"), "style rejects an unknown section", "; ".join(e2))
	d.erase("bogus")
	var e3: PackedStringArray = TLStyle.check(d)
	ok(e3.size() == 1 and e3[0].begins_with("clamped: ") and float(d["sun"]["elev"]) == 80.0, "style clamps sun.elev 500 -> 80", "; ".join(e3))
	var host: Node3D = Node3D.new()
	root.add_child(host)
	TLStyle.install(host)
	TLStyle.install(host)
	ok(host.get_child_count() == 1, "style install is idempotent", "%d child" % host.get_child_count())
	host.free()


static func random_params(table: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var p: Dictionary = {}
	for pn: String in table:
		var a: Array = table[pn]
		match String(a[0]):
			"float": p[pn] = snappedf(rng.randf_range(float(a[2]), minf(float(a[3]), maxf(float(a[2]), float(a[1]) * 2.5 + 1.0))), 0.01)
			"int": p[pn] = rng.randi_range(int(a[2]), mini(int(a[3]), maxi(int(a[2]), int(a[1]) * 2 + 2)))
			"bool": p[pn] = rng.randf() < 0.5
			"enum": p[pn] = a[2][rng.randi_range(0, (a[2] as Array).size() - 1)]
			"key": p[pn] = ["white", "car_red", "car_blue", "yellow", "flag_b"][rng.randi_range(0, 4)]
			"ints": p[pn] = [1, rng.randi_range(int(a[2]), int(a[3]))]
			_: pass
	return p


func _parts() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261110
	for kind: String in TLKit.list():
		var spec: Dictionary = TLKit.spec(kind)
		var problems: PackedStringArray = PackedStringArray()
		var tris: int = 0
		for round: int in 2:
			var p: Dictionary = {} if round == 0 else random_params(TLKit.PARTS[kind][3], rng)
			var errs: PackedStringArray = TLKit.validate(kind, p)
			if errs.size() > 0:
				problems.append("params rejected: " + "; ".join(errs))
				continue
			var a: Node3D = TLKit.build(kind, p)
			var b: Node3D = TLKit.build(kind, p)
			if a == null or b == null:
				problems.append("build returned null (%s)" % ("defaults" if round == 0 else str(p)))
				continue
			if TLKit.hash(a) != TLKit.hash(b):
				problems.append("hash differs between two builds (%s)" % ("defaults" if round == 0 else str(p)))
			problems.append_array(_convention(a, kind, spec))
			if round == 0:
				tris = TLKit.triangles(a)
			a.free()
			b.free()
		if TLKit.validate(kind, {"no_such_param": 1}).is_empty():
			problems.append("an unknown param was accepted")
		ok(problems.is_empty(), "part %s" % kind, "%d tris%s%s" % [tris, ", fracturable" if bool(spec["fracturable"]) else "", ("  " + " | ".join(problems)) if problems.size() > 0 else ""])
	ok(TLKit.validate("rink", {"length": 5000}).size() == 1 and TLKit.validate("gazebo", {}).size() == 1 and TLKit.validate("sign", {"color": "no_such_key"}).size() == 1, "part validation rejects out-of-range, unknown kind, unknown palette key")


func _convention(n: Node3D, kind: String, spec: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if String(n.get_meta("tl_kind", "")) != kind or not (n.get_meta("tl_params", null) is Dictionary):
		out.append("tl_kind / tl_params metadata missing")
	var meshes: int = 0
	var stack: Array = [n]
	while stack.size() > 0:
		var c: Node = stack.pop_back()
		stack.append_array(c.get_children())
		if c is MeshInstance3D:
			meshes += 1
		if c is RigidBody3D:
			out.append("a kit part must not create rigid bodies")
		if c is StaticBody3D:
			if not TLKit.MATERIALS.has(String(c.get_meta("tl_material", ""))):
				out.append("body %s has no valid tl_material" % c.name)
			var shapes: int = 0
			for s: Node in c.get_children():
				if s is CollisionShape3D and (s as CollisionShape3D).shape != null:
					shapes += 1
			if shapes == 0:
				out.append("body %s has no collision shape" % c.name)
	if meshes == 0:
		out.append("no MeshInstance3D")
	if bool(spec["fracturable"]):
		var intact: Node = n.get_node_or_null("Intact")
		var pieces: Node = n.get_node_or_null("Pieces")
		if intact == null or pieces == null:
			out.append("fracturable part without Intact / Pieces")
		else:
			if (pieces as Node3D).visible:
				out.append("Pieces must start hidden")
			if pieces.get_child_count() < 3:
				out.append("fewer than 3 pieces")
			for pc: Node in pieces.get_children():
				if not (pc is MeshInstance3D) or not (pc.get_meta("tl_shape", null) is ConvexPolygonShape3D) or not TLKit.MATERIALS.has(String(pc.get_meta("tl_material", ""))) or float(pc.get_meta("tl_mass_hint", 0.0)) <= 0.0:
					out.append("piece %s lacks tl_shape / tl_material / tl_mass_hint" % pc.name)
					break
	if bool(n.get_meta("tl_dynamic", false)):
		if not (n.get_meta("tl_shape", null) is Shape3D) or not TLKit.MATERIALS.has(String(n.get_meta("tl_material", ""))) or float(n.get_meta("tl_mass_hint", 0.0)) <= 0.0:
			out.append("dynamic prop lacks tl_shape / tl_material / tl_mass_hint")
	return out


static func pose_hash(rig: Node3D) -> String:
	var sk: Skeleton3D = rig.find_child("Skeleton3D", true, false)
	var s: String = ""
	if sk != null:
		for i: int in sk.get_bone_count():
			s += str(sk.get_bone_pose_rotation(i)) + str(sk.get_bone_pose_position(i))
	for c: Node in rig.get_children():
		if c is Node3D:
			s += str((c as Node3D).transform)
			for g: Node in c.get_children():
				if g is Node3D:
					s += str((g as Node3D).transform)
	return s.sha1_text()


static func pose_finite(rig: Node3D) -> bool:
	var sk: Skeleton3D = rig.find_child("Skeleton3D", true, false)
	if sk == null:
		return true
	for i: int in sk.get_bone_count():
		var q: Quaternion = sk.get_bone_pose_rotation(i)
		var p: Vector3 = sk.get_bone_pose_position(i)
		if not (is_finite(q.x) and is_finite(q.y) and is_finite(q.z) and is_finite(q.w) and p.is_finite()) or absf(q.length() - 1.0) > 0.01:
			return false
	return true


func _run_clip(family: String, params: Dictionary, clip: String, in_tree: bool) -> Array:
	var rig: Node3D = TLRigs.build(family, params)
	if in_tree:
		root.add_child(rig)
	rig.call("play", StringName(clip), 0.15)
	var finite: bool = true
	var moved: bool = false
	var first: String = ""
	for f: int in 120:
		if family == "biped" and ["idle", "walk", "run", "skate"].has(clip):
			if f == 0:
				rig.call("play", &"", 0.15)
			rig.call("set_locomotion", Vector3(0, 0, {"idle": 0.0, "walk": -1.4, "run": -5.0, "skate": -6.0}[clip]), true)
		if family == "vehicle":
			rig.call("set_param", &"wheel_spin", 30.0)
			rig.call("set_param", &"steer", sin(float(f) * 0.1))
			rig.call("set_param", &"suspension", [0.05, 0.0, 0.02 * sin(float(f) * 0.3), 0.0])
			rig.call("set_param", &"nitro", 0.5 if f > 60 else 0.0)
		rig.call("tick", f + 1)
		finite = finite and pose_finite(rig)
		var h: String = pose_hash(rig)
		if f == 0:
			first = h
		elif h != first:
			moved = true
	var final: String = pose_hash(rig)
	rig.free()
	return [finite, moved, final]


func _rigs() -> void:
	for family: String in TLRigs.list():
		var rig: Node3D = TLRigs.build(family, {})
		ok(rig != null, "rig %s builds" % family)
		if rig == null:
			continue
		var m: Dictionary = rig.call("metrics")
		var need: Array = ["wheelbase", "track", "wheel_radius", "ride_height", "length", "width", "mass_hint"] if family == "vehicle" else ["height", "radius", "eye_height"]
		var missing: PackedStringArray = PackedStringArray()
		for k: String in need:
			if not m.has(k):
				missing.append(k)
		for meth: String in ["metrics", "clips", "play", "set_locomotion", "set_param", "socket", "tick"]:
			if not rig.has_method(meth):
				missing.append(meth + "()")
		ok(missing.is_empty() and StringName(rig.get("family")) == StringName(family), "rig %s contract members" % family, "missing: " + ", ".join(missing) if missing.size() > 0 else "")
		var tris: int = TLKit.triangles(rig)
		var bones: int = int(m.get("bones", 0))
		ok(tris <= int(BUDGET[family][0]) and (bones <= int(BUDGET[family][1]) or family == "vehicle"), "rig %s budget" % family, "%d triangles (max %d), %d bones (max %d)" % [tris, int(BUDGET[family][0]), bones, int(BUDGET[family][1])])
		var socks: Array = {"biped": ["hand_r", "hand_l", "head", "back", "foot_r", "foot_l"], "vehicle": ["exhaust_l", "exhaust_r", "driver"], "bot": ["tool", "head"]}[family]
		var no_sock: PackedStringArray = PackedStringArray()
		for s: String in socks:
			if rig.call("socket", StringName(s)) == null:
				no_sock.append(s)
		ok(no_sock.is_empty() and rig.call("socket", &"no_such_socket") == null, "rig %s sockets" % family, "missing: " + ", ".join(no_sock) if no_sock.size() > 0 else ", ".join(socks))
		var a: Node3D = TLRigs.build(family, {})
		ok(TLKit.hash(a) == TLKit.hash(rig), "rig %s builds twice with equal hashes" % family)
		a.free()
		var clip_names: PackedStringArray = rig.call("clips")
		rig.free()
		if family == "biped":
			var want: Array = ["idle", "walk", "run", "skate", "skate_stop", "shoot", "pass", "cheer", "fall", "carry", "work"]
			var lacking: PackedStringArray = PackedStringArray()
			for w: String in want:
				if not clip_names.has(w):
					lacking.append(w)
			ok(lacking.is_empty(), "rig biped has the 11 required clips", ", ".join(lacking))
		for clip: String in clip_names:
			var p: Dictionary = {}
			if family == "biped" and ["skate", "skate_stop", "shoot", "pass"].has(clip):
				p = {"mode": "skate", "stick": true}
			var r1: Array = _run_clip(family, p, clip, true)
			var r2: Array = _run_clip(family, p, clip, false)   # not in the tree: same result, no error
			ok(bool(r1[0]) and bool(r1[1]) and r1[2] == r2[2], "rig %s clip %s 120 frames" % [family, clip],
				"%s%s%s" % ["" if bool(r1[0]) else "non-finite pose ", "" if bool(r1[1]) else "pose never changed ", "deterministic" if r1[2] == r2[2] else "two runs differ"])
	# params and blending
	var b: Node3D = TLRigs.build("biped", {"colors": {"top": "car_blue"}, "scale": 1.2})
	root.add_child(b)
	b.call("set_param", &"mode", &"skate")
	b.call("set_param", &"stick", true)
	b.call("set_param", &"look_at", Vector3(3, 1.5, -4))
	b.call("set_param", &"expression", &"focus")
	b.call("set_param", &"lean", 0.7)
	b.call("set_param", &"colors", {"top": "car_red", "legs": "black"})
	var okp: bool = true
	for f: int in 90:
		b.call("set_locomotion", Vector3(0, 0, -float(f) * 0.1), f % 30 != 29)
		if f == 20:
			b.call("play", &"shoot", 0.1)
		if f == 50:
			b.call("play", &"no_such_clip")
		b.call("tick", f + 1)
		okp = okp and pose_finite(b)
	ok(okp and String(b.get("clip")) == "", "rig biped params, locomotion blend, upper-body shot over skating, unknown clip ignored")
	b.free()
	ok(TLRigs.validate("biped", {"mode": "swim"}).size() == 1 and TLRigs.validate("vehicle", {"wings": true}).size() == 1 and TLRigs.validate("drone", {}).size() == 1, "rig validation rejects bad enum, unknown param, unknown family")


func _layouts() -> void:
	var dir: DirAccess = DirAccess.open("res://kits_lab/layouts")
	var files: PackedStringArray = dir.get_files() if dir != null else PackedStringArray()
	files.sort()
	for f: String in files:
		if not f.ends_with(".json") or f.begins_with("broken"):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://kits_lab/layouts/" + f))
		if not (parsed is Dictionary):
			ok(false, "layout %s" % f, "not a JSON object")
			continue
		var errs: PackedStringArray = TLKit.validate_layout(parsed)
		if errs.size() > 0:
			ok(false, "layout %s validates" % f, "; ".join(errs.slice(0, 4)))
			continue
		var host: Node3D = Node3D.new()
		root.add_child(host)
		var r1: Dictionary = TLKit.build_layout(parsed, host)
		var h1: String = TLKit.hash(r1["root"]) if r1.get("ok", false) else ""
		var tris: int = int(r1.get("triangles", 0))
		var bodies: int = host.find_children("*", "StaticBody3D", true, false).size()
		var untagged: int = 0
		for sb: Node in host.find_children("*", "StaticBody3D", true, false):
			if not TLKit.MATERIALS.has(String(sb.get_meta("tl_material", ""))):
				untagged += 1
		host.free()
		var host2: Node3D = Node3D.new()
		root.add_child(host2)
		var r2: Dictionary = TLKit.build_layout(parsed, host2)
		var h2: String = TLKit.hash(r2["root"]) if r2.get("ok", false) else "x"
		host2.free()
		ok(bool(r1.get("ok", false)) and h1 == h2 and tris <= LAYOUT_TRIS and untagged == 0, "layout %s builds" % f,
			"%d nodes, %d triangles (max %d), %d bodies%s%s%s" % [(r1.get("nodes", {}) as Dictionary).size(), tris, LAYOUT_TRIS, bodies,
			"" if h1 == h2 else ", two builds differ", "" if untagged == 0 else ", %d bodies without tl_material" % untagged, ("  " + "; ".join((r1.get("errors", []) as PackedStringArray).slice(0, 3))) if not r1.get("ok", false) else ""])
	var bad: Dictionary = {"schema": "tl.layout/1", "name": "bad", "sead": 3, "arenas": [{"id": "a", "c": [0, 0, 0], "ribs": {"count": 2, "built": 5, "dx": 8}}],
		"props": [{"kind": "gazebo", "p": [0, 0]}, {"kind": "sign", "p": [0, 0], "params": {"colour": "sign"}}], "_note": "a comment key is allowed"}
	var be: PackedStringArray = TLKit.validate_layout(bad)
	ok(be.size() == 4, "layout validator: unknown key, built > count, unknown kind, unknown param; `_` key accepted", "%d errors: %s" % [be.size(), " | ".join(be)])
	var host3: Node3D = Node3D.new()
	var rb: Dictionary = TLKit.build_layout(bad, host3)
	ok(not bool(rb["ok"]) and host3.get_child_count() == 0, "an invalid layout builds nothing")
	host3.free()


func _refs() -> void:
	var bad: PackedStringArray = PackedStringArray()
	var banned: Array = ["randf(", "randi(", "randomize(", "rand_range(", "randfn(", "Time.get", "OS.get_ticks", "OS.get_unix", "Engine.get_frames_drawn", "get_ticks_msec", "get_ticks_usec"]
	for d: String in ["res://kits", "res://rigs", "res://style"]:
		_scan(d, banned, bad)
	ok(bad.is_empty(), "refs: kits/ rigs/ style/ are self-contained, no global random, no wall clock", "; ".join(bad.slice(0, 6)))


func _scan(dir_path: String, banned: Array, bad: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_scan(dir_path + "/" + sub, banned, bad)
	for f: String in dir.get_files():
		if not (f.ends_with(".gd") or f.ends_with(".gdshader") or f.ends_with(".json") or f.ends_with(".tscn")):
			continue
		var text: String = FileAccess.get_file_as_string(dir_path + "/" + f)
		var ln: int = 0
		for line: String in text.split("\n"):
			ln += 1
			var from: int = 0
			while true:
				var i: int = line.find("res://", from)
				if i < 0:
					break
				from = i + 6
				var rest: String = line.substr(i + 6)
				if not (rest.begins_with("kits/") or rest.begins_with("rigs/") or rest.begins_with("style/")):
					bad.append("%s:%d references res://%s" % [f, ln, rest.substr(0, 24)])
			if f.ends_with(".gd"):
				var code: String = line.split("#")[0]
				for b: String in banned:
					var j: int = code.find(b)
					# a call on a seeded generator (rng.randf(), mk.rng.randf_range()) is the allowed form
					if j >= 0 and (j == 0 or code[j - 1] != "."):
						bad.append("%s:%d uses %s" % [f, ln, b])
