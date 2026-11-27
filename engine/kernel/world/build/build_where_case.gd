extends SceneTree
## F2 (27 Nov 2026 day, the newcomer's playtest #3, #4, #6, #7): building where you stand, headless, in the landscape
## of res://boot/village.json (the Home grown by home/hook.gd, build mode mounted), driven as a person drives it: keys
## and buttons through the engine's input state, the pointer as mouse motion or build mode's `pointer` (the test
## hook's). A camera of the case's own looks down from 16 m. Frames, not wall clock. Run with `-- bar` (selftest 797:
## where.*) or `-- slope` (selftest 798: slope.*). Prints `HOME <case> ok|fail <detail>`, then `HOME where ok` (or
## fail) and `HOME DONE`.
##   where.tab     the pointer (mouse motion) on the Rules tab: the tab is hovered and a click picks the Rules tool;
##                 nothing is built, though the ray at that pixel meets the ground in reach (it would have before)
##   where.slot    the Blocks tab and then the "2 slab" slot clicked through build mode's `pointer` (the hook's way):
##                 the tool and the shape change; a click in the gap between two slots does nothing; the keys line
##                 under the bar is not a button (a click there builds, as in the world); a click in the world builds one
##   where.village Sculpt aimed inside the village: the reason "village", the refused cells round the cursor tinted,
##                 the where line says it as a sentence and, within 600 frames, "buildable ground <m> <way>"; that
##                 ground takes the land (protect.gd `refusal_area` says nothing)
##   where.lot     Stamps, the first starter aimed on a game lot: refused, its block ghost red, the lot's cells tinted,
##                 the where line "a game's lot ..." and the way to ground free of lots; over that ground the ghost is
##                 red exactly when the stamp is refused there
##   where.reach   the cursor past the reach (a camera 200 m up, the visitor beside it): the where line says
##                 "out of reach", and nothing is tinted
##   slope.door    a wall on natural ground whose blocks stand a cell over the feet of a person in front of it (the
##                 playtest's course: feet 2.90, cell 2, the Door's blocks cells 3 and 4): the Door preset placed by
##                 the Rules tool on its blocks holds the feet cell at every point of the columns in front and behind
##                 (the box as drawn before F2 held none), and E there opens it (rules_run.gd over a recording facade)
##   slope.pad     a Jump pad clicked on ground whose height is just under a whole metre (feet 2.95 read cell 3, the
##                 pad's cell is 2): the pad holds the feet cell at every point of its cell, and walking onto it launches

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const Presets := preload("res://kernel/world/build/rules_tool_presets.gd")
const RulesRun := preload("res://kernel/world/build/rules_run.gd")
const Buildable := preload("res://kernel/world/build/buildable.gd")
const BuildMode := preload("res://kernel/world/build/build_mode.gd")
const NEAR := Vector2i(700, -60)
const CAM_H := 16.0


class Rec extends "res://kernel/world/build/rules_facade.gd":
	var log := []
	func set_open(z: int, _box: Array, o: bool) -> void: log.append(["set_open", z, o])
	func launch(u: int, f: int) -> void: log.append(["launch", u, f])
	func look_taken(z: int, tk: bool) -> void: log.append(["look_taken", z, tk])
	func teleport(at: Vector3) -> void: log.append(["teleport", at])
	func say(tx: String, n: int) -> void: log.append(["say", tx, n])

var walk: Dictionary
var node: Node3D
var ws: Object
var bm: Node
var b: RefCounted
var home: RefCounted
var cam: Camera3D
var hb: CanvasLayer
var ok_all := true
var site := {}


func _initialize() -> void:
	call_deferred("run")


