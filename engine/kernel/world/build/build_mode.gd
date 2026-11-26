extends Node
## WP2 (spark world-sandbox, M1): build mode in the Home. B turns it on and off while the visitor walks. While it is
## on the cursor is free (kernel/runner/visit.gd asks `active` and `looking`), the hotbar shows (hotbar.gd), and a
## holo ghost (ghost.gd) sits in the cell the cursor names: the cursor ray from the camera (home_build.gd `pick`), which
## reaches 24 m past the visitor (`_reach`).
## Keys and buttons (polled from the engine's input state once per physics frame, as TLInput polls them; the wheel is
## taken from its events):
##   LMB place (a drag places along the cells crossed, ONE batch)    RMB remove (a drag is one batch)
##   wheel or 1-8 shape   Tab / Shift+Tab material (1-9; a window's pane is glass by itself)   R turn (+1 rot)
##   F2 flip (stair, ramp, roof)   Ctrl+Z undo   Ctrl+Y (or Ctrl+Shift+Z) redo   hold MMB or Alt: look (mouse captured)
##   B or Esc leave (Esc never quits from build mode: visit.gd does not quit while `active`)
## The ghost shows the remove target (red) while RMB is held or Ctrl is down; otherwise the place target (holo, red
## with the reason when `can_place` refuses). A drag keeps to the layer of its first cell: the cursor slides on the
## plane of the surface first pressed (the ground's height there, a row's top, a wall's side), and every cell it crosses
## on that plane gets the first cell's level (or wall plane).
## The default rot is HomeBuild.rot_facing(camera forward); R adds a quarter turn. Walking keys and F flight still work.
##
## Saving (tl.build/1, user://home; TL_HOME_BUILD_DIR=<abs dir> names another): on leaving build mode, 1800 physics
## frames after the first unsaved change, and on quit (tree_exiting and the window's close request). The save is only
## made where a load was made: the Home loads its save when a person walks it (the view's visit reads a person's
## devices, no device script), or when the owner calls `open(dir)` (a test). A save error is shown in the hotbar and
## printed, never swallowed; a build file that cannot be read is never written over (nothing is saved then).
##
## Mounting: home/hook.gd `grow` calls `mount(landscape, valley)`; the walk (for the game plots) is the landscape's meta
## "tl_walk" when set (a test), else the view's world's walk (landscape.gd reads it the same way). The builder is the
## landscape's meta "tl_build", this node its meta "tl_build_mode". A case sets `cam`, `feet_at` and `pointer`.
## Test hook TL_BUILD_DEVICES="<frame>:<kind>[:<args>];..." (this node's own physics frames, which are boot.gd's frames
## in the exe: both start counting on the same tick):  px:x,y (the pointer at that pixel)   at:x,y,z (the pointer at
## the pixel of that world point, followed every frame)   mouse (the real mouse again)   lmb|rmb|mmb:1|0 (a button)
## key:<Key>:1|0   fill:x0,y0,z0,x1,y1,z1,shape,mat (one batch: a box of blocks; a load test)   state (prints it).

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const Ghost := preload("res://kernel/world/build/ghost.gd")
const Hotbar := preload("res://kernel/world/build/hotbar.gd")
const Blocks := preload("res://kernel/world/build/blocks.gd")
const SELF := "res://kernel/world/build/build_mode.gd"
const REACH := 24.0                     # metres the cursor reaches past the camera's distance to the visitor
const AUTOSAVE_FRAMES := 1800
const DRAG_MAX := 64                    # cells one drag may touch
const MATS := 9                         # materials a person picks (10, glass, is a window's pane)
const TURNS := [Blocks.STAIR, Blocks.RAMP, Blocks.ROOF, Blocks.WINDOW]
const FLIPS := [Blocks.STAIR, Blocks.RAMP, Blocks.ROOF]
const POLLED := [KEY_B, KEY_ESCAPE, KEY_TAB, KEY_R, KEY_F2, KEY_Z, KEY_Y, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8]

