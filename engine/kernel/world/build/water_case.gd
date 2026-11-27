extends SceneTree
## M5 lane W (spark world-sandbox): still water in the Home, headless (engine/tools/selftest.d/761-home-water.sh).
## Flat ground (a builder without a valley: the ground's own height is 0) holds the hand-computed fills; the landscape
## of res://boot/village.json (the Home grown by home/hook.gd, build mode mounted) holds the river, the protected areas,
## the tool as a person drives it, the drawing and the scatter. Frames, not wall clock (wall clock is measured, never
## decided on). Prints `HOME water.<case> ok|fail <detail>`, then `HOME water ok` (or fail) and `HOME DONE`.
##   water.hollow   a 5 x 5 vertex hollow 2 m deep in flat ground: spill 0, level -10 cm, the 36 cells i, j -1..4
##   water.notch    the same hollow walled at +1 m with one notch vertex at +30 cm: spill 30, level 20, 36 cells
##   water.refuse   an open slope: "no hollow here"; a bowl of ~3,000 cells: "spills: too big"; flat ground: "no hollow";
##                  a lowered level (the wheel) gives the same cells 50 cm lower; water there already
##   water.undo     a pour is one batch: undo leaves no water, redo brings it back; drain removes the body; undo of it
##   water.files    save -> tl.build/3 with a `water` key after the v2 keys -> load: the same levels -> save: same bytes;
##                  the journal replays a pour
##   water.input    `pour` through home_build.gd `expand_input` is one flood op with the fill's cells; a bad pour and a
##                  pour over water are refused; `water_runs` has the ask's shape and the wet columns; the ghost
##   water.river    (the valley) a cell in the land's river band and one the river's ribbon reaches below the river's
##                  level refuse "spills into the river"; a game lot and the village "spills: ..."; how much ground the
##                  ribbon reaches beyond the land's 71 m band that a dig can take below the river (measured)
##   water.tool     (the valley) B, T to the water tool, the pointer in a dug hollow: the ghost and its count, the wheel
##                  lowers the level, LMB pours (one batch), the mesh in the still-water look (UV.x -1, no shadow, no
##                  body), the cursor ray reaches the bed through the water, Ctrl+Z undoes it, 2 + LMB drains
##   water.scatter  (the valley) a tree in a shallow dig (moved by the land, not hidden) is hidden by the water poured
##                  over it and back, moved as the land has it, when drained
##   water.cost     fill and mesh times of a pour, triangles

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const WaterFill := preload("res://kernel/world/build/water_fill.gd")
const More := preload("res://kernel/world/build/water_case_valley.gd")
const TMP := "user://tl_water_case"
const SEED := 11

var ok_all := true


func _initialize() -> void:
	call_deferred("run")


func say(case_name: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME water.%s %s %s" % [case_name, "ok" if ok else "fail", detail])


func run() -> void:
	TLStyle.set_headless(false)
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP))
	hollow_case()
	notch_case()
	refuse_case()
	undo_case()
	files_case()
	input_case()
	var m: RefCounted = More.new()
	await m.run(self)
	finish()


func finish() -> void:
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	print("HOME water %s" % ("ok" if ok_all else "fail"))
	print("HOME DONE")
	quit(0)


func flat() -> RefCounted:
	return HomeBuild.new(null, null, {"seed": SEED})


## Every vertex [i0..i1] x [j0..j1] set to (i, j) -> cm by `f` (from the flat ground's 0), one land op.
static func shape(b: RefCounted, i0: int, i1: int, j0: int, j1: int, f: Callable) -> String:
	var verts := []
	for j: int in range(j0, j1 + 1):
		for i: int in range(i0, i1 + 1):
			var cm := int(f.call(i, j))
			if cm != 0:
				verts.append([i, j, int(b.layer("land").cm_at(Vector2i(i, j))), cm])
	return str(b.apply({"op": "land", "verts": verts}).reason)


## The 5 x 5 vertices i, j in o..o+4 at -2 m.
static func hollow(b: RefCounted, o: Vector2i) -> String:
	return shape(b, o.x, o.x + 4, o.y, o.y + 4, func(_i: int, _j: int) -> int: return -200)


