extends SceneTree
## Selftest block 660 (lane L2 fight-clips, 21 Nov 2026), headless. Prints one `FIGHT <case> ok=true|false ...` line per
## case, under the classic, crisp (cel) and diorama (clay) looks:
##   clips   the eight fight clips exist on the walking and the skating biped, each with the length of
##           TLRigBipedFight.TIMING and of the "Fight clips" table of rigs/RIGS.md (frames, anticipation, active,
##           control, ends); a "returns" clip is back to locomotion one tick after its last frame, a "holds" clip
##           still shows its last pose 40 ticks later; two runs of every clip give the same poses
##   golden  the baseline clips and both swings match their latest entries in fight_golden.txt, with stick_yaw
##           never set and with stick_yaw set to 0 every tick
##   yaw     stick_yaw turns the blade to the side it names (+ = left), costs nothing at 0, and the pose is the golden
##           one again on the tick after it goes back to 0
##   cross   cross_check with a stick, held: the shaft lies level across the chest (butt to the left), both hands on it
##           and apart, chest-high; roll is upside down at its middle frame
## Regenerate the golden file only when an existing clip changes on purpose: --golden=<abs path> on that tree. New clips
## append their lines (21 Nov: falls arm A added 72 lines for its hit, fall and get-up clips; the 120 older lines are unchanged).

const F := preload("res://rigs/biped/tl_rig_biped_fight.gd")
const LOOKS: Array = ["res://style/style.json", "res://style/style_crisp.json", "res://style/style_diorama.json"]
const SKIP: Array = ["Hair", "Backpack"]     # secondary motion of the cel and clay figures keeps settling in a hold
const SKIP_HOLD: Array = ["Hair", "Backpack", "LeftShoulder", "RightShoulder"]   # + the clay shoulders easing up over 7 ticks
const HELD: Array = ["block", "body_check", "cross_check"]   # round L2b: the key pose holds 3 frames from the hit

var fails: Dictionary = {"clips": [], "golden": [], "yaw": [], "cross": []}
var notes: Dictionary = {"clips": 0, "golden": 0, "yaw": "", "cross": ""}


static func pose_hash(rig: Node3D, skip: Array = []) -> String:
	var sk: Skeleton3D = rig.find_child("Skeleton3D", true, false)
	var s: String = ""
	for i: int in sk.get_bone_count():
		if skip.has(sk.get_bone_name(i)):
			continue
		var q: Quaternion = sk.get_bone_pose_rotation(i)
		var p: Vector3 = sk.get_bone_pose_position(i)
		s += "%.5f,%.5f,%.5f,%.5f|%.5f,%.5f,%.5f;" % [q.x, q.y, q.z, q.w, p.x, p.y, p.z]
	var b: Node3D = rig.call("socket", &"stick_blade")
	if b != null and b.is_inside_tree():
		var g: Vector3 = b.global_position
		s += "B%.4f,%.4f,%.4f" % [g.x, g.y, g.z]
	return s.sha1_text().substr(0, 12)


## The golden run of one clip (as written on the base tree): 130 ticks, locomotion stepping through 0 / 1.4 / 5 m/s with
## a little side drift and an air tick every 50; hashes at six frames. yaw_mode 0 = never set, 1 = set to 0.0 every tick.
func golden_run(params: Dictionary, clip: String, yaw_mode: int) -> String:
	var rig: Node3D = TLRigs.build("biped", params)
	root.add_child(rig)
	rig.call("play", StringName(clip), 0.15)
	var hs: PackedStringArray = []
	for f: int in 130:
		var v: float = [0.0, -1.4, -5.0][f / 45 % 3]
		rig.call("set_locomotion", Vector3(0.3 * sin(f * 0.05), 0, v), f % 50 != 49)
		if yaw_mode == 1:
			rig.call("set_param", &"stick_yaw", 0.0)
		rig.call("tick", f + 1)
		if f in [3, 9, 20, 40, 70, 129]:
			hs.append(pose_hash(rig))
	rig.free()
	return ",".join(hs)


var _done: bool = false