var build: RefCounted = null            # home_build.gd
var land: Node3D = null                 # the landscape it hangs under
var active := false
var looking := false
var shape := Blocks.CUBE
var mat := 3                            # plank
var turn := 0                           # R presses (quarter turns added to the facing rot)
var flip := false
var dir := ""                           # where the Home is saved ("" = nothing is saved)
var blocked := ""                       # why nothing may be saved (the build file there could not be read)
var save_error := ""
var reason := ""                        # why the ghost's cell is refused ("" = it is not)
var frames := 0
var autosave_frames := AUTOSAVE_FRAMES
var cam: Camera3D = null                # set by a test; else the view's visitor's camera
var feet_at: Callable                   # () -> Vector3, set by a test; else the view's visitor's feet
var pointer := Vector2(-1.0, -1.0)      # a pixel set by a test or the hook; negative: the mouse
var hit := {}                           # the last pick (home_build.gd `pick`)
var ghost: Node3D = null
var hotbar: CanvasLayer = null
var _down := {}                         # polled key / button -> down at the last poll
var _wheel := 0
var _drag := {}                         # {"op": "place"|"remove", "axis", "at", "last": Vector3i, "done": {cell: true}}
var _dirty_at := -1                     # frame of the first unsaved change (-1: none)
var _script := {}                       # TL_BUILD_DEVICES: frame -> [[kind, args], ...]
var _aim_at: Variant = null             # TL_BUILD_DEVICES `at`: a world point the pointer follows
var _held := {}                         # TL_BUILD_DEVICES: buttons the script holds down
var _view: Node = null
var _saved_on_exit := false


## Called by home/hook.gd `grow`: the builder (P1: the walk's plots and the valley's sites are protected) and this node.
static func mount(parent: Node3D, valley: RefCounted) -> Node:
	var b: RefCounted = HomeBuild.attach(parent, walk_of(parent), valley)
	var n: Node = (load(SELF) as GDScript).new()
	n.name = "HomeBuildMode"
	n.set("build", b)
	n.set("land", parent)
	parent.add_child(n)
	parent.set_meta(&"tl_build", b)
	parent.set_meta(&"tl_build_mode", n)
	return n


## The walk the landscape was built for: the meta "tl_walk" (a test), else the view's world's walk, else {}.
static func walk_of(parent: Node3D) -> Dictionary:
	if parent.has_meta(&"tl_walk"):
		return parent.get_meta(&"tl_walk")
	var view: Node = parent.get_parent()
	var world: Variant = view.get("world") if view != null else null
	var w: Variant = (world as Object).get("walk") if world is Object else null
	return w if w is Dictionary else {}


func _ready() -> void:
	process_physics_priority = 150000          # after the viewer (100000: visit.sample, steer, the visitor's step)
	ghost = Ghost.new()
	add_child(ghost)
	hotbar = Hotbar.new()
	add_child(hotbar)
	_view = land.get_parent() if land != null else null
	build.dirty_changed.connect(_on_dirty)
	tree_exiting.connect(_on_exit)
	_read_script(OS.get_environment("TL_BUILD_DEVICES"))


# ------------------------------------------------------------------ the owner's calls
## Loads the Home saved in `d` and saves there from now on. Returns home_build.gd `load`'s figures.
func open(d: String) -> Dictionary:
	var r: Dictionary = build.load(d)
	dir = d
	blocked = "" if bool(r.ok) else "the saved Home could not be read (%s): nothing is saved until it is moved away" % str(r.reason)
	_dirty_at = frames if bool(build.dirty) else -1
	print(JSON.stringify({"schema": "tl.view/1", "kind": "home_build_load", "dir": d, "ok": bool(r.ok), "reason": str(r.reason),
		"rev": int(r.rev), "blocks": int(r.blocks), "replayed": int(r.replayed), "bad": (r.bad as Array).size()}, "", false))
	if not blocked.is_empty():
		push_error("[build] " + blocked)
	return r


