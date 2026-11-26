extends SceneTree
## M5 lane C (spark world-sandbox): the LLM command bar's M5 part, headless, in the landscape of res://boot/village.json
## with build mode mounted, driven as a person drives it (keys through the engine's input state, letters pushed into the
## viewport, the pointer on a pixel). No model is run: the Foreman door is dry and the case writes the answer files the
## Foreman would write (the FAKE fixture answers). Frames, not wall clock. Prints `HOME command-m5.<case> ok|fail
## <detail>`, then `HOME command-m5 ok` (or fail) and `HOME DONE`; engine/tools/selftest.d/765-home-command-m5.sh reads them.
##   command-m5.water   an ask at the stream near the spawn carries `water` (the valley's river: y = floor(level), the
##                      cursor's column in a run) and its `ground` there is the bed (below the surface)
##   command-m5.locks   the ask's tables list only what play has unlocked: no mat 11 or 12, no locked part; after a grant
##                      (trophies.json) they are there, and what is still locked is not
##   command-m5.locked  an answer naming a locked part and material: the ghost counts them refused "locked: <condition>",
##                      Enter keeps the rest as one batch and the journal holds no locked op
##   command-m5.ghosts  an answer of land, paint, put, place, pour, path and plant ops: a ghost node per layer that applied
##                      ops and draws one (blocks by the tool's preview, the others by `preview_nodes`), the counts note
##                      over every kind; Esc reverts, the Home untouched
##   command-m5.stamp   the stamps tool: G opens the name field with "Stamp 1" selected, "My tower" typed and Enter held
##                      saves it under that name, and the held Enter neither opens the command bar nor leaves build mode;
##                      G then Esc saves nothing

const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const Door := preload("res://ui/foreman_door.gd")
const Unlocks := preload("res://kernel/world/build/unlocks.gd")
const StampFile := preload("res://kernel/world/build/stamp_file.gd")
const Lists := preload("res://kernel/world/build/seam_lists.gd")
const TMP := "user://tl_command_m5_case"
const NEAR := Vector2i(700, -60)          # the dry site's search start (757's)
const STREAM := Vector2i(-250, -30)       # the stream near the spawn (COMMAND.md's bridge)
const M1_MATS := [1, 2, 3, 4, 5, 6, 7, 8, 9]

var walk: Dictionary
var node: Node3D
var ws: Object
var bm: Node
var b: RefCounted
var t: RefCounted                         # the command tool
var cam: Camera3D
var site := {}
var ok_all := true
var door: RefCounted


func _initialize() -> void:
	call_deferred("run")


func say(n: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME command-m5.%s %s %s" % [n, "ok" if ok else "fail", detail])


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func run() -> void:
	TLStyle.set_headless(false)
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP))
	walk = CaseUtil.walk()
	node = CaseUtil.landscape(root, walk)
	if not node.has_meta(&"tl_build_mode"):
		say("water", false, "no build mode was mounted")
		return finish()
	ws = node.get_meta(&"tl_space")
	bm = node.get_meta(&"tl_build_mode")
	b = node.get_meta(&"tl_build")
	for x: RefCounted in bm.get("tools"):
		if x.get("id") == "command":
			t = x
	bm.call("open", TMP)
	door = Door.new()
	door.setup(ProjectSettings.globalize_path(TMP.path_join("llm")), {"dry": true, "flags": {"world_edit": ["--adapter", "fake"]}})
	t.set("door", door)
	cam = Camera3D.new()
	cam.fov = 60.0
	root.add_child(cam)
	cam.current = true
	bm.set("cam", cam)
	root.size = Vector2i(1280, 720)
	site = find_site(NEAR)
	var away := Vector3(site.x + 2.5, site.y + 1.0, site.z + 40.0)
	bm.set("feet_at", func() -> Vector3: return away)
	await wait(3)
	await tap(KEY_B)
	await water_case()
	await locked_case()
	await ghosts_case()
	await locks_case()
	await stamp_case()
	finish()


func finish() -> void:
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	print("HOME command-m5 %s" % ("ok" if ok_all else "fail"))
	print("HOME DONE")
	quit(0)


