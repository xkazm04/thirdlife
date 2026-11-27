extends SceneTree
## M5 (spark world-sandbox, lane P): paths and the plant scatter in the Home, headless, in the landscape of
## res://boot/village.json (the Home grown by home/hook.gd, build mode mounted). The path tool is driven as a person
## drives it (B, T, 1-6, 0, the wheel, the pointer on the ground, LMB, RMB, Enter, Backspace, Ctrl+Z); the layer's rules
## and files are asked directly. Frames, not wall clock (wall clock is measured, never decided on). Prints
## `HOME paths.<case> ok|fail <detail>`, then `HOME paths ok` (or fail) and `HOME DONE`; 762-home-paths.sh reads them.
##   paths.lay      3 points clicked, RMB: ONE batch of a path op and a land op; a mesh in every chunk it crosses, its
##                  triangles = sections x rows; the ribbon over the drawn ground (least clearance); the ghost followed
##   paths.grade    the land op: every vertex within half width + 3 m of the centre line, none moved over 1.5 m, the
##                  cross slope at the path's edges before and after
##   paths.skip     a block beside the path: its vertex is left out (refused), the path still lays
##   paths.undo     Ctrl+Z takes the path and its grading back exactly (one undo), its meshes go; Ctrl+Y brings both
##   paths.unpath   the remove slot (0) + LMB on the path unpaths it (the whole record); undo gives it back
##   paths.ids      two paths get ids 1 and 2; a taken id, a width, a paint, a point spacing and a protected place are
##                  refused with their reasons and never logged
##   paths.enter    two points, Enter: the path lays and the tool stays the path tool (the host never saw Enter);
##                  Backspace drops a point; the wheel sets the width
##   paths.files    save (tl.build/3 with `paths`) -> load -> save byte-identical, the same chunk mesh hashes; the
##                  journal replays a path; a plank path (boardwalk) draws
##   paths.scatter  the same arguments give the same puts; the density within 20 %; none on a path, in water (a test
##                  water layer), in a protected cell; the batch applies whole and one undo takes it back
##   paths.cost     the lay time of one 60 m path, chunk mesh ms, the tool's aim (ghost) per frame

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const Blocks := preload("res://kernel/world/build/blocks.gd")
const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const PathShape := preload("res://kernel/world/build/path_shape.gd")
const PathMesh := preload("res://kernel/world/build/path_mesh.gd")
const PlantScatter := preload("res://kernel/world/build/plant_scatter.gd")
const TMP := "user://tl_paths_case"
const CAM_H := 90.0

var node: Node3D
var home: RefCounted
var bm: Node
var b: RefCounted
var land: RefCounted
var paths: RefCounted
var cam: Camera3D
var ok_all := true
var site := Vector2.ZERO
var far := Vector3.ZERO
var main_pts: Array = []                 # the 3 control points of the first path (metres)
var figures := {}


func _initialize() -> void:
	call_deferred("run")