## Saves now if anything is unsaved. Returns "" or what went wrong (also shown in the hotbar).
func save_now(why: String) -> String:
	if dir.is_empty() or not bool(build.dirty):
		return ""
	if not blocked.is_empty():
		save_error = blocked
		return blocked
	save_error = str(build.save(dir))
	print(JSON.stringify({"schema": "tl.view/1", "kind": "home_build_save", "why": why, "dir": dir, "ok": save_error.is_empty(),
		"error": save_error, "rev": int(build.rev), "blocks": int(build.blocks.total), "frame": frames}, "", false))
	if not save_error.is_empty():
		push_error("[build] the Home was not saved: " + save_error)
	return save_error


func enter() -> void:
	if active:
		return
	active = true
	turn = 0
	print(JSON.stringify({"schema": "tl.view/1", "kind": "build_mode", "on": true, "frame": frames}, "", false))


func leave(why := "key") -> void:
	if not active:
		return
	_end_drag()
	active = false
	looking = false
	hit = {}
	reason = ""
	ghost.hide_ghost()
	save_now("leave")
	print(JSON.stringify({"schema": "tl.view/1", "kind": "build_mode", "on": false, "why": why, "frame": frames,
		"blocks": int(build.blocks.total)}, "", false))


## The code a click would place now: the selected shape and material, the rot facing away from the camera plus the
## R turns (shapes that do not turn keep 0), flip only for a stair, ramp or roof.
func code_now() -> int:
	var r := 0
	if shape in TURNS:
		r = (HomeBuild.rot_facing(_forward()) + turn) % 4
	return HomeBuild.code(shape, mat, r, flip and shape in FLIPS)


# ------------------------------------------------------------------ per frame
func _physics_process(_delta: float) -> void:
	frames += 1
	if build == null:
		return
	if dir.is_empty() and _person_walks():
		var d := OS.get_environment("TL_HOME_BUILD_DIR")
		open(d if d.is_absolute_path() else HomeBuild.HOME_DIR)
	if feet_at.is_valid():
		build.protect.visitor_at = feet_at
	elif not build.protect.visitor_at.is_valid() and _visitor() != null:
		var v: Node3D = _visitor()
		build.protect.visitor_at = func() -> Vector3: return v.get("feet") if is_instance_valid(v) else Vector3(0, -1e6, 0)   # P3
	_run_script()
	_poll()
	build.step()
	if _dirty_at >= 0 and frames - _dirty_at >= autosave_frames and _drag.is_empty():
		save_now("autosave")


func _process(_delta: float) -> void:
	if build == null:
		return
	if active and not looking:
		var h := _pick()
		_show(h)
	else:
		ghost.hide_ghost()
	hotbar.refresh(_hotbar_state())


func _input(event: InputEvent) -> void:
	if active and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var bi: int = (event as InputEventMouseButton).button_index
		if bi == MOUSE_BUTTON_WHEEL_UP:
			_wheel -= 1
		elif bi == MOUSE_BUTTON_WHEEL_DOWN:
			_wheel += 1


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now("quit")


func _on_exit() -> void:
	if _saved_on_exit:
		return
	_saved_on_exit = true
	_end_drag()
	save_now("quit")
	build.free_all()


func _on_dirty(d: bool) -> void:
	_dirty_at = frames if d else -1


# ------------------------------------------------------------------ input
func _edge(k: int, down: bool) -> bool:
	var was: bool = _down.get(k, false)
	_down[k] = down
	return down and not was


