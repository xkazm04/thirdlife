extends RefCounted
## SEAM M6: the 773 cases `rules-seam.run`, `rules-seam.records` and `rules-seam.play`, run by rules_case.gd.
##   run      rules_run.gd over a scripted feet path with a recording facade: start on entering the start zone, three
##            coins taken (a taken coin fires no more), "count at 3" says on the next frame, a jump pad's second rule
##            sees the first one's counter in the same frame, E toggles a door, checkpoint -> hazard respawns there,
##            finish records plays, finishes and the best ("new best" on the first and on a faster run, not on a slower
##            one), "every 60" fires on frames 60 apart, a restart brings the coins back and closes the door, build
##            mode drops the run unrecorded; the same path twice gives the same call log
##   records  home_records.gd: tl.records/1 written and read back byte for byte, the best kept, malformed files
##            refused and never written over
##   play     the wiring: build_mode.gd steps the rules while build mode is off (rules_play.gd), stops them (zones
##            closed) when B turns it on and begins again when it goes off; the blocks layer's mask

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const BuildMode := preload("res://kernel/world/build/build_mode.gd")
const Blocks := preload("res://kernel/world/build/blocks.gd")
const RulesRun := preload("res://kernel/world/build/rules_run.gd")
const HomeRecords := preload("res://kernel/world/build/home_records.gd")
const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const SEED := 11

var tmp := ""


## What the rules did, frame by frame: [frame, method, args...].
class Rec extends "res://kernel/world/build/rules_facade.gd":
	var log := []
	var run: WeakRef = null              # the runtime whose frame stamps a call (weak: it holds this facade)
	func _f() -> int: return int(run.get_ref().get("frame")) if run != null and run.get_ref() != null else -1
	func set_open(z: int, box: Array, o: bool) -> void: log.append([_f(), "set_open", z, str(box), o])
	func look_taken(z: int, t: bool) -> void: log.append([_f(), "look_taken", z, t])
	func launch(u: int, f: int) -> void: log.append([_f(), "launch", u, f])
	func teleport(at: Vector3) -> void: log.append([_f(), "teleport", at])
	func say(t: String, n: int) -> void: log.append([_f(), "say", t, n])
	func run_started(n: String, fr: int) -> void: log.append([_f(), "run_started", n, fr])
	func run_finished(n: String, fr: int, best: int, nb: bool) -> void: log.append([_f(), "run_finished", n, fr, best, nb])
	func run_stopped(n: String, why: String) -> void: log.append([_f(), "run_stopped", n, why])


func _init(dir: String) -> void:
	tmp = dir


static func zone(n: int, lo: Array, hi: Array, look: String, name: String) -> Dictionary:
	return {"op": "zone", "id": n, "box": [lo, hi], "look": look, "name": name}


static func rule(n: int, when: Dictionary, effects: Array, conds: Array = []) -> Dictionary:
	var r := {"op": "rule", "id": n, "when": when, "do": effects}
	if not conds.is_empty():
		r["if"] = conds
	return r


