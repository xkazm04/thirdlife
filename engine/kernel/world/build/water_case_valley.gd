extends RefCounted
## M5 lane W (spark world-sandbox): the part of water_case.gd that needs the Home's valley (res://boot/village.json's
## landscape, the Home grown by home/hook.gd, build mode mounted): water.river, water.tool, water.scatter, water.cost.
## The tool is driven as a person drives it (B, T, the pointer on the ground, LMB, the wheel, Ctrl+Z). Frames counted.

const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const WaterFill := preload("res://kernel/world/build/water_fill.gd")
const TMP := "user://tl_water_case/valley"
const CAM_H := 40.0

var t = null                             # the case (water_case.gd: a SceneTree with `say`)
var node: Node3D
var ws: Object
var home: RefCounted
var bm: Node
var b: RefCounted
var land: RefCounted
var w: RefCounted
var cam: Camera3D
var far := Vector3.ZERO
var pour_fill := {}


func run(tree: SceneTree) -> void:
	t = tree
	node = CaseUtil.landscape(t.root, CaseUtil.walk())
	if not node.has_meta(&"tl_build_mode"):
		t.say("river", false, "no build mode: home/hook.gd did not mount it")
		return
	ws = node.get_meta(&"tl_space")
	home = node.get_meta(&"tl_home")
	bm = node.get_meta(&"tl_build_mode")
	b = node.get_meta(&"tl_build")
	land = b.layer("land")
	w = b.layer("water")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP))
	bm.call("open", TMP)
	cam = Camera3D.new()
	cam.fov = 60.0
	t.root.add_child(cam)
	cam.current = true
	bm.set("cam", cam)
	t.root.size = Vector2i(1280, 720)
	await wait(3)
	river_case()
	var site := find_site()
	far = Vector3(site.x + 300.0, 0.0, site.y + 300.0)
	bm.set("feet_at", func() -> Vector3: return far)
	b.protect.visitor_at = func() -> Vector3: return far
	home.ensure(site)
	await tool_case(site)
	await scatter_case()
	cost_case()
	bm.set("feet_at", Callable())             # the lambdas hold this object: no cycle left behind
	b.protect.visitor_at = Callable()


func wait(n: int) -> void:
	for i in n:
		await t.physics_frame


func vtx(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x / 3.0), roundi(p.y / 3.0))


func free_for(v: Vector2i, r: int) -> bool:
	for j: int in range(-r, r + 1):
		for i: int in range(-r, r + 1):
			if land.refusal(v + Vector2i(i, j), "land") != "":
				return false
	return true


## A chunk corner 384..1536 m east whose vertices within 21 m nothing protects (as land_case.gd's site).
func find_site() -> Vector2:
	for cz: int in range(-5, 7):
		for cx: int in range(4, 16):
			var c := Vector2(cx * 96.0 + 48.0, cz * 96.0 + 48.0)
			if free_for(vtx(c), 7):
				return c
	return Vector2(816.0, 48.0)


func over(p: Vector3, h := CAM_H) -> void:
	cam.look_at_from_position(p + Vector3(0.0, h, 0.01), p, Vector3.FORWARD)
	cam.reset_physics_interpolation()


func key(k: Key, down: bool, shift := false) -> void:
	CaseUtil.key(k, down, shift)


func tap(k: Key) -> void:
	key(k, true)
	await wait(2)
	key(k, false)
	await wait(2)


