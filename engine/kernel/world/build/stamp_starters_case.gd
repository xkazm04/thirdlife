extends SceneTree
## M6 round 3, lane T (27 Nov 2026): the starter courses shipped with the game (res://kernel/world/build/starters,
## stamp_starters_make.gd) and a placed course's run name (contracts/BUILD.md "Courses travel": a name field prefilled
## "<name> (2)"), headless. Prints `HOME stamp-starters.<case> ok|fail <detail>`, then `HOME stamp-starters ok` (or
## fail) and `HOME DONE`; engine/tools/selftest.d/789-home-stamp-starters.sh reads them. Frames, not wall clock.
##   stamp-starters.files    three tl.stamp/2 files, valid, each under 4,000 blocks, only the materials 1-9 (never locked)
##   stamp-starters.tool     the stamp tool lists them first (the Starters page, "starter" on each slot), your own
##                           stamps after them on their own page; one placed by 1 and LMB is one batch, nothing written
##                           into the starters folder
##   stamp-starters.runs     each placed starter finishes by a scripted feet path (rules_run.gd, a recording facade):
##                           Tower climb (3 coins), Garden gate (E opens the gate, the message, 3 coins), Pad hop (3
##                           pads, a hazard respawns at the checkpoint before the pad). The real walker's play of the
##                           same courses is selftest 799 (play_case_starters.gd, lane F3)
##   stamp-starters.runname  a course whose run the Home already has: the field "Tower climb (2)" (selected); Enter
##                           places it with that run, a third with Esc shares the name; one batch each; the guard keys

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const BuildMode := preload("res://kernel/world/build/build_mode.gd")
const StampFile := preload("res://kernel/world/build/stamp_file.gd")
const StampCode := preload("res://kernel/world/build/stamp_code.gd")
const Blocks := preload("res://kernel/world/build/blocks.gd")
const RulesRun := preload("res://kernel/world/build/rules_run.gd")
const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const TMP := "user://tl_stamp_starters_case"

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
	print("HOME stamp-starters.%s %s %s" % [case_name, "ok" if ok else "fail", detail])


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func tap(k: Key) -> void:
	CaseUtil.key(k, true)
	await wait(2)
	CaseUtil.key(k, false)
	await wait(2)


