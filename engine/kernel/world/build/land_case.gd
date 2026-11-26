extends SceneTree
## M2 (spark world-sandbox): land sculpt and paint in the Home, headless, in the landscape of res://boot/village.json
## (the Home grown by home/hook.gd, build mode mounted). The tools are driven as a person drives them (B, T, the keys,
## the pointer on the ground, LMB held for frames); the layer's rules and files are asked directly. Frames, not wall
## clock (wall clock is measured, never decided on). Prints `HOME land.<case> ok|fail <detail>`, then `HOME land ok`
## (or fail) and `HOME DONE`; engine/tools/selftest.d/755-home-land.sh reads them.
##   land.protect  the village, a game lot, a lane, the river, a structure, a field, blocks and the visitor refuse
##                 with their reasons; beyond 24 m and a wrong from_cm refuse; a refused op is not logged
##   land.stroke   raise (LMB held), lower (Shift), flatten (3) and smooth (4) strokes: each ONE op in one batch, every
##                 vertex from its first height to its last; undo of all four gives every vertex back exactly
##   land.paint    a dirt stroke paints cells (the mesh's colour there is dirt's), the eraser clears them, undo and redo
##   land.seam     a hill over a chunk corner and a hollow alone: every rim vertex of an edited chunk against the valley
##                 (or the edited neighbour) it meets: the worst gap; the valley's cells there hidden
##   land.collide  a walker dropped on the raised hill stands on it (frames counted); the space's ray agrees
##   land.block    a block placed by a cursor ray on the hill sits on it
##   land.scatter  a tree in a lowered cell is hidden (and its trunk gone), one in a slightly raised cell moves; undo
##   land.hash     the same op list gives the same chunk mesh hashes
##   land.files    save -> load -> save is byte-identical (tl.build/2 with land and paint), the journal replays
##   land.cost     redraw ms per chunk (median, max), triangles per edited chunk, frame time while sculpting

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const Blocks := preload("res://kernel/world/build/blocks.gd")
const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const Probe := preload("res://kernel/world/build/land_probe.gd")
const TMP := "user://tl_land_case"
const CAM_H := 40.0
const HOLLOW := Vector2(144.0, 48.0)    # from the site: the middle of the chunk east of the hill's (+x, +z) quarter

var node: Node3D
var ws: Object
var home: RefCounted
var bm: Node
var b: RefCounted
var land: RefCounted
var cam: Camera3D
var ok_all := true
var site := Vector2.ZERO               # a chunk corner whose ground nothing protects for 36 m round
var far := Vector3.ZERO


func _initialize() -> void:
	call_deferred("run")


func say(case_name: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME land.%s %s %s" % [case_name, "ok" if ok else "fail", detail])


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func run() -> void:
	TLStyle.set_headless(false)
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	node = CaseUtil.landscape(root, CaseUtil.walk())
	if not node.has_meta(&"tl_build_mode"):
		say("protect", false, "no build mode: home/hook.gd did not mount it")
		finish()
		return
	ws = node.get_meta(&"tl_space")
	home = node.get_meta(&"tl_home")
	bm = node.get_meta(&"tl_build_mode")
	b = node.get_meta(&"tl_build")
	land = b.layer("land")
	bm.call("open", TMP)
	site = find_site()
	far = Vector3(site.x + 300.0, 0.0, site.y + 300.0)
	bm.set("feet_at", func() -> Vector3: return far)
	b.protect.visitor_at = func() -> Vector3: return far
	home.ensure(site)
	cam = Camera3D.new()
	cam.fov = 60.0
	root.add_child(cam)
	cam.current = true
	bm.set("cam", cam)
	root.size = Vector2i(1280, 720)
	over(Vector3(site.x, land.height_at(site.x, site.y), site.y))
	await wait(3)
	protect_case()
	await stroke_case()
	await paint_case()
	seam_case()
	await collide_case()
	block_case()
	scatter_case()
	hash_case()
	files_case()
	await cost_case()
	finish()


func finish() -> void:
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	print("HOME land %s" % ("ok" if ok_all else "fail"))
	print("HOME DONE")
	quit(0)


func over(p: Vector3) -> void:
	cam.look_at_from_position(p + Vector3(0.0, CAM_H, 0.01), p, Vector3.FORWARD)
	cam.reset_physics_interpolation()


## A chunk corner 384..1536 m east whose vertices within 36 m nothing protects (for land and paint), and the ground
## of the hollow (HOLLOW from it) too.
func find_site() -> Vector2:
	for cz: int in range(-5, 7):
		for cx: int in range(4, 16):
			var c := Vector2(cx * 96.0, cz * 96.0)
			var free := true
			for o: Vector2 in [Vector2.ZERO, HOLLOW]:
				for j: int in range(-12, 13, 3):
					for i: int in range(-12, 13, 3):
						var v := vtx(c + o) + Vector2i(i, j)
						free = free and land.refusal(v, "land") == "" and land.refusal(v, "paint") == ""
			if free:
				return c
	return Vector2(768.0, 0.0)


func vtx(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x / 3.0), roundi(p.y / 3.0))


