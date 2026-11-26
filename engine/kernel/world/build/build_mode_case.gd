extends SceneTree
## WP2 (spark world-sandbox, M1): build mode (build_mode.gd), headless, in the landscape of res://boot/village.json
## (the Home grown by home/hook.gd, which mounts build mode), driven by input events as a person makes them: keys and
## buttons through Input.parse_input_event (the engine's input state), the pointer as mouse motion, the wheel pushed
## into the viewport (no window system hands events on in a headless run: session.gd `_pointer_event`). A camera of
## the case's own looks straight down on a flat clear patch. Frames, not wall clock. Prints `HOME mode.<case> ok|fail
## <detail>`, then `HOME build-mode ok` (or fail) and `HOME DONE`; engine/tools/selftest.d/753-home-build-mode.sh reads them.
##   mode.keys     B turns build mode on (hotbar shown); the wheel and 1-8 pick the shape, Tab the
##                 material, R turns
##   mode.place    three LMB clicks at three cells and a drag across 4 cells: the cells placed are the ones aimed at,
##                 and the drag is one batch (one undo step); Ctrl+Z undoes the drag (4 cells), RMB removes one block
##   mode.refuse   the cursor on a game lot: the ghost is refused, the hotbar names "game lot", a click places nothing
##   mode.save     B again leaves build mode and saves (build.json written, unsaved -> saved); a change autosaves after
##                 `autosave_frames` (lowered to 30 here) without leaving
##   mode.load     a fresh landscape loads the save and finds the same blocks; the temporary folder is removed
const Landscape := preload("res://kernel/world/landscape.gd")
const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const Blocks := preload("res://kernel/world/build/blocks.gd")
const TMP := "user://tl_build_mode_case"
const NEAR := Vector2i(700, -60)        # the search for a flat clear patch starts here (build_case.gd WALK_AT)
const CAM_H := 16.0                     # metres the camera stands over the patch

var walk: Dictionary
var node: Node3D
var ws: Object
var bm: Node
var b: RefCounted
var cam: Camera3D
var ok_all := true
var site := {}


func _initialize() -> void:
	call_deferred("run")