## The course: start, three coins, a jump pad, a door (E), a checkpoint, a hazard, the finish, a beat every 90 frames.
static func course() -> RefCounted:
	var b: RefCounted = HomeBuild.new(null, null, {"seed": SEED})
	var ops := [zone(1, [0, 0, -1], [1, 1, 1], "flag", "Start"), zone(2, [3, 0, 0], [3, 1, 0], "coin", "Coin A"),
		zone(3, [4, 0, 0], [4, 1, 0], "coin", "Coin B"), zone(4, [5, 0, 0], [5, 1, 0], "coin", "Coin C"),
		zone(5, [7, 0, 0], [7, 0, 0], "pad", "Pad"), zone(6, [10, 0, 0], [10, 2, 0], "none", "Door"),
		zone(7, [13, 0, 0], [13, 1, 0], "flag", "Check"), zone(8, [16, 0, 0], [16, 1, 0], "none", "Hazard"),
		zone(9, [20, 0, -1], [21, 1, 1], "flag", "Finish"),
		rule(1, {"on": "enter", "zone": 1}, [{"do": "start", "run": "Course"}])]
	for z: int in [2, 3, 4]:
		ops.append(rule(z, {"on": "enter", "zone": z}, [{"do": "take", "zone": z}, {"do": "add", "counter": "coins", "by": 1}]))
	ops.append_array([rule(5, {"on": "count", "counter": "coins", "at": 3}, [{"do": "say", "text": "Three coins", "frames": 120}]),
		rule(6, {"on": "enter", "zone": 5}, [{"do": "add", "counter": "hops", "by": 1}, {"do": "launch", "up_cm": 900, "fwd_cm": 200}]),
		rule(7, {"on": "enter", "zone": 5}, [{"do": "say", "text": "Hop", "frames": 30}], [{"counter": "hops", "min": 1}]),
		rule(8, {"on": "use", "zone": 6}, [{"do": "toggle", "zone": 6}]),
		rule(9, {"on": "enter", "zone": 7}, [{"do": "checkpoint", "zone": 7}]),
		rule(10, {"on": "enter", "zone": 8}, [{"do": "respawn"}], [{"running": true}]),
		rule(11, {"on": "enter", "zone": 9}, [{"do": "finish"}], [{"running": true}]),
		rule(12, {"on": "finish"}, [{"do": "say", "text": "Done", "frames": 60}]),
		rule(13, {"on": "every", "frames": 60}, [{"do": "say", "text": "Beat", "frames": 30}]),
		rule(14, {"on": "leave", "zone": 1}, [{"do": "say", "text": "Go", "frames": 30}], [{"running": true}]),
		rule(15, {"on": "enter", "zone": 2}, [{"do": "say", "text": "never", "frames": 30}], [{"counter": "coins", "max": 0}])])
	var r: Dictionary = b.apply(ops)
	assert(r.ok, str(r.refused))
	return b


## Walks x = -3..21 at `per` frames a cell (E down on the 2nd frame in the door's cell), then back into the start
## for 5 frames. Returns [frames stepped (the last frame), {"fin": frame the finish cell was entered}].
static func walk(run: RefCounted, per: int, f0: int) -> Array:
	var f := f0
	var marks := {}
	for x: int in range(-3, 22):
		for k: int in per:
			f += 1
			if k == 0:
				marks[x] = f
			run.step(f, Vector3i(x, 0, 0), x == 10 and k == 1)
	for k: int in 5:
		f += 1
		if k == 0:
			marks["back"] = f
		run.step(f, Vector3i(1, 0, 0), false)
	return [f, marks]


