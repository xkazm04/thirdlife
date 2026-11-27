extends SceneTree
## M5 lane L (spark world-sandbox): the land look, headless, in the landscape of res://boot/village.json with the tools
## driven as a person does (land_drive.gd). Prints `HOME look.<case> ok|fail <detail>`, then `HOME look ok` (or fail)
## and `HOME DONE`; engine/tools/selftest.d/764-home-look.sh reads them.
##   look.bell     a raise stroke is a cosine bell: the height 2 cells (a third of the radius) out is under 0.88 of the
##                 centre's (M2's plateau kept 0.97), and it falls every cell to the rim
##   look.terrace  a flatten on a slope: a flat top; LP (27 Nov): rock is drawn per triangle by the shader from the
##                 triangle's own plane (land_mesh.gd FACE_FROM_NY), so every steep side triangle of the drawn mesh
##                 (normal y under FACE_TO_NY) has the Home land's UV (y <= -8), the terrain code and a colour alpha of
##                 1 at its three vertices (rock may show), and the top's vertices along the crease keep the ground's
##                 own colour (the nearest paint is a grass: M5 pulled them toward rock_warm, half a cell onto the top)
##   look.paint    one painted cell gives the 4 x 4 vertices round it (1, 3, 3, 1)^2 / 64 of the paint (worst error)
##   look.river    beyond the 71 m band, inside the water ribbon: lowering under the ribbon's level is refused
##                 ("river (its water would show ..."), raising is not; far from the river no ribbon is found
##   look.ghost    the land layer's ghost of a dry run: raised cells in holo, lowered in red, painted in the paint
##   look.cost     a whole edited chunk's mesh with paint, growth and rock (ms)

const Drive := preload("res://kernel/world/build/land_drive.gd")
const Probe := preload("res://kernel/world/build/land_probe.gd")
const LandMesh := preload("res://kernel/world/build/land_mesh.gd")
const TMP := "user://tl_look_case"

var d: RefCounted = Drive.new()
var ok_all := true


func _initialize() -> void:
	call_deferred("run")