func _poll() -> void:
	var stage := _stage()
	var vp := get_viewport()
	var f: Control = vp.gui_get_focus_owner() if vp != null else null
	var typing := f is LineEdit or f is TextEdit
	var e := {}
	for k: int in POLLED:
		e[k] = _edge(k, Input.is_physical_key_pressed(k) and not typing)
	var lmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var rmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var lmb_e := _edge(-1, lmb)
	var rmb_e := _edge(-2, rmb)
	var wheel := _wheel
	_wheel = 0
	if stage >= 0:
		leave("stage")
		return
	if not active:
		if e[KEY_B]:
			enter()
		return
	if e[KEY_B] or e[KEY_ESCAPE]:
		leave("key" if e[KEY_B] else "esc")
		return
	var ctrl := Input.is_physical_key_pressed(KEY_CTRL)
	var shift := Input.is_physical_key_pressed(KEY_SHIFT)
	looking = Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) or Input.is_physical_key_pressed(KEY_ALT)
	for i: int in 8:
		if e[KEY_1 + i]:
			shape = i + 1
	if wheel != 0:
		shape = posmod(shape - 1 + wheel, 8) + 1
	if e[KEY_TAB]:
		mat = posmod(mat - 1 + (-1 if shift else 1), MATS) + 1
	if e[KEY_R]:
		turn = (turn + 1) % 4
	if e[KEY_F2]:
		flip = not flip
	if ctrl and e[KEY_Z]:
		_end_drag()
		if shift: build.redo()
		else: build.undo()
	elif ctrl and e[KEY_Y]:
		_end_drag()
		build.redo()
	if looking:
		_end_drag()
		return
	var h := _pick()
	if not _drag.is_empty():
		if (_drag.op == "place" and not lmb) or (_drag.op == "remove" and not rmb):
			_end_drag()
		else:
			_drag_to()
	if _drag.is_empty() and lmb_e and h.has("place"):
		_start_drag("place", h.place, h)
	elif _drag.is_empty() and rmb_e and h.has("remove") and h.remove != HomeBuild.NO_CELL:
		_start_drag("remove", h.remove, h)


# ------------------------------------------------------------------ edits
## The drag keeps to the plane of the surface first pressed: through the press point, across the axis of its normal
## (the cursor slides along that surface; every cell it crosses is on the first cell's layer).
func _start_drag(op: String, c: Vector3i, h: Dictionary) -> void:
	var a: Vector3 = (h.normal as Vector3).abs()
	var axis := 0 if a.x >= a.y and a.x >= a.z else (1 if a.y >= a.z else 2)
	build.begin_batch("hand")
	_drag = {"op": op, "axis": axis, "at": c[axis], "plane": float((h.pos as Vector3)[axis]), "last": c, "done": {}}
	_edit(c)


func _end_drag() -> void:
	if not _drag.is_empty():
		build.end_batch()
		_drag = {}


## The cell under the cursor on the drag's plane; every cell on the line from the last one to it is edited.
func _drag_to() -> void:
	var ray := _ray()
	if ray.is_empty():
		return
	var ax: int = _drag.axis
	var from: Vector3 = ray[0]
	var d: Vector3 = ray[1]
	if absf(d[ax]) < 0.0001:
		return
	var t := (float(_drag.plane) - from[ax]) / d[ax]
	if t <= 0.0 or t > _reach(from):
		return
	var c := Vector3i((from + d * t).floor())
	c[ax] = int(_drag.at)
	var last: Vector3i = _drag.last
	if c == last:
		return
	var delta := c - last
	var n: int = maxi(absi(delta.x), maxi(absi(delta.y), absi(delta.z)))
	for i: int in range(1, n + 1):
		var q := Vector3(last) + Vector3(delta) * (float(i) / float(n))
		_edit(Vector3i(roundi(q.x), roundi(q.y), roundi(q.z)))
	_drag.last = c


func _edit(c: Vector3i) -> void:
	var done: Dictionary = _drag.done
	if done.has(c) or done.size() >= DRAG_MAX:
		return
	done[c] = true
	var r: Dictionary
	if _drag.op == "place":
		r = build.place(c, code_now())
	elif build.code_at(c) != 0:
		r = build.remove(c)
	else:
		return
	if not bool(r.ok):
		reason = str(r.reason)
	if not _script.is_empty():                 # the test hook says what each edit did
		print(JSON.stringify({"schema": "tl.view/1", "kind": "build_edit", "frame": frames, "op": _drag.op, "at": [c.x, c.y, c.z],
			"code": code_now() if _drag.op == "place" else 0, "ok": bool(r.ok), "reason": str(r.reason)}, "", false))