func say(case_name: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME paths.%s %s %s" % [case_name, "ok" if ok else "fail", detail])


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func run() -> void:
	TLStyle.set_headless(false)
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	node = CaseUtil.landscape(root, CaseUtil.walk())
	if not node.has_meta(&"tl_build_mode"):
		say("lay", false, "no build mode: home/hook.gd did not mount it")
		finish()
		return
	home = node.get_meta(&"tl_home")
	bm = node.get_meta(&"tl_build_mode")
	b = node.get_meta(&"tl_build")
	land = b.layer("land")
	paths = b.layer("paths")
	bm.call("open", TMP)
	site = find_site()
	far = Vector3(site.x + 400.0, 0.0, site.y + 400.0)
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
	await tap(KEY_B)
	for i: int in 12:
		if str(bm.call("tool").get("id")) == "path":
			break
		await tap(KEY_T)
	await lay_case()
	await skip_case()
	await undo_case()
	await unpath_case()
	await ids_case()
	await enter_case()
	await files_case()
	scatter_case()
	await cost_case()
	finish()


func finish() -> void:
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	print("HOME paths %s" % ("ok" if ok_all else "fail"))
	print("HOME DONE")
	quit(0)


## The camera over (x, z) = `c`, settled.
func look(c: Vector2) -> void:
	over(Vector3(c.x, land.height_at(c.x, c.y), c.y))
	await wait(3)


func over(p: Vector3) -> void:
	cam.look_at_from_position(p + Vector3(0.0, CAM_H, 0.01), p, Vector3.FORWARD)
	cam.reset_physics_interpolation()


## A place 384..1536 m east where a 60 m path with a bend lies on unprotected, gently sloping ground (3-20 %).
func find_site() -> Vector2:
	var best := Vector2(768.0, 0.0)
	for cz: int in range(-6, 8):
		for cx: int in range(4, 16):
			var c := Vector2(cx * 96.0 + 48.0, cz * 96.0 + 48.0)
			var g := Vector2(land.height_at(c.x + 5.0, c.y) - land.height_at(c.x - 5.0, c.y), land.height_at(c.x, c.y + 5.0) - land.height_at(c.x, c.y - 5.0)) / 10.0
			if g.length() < 0.03 or g.length() > 0.2:
				continue
			var free := true
			for pts: Array in [pts_at(c), [c + Vector2(-15, 30), c + Vector2(17, 30)], [c + Vector2(-10, -30), c + Vector2(12, -24)],
					[c + Vector2(-12, -50), c + Vector2(4, -47)], [c + Vector2(-40, -40), c + Vector2(-28, -30)], [c + Vector2(-20, 50), c + Vector2(10, 58)]]:
				free = free and str(paths.refusal_of(rec_of(pts, 500))) == ""
			for k: int in 12:
				var q := c + Vector2(60, 60) + Vector2.from_angle(k * TAU / 12.0) * 9.0 * float(k % 2)
				free = free and str(b.protect.refusal_area(Rect2(q, Vector2.ONE), "plant")) == ""
			if not free:
				continue
			for q: Vector2 in pts_at(c):
				free = free and land.refusal(Vector2i(roundi(q.x / 3.0), roundi(q.y / 3.0)), "land") == ""
			if free:
				return c
	return best


func pts_at(c: Vector2) -> Array:
	return [c + Vector2(-30.0, -8.0), c + Vector2(0.0, 8.0), c + Vector2(30.0, -4.0)]


static func rec_of(pts_m: Array, width_cm: int, paint := "dirt", n := 1) -> Dictionary:
	var cm := []
	for q: Vector2 in pts_m:
		cm.append([roundi(q.x * 100.0), roundi(q.y * 100.0)])
	return {"op": "path", "id": n, "pts": cm, "width_cm": width_cm, "paint": paint}


func key(k: Key, down: bool, shift := false) -> void:
	CaseUtil.key(k, down, shift)


func tap(k: Key, shift := false) -> void:
	key(k, true, shift)
	await wait(2)
	key(k, false, shift)
	await wait(2)


func ctrl_tap(k: Key) -> void:
	key(KEY_CTRL, true)
	await tap(k)
	key(KEY_CTRL, false)
	await wait(1)


func point(p: Vector2) -> void:
	var q := p + Vector2(0.23, 0.31)               # off the lattice (a ray through a shared edge can miss both triangles)
	bm.set("pointer", cam.unproject_position(Vector3(q.x, land.height_at(q.x, q.y), q.y)))


func click(p: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	point(p)
	await wait(3)
	for down: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = down
		e.position = bm.get("pointer")
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await wait(2)


func wheel(up: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	e.pressed = true
	e.position = bm.get("pointer")
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await wait(2)


func tool() -> RefCounted:
	return bm.call("tool")


func last_ops() -> Array:
	return (b.edits.history[b.edits.history.size() - 1] as Dictionary).ops if not b.edits.history.is_empty() else []


## Heights (cm) of the lattice vertices round the path's box.
func snapshot(box: Rect2) -> Dictionary:
	var out := {}
	for j: int in range(floori(box.position.y / 3.0) - 2, ceili(box.end.y / 3.0) + 3):
		for i: int in range(floori(box.position.x / 3.0) - 2, ceili(box.end.x / 3.0) + 3):
			out[Vector2i(i, j)] = int(land.cm_at(Vector2i(i, j)))
	return out


## The mean |height left - height right| at the path's edges (cm), over its samples: its cross slope.
func cross(sm: Dictionary, h: float) -> float:
	var s := 0.0
	var p: PackedVector2Array = sm.p
	var t: PackedVector2Array = sm.t
	for i: int in p.size():
		var side := t[i].orthogonal() * h
		s += absf(land.height_at(p[i].x + side.x, p[i].y + side.y) - land.height_at(p[i].x - side.x, p[i].y - side.y))
	return s / maxf(1.0, p.size()) * 100.0


# ------------------------------------------------------------------ cases
func lay_case() -> void:
	var bad := []
	main_pts = pts_at(site)
	await tap(KEY_1)
	var h := float(tool().width_cm) / 200.0
	var clicked: Array = main_pts.map(func(q: Vector2) -> Vector2: return q + Vector2(0.23, 0.31))   # where `point` aims
	var sm := PathShape.sample(rec_of(clicked, int(tool().width_cm)).pts)
	figures["cross_before"] = cross(sm, h)
	figures["snap"] = snapshot(PathShape.box_of(sm.p, h + 6.0))
	var n0: int = b.edits.history.size()
	await click(main_pts[0])
	await click(main_pts[1])
	point(main_pts[2] + Vector2(-6.0, 2.0))
	await wait(3)
	var gh: Node3D = tool().ghost_node()
	var ghost_ok := gh != null and gh.is_inside_tree() and gh is MeshInstance3D and (gh as MeshInstance3D).mesh != null
	await click(main_pts[2])
	await click(main_pts[2] + Vector2(3.0, 3.0), MOUSE_BUTTON_RIGHT)
	b.flush()
	var ops := last_ops()
	var kinds: Array = ops.map(func(o: Dictionary) -> String: return str(o.op))
	var batches: int = b.edits.history.size() - n0
	if tool().get("id") != "path" or batches != 1 or kinds != ["path", "land"] or not ghost_ok:
		bad.append("tool %s, %d batches, kinds %s, ghost %s" % [tool().get("id"), batches, str(kinds), ghost_ok])
	var pid: int = int(ops[0].id) if not ops.is_empty() else 0
	var inf: Dictionary = paths.info.get(pid, {})
	var want_tris := 0
	var missing := []
	if not inf.is_empty():
		want_tris = (inf.secs.size() - 1) * (inf.rows.size() - 1) * 2
		for c: Vector2i in inf.chunks:
			var d: Dictionary = paths.drawn.get(c, {})
			if d.is_empty() or (d.nodes as Array).is_empty() or int(d.tris) <= 0:
				missing.append(str(c))
	var f: Dictionary = paths.figures()
	if pid != 1 or inf.is_empty() or not missing.is_empty() or int(f.tris) != want_tris or int(f.chunks) != (inf.chunks as Array).size():
		bad.append("id %d, chunks %s missing %s, tris %d want %d" % [pid, str(inf.get("chunks", [])), str(missing), int(f.tris), want_tris])
	var clear := clearance()
	if float(clear[0]) < -0.02:
		bad.append("the ground pokes 2 cm or more through the ribbon (least clearance %.3f m)" % clear[0])
	figures["lay"] = tool().last
	say("lay", bad.is_empty(), "3 points + RMB: 1 batch %s; path %d, %.1f m long, %d sections x %d rows; %d chunk(s) %s, %d triangles (= sections-1 x rows-1 x 2: %d), %d vertices; ribbon clearance over the drawn ground: least %.3f m, median %.3f m over %d points; ghost followed the cursor %s%s" % [
		str(kinds), pid, float(inf.sm.len) if not inf.is_empty() else 0.0, (inf.secs as Array).size() if not inf.is_empty() else 0,
		(inf.rows as PackedFloat32Array).size() if not inf.is_empty() else 0, int(f.chunks), str(inf.get("chunks", [])), int(f.tris), want_tris,
		int(f.verts), clear[0], clear[1], clear[2], ghost_ok, "" if bad.is_empty() else "; BAD " + "; ".join(bad)])
	grade_case(ops, inf.sm if not inf.is_empty() else sm, h)


## [least, median, count]: the ribbon's height over the land's drawn surface at every triangle's centre and edge middles.
func clearance() -> Array:
	var gaps := PackedFloat32Array()
	for c: Vector2i in paths.by_chunk:
		var ids: Array = (paths.by_chunk[c] as Dictionary).keys()
		var a: Dictionary = paths._mesher().chunk_arrays(c, ids, paths.info, paths.index)
		var t: Dictionary = a.terrain
		if t.is_empty():
			continue
		var pos: PackedVector3Array = t.pos
		var idx: PackedInt32Array = t.idx
		for k: int in range(0, idx.size(), 3):
			var p0 := pos[idx[k]]
			var p1 := pos[idx[k + 1]]
			var p2 := pos[idx[k + 2]]
			for q: Vector3 in [(p0 + p1 + p2) / 3.0, (p0 + p1) * 0.5, (p1 + p2) * 0.5, (p0 + p2) * 0.5]:
				gaps.append(q.y - float(land.drawn_height_at(q.x, q.z)))
	if gaps.is_empty():
		return [0.0, 0.0, 0]
	gaps.sort()
	return [gaps[0], gaps[gaps.size() / 2], gaps.size()]


func grade_case(ops: Array, sm: Dictionary, h: float) -> void:
	var bad := []
	var verts: Array = ops[1].verts if ops.size() == 2 else []
	var worst := 0.0
	var big := 0
	for e: Array in verts:
		var q := Vector2(int(e[0]) * 3.0, int(e[1]) * 3.0)
		var d: float = PathShape.nearest(sm.p, q)[0]
		worst = maxf(worst, d)
		if absi(int(e[3]) - int(e[2])) > 150:
			big += 1
	var after := cross(sm, h)
	var before: float = figures.cross_before
	if verts.is_empty() or worst > h + 3.0 + 0.01 or big > 0 or after > before * 0.5:
		bad.append("%d vertices, farthest %.2f m (limit %.2f), %d over 1.5 m, cross slope %.1f -> %.1f cm" % [verts.size(), worst, h + 3.0, big, before, after])
	var moved := 0
	for e: Array in verts:
		moved = maxi(moved, absi(int(e[3]) - int(e[2])))
	say("grade", bad.is_empty(), "land op of %d vertices in the same batch, all within %.2f m of the centre line (limit h + 3 = %.2f m), the largest move %d cm (limit 150), cross slope at the edges %.1f -> %.1f cm, %d vertex(es) skipped%s" % [
		verts.size(), worst, h + 3.0, moved, before, after, int(tool().last.get("skipped", 0)), "" if bad.is_empty() else "; BAD " + "; ".join(bad)])


func skip_case() -> void:
	var bad := []
	var c := site + Vector2(0.0, 30.0)
	var pts := [c + Vector2(-15.0, 0.0), c + Vector2(15.0, 0.0)]
	# a block on the lattice vertex 3 m beside the centre line (inside the grading's reach, outside the path)
	var v := Vector2i(roundi(c.x / 3.0), roundi(c.y / 3.0) + 1)
	var bx := Vector3i(v.x * 3, int(floorf(land.height_at(v.x * 3.0, v.y * 3.0))), v.y * 3)
	var placed: Dictionary = b.place(bx, Blocks.code(Blocks.CUBE, 1))
	var before: int = land.cm_at(v)
	over(Vector3(c.x, land.height_at(c.x, c.y), c.y)); await wait(3)   # F2: 30 m south the clicks fell on the hotbar's slots
	await click(pts[0])
	await click(pts[1])
	await click(pts[1] + Vector2(2.0, 0.0), MOUSE_BUTTON_RIGHT)
	b.flush()
	var last: Dictionary = tool().last
	var ops := last_ops()
	if not bool(placed.ok) or not bool(last.ok) or int(last.skipped) < 1 or str(last.skip_reason) != "blocks" or land.cm_at(v) != before or ops.size() != 2:
		bad.append("block placed %s, lay %s, skipped %d '%s', vertex %d -> %d, ops %d" % [placed.ok, str(last.ok), int(last.get("skipped", 0)),
			str(last.get("skip_reason", "")), before, land.cm_at(v), ops.size()])
	say("skip", bad.is_empty(), "a block at %s beside a 30 m path: the path lays (%s), %d vertex(es) left out ('%s'), the one under the block stays at %d cm%s" % [
		str(bx), str(last.get("ok")), int(last.get("skipped", 0)), str(last.get("skip_reason", "")), land.cm_at(v), "" if bad.is_empty() else "; BAD " + "; ".join(bad)])
	await ctrl_tap(KEY_Z)
	b.undo()                                   # the block
	b.flush(); over(Vector3(site.x, land.height_at(site.x, site.y), site.y)); await wait(3)


func undo_case() -> void:
	var bad := []
	var snap_laid := snapshot(PathShape.box_of(paths.info[1].sm.p, paths.info[1].h + 6.0)) if paths.info.has(1) else {}
	var chunks: Array = paths.info[1].chunks if paths.info.has(1) else []
	await ctrl_tap(KEY_Z)
	b.flush()
	var gone: bool = paths.size() == 0 and snapshot(PathShape.box_of(PathShape.sample(rec_of(main_pts, 300).pts).p, 1.5 + 6.0)) == figures.snap
	var meshes_gone := chunks.all(func(c: Vector2i) -> bool: return not paths.drawn.has(c))
	await ctrl_tap(KEY_Y)
	b.flush()
	var back: bool = paths.size() == 1 and paths.info.has(1) and snapshot(PathShape.box_of(paths.info[1].sm.p, paths.info[1].h + 6.0)) == snap_laid
	var meshes_back := chunks.all(func(c: Vector2i) -> bool: return paths.drawn.has(c))
	if not gone or not meshes_gone or not back or not meshes_back:
		bad.append("undo: gone %s, meshes gone %s; redo: back %s, meshes back %s" % [gone, meshes_gone, back, meshes_back])
	say("undo", bad.is_empty(), "Ctrl+Z: the path and every graded vertex back exactly %s, its %d chunk mesh(es) gone %s; Ctrl+Y: both back %s %s%s" % [
		gone, chunks.size(), meshes_gone, back, meshes_back, "" if bad.is_empty() else "; BAD " + "; ".join(bad)])


func unpath_case() -> void:
	var bad := []
	await tap(KEY_0)
	await click(main_pts[1])
	b.flush()
	var ops := last_ops()
	var whole: bool = ops.size() == 1 and ops[0].op == "unpath" and int(ops[0].id) == 1 and (ops[0].pts as Array).size() == 3 and int(ops[0].width_cm) == 300 and ops[0].paint == "dirt"
	var gone: bool = paths.size() == 0 and paths.drawn.is_empty()
	await ctrl_tap(KEY_Z)
	b.flush()
	var back: bool = paths.size() == 1 and paths.paths.has(1)
	await tap(KEY_1)
	if not whole or not gone or not back:
		bad.append("op %s, gone %s, back %s" % [str(ops).left(160), gone, back])
	say("unpath", bad.is_empty(), "0 then LMB on the path: one unpath op naming the whole path %s, gone with its meshes %s; Ctrl+Z gives it back %s%s" % [
		whole, gone, back, "" if bad.is_empty() else "; BAD " + "; ".join(bad)])


func ids_case() -> void:
	var bad := []
	var c := site + Vector2(0.0, -30.0)
	await click(c + Vector2(-10.0, 0.0))
	await click(c + Vector2(10.0, 0.0))
	await click(c + Vector2(12.0, 0.0), MOUSE_BUTTON_RIGHT)
	var second: int = int(tool().last.get("id", 0))
	var n0: int = b.edits.history.size()
	var p := rec_of([c + Vector2(-10.0, 6.0), c + Vector2(10.0, 6.0)], 300)
	var got := {}
	got["taken"] = str(b.apply(p).reason)
	got["width"] = str(b.apply(_with(p, "width_cm", 900, 9)).reason)
	got["narrow"] = str(b.apply(_with(p, "width_cm", 100, 9)).reason)
	got["paint"] = str(b.apply(_with(p, "paint", "lava", 9)).reason)
	got["spacing"] = str(b.apply(_with(p, "pts", [[0, 0], [50, 0]], 9)).reason)
	got["far"] = str(b.apply(_with(p, "pts", [[0, 0], [5000, 0]], 9)).reason)
	got["village"] = str(b.apply(_with(p, "pts", [[0, 0], [1000, 0]], 9)).reason)
	got["no path"] = str(b.apply(_with(_with(p, "op", "unpath", 9), "id", 77, 77)).reason)
	var want := {"taken": "id 1 is taken (the next free id is 3)", "width": "width_cm must be an integer 150..800", "narrow": "width_cm must be an integer 150..800",
		"paint": "paint must be one of", "spacing": "pts: consecutive points are 100-4800 cm apart (50)", "far": "pts: consecutive points are 100-4800 cm apart (5000)",
		"village": "village", "no path": "no path 77"}
	for k: String in want:
		if not str(got[k]).begins_with(want[k]):
			bad.append("%s: '%s'" % [k, got[k]])
	if second != 2 or paths.next_id() != 3 or b.edits.history.size() != n0:
		bad.append("second id %d, next %d, logged %d" % [second, paths.next_id(), b.edits.history.size() - n0])
	var parts := []
	for k: String in got:
		parts.append("%s '%s'" % [k, got[k]])
	say("ids", bad.is_empty(), "the second path is id %d, next free %d; %s; none logged%s" % [second, paths.next_id(), "; ".join(parts),
		"" if bad.is_empty() else "; BAD " + "; ".join(bad)])


static func _with(op: Dictionary, k: String, v: Variant, n: int) -> Dictionary:
	var o := op.duplicate(true)
	o[k] = v
	o["id"] = n
	return o


func enter_case() -> void:
	var bad := []
	var c := site + Vector2(0.0, -50.0)
	await look(c)
	await wheel(true)
	await wheel(true)
	var w: int = tool().width_cm
	await click(c + Vector2(-12.0, 0.0))
	await click(c + Vector2(0.0, 3.0))
	await click(c + Vector2(4.0, 3.0))
	await tap(KEY_BACKSPACE)
	var n_draft: int = (tool().pts as Array).size()
	var n0: int = paths.size()
	key(KEY_ENTER, true)
	await wait(4)
	key(KEY_ENTER, false)
	await wait(3)
	var still: String = tool().get("id")
	var laid: bool = paths.size() == n0 + 1 and int(tool().last.get("id", 0)) == n0 + 1 and (paths.paths[n0 + 1].pts as Array).size() == 2
	var wide: bool = laid and int(paths.paths[n0 + 1].width_cm) == 400
	await wheel(false)
	await wheel(false)
	if w != 400 or n_draft != 2 or not laid or still != "path" or not wide:
		bad.append("width %d, draft after Backspace %d, laid %s, tool %s, reason '%s'" % [w, n_draft, laid, still, str(tool().reason)])
	say("enter", bad.is_empty(), "wheel up x2: %d cm; 3 points, Backspace: %d; Enter laid path %d (%s, %d cm wide) and the tool is still '%s'%s" % [
		w, n_draft, n0 + 1, laid, int(paths.paths[n0 + 1].width_cm) if laid else 0, still, "" if bad.is_empty() else "; BAD " + "; ".join(bad)])


func files_case() -> void:
	var bad := []
	var c := site + Vector2(-40.0, -40.0)
	var plank := rec_of([c, c + Vector2(12.0, 2.0)], 250, "plank", paths.next_id())
	var rp: Dictionary = b.apply(plank)
	b.flush()
	var pc: Vector2i = PathMesh.chunk_of(c + Vector2(6.0, 1.0))
	var board: bool = bool(rp.ok) and paths.drawn.has(pc) and (paths.drawn[pc].nodes as Array).any(func(n: Node) -> bool: return str(n.name).begins_with("Slabs"))
	var h0: String = paths.content_hash()
	var m0: Dictionary = paths.figures().hashes
	var d1 := TMP.path_join("a")
	var d2 := TMP.path_join("b")
	var why1: String = b.save(d1)
	var t1 := FileAccess.get_file_as_string(d1.path_join("build.json"))
	var r: Dictionary = b.load(d1)
	b.flush()
	var m1: Dictionary = paths.figures().hashes
	var why2: String = b.save(d2)
	var t2 := FileAccess.get_file_as_string(d2.path_join("build.json"))
	if why1 != "" or why2 != "" or t1 != t2 or not r.ok or paths.content_hash() != h0 or str(m0) != str(m1):
		bad.append("save '%s', load %s, save '%s', same bytes %s, same paths %s, same meshes %s" % [why1, str(r.ok), why2, t1 == t2, paths.content_hash() == h0, str(m0) == str(m1)])
	if not t1.begins_with("{\"v\":3,") or t1.find("\"paths\":[{\"id\":1,\"pts\":[[") < 0 or t1.find("\"land\":") > t1.find("\"paths\":"):
		bad.append("head %s" % t1.substr(0, 80))
	# one more path journaled, then the file read back with its journal
	var extra := rec_of([c + Vector2(0.0, 10.0), c + Vector2(10.0, 10.0)], 200, "sand", paths.next_id())
	b.apply(extra)
	var h1: String = paths.content_hash()
	var r2: Dictionary = b.load(d2)
	b.flush()
	var replay_ok: bool = r2.ok and int(r2.replayed) == 1 and paths.content_hash() == h1
	if not replay_ok or not board:
		bad.append("journal replay %s (hash %s), boardwalk %s" % [str(r2), paths.content_hash() == h1, board])
	var start := t1.find("\"paths\":")
	say("files", bad.is_empty(), "tl.build/3 %d bytes, %s...; save -> load -> save byte-identical %s, %d chunk mesh hashes the same %s; one more path journaled and replayed %s; a plank path draws a boardwalk %s%s" % [
		t1.length(), t1.substr(start, 70), t1 == t2, m0.size(), str(m0) == str(m1), replay_ok, board, "" if bad.is_empty() else "; BAD " + "; ".join(bad)])


class FakeWater:
	extends RefCounted
	var id := "water"
	var box := Rect2i()

	func water_runs(lo: Vector3i, hi: Vector3i) -> Array:
		var runs := []
		for z: int in range(maxi(lo.z, box.position.y), mini(hi.z, box.end.y - 1) + 1):
			runs.append([z, maxi(lo.x, box.position.x), mini(hi.x, box.end.x - 1)])
		return [{"y": 0, "runs": runs}]


func scatter_case() -> void:
	var bad := []
	var c := site + Vector2(60.0, 60.0)
	var centre := Vector3(c.x, land.height_at(c.x, c.y), c.y)
	var t0 := Time.get_ticks_usec()
	var a: Array = PlantScatter.scatter(b, centre, 10.0, "tree", 3.0, 11)
	var us := Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	var a2: Array = PlantScatter.scatter(b, centre, 10.0, "tree", 3.0, 11)
	var us2 := Time.get_ticks_usec() - t0
	var other: Array = PlantScatter.scatter(b, centre, 10.0, "tree", 3.0, 12)
	var want := 3.0 * PI * 100.0 / 100.0
	var bushes: Array = PlantScatter.scatter(b, centre, 8.0, "bush", 6.0, 5)
	var want_b := 6.0 * PI * 64.0 / 100.0
	if a != a2 or a == other or absf(a.size() - want) > want * 0.2 or absf(bushes.size() - want_b) > want_b * 0.2:
		bad.append("same %s, another seed differs %s, trees %d (want %.1f), bushes %d (want %.1f)" % [a == a2, a != other, a.size(), want, bushes.size(), want_b])
	var looks := {}
	for o: Dictionary in a:
		looks[str(o.get("params", {})) + str(int(o.seed) % 4)] = true
	# none on a path: a disc over the first path
	var on_path: Array = PlantScatter.scatter(b, Vector3(main_pts[1].x, 0.0, main_pts[1].y), 8.0, "bush", 8.0, 3)
	var bad_path := on_path.filter(func(o: Dictionary) -> bool: return paths.covers(float(o.at[0]) + 0.5, float(o.at[2]) + 0.5, 0.5))
	# none in water: a test water layer over the west half of the disc
	var wl := FakeWater.new()
	wl.box = Rect2i(floori(c.x) - 20, floori(c.y) - 20, 20, 40)
	var wi: int = b.layers.find(b.layer("water"))
	var keep: RefCounted = b.layers[wi]
	b.layers[wi] = wl
	var dry: Array = PlantScatter.scatter(b, centre, 10.0, "tree", 3.0, 11)
	b.layers[wi] = keep
	var wet := dry.filter(func(o: Dictionary) -> bool: return wl.box.has_point(Vector2i(int(o.at[0]), int(o.at[2]))))
	# none in a protected cell; the batch applies whole, one undo
	var refused := a.filter(func(o: Dictionary) -> bool: return str(b.protect.refusal_area(Rect2(int(o.at[0]), int(o.at[2]), 1, 1), "plant")) != "")
	var n0: int = b.layer("pieces").size()
	var r: Dictionary = b.apply(a)
	var applied: int = b.layer("pieces").size() - n0
	b.undo()
	var undone: bool = b.layer("pieces").size() == n0
	if not bad_path.is_empty() or not wet.is_empty() or dry.size() >= a.size() or not refused.is_empty() or not bool(r.ok) or applied != a.size() or not undone:
		bad.append("on the path %d, in water %d (of %d), refused cells %d, batch %s applied %d of %d, undone %s" % [bad_path.size(), wet.size(), dry.size(),
			refused.size(), str(r.reason), applied, a.size(), undone])
	say("scatter", bad.is_empty(), "10 m disc, 3 trees per 100 m2: %d puts (want %.1f +-20 %%) in %.1f ms (%.1f ms again, the prototypes built), the same args the same puts %s, seed 12 others %s, %d looks; 8 m disc of bushes at 6: %d (want %.1f); over the path: %d puts, %d on it; half the disc water: %d puts, %d in it; in protected cells %d; one batch applied %d, one undo %s%s" % [
		a.size(), want, us / 1000.0, us2 / 1000.0, a == a2, a != other, looks.size(), bushes.size(), want_b, on_path.size(), bad_path.size(), dry.size(), wet.size(),
		refused.size(), applied, undone, "" if bad.is_empty() else "; BAD " + "; ".join(bad)])


func cost_case() -> void:
	var usec: Array = (paths.stats.usec as Array).duplicate()
	usec.sort()
	var steps: Array = (paths.stats.step_usec as Array).duplicate()
	steps.sort()
	var lay: Dictionary = figures.get("lay", {})
	# the tool aiming with a draft of 2 points: the ghost follows the cursor every frame
	var c := site + Vector2(-20.0, 50.0)
	await look(c)
	await click(c)
	await click(c + Vector2(20.0, 4.0))
	var aims := []
	for f: int in 30:
		point(c + Vector2(30.0, 4.0 + f * 0.4))
		var t0 := Time.get_ticks_usec()
		tool().aim(bm.call("_pick"), {})
		aims.append(Time.get_ticks_usec() - t0)
	aims.sort()
	# RMB lays the 2-point draft: the frames of the lay and after, and who spent them
	point(c + Vector2(20.0, 4.0))
	await wait(3)
	var lm0: int = (land.stats.mesh_usec as Array).size()
	var lb0: int = (land.stats.body_usec as Array).size()
	var ps0: int = (paths.stats.step_usec as Array).size()
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = true
	e.position = bm.get("pointer")
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	var frames := []
	for f: int in 6:
		var t0 := Time.get_ticks_usec()
		await physics_frame
		frames.append(Time.get_ticks_usec() - t0)
		if f == 0:
			e = e.duplicate()
			e.pressed = false
			Input.parse_input_event(e)
			Input.flush_buffered_events()
	var sum := func(a: Array, from: int) -> float: return a.slice(from).reduce(func(x: int, y: int) -> int: return x + y, 0) / 1000.0
	var lay2: Dictionary = tool().last
	var ok: bool = not usec.is_empty() and int(lay.get("usec", 0)) > 0 and bool(lay2.get("ok", false))
	say("cost", ok, "laying the first path (60 m, 3 points, %d graded vertices): %.1f ms; chunk meshes drawn %d, median %.2f ms, max %.2f ms of work each, spread over frames: a frame's drawing median %.2f ms, max %.2f ms (%d frames); the tool's aim with a 2-point draft and the ghost following: median %.2f ms, max %.2f ms; a 20 m path laid by RMB: frames %s ms (the lay %.1f ms; then land meshes %.1f ms, land bodies %.1f ms, path drawing %.1f ms in all)" % [
		int(lay.get("graded", 0)), int(lay.get("usec", 0)) / 1000.0, usec.size(), (usec[usec.size() / 2] if not usec.is_empty() else 0) / 1000.0,
		(usec[usec.size() - 1] if not usec.is_empty() else 0) / 1000.0, (steps[steps.size() / 2] if not steps.is_empty() else 0) / 1000.0,
		(steps[steps.size() - 1] if not steps.is_empty() else 0) / 1000.0, steps.size(), aims[aims.size() / 2] / 1000.0, aims[aims.size() - 1] / 1000.0,
		str(frames.map(func(u: int) -> float: return snappedf(u / 1000.0, 0.1))), int(lay2.get("usec", 0)) / 1000.0, sum.call(land.stats.mesh_usec, lm0),
		sum.call(land.stats.body_usec, lb0), sum.call(paths.stats.step_usec, ps0)])