# ------------------------------------------------------------------ devices (as 757's command_case.gd)
func tap(k: Key) -> void:
	CaseUtil.key(k, true)
	await wait(2)
	CaseUtil.key(k, false)
	await wait(2)


func type_text(s: String) -> void:
	for i: int in s.length():
		var e := InputEventKey.new()
		e.pressed = true
		e.unicode = s.unicode_at(i)
		root.push_input(e)
	await wait(1)


func push_key(k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	root.push_input(e)
	var up := e.duplicate() as InputEventKey
	up.pressed = false
	root.push_input(up)
	await wait(2)


func over(p: Vector3) -> void:
	cam.look_at_from_position(p + Vector3(0.0, 16.0, 0.0), p, Vector3.FORWARD)
	cam.reset_physics_interpolation()


func ground(x: int, z: int) -> float:
	return float(ws.call("ground_at", x + 0.5, z + 0.5, site.get("y", 0) + 60.0))


func point(c: Vector2i) -> void:
	bm.set("pointer", cam.unproject_position(Vector3(c.x + 0.5, ground(c.x, c.y), c.y + 0.5)))


## A 9 x 7 patch near `near` whose ground varies less than 0.6 m and that nothing protects (757's).
func find_site(near: Vector2i) -> Dictionary:
	var home: RefCounted = node.get_meta(&"tl_home")
	for k in 30:
		var sx := near.x + 10 * k
		var sz := near.y
		home.ensure(Vector2(sx, sz))
		var lo := INF
		var hi := -INF
		var clear := true
		for z in range(sz - 1, sz + 6):
			for x in range(sx - 1, sx + 8):
				var g: float = float(ws.call("ground_at", x + 0.5, z + 0.5, 300.0))
				lo = minf(lo, g)
				hi = maxf(hi, g)
				clear = clear and b.protect.call("refusal", Vector3i(x, int(floorf(g + 0.01)), z)) == ""
		if clear and hi - lo < 0.6:
			return {"x": sx, "y": int(floorf(lo + 0.01)), "z": sz, "tries": k + 1}
	return {"x": near.x, "y": 0, "z": near.y, "tries": 30}


func answer_for(p: Dictionary, ops: Array, note: String) -> void:
	var f := FileAccess.open(str(p.out), FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": "tl.world-edit/1", "ops": ops, "note": note, "model": "fake-model",
		"durationMs": 1234, "tokensIn": 900, "tokensOut": 300}) + "\n")
	f.close()


func error_for(p: Dictionary) -> void:
	var f := FileAccess.open(str(p.out), FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": "tl.world-edit/1", "error": "a case's answer"}))
	f.close()


func ask_of(p: Dictionary) -> Dictionary:
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(p.ask)))
	return j if j is Dictionary else {}


## Sends `sentence` at `cell` through the tool (as 759 does) and returns the pending ask, or {}.
func send(sentence: String, cell: Vector3i) -> Dictionary:
	var why: String = t.call("send", sentence, cell, 0)
	var pend: Array = t.get("pending")
	return {} if why != "" or pend.is_empty() else pend[pend.size() - 1]


func ids(rows: Array, k: String) -> Array:
	return rows.map(func(r: Dictionary) -> Variant: return int(r[k]) if k == "id" else str(r[k]))


func last_journal_ops() -> Array:
	var h: Array = b.edits.history
	return (h[h.size() - 1] as Dictionary).get("ops", []) if not h.is_empty() else []