## The cells with a corner among the 5 x 5 vertices: i, j in o-1..o+4 (36).
static func cells_round(o: Vector2i) -> Array:
	var out := []
	for j: int in range(o.y - 1, o.y + 5):
		for i: int in range(o.x - 1, o.x + 5):
			out.append(Vector2i(i, j))
	return out


# ------------------------------------------------------------------ cases on flat ground
func hollow_case() -> void:
	var b := flat()
	var w: RefCounted = b.layer("water")
	var why := hollow(b, Vector2i(0, 0))
	var f: Dictionary = w.plan(Vector2i(2, 2))
	var want := cells_round(Vector2i(0, 0))
	var side: Dictionary = w.plan(Vector2i(4, 4))        # a corner cell of the hollow (its low corner is the hollow's)
	var ok: bool = why == "" and str(f.reason) == "" and int(f.spill) == 0 and int(f.level) == -10 and f.cells == want \
		and side.cells == f.cells and int(side.level) == -10
	say("hollow", ok, "a 5 x 5 vertex hollow at -2 m in flat ground: spill %d cm, level %d cm (want 0, -10), %d cells %s the 36 of i, j -1..4; %d wet vertices, %d explored; from a corner cell the same %s; %d us%s" % [
		int(f.spill), int(f.level), (f.cells as Array).size(), "=" if f.cells == want else "!=", int(f.verts), int(f.explored),
		side.cells == f.cells, int(f.usec), "" if ok else "; BAD land '%s', reason '%s'" % [why, f.reason]])


func notch_case() -> void:
	var b := flat()
	var w: RefCounted = b.layer("water")
	var o := Vector2i(40, 0)
	var why := hollow(b, o)
	# the wall: the 7 x 7 ring of vertices round the hollow at +1 m, one notch vertex (o + (2, -1)) at +30 cm
	why += shape(b, o.x - 1, o.x + 5, o.y - 1, o.y + 5, func(i: int, j: int) -> int:
		if i > o.x - 1 and i < o.x + 5 and j > o.y - 1 and j < o.y + 5:
			return 0
		return 30 if Vector2i(i, j) == o + Vector2i(2, -1) else 100)
	var f: Dictionary = w.plan(o + Vector2i(2, 2))
	var want := cells_round(o)
	var ok: bool = why == "" and str(f.reason) == "" and int(f.spill) == 30 and int(f.level) == 20 and f.cells == want
	var unnotched := flat()
	hollow(unnotched, o)
	shape(unnotched, o.x - 1, o.x + 5, o.y - 1, o.y + 5, func(i: int, j: int) -> int:
		return 0 if (i > o.x - 1 and i < o.x + 5 and j > o.y - 1 and j < o.y + 5) else 100)
	var g: Dictionary = unnotched.layer("water").plan(o + Vector2i(2, 2))
	ok = ok and int(g.spill) == 100 and int(g.level) == 90 and (g.cells as Array).size() == 36
	say("notch", ok, "the hollow walled at +1 m with a notch vertex at +30 cm: spill %d, level %d cm (want 30, 20), %d cells %s the hollow's 36; without the notch spill %d, level %d, %d cells%s" % [
		int(f.spill), int(f.level), (f.cells as Array).size(), "=" if f.cells == want else "!=", int(g.spill), int(g.level), (g.cells as Array).size(),
		"" if ok else "; BAD land '%s', reason '%s'" % [why, f.reason]])