## The golden runs and the clip checks run here, before the root is in the tree (as on the base tree, where the golden
## file was written); the yaw and cross-check cases need world transforms and run on the first frame (_process).
func _initialize() -> void:
	var gold_out: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--golden="):
			gold_out = a.trim_prefix("--golden=")
	var golden: Dictionary = {}
	if gold_out == "":
		var gf: FileAccess = FileAccess.open("res://rigs/review/fight_golden.txt", FileAccess.READ)
		if gf == null:
			fails["golden"].append("no fight_golden.txt")
		else:
			for line: String in gf.get_as_text().split("\n", false):
				if line.begins_with("#"):
					continue
				var parts: PackedStringArray = line.split("|")
				golden["%s|%s|%s" % [parts[0], parts[1], parts[2]]] = parts[3]
	var table: Dictionary = _rigs_md_table()
	var out: PackedStringArray = []
	for look: String in LOOKS:
		TLStyle.load_style(look)
		for pset: Dictionary in [{}, {"mode": "skate", "stick": true}]:
			var mode: String = "skate" if pset.size() > 0 else "walk"
			var probe: Node3D = TLRigs.build("biped", pset)
			var names: PackedStringArray = probe.call("clips")
			var clips_d: Dictionary = probe.get("_clips")
			probe.free()
			for clip: String in names:
				var key: String = "%s|%s|%s" % [look.get_file(), mode, clip]
				if F.TIMING.has(clip) and clip not in ["strike", "strike_heavy"]:
					continue
				var h: String = golden_run(pset, clip, 0)
				if gold_out != "":
					out.append(key + "|" + h)
					continue
				notes["golden"] = int(notes["golden"]) + 1
				if not golden.has(key):
					fails["golden"].append(key + ": not in the golden file")
				elif golden[key] != h:
					fails["golden"].append(key + ": pose moved")
				elif golden_run(pset, clip, 1) != h:
					fails["golden"].append(key + ": stick_yaw = 0 moved the pose")
			if gold_out != "":
				continue
			for clip: String in F.TIMING:
				_check_clip(look.get_file(), mode, pset, clip, names, clips_d, table)
	if gold_out != "":
		var f: FileAccess = FileAccess.open(gold_out, FileAccess.WRITE)
		f.store_string("\n".join(out) + "\n")
		f.close()
		print("FIGHT golden written %s (%d lines)" % [gold_out, out.size()])
		_done = true
		quit()
		return
	_check_dodge_side()
	if golden.size() != int(notes["golden"]):
		fails["golden"].append("%d golden lines, %d clip runs: an existing clip is missing" % [golden.size(), int(notes["golden"])])


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_check_yaw()
	_check_cross()
	print("FIGHT clips ok=%s checked=%d %s" % [str(fails["clips"].is_empty()), int(notes["clips"]), "; ".join(fails["clips"]).substr(0, 400)])
	print("FIGHT golden ok=%s runs=%d %s" % [str(fails["golden"].is_empty()), int(notes["golden"]), "; ".join(fails["golden"]).substr(0, 400)])
	print("FIGHT yaw ok=%s %s %s" % [str(fails["yaw"].is_empty()), notes["yaw"], "; ".join(fails["yaw"]).substr(0, 400)])
	print("FIGHT cross ok=%s %s %s" % [str(fails["cross"].is_empty()), notes["cross"], "; ".join(fails["cross"]).substr(0, 400)])
	quit()
	return true


## RIGS.md "Fight clips" rows: clip -> [frames, anticipation, active, control, ends].
func _rigs_md_table() -> Dictionary:
	var t: Dictionary = {}
	var f: FileAccess = FileAccess.open("res://rigs/RIGS.md", FileAccess.READ)
	if f == null:
		return t
	var on: bool = false
	for line: String in f.get_as_text().split("\n"):
		if line.begins_with("## "):
			on = line.begins_with("## Fight clips")
		if on and line.begins_with("| `"):
			var c: PackedStringArray = line.split("|")
			t[c[1].strip_edges().trim_prefix("`").trim_suffix("`")] = [c[2].strip_edges(), c[3].strip_edges(), c[4].strip_edges(), c[7].strip_edges(), c[8].strip_edges(), c[5].strip_edges()]
	return t


