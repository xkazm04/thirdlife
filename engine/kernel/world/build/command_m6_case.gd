extends SceneTree
## M6 lane C (27 Nov 2026): the LLM command bar's M6 part, headless, in the landscape of res://boot/village.json with
## build mode mounted, driven as a person drives it (keys through the engine's input state). No model is run: the
## Foreman door is dry and the case writes the answer files the Foreman would write (FAKE fixture answers). Frames, not
## wall clock. Prints `HOME command-m6.<case> ok|fail <detail>`, then `HOME command-m6 ok` (or fail) and `HOME DONE`;
## engine/tools/selftest.d/785-home-command-m6.sh reads them. A stone platform is laid first (hand blocks), so every
## fixture stands on one level whatever the ground does there.
##   command-m6.ask       with a hand zone and rule in the region, the ask carries `zones`, `rules` and `rules_room` at
##                        the top level and none of them in `layers` (the file: `-- <ask file>`, read by the Foreman's
##                        own reader in the shell script, which also measures the prompt)
##   command-m6.floating  an answer with a block in the air, a pad over nothing and a coin inside a cube: the ghost's
##                        note says "check: 1 block floats; ... has no floor; a coin is inside a block", red marks stand
##                        on the problem cells; Esc reverts, the Home untouched
##   command-m6.reach     the reachability estimate on three courses: a stair, a ledge, a 2-cell gap and a pillar
##                        (reachable); the same with a 5-cell gap (not); a flag on a 2-block pillar beside the start (not)
##   command-m6.course    a course answer (stair, ledge, coins, checkpoint, gap, pillar, flag; ids 1..n) over a Home that
##                        holds zone 1 and rule 1: the note counts "N zones, M rules: Hop" and finds nothing; Enter keeps
##                        ONE batch; the ids are renumbered past the Home's and the rules name the renumbered zones
##   command-m6.replay    the kept course replayed headless over the check's walk (command_replay.gd): the run starts,
##                        every coin is taken, the finish is recorded
## `-- replay <home dir>` instead loads a saved Home and prints `HOME replay <json>` per run (the real call's check);
## `-- site <x> <z>` prints flat unprotected patches near (x, z) (where the real call is asked).

const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const Door := preload("res://ui/foreman_door.gd")
const Replay := preload("res://kernel/world/build/command_replay.gd")
const TMP := "user://tl_command_m6_case"
const NEAR := Vector2i(700, -60)          # the dry site's search start (757's, 765's)

var walk: Dictionary
var node: Node3D
var ws: Object
var bm: Node
var b: RefCounted
var t: RefCounted
var ok_all := true
var site := {}                            # x, z: the platform's north-west cell; y: its blocks' y; top: the feet cell on it
var ask_out := ""                         # the first user argument: where the ask case copies its ask (a subclass: its file)
var prefix := "command-m6"                # the verdict lines' name


func _initialize() -> void:
	call_deferred("run")


func say(n: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME %s.%s %s %s" % [prefix, n, "ok" if ok else "fail", detail])


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func run() -> void:
	TLStyle.set_headless(false)
	var args := OS.get_cmdline_user_args()
	walk = CaseUtil.walk()
	node = CaseUtil.landscape(root, walk)
	if not node.has_meta(&"tl_build_mode"):
		say("ask", false, "no build mode was mounted")
		finish()
		return
	ws = node.get_meta(&"tl_space")
	bm = node.get_meta(&"tl_build_mode")
	b = node.get_meta(&"tl_build")
	if args.size() >= 2 and args[0] == "replay":
		await replay_dir(args[1])
		return
	if args.size() >= 3 and args[0] == "site":
		var near := Vector2i(int(args[1]), int(args[2]))
		for k in 8:
			var sx := find_site(near + Vector2i([0, 0, -14, 14, -14, 14, 0, 0][k], [0, -18, 0, 0, 18, 18, 18, -36][k]))
			print("HOME site %s" % JSON.stringify(sx))
		print("HOME DONE")
		quit(0)
		return
	ask_out = args[0] if args.size() >= 1 else ""
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP))
	for x: RefCounted in bm.get("tools"):
		if x.get("id") == "command":
			t = x
	bm.call("open", TMP)
	var door := Door.new()
	door.setup(ProjectSettings.globalize_path(TMP.path_join("llm")), {"dry": true, "flags": {"world_edit": ["--adapter", "fake"]}})
	t.set("door", door)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	bm.set("cam", cam)
	site = find_site(NEAR)
	var away := Vector3(site.x + 2.5, site.top + 1.0, site.z + 40.0)
	bm.set("feet_at", func() -> Vector3: return away)
	await wait(3)
	await tap(KEY_B)
	platform()
	await cases()
	finish()


