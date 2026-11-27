extends SceneTree
## M6 round 2, lane T (27 Nov 2026): courses travel (contracts/BUILD.md "Courses travel: tl.stamp/2 and the share
## code"; stamp_file.gd, tools/stamp_tool.gd), headless, no landscape. Prints `HOME stamp-courses.<case> ok|fail
## <detail>`, then `HOME stamp-courses ok` (or fail) and `HOME DONE`; engine/tools/selftest.d/788-home-stamp-courses.sh
## reads them. Frames, not wall clock.
##   stamp-courses.v1        a box with no zones is tl.stamp/1: the v1 keys only, in the v1 order, saved bytes as text_of
##   stamp-courses.v2        a course (the Rules tool's presets) stamped: the zones wholly inside, the rules naming only
##                           them, ids 1.. and references rewritten; a zone half out and a rule naming it left out;
##                           saved, listed, read back byte for byte
##   stamp-courses.turns     placed at 4 rots: every zone box where an independent turn of its corners' centres says,
##                           blocks, zones and rules in ONE batch, one undo empties it
##   stamp-courses.renumber  placed into a Home that has zones and rules: the next free ids, every reference to the new
##                           zones, the Home's own untouched
##   stamp-courses.run       the placed course runs (rules_run.gd over a scripted feet path): start, 3 coins, finish
##   stamp-courses.code      the share code: TL1-, base64url, no padding, a zlib stream; read back byte for byte
##   stamp-courses.refusals  bad prefix, cut short, a letter outside base64url, not a stream, not JSON, an unknown key
##                           (top, zone, rule), a rule naming a zone not in it, a v2 with no zones, too long
##   stamp-courses.tool      the stamp tool: a box over the course (its top reaches the finish zone), G, Ctrl+C (the
##                           info line's length), another Home: Ctrl+V adds it, LMB places it (one batch)

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const BuildMode := preload("res://kernel/world/build/build_mode.gd")
const Blocks := preload("res://kernel/world/build/blocks.gd")
const StampFile := preload("res://kernel/world/build/stamp_file.gd")
const Presets := preload("res://kernel/world/build/rules_tool_presets.gd")
const Check := preload("res://kernel/world/build/rules_check.gd")
const RulesRun := preload("res://kernel/world/build/rules_run.gd")
const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const TMP := "user://tl_stamp_courses_case"
const LO := Vector3i(0, 0, -4)
const HI := Vector3i(16, 8, 4)

var ok_all := true


class Rec extends "res://kernel/world/build/rules_facade.gd":
	var log := []
	func set_open(z: int, _b: Array, o: bool) -> void: log.append(["set_open", z, o])
	func look_taken(z: int, t: bool) -> void: log.append(["look_taken", z, t])
	func launch(u: int, f: int) -> void: log.append(["launch", u, f])
	func teleport(at: Vector3) -> void: log.append(["teleport", at])
	func say(t: String, n: int) -> void: log.append(["say", t, n])
	func run_started(n: String, _f: int) -> void: log.append(["run_started", n])
	func run_finished(n: String, f: int, _b: int, _nb: bool) -> void: log.append(["run_finished", n, f])
	func run_stopped(n: String, w: String) -> void: log.append(["run_stopped", n, w])


func _initialize() -> void:
	call_deferred("run")