func _check_clip(look: String, mode: String, pset: Dictionary, clip: String, names: PackedStringArray, clips_d: Dictionary, table: Dictionary) -> void:
	var where: String = "%s %s %s" % [look, mode, clip]
	notes["clips"] = int(notes["clips"]) + 1
	if not names.has(clip):
		fails["clips"].append(where + ": missing")
		return
	var tm: Dictionary = F.TIMING[clip]
	var n: int = int(tm["frames"])
	var holds: bool = String(tm["end"]) == "holds"
	var c: Dictionary = clips_d[clip]
	if roundi(float(c["dur"]) * 60.0) != n or bool(c["loop"]) or bool(c["hold"]) != holds or bool(c["upper"]) != bool(tm["upper"]):
		fails["clips"].append(where + ": registered %.3f s loop=%s hold=%s upper=%s" % [float(c["dur"]), c["loop"], c["hold"], c["upper"]])
	var row: Array = table.get(clip, [])
	var want: Array = [str(n), str(tm["anticipation"]), str(tm["active"]), str(tm["control"]), "holds" if holds else "returns", str(tm["hit"]) if tm.has("hit") else "-"]
	if row.size() != 6 or row[0] != want[0] or row[1] != "0-" + want[1] or row[2] != want[1] + "-" + want[2] or row[3] != want[3] or not String(row[4]).begins_with(want[4]) or row[5] != want[5]:
		fails["clips"].append(where + ": RIGS.md row %s, TIMING %s" % [str(row), str(want)])
	if tm.has("hit") and (int(tm["hit"]) < int(tm["anticipation"]) or int(tm["hit"]) > int(tm["active"])):
		fails["clips"].append(where + ": hit f%d is outside anticipation..active" % int(tm["hit"]))
	var hold_at: int = int(tm["hit"]) if HELD.has(clip) else -1
	var runs: Array = []
	for rep: int in 2:
		var rig: Node3D = TLRigs.build("biped", pset)
		root.add_child(rig)
		rig.call("set_locomotion", Vector3.ZERO, true)
		rig.call("tick", 0)
		rig.call("play", StringName(clip), 0.15)
		var seq: PackedStringArray = []
		var end_ok: bool = true
		var held: String = ""
		var held_key: String = ""
		for f: int in n + 41:
			rig.call("set_locomotion", Vector3(2.0 if clip == "dodge" and f < 3 else 0.0, 0, 0), true)
			rig.call("tick", f + 1)
			seq.append(pose_hash(rig))
			if f + 1 == hold_at:
				held_key = pose_hash(rig, SKIP_HOLD)
			if hold_at > 0 and f + 1 == hold_at + 3 and pose_hash(rig, SKIP_HOLD) != held_key:
				fails["clips"].append(where + ": the key pose does not hold from the hit f%d to f%d" % [hold_at, hold_at + 3])
			if f + 1 == n - 1 and String(rig.get("clip")) != clip:
				end_ok = false
			if f + 1 == n + 1 and not holds and String(rig.get("clip")) != "":
				end_ok = false
			if holds and f + 1 == n + 11:
				held = pose_hash(rig, SKIP)
			if holds and f + 1 == n + 41 and (String(rig.get("clip")) != clip or pose_hash(rig, SKIP) != held):
				end_ok = false
		if not end_ok:
			fails["clips"].append(where + ": does not end as RIGS.md says (%s)" % tm["end"])
		runs.append(",".join(seq))
		rig.free()
	if runs[0] != runs[1]:
		fails["clips"].append(where + ": two runs differ")


## dodge_side: -1 steps left and +1 right whatever the body does; 0 = the side the body moves (the hips lean that way).
func _check_dodge_side() -> void:
	for look: String in LOOKS:
		TLStyle.load_style(look)
		for c: Array in [[-1.0, 3.0, 1.0], [1.0, -3.0, -1.0], [0.0, -3.0, 1.0], [0.0, 3.0, -1.0]]:
			var rig: Node3D = TLRigs.build("biped", {})
			root.add_child(rig)
			if float(c[0]) != 0.0:
				rig.call("set_param", &"dodge_side", float(c[0]))
			rig.call("play", &"dodge", 0.0)
			for f: int in 6:
				rig.call("set_locomotion", Vector3(float(c[1]), 0, 0), true)
				rig.call("tick", f + 1)
			var sk: Skeleton3D = rig.find_child("Skeleton3D", true, false)
			var z: float = sk.get_bone_pose_rotation(sk.find_bone("Hips")).get_euler().z
			if z * float(c[2]) < 0.2:
				fails["clips"].append("%s dodge_side %+.0f moving %+.0f m/s: hips roll %.2f rad, want sign %+.0f" % [look.get_file(), float(c[0]), float(c[1]), z, float(c[2])])
			rig.free()


## The stick in the rig's own space, from the bone poses (a BoneAttachment3D only follows its bone once a frame is drawn).
func _stick_xf(rig: Node3D) -> Transform3D:
	var sk: Skeleton3D = rig.find_child("Skeleton3D", true, false)
	var hand: Node3D = rig.call("socket", &"hand_r")
	var stick: Node3D = rig.find_child("Stick", true, false)
	return (sk.get_parent() as Node3D).transform * sk.get_bone_global_pose(sk.find_bone("RightHand")) * hand.transform * stick.transform


static func _bearing(p: Vector3) -> float:
	return atan2(-p.x, -p.z)


func _blade(rig: Node3D) -> Vector3:
	return _stick_xf(rig) * (rig.call("socket", &"stick_blade") as Node3D).position