## The cases on the platform (round 2: command_fix_case.gd extends this file and runs its own).
func cases() -> void:
	await ask_case()
	await floating_case()
	await reach_case()
	await course_case()


func finish() -> void:
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	print("HOME %s %s" % [prefix, "ok" if ok_all else "fail"])
	print("HOME DONE")
	quit(0)


func tap(k: Key) -> void:
	CaseUtil.key(k, true)
	await wait(2)
	CaseUtil.key(k, false)
	await wait(2)


## A 12 x 16 patch near `near` that nothing protects, ground within 1.5 m: the platform's blocks at its highest ground
## cell, so its top feet cell is one above.
func find_site(near: Vector2i) -> Dictionary:
	var home: RefCounted = node.get_meta(&"tl_home")
	for k in 40:
		var sx := near.x + 12 * k
		var sz := near.y
		home.ensure(Vector2(sx, sz))
		var lo := 1 << 30
		var hi := -(1 << 30)
		var clear := true
		for z in range(sz - 2, sz + 15):
			for x in range(sx - 2, sx + 11):
				var g := floori(float(ws.call("ground_at", x + 0.5, z + 0.5, 300.0)) + 0.01)
				lo = mini(lo, g)
				hi = maxi(hi, g)
				clear = clear and b.protect.call("refusal", Vector3i(x, g, z)) == ""
		if clear and hi - lo <= 1:
			return {"x": sx, "y": hi, "z": sz, "top": hi + 1, "tries": k + 1}
	return {"x": near.x, "y": 0, "z": near.y, "top": 1, "tries": 40}


## The hand-laid stone platform x .. x+9, z .. z+13 at y, with the ground filled under it.
func platform() -> void:
	var ops := []
	for z in range(site.z, site.z + 14):
		for x in range(site.x, site.x + 10):
			var g := floori(float(ws.call("ground_at", x + 0.5, z + 0.5, 300.0)) + 0.01)
			for y in range(g, site.y + 1):
				ops.append(place([x, y, z], 1, 2))
	var r: Dictionary = b.apply(ops)
	assert(r.ok, str(r.refused))


static func place(at: Array, shape: int, mat: int, rot := 0) -> Dictionary:
	return {"op": "place", "at": at, "shape": shape, "mat": mat, "rot": rot}


## The places of a filled box, as the Foreman expands a `fill` (x fastest, then z, then y).
static func fill(a: Array, c: Array, shape: int, mat: int, rot := 0) -> Array:
	var out := []
	for y in range(a[1], c[1] + 1):
		for z in range(a[2], c[2] + 1):
			for x in range(a[0], c[0] + 1):
				out.append(place([x, y, z], shape, mat, rot))
	return out


static func zone(n: int, lo: Array, hi: Array, look: String, name := "") -> Dictionary:
	var z := {"op": "zone", "id": n, "box": [lo, hi], "look": look}
	if name != "":
		z["name"] = name
	return z


static func rule(n: int, when: Dictionary, effects: Array, conds: Array = []) -> Dictionary:
	var r := {"op": "rule", "id": n, "when": when, "do": effects}
	if not conds.is_empty():
		r["if"] = conds
	return r