# ------------------------------------------------------------------ cases
func water_case() -> void:
	var valley: Object = load("res://kernel/world/build/command_ask.gd").call("valley_of", b)
	(node.get_meta(&"tl_home") as RefCounted).call("ensure", Vector2(STREAM.x, STREAM.y))
	var cell := Vector3i.ZERO
	var level := NAN
	var depth := 0.0
	for dx in range(-40, 41):                 # the deepest column of the stream along z = STREAM.y near STREAM.x
		var x := STREAM.x + dx
		var lv: Variant = valley.call("water", x + 0.5, STREAM.y + 0.5) if valley != null else null
		var bed: float = float(b.layer("land").call("height_at", x + 0.5, STREAM.y + 0.5))
		if lv != null and float(lv) - bed > depth:
			depth = float(lv) - bed
			level = float(lv)
			cell = Vector3i(x, int(floorf(bed + 0.01)), STREAM.y)
	var t0 := Time.get_ticks_usec()
	var p := send("a small stone bridge with railings across the stream here", cell)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	if p.is_empty() or is_nan(level):
		say("water", false, "no stream found near %s (level %s) or the ask was not sent: %s" % [str(STREAM), level, str(t.call("status"))])
		return
	var a := ask_of(p)
	var water: Array = a.get("water", [])
	var mine := {}
	for w: Dictionary in water:
		for r: Array in w.runs:
			if int(r[0]) == cell.z and cell.x >= int(r[1]) and cell.x <= int(r[2]):
				mine = w
	var lo: Array = a.region.min
	var bed_y := int(a.ground.rows[cell.z - int(lo[2])][cell.x - int(lo[0])])
	var cols := 0
	for w: Dictionary in water:
		for r: Array in w.runs:
			cols += int(r[2]) - int(r[1]) + 1
	var ok: bool = not water.is_empty() and not mine.is_empty() and int(mine.y) == floori(level) and bed_y <= int(mine.y) and \
		(water as Array).all(func(w: Variant) -> bool: return (w as Dictionary).keys() == ["y", "runs"])
	say("water", ok, "cursor %s on the bed (ground row %d), river level %.2f m -> water y %s over %d columns in %d level(s); ask %d bytes in %.1f ms (Ask.make + write)" % [
		str(cell), bed_y, level, str(mine.get("y", "none")), cols, water.size(), FileAccess.get_file_as_string(str(p.ask)).length(), ms])
	_water_ask = a
	error_for(p)
	await wait(20)


var _water_ask := {}


## The answer naming a locked part (house: win Parkour once) and a locked material (11 brick), beside free ones.
func locked_case() -> void:
	(node.get_meta(&"tl_home") as RefCounted).call("ensure", Vector2(site.x, site.z))   # the stream's ensure moved the kept chunks
	over(Vector3(site.x + 2.5, site.y, site.z + 2.0))
	await wait(4)
	point(Vector2i(site.x + 2, site.z + 2))
	await wait(3)
	await tap(KEY_ENTER)
	await type_text("a little wall with a house")
	await push_key(KEY_ENTER)
	await wait(2)
	var pend: Array = t.get("pending")
	if pend.is_empty():
		say("locked", false, "the ask was not sent: %s" % str(t.call("status")))
		return
	var u := Unlocks.new(ProjectSettings.globalize_path(TMP))
	var ops := []
	for x in range(site.x, site.x + 4):
		ops.append({"op": "place", "at": [x, site.y, site.z + 5], "shape": 1, "mat": 1, "rot": 0})
	ops.append({"op": "place", "at": [site.x + 4, site.y, site.z + 5], "shape": 1, "mat": 11, "rot": 0})
	ops.append({"op": "put", "at": [site.x + 2, site.y, site.z + 1], "part": "house", "rot": 0, "seed": 5})
	ops.append({"op": "put", "at": [site.x + 6, site.y, site.z + 1], "part": "crate", "rot": 0, "seed": 5})
	var before: int = b.blocks.total
	var hist: int = (b.edits.history as Array).size()
	answer_for(pend[0], ops, "A little stone wall, a house and a crate.")
	await wait(20)
	var shown: Dictionary = t.get("shown")
	var info := str(t.call("status").info)
	var refused: Array = (shown.get("preview", {}) as Dictionary).get("refused", [])
	var reasons := refused.map(func(x: Array) -> String: return str(x[1]))
	var want := ["locked: " + u.locked("mats", 11), "locked: " + u.locked("parts", "house")]
	CaseUtil.key(KEY_ENTER, true)
	await wait(2)
	CaseUtil.key(KEY_ENTER, false)
	await wait(3)
	var kept := last_journal_ops()
	var no_locked := kept.all(func(o: Dictionary) -> bool: return int(o.get("mat", 1)) != 11 and str(o.get("part", "")) != "house")
	var call: Array = (t.get("calls") as RefCounted).call("calls")
	var last: Dictionary = call[call.size() - 1]
	var ok: bool = not shown.is_empty() and reasons.has(want[0]) and reasons.has(want[1]) and info.contains("4 blocks, 1 part; 2 refused: locked: ") and \
		(b.edits.history as Array).size() == hist + 1 and kept.size() == 5 and no_locked and int(b.blocks.total) == before + 4 and \
		int(last.get("refused", 0)) == 2 and last.get("accepted") == true
	say("locked", ok, "ghost '%s' (refused %s, conditions %s); Enter kept %d ops in %d batch, none locked %s; blocks %d -> %d; log refused %s" % [
		info, str(reasons), str(want), kept.size(), (b.edits.history as Array).size() - hist, no_locked, before, int(b.blocks.total), str(last.get("refused"))])
	b.undo()
	await wait(2)


