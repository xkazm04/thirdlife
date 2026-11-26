extends RefCounted
## SEAM M5 (spark world-sandbox): the 754 cases `seam.v3` and `seam.m5`, run by seam_case.gd (which prints them).
## Headless, no landscape, no tree needed. Each case returns [name, ok, detail].
##   v3   tl.build/3 and the per-op-kind versions (build_file.gd KEY_V, OP_V, mark_v): a v1 and a v2 Home written by
##        main's writer (`main_text`, build_file.gd `text_of` as of e66eb94e) load and re-save byte for byte; water
##        content (a test water layer, TestWater) writes v3 with its key after the v2 keys and loads back; build.json is
##        raised to v2 before the first land op and to v3 before the first flood op is journaled, its content unchanged,
##        and the journal replays over it; a save without water writes v2 again; a reader whose max is 2 refuses the v3
##        file and leaves it as it was; a v2 file with a water key is refused
##   m5   the M5 interface (BUILD.md "Layers"): `offers` and command_ask.gd `ops_now`, `expand_input` (a pour), the
##        ghost per layer (`preview_nodes`), `water_runs`, plant_scatter.gd, the stub layers' files. A stub is held to
##        its stub answers, a built layer only to the shapes of its answers (its lane's block holds the rest)

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const BuildFile := preload("res://kernel/world/build/build_file.gd")
const Blocks := preload("res://kernel/world/build/blocks.gd")
const Lists := preload("res://kernel/world/build/seam_lists.gd")
const CommandAsk := preload("res://kernel/world/build/command_ask.gd")
const PlantScatter := preload("res://kernel/world/build/plant_scatter.gd")
const SEED := 11

var tmp := ""


## A water layer made applicable for this case only (M5's stub stays a stub): a level per 3 m cell, saved as `water`.
class TestWater extends RefCounted:
	const WaterLayer := preload("res://kernel/world/build/water_layer.gd")
	var id := "water"
	var lv := {}                         # Vector2i -> cm
	var check: RefCounted = WaterLayer.new({})
	func ops() -> PackedStringArray: return PackedStringArray(["flood", "drain"])
	func malformed(op: Variant, strict := false) -> String: return check.malformed(op, strict)
	func can_apply(_op: Dictionary) -> String: return ""
	func fits(_rec: Dictionary) -> String: return ""
	func raw(op: Dictionary) -> Dictionary: return check.raw(op)
	func invert(rec: Dictionary) -> Dictionary: return check.invert(rec)
	func apply(rec: Dictionary) -> void:
		for e: Array in rec.cells:
			if rec.op == "drain": lv.erase(Vector2i(int(e[0]), int(e[1])))
			else: lv[Vector2i(int(e[0]), int(e[1]))] = int(e[2])
	func save_part() -> Dictionary:
		if lv.is_empty(): return {}
		var pairs := PackedInt32Array()
		var keys: Array = lv.keys()
		keys.sort()
		for k: Vector2i in keys: pairs.append_array([k.x + 32 * k.y, lv[k]])
		return {"water": {"0,0": Marshalls.raw_to_base64(pairs.to_byte_array())}}
	func load_part(doc: Dictionary) -> String:
		var pairs := Marshalls.base64_to_raw(str((doc.get("water", {}) as Dictionary).get("0,0", ""))).to_int32_array()
		for i: int in range(0, pairs.size(), 2): lv[Vector2i(pairs[i] % 32, pairs[i] / 32)] = pairs[i + 1]
		return ""
	func clear() -> void: lv.clear()
	func size() -> int: return lv.size()
	func content_hash() -> String: return str(lv)
	func dirty_regions(_rec: Dictionary) -> Array: return []
	func step(_b: int) -> int: return 0
	func pending() -> int: return 0
	func copy() -> RefCounted:
		var c := TestWater.new()
		c.lv = lv.duplicate()
		return c
	func free_all() -> void: pass


func _init(dir: String) -> void:
	tmp = dir


## main's writer of tl.build/1 and /2 (build_file.gd `text_of` at e66eb94e), to hold the bytes to it.
static func main_text(layers: Array, home_seed: int, rev: int) -> String:
	var parts := {}
	for l: RefCounted in layers:
		var p: Dictionary = l.save_part()
		for k: Variant in p:
			parts[k] = p[k]
	var v := 1
	for k: Variant in parts:
		if not ["v", "seed", "rev", "chunks"].has(k):
			v = 2
	var text := "{\"v\":%d,\"seed\":%d,\"rev\":%d" % [v, home_seed, rev]
	for k: String in ["chunks", "land", "paint", "pieces"]:
		if parts.has(k):
			text += ",%s:%s" % [JSON.stringify(k), JSON.stringify(parts[k], "", false)]
	return text + "}\n"