func say(case_name: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME %s %s %s" % [case_name, "ok" if ok else "fail", detail])


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func tap(k: Key) -> void:
	CaseUtil.key(k, true)
	await wait(2)
	CaseUtil.key(k, false)
	await wait(2)


func button(down: bool, at: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	e.global_position = at
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func move_mouse(px: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = px
	e.global_position = px
	e.relative = px - root.get_mouse_position()
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func click_px(px: Vector2) -> void:
	await wait(2)
	button(true, px)
	await wait(2)
	button(false, px)
	await wait(2)


func over(p: Vector3, h := CAM_H) -> void:
	cam.look_at_from_position(p + Vector3(0.0, h, 0.0), p, Vector3.FORWARD)
	cam.reset_physics_interpolation()


func ground(x: float, z: float) -> float:
	return float(ws.call("ground_at", x, z, 400.0))


func run() -> void:
	walk = CaseUtil.walk()
	TLStyle.set_headless(false)
	node = CaseUtil.landscape(root, walk)
	if not node.has_meta(&"tl_build_mode"):
		say("where.tab", false, "no build mode: home/hook.gd did not mount it")
		finish()
		return
	ws = node.get_meta(&"tl_space")
	bm = node.get_meta(&"tl_build_mode")
	b = node.get_meta(&"tl_build")
	home = node.get_meta(&"tl_home")
	hb = bm.get("hotbar")
	cam = Camera3D.new()
	cam.fov = 60.0
	root.add_child(cam)
	cam.current = true
	bm.set("cam", cam)
	root.size = Vector2i(1280, 720)
	site = find_site()
	over(Vector3(site.x + 2.5, site.y, site.z + 2.0))
	var away := Vector3(site.x + 2.5, site.y + 1.0, site.z + 40.0)
	bm.set("feet_at", func() -> Vector3: return away)
	await wait(3)
	await tap(KEY_B)
	await wait(4)
	var mode := "bar"
	for a: String in OS.get_cmdline_user_args():
		mode = a
	if mode == "slope":
		await door_case()
		await pad_case()
	else:
		await tab_case()
		await slot_case()
		await village_case()
		await lot_case()
		await reach_case()
	finish()


func finish() -> void:
	print("HOME where %s" % ("ok" if ok_all else "fail"))
	print("HOME DONE")
	quit(0)


## A patch near NEAR, 9 x 7 cells, flat within 0.6 m and free of every refusal (build_mode_case.gd's search).
func find_site() -> Dictionary:
	for k in 30:
		var sx := NEAR.x + 10 * k
		var sz := NEAR.y
		home.ensure(Vector2(sx, sz))
		var lo := INF
		var hi := -INF
		var clear := true
		for z in range(sz - 1, sz + 6):
			for x in range(sx - 1, sx + 8):
				var g := ground(x + 0.5, z + 0.5)
				lo = minf(lo, g)
				hi = maxf(hi, g)
				clear = clear and b.protect.call("refusal", Vector3i(x, int(floorf(g + 0.01)), z)) == ""
		if clear and hi - lo < 0.6:
			return {"x": sx, "y": int(floorf(lo)), "z": sz}
	return {"x": NEAR.x, "y": 0, "z": NEAR.y}


func tab_index(title: String) -> int:
	var names: Array = (bm.get("tools") as Array).map(func(x: RefCounted) -> String: return str(x.get("title")))
	return names.find(title)


func centre_of(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


# ------------------------------------------------------------------ the bar
func tab_case() -> void:
	bm.call("switch_tool", -int(bm.get("tool_index")))           # Blocks
	await wait(3)
	var ri := tab_index("Rules")
	var px := centre_of((hb.get("tools") as Array)[ri][0])
	var r: Array = bm.call("ray")
	move_mouse(px)
	await wait(3)
	var behind: Dictionary = {}
	r = bm.call("ray")
	if not r.is_empty():
		behind = b.pick(r[0], r[0] + r[1] * float(bm.call("reach", r[0])))
	var hover: Dictionary = bm.get("bar_hover")
	var ghost_hidden: bool = str((bm.get("ghost") as Node).get("shown")) == ""
	var total: int = b.blocks.total
	var hist: int = b.edits.history.size()
	await click_px(px)
	var now := str(bm.call("tool").get("id"))
	var ok: bool = now == "rules" and int(hover.get("tool", -1)) == ri and b.blocks.total == total and b.edits.history.size() == hist \
		and not behind.is_empty() and ghost_hidden
	say("where.tab", ok, "Rules tab at %s: hovered %s, ghost hidden %s, the ray behind it meets %s; a click: tool '%s', blocks %d -> %d, edits %d -> %d" % [
		str(px.round()), str(hover), ghost_hidden, str(behind.get("place", "nothing")), now, total, b.blocks.total, hist, b.edits.history.size()])


func slot_case() -> void:
	var px := centre_of((hb.get("tools") as Array)[tab_index("Blocks")][0])
	bm.set("pointer", px)
	await click_px(px)
	var on_blocks := str(bm.call("tool").get("id")) == "blocks"
	await wait(3)
	var total: int = b.blocks.total
	var hist: int = b.edits.history.size()
	var slot_px := centre_of((hb.get("slots") as Array)[1][0])  # "2 slab"
	bm.set("pointer", slot_px)
	await click_px(slot_px)
	var shape: int = bm.get("shape")
	# the gap between slot 1 and slot 2 (6 px): the bar's, nothing happens
	var r1: Rect2 = ((hb.get("slots") as Array)[0][0] as Control).get_global_rect()
	var r2: Rect2 = ((hb.get("slots") as Array)[1][0] as Control).get_global_rect()
	var gap_px := Vector2((r1.end.x + r2.position.x) * 0.5, r1.get_center().y)
	bm.set("pointer", gap_px)
	await click_px(gap_px)
	var none_built: bool = b.blocks.total == total and b.edits.history.size() == hist and int(bm.get("shape")) == 2
	# the keys line under the bar is not a button: a click there builds, as one in the open world does
	var help: Label = hb.get("help")
	var help_px := Vector2(help.get_global_rect().get_center().x, help.get_global_rect().get_center().y)
	var hits_ground: bool = not b.pick(cam.project_ray_origin(help_px), cam.project_ray_origin(help_px) + cam.project_ray_normal(help_px) * 60.0).is_empty()
	bm.set("pointer", help_px)
	await click_px(help_px)
	var through: bool = b.blocks.total == total + (1 if hits_ground else 0)
	var world_px := Vector2(640, 300)
	bm.set("pointer", world_px)
	await wait(3)
	var before_world: int = b.blocks.total
	await click_px(world_px)
	var built_one: bool = b.blocks.total == before_world + 1
	bm.set("pointer", Vector2(-1, -1))
	for i in 3:
		if b.blocks.total > total:
			b.undo()
	say("where.slot", on_blocks and shape == 2 and none_built and through and built_one, "Blocks tab: tool blocks %s; slot '2 slab' at %s: shape %d; the gap between slots at %s: nothing built %s; the keys line at %s (ground behind it %s) builds as the world does %s; a click in the world at %s built one %s (bar clicks %d)" % [
		on_blocks, str(slot_px.round()), shape, str(gap_px.round()), none_built, str(help_px.round()), hits_ground, through, str(world_px), built_one, int(bm.get("bar_clicks"))])
	bm.set("shape", 1)


func village_case() -> void:
	var land: RefCounted = b.layer("land")
	var border: Rect2 = land.ground().border
	var p := Vector2(border.position.x + border.size.x * 0.5, border.end.y + 20.0)    # in the band south of it
	home.ensure(p)
	await wait(2)
	var gy := ground(p.x, p.y)
	over(Vector3(p.x, gy, p.y))
	bm.set("feet_at", func() -> Vector3: return Vector3(p.x + 30.0, gy, p.y))
	bm.call("switch_tool", tab_index("Sculpt") - int(bm.get("tool_index")))
	move_mouse(Vector2(640, 360))
	await wait(4)
	var why := str(bm.get("reason"))
	var wh: RefCounted = bm.get("where")
	var tinted: int = (bm.get("tint") as Node).get("count")
	var first := str(bm.get("where_line"))
	var f := 0
	while f < 600 and not pointed(str(bm.get("where_line"))):
		await wait(1)
		f += 1
	var line := str(bm.get("where_line"))
	var found: Variant = wh.get("found")
	var free := ""
	if found is Vector2:
		free = str(b.protect.refusal_area(Rect2(found - Vector2(3, 3), Vector2(6, 6)), "land"))
	# where a person arrives: the search goes far; it ends within 600 frames (figures: its frames, a
	# sample's cost in microseconds, read from the wall clock and never judged)
	var q := Vector2(-60.0, 2.0)                    # where he arrives (the playtest pressed B there: 352 m to free ground)
	home.ensure(q)
	await wait(2)
	var qy := ground(q.x, q.y)
	over(Vector3(q.x, qy, q.y))
	bm.set("feet_at", func() -> Vector3: return Vector3(q.x + 30.0, qy, q.y))
	await wait(2)
	var g := 0
	while g < 600 and not pointed(str(bm.get("where_line"))):
		await wait(1)
		g += 1
	var far_line := str(bm.get("where_line"))
	var far_asked: int = wh.get("asked")
	var t0 := Time.get_ticks_usec()
	for i in 200:
		wh.free_at(b.protect, land, q + Vector2(float(i), 0.0))
	var us := float(Time.get_ticks_usec() - t0) / 200.0
	var ok: bool = why == "village" and tinted > 0 and first.begins_with(Buildable.SENTENCES["village"]) and pointed(line) \
		and found is Vector2 and (free == "" or free == "too close") and pointed(far_line)
	say("where.village", ok, "Sculpt at (%.0f, %.1f, %.0f): reason '%s', %d cells tinted; line '%s', after %d frames (%d samples) '%s'; that ground refuses '%s'; from where he arrives (%.0f, %.0f): '%s' after %d frames, %d samples, %.1f us a sample" % [
		p.x, gy, p.y, why, tinted, first, f, int(wh.get("asked")), line, free, q.x, q.y, far_line, g, far_asked, us])


func lot_case() -> void:
	var plot: Array = walk.plots[0].origin
	var p := Vector2(float(plot[0]) + 0.5, float(plot[2]) + 0.5)
	home.ensure(p)
	await wait(2)
	var gy := ground(p.x, p.y)
	over(Vector3(p.x, gy, p.y), 24.0)
	bm.set("feet_at", func() -> Vector3: return Vector3(p.x + 30.0, gy, p.y))
	bm.call("switch_tool", tab_index("Stamps") - int(bm.get("tool_index")))
	await wait(2)
	await tap(KEY_1)
	move_mouse(Vector2(640, 360))
	await wait(14)
	var t: RefCounted = bm.call("tool")
	var why := str(t.get("reason"))
	var red: bool = t.get("red_ghost")
	var tinted: int = (bm.get("tint") as Node).get("count")
	var f := 0
	while f < 600 and not pointed(str(bm.get("where_line"))):
		await wait(1)
		f += 1
	var line := str(bm.get("where_line"))
	var wh: RefCounted = bm.get("where")
	var found: Variant = wh.get("found")
	var lot_free := "-"
	var red2 := true
	var why2 := "-"
	if found is Vector2:
		var size: Vector2 = wh.get("size")
		lot_free = Buildable.lot_refusal(b.protect, Rect2(found - size * 0.5, size))
		home.ensure(found)
		await wait(2)
		var g2 := ground(found.x, found.y)
		over(Vector3(found.x, g2, found.y), 24.0)
		bm.set("feet_at", func() -> Vector3: return Vector3(found.x + 30.0, g2, found.y))
		await wait(16)
		red2 = t.get("red_ghost")
		why2 = str(t.get("reason"))
	var ok: bool = why.find("game lot") >= 0 and red and tinted > 0 and line.begins_with(Buildable.SENTENCES["game lot"]) \
		and pointed(line) and lot_free == "" and red2 == (why2 != "")
	say("where.lot", ok, "'%s' on lot %s: reason '%s', ghost red %s, %d cells tinted; line after %d frames '%s'; there: lots '%s', reason '%s', ghost red %s" % [
		str(t.call("stamp").get("name", "")), str(walk.plots[0].id), why, red, tinted, f, line, lot_free, why2, red2])


func reach_case() -> void:
	bm.call("switch_tool", -int(bm.get("tool_index")))
	var p := Vector3(site.x + 2.5, site.y, site.z + 2.0)
	home.ensure(Vector2(p.x, p.z))
	over(p, 200.0)
	var eye := p + Vector3(0, 200.0, 0)
	bm.set("feet_at", func() -> Vector3: return eye)
	move_mouse(Vector2(640, 360))
	await wait(4)
	var line := str(bm.get("where_line"))
	var tint_on: bool = (bm.get("tint") as Node3D).visible
	say("where.reach", line == BuildMode.OUT_OF_REACH and not tint_on, "camera 200 m up, the visitor beside it: line '%s', tint shown %s" % [line, tint_on])


# ------------------------------------------------------------------ presets on natural ground
## A cell near the site whose ground (at its centre and the cell in front) has a fractional height in [lo, hi), free
## of refusals for blocks two cells up; [] none.
func slope_spot(lo: float, hi: float, need_front: bool) -> Array:
	for k in 60:
		var cx := NEAR.x + 10 * (k % 12)
		var cz := NEAR.y + 12 * (k / 12)
		home.ensure(Vector2(cx, cz))
		for dz in range(0, 10):
			for dx in range(0, 10):
				var x := cx + dx
				var z := cz + dz
				var ok := true
				var hs := []
				for o: Vector2 in ([Vector2(0, -1), Vector2(0, 1)] if need_front else [Vector2.ZERO]):
					for s: Vector2 in [Vector2(0.5, 0.5), Vector2(0.15, 0.15), Vector2(0.85, 0.15), Vector2(0.15, 0.85), Vector2(0.85, 0.85)]:
						var h := ground(x + o.x + s.x, z + o.y + s.y)
						hs.append(h)
						var fr := h - floorf(h)
						ok = ok and fr >= lo and fr < hi
				if not ok:
					continue
				var y := floori((hs[0] as float)) + (1 if need_front else 0)
				for c: Vector3i in [Vector3i(x - 1, y, z), Vector3i(x + 1, y + 2, z), Vector3i(x, y, z)]:
					ok = ok and str(b.protect.refusal(c)) == "" and str(b.protect.refusal(c + Vector3i(0, 1, 0))) == ""
				if ok:
					return [x, z, hs]
	return []


## The cells a person's feet read standing at 9 points of column (x, z) (on the ground the walker's collider is).
func feet_cells(x: int, z: int) -> Array:
	var out := []
	for j in 3:
		for i in 3:
			var px := x + 0.15 + 0.35 * i
			var pz := z + 0.15 + 0.35 * j
			out.append([RulesRun.feet_cell(Vector3(px, ground(px, pz), pz)), Vector3(px, ground(px, pz), pz)])
	return out


static func in_box(c: Vector3i, bx: Array) -> bool:
	return c.x >= int(bx[0][0]) and c.x <= int(bx[1][0]) and c.y >= int(bx[0][1]) and c.y <= int(bx[1][1]) and c.z >= int(bx[0][2]) and c.z <= int(bx[1][2])


func use_tool_on(t: RefCounted, k: Key, h1: Dictionary, h2: Dictionary) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	t.key(e)
	bm.set("hit", h1)
	if t.press(MOUSE_BUTTON_LEFT, {}):
		t.drag(h2)
		t.release(MOUSE_BUTTON_LEFT)
	t.key(e)                                          # the same key again: disarmed


func door_case() -> void:
	bm.call("switch_tool", tab_index("Rules") - int(bm.get("tool_index")))
	await wait(2)
	var s := slope_spot(0.55, 0.92, true)
	if s.is_empty():
		say("slope.door", false, "no spot near %s with ground 0.55..0.92 over a whole metre in front and behind" % str(NEAR))
		return
	var x: int = s[0]
	var z: int = s[1]
	var y := floori(float(s[2][0])) + 1                  # the wall's first cell: a cell over the feet in front
	var ops := []
	for dx in [-1, 0, 1]:
		for dy in 3:
			ops.append({"op": "place", "at": [x + dx, y + dy, z], "shape": 1, "mat": 1, "rot": 0})
	var r: Dictionary = b.apply(ops)
	await wait(3)
	# the Door on the two blocks at x, y..y+1 (the lintel above stays), clicked on their front face as a person does
	var front := Vector3(x + 0.5, y + 0.5, z - 3.0)
	var h1: Dictionary = b.pick(front, Vector3(x + 0.5, y + 0.5, z + 0.5))
	var h2: Dictionary = b.pick(Vector3(x + 0.5, y + 1.5, z - 3.0), Vector3(x + 0.5, y + 1.5, z + 0.5))
	var t: RefCounted = bm.call("tool")
	var rl: RefCounted = b.layer("rules")
	var z0: int = rl.zones.size()
	use_tool_on(t, KEY_5, h1, h2)
	var zid := -1
	for id: int in rl.zones:
		zid = maxi(zid, id)
	var bx: Array = (rl.zones.get(zid, {}) as Dictionary).get("box", [[0, 0, 0], [0, 0, 0]])
	var old := Presets.box_for("door", Vector3i(x, y, z), Vector3i(x, y + 1, z), 2)
	var old_box := [[old[0].x, old[0].y, old[0].z], [old[1].x, old[1].y, old[1].z]]
	var now_in := 0
	var was_in := 0
	var pts := feet_cells(x, z - 1) + feet_cells(x, z + 1)
	for e: Array in pts:
		now_in += 1 if in_box(e[0], bx) else 0
		was_in += 1 if in_box(e[0], old_box) else 0
	var rec := Rec.new()
	var run: RefCounted = RulesRun.new(rl, rec)
	var feet: Vector3 = pts[4][1]
	run.begin(0, feet)
	run.step(1, RulesRun.feet_cell(feet), false)
	run.step(2, RulesRun.feet_cell(feet), true)
	var opened := rec.log.filter(func(e: Array) -> bool: return str(e[0]) == "set_open" and int(e[1]) == zid and bool(e[2]))
	# on the wall's top (blocks under it, the ground 3 m down) a Checkpoint keeps the box as drawn
	var ht: Dictionary = b.pick(Vector3(x + 0.5, y + 8.0, z + 0.5), Vector3(x + 0.5, y - 2.0, z + 0.5))
	use_tool_on(t, KEY_2, ht, ht)
	var zt := -1
	for id: int in rl.zones:
		zt = maxi(zt, id)
	var tb: Array = (rl.zones.get(zt, {}) as Dictionary).get("box", [])
	var cp: Vector3i = ht.get("place", Vector3i.ZERO)
	var told := Presets.box_for("checkpoint", cp, cp)
	var on_top: bool = zt != zid and tb == [[told[0].x, told[0].y, told[0].z], [told[1].x, told[1].y, told[1].z]]
	var ok: bool = bool(r.ok) and rl.zones.size() == z0 + 2 and now_in == pts.size() and was_in < pts.size() and not opened.is_empty() and on_top
	say("slope.door", ok, "wall at (%d, %d..%d, %d) on ground %.2f in front: the Door's box %s (as drawn before: %s); feet cells inside at %d of %d points (before: %d); E at feet %s (cell %s): opened %s; a Checkpoint on the wall's top keeps its box %s: %s" % [
		x, y, y + 2, z, float(s[2][0]), str(bx), str(old_box), now_in, pts.size(), was_in, str(feet.snapped(Vector3.ONE * 0.01)), str(RulesRun.feet_cell(feet)), not opened.is_empty(), str(tb), on_top])


func pad_case() -> void:
	var s := slope_spot(0.955, 0.999, false)
	if s.is_empty():
		say("slope.pad", false, "no spot near %s with ground 0.955..0.999 over a whole metre" % str(NEAR))
		return
	var x: int = s[0]
	var z: int = s[1]
	var top := float(s[2][0]) + 10.0
	var h: Dictionary = b.pick(Vector3(x + 0.5, top, z + 0.5), Vector3(x + 0.5, top - 20.0, z + 0.5))
	var t: RefCounted = bm.call("tool")
	var rl: RefCounted = b.layer("rules")
	use_tool_on(t, KEY_6, h, h)
	var zid := -1
	for id: int in rl.zones:
		zid = maxi(zid, id)
	var bx: Array = (rl.zones.get(zid, {}) as Dictionary).get("box", [[0, 0, 0], [0, 0, 0]])
	var cell: Vector3i = h.get("place", Vector3i.ZERO)
	var old := Presets.box_for("pad", cell, cell)
	var old_box := [[old[0].x, old[0].y, old[0].z], [old[1].x, old[1].y, old[1].z]]
	var pts := feet_cells(x, z)
	var now_in := 0
	var was_in := 0
	for e: Array in pts:
		now_in += 1 if in_box(e[0], bx) else 0
		was_in += 1 if in_box(e[0], old_box) else 0
	var rec := Rec.new()
	var run: RefCounted = RulesRun.new(rl, rec)
	run.begin(0, Vector3(x - 4.5, float(s[2][0]), z + 0.5))
	run.step(1, RulesRun.feet_cell(Vector3(x - 4.5, ground(x - 4.5, z + 0.5), z + 0.5)), false)
	var feet: Vector3 = pts[4][1]
	run.step(2, RulesRun.feet_cell(feet), false)
	var launched := rec.log.filter(func(e: Array) -> bool: return str(e[0]) == "launch")
	var ok: bool = now_in == pts.size() and was_in < pts.size() and not launched.is_empty()
	say("slope.pad", ok, "pad clicked at cell %s on ground %.3f: box %s (as drawn before: %s); feet cells inside at %d of %d points (before: %d); walking on at %s (cell %s): launched %s" % [
		str(cell), float(s[2][0]), str(bx), str(old_box), now_in, pts.size(), was_in, str(feet.snapped(Vector3.ONE * 0.001)), str(RulesRun.feet_cell(feet)), not launched.is_empty()])


## The where line points somewhere ("buildable ground 65 m south-east"), not "looking for buildable ground...".
static func pointed(line: String) -> bool:
	return RegEx.create_from_string("buildable ground [0-9]+ m ").search(line) != null