func run() -> Array:
	var bad := []
	var b := course()
	var l: RefCounted = b.layer("rules")
	var recs: RefCounted = HomeRecords.new(tmp.path_join("rec-run"))
	var fac := Rec.new()
	var rr: RefCounted = RulesRun.new(l, fac, recs)
	fac.run = weakref(rr)
	rr.begin(100, Vector3(-3, 0, 0))
	var w: Array = walk(rr, 6, 100)
	var m: Dictionary = w[1]
	rr.stop("build")
	var log: Array = fac.log
	var plain: Array = log.filter(func(e: Array) -> bool: return not (e[1] == "say" and e[2] == "Beat"))
	var kinds: Array = plain.map(func(e: Array) -> String: return str(e[1]) + ("" if e[1] != "say" else " " + str(e[2])))
	var want := ["run_started", "say Go", "look_taken", "look_taken", "look_taken", "say Three coins", "launch", "say Hop", "set_open",
		"teleport", "run_finished", "say Done", "set_open", "look_taken", "look_taken", "look_taken", "run_started", "run_stopped"]
	if kinds != want:
		bad.append("calls %s, want %s" % [str(kinds), str(want)])
	var at := func(kind: String, arg: String) -> Array:
		for e: Array in log:
			if e[1] == kind and (arg == "" or str(e[2]) == arg):
				return e
		return []
	var started: Array = at.call("run_started", "")
	var three: Array = at.call("say", "Three coins")
	var hop: Array = at.call("say", "Hop")
	var launch: Array = at.call("launch", "")
	var tele: Array = at.call("teleport", "")
	var fin: Array = at.call("run_finished", "")
	var done: Array = at.call("say", "Done")
	var door: Array = at.call("set_open", "")
	var beats: Array = log.filter(func(e: Array) -> bool: return e[1] == "say" and e[2] == "Beat").map(func(e: Array) -> int: return int(e[0]))
	var beat_ok: bool = beats.size() >= 2 and beats.all(func(f: int) -> bool: return (f - 100) % 60 == 0) and int(beats[0]) == 160 		and int(beats[1]) == 220
	var checks := {
		"start on entering the start zone": started.size() > 0 and int(started[0]) == int(m[0]) and int(started[3]) == int(m[0]),
		"count at 3 says the frame after the third coin": three.size() > 0 and int(three[0]) == int(m[5]) + 1,
		"the pad's second rule sees the first's counter in the same frame": hop.size() > 0 and launch.size() > 0 and int(hop[0]) == int(launch[0]) and int(launch[0]) == int(m[7]) and launch.slice(2) == [900, 200],
		"E toggles the door open": door.size() > 0 and int(door[0]) == int(m[10]) + 1 and door[2] == 6 and door[4] == true,
		"the hazard respawns at the checkpoint": tele.size() > 0 and int(tele[0]) == int(m[16]) and tele[2] == Vector3(13.5, 0, 0.5),
		"finish records the time and a new best": fin.size() > 0 and int(fin[3]) == int(m[20]) - int(m[0]) and int(fin[4]) == int(fin[3]) and fin[5] == true,
		"the finish trigger answers the frame after": done.size() > 0 and int(done[0]) == int(m[20]) + 1,
		"every 60 fires on frames 60 apart": beat_ok,
		"a taken coin fires no more, a never-true condition never runs": not kinds.has("say never") and kinds.count("look_taken") == 6,
		"the restart closes the door and brings the coins back": plain.size() == 18 and plain.slice(12, 17).all(func(e: Array) -> bool: return int(e[0]) == int(m["back"])) and plain[12][4] == false,
		"build mode drops the run unrecorded": plain.size() == 18 and str(plain[17].slice(1)) == str(["run_stopped", "Course", "build"]) and int(recs.of("Course").plays) == 2 and int(recs.of("Course").finishes) == 1}
	for k: String in checks:
		if not bool(checks[k]):
			bad.append(k)
	# a faster run is a new best, a slower one is not
	var times := [int(fin[3]) if fin.size() > 0 else -1]
	var bests := [fin[5] if fin.size() > 0 else null]
	for per: int in [3, 9]:
		var f2 := Rec.new()
		var r2: RefCounted = RulesRun.new(l, f2, recs)
		f2.run = weakref(r2)
		r2.begin(100, Vector3(-3, 0, 0))
		walk(r2, per, 100)
		var e: Array = f2.log.filter(func(x: Array) -> bool: return x[1] == "run_finished")[0]
		times.append(int(e[3]))
		bests.append(e[5])
	var rec: Dictionary = recs.of("Course")
	if bests != [true, true, false] or int(rec.best_frames) != int(times[1]) or int(rec.plays) != 6 or int(rec.finishes) != 3:
		bad.append("times %s new best %s, records %s" % [str(times), str(bests), str(rec)])
	# determinism: the same path twice, the same call log
	var logs := []
	for i in 2:
		var f3 := Rec.new()
		var r3: RefCounted = RulesRun.new(course().layer("rules"), f3, HomeRecords.new(tmp.path_join("rec-det-%d" % i)))
		f3.run = weakref(r3)
		r3.begin(100, Vector3(-3, 0, 0))
		walk(r3, 6, 100)
		logs.append(str(f3.log))
	var same: bool = logs[0] == logs[1] and logs[0] == str(log.slice(0, log.size() - 1))
	if not same:
		bad.append("two runs of the same path gave different call logs")
	return ["run", bad.is_empty(), "%d facade calls over %d frames (%d beats at %s...); %s; times %s frames, new best %s, records %s; the same path twice: the same %d calls %s%s" % [
		log.size(), int(w[0]) - 100, beats.size(), str(beats.slice(0, 3)), ", ".join(checks.keys().filter(func(k: String) -> bool: return checks[k])),
		str(times), str(bests), str(rec), log.size() - 1, same, "" if bad.is_empty() else "; BAD " + "; ".join(bad)]]