## land + paint + put + place + pour + path + plant in one answer: a ghost per layer that draws one, the counts.
func ghosts_case() -> void:
	var p := send("a terrace with a crate, a pond and a path", Vector3i(site.x + 2, site.y, site.z + 2))
	if p.is_empty():
		say("ghosts", false, "the ask was not sent: %s" % str(t.call("status")))
		return
	var land: RefCounted = b.layer("land")
	var i0 := floori((site.x + 1) / 3.0) + 1
	var j0 := floori((site.z + 1) / 3.0) + 1
	var verts := []
	for i in [i0, i0 + 1]:
		verts.append([i, j0, roundi(float(land.call("height_at", 3.0 * i, 3.0 * j0)) * 100.0) + 40])
	var ops := [
		{"op": "land", "verts": verts},
		{"op": "paint", "cells": [[i0, j0 + 1, "valley", "dirt"], [i0 + 1, j0 + 1, "valley", "dirt"]]},
		{"op": "place", "at": [site.x + 7, site.y, site.z + 4], "shape": 1, "mat": 2, "rot": 0},
		{"op": "place", "at": [site.x + 7, site.y + 1, site.z + 4], "shape": 2, "mat": 2, "rot": 0},
		{"op": "put", "at": [site.x + 6, site.y, site.z], "part": "crate", "rot": 1, "seed": 9},
		{"op": "pour", "at": [site.x + 3, site.y, site.z + 3]},
		{"op": "path", "id": 1, "pts": [[site.x * 100, (site.z + 5) * 100], [(site.x + 6) * 100, (site.z + 5) * 100]], "width_cm": 200, "paint": "dirt"},
		{"op": "plant", "cells": [[i0, j0 - 1, "valley", "meadow"]]}]
	var before: int = b.blocks.total
	var hist: int = (b.edits.history as Array).size()
	var t0 := Time.get_ticks_usec()
	answer_for(p, ops, "A terrace, a crate, a pond and a path.")
	await wait(20)
	var shown: Dictionary = t.get("shown")
	if shown.is_empty():
		say("ghosts", false, "no ghost: %s" % str(t.call("status")))
		return
	var r: Dictionary = shown.preview
	var got := (t.get("layer_ghosts") as Node3D).get_children().map(func(n: Node) -> String: return str(n.get_meta(&"tl_layer", "")))
	var applied := {}                          # layer -> ops it took in the dry run
	var bad := {}
	for x: Array in r.refused:
		bad[int(x[0])] = true
	for k: int in (shown.ops as Array).size():
		if not bad.has(k):
			var lid := Lists.layer_of(str(shown.ops[k].op))
			applied[lid] = int(applied.get(lid, 0)) + 1
	var want := []
	var none := []
	for l: RefCounted in b.layers:
		var lid := str(l.get("id"))
		if lid == "blocks" or not applied.has(lid):
			continue
		if not Lists.is_stub_layer(l) and l.has_method("preview_node"):
			want.append(lid)
		else:
			none.append(lid)
	var info := str(t.call("status").info)
	var blocks_drawn := int((t.get("preview") as Node3D).call("stats").tris)
	var piece_tris := 0
	for n: Node in (t.get("layer_ghosts") as Node3D).get_children():
		if str(n.get_meta(&"tl_layer", "")) == "pieces":
			for g: Node in n.get_children():
				piece_tris += (g as Node3D).get_child_count()
	CaseUtil.key(KEY_ESCAPE, true)             # the ghost has the keyboard: Esc reverts
	await wait(2)
	CaseUtil.key(KEY_ESCAPE, false)
	await wait(3)
	var untouched: bool = int(b.blocks.total) == before and (b.edits.history as Array).size() == hist and (t.get("shown") as Dictionary).is_empty() and \
		(t.get("layer_ghosts") as Node3D).get_child_count() == 0 and bool(bm.get("active"))
	var ok: bool = got == want and blocks_drawn > 0 and piece_tris > 0 and info.contains("2 blocks") and info.contains("1 part") and \
		info.contains("land 2 points") and info.contains("paint 2 cells") and untouched
	for k: String in ["pour", "path", "plant"]:
		var lid := Lists.layer_of(k)
		if Lists.is_stub_layer(b.layer(lid)):
			ok = ok and info.contains("not built yet: %s" % lid)
	say("ghosts", ok, "ghost nodes %s (want %s; layers that took ops but draw no ghost yet: %s); blocks %d tris, pieces %d meshes; note '%s'; shown in %.1f ms of wall clock (measured, not decided on); Esc: Home untouched %s" % [
		str(got), str(want), str(none), blocks_drawn, piece_tris, info, (Time.get_ticks_usec() - t0) / 1000.0, untouched])