func refuse_case() -> void:
	var bad := []
	var got := {}
	# an open slope: 0 at i = 70 rising 50 cm a vertex to i = 90, 21 vertices deep
	var b := flat()
	var w: RefCounted = b.layer("water")
	shape(b, 70, 90, -10, 10, func(i: int, _j: int) -> int: return 50 * (i - 70))
	got["slope"] = str(w.plan(Vector2i(80, 0)).reason)
	got["flat"] = str(w.plan(Vector2i(-300, -300)).reason)
	# a bowl of radius 31 vertices: -3 m in the middle, 0 at its rim (about 3,000 cells under 0)
	var bowl := Vector2i(200, 0)
	var r := 31.0
	shape(b, bowl.x - 31, bowl.x + 31, bowl.y - 31, bowl.y + 31, func(i: int, j: int) -> int:
		var d := Vector2(i - bowl.x, j - bowl.y).length() / r
		return roundi(-300.0 * (1.0 - d * d)) if d < 1.0 else 0)
	var under := 0
	for j: int in range(bowl.y - 32, bowl.y + 32):
		for i: int in range(bowl.x - 32, bowl.x + 32):
			var lo := 0
			for q: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				lo = mini(lo, int(b.layer("land").cm_at(Vector2i(i, j) + q)))
			under += 1 if lo < -10 else 0
	var big: Dictionary = w.plan(bowl)
	got["bowl"] = str(big.reason)
	# the wheel: a level 50 cm lower in the hollow
	hollow(b, Vector2i(0, 0))
	var full: Dictionary = w.plan(Vector2i(2, 2))
	var low: Dictionary = w.plan(Vector2i(2, 2), 50)
	var too_low: Dictionary = w.plan(Vector2i(2, 2), 400)
	got["too low"] = str(too_low.reason)
	# water there already
	b.apply(w.pour_ops(Vector2i(2, 2)).ops)
	got["again"] = str(w.pour_ops(Vector2i(2, 2)).reason)
	got["flood wet"] = str(b.apply({"op": "flood", "cells": [[1, 1, 0]]}).reason)
	var relevel: Dictionary = w.pour_ops(Vector2i(2, 2), 50)
	var want := {"slope": WaterFill.NO_HOLLOW, "flat": WaterFill.NO_HOLLOW, "bowl": WaterFill.TOO_BIG,
		"too low": "no water at that level", "again": "water there already", "flood wet": "water there already at [1, 1]"}
	for k: String in want:
		if not str(got[k]).begins_with(want[k]):
			bad.append("%s: '%s'" % [k, got[k]])
	if int(low.level) != int(full.level) - 50 or low.cells != full.cells:
		bad.append("lowered 50: level %d, %d cells (full %d, %d)" % [int(low.level), (low.cells as Array).size(), int(full.level), (full.cells as Array).size()])
	var kinds: Array = (relevel.ops as Array).map(func(o: Dictionary) -> String: return o.op)
	if kinds != ["drain", "flood"] or under < 2900:
		bad.append("re-level ops %s, bowl cells under -10 cm %d" % [str(kinds), under])
	var parts := []
	for k: String in got:
		parts.append("%s '%s'" % [k, got[k]])
	say("refuse", bad.is_empty(), "%s; the bowl has %d cells under -10 cm (explored %d vertices); lowered 50 cm: level %d, same %d cells; a pour over the pond at 50 cm lower: %s in one batch%s" % [
		"; ".join(parts), under, int(big.explored), int(low.level), (low.cells as Array).size(), str(kinds), "" if bad.is_empty() else "; BAD " + "; ".join(bad)])


func undo_case() -> void:
	var b := flat()
	var w: RefCounted = b.layer("water")
	hollow(b, Vector2i(0, 0))
	var n0: int = b.edits.history.size()
	var r: Dictionary = b.apply(w.pour_ops(Vector2i(2, 2)).ops)
	var batches: int = b.edits.history.size() - n0
	var poured: int = w.size()
	var undone: int = b.undo()
	var after_undo: int = w.size()
	b.redo()
	var redone: int = w.size()
	var d: Dictionary = w.drain_op(Vector2i(1, 1))
	b.apply(d)
	var drained: int = w.size()
	var land_left: int = b.layer("land").size()
	b.undo()
	var back: int = w.size()
	var ok: bool = bool(r.ok) and batches == 1 and poured == 36 and undone == 1 and after_undo == 0 and redone == 36 \
		and (d.cells as Array).size() == 36 and drained == 0 and back == 36 and land_left == 25
	say("undo", ok, "pour: %d cells in %d batch; undo (%d op) -> %d cells, redo -> %d; drain of the body at [1, 1]: %d cells -> %d left (the land's %d vertices stay); undo -> %d%s" % [
		poured, batches, undone, after_undo, redone, (d.cells as Array).size(), drained, land_left, back, "" if ok else "; BAD " + str(r)])


