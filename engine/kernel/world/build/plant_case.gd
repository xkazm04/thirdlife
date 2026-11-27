extends SceneTree
## M5 lane L (spark world-sandbox): plants in the Home, headless, in the landscape of res://boot/village.json with the
## plant tool driven as a person does (land_drive.gd). Prints `HOME plants.<case> ok|fail <detail>`, then
## `HOME plants ok` (or fail) and `HOME DONE`; engine/tools/selftest.d/763-home-plants.sh reads them.
##   plants.tool     T to the plant tool, 1 meadow: a held stroke is ONE plant op in one batch, every cell from its
##                   growth before to meadow; 0 clears; Ctrl+Z gives every cell back
##   plants.op       a plant op applied, refused where the land is (the village), not refused where the visitor stands
##                   (growth moves nothing); a wrong `from` refused; undo and redo
##   plants.uv       the land mesh's UV carries the density (meadow, flowers, tall grass: x tufts, -8 - y flowers) and
##                   the colour goes green; an open chunk without growth has UV (0, -8) and no green
##   plants.unedited the valley's own mesh is byte for byte the same after planting and undoing; a painted chunk's mesh
##                   is the same before and after growth elsewhere; planting then undoing closes the chunk it opened
##   plants.files    tl.build/3 with `plants`: save -> load -> save byte-identical, the growth back
##   plants.scatter  slots 4 trees and 5 bushes call plant_scatter.gd `scatter(...)` with the brush disc and apply what
##                   it gives as one batch (its stub gives none and the info line says so)
##   plants.ghost    a dry run of a plant op draws the plants layer's ghost (its green; red where cleared)

const Drive := preload("res://kernel/world/build/land_drive.gd")
const Probe := preload("res://kernel/world/build/land_probe.gd")
const PlantScatter := preload("res://kernel/world/build/plant_scatter.gd")
const TMP := "user://tl_plants_case"

var d: RefCounted = Drive.new()
var ok_all := true
var pl: RefCounted


func _initialize() -> void:
	call_deferred("run")