## The ask's tables before and after trophies grant mats 11, 12 and four parts (the stream ask had none of them).
func locks_case() -> void:
	var before := _water_ask
	var f := FileAccess.open(TMP.path_join("trophies.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": "tl.trophies/1", "packs": {"seed.paddle": {"plays": 2, "wins": 1, "best": 6},
		"game.parkour": {"plays": 2, "wins": 1}}}))
	f.close()
	var u := Unlocks.new(ProjectSettings.globalize_path(TMP))
	var p := send("a brick house", Vector3i(site.x + 2, site.y, site.z + 2))
	if p.is_empty() or before.is_empty():
		say("locks", false, "no ask: %s" % str(t.call("status")))
		return
	var a := ask_of(p)
	var mats0 := ids(before.get("mats", []), "id")
	var mats1 := ids(a.get("mats", []), "id")
	var parts0 := ids(before.get("parts", []), "kind")
	var parts1 := ids(a.get("parts", []), "kind")
	var granted := ["bench", "street_lamp", "light_mast", "house"]
	var ok: bool = mats0 == M1_MATS and mats1 == M1_MATS + [11, 12] and granted.all(func(k: String) -> bool: return not parts0.has(k) and parts1.has(k)) and \
		not parts0.has("watch_tower") and not parts1.has("watch_tower") and u.locked("parts", "watch_tower") != "" and parts1.has("tree")
	say("locks", ok, "mats %s -> %s; parts %d -> %d (granted %s present %s; watch_tower still locked: '%s')" % [
		str(mats0), str(mats1), parts0.size(), parts1.size(), str(granted), granted.all(func(k: String) -> bool: return parts1.has(k)), u.locked("parts", "watch_tower")])
	error_for(p)
	await wait(20)