func records() -> Array:
	var bad := []
	var d := tmp.path_join("records")
	var r: RefCounted = HomeRecords.new(d)
	var first: String = r.load()
	var s1: String = r.started("Tower \"run\"")
	var a: Dictionary = r.finished("Tower \"run\"", 500)
	var b: Dictionary = r.finished("Tower \"run\"", 600)
	r.started("Dash")
	var c: Dictionary = r.finished("Tower \"run\"", 400)
	var text := FileAccess.get_file_as_string(d.path_join("records.json"))
	var want := "{\"schema\":\"tl.records/1\",\"runs\":{\"Dash\":{\"plays\":1,\"finishes\":0},\"Tower \\\"run\\\"\":{\"plays\":1,\"finishes\":3,\"best_frames\":400}}}\n"
	if first != "" or s1 != "" or not a.new_best or b.new_best or not c.new_best or int(b.best_frames) != 500 or text != want:
		bad.append("load '%s' started '%s'; finishes %s %s %s; file %s" % [first, s1, str(a), str(b), str(c), text])
	var again: RefCounted = HomeRecords.new(d)
	var why: String = again.load()
	again.save()
	if why != "" or again.runs != r.runs or FileAccess.get_file_as_string(d.path_join("records.json")) != text:
		bad.append("reload '%s' %s" % [why, str(again.runs)])
	var refusals := {}
	for k: String in ["unknown key", "schema", "negative", "missing"]:
		var t := ""
		match k:
			"unknown key": t = "{\"schema\":\"tl.records/1\",\"runs\":{},\"best\":1}"
			"schema": t = "{\"schema\":\"records\",\"runs\":{}}"
			"negative": t = "{\"schema\":\"tl.records/1\",\"runs\":{\"A\":{\"plays\":1,\"finishes\":0,\"best_frames\":-1}}}"
			"missing": t = "{\"schema\":\"tl.records/1\",\"runs\":{\"A\":{\"finishes\":0}}}"
		var dk := tmp.path_join("rec-" + k.replace(" ", "-"))
		DirAccess.make_dir_recursive_absolute(dk)
		var f := FileAccess.open(dk.path_join("records.json"), FileAccess.WRITE)
		f.store_string(t)
		f.close()
		var x: RefCounted = HomeRecords.new(dk)
		var why_k: String = x.load()
		refusals[k] = why_k.substr(why_k.find("records.json"))
		var kept: bool = x.started("A") != "" and FileAccess.get_file_as_string(dk.path_join("records.json")) == t
		if not kept:
			bad.append("%s: written over" % k)
	var want_r := {"unknown key": "records.json: unknown key 'best'", "schema": "records.json: schema must be tl.records/1",
		"negative": "records.json: runs: 'A': best_frames must be a whole number of at least 0", "missing": "records.json: runs: 'A': plays is missing"}
	if refusals != want_r:
		bad.append("refusals %s" % str(refusals))
	return ["records", bad.is_empty(), "%d B written (runs sorted, best_frames only after a finish), new best 500 %s / 600 %s / 400 %s; reloaded and re-saved byte for byte; refused and kept: %s%s" % [
		text.length(), a.new_best, b.new_best, c.new_best, str(refusals.values()), "" if bad.is_empty() else "; BAD " + "; ".join(bad)]]