func say(case_name: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME stamp-courses.%s %s %s" % [case_name, "ok" if ok else "fail", detail])


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func run() -> void:
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	DirAccess.make_dir_recursive_absolute(TMP)
	v1_case()
	var st := v2_case()
	turns_case(st)
	var placed := renumber_case(st)
	run_case(placed)
	code_case(st)
	refusals_case(st)
	await tool_case()
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	print("HOME stamp-courses %s" % ("ok" if ok_all else "fail"))
	print("HOME DONE")
	quit(0)


## A stone floor (y 0, x 0..16, z -4..4), a wall at x 6 (y 1..3), a tower x 10..12 (y 1..4).
static func stage(b: RefCounted) -> void:
	var ops := []
	for x in range(0, 17):
		for z in range(-4, 5):
			ops.append({"op": "place", "at": [x, 0, z], "shape": Blocks.CUBE, "mat": 2, "rot": 0})
	for y in range(1, 4):
		for z in range(-4, 5):
			ops.append({"op": "place", "at": [6, y, z], "shape": Blocks.CUBE, "mat": 6, "rot": 0})
	for x in range(10, 13):
		for y in range(1, 5):
			for z in range(-1, 2):
				ops.append({"op": "place", "at": [x, y, z], "shape": Blocks.CUBE, "mat": 6, "rot": 0})
	b.apply(ops)


## The tower course by the Rules tool's presets, and what a stamp must leave out: a zone half out of the box and a rule
## naming it.
static func course(b: RefCounted) -> void:
	var rl: RefCounted = b.layer("rules")
	var put := func(kind: String, lo: Vector3i, hi: Vector3i, opt: Dictionary) -> void:
		var r: Dictionary = b.apply(Presets.ops(rl, kind, lo, hi, opt))
		assert(bool(r.ok), str(r.refused))
	put.call("start", Vector3i(0, 1, -1), Vector3i(1, 1, 1), {"run": "Tower"})
	put.call("coin", Vector3i(2, 1, 0), Vector3i(2, 1, 0), {})
	put.call("coin", Vector3i(3, 1, 2), Vector3i(3, 1, 2), {})
	put.call("coin", Vector3i(4, 1, -2), Vector3i(4, 1, -2), {})
	put.call("door", Vector3i(6, 1, 0), Vector3i(6, 2, 0), {"thin": 0})
	put.call("pad", Vector3i(8, 1, 0), Vector3i(8, 1, 0), {})
	put.call("finish", Vector3i(11, 5, 0), Vector3i(11, 5, 0), {})
	var far: int = rl.next_zone_id()
	b.apply([{"op": "zone", "id": far, "box": [[15, 1, 3], [18, 2, 4]], "look": "none", "name": "Half out"},
		{"op": "rule", "id": rl.next_rule_id(), "when": {"on": "enter", "zone": 1}, "do": [{"do": "teleport", "zone": far}]}])


func v1_case() -> void:
	var b: RefCounted = HomeBuild.new(null, null, {})
	stage(b)
	b.apply([{"op": "zone", "id": 1, "box": [[30, 1, 0], [31, 2, 1]], "look": "pad", "name": "Elsewhere"}])
	var r: Dictionary = StampFile.from_region(b, LO, HI, "Plain")
	var text: String = StampFile.text_of(r.stamp)
	var keys: Array = (r.stamp as Dictionary).keys()
	var v1_text := "{%s}\n" % ",".join(PackedStringArray(["schema", "name", "size", "blocks"].map(func(k: String) -> String:
		return "%s:%s" % [JSON.stringify(k), JSON.stringify(r.stamp[k], "", false)])))
	var dir := TMP.path_join("v1")
	var w: Dictionary = StampFile.save(dir, r.stamp)
	var bytes_ok: bool = bool(w.ok) and FileAccess.get_file_as_string(w.path) == v1_text
	var ok: bool = bool(r.ok) and str(r.stamp.schema) == "tl.stamp/1" and keys == ["schema", "name", "size", "blocks"] and text == v1_text and bytes_ok \
		and not text.contains("zones") and StampFile.validate(r.stamp) == ""
	say("v1", ok, "a box of %d blocks, a zone outside it: schema %s, keys %s, text = the v1 form %s, the file's bytes the same %s (%d bytes)" % [
		(r.stamp.blocks as Array).size(), str(r.stamp.schema), str(keys), text == v1_text, bytes_ok, text.length()])


func v2_case() -> Dictionary:
	var b: RefCounted = HomeBuild.new(null, null, {})
	stage(b)
	course(b)
	var r: Dictionary = StampFile.from_region(b, LO, HI, "Tower course")
	var s: Dictionary = r.stamp
	var zs: Array = s.get("zones", [])
	var rs: Array = s.get("rules", [])
	var names: Array = zs.map(func(z: Dictionary) -> String: return str(z.get("name", "")))
	var ids_ok: bool = zs.map(func(z: Dictionary) -> int: return int(z.id)) == range(1, zs.size() + 1) and rs.map(func(x: Dictionary) -> int: return int(x.id)) == range(1, rs.size() + 1)
	var refs_ok := true
	for x: Dictionary in rs:
		for z: int in Check.zones_named(x):
			refs_ok = refs_ok and z >= 1 and z <= zs.size()
	var door: Dictionary = zs[4] if zs.size() > 4 else {}
	var dir := TMP.path_join("v2")
	var w: Dictionary = StampFile.save(dir, s)
	var listed: Array = StampFile.list(dir).stamps
	var back: Dictionary = listed[0].stamp if not listed.is_empty() else {}
	var same: bool = not back.is_empty() and StampFile.text_of(back) == StampFile.text_of(s) and FileAccess.get_file_as_string(w.path) == StampFile.text_of(s)
	var ok: bool = bool(r.ok) and str(s.schema) == "tl.stamp/2" and zs.size() == 7 and rs.size() == 8 and not names.has("Half out") and ids_ok and refs_ok \
		and str(door.get("box", [])) == str([[5, 1, 4], [7, 2, 4]]) and same and StampFile.validate(s) == ""
	say("v2", ok, "schema %s: %d zones %s, %d rules (the teleport to 'Half out' left out), ids 1.. %s, references in the stamp %s; door box %s (relative); saved, listed, read back byte for byte %s (%d bytes)" % [
		str(s.schema), zs.size(), str(names), rs.size(), ids_ok, refs_ok, str(door.get("box", [])), same, StampFile.text_of(s).length()])
	return s


## The cell of relative cell `c` (a box of `size`) turned `r` quarter turns about +y, as a rotation of its centre (not
## stamp_file's index formula): the independent check (stamp_case.gd's `spun`).
static func spun(c: Vector3i, size: Vector3i, r: int) -> Vector3i:
	var centre := Vector3(size.x, 0, size.z) * 0.5
	var p := Vector3(c.x + 0.5, c.y, c.z + 0.5) - centre
	var q := Basis(Vector3.UP, r * PI * 0.5) * p
	var ts := Vector3(size.z, 0, size.x) * 0.5 if r % 2 == 1 else centre
	var w := q + ts
	return Vector3i(floori(w.x), c.y, floori(w.z))


func turns_case(s: Dictionary) -> void:
	var size := Vector3i(int(s.size[0]), int(s.size[1]), int(s.size[2]))
	var lines := []
	var bad := []
	for r in 4:
		var b: RefCounted = HomeBuild.new(null, null, {})
		var at := Vector3i(40, 0, -30)
		var p: Dictionary = StampFile.placed_ops(b, s, at, r)
		var res: Dictionary = b.apply(p.ops)
		var rl: RefCounted = b.layer("rules")
		var good := 0
		for z: Dictionary in s.zones:
			var a := spun(Vector3i(int(z.box[0][0]), int(z.box[0][1]), int(z.box[0][2])), size, r)
			var c := spun(Vector3i(int(z.box[1][0]), int(z.box[1][1]), int(z.box[1][2])), size, r)
			var want := [[at.x + mini(a.x, c.x), at.y + a.y, at.z + mini(a.z, c.z)], [at.x + maxi(a.x, c.x), at.y + c.y, at.z + maxi(a.z, c.z)]]
			var got: Dictionary = rl.zones.get(int(z.id), {})
			if str(got.get("box", [])) == str(want) and str(got.get("name", "")) == str(z.get("name", "")):
				good += 1
			elif bad.size() < 4:
				bad.append("r%d %s: %s, want %s" % [r, str(z.get("name", "")), str(got.get("box", [])), str(want)])
		var batches: int = b.edits.history.size()
		var n_blocks: int = b.blocks.total
		b.undo()
		var empty: bool = b.blocks.total == 0 and rl.size() == 0
		lines.append("r%d: %d/%d zones where the turn puts them, %d rules, %d blocks, %d batch, undo empty %s" % [r, good, (s.zones as Array).size(), rl.rules.size() if not empty else (s.rules as Array).size(), n_blocks, batches, empty])
		if not (bool(res.ok) and good == (s.zones as Array).size() and batches == 1 and empty):
			bad.append("r%d: ok %s, %d good, %d batches, empty %s, %s" % [r, res.ok, good, batches, empty, str(res.reason)])
	say("turns", bad.is_empty(), "; ".join(lines) + ("" if bad.is_empty() else "; BAD " + "; ".join(bad)))


## Returns {"build", "zones": name -> id} of the course placed turned 1 into a Home that already has zones and rules.
func renumber_case(s: Dictionary) -> Dictionary:
	var b: RefCounted = HomeBuild.new(null, null, {})
	var rl: RefCounted = b.layer("rules")
	for i in 3:
		b.apply(Presets.ops(rl, "coin", Vector3i(100 + 3 * i, 0, 0), Vector3i(100 + 3 * i, 0, 0), {}))
	b.apply([{"op": "zone", "id": 4, "box": [[120, 0, 0], [121, 1, 1]], "look": "none", "name": "Own"}])
	var before := JSON.stringify(rl.save_part())
	var own_rules: Array = rl.rules.keys()
	var p: Dictionary = StampFile.placed_ops(b, s, Vector3i(50, 0, 50), 1)
	var hist: int = b.edits.history.size()
	var res: Dictionary = b.apply(p.ops)
	var new_z := []
	var by_name := {}
	for zid: int in rl.zones:
		if zid > 4:
			new_z.append(zid)
			by_name[str(rl.zones[zid].get("name", ""))] = zid
	new_z.sort()
	var new_r: Array = rl.rules.keys().filter(func(n: int) -> bool: return not own_rules.has(n))
	new_r.sort()
	var refs_ok := true
	for n: int in new_r:
		for z: int in Check.zones_named(rl.rules[n]):
			refs_ok = refs_ok and new_z.has(z)
	var own_same := true
	for n: int in own_rules:
		for z: int in Check.zones_named(rl.rules[n]):
			own_same = own_same and z <= 3
	var lines: Array = new_r.map(func(n: int) -> String: return rl.describe(n))
	var ok: bool = bool(res.ok) and (p.refused as Array).is_empty() and b.edits.history.size() == hist + 1 and new_z == range(5, 12) \
		and new_r == range(4, 12) and refs_ok and own_same and rl.size() == 7 + 15 and JSON.stringify(rl.save_part()).length() > before.length()
	say("renumber", ok, "a Home with zones 1-4 and rules 1-3: the course's zones -> %s, rules -> %s, every reference to the new zones %s, the Home's own rules untouched %s, one batch %s; %s" % [
		str(new_z), str(new_r), refs_ok, own_same, b.edits.history.size() == hist + 1, " | ".join(lines.slice(0, 3))])
	return {"build": b, "zones": by_name}


func run_case(placed: Dictionary) -> void:
	var b: RefCounted = placed.build
	var rl: RefCounted = b.layer("rules")
	var z: Dictionary = placed.zones
	var rec := Rec.new()
	var rr: RefCounted = RulesRun.new(rl, rec)
	rr.begin(0, Vector3(0, 0, 0))
	var path := [Vector3i(0, 0, 0)]
	for nm: String in ["Start", "Coin 1", "Coin 2", "Coin 3", "Finish"]:
		var box: Array = rl.zones[int(z[nm])].box
		path.append(Vector3i(int(box[0][0]), int(box[0][1]), int(box[0][2])))
		path.append(Vector3i(0, 0, 0) + Vector3i(int(box[0][0]), int(box[0][1]) + 6, int(box[0][2])))   # step out above it
	var f := 0
	for c: Vector3i in path:
		for i in 3:
			f += 1
			rr.step(f, c, false)
	var kinds: Array = rec.log.map(func(e: Array) -> String: return str(e[0]))
	var taken: int = kinds.count("look_taken")
	var fin: Array = rec.log.filter(func(e: Array) -> bool: return str(e[0]) == "run_finished")
	var ok: bool = kinds.has("run_started") and taken == 3 and fin.size() == 1 and str(fin[0][1]) == "Tower"
	say("run", ok, "the placed course over a scripted path: %s; coins taken %d; finished '%s' in %s frames" % [
		" > ".join(kinds), taken, str(fin[0][1]) if not fin.is_empty() else "-", str(fin[0][2]) if not fin.is_empty() else "-"])


func code_case(s: Dictionary) -> void:
	var code: String = StampFile.code_of(s)
	var body := code.substr(4)
	var alphabet := true
	for ch: String in body:
		alphabet = alphabet and (ch.is_valid_identifier() or ch == "-" or ch == "_" or (ch >= "0" and ch <= "9"))
	var std := body.replace("-", "+").replace("_", "/")
	while std.length() % 4 != 0:
		std += "="
	var raw := Marshalls.base64_to_raw(std)
	var zlib: bool = raw.size() > 2 and raw[0] == 0x78 and (int(raw[0]) * 256 + int(raw[1])) % 31 == 0
	var back: Dictionary = StampFile.from_code(code)
	var same: bool = bool(back.ok) and StampFile.text_of(back.stamp) == StampFile.text_of(s)
	var spaced: Dictionary = StampFile.from_code("  " + code + "\n")
	var text_len: int = StampFile.text_of(s).length()
	var ok: bool = code.begins_with("TL1-") and alphabet and not code.contains("=") and zlib and same and bool(spaced.ok)
	say("code", ok, "TL1- code of %d characters for a %d-byte stamp (%.0f%%), base64url without padding %s, a zlib stream (RFC 1950) %s, read back byte for byte %s, with spaces and a newline around it %s" % [
		code.length(), text_len, 100.0 * code.length() / text_len, alphabet and not code.contains("="), zlib, same, bool(spaced.ok)])


static func code_of_text(t: String) -> String:
	return "TL1-" + Marshalls.raw_to_base64(t.to_utf8_buffer().compress(FileAccess.COMPRESSION_DEFLATE)).replace("+", "-").replace("/", "_").replace("=", "")


func refusals_case(s: Dictionary) -> void:
	var text: String = StampFile.text_of(s).strip_edges()
	var extra_zone: Dictionary = s.duplicate(true)
	(extra_zone.zones[0] as Dictionary)["colour"] = "red"
	var extra_rule: Dictionary = s.duplicate(true)
	(extra_rule.rules[0] as Dictionary)["note"] = "x"
	var stray: Dictionary = s.duplicate(true)
	(stray.rules[0].when as Dictionary)["zone"] = 99
	var bare: Dictionary = s.duplicate(true)
	bare.erase("zones")
	bare.erase("rules")
	var cases := [
		["bad prefix", "TL2-" + StampFile.code_of(s).substr(4), "begins with TL1-"],
		["cut short", "TL1-abcde", "cut short"],
		["a letter outside base64url", "TL1-ab+d", "not a base64url letter"],
		["not a stream", "TL1-AAAAAAAA", "does not unpack"],
		["not JSON", code_of_text("this is not json"), "no JSON"],
		["an unknown key", code_of_text(text.replace("{\"schema\"", "{\"author\":\"me\",\"schema\"")), "unknown key 'author'"],
		["a zone's unknown key", code_of_text(StampFile.text_of(extra_zone)), "zones: unknown key 'colour'"],
		["a rule's unknown key", code_of_text(StampFile.text_of(extra_rule)), "rules: unknown key 'note'"],
		["a rule naming a zone not in it", code_of_text(StampFile.text_of(stray)), "not in the stamp"],
		["a v2 with no zones or rules", code_of_text(StampFile.text_of(bare)), "holds zones or rules"],
		["too long", "TL1-" + "A".repeat(65537), "at most 65536"]]
	var bad := []
	var seen := []
	for c: Array in cases:
		var r: Dictionary = StampFile.from_code(c[1])
		seen.append("%s: '%s'" % [c[0], str(r.reason)])
		if bool(r.ok) or not str(r.reason).contains(c[2]):
			bad.append("%s: ok %s '%s' (want '%s')" % [c[0], r.ok, str(r.reason), c[2]])
	say("refusals", bad.is_empty(), "; ".join(seen) + ("" if bad.is_empty() else "; BAD " + "; ".join(bad)))


func tap(k: Key, ctrl := false) -> void:
	if ctrl:
		CaseUtil.key(KEY_CTRL, true)
	CaseUtil.key(k, true)
	await wait(2)
	CaseUtil.key(k, false)
	if ctrl:
		CaseUtil.key(KEY_CTRL, false)
	await wait(2)


func tool_case() -> void:
	var a: RefCounted = HomeBuild.new(null, null, {})
	var bm: Node = BuildMode.new()
	bm.set("build", a)
	root.add_child(bm)
	bm.open(ProjectSettings.globalize_path(TMP.path_join("home_a")))       # a load: the course is built after it
	stage(a)
	course(a)
	await wait(2)
	await tap(KEY_B)
	while str(bm.call("tool").get("id")) != "stamp":
		await tap(KEY_T)
	var t: RefCounted = bm.call("tool")
	await tap(KEY_0)
	bm.set("hit", {"pos": Vector3(0.5, 1.0, -3.5), "normal": Vector3.UP, "block": true, "place": Vector3i(0, 1, -4), "remove": Vector3i(0, 0, -4)})
	t.press(MOUSE_BUTTON_LEFT, {})
	bm.set("hit", {"pos": Vector3(16.5, 1.0, 4.5), "normal": Vector3.UP, "block": true, "place": Vector3i(16, 1, 4), "remove": Vector3i(16, 0, 4)})
	t.press(MOUSE_BUTTON_LEFT, {})
	var bx: Array = t.call("box")
	await tap(KEY_G)
	var e := InputEventKey.new()
	e.keycode = KEY_ENTER
	e.physical_keycode = KEY_ENTER
	e.pressed = true
	root.push_input(e)
	await wait(4)
	var st: Dictionary = t.call("stamp")
	await tap(KEY_C, true)
	var code := str(t.get("fake_clip"))
	var info := str(t.call("status").info)
	await tap(KEY_B)
	bm.queue_free()
	await wait(2)
	# another Home: Ctrl+V, then LMB places it
	var b: RefCounted = HomeBuild.new(null, null, {})
	var bm2: Node = BuildMode.new()
	bm2.set("build", b)
	root.add_child(bm2)
	bm2.open(ProjectSettings.globalize_path(TMP.path_join("home_b")))
	await wait(2)
	await tap(KEY_B)
	while str(bm2.call("tool").get("id")) != "stamp":
		await tap(KEY_T)
	var t2: RefCounted = bm2.call("tool")
	t2.set("fake_clip", code)
	await tap(KEY_V, true)
	var pasted: Dictionary = t2.call("stamp")
	var note2 := str(t2.get("note"))
	var hist: int = b.edits.history.size()
	bm2.set("hit", {"pos": Vector3(60.5, 0.0, 60.5), "normal": Vector3.UP, "block": false, "place": Vector3i(60, 0, 60), "remove": HomeBuild.NO_CELL})
	t2.press(MOUSE_BUTTON_LEFT, {})
	var rl: RefCounted = b.layer("rules")
	var one: bool = b.edits.history.size() == hist + 1
	var why := str(t2.get("reason"))
	await tap(KEY_B)
	bm2.queue_free()
	await wait(2)
	var ok: bool = bx.size() == 2 and (bx[1] as Vector3i).y == 6 and str(st.get("schema", "")) == "tl.stamp/2" and code.begins_with("TL1-") \
		and info.contains("%d characters" % code.length()) and str(pasted.get("name", "")) == "Stamp 1" and (pasted.get("zones", []) as Array).size() == 7 \
		and one and rl.zones.size() == 7 and rl.rules.size() == 8 and b.blocks.total == int((st.get("blocks", []) as Array).size()) and why == ""
	say("tool", ok, "box %s (top %d: the finish zone's); G saved '%s' %s; Ctrl+C: '%s'; another Home, Ctrl+V: '%s' (%d zones); LMB placed %d blocks, %d zones, %d rules in one batch %s%s" % [
		str(bx), (bx[1] as Vector3i).y if bx.size() == 2 else -1, str(st.get("name", "")), str(st.get("schema", "")), info, note2,
		(pasted.get("zones", []) as Array).size(), b.blocks.total, rl.zones.size(), rl.rules.size(), one, "" if why == "" else "; refused '%s'" % why])