## A course on the platform (feet cell T = site.top): a start pad at z+11..12, a stair at z+10 onto a ledge at z+7..9
## (feet T+1) with a coin, a gap of `gap` cells, a pillar (feet T+2) with the finish flag. `wall`: instead, the flag
## stands on a 2-block pillar right beside the start.
func course_ops(gap: int, wall := false, coins := true) -> Array:
	var x: int = site.x + 2
	var z: int = site.z
	var y: int = site.top
	var ops := [zone(1, [x, y, z + 11], [x + 1, y, z + 12], "pad", "Start")]
	if wall:
		ops.append_array(fill([x, y, z + 9], [x + 1, y + 1, z + 10], 1, 1))
		ops.append(zone(2, [x, y + 2, z + 9], [x + 1, y + 2, z + 10], "flag", "Finish"))
	else:
		var p := z + 6 - gap                  # the pillar's south row
		ops.append_array(fill([x, y, z + 10], [x + 1, y, z + 10], 3, 1, 0))
		ops.append_array(fill([x, y, z + 7], [x + 1, y, z + 9], 1, 1))
		ops.append_array(fill([x, y, p - 1], [x + 1, y + 1, p], 1, 2))
		ops.append(zone(2, [x, y + 2, p - 1], [x + 1, y + 2, p], "flag", "Finish"))
		if coins:
			ops.append(zone(3, [x + 1, y + 1, z + 8], [x + 1, y + 2, z + 8], "coin"))
			ops.append(zone(4, [x, y, z + 7], [x + 1, y + 1, z + 9], "none", "Ledge"))
			ops.append(zone(5, [x - 1, y + 1, p - 1], [x - 1, y + 2, p - 1], "coin"))
			ops.append_array(fill([x - 1, y, p - 1], [x - 1, y, p - 1], 1, 2))
	ops.append(rule(1, {"on": "enter", "zone": 1}, [{"do": "start", "run": "Hop"}, {"do": "say", "text": "Go!", "frames": 60}]))
	ops.append(rule(2, {"on": "enter", "zone": 2}, [{"do": "finish"}], [{"running": true}]))
	if coins and not wall:
		for c: int in [3, 5]:
			ops.append(rule(c, {"on": "enter", "zone": c}, [{"do": "take", "zone": c}, {"do": "add", "counter": "coins", "by": 1}], [{"running": true}]))
		ops.append(rule(4, {"on": "enter", "zone": 4}, [{"do": "checkpoint", "zone": 4}], [{"running": true}]))
	return ops


func answer_for(p: Dictionary, ops: Array, note: String) -> void:
	var f := FileAccess.open(str(p.out), FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": "tl.world-edit/1", "ops": ops, "note": note, "model": "fake-model",
		"durationMs": 1234, "tokensIn": 900, "tokensOut": 300}) + "\n")
	f.close()


func send(sentence: String) -> Dictionary:
	var why: String = t.call("send", sentence, Vector3i(site.x + 3, site.top, site.z + 6), 0)
	var pend: Array = t.get("pending")
	return {} if why != "" or pend.is_empty() else pend[pend.size() - 1]


## Sends, answers with `ops` and waits for the ghost; returns the shown answer ({} when none came).
func ghost(sentence: String, ops: Array, note: String) -> Dictionary:
	var p := send(sentence)
	if p.is_empty():
		return {}
	answer_for(p, ops, note)
	await wait(20)
	return t.get("shown")


func key_on_ghost(k: Key) -> void:
	CaseUtil.key(k, true)
	await wait(2)
	CaseUtil.key(k, false)
	await wait(3)


# ------------------------------------------------------------------ cases
func ask_case() -> void:
	var x: int = site.x + 7
	var r: Dictionary = b.apply([zone(1, [x, site.top, site.z + 1], [x, site.top + 1, site.z + 1], "none", "Bell"),
		rule(1, {"on": "use", "zone": 1}, [{"do": "say", "text": "Ding", "frames": 60}])])
	var p := send("ring the bell")
	if p.is_empty() or not bool(r.ok):
		say("ask", false, "no ask (%s) or the hand zone was refused %s" % [str(t.call("status")), str(r.refused)])
		return
	var a: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(p.ask)))
	if ask_out != "":
		var f := FileAccess.open(ask_out, FileAccess.WRITE)
		f.store_string(FileAccess.get_file_as_string(str(p.ask)))
		f.close()
	var layers: Dictionary = a.get("layers", {})
	var ok: bool = a.has("zones") and a.has("rules") and a.has("rules_room") and not layers.has("zones") and not layers.has("rules") and \
		(a.zones as Array).size() == 1 and int(a.zones[0].id) == 1 and (a.rules as Array).size() == 1 and \
		int(a.rules_room.zones_left) == 511 and int(a.rules_room.rules_left) == 511 and (a.ops as Array).has("zone")
	say("ask", ok, "zones %s, rules %s, rules_room %s; layers keys %s; ops %s; %d bytes" % [JSON.stringify(a.get("zones")), JSON.stringify(a.get("rules")),
		JSON.stringify(a.get("rules_room")), str(layers.keys()), str(a.ops), FileAccess.get_file_as_string(str(p.ask)).length()])
	var f2 := FileAccess.open(str(p.out), FileAccess.WRITE)
	f2.store_string(JSON.stringify({"schema": "tl.world-edit/1", "error": "a case's answer"}))
	f2.close()
	await wait(20)