func say(name: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME look.%s %s %s" % [name, "ok" if ok else "fail", detail])


func run() -> void:
	var why: String = d.setup(self, TMP)
	if why != "":
		say("bell", false, why)
		finish()
		return
	await d.wait(3)
	await d.tap(KEY_B)
	await bell_case()
	await terrace_case()
	paint_case()
	river_case()
	ghost_case()
	cost_case()
	finish()


func finish() -> void:
	Drive.CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	d.release()
	print("HOME look %s" % ("ok" if ok_all else "fail"))
	print("HOME DONE")
	quit(0)


func land() -> RefCounted:
	return d.land


func bell_case() -> void:
	var site: Vector2 = d.free_site(Vector2(480, -480), 24.0)
	var c: Vector2i = d.vtx(site)
	await d.to_tool("sculpt")
	await d.set_radius(6)
	await d.tap(KEY_1)
	await d.stroke(Vector2(c.x * 3.0, c.y * 3.0), 60)
	var prof := []
	for i: int in 7:
		var v := c + Vector2i(i, 0)
		prof.append(int(land().cm_at(v)) - int(land().ground().base_cm(v)))
	var ratio := float(prof[2]) / maxf(1.0, float(prof[0]))
	var falls := true
	for i: int in 6:
		falls = falls and int(prof[i]) > int(prof[i + 1])
	var ok: bool = prof[0] > 200 and ratio < 0.88 and falls and int(prof[6]) <= 0
	say("bell", ok, "raise, brush 6 (18 m), 60 frames: heights over the ground from the centre out, cm %s; 2 cells (0.33 r) out / centre %.2f (a cosine bell 0.75, M2's plateau 0.97); falls every cell %s" % [str(prof), ratio, falls])
	d.b.undo()
	d.b.flush()


func terrace_case() -> void:
	var site: Vector2 = d.free_site(Vector2(640, -480), 24.0, 0.12)
	var c: Vector2i = d.vtx(site)
	var slope0 := Vector2(land().height_at(site.x + 3, site.y) - land().height_at(site.x - 3, site.y), land().height_at(site.x, site.y + 3) - land().height_at(site.x, site.y - 3)).length() / 6.0
	await d.to_tool("sculpt")
	await d.set_radius(5)
	await d.tap(KEY_3)
	await d.stroke(Vector2(c.x * 3.0, c.y * 3.0), 60)
	var top := Probe.spread(_heights(c, 3), c, 3)
	var side := 0
	var rocky := 0
	var bad := []
	var tcode := int(land().ground().terrain_code)
	var crease := {}                         # vertices of a steep triangle that are also vertices of a level one
	var level_v := {}
	var steep_v := {}
	var box := Rect2(Vector2(c) * 3.0 - Vector2(24, 24), Vector2(48, 48))
	for id: Vector2i in land().mesh.chunks:
		var s: Dictionary = land().mesh.chunks[id]
		var pos: PackedVector3Array = s.pos
		var idx: PackedInt32Array = s.idx
		var col: PackedColorArray = s.col
		var code: PackedInt32Array = s.code
		var uv: PackedVector2Array = s.uv
		for t: int in range(0, idx.size(), 3):
			var a := pos[idx[t]]
			if not box.has_point(Vector2(a.x, a.z)):
				continue
			var n := (pos[idx[t + 1]] - a).cross(pos[idx[t + 2]] - a).normalized()
			var ny := absf(n.y)
			for k: int in 3:
				(steep_v if ny < LandMesh.FACE_TO_NY else level_v)[idx[t + k]] = id
			if ny >= LandMesh.FACE_TO_NY:
				continue
			side += 1
			var good := true
			for k: int in 3:
				var vi := idx[t + k]
				good = good and code[vi] == tcode and col[vi].a > 0.999 and uv[vi].y <= -7.99
			if good:
				rocky += 1
			elif bad.size() < 3:
				bad.append("triangle at %s ny %.2f codes %d alpha %.2f uv.y %.2f" % [str(a), ny, code[idx[t]], col[idx[t]].a, uv[idx[t]].y])
	var top_edge := 0
	var top_grass := 0
	for vi: int in steep_v:
		if not level_v.has(vi):
			continue
		var s: Dictionary = land().mesh.chunks[steep_v[vi]]
		var p: Vector3 = (s.pos as PackedVector3Array)[vi]
		if absf(p.y - land().height_at(c.x * 3.0, c.y * 3.0)) > 0.05:
			continue                             # the crease at the top (the foot is another)
		top_edge += 1
		var v := Vector2i(roundi(p.x / 3.0), roundi(p.z / 3.0))
		if _nearest_paint((s.col as PackedColorArray)[vi], v) in ["grass", "grass_dark", "grass_dry"]:
			top_grass += 1
		elif bad.size() < 4:
			bad.append("top edge %s paint %s" % [str(p), _nearest_paint((s.col as PackedColorArray)[vi], v)])
	var ok: bool = side >= 8 and rocky == side and top <= 30 and top_edge >= 4 and top_grass == top_edge
	say("terrace", ok, "flatten, brush 5, 60 frames on a slope of %.2f: the top's spread over 7 x 7 vertices %d cm; %d drawn triangles steeper than normal y %.2f, %d of them Home land with the terrain code and rock allowed at all 3 vertices; %d vertices on the top's crease, %d of them the ground's grass%s" % [
		slope0, top, side, LandMesh.FACE_TO_NY, rocky, top_edge, top_grass, "" if bad.is_empty() else "; NOT " + "; ".join(bad)])
	d.b.undo()
	d.b.flush()


func _heights(c: Vector2i, r: int) -> Dictionary:
	var out := {}
	for j: int in range(-r, r + 1):
		for i: int in range(-r, r + 1):
			out[c + Vector2i(i, j)] = int(land().cm_at(c + Vector2i(i, j)))
	return out


func _nearest_paint(c: Color, v: Vector2i) -> String:
	var best := ""
	var dist := 1e9
	for name: String in LandMesh.NAMES:
		var p: Color = land().ground().pigment(name, v.x * 3.0, v.y * 3.0)
		var e := Vector3(c.r - p.r, c.g - p.g, c.b - p.b).length()
		if e < dist:
			dist = e
			best = name
	return best


func paint_case() -> void:
	var site: Vector2 = d.free_site(Vector2(480, -380), 12.0)
	var c: Vector2i = d.vtx(site)
	var r: Dictionary = d.b.apply({"op": "paint", "cells": [[c.x, c.y, "valley", "dirt"]]})
	d.b.flush()
	var worst := 0.0
	var got := []
	for oy: int in 4:
		for ox: int in 4:
			var v := c + Vector2i(ox - 1, oy - 1)
			var m: Array = d.mesh_at(v)
			var base: Color = land().ground().attrs(v.x * 3.0, v.y * 3.0)[1]
			var pig: Color = land().ground().pigment("dirt", (c.x + 0.5) * 3.0, (c.y + 0.5) * 3.0)
			var dp := Vector3(pig.r - base.r, pig.g - base.g, pig.b - base.b)
			var col: Color = m[0] if not m.is_empty() else base
			var f := Vector3(col.r - base.r, col.g - base.g, col.b - base.b).dot(dp) / maxf(dp.length_squared(), 1e-9)
			var want: float = LandMesh.BLUR[ox] * LandMesh.BLUR[oy]
			worst = maxf(worst, absf(f - want))
			if oy == 1:
				got.append("%.3f" % f)
	var ok: bool = r.ok and worst < 0.01
	say("paint", ok, "one dirt cell: its vertices take %s of the paint along a row (want 0.047 0.141 0.141 0.047), worst error over the 4 x 4 %.4f (M2: a quarter to each of its 4 corners, none beyond)" % [" ".join(got), worst])
	d.b.undo()
	d.b.flush()


func river_case() -> void:
	var v: RefCounted = d.home.ground.land
	var z := 420.0
	var p := Vector2(float(v.river_x(z)) + 80.0, z)
	var at: Vector2i = d.vtx(p)
	var level: float = land().guard.water_level(at.x * 3.0, at.y * 3.0)
	var now: int = land().cm_at(at)
	var deep := roundi(level * 100.0) - 50
	var down := str(d.b.apply({"op": "land", "verts": [[at.x, at.y, deep]]}).reason)
	var up_r: Dictionary = d.b.apply({"op": "land", "verts": [[at.x, at.y, now + 100]]})
	if up_r.ok:
		d.b.undo()
	var shallow := str(d.b.apply({"op": "land", "verts": [[at.x, at.y, roundi(level * 100.0) + 200]]}).reason)
	if shallow == "":
		d.b.undo()
	var far_level: float = land().guard.water_level(p.x + 600.0, p.y)
	var band := str(land().refusal(d.vtx(Vector2(float(v.river_x(z)) + 40.0, z)), "land"))
	var ok: bool = not is_nan(level) and down.begins_with("river (its water would show") and bool(up_r.ok) and shallow == "" and is_nan(far_level) and band == "river"
	d.b.flush()
	say("river", ok, "80 m from the river line (outside the 71 m band): the water ribbon stands at %.2f m over ground at %.2f m; lowering to %.2f m: '%s'; raising 1 m: %s; lowering to 2 m over the water: '%s'; 680 m away: ribbon %s; 40 m from the line: '%s'" % [
		level, now / 100.0, deep / 100.0, down, "applied" if up_r.ok else str(up_r.reason), shallow, "none" if is_nan(far_level) else "%.2f" % far_level, band])


func ghost_case() -> void:
	var site: Vector2 = d.free_site(Vector2(560, -380), 12.0)
	var c: Vector2i = d.vtx(site)
	var r: Dictionary = d.b.preview([
		{"op": "land", "verts": [[c.x, c.y, land().cm_at(c) + 300], [c.x + 4, c.y, land().cm_at(c + Vector2i(4, 0)) - 200]]},
		{"op": "paint", "cells": [[c.x - 3, c.y, "valley", "sand"], [c.x - 3, c.y + 1, "valley", "sand"]]}])
	var nodes: Array = d.b.preview_nodes(r, ["blocks"])
	var tris := {}
	for n: Node3D in nodes:
		root.add_child(n)
		if str(n.get_meta(&"tl_layer", "")) == "land":
			tris = n.call("tris")
	var untouched: bool = land().size() == 0
	for n: Node3D in nodes:
		n.free()
	var ok: bool = r.ok and int(tris.get("holo", 0)) == 8 and int(tris.get("valley", 0)) == 8 and int(tris.get("sand", 0)) == 4 and untouched
	say("ghost", ok, "a dry run of one raised vertex, one lowered and two sand cells: the land layer's ghost draws %s triangles (raised: 4 cells in holo, lowered: 4 in red, 2 sand cells in sand); the Home untouched %s" % [str(tris), untouched])


func cost_case() -> void:
	var site: Vector2 = d.free_site(Vector2(480, -480), 24.0)
	var c: Vector2i = d.vtx(site)
	var verts := []
	var cells := []
	var grow := []
	for j: int in range(-6, 7):
		for i: int in range(-6, 7):
			var v := c + Vector2i(i, j)
			verts.append([v.x, v.y, land().cm_at(v) + (400 if absi(i) < 3 and absi(j) < 3 else 0) + 1])
			cells.append([v.x, v.y, "valley", "dirt" if i < 0 else "grass"])
			grow.append([v.x + 14, v.y, "valley", "meadow"])
	var r: Dictionary = d.b.apply([{"op": "land", "verts": verts}, {"op": "paint", "cells": cells}, {"op": "plant", "cells": grow}])
	d.b.flush()
	var id := Vector2i(floori(site.x / 96.0), floori(site.y / 96.0))
	var whole: Array = Probe.parts(land(), d.home, id, 15)
	say("cost", bool(r.ok), "%d vertices raised, %d cells painted, %d planted: a whole edited chunk's redraw: mesh %.2f ms (M2: 2.7-2.9 ms), body %.2f ms, scatter %.2f ms; %d chunks open" % [
		verts.size(), cells.size(), grow.size(), whole[0], whole[1], whole[2], land().mesh.chunks.size()])
