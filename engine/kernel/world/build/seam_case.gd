extends SceneTree
## SEAM (spark world-sandbox, M2-M4): the shared seam, headless, without a landscape (build mode is mounted on a bare
## builder). Prints `HOME seam.<case> ok|fail <detail>`, then `HOME seam ok` (or fail) and `HOME DONE`;
## engine/tools/selftest.d/754-home-build-seam.sh reads them. Frames, not wall clock.
##   seam.registry  the three layers and the six ops they own; an unknown op names the known ones; a layer that owns
##                  an op replaces the one that had it
##   seam.stubs     well-formed land, paint, put and lift ops are refused "not built yet (M2)" / "(M3)"; malformed ones
##                  with the contract's reason (unknown key, entries, types, paint names, rot, seed, part); none logged
##   seam.files     a blocks-only Home is written as tl.build/1 byte for byte as M1's writer did; a layer with content
##                  makes it tl.build/2 (keys in order), which loads back; a v1 file with a v2 key is refused
##   seam.mark      build.json becomes tl.build/2 BEFORE the first op v1 cannot read is journaled (once), its content
##                  unchanged; the journal replays over it; a save with no v2 content writes v1 again
##   seam.tools     T / Shift+T walk the six tools, the hotbar shows each stub's "coming in M2/M3/M4" line, a stub takes
##                  no key, Enter picks the command tool (its disabled line), the blocks tool's keys still work
##   seam.preview   a dry run of 200 ops (and a land op) returns what it would add and remove and leaves the store,
##                  the log, the journal and build.json as they were; the preview mesh draws it
##   seam.region    read_region gives the blocks in a box sorted by z, x, y, and refuses a box too large
##   seam.protect   a layer's cell rule and area rule refuse with their reasons (add_rule, refusal_area)

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const BuildFile := preload("res://kernel/world/build/build_file.gd")
const BuildMode := preload("res://kernel/world/build/build_mode.gd")
const PreviewMesh := preload("res://kernel/world/build/preview_mesh.gd")
const Blocks := preload("res://kernel/world/build/blocks.gd")
const EditLog := preload("res://kernel/world/build/edit_log.gd")
const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const TMP := "user://tl_build_seam_case"

var ok_all := true


## A land layer made applicable for this case only (M2's stub stays a stub): heights per vertex, saved as `land`.
class TestLand extends RefCounted:
	const LandLayer := preload("res://kernel/world/build/land_layer.gd")
	var id := "land"
	var h := {}                          # Vector2i -> cm
	var check: RefCounted = LandLayer.new({})
	func ops() -> PackedStringArray: return PackedStringArray(["land"])
	func malformed(op: Variant, strict := false) -> String: return check.malformed(op, strict)
	func can_apply(_op: Dictionary) -> String: return ""
	func fits(_rec: Dictionary) -> String: return ""
	func raw(op: Dictionary) -> Dictionary: return check.raw(op)
	func invert(rec: Dictionary) -> Dictionary: return check.invert(rec)
	func apply(rec: Dictionary) -> void:
		for e: Array in rec.verts:
			if int(e[3]) == 0: h.erase(Vector2i(int(e[0]), int(e[1])))
			else: h[Vector2i(int(e[0]), int(e[1]))] = int(e[3])
	func save_part() -> Dictionary:
		if h.is_empty(): return {}
		var pairs := PackedInt32Array()
		var keys: Array = h.keys()
		keys.sort()
		for k: Vector2i in keys: pairs.append_array([k.x + 32 * k.y, h[k]])
		return {"land": {"0,0": Marshalls.raw_to_base64(pairs.to_byte_array())}}
	func load_part(doc: Dictionary) -> String:
		var pairs := Marshalls.base64_to_raw(str((doc.get("land", {}) as Dictionary).get("0,0", ""))).to_int32_array()
		for i: int in range(0, pairs.size(), 2): h[Vector2i(pairs[i] % 32, pairs[i] / 32)] = pairs[i + 1]
		return ""
	func clear() -> void: h.clear()
	func size() -> int: return h.size()
	func content_hash() -> String: return str(h)
	func dirty_regions(_rec: Dictionary) -> Array: return []
	func step(_b: int) -> int: return 0
	func pending() -> int: return 0
	func copy() -> RefCounted:
		var c := TestLand.new()
		c.h = h.duplicate()
		return c
	func free_all() -> void: pass