func floating_case() -> void:
	var x: int = site.x + 6
	var y: int = site.top
	var ops := [place([x, y + 3, site.z + 4], 1, 1), place([x + 1, y, site.z + 4], 1, 1),
		zone(1, [x, y + 5, site.z + 8], [x + 1, y + 5, site.z + 9], "pad", "Sky"),
		zone(2, [x + 1, y, site.z + 4], [x + 1, y, site.z + 4], "coin")]
	var before: int = b.blocks.total
	var hist: int = (b.edits.history as Array).size()
	var shown := await ghost("a block in the air and a coin", ops, "A floating block.")
	if shown.is_empty():
		say("floating", false, "no ghost: %s" % str(t.call("status")))
		return
	var info := str(t.call("status").info)
	var sp: Dictionary = shown.get("space", {})
	var marks: Node3D = t.get("space_marks")
	var n_marks := marks.get_child_count() if marks != null else 0
	await key_on_ghost(KEY_ESCAPE)
	var untouched: bool = int(b.blocks.total) == before and (b.edits.history as Array).size() == hist and t.get("space_marks") == null
	var ok: bool = info.contains("check: 1 block floats; the pad Sky has no floor; a coin is inside a block") and n_marks == 3 and \
		(sp.floating as Array) == [Vector3i(x, y + 3, site.z + 4)] and untouched
	say("floating", ok, "note '%s'; marks %d; floating %s; Esc: untouched %s" % [info, n_marks, str(sp.get("floating")), untouched])


func reach_case() -> void:
	var got := []
	var lines := []
	var ok := true
	for f: Array in [[2, false, true], [5, false, false], [0, true, false]]:
		var shown := await ghost("a course", course_ops(int(f[0]), bool(f[1]), false), "A course.")
		if shown.is_empty():
			say("reach", false, "no ghost for %s: %s" % [str(f), str(t.call("status"))])
			return
		var sp: Dictionary = shown.space
		var runs: Array = sp.runs
		var reach: bool = runs.size() == 1 and bool(runs[0].reachable)
		got.append(reach)
		lines.append("'%s' (%d feet cells, path %d)" % [sp.line, int(sp.nodes), (runs[0].path as Array).size() if runs.size() == 1 else -1])
		ok = ok and reach == bool(f[2]) and (str(sp.line) == "" if reach else str(sp.line) == "finish not reachable")
		await key_on_ghost(KEY_ESCAPE)
	say("reach", ok, "reachable %s (want [true, false, false]: 2-cell gap, 5-cell gap, 2-block wall); lines %s" % [str(got), ", ".join(PackedStringArray(lines))])