# ------------------------------------------------------------------ the cursor
func _pick() -> Dictionary:
	var ray := _ray()
	hit = {} if ray.is_empty() else build.pick(ray[0], ray[0] + ray[1] * _reach(ray[0]))
	return hit


func _show(h: Dictionary) -> void:
	var removing := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_physical_key_pressed(KEY_CTRL)
	if h.is_empty():
		ghost.hide_ghost()
		reason = ""
		return
	if removing:
		reason = ""
		if h.remove != HomeBuild.NO_CELL:
			ghost.show_at(h.remove, 0, "remove")
		else:
			ghost.hide_ghost()
		return
	var c := code_now()
	reason = build.can_place(h.place, c)
	ghost.show_at(h.place, c, "place" if reason.is_empty() else "refused")


## [from, direction] of the cursor's ray through the camera as it is drawn (its interpolated pose), or [].
func _ray() -> Array:
	var c := _cam()
	var vp := get_viewport()
	if c == null or vp == null:
		return []
	if _aim_at != null:
		pointer = c.unproject_position(_aim_at)
	var mp := pointer if pointer.x >= 0.0 else vp.get_mouse_position()
	var size := vp.get_visible_rect().size
	if size.x < 1.0 or size.y < 1.0 or not Rect2(Vector2.ZERO, size).has_point(mp):
		return []
	var xf := c.get_global_transform_interpolated()
	var ndc := Vector2(mp.x / size.x * 2.0 - 1.0, 1.0 - mp.y / size.y * 2.0)
	var t := tan(deg_to_rad(c.fov) * 0.5)
	var aspect := size.x / size.y
	var local := Vector3(ndc.x * t * aspect, ndc.y * t, -1.0) if c.keep_aspect == Camera3D.KEEP_HEIGHT \
		else Vector3(ndc.x * t, ndc.y * t / aspect, -1.0)
	if c.projection != Camera3D.PROJECTION_PERSPECTIVE:
		return [c.project_ray_origin(mp), c.project_ray_normal(mp)]
	return [xf.origin, (xf.basis.orthonormalized() * local).normalized()]


## The cursor's reach from the camera at `from`: REACH past the visitor (the chase camera stands 5 m behind him on
## foot and about 14 m in flight, so a reach counted from the camera would shrink to 10 m round him in the air).
func _reach(from: Vector3) -> float:
	var f: Variant = feet_at.call() if feet_at.is_valid() else (_visitor().get("feet") if _visitor() != null else null)
	return REACH + (from.distance_to(f as Vector3) if f is Vector3 else 0.0)


func _forward() -> Vector3:
	var c := _cam()
	var f := -c.get_global_transform_interpolated().basis.z if c != null else Vector3.FORWARD
	return Vector3(f.x, 0.0, f.z)


# ------------------------------------------------------------------ the view (duck-typed: kernel/world/draw/view.gd)
func _visitor() -> Node3D:
	var v: Variant = _view.get("visitor") if _view != null else null
	return v if is_instance_valid(v) and v is Node3D else null


func _cam() -> Camera3D:
	if cam != null:
		return cam
	var v := _visitor()
	var c: Variant = v.get("cam") if v != null else null
	return c if c is Camera3D else null


func _stage() -> int:
	var s: Variant = _view.get("stage") if _view != null else null
	return int(s) if s != null else -1


## A person walks: the view's visit reads devices (not a replay) and runs no device script (not a test).
func _person_walks() -> bool:
	var visit: Variant = _view.get("visit") if _view != null else null
	if not (visit is Node) or not bool((visit as Node).get("devices")):
		return false
	var s: Variant = (visit as Node).get("_script")
	return s is Dictionary and (s as Dictionary).is_empty()