func files_case() -> void:
	var bad := []
	var d := TMP.path_join("files")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))
	var b := flat()
	b.load(d)
	var w: RefCounted = b.layer("water")
	hollow(b, Vector2i(0, 0))
	hollow(b, Vector2i(-40, 37))                    # a second pond in another chunk (negative i, j)
	b.apply(w.pour_ops(Vector2i(2, 2)).ops)
	b.apply(w.pour_ops(Vector2i(-38, 39), 30).ops)
	var journal := FileAccess.get_file_as_string(ProjectSettings.globalize_path(d).path_join("edits.jsonl"))
	var replay := flat()
	var rr: Dictionary = replay.load(d)                # build.json raised to v3 before the first flood was journaled
	var replayed_same: bool = replay.layer("water").content_hash() == w.content_hash()
	var why := str(b.save(d))
	var text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(d).path_join("build.json"))
	var c := flat()
	var r: Dictionary = c.load(d)
	var cw: RefCounted = c.layer("water")
	var same: bool = cw.store.levels == w.store.levels
	var d2 := TMP.path_join("files2")
	c.save(d2)
	var text2 := FileAccess.get_file_as_string(ProjectSettings.globalize_path(d2).path_join("build.json"))
	var order_ok := text.begins_with("{\"v\":3,") and text.find("\"land\":") < text.find("\"water\":{\"-1,-1\":") and text.rfind("\"-2,1\":") > text.find("\"water\":")
	if why != "" or not order_ok or not bool(r.ok) or int(r.v) != 3 or not same or text2 != text:
		bad.append("save '%s', v3 order %s, load %s, same %s, bytes %s" % [why, order_ok, str(r), same, text2 == text])
	if not bool(rr.ok) or int(rr.replayed) < 4 or not replayed_same or journal.find("\"op\":\"flood\"") < 0:
		bad.append("replay %s, same %s" % [str(rr), replayed_same])
	var c2 := flat()
	c2.load(d2)
	var resaved: bool = c2.save(d2) == "" and FileAccess.get_file_as_string(ProjectSettings.globalize_path(d2).path_join("build.json")) == text2
	if not resaved:
		bad.append("load -> save changed the bytes")
	say("files", bad.is_empty(), "two ponds (%d cells) -> %s... (%d B, water after land, chunks -1,-1 .. 0,0 and -2,1); loaded back v%d, levels equal %s; save of the load: same bytes %s; the journal (%d lines) replays over the v3 build.json: %d ops, same water %s%s" % [
		w.size(), text.substr(0, 24), text.length(), int(r.v), same, resaved, journal.count("\n"), int(rr.replayed), replayed_same,
		"" if bad.is_empty() else "; BAD " + "; ".join(bad)])