func say(case_name: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME mode.%s %s %s" % [case_name, "ok" if ok else "fail", detail])


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func landscape() -> bool:
	var cfg: Dictionary = walk.landscape.duplicate(true)
	cfg.road = walk.road
	cfg.footprints = []
	var xf := []
	var radii := []
	var own := []
	for p: Dictionary in walk.plots:
		xf.append(Transform3D(Basis.IDENTITY, Vector3(p.origin[0], p.origin[1], p.origin[2])))
		radii.append(p.radius)
		own.append(false)
		cfg.footprints.append(Vector2(p.footprint.size_m[0], p.footprint.size_m[1]))
	node = Node3D.new()
	node.set_meta(&"tl_walk", walk)                 # build_mode.gd `walk_of`: the plots it protects
	root.add_child(node)
	Landscape.build(node, xf, radii, own, cfg)
	Landscape.arrive(node)
	if not node.has_meta(&"tl_build_mode"):
		return false
	ws = node.get_meta(&"tl_space")
	bm = node.get_meta(&"tl_build_mode")
	b = node.get_meta(&"tl_build")
	return true


func run() -> void:
	walk = JSON.parse_string(FileAccess.get_file_as_string("res://boot/village.json"))
	TLStyle.set_headless(false)
	_remove_dir(ProjectSettings.globalize_path(TMP))
	if not landscape():
		say("keys", false, "no build mode: home/hook.gd did not mount it (TL_HOME=%s)" % OS.get_environment("TL_HOME"))
		finish()
		return
	bm.call("open", TMP)
	site = find_site()
	cam = Camera3D.new()
	cam.fov = 60.0
	root.add_child(cam)
	cam.current = true
	bm.set("cam", cam)
	root.size = Vector2i(1280, 720)                 # a headless window is 64 x 64 px
	over(Vector3(site.x + 2.5, site.y, site.z + 2.0))
	var away := Vector3(site.x + 2.5, site.y + 1.0, site.z + 40.0)
	bm.set("feet_at", func() -> Vector3: return away)     # the visitor stands 40 m away (P3: protection asks this)
	await wait(3)
	await keys_case()
	await place_case()
	await refuse_case()
	await save_case()
	await load_case()
	finish()


func finish() -> void:
	_remove_dir(ProjectSettings.globalize_path(TMP))
	print("HOME build-mode %s" % ("ok" if ok_all else "fail"))
	print("HOME DONE")
	quit(0)


# ------------------------------------------------------------------ devices
func key(k: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func tap(k: Key) -> void:
	key(k, true)
	await wait(2)
	key(k, false)
	await wait(2)


func button(bi: MouseButton, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = bi
	e.pressed = down
	e.position = root.get_mouse_position()
	e.global_position = e.position
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func wheel(down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
	e.pressed = true
	e.position = root.get_mouse_position()
	root.push_input(e)


## The mouse moves to the pixel where the camera sees world point `p`.
func aim(p: Vector3) -> void:
	var px := cam.unproject_position(p)
	var e := InputEventMouseMotion.new()
	e.position = px
	e.global_position = px
	e.relative = px - root.get_mouse_position()
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func over(p: Vector3) -> void:
	cam.look_at_from_position(p + Vector3(0.0, CAM_H, 0.0), p, Vector3.FORWARD)
	cam.reset_physics_interpolation()


func ground(x: int, z: int) -> float:
	return float(ws.call("ground_at", x + 0.5, z + 0.5, site.get("y", 0) + 60.0))


func gcell(x: int, z: int) -> Vector3i:
	return Vector3i(x, int(floorf(ground(x, z) + 0.01)), z)


func click(p: Vector3, bi := MOUSE_BUTTON_LEFT) -> void:
	aim(p)
	await wait(2)
	button(bi, true)
	await wait(2)
	button(bi, false)
	await wait(2)


func cells() -> Array:
	var out := []
	for s: Vector2i in b.blocks.sections:
		for idx: int in b.blocks.sections[s]:
			out.append([b.blocks.cell_of(s, idx), int(b.blocks.sections[s][idx])])
	out.sort_custom(func(p: Array, q: Array) -> bool: return str(p[0]) < str(q[0]))
	return out


## A 9 x 7 patch near NEAR whose ground varies less than 0.6 m and that nothing protects.
func find_site() -> Dictionary:
	var home: RefCounted = node.get_meta(&"tl_home")
	for k in 30:
		var sx := NEAR.x + 10 * k
		var sz := NEAR.y
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
			return {"x": sx, "y": int(floorf(lo)), "z": sz, "tries": k + 1}
	return {"x": NEAR.x, "y": 0, "z": NEAR.y, "tries": 30}


# ------------------------------------------------------------------ cases
func keys_case() -> void:
	var hb: CanvasLayer = bm.get("hotbar")
	await tap(KEY_B)
	var on: bool = bm.get("active")
	var shown: bool = hb.get("box").visible
	wheel(true)
	await wait(2)
	var after_wheel: int = bm.get("shape")
	await tap(KEY_7)
	var after_7: int = bm.get("shape")
	await tap(KEY_1)
	var m0: int = bm.get("mat")
	await tap(KEY_TAB)
	var m1: int = bm.get("mat")
	key(KEY_SHIFT, true)
	await tap(KEY_TAB)
	key(KEY_SHIFT, false)
	var m2: int = bm.get("mat")
	await tap(KEY_R)
	var turned: int = bm.get("turn")
	bm.set("turn", 0)
	var ok: bool = on and shown and after_wheel == 2 and after_7 == 7 and bm.get("shape") == 1 and m1 == m0 % 9 + 1 and m2 == m0 and turned == 1
	say("keys", ok, "after B active %s, hotbar shown %s; wheel down -> shape %d, 7 -> %d, 1 -> %d; Tab mat %d -> %d, Shift+Tab -> %d; R turn %d; site (%d, %d, %d) after %d tries" % [
		on, shown, after_wheel, after_7, int(bm.get("shape")), m0, m1, m2, turned, site.x, site.y, site.z, site.tries])


func place_case() -> void:
	var x0: int = site.x
	var z0: int = site.z
	var want := []
	for i in 3:
		var c := gcell(x0 + 2 * i, z0)
		want.append(c)
		await click(Vector3(c.x + 0.5, ground(c.x, c.z), c.z + 0.5))
	var clicks_ok := true
	for c: Vector3i in want:
		clicks_ok = clicks_ok and b.code_at(c) != 0
	var batches_clicks: int = b.edits.history.size()
	# the drag: press on the ground, then the pointer crosses 3 more cells on the plane of that press
	var d0 := gcell(x0, z0 + 3)
	aim(Vector3(d0.x + 0.5, ground(d0.x, d0.z), d0.z + 0.5))
	await wait(2)
	button(MOUSE_BUTTON_LEFT, true)
	await wait(2)
	var dg := ground(d0.x, d0.z)                    # the cursor slides on the plane of the ground first pressed
	for i in range(1, 4):
		aim(Vector3(d0.x + i + 0.5, dg, d0.z + 0.5))
		await wait(2)
	button(MOUSE_BUTTON_LEFT, false)
	await wait(2)
	var drag := []
	var drag_ok := true
	for i in 4:
		var c := Vector3i(d0.x + i, d0.y, d0.z)
		drag.append(c)
		drag_ok = drag_ok and b.code_at(c) != 0
	var batches_drag: int = b.edits.history.size()
	var blocks_drag: int = b.blocks.total
	key(KEY_CTRL, true)
	await tap(KEY_Z)
	key(KEY_CTRL, false)
	await wait(2)
	var undone := true
	for c: Vector3i in drag:
		undone = undone and b.code_at(c) == 0
	var batches_undo: int = b.edits.history.size()
	# RMB on the middle click's block: the pointer on its top face
	var mid: Vector3i = want[1]
	await click(Vector3(mid.x + 0.5, mid.y + 1.0, mid.z + 0.5), MOUSE_BUTTON_RIGHT)
	var removed: bool = b.code_at(mid) == 0
	var expect := [want[0], want[2]]
	var got := []
	for p: Array in cells():
		got.append(p[0])
	var listed := got == expect
	var ok: bool = clicks_ok and batches_clicks == 3 and drag_ok and batches_drag == 4 and blocks_drag == 7 and undone and batches_undo == 3 and removed and listed
	say("place", ok, "3 clicks placed %s (%d batches); drag %s placed %s as %d batch (blocks %d); Ctrl+Z took the drag back %s (batches %d); RMB removed %s %s; cells now %s, want %s" % [
		str(want), batches_clicks, str(drag), drag_ok, batches_drag - batches_clicks, blocks_drag, undone, batches_undo, str(mid), removed, str(got), str(expect)])


func refuse_case() -> void:
	var plot: Array = walk.plots[0].origin
	var px := int(plot[0])
	var pz := int(plot[2])
	var pg := float(ws.call("ground_at", px + 0.5, pz + 0.5, float(plot[1]) + 60.0))
	over(Vector3(px + 0.5, pg, pz + 0.5))
	await wait(2)
	var before: int = b.blocks.total
	var hist: int = b.edits.history.size()
	aim(Vector3(px + 0.5, pg, pz + 0.5))
	await wait(3)
	var hb: CanvasLayer = bm.get("hotbar")
	var shown_reason: String = (hb.get("reason") as Label).text
	var ghost_mode: String = (bm.get("ghost") as Node).get("shown")
	await click(Vector3(px + 0.5, pg, pz + 0.5))
	var placed_none: bool = b.blocks.total == before and b.edits.history.size() == hist
	var ok: bool = shown_reason == "game lot" and ghost_mode == "refused" and placed_none
	say("refuse", ok, "plot %s at (%d, %.2f, %d): hotbar reason '%s', ghost '%s', a click placed nothing %s" % [
		str(walk.plots[0].id), px, pg, pz, shown_reason, ghost_mode, placed_none])
	over(Vector3(site.x + 2.5, site.y, site.z + 2.0))
	await wait(2)


func save_case() -> void:
	var path := TMP.path_join("build.json")
	var hb: CanvasLayer = bm.get("hotbar")
	var unsaved_before: String = (hb.get("saved") as Label).text
	var file_before := FileAccess.file_exists(path)
	await tap(KEY_B)
	var off: bool = not bm.get("active")
	var file_after := FileAccess.file_exists(path)
	var clean: bool = not b.dirty
	var rev_leave: int = b.rev
	# autosave without leaving: one more block, `autosave_frames` lowered to 30
	await tap(KEY_B)
	bm.set("autosave_frames", 30)
	var c := gcell(site.x + 2, site.z)
	await click(Vector3(c.x + 0.5, ground(c.x, c.z), c.z + 0.5))
	var dirty_now: bool = b.dirty
	await wait(36)
	var auto: bool = not b.dirty and b.rev == rev_leave + 1
	var saved_text: String = (hb.get("saved") as Label).text
	await tap(KEY_B)
	var ok: bool = unsaved_before == "unsaved" and not file_before and off and file_after and clean and rev_leave == 1 and dirty_now and auto and saved_text == "saved"
	say("save", ok, "hotbar '%s' before; B left build mode %s, build.json written %s (before %s), dirty after %s, rev %d; a click then dirty %s, autosaved after 30 frames %s (rev %d), hotbar '%s'" % [
		unsaved_before, off, file_after, file_before, not clean, rev_leave, dirty_now, auto, b.rev, saved_text])


func load_case() -> void:
	var before := cells()
	node.free()                                     # the landscape goes (its build mode saves nothing new: clean)
	await wait(2)
	if not landscape():
		say("load", false, "the second landscape has no build mode")
		return
	var r: Dictionary = bm.call("open", TMP)
	b.flush()
	var after := cells()
	var meshes: int = b.stats().sections
	var ok: bool = bool(r.ok) and after == before and before.size() == 3 and meshes > 0
	say("load", ok, "a fresh landscape loaded %d blocks (rev %d, ok %s), the same cells and codes %s, %d section meshes" % [
		after.size(), int(r.rev), r.ok, after == before, meshes])


func _remove_dir(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f: String in d.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	for sub: String in d.get_directories():
		_remove_dir(path.path_join(sub))
	DirAccess.remove_absolute(path)