func key(k: Key, down: bool, shift := false) -> void:
	CaseUtil.key(k, down, shift)


func tap(k: Key, shift := false) -> void:
	if shift:
		key(KEY_SHIFT, true)
	key(k, true, shift)
	await wait(2)
	key(k, false, shift)
	if shift:
		key(KEY_SHIFT, false)
	await wait(2)


func button(down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = bm.get("pointer")
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func point(p: Vector2) -> void:
	var q := p + Vector2(0.23, 0.31)               # off the lattice: a ray exactly through an edge two triangles share can miss both (Jolt)
	bm.set("pointer", cam.unproject_position(Vector3(q.x, land.height_at(q.x, q.y), q.y)))


## LMB held `frames` physics frames with the pointer on `at` (moving along `path` when given), Shift held if asked.
func stroke(at: Vector2, frames: int, shift := false, path := Vector2.ZERO) -> void:
	point(at)
	await wait(2)
	if shift:
		key(KEY_SHIFT, true)
	button(true)
	for f: int in frames:
		if path != Vector2.ZERO:
			point(at + path * (float(f) / frames))
		await wait(1)
	button(false)
	if shift:
		key(KEY_SHIFT, false)
	await wait(2)


func snapshot(centre: Vector2i, r: int) -> Dictionary:
	var out := {}
	for j: int in range(centre.y - r, centre.y + r + 1):
		for i: int in range(centre.x - r, centre.x + r + 1):
			out[Vector2i(i, j)] = int(land.cm_at(Vector2i(i, j)))
	return out


func last_ops() -> Array:
	return (b.edits.history[b.edits.history.size() - 1] as Dictionary).ops if not b.edits.history.is_empty() else []


# ------------------------------------------------------------------ cases
func protect_case() -> void:
	var v: RefCounted = home.ground.land
	var got := {}
	got["village"] = land.refusal(Vector2i(0, 0), "land")
	got["game lot"] = land.refusal(vtx(Vector2(957, 198)), "land")
	got["river"] = land.refusal(vtx(Vector2(v.river_x(800.0), 800.0)), "paint")
	for id: Vector2i in home.lanes:
		var f: PackedVector3Array = home.lanes[id]
		var why: String = land.refusal(vtx(Vector2(f[0].x, f[0].z)), "land")
		if why == "lane":
			got["lane"] = why
			break
	for t: Array in land.guard.things():
		var why: String = land.refusal(vtx(t[0]), "land")
		if why.begins_with("authored structure"):
			got["structure"] = why
			break
	for parcel: Dictionary in v.fields:
		var q: Array = parcel.corners[0]
		var mid := (Vector2(q[0], q[1]) + Vector2(parcel.corners[2][0], parcel.corners[2][1])) * 0.5
		var why: String = land.refusal(vtx(mid), "land")
		if why == "field":
			got["field"] = why
			break
	var at := vtx(site + Vector2(-30, -30))
	var cell := Vector3i(at.x * 3, int(floorf(land.height_at(at.x * 3, at.y * 3))), at.y * 3)
	b.place(cell, Blocks.code(Blocks.CUBE, 1))
	got["blocks"] = land.refusal(at, "land")
	b.undo()
	b.protect.visitor_at = func() -> Vector3: return Vector3(at.x * 3.0, land.height_at(at.x * 3.0, at.y * 3.0), at.y * 3.0)
	got["too close"] = land.refusal(at, "land")
	b.protect.visitor_at = func() -> Vector3: return far
	var n0: int = b.edits.history.size()
	var base: int = land.cm_at(at)
	got["limit"] = str(b.apply({"op": "land", "verts": [[at.x, at.y, base + 2500]]}).reason)
	got["from"] = str(b.apply({"op": "land", "verts": [[at.x, at.y, base + 7, base + 100]]}).reason)
	got["op village"] = str(b.apply({"op": "land", "verts": [[0, 0, 100]], "author": "llm"}).reason)
	var want := {"village": "village", "game lot": "game lot", "river": "river", "lane": "lane", "structure": "authored structure (",
		"field": "field", "blocks": "blocks", "too close": "too close", "limit": "height limit", "from": "verts: [%d, %d] is at %d cm" % [at.x, at.y, base],
		"op village": "village"}
	var bad := []
	for k: String in want:
		if not str(got.get(k, "(none found)")).begins_with(want[k]):
			bad.append("%s: '%s'" % [k, str(got.get(k, "(none found)"))])
	if b.edits.history.size() != n0:
		bad.append("a refused op was logged")
	var parts := []
	for k: String in got:
		parts.append("%s '%s'" % [k, got[k]])
	say("protect", bad.is_empty(), "site %s; %s; %d structures found%s" % [str(site), "; ".join(parts), land.guard.things().size(),
		"" if bad.is_empty() else "; BAD " + "; ".join(bad)])


func stroke_case() -> void:
	var bad := []
	var c := vtx(site + Vector2(-20, -20))
	var p := Vector2(c.x * 3.0, c.y * 3.0)
	var before := snapshot(c, 10)
	await tap(KEY_B)
	await tap(KEY_T)
	var tool_id: String = bm.call("tool").get("id")
	var n0: int = b.edits.history.size()
	await stroke(p, 30)
	var raise_ops := last_ops()
	var after_raise := snapshot(c, 10)
	var top := int(after_raise[c]) - int(before[c])
	var rec_ok: bool = raise_ops.size() == 1 and raise_ops[0].op == "land"
	if rec_ok:
		for e: Array in raise_ops[0].verts:
			var v := Vector2i(e[0], e[1])
			rec_ok = rec_ok and int(e[2]) == int(before.get(v, land.ground().base_cm(v))) and int(e[3]) == land.cm_at(v)
	await stroke(p + Vector2(6, 0), 15, true)
	var lower_ops := last_ops()
	var after_lower := snapshot(c, 10)
	var dropped := int(after_raise[c + Vector2i(2, 0)]) - int(after_lower[c + Vector2i(2, 0)])
	await tap(KEY_3)
	var fc := c + Vector2i(-3, 0)                   # the flatten's centre, on the mound's flank
	var flat0 := Probe.spread(after_lower, fc, 1)
	await stroke(p + Vector2(-9, 0), 40)
	var flat1 := Probe.spread(snapshot(c, 10), fc, 1)
	await tap(KEY_4)
	var rough := Probe.rough(land, snapshot(c, 10), c, 5)
	await stroke(p, 40)
	var smooth := Probe.rough(land, snapshot(c, 10), c, 5)
	var batches: int = b.edits.history.size() - n0
	for k: int in 4:
		key(KEY_CTRL, true)
		await tap(KEY_Z)
		key(KEY_CTRL, false)
	await wait(2)
	var back: bool = snapshot(c, 10) == before and land.size() == 0
	await tap(KEY_1)
	if tool_id != "sculpt" or batches != 4 or not rec_ok or top < 100 or dropped <= 0 or flat1 >= flat0 or smooth >= rough or not back:
		bad.append("tool %s, batches %d, records %s, top +%d cm, lowered %d cm, flatten spread %d -> %d, smooth roughness %.1f -> %.1f, back %s" % [
			tool_id, batches, rec_ok, top, dropped, flat0, flat1, rough, smooth, back])
	say("stroke", bad.is_empty(), "sculpt tool; raise 30 frames: 1 op of %d vertices (one batch), centre +%d cm, records from the first touch to the last %s; Shift lower 15 frames: %d vertices, -%d cm; flatten (3): spread over 5 x 5 %d -> %d cm; smooth (4): roughness %.1f -> %.1f cm; %d batches; Ctrl+Z x4: every vertex back exactly %s (store %d)%s" % [
		(raise_ops[0].verts as Array).size() if rec_ok else 0, top, rec_ok, (lower_ops[0].verts as Array).size() if not lower_ops.is_empty() else 0, dropped,
		flat0, flat1, rough, smooth, batches, back, land.size(), "" if bad.is_empty() else "; BAD " + "; ".join(bad)])



func paint_case() -> void:
	var bad := []
	await tap(KEY_T)
	var tool_id: String = bm.call("tool").get("id")
	await tap(KEY_4)
	var p := site + Vector2(-20, 20)
	var n0: int = b.edits.history.size()
	await stroke(p, 6, false, Vector2(12, 0))
	var painted: int = land.store.paints.size()
	var all_dirt := true
	for cc: Vector2i in land.store.paints:
		all_dirt = all_dirt and land.store.paint_at(cc) == "dirt"
	b.flush()
	var colour := _mesh_colour(p + Vector2(6, 0))
	var dirt: Color = land.ground().pigment("dirt", p.x + 6, p.y)
	var near := Vector3(colour.r, colour.g, colour.b).distance_to(Vector3(dirt.r, dirt.g, dirt.b))
	await tap(KEY_0)
	await stroke(p, 6, false, Vector2(12, 0))
	var erased: int = land.store.paints.size()
	b.undo()
	var undone: int = land.store.paints.size()
	b.undo()
	var gone: int = land.store.paints.size()
	b.redo()
	var redone: int = land.store.paints.size()
	b.undo()
	var batches: int = b.edits.history.size() - n0
	await tap(KEY_T)
	await tap(KEY_T)
	await tap(KEY_T)
	await tap(KEY_T)
	await tap(KEY_T)
	if tool_id != "paint" or painted < 4 or not all_dirt or near > 0.08 or erased != 0 or undone != painted or gone != 0 or redone != painted:
		bad.append("tool %s, painted %d dirt %s, colour off by %.3f, erased to %d, undo %d, undo %d, redo %d" % [tool_id, painted, all_dirt, near, erased, undone, gone, redone])
	say("paint", bad.is_empty(), "paint tool, 4 = dirt: a 6-frame stroke painted %d cells, all dirt %s; the mesh's colour in the middle is %.3f from dirt's; eraser (0): %d left; undo -> %d, undo -> %d, redo -> %d; %d batches left%s" % [
		painted, all_dirt, near, erased, undone, gone, redone, batches, "" if bad.is_empty() else "; BAD " + "; ".join(bad)])


func _mesh_colour(p: Vector2) -> Color:
	for id: Vector2i in land.mesh.chunks:
		var s: Dictionary = land.mesh.chunks[id]
		var X: PackedFloat32Array = s.X
		var Z: PackedFloat32Array = s.Z
		var px := X.find(roundf(p.x / 3.0) * 3.0)
		var qz := Z.find(roundf(p.y / 3.0) * 3.0)
		if px >= 0 and qz >= 0:
			return (s.col as PackedColorArray)[qz * X.size() + px]
	return Color.BLACK


var seam_ops := []


## A hill of +4 m over the chunk corner (radius 7 cells) and a hollow of -2.5 m in the middle of the next chunk east.
func seam_ops_of() -> Array:
	var ops := []
	for spec: Array in [[site, 7, 400], [site + HOLLOW, 4, -250]]:
		var c := vtx(spec[0])
		var verts := []
		for j: int in range(-spec[1], spec[1] + 1):
			for i: int in range(-spec[1], spec[1] + 1):
				var t := Vector2(i, j).length() / float(spec[1])
				if t < 1.0:
					var v := c + Vector2i(i, j)
					verts.append([v.x, v.y, land.cm_at(v) + roundi(spec[2] * (1.0 - t * t))])
		ops.append({"op": "land", "verts": verts})
	return ops


func seam_case() -> void:
	seam_ops = seam_ops_of()
	var r: Dictionary = b.apply(seam_ops)
	b.flush()
	var m: Dictionary = Probe.rims(land, home)
	var ok: bool = bool(r.ok) and land.mesh.chunks.size() >= 5 and float(m.valley) < 0.005 and float(m.open) < 0.005 and m.hidden == m.cells
	say("seam", ok, "%d ops applied %s; %d edited chunks drawn by their own mesh; %d rim vertices: worst gap to the valley's edge %.6f m, to an edited neighbour's rim %.6f m; valley cells hidden %d of %d" % [
		seam_ops.size(), r.ok, land.mesh.chunks.size(), m.rims, m.valley, m.open, m.hidden, m.cells])



func collide_case() -> void:
	var top: float = land.height_at(site.x + 1.5, site.y + 1.5)
	var ray: float = float(ws.call("ground_at", site.x + 1.5, site.y + 1.5, top + 50.0))
	var pos := Vector3(site.x + 1.5, top + 1.5, site.y + 1.5)
	ws.call("place", pos)
	ws.call("rest")
	var landed := -1
	for f: int in 120:
		var d: Dictionary = ws.call("drive", pos, Vector3.ZERO, false, false)
		pos = d.pos
		if landed < 0 and bool(d.get("grounded", false)) and absf(pos.y - top) < 0.15:
			landed = f
	var valley_y: float = land.ground().y(site.x + 1.5, site.y + 1.5)
	var ok: bool = landed >= 0 and absf(pos.y - top) < 0.15 and absf(ray - top) < 0.05 and top - valley_y > 3.0
	say("collide", ok, "hill top %.2f m (the valley's own %.2f m); the space's ray meets %.3f m; a walker dropped from 1.5 m stood on it at frame %d, feet %.3f m after 120 frames" % [
		top, valley_y, ray, landed, pos.y])


func block_case() -> void:
	var p := site + Vector2(4.5, -6.5)
	var h: float = land.height_at(p.x, p.y)
	var hit: Dictionary = b.pick(Vector3(p.x, h + 30.0, p.y), Vector3(p.x, h - 30.0, p.y))
	var cell: Vector3i = hit.get("place", HomeBuild.NO_CELL)
	var r: Dictionary = b.place(cell, Blocks.code(Blocks.CUBE, 7))
	var sits: bool = r.ok and float(cell.y) <= h and h < float(cell.y) + 1.0 and h - land.ground().y(p.x, p.y) > 2.0
	say("block", sits, "on the hill at (%.1f, %.1f): ground %.2f m (raised %.2f m); the cursor ray hit %.3f m, the block went into cell %s (%s): it sits on the raised ground %s" % [
		p.x, p.y, h, h - land.ground().y(p.x, p.y), float((hit.get("pos", Vector3.ZERO) as Vector3).y), str(cell), str(r.reason) if not r.ok else "placed", sits])
	b.undo()


func scatter_case() -> void:
	var sc: RefCounted = land.scatter
	sc._prepare()
	var picks := []
	for id: Vector2i in sc.by_chunk:
		for e: Array in sc.by_chunk[id]:
			var o: Vector3 = (e[2] as Transform3D).origin
			var c := Vector2i(floori(o.x / 3.0), floori(o.z / 3.0))
			var free := true
			for v: Vector2i in [c, c + Vector2i(1, 0), c + Vector2i(0, 1), c + Vector2i(1, 1)]:
				free = free and land.refusal(v, "land") == ""
			if free:
				picks.append([id, o, c])
				break
		if picks.size() >= 2:
			break
	if picks.size() < 2:
		say("scatter", false, "no two scatter instances on free ground (of %d chunks)" % sc.by_chunk.size())
		return
	var n0: int = b.edits.history.size()
	for k: int in 2:
		var c: Vector2i = picks[k][2]
		var verts := []
		for v: Vector2i in [c, c + Vector2i(1, 0), c + Vector2i(0, 1), c + Vector2i(1, 1)]:
			verts.append([v.x, v.y, land.cm_at(v) + (-150 if k == 0 else 30)])
		b.apply({"op": "land", "verts": verts})
	b.flush()
	var states := []
	for k: int in 2:
		for e: Array in sc.report(picks[k][0]):
			if (e[0] as Vector3) == picks[k][1]:
				states.append(e[1])
	var foot: Variant = land.trunk_foot(picks[0][1])
	var foot2: Variant = land.trunk_foot(picks[1][1])
	while b.edits.history.size() > n0:
		b.undo()
	b.flush()
	var after := []
	for k: int in 2:
		for e: Array in sc.report(picks[k][0]):
			if (e[0] as Vector3) == picks[k][1]:
				after.append(e[1])
	var raised: float = (foot2 as Vector3).y - (picks[1][1] as Vector3).y if foot2 is Vector3 else -1.0
	var ok: bool = states == ["hidden", "moved"] and foot == null and absf(raised - 0.30) < 0.02 and after == ["", ""]
	say("scatter", ok, "an instance at %s lowered 1.5 m: %s (trunk %s); one at %s raised 0.3 m: %s (trunk +%.3f m); undo: %s" % [
		str(picks[0][1]), states[0] if states.size() > 0 else "?", "gone" if foot == null else "kept", str(picks[1][1]),
		states[1] if states.size() > 1 else "?", raised, str(after)])


func hash_case() -> void:
	var first := Probe.hashes(land)
	var undone := 0
	while not b.edits.history.is_empty() and (last_ops()[0] as Dictionary).op == "land":
		undone += b.undo()
		if undone > 10:
			break
	b.flush()
	var closed: int = land.mesh.chunks.size()
	b.apply(seam_ops)
	b.flush()
	var again := Probe.hashes(land)
	var ok: bool = not first.is_empty() and first == again and closed == 0
	say("hash", ok, "%d edited chunks; undo -> %d drawn; the same %d ops again -> the same mesh hashes %s (%s...)" % [
		first.size(), closed, seam_ops.size(), first == again, str(first.values()[0]).substr(0, 12) if not first.is_empty() else "-"])



func files_case() -> void:
	var bad := []
	b.apply({"op": "paint", "cells": [[vtx(site).x - 5, vtx(site).y - 5, "valley", "sand"], [vtx(site).x - 4, vtx(site).y - 5, "valley", "grass_dry"]]})
	var h0: String = land.content_hash()
	var d1 := TMP.path_join("a")
	var d2 := TMP.path_join("b")
	var why1: String = b.save(d1)
	var t1 := FileAccess.get_file_as_string(d1.path_join("build.json"))
	var r: Dictionary = b.load(d1)
	b.flush()
	var why2: String = b.save(d2)
	var t2 := FileAccess.get_file_as_string(d2.path_join("build.json"))
	if why1 != "" or why2 != "" or t1 != t2 or not r.ok:
		bad.append("save '%s', load %s, save '%s', same bytes %s" % [why1, str(r.ok), why2, t1 == t2])
	if not t1.begins_with("{\"v\":2,") or t1.find("\"land\":{") < 0 or t1.find("\"paint\":{") < 0 or t1.find("\"chunks\":") > t1.find("\"land\":"):
		bad.append("head %s" % t1.substr(0, 60))
	var v := vtx(site) + Vector2i(9, 9)
	b.apply({"op": "land", "verts": [[v.x, v.y, land.cm_at(v) + 55]]})
	var h1: String = land.content_hash()
	var r2: Dictionary = b.load(d2)
	var replay_ok: bool = r2.ok and int(r2.replayed) == 1 and land.content_hash() == h1 and h1 != h0
	if not replay_ok:
		bad.append("journal replay %s (hash %s)" % [str(r2), land.content_hash() == h1])
	var flat: RefCounted = HomeBuild.new(null, null, {"seed": int(b.home_seed)})
	var r3: Dictionary = flat.load(d1)
	if not r3.ok or flat.layer("land").size() != land.size() - 1:
		bad.append("a builder without a valley read %s, %d entries (want %d)" % [str(r3.reason), flat.layer("land").size(), land.size() - 1])
	b.flush()
	say("files", bad.is_empty(), "tl.build/2 %d bytes (%s...), %d land vertices and %d paint cells; save -> load -> save byte-identical %s; one more op journaled and replayed over it %s; a builder without a valley reads it %s%s" % [
		t1.length(), t1.substr(0, 24), land.store.heights.size(), land.store.paints.size(), t1 == t2, replay_ok, r3.ok,
		"" if bad.is_empty() else "; BAD " + "; ".join(bad)])


func cost_case() -> void:
	var tris: Array = Probe.added_tris(land)
	var whole: Array = Probe.parts(land, home, Vector2i(floori(site.x / 96.0), floori(site.y / 96.0)), 15)
	# sculpting without a break: 240 frames of LMB held, the brush going round the chunk corner (the sculpt tool, raise)
	await tap(KEY_1)
	var idle := await _frames(60)
	var m0: int = (land.stats.mesh_usec as Array).size()
	var b0: int = (land.stats.body_usec as Array).size()
	var times := []
	point(site + Vector2(12, 0))
	await wait(2)
	button(true)
	var t0 := Time.get_ticks_usec()
	for f: int in 240:
		var a := TAU * f / 120.0
		point(site + Vector2(cos(a), sin(a)) * 12.0)
		await physics_frame
		var t1 := Time.get_ticks_usec()
		times.append(t1 - t0)
		t0 = t1
	button(false)
	await wait(3)
	times.sort()
	var meshes: Array = (land.stats.mesh_usec as Array).slice(m0)
	var bodies: Array = (land.stats.body_usec as Array).slice(b0)
	meshes.sort()
	bodies.sort()
	b.flush()
	var inc: Dictionary = Probe.hashes(land)                # the chunks after many partial redraws ...
	for id: Vector2i in land.mesh.chunks:
		land.mesh.draw(id, true)
	var same: bool = inc == Probe.hashes(land)             # ... are what a whole redraw makes
	await tap(KEY_B)
	var ok: bool = same and not meshes.is_empty() and not bodies.is_empty() and Probe.ms(meshes, 0.5) + Probe.ms(bodies, 0.5) < 4.0
	say("cost", ok, "a whole edited chunk: mesh %.2f ms, body %.2f ms, scatter %.2f ms; while sculpting 240 frames round a chunk corner (4 chunks): mesh redraw median %.2f ms, max %.2f over %d; body + scatter median %.2f ms, max %.2f over %d (one a frame while the stroke lasts); the partly redrawn chunks equal whole redraws %s; headless frame p50 %.2f ms, p99 %.2f ms (idle p50 %.2f, p99 %.2f); triangles added per edited chunk %s" % [
		whole[0], whole[1], whole[2], Probe.ms(meshes, 0.5), Probe.ms(meshes, 1.0), meshes.size(), Probe.ms(bodies, 0.5), Probe.ms(bodies, 1.0), bodies.size(), same,
		Probe.ms(times, 0.5), Probe.ms(times, 0.99), Probe.ms(idle, 0.5), Probe.ms(idle, 0.99), str(tris)])


func _frames(n: int) -> Array:
	var out := []
	var t0 := Time.get_ticks_usec()
	for f: int in n:
		await physics_frame
		var t1 := Time.get_ticks_usec()
		out.append(t1 - t0)
		t0 = t1
	out.sort()
	return out