func button(bi: MouseButton, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = bi
	e.pressed = down
	e.position = bm.get("pointer")
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func click(bi := MOUSE_BUTTON_LEFT) -> void:
	button(bi, true)
	await wait(2)
	button(bi, false)
	await wait(2)


func point(p: Vector2) -> void:
	var q := p + Vector2(0.23, 0.31)
	bm.set("pointer", cam.unproject_position(Vector3(q.x, land.height_at(q.x, q.y), q.y)))


## A hollow dug at `c` (metres): every vertex within `r` lattice units lowered by `depth` cm on a cosine. "" or why.
func dig(c: Vector2, r: float, depth: int) -> String:
	var verts := []
	var v0 := vtx(c)
	var n := ceili(r)
	for j: int in range(-n, n + 1):
		for i: int in range(-n, n + 1):
			var v := v0 + Vector2i(i, j)
			var d := Vector2(v.x * 3.0 - c.x, v.y * 3.0 - c.y).length() / (r * 3.0)
			if d < 1.0:
				var now: int = land.cm_at(v)
				verts.append([v.x, v.y, now, now - roundi(depth * (0.5 + 0.5 * cos(PI * d)))])
	return str(b.apply({"op": "land", "verts": verts}).reason)


# ------------------------------------------------------------------ cases
func river_case() -> void:
	var v: RefCounted = land.ground().valley
	var bad := []
	var got := {}
	got["band"] = w.refusal_cells([Vector2i(floori((v.river_x(800.0) + 30.0) / 3.0), floori(800.0 / 3.0))])
	got["game lot"] = w.refusal_cells([Vector2i(floori(float(v.sites[0].centre[0]) / 3.0), floori(float(v.sites[0].centre[1]) / 3.0))])
	got["village"] = w.refusal_cells([Vector2i(0, 0)])
	# beyond the land's 71 m band: a vertex the land may lower below the river's level, inside the ribbon's reach
	var dug := {}
	var counted := 0
	var diggable := 0
	for zi: int in range(-55, 56):
		var z := zi * 24.0
		for side: float in [-1.0, 1.0]:
			for d: float in range(75, 157, 6):
				var x: float = v.river_x(z) + side * d
				var vv := vtx(Vector2(x, z))
				if land.refusal(vv, "land") != "":
					continue
				counted += 1
				var lvl := roundi(float(v.level(vv.y * 3.0)) * 100.0)
				if land.cm_at(vv) - 2400 < lvl - 100:
					diggable += 1
					if dug.is_empty() and free_for(vv, 1):
						dug = {"v": vv, "level": lvl, "d": d, "ground": land.cm_at(vv)}
	if not dug.is_empty():
		var vv: Vector2i = dug.v
		var verts := []
		for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			verts.append([vv.x + o.x, vv.y + o.y, int(land.cm_at(vv + o)), int(dug.level) - 100])
		dug["land"] = str(b.apply({"op": "land", "verts": verts}).reason)
		got["ribbon"] = w.refusal_cells([vv])
		var cut: Dictionary = w.plan(vv)
		got["ribbon pour"] = str(cut.reason)
		b.undo()
	var want := {"band": "spills into the river", "game lot": "spills: game lot", "village": "spills: village",
		"ribbon": "spills into the river", "ribbon pour": "spills into the river"}
	# M5 integration: the land now refuses that dig itself (lane L, PATCHES-W W3: "river (its water would show ...)"), so
	# no such hollow can be made; the water's own refusal is then moot. Any other refusal of the dig is still a failure.
	var land_refuses: bool = not dug.is_empty() and str(dug.land).begins_with("river")
	if land_refuses:
		want.erase("ribbon")
		want.erase("ribbon pour")
	for k: String in want:
		if str(got.get(k, "(none)")) != want[k]:
			bad.append("%s: '%s'" % [k, str(got.get(k, "(none)"))])
	if not dug.is_empty() and str(dug.land) != "" and not land_refuses:
		bad.append("the dig was refused: %s" % dug.land)
	var parts := []
	for k: String in got:
		parts.append("%s '%s'" % [k, got[k]])
	t.say("river", bad.is_empty(), "%s; MEASURED: of %d vertices 75-156 m from the river's line that the land lets a person sculpt, %d can be dug 1 m under the river's level (inside the ribbon's reach: the river's water plane would show in such a hollow); one at %s, %d m out, ground %.1f m, river %.1f m, dug to %.1f m: '%s'%s" % [
		"; ".join(parts), counted, diggable, str(dug.get("v", "-")), int(dug.get("d", 0)), int(dug.get("ground", 0)) / 100.0,
		int(dug.get("level", 0)) / 100.0, (int(dug.get("level", 0)) - 100) / 100.0, str(dug.get("land", "-")), "" if bad.is_empty() else "; BAD " + "; ".join(bad)])


func tool_case(site: Vector2) -> void:
	var bad := []
	var c := site + Vector2(1.5, 1.5)
	var why := dig(c, 2.6, 250)
	b.flush()
	over(Vector3(c.x, land.height_at(c.x, c.y), c.y))
	await wait(4)
	var tags0: int = (ws.get("_tags") as Dictionary).size()
	await tap(KEY_B)
	for i: int in 8:
		if str(bm.call("tool").get("id")) == "water":
			break
		await tap(KEY_T)
	var tool: RefCounted = bm.call("tool")
	point(c)
	await wait(3)
	var plan: Dictionary = tool.get("plan")
	pour_fill = plan.get("fill", {})
	var info0: String = tool.call("info")
	var ghost: Node3D = tool.get("shown")
	var ghost_cells: int = int(ghost.get_child(0).get_meta(&"tl_cells", 0)) if ghost != null and ghost.get_child_count() > 0 else 0
	# the wheel: two notches down, then back
	for k: int in 2:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_WHEEL_DOWN
		e.pressed = true
		e.position = bm.get("pointer")
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await wait(2)
	await wait(2)
	var info_low: String = tool.call("info")
	var low_level := int((tool.get("plan") as Dictionary).get("fill", {}).get("level", 0))
	await tap(KEY_BRACKETRIGHT)
	await tap(KEY_BRACKETRIGHT)
	var n0: int = b.edits.history.size()
	await click()
	var batches: int = b.edits.history.size() - n0
	var poured: int = w.size()
	b.flush()
	await wait(2)
	# the drawing
	var looks := []
	var shadows_off := true
	var uv_ok := true
	var tris := 0
	for ch: Vector2i in w.mesh.nodes:
		var mi: MeshInstance3D = w.mesh.nodes[ch]
		shadows_off = shadows_off and mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tris += int(w.mesh.tris[ch])
		for s: int in mi.mesh.get_surface_count():
			looks.append(mi.mesh.surface_get_material(s) == TLStyle.material("water"))
			var uv: PackedVector2Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_TEX_UV]
			for q: Vector2 in uv:
				uv_ok = uv_ok and q.x < -0.5
	var tags1: int = (ws.get("_tags") as Dictionary).size()
	var top := Vector3(c.x + 0.4, 60.0, c.y + 0.3)
	var hit: Dictionary = b.pick(top, top - Vector3(0, 120, 0))
	var bed: float = land.height_at(top.x, top.z)
	var lvl := float(pour_fill.get("level", 0)) / 100.0
	var through: bool = not hit.is_empty() and absf(float(hit.pos.y) - bed) < 0.05 and float(hit.pos.y) < lvl - 0.5
	var chunks: int = w.mesh.nodes.size()
	# Ctrl+Z, Ctrl+Y, then drain with 2 + LMB
	key(KEY_CTRL, true)
	await tap(KEY_Z)
	key(KEY_CTRL, false)
	b.flush()
	var undone: int = w.size()
	var meshes_after_undo: int = w.mesh.nodes.size()
	key(KEY_CTRL, true)
	await tap(KEY_Y)
	key(KEY_CTRL, false)
	var redone: int = w.size()
	await tap(KEY_2)
	point(c)
	await wait(3)
	var drain_info: String = tool.call("info")
	await click()
	var drained: int = w.size()
	await tap(KEY_1)
	await tap(KEY_B)
	var f := pour_fill
	var ok: bool = why == "" and str(tool.get("id")) == "water" and str(f.get("reason", "?")) == "" and ghost_cells == (f.get("cells", []) as Array).size() \
		and info0.begins_with("pour: %d cells" % ghost_cells) and info_low.contains("lowered 0.50 m") and low_level == int(f.get("level", 0)) - 50 \
		and batches == 1 and poured == ghost_cells and looks.all(func(x: bool) -> bool: return x) and not looks.is_empty() and uv_ok and shadows_off \
		and tags1 == tags0 and through and undone == 0 and meshes_after_undo == 0 and redone == poured and drained == 0 and drain_info.begins_with("drain: %d" % poured)
	if not ok:
		bad.append("dig '%s', tool %s, reason '%s', ghost %d, info '%s' / '%s' (%d), batches %d, poured %d, water look %s, uv %s, shadows off %s, tags %d -> %d, ray %s bed %.2f, undo %d (%d meshes), redo %d, drain '%s' -> %d" % [
			why, tool.get("id"), str(f.get("reason", "?")), ghost_cells, info0, info_low, low_level, batches, poured, str(looks), uv_ok, shadows_off,
			tags0, tags1, str(hit.get("pos", "-")), bed, undone, meshes_after_undo, redone, drain_info, drained])
	t.say("tool", ok, "a hollow 15.6 m across, 2.5 m deep at %s; B, T x5 -> water; the ghost %d holo cells ('%s'); wheel down x2: '%s'; ] x2 back; LMB: one batch of %d cells at %.2f m (spill %.2f m, floor %.2f m); %d chunk mesh(es), %d tris, the water material, UV.x -1 (still water) %s, shadows off %s, space tags %d -> %d (no body); the cursor ray at the middle meets the bed at %.2f m (water %.2f m) %s; Ctrl+Z -> %d cells, %d meshes; Ctrl+Y -> %d; 2: '%s', LMB -> %d%s" % [
		str(c), ghost_cells, info0, info_low.get_slice("   ", 1) if info_low.contains("   ") else info_low, poured, lvl, int(f.get("spill", 0)) / 100.0,
		int(f.get("floor", 0)) / 100.0, chunks, tris, uv_ok, shadows_off, tags0, tags1, float(hit.get("pos", Vector3.ZERO).y) if not hit.is_empty() else 0.0, lvl, through,
		undone, meshes_after_undo, redone, drain_info, drained, "" if bad.is_empty() else "; BAD " + "; ".join(bad)])
	b.undo()                                      # the dig