func say(name: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME plants.%s %s %s" % [name, "ok" if ok else "fail", detail])


func run() -> void:
	var why: String = d.setup(self, TMP)
	if why != "":
		say("tool", false, why)
		finish()
		return
	pl = d.b.layer("plants")
	await d.wait(3)
	await d.tap(KEY_B)
	await tool_case()
	op_case()
	uv_case()
	unedited_case()
	files_case()
	await scatter_case()
	ghost_case()
	finish()


func finish() -> void:
	Drive.CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	d.release()
	print("HOME plants %s" % ("ok" if ok_all else "fail"))
	print("HOME DONE")
	quit(0)


func tool_case() -> void:
	var site: Vector2 = d.free_site(Vector2(480, -480), 18.0)
	var ok_tool: bool = await d.to_tool("plant")
	await d.set_radius(3)
	await d.tap(KEY_1)
	var n0: int = d.b.edits.history.size()
	await d.stroke(site, 8, Vector2(9, 0))
	var ops: Array = d.last_ops()
	var grown: int = pl.size()
	var all_meadow := true
	for c: Vector2i in pl.cells:
		all_meadow = all_meadow and pl.growth_at(c) == "meadow"
	var rec_ok: bool = ops.size() == 1 and ops[0].op == "plant" and (ops[0].cells as Array).size() == grown and \
		(ops[0].cells as Array).all(func(e: Array) -> bool: return e[2] == "valley" and e[3] == "meadow")
	await d.tap(KEY_0)
	await d.stroke(site, 8, Vector2(9, 0))
	var cleared: int = pl.size()
	CaseUtil_ctrl(true)
	await d.tap(KEY_Z)
	var back: int = pl.size()
	await d.tap(KEY_Z)
	CaseUtil_ctrl(false)
	await d.wait(2)
	var batches: int = d.b.edits.history.size() - n0
	var ok: bool = ok_tool and grown >= 20 and all_meadow and rec_ok and cleared == 0 and back == grown and pl.size() == 0
	say("tool", ok, "plant tool %s, 1 = meadow: a held stroke grew %d cells, all meadow %s, one op of them from valley %s; 0 = clear: %d left; Ctrl+Z -> %d, Ctrl+Z -> %d; %d batches left in the history" % [
		ok_tool, grown, all_meadow, rec_ok, cleared, back, pl.size(), batches])
	await d.tap(KEY_1)


func CaseUtil_ctrl(down: bool) -> void:
	Drive.CaseUtil.key(KEY_CTRL, down)


func op_case() -> void:
	var site: Vector2 = d.free_site(Vector2(560, -480), 9.0)
	var c: Vector2i = d.vtx(site)
	var r1: Dictionary = d.b.apply({"op": "plant", "cells": [[c.x, c.y, "valley", "flowers"], [c.x + 1, c.y, "valley", "tall_grass"]], "author": "llm"})
	var g1: String = pl.growth_at(c)
	var wrong := str(d.b.apply({"op": "plant", "cells": [[c.x, c.y, "valley", "meadow"]]}).reason)
	var village := str(d.b.apply({"op": "plant", "cells": [[0, 0, "valley", "meadow"]]}).reason)
	var lava := str(d.b.apply({"op": "plant", "cells": [[c.x, c.y, "flowers", "lava"]]}).reason)
	var feet := Vector3(c.x * 3.0 + 1.5, d.land.height_at(c.x * 3.0 + 1.5, c.y * 3.0 + 1.5), c.y * 3.0 + 1.5)
	d.b.protect.visitor_at = func() -> Vector3: return feet
	var under_him := str(pl.refusal(c))
	var paint_him := str(d.land.refusal(c, "paint"))
	d.b.protect.visitor_at = func() -> Vector3: return d.far
	d.b.undo()
	var undone: int = pl.size()
	d.b.redo()
	var redone: String = pl.growth_at(c + Vector2i(1, 0))
	d.b.undo()
	d.b.flush()
	var ok: bool = r1.ok and g1 == "flowers" and wrong.begins_with("cells: [") and village == "village" and lava.begins_with("cells: 'lava' is not a growth") \
		and under_him == "" and paint_him == "too close" and undone == 0 and redone == "tall_grass"
	say("op", ok, "flowers + tall grass by llm: applied %s ('%s'); a wrong from: '%s'; in the village: '%s'; lava: '%s'; where the visitor stands: plant '%s' (paint '%s'); undo -> %d cells, redo -> '%s'" % [
		r1.ok, g1, wrong, village, lava, under_him, paint_him, undone, redone])


func uv_case() -> void:
	var site: Vector2 = d.free_site(Vector2(480, -380), 21.0)
	var c: Vector2i = d.vtx(site)
	var cells := []
	var growths := ["meadow", "flowers", "tall_grass"]
	for k: int in 3:
		for j: int in range(-2, 3):
			for i: int in range(-2, 3):
				cells.append([c.x + (k - 1) * 7 + i, c.y + j, "valley", growths[k]])
	var r: Dictionary = d.b.apply({"op": "plant", "cells": cells})
	d.b.flush()
	var got := []
	var green := true
	for k: int in 3:
		var v := c + Vector2i((k - 1) * 7, 0)
		var m: Array = d.mesh_at(v)
		if m.is_empty():
			got.append("none")
			green = false
			continue
		var uv: Vector2 = m[2]
		got.append("%s (%.2f, %.2f)" % [growths[k], uv.x, uv.y])
		var base: Color = d.land.ground().attrs(v.x * 3.0, v.y * 3.0)[1]
		var want: Color = d.land.ground().pigment("grass_dark" if k == 2 else "grass", v.x * 3.0, v.y * 3.0)
		var col: Color = m[0]
		green = green and Vector3(col.r - want.r, col.g - want.g, col.b - want.b).length() < Vector3(base.r - want.r, base.g - want.g, base.b - want.b).length() + 0.001
	var far: Array = []
	for j: int in [6, -6, 8, -8, 10, -10, 12, -12]:
		far = d.mesh_at(c + Vector2i(0, j))
		if not far.is_empty():
			break
	var want_uv := [Vector2(0.5, -8.35), Vector2(0.3, -9.0), Vector2(1.0, -8.0)]
	var uv_ok: bool = got.size() == 3
	for k: int in 3:
		var m: Array = d.mesh_at(c + Vector2i((k - 1) * 7, 0))
		uv_ok = uv_ok and not m.is_empty() and (m[2] as Vector2).distance_to(want_uv[k]) < 0.02
	var plain_ok: bool = not far.is_empty() and (far[2] as Vector2) == Vector2(0.0, -8.0)
	var ok: bool = r.ok and uv_ok and green and plain_ok
	say("uv", ok, "%d cells planted in three 5 x 5 fields: the mesh's UV in the middle of each %s (want x tufts, -8 - y flowers: meadow (0.5, -8.35), flowers (0.3, -9), tall grass (1, -8)); colour toward its green %s; 6-12 cells off, in an open chunk, UV %s" % [
		cells.size(), ", ".join(got), green, str(far[2]) if not far.is_empty() else "none"])
	d.b.undo()
	d.b.flush()


func unedited_case() -> void:
	var gv: RefCounted = d.home.ground
	var valley0 := _valley_hash(gv)
	var site: Vector2 = d.free_site(Vector2(640, -480), 9.0)
	var c: Vector2i = d.vtx(site)
	var id := Vector2i(floori(c.x * 3.0 / 96.0), floori(c.y * 3.0 / 96.0))
	var open0: int = d.land.mesh.chunks.size()
	d.b.apply({"op": "plant", "cells": [[c.x, c.y, "valley", "meadow"]]})
	d.b.flush()
	var opened: bool = d.land.mesh.is_open(id)
	d.b.undo()
	d.b.flush()
	var closed: bool = not d.land.mesh.is_open(id) and d.land.mesh.chunks.size() == open0
	var valley1 := _valley_hash(gv)
	# a painted chunk's mesh before and after growth in another chunk
	var p2: Vector2 = d.free_site(Vector2(480, -480), 9.0)
	var c2: Vector2i = d.vtx(p2)
	var id2 := Vector2i(floori(c2.x * 3.0 / 96.0), floori(c2.y * 3.0 / 96.0))
	d.b.apply({"op": "paint", "cells": [[c2.x, c2.y, "valley", "sand"]]})
	d.b.flush()
	var h0: String = str(d.land.mesh.figures(id2)[2])
	var far_cell := c2 + Vector2i(64, 0)
	d.b.apply({"op": "plant", "cells": [[far_cell.x, far_cell.y, "valley", "tall_grass"]]})
	d.b.flush()
	var h1: String = str(d.land.mesh.figures(id2)[2])
	d.b.undo()
	d.b.undo()
	d.b.flush()
	var ok: bool = opened and closed and valley0 == valley1 and h0 == h1 and h0 != ""
	say("unedited", ok, "one meadow cell opened its chunk %s, undo closed it %s; the valley's mesh (vertices, colours, codes, UV, indices) %s... the same after %s; a sand chunk's mesh %s... the same after tall grass 192 m away %s" % [
		opened, closed, valley0.substr(0, 12), valley0 == valley1, h0.substr(0, 12), h0 == h1])


func _valley_hash(gv: RefCounted) -> String:
	var m: ArrayMesh = gv.mesh
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	var a: Array = m.surface_get_arrays(0) if m != null else [gv.vertices, gv.colors, gv.custom]
	for x: Variant in a:
		if x is PackedVector3Array or x is PackedColorArray or x is PackedFloat32Array or x is PackedVector2Array or x is PackedInt32Array:
			h.update(x.to_byte_array())
	return h.finish().hex_encode()


func files_case() -> void:
	var site: Vector2 = d.free_site(Vector2(560, -380), 9.0)
	var c: Vector2i = d.vtx(site)
	d.b.apply({"op": "plant", "cells": [[c.x, c.y, "valley", "meadow"], [c.x + 1, c.y, "valley", "flowers"], [c.x + 2, c.y, "valley", "tall_grass"]]})
	var h0: String = pl.content_hash()
	var d1 := TMP.path_join("a")
	var d2 := TMP.path_join("b")
	var why1: String = d.b.save(d1)
	var t1 := FileAccess.get_file_as_string(d1.path_join("build.json"))
	var r: Dictionary = d.b.load(d1)
	var back: bool = pl.content_hash() == h0 and pl.growth_at(c + Vector2i(1, 0)) == "flowers"
	var why2: String = d.b.save(d2)
	var t2 := FileAccess.get_file_as_string(d2.path_join("build.json"))
	d.b.flush()
	var ok: bool = why1 == "" and why2 == "" and r.ok and back and t1 == t2 and t1.begins_with("{\"v\":3,") and t1.find("\"plants\":{") > 0
	say("files", ok, "tl.build/3 %d bytes (%s...), plants %s; loaded back %s (3 cells, the same hash %s); save -> load -> save byte-identical %s" % [
		t1.length(), t1.substr(0, 16), t1.find("\"plants\":{") > 0, r.ok, back, t1 == t2])
	d.b.apply({"op": "plant", "cells": [[c.x, c.y, "meadow", "valley"], [c.x + 1, c.y, "flowers", "valley"], [c.x + 2, c.y, "tall_grass", "valley"]]})
	d.b.flush()


func scatter_case() -> void:
	var site: Vector2 = d.free_site(Vector2(400, -480), 15.0)
	await d.to_tool("plant")
	await d.set_radius(4)
	var lines := []
	var ok := true
	for k: Key in [KEY_4, KEY_5]:
		await d.tap(k)
		var t: RefCounted = d.bm.call("tool")
		var n0: int = d.b.edits.history.size()
		var pieces0: int = d.b.layer("pieces").size()
		await d.stroke(site, 4)
		var hit: Vector3 = Vector3(site.x, d.land.height_at(site.x, site.y), site.y)
		var kind := "tree" if k == KEY_4 else "bush"
		var want: Array = PlantScatter.scatter(d.b, hit, 12.0, kind, 1.0, 1)
		var put: int = d.b.layer("pieces").size() - pieces0
		var batches: int = d.b.edits.history.size() - n0
		var info: String = str(t.status().info)
		lines.append("%s: %d put in %d batch(es), info '%s'" % [kind, put, batches, info])
		# the stub gives none: nothing put, the line says so; lane P's scatter: puts in one batch
		ok = ok and str(t.get("slot")) == ("trees" if k == KEY_4 else "bushes") and ((want.is_empty() and put == 0 and info.contains("gave none")) or (not want.is_empty() and put > 0 and batches == 1))
		if batches > 0:
			d.b.undo()
	d.b.flush()
	await d.tap(KEY_1)
	say("scatter", ok, "; ".join(lines))


func ghost_case() -> void:
	var site: Vector2 = d.free_site(Vector2(560, -380), 9.0)
	var c: Vector2i = d.vtx(site)
	d.b.apply({"op": "plant", "cells": [[c.x + 2, c.y, "valley", "meadow"]]})
	var r: Dictionary = d.b.preview([{"op": "plant", "cells": [[c.x, c.y, "valley", "flowers"], [c.x + 1, c.y, "valley", "tall_grass"], [c.x + 2, c.y, "meadow", "valley"]]}])
	var nodes: Array = d.b.preview_nodes(r, ["blocks"])
	var tris := {}
	for n: Node3D in nodes:
		root.add_child(n)
		if str(n.get_meta(&"tl_layer", "")) == "plants":
			tris = n.call("tris")
	var real: String = pl.growth_at(c)
	for n: Node3D in nodes:
		n.free()
	d.b.undo()
	var ok: bool = r.ok and tris == {"neon_pink": 2, "grass_dark": 2, "valley": 2} and real == "valley"
	say("ghost", ok, "a dry run of flowers, tall grass and a clear: the plants layer's ghost %s triangles (a cell each, flowers pink, tall grass dark green, cleared red); the Home untouched %s" % [str(tris), real == "valley"])