func _initialize() -> void:
	call_deferred("run")


func say(case_name: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME seam.%s %s %s" % [case_name, "ok" if ok else "fail", detail])


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func run() -> void:
	TLStyle.set_headless(false)
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	DirAccess.make_dir_recursive_absolute(TMP)
	registry()
	stubs()
	files()
	mark()
	await tools()
	preview()
	region()
	protect()
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	print("HOME seam %s" % ("ok" if ok_all else "fail"))
	print("HOME DONE")
	quit(0)


func cube(m := 1) -> int:
	return Blocks.code(Blocks.CUBE, m)


# ------------------------------------------------------------------ cases
func registry() -> void:
	var b: RefCounted = HomeBuild.new(null, null, {})
	var ids: Array = b.layers.map(func(l: RefCounted) -> String: return str(l.get("id")))
	var op_names: Array = b.edits.by_op.keys()
	var unknown := str(b.apply({"op": "dig", "at": [0, 0, 0]}).reason)
	var t := TestLand.new()
	b.register(t)
	var after: Array = b.layers.map(func(l: RefCounted) -> String: return str(l.get("id")))
	var paint_gone: bool = not b.edits.by_op.has("paint")       # the land stub owned paint too: replaced whole
	var ok: bool = ids == ["blocks", "land", "pieces"] and op_names == ["place", "remove", "land", "paint", "put", "lift"] \
		and unknown.begins_with("op must be one of \"place\"") and b.layer("land") == t and after == ["blocks", "pieces", "land"] and paint_gone
	say("registry", ok, "layers %s owning %s; unknown op: '%s'; a test layer owning land replaced the stub: layers %s, paint unowned %s" % [
		str(ids), str(op_names), unknown, str(after), paint_gone])


func stubs() -> void:
	var b: RefCounted = HomeBuild.new(null, null, {})
	var cases := {
		"land": [{"op": "land", "verts": [[1, 2, 0, 2500]]}, ["not built yet (M2)", "height limit (24 m"]],
		"paint": [{"op": "paint", "cells": [[1, 2, "sand", "dirt"]]}, ["not built yet (M2)", "cells: [1, 2] is 'valley', not 'sand'"]],
		"put": [{"op": "put", "at": [3, 20, 4], "part": "fence", "params": {"length": 40.0}, "rot": 1, "seed": 7}, ["not built yet (M3)", "too large for a piece"]],
		"lift": [{"op": "lift", "at": [3, 20, 4]}, ["not built yet (M3)", "no piece there"]],
		"land unknown key": [{"op": "land", "verts": [[1, 2, 0, 150]], "brush": 3}, "unknown key 'brush'"],
		"land three numbers": [{"op": "land", "verts": [[1, 2, 2500]]}, ["verts: every entry is [i, j, from_cm, to_cm]", "height limit (24 m"]],
		"land half a cm": [{"op": "land", "verts": [[1, 2, 0, 1.5]]}, "verts: heights are integer cm"],
		"land twice": [{"op": "land", "verts": [[1, 2, 0, 10], [1, 2, 10, 20]]}, "verts: [1, 2] is named twice"],
		"land no verts": [{"op": "land", "verts": []}, "verts must be a non-empty list"],
		"paint lava": [{"op": "paint", "cells": [[0, 0, "valley", "lava"]]}, "cells: 'lava' is not a paint"],
		"paint verts": [{"op": "paint", "verts": [[0, 0, 0, 1]]}, "unknown key 'verts'"],
		"put rot 4": [{"op": "put", "at": [3, 20, 4], "part": "crate", "rot": 4, "seed": 7}, "rot must be 0..3"],
		"put seed text": [{"op": "put", "at": [3, 20, 4], "part": "crate", "rot": 0, "seed": "x"}, "seed must be an integer"],
		"put no part": [{"op": "put", "at": [3, 20, 4], "rot": 0}, "part is missing"],
		"put spaceship": [{"op": "put", "at": [3, 20, 4], "part": "spaceship", "rot": 0}, "'spaceship' is not a kit part"],
		"put empty params": [{"op": "put", "at": [3, 20, 4], "part": "crate", "params": {}, "rot": 0}, "params are written only when not all defaults"],
		"put y 200": [{"op": "put", "at": [3, 200, 4], "part": "crate", "rot": 0}, "out of range"],
		"journal land without batch": [{"v": 1, "op": "land", "verts": [[1, 2, 0, 150]], "author": "hand"}, "batch is missing"]}
	var got := []
	var bad := []
	for k: String in cases:
		var why: String = str(b.edits.validate(cases[k][0], true)) if k.begins_with("journal") else str(b.apply(cases[k][0]).reason)
		got.append("%s: '%s'" % [k, why])
		var wants: Array = cases[k][1] if cases[k][1] is Array else [cases[k][1]]   # a stub's reason, or the built layer's refusal
		if not wants.any(func(w: String) -> bool: return why.begins_with(w)):
			bad.append("%s: '%s', want '%s'" % [k, why, cases[k][1]])
	if b.edits.history.size() != 0:
		bad.append("a refused op reached the log")
	say("stubs", bad.is_empty(), "; ".join(got) + ("" if bad.is_empty() else "; BAD " + "; ".join(bad)))


## M1's writer of tl.build/1 (build_file.gd `text_of` as committed in dbf5ce2b), to hold the bytes to it.
static func m1_text(store: RefCounted, home_seed: int, rev: int) -> String:
	var parts := PackedStringArray()
	for ch: Vector2i in Blocks.sorted_ids(store.counts):
		var pairs: PackedInt32Array = store.chunk_pairs(ch)
		parts.append("%s:%s" % [JSON.stringify("%d,%d" % [ch.x, ch.y]), JSON.stringify(Marshalls.raw_to_base64(pairs.to_byte_array()))])
	return "{\"v\":1,\"seed\":%d,\"rev\":%d,\"chunks\":{%s}}\n" % [home_seed, rev, ",".join(parts)]


func files() -> void:
	var bad := []
	var b: RefCounted = HomeBuild.new(null, null, {"seed": 11})
	for c: Vector3i in [Vector3i(1, 2, 3), Vector3i(-200, 5, 7), Vector3i(100, -16, -100), Vector3i(1, 3, 3)]:
		b.place(c, Blocks.code(Blocks.STAIR, 2, 1, true) if c.y == 3 else cube())
	var d1 := TMP.path_join("v1")
	b.save(d1)
	var text1 := FileAccess.get_file_as_string(d1.path_join("build.json"))
	var same_v1 := text1 == m1_text(b.blocks, 11, b.rev)
	if not same_v1:
		bad.append("v1 bytes differ from M1's writer: %s" % text1.substr(0, 80))
	var t := TestLand.new()
	b.register(t)
	b.apply({"op": "land", "verts": [[3, 4, 0, 250], [5, 6, 0, -40]]})
	var d2 := TMP.path_join("v2")
	b.save(d2)
	var text2 := FileAccess.get_file_as_string(d2.path_join("build.json"))
	var head_ok := text2.begins_with("{\"v\":2,\"seed\":11,\"rev\":") and text2.find("\"chunks\":") < text2.find("\"land\":")
	if not head_ok:
		bad.append("v2 head or key order: %s" % text2.substr(0, 60))
	var c2: RefCounted = HomeBuild.new(null, null, {"seed": 11})
	var t2 := TestLand.new()
	c2.register(t2)
	var r2: Dictionary = c2.load(d2)
	if not r2.ok or int(r2.v) != 2 or t2.h != t.h or c2.blocks.content_hash() != b.blocks.content_hash():
		bad.append("v2 load: %s, land %s want %s" % [str(r2), str(t2.h), str(t.h)])
	var d3 := TMP.path_join("v1land")
	DirAccess.make_dir_recursive_absolute(d3)
	var f := FileAccess.open(d3.path_join("build.json"), FileAccess.WRITE)
	f.store_string("{\"v\":1,\"seed\":11,\"rev\":1,\"chunks\":{},\"land\":{}}\n")
	f.close()
	var r3: Dictionary = HomeBuild.new(null, null, {"seed": 11}).load(d3)
	if r3.ok or not str(r3.reason).ends_with("unknown key 'land'"):
		bad.append("a v1 file with land: %s" % str(r3.reason))
	var c4: RefCounted = HomeBuild.new(null, null, {"seed": 11})
	var r4: Dictionary = c4.load(d2)                         # the stub layer: a v2 file with land content
	say("files", bad.is_empty(), "v1 %d bytes equal to M1's writer %s; with land: %s...; loaded back v%d with %d vertices; v1 + land key: '%s'; the M2 stub reads that v2 file as '%s'%s" % [
		text1.length(), str(same_v1), text2.substr(0, 40), int(r2.v), t2.h.size(),
		str(r3.reason).get_file(), str(r4.reason).get_file(), "" if bad.is_empty() else "; BAD " + "; ".join(bad)])


func mark() -> void:
	var bad := []
	var d := TMP.path_join("mark")
	var b: RefCounted = HomeBuild.new(null, null, {"seed": 11})
	b.place(Vector3i(4, 4, 4), cube())
	b.save(d)
	b.place(Vector3i(5, 4, 4), cube())                         # journaled under a v1 build.json
	var before := FileAccess.get_file_as_string(d.path_join("build.json"))
	var t := TestLand.new()
	b.register(t)
	var seen := []                                             # what the hook saw: build.json's head, journal lines
	var hook: Callable = b.edits.before_journal
	b.edits.before_journal = func(rec: Dictionary) -> String:
		var why := str(hook.call(rec))
		seen.append([FileAccess.get_file_as_string(d.path_join("build.json")).substr(0, 7), _lines(d), rec.op])
		return why
	b.apply({"op": "land", "verts": [[1, 1, 0, 100]]})
	b.apply({"op": "land", "verts": [[2, 1, 0, 100]]})
	var after := FileAccess.get_file_as_string(d.path_join("build.json"))
	var journal := _lines(d)
	if seen.size() != 1 or seen[0][0] != "{\"v\":2," or int(seen[0][1]) != 1:
		bad.append("hook calls %s (want one, after build.json became v2, before the land line)" % str(seen))
	if after != "{\"v\":2," + before.substr(7):
		bad.append("build.json content changed: %s" % after.substr(0, 60))
	if journal != 3:
		bad.append("journal %d lines, want 3" % journal)
	var c: RefCounted = HomeBuild.new(null, null, {"seed": 11})
	var t2 := TestLand.new()
	c.register(t2)
	var r: Dictionary = c.load(d)
	if not r.ok or int(r.replayed) != 3 or c.blocks.total != 2 or t2.h.size() != 2:
		bad.append("replay over the v2 file: %s, %d blocks, %d vertices" % [str(r), c.blocks.total, t2.h.size()])
	b.undo()
	b.undo()
	b.save(d)
	var v1_again := FileAccess.get_file_as_string(d.path_join("build.json")).begins_with("{\"v\":1,")
	if not v1_again:
		bad.append("a save with no land wrote %s" % FileAccess.get_file_as_string(d.path_join("build.json")).substr(0, 8))
	b.edits.before_journal = hook
	b.redo()                                                   # a redo of a land op marks again
	var remarked := FileAccess.get_file_as_string(d.path_join("build.json")).begins_with("{\"v\":2,")
	if not remarked:
		bad.append("a redone land op was journaled under a v1 build.json")
	say("mark", bad.is_empty(), "hook called %d time(s), saw build.json %s with %d journal line(s) before the %s line; content unchanged %s; journal %d lines replayed over it (%d blocks, %d vertices); save without land -> v1 %s; redo of land -> v2 %s%s" % [
		seen.size(), str(seen[0][0]) if not seen.is_empty() else "-", int(seen[0][1]) if not seen.is_empty() else -1, str(seen[0][2]) if not seen.is_empty() else "-",
		str(after == "{\"v\":2," + before.substr(7)), journal, c.blocks.total, t2.h.size(), v1_again, remarked, "" if bad.is_empty() else "; BAD " + "; ".join(bad)])


func _lines(d: String) -> int:
	return FileAccess.get_file_as_string(d.path_join("edits.jsonl")).strip_edges().split("\n", false).size()


func tap(k: Key, shift := false) -> void:
	if shift:
		CaseUtil.key(KEY_SHIFT, true)
	CaseUtil.key(k, true, shift)
	await wait(2)
	CaseUtil.key(k, false, shift)
	if shift:
		CaseUtil.key(KEY_SHIFT, false)
	await wait(2)


func _is_stub(t: RefCounted) -> bool:
	var sc: Script = t.get_script()
	return sc != null and (sc as GDScript).get_base_script() == preload("res://kernel/world/build/tools/stub_tool.gd")


func tools() -> void:
	var b: RefCounted = HomeBuild.new(null, null, {})
	var bm: Node = BuildMode.new()
	bm.set("build", b)
	root.add_child(bm)
	await wait(2)
	await tap(KEY_B)
	var hb: CanvasLayer = bm.get("hotbar")
	var seen := []
	var want := ["Sculpt: coming in M2", "Paint: coming in M2", "Pieces: coming in M3", "Stamps: coming in M3", "Command: coming in M4"]
	var bad := []
	for i in 5:
		await tap(KEY_T)
		var text: String = (hb.get("info") as Label).text
		seen.append("%s '%s'" % [bm.call("tool").get("id"), text])
		var stub: bool = _is_stub(bm.call("tool"))   # a lane's built tool replaces its stub: then any non-empty line will do
		if (stub and (text != want[i] or (hb.get("row") as Control).visible)) or (not stub and text.is_empty()):
			bad.append("T %d: '%s' (slots shown %s)" % [i + 1, text, (hb.get("row") as Control).visible])
		if i == 0:
			await tap(KEY_3)                                   # a stub takes no key: the shape stays
			if int(bm.get("shape")) != 1:
				bad.append("3 on the sculpt tool changed the shape to %d" % int(bm.get("shape")))
	await tap(KEY_T)
	var wrapped: String = bm.call("tool").get("id")
	await tap(KEY_T, true)
	var back: String = bm.call("tool").get("id")
	await tap(KEY_T, true)
	await tap(KEY_ENTER)
	var line: String = (hb.get("info") as Label).text
	var cmd: String = bm.call("tool").get("id")
	await tap(KEY_T)
	await tap(KEY_3)
	var slots: Array = hb.get("slots")
	var lit := -1
	for i: int in slots.size():
		if (slots[i][0] as PanelContainer).get_theme_stylebox("panel") == hb.get("_lit"):
			lit = i + 1
	var strip: Array = hb.get("tools")
	if wrapped != "blocks" or back != "command" or cmd != "command" or (_is_stub(bm.call("tool")) and not line.ends_with("coming in M4)")) or line.is_empty() or int(bm.get("shape")) != 3 or lit != 3 or strip.size() != 6:
		bad.append("wrap %s, Shift+T %s, Enter %s '%s', blocks shape %d lit slot %d, strip %d" % [wrapped, back, cmd, line, int(bm.get("shape")), lit, strip.size()])
	say("tools", bad.is_empty(), "%s; T from command -> %s; Shift+T -> %s; Enter -> %s '%s'; T then 3 -> blocks shape %d (slot %d lit of %d), strip of %d tools%s" % [
		"; ".join(seen), wrapped, back, cmd, line, int(bm.get("shape")), lit, slots.size(), strip.size(), "" if bad.is_empty() else "; BAD " + "; ".join(bad)])
	bm.queue_free()
	await wait(2)


func preview() -> void:
	var bad := []
	var d := TMP.path_join("preview")
	var b: RefCounted = HomeBuild.new(null, null, {})
	for x in 20:
		b.place(Vector3i(x, 10, 0), cube())
	b.save(d)
	b.place(Vector3i(0, 11, 0), cube())
	var snap := [b.blocks.content_hash(), b.edits.history.size(), b.edits.next_batch, b.blocks.total, b.dirty, _bytes(d, "build.json"), _bytes(d, "edits.jsonl")]
	var ops := []
	for i in 190:
		ops.append({"op": "place", "at": [i % 19, 10 + i / 19, 2], "shape": 1, "mat": 3, "rot": 0})
	for x in 9:
		ops.append({"op": "remove", "at": [x, 10, 0]})
	ops.append({"op": "land", "verts": [[0, 0, 0, 100]]})
	var r: Dictionary = b.preview(ops)
	var snap2 := [b.blocks.content_hash(), b.edits.history.size(), b.edits.next_batch, b.blocks.total, b.dirty, _bytes(d, "build.json"), _bytes(d, "edits.jsonl")]
	if snap2 != snap:
		bad.append("the real Home changed: %s -> %s" % [str(snap.slice(0, 5)), str(snap2.slice(0, 5))])
	if int(r.applied) != 199 or (r.refused as Array).size() != 1 or not (str(r.refused[0][1]) in ["not built yet (M2)", "blocks"]):
		bad.append("applied %d, refused %s" % [int(r.applied), str(r.refused)])
	var added: int = (r.store as RefCounted).get("total")
	var removed: int = (r.removed as RefCounted).get("total")
	if added != 190 or removed != 9:
		bad.append("added %d (want 190), removed %d (want 9)" % [added, removed])
	var holder := Node3D.new()
	root.add_child(holder)
	var pm: Node3D = PreviewMesh.new()
	holder.add_child(pm)
	var tris: int = pm.show_stores(r.store, r.removed)
	var st: Dictionary = pm.stats()
	if tris <= 0 or b.stats().sections != 0:
		bad.append("preview drew %d triangles; the Home's own meshes %d" % [tris, b.stats().sections])
	pm.clear()
	holder.queue_free()
	say("preview", bad.is_empty(), "%d ops (190 places, 9 removes, 1 land): applied %d, refused %s; would add %d and remove %d blocks; the store, log, batch counter, dirty flag, build.json and edits.jsonl unchanged %s; preview mesh %d sections %d triangles%s" % [
		ops.size(), int(r.applied), str(r.refused), added, removed, str(snap2 == snap), int(st.sections), tris, "" if bad.is_empty() else "; BAD " + "; ".join(bad)])


func _bytes(d: String, f: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(d.path_join(f))


func region() -> void:
	var b: RefCounted = HomeBuild.new(null, null, {})
	for c: Vector3i in [Vector3i(3, 5, 2), Vector3i(1, 5, 2), Vector3i(1, 4, 2), Vector3i(2, 5, 1), Vector3i(40, 5, 2), Vector3i(-1, 5, 2), Vector3i(2, 30, 2)]:
		b.place(c, cube(int(c.x) % 9 + 1 if c.x > 0 else 9))
	var r: Dictionary = b.read_region(Vector3i(0, 0, 0), Vector3i(10, 10, 10))
	var cells: Array = (r.get("blocks", []) as Array).map(func(e: Array) -> String: return "%d,%d,%d" % [e[0], e[1], e[2]])
	var want := ["2,5,1", "1,4,2", "1,5,2", "3,5,2"]
	var big: Dictionary = b.read_region(Vector3i(0, 0, 0), Vector3i(200, 10, 10))
	var codes_ok: bool = not (r.get("blocks", []) as Array).is_empty() and int(r.blocks[0][3]) == cube(3)
	var ok: bool = cells == want and codes_ok and (r.keys() as Array).slice(0, 3) == ["min", "max", "blocks"] and big.has("error")
	say("region", ok, "box 0..10: %s (want %s), codes %s, keys %s; a 201-cell box: '%s'" % [str(cells), str(want), codes_ok, str(r.keys()), str(big.get("error", ""))])


var _rule_cell := Vector3i(7, 7, 7)


func _piece_rule(cell: Vector3i, _code: int) -> String:
	return "piece (test crate)" if cell == _rule_cell else ""


func _area_rule(rect: Rect2, what: String) -> String:
	return "the river band" if rect.has_point(Vector2(31, 31)) and what == "land" else ""


func protect() -> void:
	var b: RefCounted = HomeBuild.new(null, null, {})
	b.protect.add_rule(Callable(self, "_piece_rule"))
	b.protect.add_rule(Callable(self, "_area_rule"), "area")
	b.protect.add_circle(Vector2(100, 100), 5.0, "game lot")
	var cell_why: String = b.can_place(_rule_cell, cube())
	var place_why := str(b.place(_rule_cell, cube()).reason)
	var free_why: String = b.can_place(_rule_cell + Vector3i.RIGHT, cube())
	var river: String = b.protect.refusal_area(Rect2(30, 30, 3, 3), "land")
	var river_paint: String = b.protect.refusal_area(Rect2(30, 30, 3, 3), "paint")
	var lot: String = b.protect.refusal_area(Rect2(102, 102, 3, 3), "paint")
	var ok: bool = cell_why == "piece (test crate)" and place_why == cell_why and free_why == "" and river == "the river band" and river_paint == "" and lot == "game lot"
	say("protect", ok, "cell rule: can_place '%s', place '%s', the next cell '%s'; area rule: land '%s', paint '%s'; a circle over an area: '%s'" % [
		cell_why, place_why, free_why, river, river_paint, lot])