## A valley tree or reed in a free, gentle spot: its cell's corners lowered 40 cm (the land moves it, not hides it),
## the hollow round it 1.5 m under the lowest ground and a wall 1 m over the highest; poured, drained.
func scatter_case() -> void:
	var sc: RefCounted = land.scatter            # the land's scatter hides what stands in the water (PATCHES-W W1, lane L)
	var pick := []
	if sc != null:
		sc.call("_prepare")
		var ids: Array = (sc.by_chunk as Dictionary).keys()
		ids.sort()
		for id: Vector2i in ids:
			for cand: Array in sc.by_chunk[id]:
				var p: Vector3 = (cand[2] as Transform3D).origin
				var v := vtx(Vector2(p.x, p.z))
				if absf(p.x) > 1500.0 or absf(p.z) > 1500.0 or not free_for(v, 6) or w.refusal_cells([v]) != "":
					continue
				var low := 1 << 30
				var high := -(1 << 30)
				for j: int in range(-5, 6):
					for i: int in range(-5, 6):
						low = mini(low, int(land.cm_at(v + Vector2i(i, j))))
						high = maxi(high, int(land.cm_at(v + Vector2i(i, j))))
				if high - low < 300:
					pick = [cand, v, low, high, id]
					break
			if not pick.is_empty():
				break
	if pick.is_empty():
		t.say("scatter", false, "no valley tree or reed found in a free, gentle spot")
		return
	var e: Array = pick[0]
	var mm: MultiMesh = e[0]
	var idx: int = e[1]
	var xf: Transform3D = e[2]
	var p := xf.origin
	var c := Vector2i(floori(p.x / 3.0), floori(p.z / 3.0))
	var lo: int = pick[2]
	var hi: int = pick[3]
	home.ensure(Vector2(p.x, p.z))
	var verts := []
	for j: int in range(-5, 7):
		for i: int in range(-5, 7):
			var v := c + Vector2i(i, j)
			var d := Vector2(i - 0.5, j - 0.5).length()
			var now: int = land.cm_at(v)
			var to := now
			if i in [0, 1] and j in [0, 1]:
				to = now - 40
			elif d <= 3.2:
				to = lo - 150
			elif d <= 5.0:
				to = hi + 100
			if to != now:
				verts.append([v.x, v.y, now, to])
	var why := str(b.apply({"op": "land", "verts": verts}).reason)
	b.flush()
	var key_of := "%d:%d" % [mm.get_instance_id(), idx]
	var land_state := ""
	for r: Array in land.scatter.report(pick[4]):
		if (r[0] as Vector3).is_equal_approx(p):
			land_state = str(r[1])
	# (the headless renderer keeps no instance transforms: what the scatter set is read from its own record, `set_to`)
	var moved_y: float = land.delta_at(p.x, p.z)
	var f: Dictionary = w.plan(c)
	b.apply(w.pour_ops(c).ops)
	b.flush()
	var wet_state := ""
	for r: Array in land.scatter.report(pick[4]):
		if (r[0] as Vector3).is_equal_approx(p):
			wet_state = str(r[1])
	b.apply(w.drain_op(c))
	b.flush()
	var back_state := ""
	for r: Array in land.scatter.report(pick[4]):
		if (r[0] as Vector3).is_equal_approx(p):
			back_state = str(r[1])
	var ok: bool = why == "" and land_state == "moved" and absf(moved_y + 0.40) < 0.02 and str(f.reason) == "" and wet_state == "hidden" 		and back_state == "moved"
	t.say("scatter", ok, "an instance at %s (cell %s): the land lowered it %.2f m (%s); poured %d cells at %.2f m over its foot -> %s; drained -> %s%s" % [
		str(p.snapped(Vector3.ONE * 0.1)), str(c), moved_y, land_state, (f.cells as Array).size(), int(f.level) / 100.0, wet_state, back_state,
		"" if ok else "; BAD land '%s', fill '%s'" % [why, f.reason]])
	b.undo()


func cost_case() -> void:
	var fills: Array = w.stats.fill_usec
	var meshes: Array = w.mesh.stats.usec
	var checks: Array = w.stats.check_usec
	var sorted_m: Array = meshes.duplicate()
	sorted_m.sort()
	var f := pour_fill
	t.say("cost", not fills.is_empty() and not meshes.is_empty(), "the tool's pour: %d cells, the fill %.1f ms (%d vertices taken), its area checks %.1f ms; chunk mesh draws: %d, median %.2f ms, max %.2f ms; fills this run: %d, max %.1f ms" % [
		(f.get("cells", []) as Array).size(), int(f.get("usec", 0)) / 1000.0, int(f.get("explored", 0)), (int(checks.max()) if not checks.is_empty() else 0) / 1000.0,
		meshes.size(), (int(sorted_m[sorted_m.size() / 2]) if not sorted_m.is_empty() else 0) / 1000.0, (int(sorted_m.max()) if not sorted_m.is_empty() else 0) / 1000.0,
		fills.size(), (int(fills.max()) if not fills.is_empty() else 0) / 1000.0])