func push_key(k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	root.push_input(e)
	await wait(2)


func run() -> void:
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	var st := StampCode.starters()
	files_case(st)
	await tool_case()
	runs_case(st)
	await runname_case()
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	print("HOME stamp-starters %s" % ("ok" if ok_all else "fail"))
	print("HOME DONE")
	quit(0)


func files_case(st: Array) -> void:
	var lines := []
	var bad := []
	for e: Dictionary in st:
		var d: Dictionary = e.stamp
		var mats := {}
		for b: Array in d.get("blocks", []):
			mats[Blocks.mat_of(int(b[3]))] = true
		var n: int = (d.get("blocks", []) as Array).size()
		lines.append("%s: %s, %d blocks, mats %s, %d zones, %d rules" % [str(d.name), str(d.size), n, str(mats.keys()), (d.get("zones", []) as Array).size(), (d.get("rules", []) as Array).size()])
		if str(d.schema) != "tl.stamp/2" or n >= 4000 or mats.keys().any(func(m: int) -> bool: return m < 1 or m > 9) or StampFile.validate(d) != "":
			bad.append(str(d.name))
	var names: Array = st.map(func(e: Dictionary) -> String: return str(e.stamp.name))
	var ok: bool = names == ["Garden gate", "Pad hop", "Tower climb"] and bad.is_empty() and StampFile.list(StampCode.STARTERS).bad.is_empty()
	say("files", ok, "; ".join(lines) + ("" if bad.is_empty() else "; BAD " + ", ".join(bad)))


func tool_case() -> void:
	var b: RefCounted = HomeBuild.new(null, null, {})
	var bm: Node = BuildMode.new()
	bm.set("build", b)
	root.add_child(bm)
	var home := ProjectSettings.globalize_path(TMP.path_join("home"))
	bm.open(home)
	StampFile.save(home.path_join("stamps"), {"schema": "tl.stamp/1", "name": "Mine", "size": [1, 1, 1], "blocks": [[0, 0, 0, Blocks.code(1, 1)]]})
	await wait(2)
	await tap(KEY_B)
	bm.call("switch_tool", 0, "stamp")
	var t: RefCounted = bm.call("tool")
	var first: Array = (t.call("slots") as Array).map(func(s: Dictionary) -> String: return str(s.label).replace("\n", " "))
	var info: String = str(t.call("status").info)
	await tap(KEY_TAB)
	var second: Array = (t.call("slots") as Array).map(func(s: Dictionary) -> String: return str(s.label).replace("\n", " "))
	await tap(KEY_TAB)
	await tap(KEY_3)
	var picked := str((t.call("stamp") as Dictionary).get("name", ""))
	var before := _starter_bytes()
	var hist: int = b.edits.history.size()
	var why: String = t.call("place_at", Vector3i(30, 0, 30))
	var one: bool = b.edits.history.size() == hist + 1
	var untouched: bool = _starter_bytes() == before
	await tap(KEY_B)
	bm.queue_free()
	await wait(2)
	var ok: bool = first == ["new box", "Garden gate starter", "Pad hop starter", "Tower climb starter"] and info.contains("Starters") and second == ["new box", "Mine"] \
		and picked == "Tower climb" and why == "" and one and untouched and b.layer("rules").zones.size() == 5
	say("tool", ok, "first page %s ('%s'); Tab: %s; Tab, 3: '%s'; LMB placed it: one batch %s, %d zones, %d blocks; the starters' bytes untouched %s%s" % [
		str(first), info, str(second), picked, one, b.layer("rules").zones.size(), b.blocks.total, untouched, "" if why == "" else "; refused '%s'" % why])


func _starter_bytes() -> String:
	var s := ""
	for f: String in ["garden-gate.json", "pad-hop.json", "tower-climb.json"]:
		s += FileAccess.get_file_as_string(StampCode.STARTERS.path_join(f))
	return s.sha256_text()


## The path of each starter in its own cells (feet cells), [cell, E down on its first frame].
## The feet cells walked, in each recipe's own cells (stamp_starters_make.gd; lane F3 remade the courses on 27 Nov:
## Tower climb an L of half-block steps, Pad hop with stairs, wide checkpoints and the finish on its last platform).
static func paths() -> Dictionary:
	return {
		"Tower climb": [[Vector3i(-1, 1, 1), false], [Vector3i(0, 1, 1), false], [Vector3i(3, 1, 1), false], [Vector3i(6, 2, 1), false],
			[Vector3i(9, 2, 1), false], [Vector3i(9, 3, 4), false], [Vector3i(9, 3, 7), false], [Vector3i(9, 4, 10), false]],
		"Garden gate": [[Vector3i(5, 1, -4), false], [Vector3i(5, 1, -3), false], [Vector3i(5, 1, -1), true], [Vector3i(5, 1, 0), false],
			[Vector3i(5, 1, 1), false], [Vector3i(5, 1, 2), false], [Vector3i(2, 1, 5), false], [Vector3i(8, 1, 4), false],
			[Vector3i(3, 1, 7), false], [Vector3i(5, 1, 9), false]],
		"Pad hop": [[Vector3i(-2, 2, 2), false], [Vector3i(0, 3, 2), false], [Vector3i(3, 3, 2), false], [Vector3i(9, 3, 2), false],
			[Vector3i(10, 3, 2), false], [Vector3i(12, 1, 2), false], [Vector3i(9, 3, 2), false], [Vector3i(10, 3, 2), false],
			[Vector3i(16, 3, 2), false], [Vector3i(17, 3, 2), false], [Vector3i(23, 3, 2), false]]}


## Each recipe's box corner (its `lo`): a recipe cell c is the placed stamp's cell c - lo.
const LO := {"Tower climb": Vector3i(-1, 0, -1), "Garden gate": Vector3i(-1, 0, -5), "Pad hop": Vector3i(-5, 0, -1)}


func runs_case(st: Array) -> void:
	var lines := []
	var bad := []
	var want := {"Tower climb": {"look_taken": 3, "run_finished": 1},
		"Garden gate": {"set_open": 2, "say": 1, "look_taken": 3, "run_finished": 1},
		"Pad hop": {"launch": 4, "teleport": 1, "say": 3, "run_finished": 1}}
	for e: Dictionary in st:
		var d: Dictionary = e.stamp
		var b: RefCounted = HomeBuild.new(null, null, {})
		var at := Vector3i(100, 0, 100)
		var r: Dictionary = b.apply(StampFile.placed_ops(b, d, at, 0).ops)
		var shift: Vector3i = -(LO[str(d.name)] as Vector3i)
		var rec := Rec.new()
		var rr: RefCounted = RulesRun.new(b.layer("rules"), rec)
		rr.begin(0, Vector3(at))
		var f := 0
		for p: Array in paths()[str(d.name)]:
			for i in 3:
				f += 1
				rr.step(f, at + shift + (p[0] as Vector3i), bool(p[1]) and i == 0)
		var kinds: Array = rec.log.map(func(x: Array) -> String: return str(x[0]))
		var fin: Array = rec.log.filter(func(x: Array) -> bool: return str(x[0]) == "run_finished")
		var tel: Array = rec.log.filter(func(x: Array) -> bool: return str(x[0]) == "teleport")
		var ok_one: bool = bool(r.ok) and fin.size() == 1 and str(fin[0][1]) == str(d.name)
		for k: String in want[str(d.name)]:
			ok_one = ok_one and kinds.count(k) == int(want[d.name][k])
		if str(d.name) == "Pad hop":
			ok_one = ok_one and not tel.is_empty() and (tel[0][1] as Vector3).is_equal_approx(Vector3(at) + Vector3(14.0, 3.0, 3.5))
		lines.append("%s: %s, finished in %s frames" % [str(d.name), " > ".join(kinds), str(fin[0][2]) if not fin.is_empty() else "-"])
		if not ok_one:
			bad.append("%s %s" % [str(d.name), str(rec.log)])
	say("runs", bad.is_empty(), "; ".join(lines) + ("" if bad.is_empty() else "; BAD " + "; ".join(bad)))


func runname_case() -> void:
	var b: RefCounted = HomeBuild.new(null, null, {})
	var bm: Node = BuildMode.new()
	bm.set("build", b)
	root.add_child(bm)
	bm.open(ProjectSettings.globalize_path(TMP.path_join("home2")))
	await wait(2)
	await tap(KEY_B)
	bm.call("switch_tool", 0, "stamp")
	var t: RefCounted = bm.call("tool")
	await tap(KEY_3)                    # Tower climb (the Starters page)
	var w1: String = t.call("place_at", Vector3i(0, 0, 0))
	var h1: int = b.edits.history.size()
	var w2: String = t.call("place_at", Vector3i(30, 0, 0))
	var bar: CanvasLayer = t.get("run_bar")
	var line: LineEdit = bar.get("line") if bar != null else null
	var shown: String = line.text if line != null else ""
	var sel: bool = line != null and line.has_selection() and line.get_selected_text() == shown
	var blocked: bool = bool(t.call("blocks_input"))
	CaseUtil.key(KEY_ENTER, true)
	await wait(1)
	if bar != null and bar.call("is_open"):
		await push_key(KEY_ENTER)
	await wait(6)
	var held_ok: bool = str(bm.call("tool").get("id")) == "stamp" and bool(bm.get("active"))
	CaseUtil.key(KEY_ENTER, false)
	await wait(4)
	var h2: int = b.edits.history.size()
	var w3: String = t.call("place_at", Vector3i(60, 0, 0))
	var shown3: String = line.text if line != null else ""
	CaseUtil.key(KEY_ESCAPE, true)
	await wait(1)
	if bar != null and bar.call("is_open"):
		await push_key(KEY_ESCAPE)
	await wait(4)
	var esc_ok: bool = bool(bm.get("active"))
	CaseUtil.key(KEY_ESCAPE, false)
	await wait(4)
	var h3: int = b.edits.history.size()
	var runs := {}
	var rules: Dictionary = b.layer("rules").rules
	for n: int in rules:
		for e: Dictionary in rules[n].do:
			if str(e.do) == "start":
				runs[str(e.run)] = int(runs.get(str(e.run), 0)) + 1
	await tap(KEY_B)
	bm.queue_free()
	await wait(2)
	var ok: bool = w1 == "" and w2 == "asked" and shown == "Tower climb (2)" and sel and blocked and held_ok and h2 == h1 + 1 and w3 == "asked" \
		and shown3 == "Tower climb (3)" and esc_ok and h3 == h2 + 1 and runs == {"Tower climb": 2, "Tower climb (2)": 1}
	say("runname", ok, "first placed '%s'; second: '%s', field '%s' selected %s, keyboard taken %s; Enter held: still the stamp tool and building %s, one batch %s; third: field '%s', Esc: building %s, one batch %s; runs %s" % [
		w1, w2, shown, sel, blocked, held_ok, h2 == h1 + 1, shown3, esc_ok, h3 == h2 + 1, str(runs)])