func stamp_case() -> void:
	for x in range(site.x, site.x + 3):
		b.apply([{"op": "place", "at": [x, site.y, site.z + 2], "shape": 1, "mat": 1, "rot": 0}])
	var st: RefCounted = null
	while str(bm.call("tool").get("id")) != "stamp":
		await tap(KEY_T)
	st = bm.call("tool")
	await tap(KEY_0)
	bm.set("hit", {"pos": Vector3(site.x + 0.5, site.y + 0.5, site.z + 2.5), "normal": Vector3.UP, "block": true,
		"place": Vector3i(site.x, site.y + 1, site.z + 2), "remove": Vector3i(site.x, site.y, site.z + 2)})
	st.press(MOUSE_BUTTON_LEFT, {})
	bm.set("hit", {"pos": Vector3(site.x + 2.5, site.y + 0.5, site.z + 2.5), "normal": Vector3.UP, "block": true,
		"place": Vector3i(site.x + 2, site.y + 1, site.z + 2), "remove": Vector3i(site.x + 2, site.y, site.z + 2)})
	st.press(MOUSE_BUTTON_LEFT, {})
	await tap(KEY_G)
	var bar: CanvasLayer = st.get("name_bar")
	var line: LineEdit = bar.get("line") if bar != null else null
	var shown_name: String = line.text if line != null else ""
	var selected: bool = line != null and line.has_selection() and line.get_selected_text() == shown_name
	var focus: bool = line != null and root.gui_get_focus_owner() == line
	await type_text("My tower")
	var typed: String = line.text if line != null else ""
	CaseUtil.key(KEY_ENTER, true)             # held, as a person holds it: the field takes it, build mode must not
	await wait(1)
	var via := "the engine's key"
	if bar != null and bar.call("is_open"):
		via = "pushed into the viewport"
		var e := InputEventKey.new()          # a headless run hands the engine's key to no GUI: the field gets it here
		e.keycode = KEY_ENTER
		e.physical_keycode = KEY_ENTER
		e.pressed = true
		root.push_input(e)
	await wait(8)
	var held_ok: bool = str(bm.call("tool").get("id")) == "stamp" and not (t.get("bar") != null and t.get("bar").call("is_open")) and bool(bm.get("active"))
	CaseUtil.key(KEY_ENTER, false)
	await wait(4)
	var after_ok: bool = str(bm.call("tool").get("id")) == "stamp" and not (t.get("bar") != null and t.get("bar").call("is_open")) and bool(bm.get("active")) and \
		not bool(st.call("blocks_input"))
	var dir := ProjectSettings.globalize_path(TMP.path_join("stamps"))
	var names: Array = StampFile.list(dir).stamps.map(func(s: Dictionary) -> String: return str(s.stamp.name))
	# G then Esc: nothing saved, still building
	await tap(KEY_0)
	bm.set("hit", {"pos": Vector3(site.x + 0.5, site.y + 0.5, site.z + 2.5), "normal": Vector3.UP, "block": true,
		"place": Vector3i(site.x, site.y + 1, site.z + 2), "remove": Vector3i(site.x, site.y, site.z + 2)})
	st.press(MOUSE_BUTTON_LEFT, {})
	st.press(MOUSE_BUTTON_LEFT, {})
	await tap(KEY_G)
	var second: String = line.text if line != null else ""
	CaseUtil.key(KEY_ESCAPE, true)
	await wait(1)
	if bar != null and bar.call("is_open"):
		await push_key(KEY_ESCAPE)
	await wait(4)
	var esc_active: bool = bool(bm.get("active"))
	CaseUtil.key(KEY_ESCAPE, false)
	await wait(4)
	var names2: Array = StampFile.list(dir).stamps.map(func(s: Dictionary) -> String: return str(s.stamp.name))
	var ok: bool = shown_name == "Stamp 1" and selected and focus and typed == "My tower" and held_ok and after_ok and names == ["My tower"] and \
		second == "Stamp 1" and esc_active and bool(bm.get("active")) and names2 == ["My tower"] and line.max_length == StampFile.NAME_MAX
	say("stamp", ok, "G: field '%s' selected %s focus %s (max %d); typed '%s'; Enter (reached the field %s) held 8 frames: tool %s, command bar open %s, building %s; saved %s; G again '%s', Esc: building %s, stamps %s" % [
		shown_name, selected, focus, line.max_length if line != null else -1, typed, via, str(bm.call("tool").get("id")),
		t.get("bar") != null and t.get("bar").call("is_open"), bm.get("active"), str(names), second, esc_active, str(names2)])