static func _wait(tree: SceneTree, n: int) -> void:
	for i in n:
		await tree.physics_frame


static func _tap(tree: SceneTree, k: Key) -> void:
	CaseUtil.key(k, true)
	await _wait(tree, 2)
	CaseUtil.key(k, false)
	await _wait(tree, 2)


func play(root: Node, tree: SceneTree) -> Array:
	var bad := []
	var b: RefCounted = HomeBuild.new(null, null, {"seed": SEED})
	for c: Vector3i in [Vector3i(0, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 0, 0)]:
		b.place(c, Blocks.code(Blocks.CUBE, 1))
	b.apply([zone(1, [0, 0, 0], [1, 1, 0], "none", "Door"), zone(2, [5, 0, 0], [5, 1, 0], "pad", "Switch"),
		rule(1, {"on": "enter", "zone": 2}, [{"do": "open", "zone": 1}])])
	var feet := [Vector3(-5, 0, 0.5)]
	var bm: Node = BuildMode.new()
	bm.set("build", b)
	bm.set("feet_at", func() -> Vector3: return feet[0])
	root.add_child(bm)
	var p: RefCounted = bm.get("play")
	var fac := Rec.new()
	p.set("facade", fac)
	fac.run = weakref(p.get("run"))
	await _wait(tree, 4)
	var on_walk: bool = p.get("running")
	feet[0] = Vector3(5.5, 0.0, 0.5)
	await _wait(tree, 2)
	var opened := str(fac.log)
	await _tap(tree, KEY_B)
	var stopped := [bool(bm.get("active")), p.get("running"), str(p.get("why_off"))]
	var closed := str(fac.log)
	var t0: int = p.get("ticks")
	await _wait(tree, 5)
	var t1: int = p.get("ticks")
	await _tap(tree, KEY_B)
	await _wait(tree, 2)
	var again: bool = p.get("running")
	if not on_walk or not opened.contains("\"set_open\", 1, \"[[0, 0, 0], [1, 1, 0]]\", true") or stopped != [true, false, "build"] \
			or not closed.ends_with("\"[[0, 0, 0], [1, 1, 0]]\", false]]") or t1 != t0 or not again:
		bad.append("walking %s; log after the switch %s; B -> active, running, why %s; log %s; ticks while building %d -> %d; B again running %s" % [
			on_walk, opened, str(stopped), closed, t0, t1, again])
	bm.queue_free()
	await _wait(tree, 2)
	# the blocks layer's mask: sections marked, the store and the file unchanged
	var bl: RefCounted = b.layer("blocks")
	b.flush()
	var h: String = bl.content_hash()
	var part := str(bl.save_part())
	bl.set_mask(1, Vector3i(0, 0, 0), Vector3i(1, 1, 0), true)
	var marked: int = (b.blocks.dirty as Dictionary).size()
	var m_in: bool = bl.masked(Vector3i(0, 1, 0))
	var m_out: bool = bl.masked(Vector3i(2, 0, 0))
	bl.clear_masks()
	var after: bool = bl.masked(Vector3i(0, 1, 0))
	if marked < 1 or not m_in or m_out or after or bl.content_hash() != h or str(bl.save_part()) != part:
		bad.append("mask: %d sections marked, masked in %s out %s after clear %s, store kept %s" % [marked, m_in, m_out, after, bl.content_hash() == h])
	return ["play", bad.is_empty(), "build mode off: the rules run (the switch opened the door: set_open 1 true); B on -> stopped '%s', the door closed, no ticks while building (%d -> %d); B off -> running again %s; mask: %d section(s) marked, masked %s/%s, cleared, store and file unchanged%s" % [
		str(stopped[2]), t0, t1, again, marked, m_in, m_out, "" if bad.is_empty() else "; BAD " + "; ".join(bad)]]