func _hotbar_state() -> Dictionary:
	var s := {"building": active}
	if not active:
		return s
	s.shape = shape
	s.mat = mat
	s.turns = shape in TURNS
	s.rot = (HomeBuild.rot_facing(_forward()) + turn) % 4
	if shape in FLIPS:
		s.flip = flip
	s.reason = reason
	if not save_error.is_empty():
		s.save = "save failed: " + save_error
	elif dir.is_empty():
		s.save = "not saved (no Home file here)"
	else:
		s.save = "unsaved" if bool(build.dirty) else "saved"
	return s


# ------------------------------------------------------------------ TL_BUILD_DEVICES (a test hook)
func _read_script(text: String) -> void:
	for part: String in text.split(";", false):
		var f := part.strip_edges().split(":")
		if f.size() < 2 or not f[0].is_valid_int():
			print("[build] TL_BUILD_DEVICES: cannot read '%s'" % part)
			continue
		var t := int(f[0])
		if not _script.has(t):
			_script[t] = []
		(_script[t] as Array).append(f.slice(1))


func _run_script() -> void:
	for e: PackedStringArray in _script.get(frames, []):
		var a := e[1].split(",") if e.size() > 1 else PackedStringArray()
		match e[0]:
			"px":
				_aim_at = null
				pointer = Vector2(float(a[0]), float(a[1]))
			"at":
				_aim_at = Vector3(float(a[0]), float(a[1]), float(a[2]))
			"mouse":
				_aim_at = null
				pointer = Vector2(-1.0, -1.0)
			"lmb", "rmb", "mmb":
				var bi: int = {"lmb": MOUSE_BUTTON_LEFT, "rmb": MOUSE_BUTTON_RIGHT, "mmb": MOUSE_BUTTON_MIDDLE}[e[0]]
				_button(bi, a[0] == "1")
				if a[0] == "1": _held[bi] = true
				else: _held.erase(bi)
			"key":
				var k := InputEventKey.new()
				k.keycode = OS.find_keycode_from_string(e[1])
				k.physical_keycode = k.keycode
				k.pressed = e.size() > 2 and e[2] == "1"
				Input.parse_input_event(k)
				Input.flush_buffered_events()
			"fill":
				var v := a
				var ops := []
				for y: int in range(int(v[1]), int(v[4]) + 1):
					for z: int in range(int(v[2]), int(v[5]) + 1):
						for x: int in range(int(v[0]), int(v[3]) + 1):
							ops.append({"op": "place", "at": [x, y, z], "shape": int(v[6]), "mat": int(v[7]), "rot": 0})
				var r: Dictionary = build.apply(ops)
				print(JSON.stringify({"schema": "tl.view/1", "kind": "build_fill", "frame": frames, "ops": ops.size(),
					"applied": int(r.applied), "refused": (r.refused as Array).size(), "reason": str(r.reason)}, "", false))
			"state":
				print(JSON.stringify({"schema": "tl.view/1", "kind": "build_state", "frame": frames, "active": active,
					"shape": shape, "mat": mat, "reason": reason, "pick": str(hit.get("place", "")), "pointer": str(pointer.snapped(Vector2.ONE)), "stats": build.stats(),
					"cam": str(_cam().global_position.snapped(Vector3.ONE * 0.01)) if _cam() != null else "", "feet": str(_visitor().get("feet")) if _visitor() != null else ""}, "", false))
	# a button the script holds is pressed again when the engine let go of it (another window took the focus), as
	# boot.gd does for the keys of TL_EXE_KEYS
	for bi: int in _held:
		if not Input.is_mouse_button_pressed(bi):
			_button(bi, true)


func _button(bi: int, down: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = bi as MouseButton
	mb.pressed = down
	mb.position = pointer
	Input.parse_input_event(mb)
	Input.flush_buffered_events()