func course_case() -> void:
	var hist: int = (b.edits.history as Array).size()
	var ops := course_ops(2)
	var shown := await ghost("make this a parkour course", ops, "A short run, Hop: a stair, a ledge, a gap and a flag.")
	if shown.is_empty():
		say("course", false, "no ghost: %s" % str(t.call("status")))
		return
	var info := str(t.call("status").info)
	var sp: Dictionary = shown.space
	await key_on_ghost(KEY_ENTER)
	var rl: RefCounted = b.layer("rules")
	var zones: Dictionary = rl.get("zones")
	var rules: Dictionary = rl.get("rules")
	var flag := -1
	for n: int in zones:
		if str(zones[n].get("name", "")) == "Finish":
			flag = n
	var fin_rule := {}
	for n: int in rules:
		for e: Dictionary in rules[n].do:
			if str(e.do) == "finish":
				fin_rule = rules[n]
	var ids := zones.keys()
	ids.sort()
	var batches := (b.edits.history as Array).size() - hist
	var ok: bool = info.contains("5 zones, 5 rules: Hop") and not info.contains("check:") and batches == 1 and ids == [1, 2, 3, 4, 5, 6] and \
		flag == 3 and int(fin_rule.get("when", {}).get("zone", -1)) == flag and rules.size() == 6 and bool(sp.runs[0].reachable)
	say("course", ok, "note '%s'; Enter: %d batch; zone ids %s (the answer's 1..5 after the Home's 1), Finish is %d, its rule names %s; rules %d" % [
		info, batches, str(ids), flag, str(fin_rule.get("when")), rules.size()])
	var rp := Replay.replay(b, node)
	var hop: Dictionary = {}
	for r: Dictionary in rp.runs:
		if str(r.run) == "Hop":
			hop = r
	var rok: bool = not hop.is_empty() and bool(hop.finished) and int(hop.taken) == 2 and int(hop.coins) == 2 and (hop.says as Array).has("Go!")
	say("replay", rok, "run %s: walk %d feet cells, coins %d (on the walk %d, taken %d), finished %s in %d frames; says %s" % [
		str(hop.get("run")), (hop.get("walk", []) as Array).size(), int(hop.get("coins", -1)), int(hop.get("coins_on_walk", -1)), int(hop.get("taken", -1)),
		hop.get("finished"), int(hop.get("frames", -1)), str(hop.get("says"))])


## `-- replay <dir>`: the saved Home in `dir`, every run checked and replayed (the real call's evidence).
func replay_dir(dir: String) -> void:
	var r: Dictionary = bm.call("open", dir)
	var rl: RefCounted = b.layer("rules")
	var zs: Dictionary = rl.get("zones")
	for n: int in zs:
		var bx: Array = zs[n].box
		(node.get_meta(&"tl_home") as RefCounted).call("ensure", Vector2(bx[0][0], bx[0][2]))
	await wait(3)
	var rp := Replay.replay(b, node)
	var sp: Dictionary = rp.space
	print("HOME replay-space %s" % JSON.stringify({"loaded": r.ok, "blocks": int(b.blocks.total), "zones": zs.size(),
		"rules": (rl.get("rules") as Dictionary).size(), "line": sp.line, "nodes": sp.nodes, "no_floor": sp.no_floor,
		"coin_in_block": sp.coin_in_block}))
	for run: Dictionary in rp.runs:
		var d := run.duplicate()
		d.erase("log")
		d["walk"] = (run.walk as Array).map(func(c: Vector3i) -> Array: return [c.x, c.y, c.z])
		print("HOME replay %s" % JSON.stringify(d))
	var g: RefCounted = sp.grid
	if g != null:                         # the same runs for stricter walkers: hops of one cell, then walking only
		for lim: Array in [[1.2, 2.0], [0.55, 1.0]]:
			g.set("jump_up", lim[0])
			g.set("jump_across", lim[1])
			var mv := Replay.Space.moves(rl.get("rules"))
			for run: Dictionary in sp.runs:
				var w: Dictionary = g.call("walk", g.call("nodes_in", zs[int(run.start)].box), zs, mv.launches, mv.teleports)
				var fin: Array = (run.finish as Array).filter(func(f: int) -> bool: return (g.call("nodes_in", zs[f].box) as Array).any(func(c: Vector3i) -> bool: return w.has(c)))
				var coins := zs.values().filter(func(z: Dictionary) -> bool: return str(z.look) == "coin" and (g.call("nodes_in", z.box) as Array).any(func(c: Vector3i) -> bool: return w.has(c))).size()
				print("HOME replay-strict %s" % JSON.stringify({"run": run.run, "jump_up": lim[0], "jump_across": lim[1], "finish_reached": not fin.is_empty(), "coins_reached": coins, "cells_reached": w.size()}))
	for n: int in zs:
		print("HOME replay-zone %s" % JSON.stringify(zs[n]))
	for n: int in rl.get("rules"):
		print("HOME replay-rule %s" % rl.call("describe", n))
	print("HOME DONE")
	quit(0)