func input_case() -> void:
	var bad := []
	var b := flat()
	var w: RefCounted = b.layer("water")
	hollow(b, Vector2i(0, 0))
	var f: Dictionary = w.plan(Vector2i(2, 2))
	var ex: Dictionary = b.expand_input([{"op": "pour", "at": [7, 0, 7], "author": "llm"}, {"op": "pour", "at": [7, 0], "author": "llm"},
		{"op": "pour", "at": [7, 0, 7], "level": 3}, {"op": "pour", "at": [-900, 0, -900]}])
	var ops: Array = ex.ops
	var flood_ok: bool = ops.size() == 1 and ops[0].op == "flood" and ops[0].get("author") == "llm" and (ops[0].cells as Array).size() == 36
	if flood_ok:
		for k: int in 36:
			flood_ok = flood_ok and ops[0].cells[k] == [f.cells[k].x, f.cells[k].y, int(f.level)]
	var reasons: Array = (ex.refused as Array).map(func(e: Array) -> String: return "%d '%s'" % [e[0], e[1]])
	if not flood_ok or reasons != ["1 'at must be [x, y, z]'", "2 'unknown key 'level''", "3 '%s'" % WaterFill.NO_HOLLOW]:
		bad.append("expand %s / refused %s" % [str(ops).left(80), str(reasons)])
	# the ghost of a dry run of that flood
	var pr: Dictionary = b.preview(ops)
	var ghosts: Array = b.preview_nodes(pr, ["blocks"])
	var wg: Array = ghosts.filter(func(n: Node3D) -> bool: return n.get_meta(&"tl_layer", "") == "water")
	var ghost_cells: int = int((wg[0] as Node3D).get_child(0).get_meta(&"tl_cells", 0)) if not wg.is_empty() else 0
	for n: Node3D in ghosts:
		n.free()
	if ghost_cells != 36 or w.size() != 0:
		bad.append("ghost %d cells, water %d" % [ghost_cells, w.size()])
	# applied, the ask's water, a pour over water
	b.apply(ops)
	var over: Dictionary = b.expand_input([{"op": "pour", "at": [7, 0, 7]}])
	if str(over.refused) != str([[0, "water there already: drain it first"]]):
		bad.append("pour over water: %s" % str(over))
	var runs: Array = w.water_runs(Vector3i(-8, -8, -8), Vector3i(20, 8, 20))
	var shape_ok: bool = runs.size() == 1 and (runs[0] as Dictionary).keys() == ["y", "runs"] and int(runs[0].y) == -1
	var cols := 0
	var inside := true
	var last := [-(1 << 30), -(1 << 30)]
	if shape_ok:
		for run: Array in runs[0].runs:
			cols += int(run[2]) - int(run[1]) + 1
			inside = inside and run.size() == 3 and int(run[1]) >= -3 and int(run[2]) <= 14 and int(run[0]) >= -3 and int(run[0]) <= 14
			inside = inside and (int(run[0]) > int(last[0]) or (int(run[0]) == int(last[0]) and int(run[1]) > int(last[1]) + 1))
			last = run
	var brute := 0
	for z: int in range(-8, 21):
		for x: int in range(-8, 21):
			var c := Vector2i(floori(x / 3.0), floori(z / 3.0))
			brute += 1 if w.store.has(c) and b.layer("land").height_at(x + 0.5, z + 0.5) < -0.10 else 0
	var none: Array = w.water_runs(Vector3i(100, -8, 100), Vector3i(120, 8, 120))
	var reg: Dictionary = b.read_region(Vector3i(0, -4, 0), Vector3i(5, 4, 2))     # PATCHES-C C3: the drain's level, measured
	if reg.get("water_cells") != [[0, 0, -10], [1, 0, -10]] or b.read_region(Vector3i(100, -4, 100), Vector3i(110, 4, 110)).has("water_cells"):
		bad.append("read_region water_cells %s" % str(reg.get("water_cells")))
	# M5 integration: an answer that digs, then pours: the pour fills the dug land (planned on a scratch copy), the
	# Home is untouched until the answer is applied
	var b2 := flat()
	var dig := []
	for j: int in range(0, 5):
		for i: int in range(0, 5):
			dig.append([i, j, -200])
	var both: Dictionary = b2.expand_input([{"op": "land", "verts": dig}, {"op": "pour", "at": [7, 0, 7]}])
	var both_ops: Array = both.ops
	if not (both.refused as Array).is_empty() or both_ops.size() != 2 or str(both_ops[1].get("op")) != "flood" 			or (both_ops[1].cells as Array).size() != 36 or int(b2.layer("land").cm_at(Vector2i(2, 2))) != 0:
		bad.append("dig + pour %s / refused %s" % [str(both_ops).left(80), str(both.refused)])
	if not shape_ok or not inside or cols != brute or cols < 144 or not none.is_empty():
		bad.append("runs %s (%d columns, brute %d), inside %s, far %s" % [str(runs).left(100), cols, brute, inside, str(none)])
	say("input", bad.is_empty(), "pour at [7, 0, 7] -> 1 flood of %d cells at %d cm, author llm, the fill's cells %s; refused %s; the ghost (preview_nodes) %d holo cells, the Home untouched; pour over the pond: '%s'; read_region water_cells %s; water_runs y %s (floori(-10 / 100.0)), %d runs, %d wet columns (every column of the 12 x 12 m floor and the shallows where the bed is under -10 cm)%s" % [
		(ops[0].cells as Array).size() if not ops.is_empty() else 0, int(f.level), flood_ok, str(reasons), ghost_cells,
		str(over.refused[0][1]) if not (over.refused as Array).is_empty() else "", str(reg.get("water_cells")), str(runs[0].y) if not runs.is_empty() else "-",
		(runs[0].runs as Array).size() if not runs.is_empty() else 0, cols, "" if bad.is_empty() else "; BAD " + "; ".join(bad)])