static func _write(d: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(d)
	var f := FileAccess.open(d.path_join("build.json"), FileAccess.WRITE)
	f.store_string(text)
	f.close()


static func _text(d: String) -> String:
	return FileAccess.get_file_as_string(d.path_join("build.json"))


static func _lines(d: String) -> int:
	return FileAccess.get_file_as_string(d.path_join("edits.jsonl")).strip_edges().split("\n", false).size()


## `text` as main wrote it into `name`, loaded by this exe and saved into `name`-again: "" or what differs.
func _resave(name: String, text: String, want_v: int) -> String:
	var d := tmp.path_join(name)
	_write(d, text)
	var c: RefCounted = HomeBuild.new(null, null, {"seed": SEED})
	var r: Dictionary = c.load(d)
	if not r.ok or int(r.v) != want_v:
		return "%s: load %s" % [name, str(r)]
	var again := tmp.path_join(name + "-again")
	var why: String = c.save(again)
	if why != "" or _text(again) != text:
		return "%s: re-saved %s, %d bytes, want the same %d bytes (%s...)" % [name, why, _text(again).length(), text.length(), _text(again).substr(0, 60)]
	return ""


func v3() -> Array:
	var bad := []
	# a v1 and a v2 Home as main wrote them
	var b: RefCounted = HomeBuild.new(null, null, {"seed": SEED})
	for c: Vector3i in [Vector3i(101, 2, 3), Vector3i(-200, 5, 7), Vector3i(100, -16, -100)]:
		b.place(c, Blocks.code(Blocks.CUBE, 2))
	var t1 := main_text(b.layers, SEED, 4)
	var why := _resave("main-v1", t1, 1)
	if why != "":
		bad.append(why)
	var land := str(b.apply({"op": "land", "verts": [[3, 4, 0, 250], [5, 6, 0, -40]]}).reason)
	var paint := str(b.apply({"op": "paint", "cells": [[7, 8, "valley", "sand"]]}).reason)
	var t2 := main_text(b.layers, SEED, 5)
	if land != "" or paint != "" or not t2.begins_with("{\"v\":2,"):
		bad.append("the land layer took land '%s', paint '%s'; main's text %s" % [land, paint, t2.substr(0, 20)])
	why = _resave("main-v2", t2, 2)
	if why != "":
		bad.append(why)
	var own: String = BuildFile.text_of(b.layers, SEED, 5).text
	if own != t2:
		bad.append("this exe's writer differs from main's for v2 content")
	# water content: v3, the key after the v2 keys, loaded back; refused by a reader whose max is 2
	var tw := TestWater.new()
	b.register(tw)
	b.apply({"op": "flood", "cells": [[3, 4, 300], [2, 1, 120]]})
	var d3 := tmp.path_join("v3")
	b.save(d3)
	var t3 := _text(d3)
	var order_ok := t3.begins_with("{\"v\":3,\"seed\":11,\"rev\":") and t3.find("\"chunks\":") < t3.find("\"land\":") \
		and t3.find("\"paint\":") < t3.find("\"water\":") and t3.find("\"water\":") > 0
	if not order_ok:
		bad.append("v3 head or key order: %s" % t3.substr(0, 60))
	var c3: RefCounted = HomeBuild.new(null, null, {"seed": SEED})
	var tw3 := TestWater.new()
	c3.register(tw3)
	var r3: Dictionary = c3.load(d3)
	if not r3.ok or int(r3.v) != 3 or tw3.lv != tw.lv or c3.layer("land").content_hash() != b.layer("land").content_hash():
		bad.append("v3 load: %s, water %s want %s" % [str(r3), str(tw3.lv), str(tw.lv)])
	var c4: RefCounted = HomeBuild.new(null, null, {"seed": SEED})
	var old: Dictionary = BuildFile.load_into(d3, c4.layers, c4.edits, SEED, 2)
	var left := _text(d3) == t3
	if old.ok or not str(old.reason).contains("tl.build/3 is newer than this exe reads (1..2)") or not left:
		bad.append("a reader of max 2: %s, file left as it was %s" % [str(old.reason), left])
	var stubbed: Dictionary = HomeBuild.new(null, null, {"seed": SEED}).load(d3)   # the water stub: content it cannot keep
	var d5 := tmp.path_join("v2water")
	_write(d5, "{\"v\":2,\"seed\":11,\"rev\":1,\"chunks\":{},\"water\":{}}\n")
	var r5: Dictionary = HomeBuild.new(null, null, {"seed": SEED}).load(d5)
	if r5.ok or not str(r5.reason).ends_with("unknown key 'water'"):
		bad.append("a v2 file with water: %s" % str(r5.reason))
	# build.json raised before the first op of a higher version is journaled
	var marks := _marks()
	bad.append_array(marks.bad)
	return ["v3", bad.is_empty(), "main's v1 %d B and v2 %d B re-saved byte for byte; water -> %s... loaded back v%d (%d cells); max-2 reader: '%s', file kept %s; the water stub reads it as '%s'; v2 + water key: '%s'; %s%s" % [
		t1.length(), t2.length(), t3.substr(0, 8), int(r3.v), tw3.lv.size(), str(old.reason).get_slice(": ", 1), left,
		str(stubbed.reason).get_file(), str(r5.reason).get_file(), marks.detail, "" if bad.is_empty() else "; BAD " + "; ".join(bad)]]


## The marks: from v1 a land op raises build.json to v2 and a flood op to v3 (one hook call each, before its line);
## straight from v1 a flood op raises it to v3 in one call; undo and a save without water write v2 again.
func _marks() -> Dictionary:
	var bad := []
	var d := tmp.path_join("mark3")
	var b: RefCounted = HomeBuild.new(null, null, {"seed": SEED})
	b.place(Vector3i(104, 4, 4), Blocks.code(Blocks.CUBE, 1))
	b.save(d)
	var before := _text(d)
	b.register(TestWater.new())
	var seen := []
	var hook: Callable = b.edits.before_journal
	b.edits.before_journal = func(rec: Dictionary) -> String:
		var why := str(hook.call(rec))
		seen.append([_text(d).substr(0, 7), _lines(d), rec.op])
		return why
	var r1 := str(b.apply({"op": "land", "verts": [[1, 1, 0, 100]]}).reason)
	var r2 := str(b.apply({"op": "flood", "cells": [[1, 1, 200]]}).reason)
	b.apply({"op": "flood", "cells": [[2, 1, 200]]})
	var after := _text(d)
	var want_seen := [["{\"v\":2,", 0, "land"], ["{\"v\":3,", 1, "flood"]]
	if r1 != "" or r2 != "" or str(seen) != str(want_seen):
		bad.append("land '%s', flood '%s'; hook saw %s, want %s" % [r1, r2, str(seen), str(want_seen)])
	if after != "{\"v\":3," + before.substr(7):
		bad.append("build.json content changed: %s" % after.substr(0, 40))
	var c: RefCounted = HomeBuild.new(null, null, {"seed": SEED})
	var tw := TestWater.new()
	c.register(tw)
	var r: Dictionary = c.load(d)
	if not r.ok or int(r.v) != 3 or int(r.replayed) != 3 or tw.lv.size() != 2:
		bad.append("replay over the v3 file: %s, %d water cells" % [str(r), tw.lv.size()])
	b.undo()
	b.undo()
	b.edits.before_journal = hook
	b.save(d)
	var v2_again := _text(d).begins_with("{\"v\":2,")
	if not v2_again:
		bad.append("a save with land and no water wrote %s" % _text(d).substr(0, 8))
	var d1 := tmp.path_join("mark3-from-v1")
	var e: RefCounted = HomeBuild.new(null, null, {"seed": SEED})
	e.place(Vector3i(104, 4, 4), Blocks.code(Blocks.CUBE, 1))
	e.save(d1)
	e.register(TestWater.new())
	var calls := [0]
	var hook1: Callable = e.edits.before_journal
	e.edits.before_journal = func(rec: Dictionary) -> String:
		calls[0] += 1
		return str(hook1.call(rec))
	e.apply({"op": "flood", "cells": [[1, 1, 200]]})
	var straight := _text(d1).begins_with("{\"v\":3,")
	if int(calls[0]) != 1 or not straight:
		bad.append("from v1 a flood op: %d hook call(s), build.json %s" % [int(calls[0]), _text(d1).substr(0, 8)])
	return {"bad": bad, "detail": "marks seen %s, content unchanged %s, %d lines replayed over v3; undo + save -> v2 %s; v1 + flood -> v3 in %d call" % [
		str(seen.map(func(x: Array) -> String: return "%s before %s line %d" % [x[0], x[2], int(x[1]) + 1])), after == "{\"v\":3," + before.substr(7),
		int(r.replayed), v2_again, int(calls[0])]}


func m5() -> Array:
	var bad := []
	var b: RefCounted = HomeBuild.new(null, null, {"seed": SEED})
	# offers and ops_now
	var offered := []
	for l: RefCounted in b.layers:
		var o: Array = l.call("offers") if l.has_method("offers") else []
		if Lists.is_stub_layer(l) and not o.is_empty():
			bad.append("stub %s offers %s" % [l.get("id"), str(o)])
		for k: Variant in o:
			if not offered.has(k):
				offered.append(k)
	var now: Array = CommandAsk.ops_now(b, Vector3i.ZERO)
	if now != offered or now.slice(0, 2) != ["place", "remove"] or not now.all(func(k: String) -> bool: return Lists.ask_ops().has(k)):
		bad.append("ops_now %s, offers %s" % [str(now), str(offered)])
	# expand_input: a pour goes to the water layer, every other op passes through
	var place := {"op": "place", "at": [0, 5, 0], "shape": 1, "mat": 1, "rot": 0, "author": "llm"}
	var ex: Dictionary = b.expand_input([{"op": "pour", "at": [1, 0, 1], "author": "llm"}, place])
	var water_stub := Lists.is_stub_layer(b.layer("water"))
	if water_stub and (str(ex.refused) != str([[0, "not built yet: water"]]) or ex.ops != [place]):
		bad.append("expand_input with the water stub: %s" % str(ex))
	if not water_stub and ((ex.ops as Array).any(func(o: Dictionary) -> bool: return o.op == "pour") or (ex.ops as Array).find(place) < 0):
		bad.append("expand_input left a pour or lost the place: %s" % str(ex))
	# the ghost per layer
	var ops := [place.duplicate(), {"op": "place", "at": [1, 5, 0], "shape": 1, "mat": 2, "rot": 0}]
	for kind: String in Lists.M5_EXAMPLES:
		ops.append((Lists.M5_EXAMPLES[kind] as Dictionary).duplicate(true))
	var r: Dictionary = b.preview(ops)
	var nodes: Array = b.preview_nodes(r)
	var shown: Array = nodes.map(func(n: Node3D) -> String: return str(n.get_meta(&"tl_layer", "")))
	var tris := 0
	for n: Node3D in nodes:
		if n.get_meta(&"tl_layer", "") == "blocks":
			tris = int(n.call("stats").tris)
	var stub_ghost: Array = shown.filter(func(id: String) -> bool: return Lists.is_stub_layer(b.layer(id)) and id != "blocks")
	var skipped: Array = b.preview_nodes(r, ["blocks"]).map(func(n: Node3D) -> String: return str(n.get_meta(&"tl_layer", "")))
	if shown.is_empty() or shown[0] != "blocks" or tris <= 0 or not stub_ghost.is_empty() or skipped.has("blocks") or b.blocks.total != 0:
		bad.append("ghosts %s (blocks %d tris), skip blocks %s, stub ghosts %s, Home blocks %d" % [str(shown), tris, str(skipped), str(stub_ghost), b.blocks.total])
	for n: Node3D in nodes:
		n.free()
	# water_runs, the scatter
	var runs: Array = CommandAsk.water_of(b, Vector3i(-16, -4, -16), Vector3i(15, 19, 15))
	var runs_ok: bool = runs.all(func(w: Variant) -> bool: return w is Dictionary and (w as Dictionary).keys() == ["y", "runs"])
	if (water_stub and not runs.is_empty()) or not runs_ok:
		bad.append("water_runs %s" % str(runs))
	var sc: Array = PlantScatter.scatter(b, Vector3(10, 0, 10), 6.0, "tree", 4.0, 7)
	var sc_ok: bool = sc == PlantScatter.scatter(b, Vector3(10, 0, 10), 6.0, "tree", 4.0, 7) and \
		sc.all(func(o: Variant) -> bool: return o is Dictionary and o.get("op") == "put" and str(o.get("part")) in PlantScatter.KINDS)
	if not sc_ok:
		bad.append("scatter %s" % str(sc).left(120))
	# the stub layers' files
	var files := []
	for id: String in ["water", "paths", "plants"]:
		var l: RefCounted = b.layer(id)
		if not Lists.is_stub_layer(l):
			files.append("%s built" % id)
			continue
		var empty := str(l.load_part({"chunks": {}, id: {} if id != "paths" else []}))
		var full := str(l.load_part({"chunks": {}, id: {"0,0": "AAAA"} if id != "paths" else [{"id": 1}]}))
		if not l.save_part().is_empty() or empty != "" or not full.begins_with("%s: not built yet" % id):
			bad.append("%s stub: saves %s, an empty key '%s', content '%s'" % [id, str(l.save_part()), empty, full])
		files.append("%s: '%s'" % [id, full])
	return ["m5", bad.is_empty(), "ops_now %s; pour -> %s; ghosts %s (blocks %d tris; skip blocks: %s); water_runs %d; scatter %d puts; files %s%s" % [
		str(now), str(ex.refused) if water_stub else "%d ops" % (ex.ops as Array).size(), str(shown), tris, str(skipped), runs.size(), sc.size(),
		", ".join(files), "" if bad.is_empty() else "; BAD " + "; ".join(bad)]]