func _check_yaw() -> void:
	var parts: PackedStringArray = []
	for look: String in LOOKS:
		TLStyle.load_style(look)
		var rig: Node3D = TLRigs.build("biped", {"mode": "skate", "stick": true})
		var twin: Node3D = TLRigs.build("biped", {"mode": "skate", "stick": true})   # never turned: the yaw-0 pose
		root.add_child(rig)
		root.add_child(twin)
		var xs: Dictionary = {}
		for f: int in 80:
			var y: float = 0.0 if f < 20 else (1.0 if f < 40 else (-1.0 if f < 60 else 0.0))
			rig.call("set_param", &"stick_yaw", y)
			for r: Node3D in [rig, twin]:
				r.call("set_locomotion", Vector3(0, 0, -2.0 if f > 64 else 0.0), true)
				r.call("tick", f + 1)
			if f == 19:
				xs["0"] = _blade(rig)
			elif f == 39:
				xs["+"] = _blade(rig)
			elif f == 59:
				xs["-"] = _blade(rig)
			if (f < 20 or f >= 60) and pose_hash(rig, SKIP) != pose_hash(twin, SKIP):
				fails["yaw"].append("%s: at yaw 0 the pose differs from a rig never turned (tick %d)" % [look.get_file(), f + 1])
				break
		rig.free()
		twin.free()
		# the blade's bearing round the body (+ = left of straight ahead) turns by about the yaw, each way
		var dl: float = wrapf(_bearing(xs["+"]) - _bearing(xs["0"]), -PI, PI)
		var dr: float = wrapf(_bearing(xs["-"]) - _bearing(xs["0"]), -PI, PI)
		if not (dl > 0.6 and dl < 1.4 and dr < -0.6 and dr > -1.4):
			fails["yaw"].append("%s: the blade's bearing turns %.2f rad at +1 rad, %.2f at -1 rad" % [look.get_file(), dl, dr])
		var hy: float = absf((xs["+"] as Vector3).y - (xs["0"] as Vector3).y)
		if hy > 0.25:
			fails["yaw"].append("%s: the blade leaves the ice by %.2f m at +1 rad" % [look.get_file(), hy])
		parts.append("%s blade at rest: bearing %+.2f rad, %.2f m out; turns %+.2f / %+.2f rad at +1 / -1 rad (height change %.2f m)" % [look.get_file().get_basename(), _bearing(xs["0"]), Vector2(xs["0"].x, xs["0"].z).length(), dl, dr, hy])
	notes["yaw"] = ", ".join(parts)


func _check_cross() -> void:
	var parts: PackedStringArray = []
	for look: String in LOOKS:
		TLStyle.load_style(look)
		var rig: Node3D = TLRigs.build("biped", {"mode": "skate", "stick": true})
		root.add_child(rig)
		rig.call("set_locomotion", Vector3.ZERO, true)
		rig.call("tick", 0)
		rig.call("play", &"cross_check", 0.05)
		for f: int in 30:
			rig.call("set_locomotion", Vector3.ZERO, true)
			rig.call("tick", f + 1)
		var shaft: Vector3 = _stick_xf(rig).basis.y.normalized()
		var sk: Skeleton3D = rig.find_child("Skeleton3D", true, false)
		var model: Node3D = sk.get_parent()
		var hr: Vector3 = rig.to_local(model.to_global(sk.get_bone_global_pose(sk.find_bone("RightHand")).origin))
		var hl: Vector3 = rig.to_local(model.to_global(sk.get_bone_global_pose(sk.find_bone("LeftHand")).origin))
		var apart: float = (hr - hl).length()
		var mid: Vector3 = _stick_xf(rig) * Vector3(0, -0.235, 0)     # the middle of the shaft (butt +0.55, blade end -1.02)
		var off: float = absf(mid.x - (hr.x + hl.x) * 0.5)
		if off > 0.15:
			fails["cross"].append("%s: the shaft's middle is %.2f m off the middle of the hands" % [look.get_file(), off])
		if absf(shaft.y) > 0.25 or shaft.x > -0.85:
			fails["cross"].append("%s: shaft %s is not level across the chest" % [look.get_file(), str(shaft)])
		if apart < 0.3 or hr.y < 0.85 or hr.y > 1.55 or hr.z > -0.25:
			fails["cross"].append("%s: hands %s / %s (apart %.2f m)" % [look.get_file(), str(hr), str(hl), apart])
		parts.append("%s shaft.y %.2f hands apart %.2f m at %.2f m, %.2f m ahead, shaft middle %.2f m off" % [look.get_file().get_basename(), shaft.y, apart, hr.y, -hr.z, off])
		rig.free()
		# the roll is upside down half-way through
		var r: Node3D = TLRigs.build("biped", {})
		root.add_child(r)
		r.call("play", &"roll", 0.0)
		for f: int in 12:
			r.call("tick", f + 1)
		var sk2: Skeleton3D = r.find_child("Skeleton3D", true, false)
		var up: Vector3 = sk2.get_bone_global_pose(sk2.find_bone("Hips")).basis.y
		if up.y > -0.5:
			fails["cross"].append("%s: roll at f12 is not upside down (hips up %s)" % [look.get_file(), str(up)])
		r.free()
	notes["cross"] = ", ".join(parts)
