extends Node
## WP2 + SEAM (spark world-sandbox): build mode in the Home, the host of its TOOLS (BUILD.md "Build mode", "Tools").
## B turns it on and off while the visitor walks; while it is on the cursor is free (kernel/runner/visit.gd asks
## `active` and `looking`), the hotbar shows (hotbar.gd) and the current tool acts on the cursor ray from the camera
## (home_build.gd `pick`, reaching 24 m past the visitor: `reach`). This node polls keys and buttons once per physics
## frame (as TLInput polls; the wheel from its events), owns the cursor, the ghost, the hotbar, undo and redo, saving
## and the test hook (build_devices.gd), and hands the rest to the tool: tools/blocks_tool.gd is M1's hand building;
## sculpt, paint, piece, stamp and command are M2, M3 and M4's; water, path and plant are M5's; rules is M6's (a stub
## until lane T lands). M6 seam: while build mode is off and no game is on stage the Home's rules run, once per physics
## frame after `build.step()` (`play`, rules_play.gd: lane P's). Host keys: B or Esc leave (Esc never quits
## from build mode), T / Shift+T next / previous tool, Enter the command tool, Ctrl+Z undo, Ctrl+Y (Ctrl+Shift+Z)
## redo, hold MMB or Alt look. A tool whose `blocks_input()` is true has the keyboard: the host reads no key then.
## Saving (user://home or TL_HOME_BUILD_DIR): on leaving, `autosave_frames` after the first unsaved change (never in a
## drag), on quit; only where a load was made (a person walks the Home, or `open(dir)`); an unreadable build file is
## never written over. Mounting: home/hook.gd `grow` calls `mount`; metas "tl_build" (the builder) and
## "tl_build_mode" (this node). A case sets `cam`, `feet_at` and `pointer`.
## F2 (27 Nov 2026 day, the newcomer's playtest #3, #4, #7): the hotbar answers a click (hotbar.gd `at`: a tab picks
## its tool, a slot presses its key for the tool, a gap between them takes the click) and a press on the bar never
## reaches the tool, so nothing is built behind it; while the pointer is over the bar the tool aims at nothing (no
## ghost). Where can I build (buildable.gd, refusal_tint.gd): with a ground tool or a stamp in the hand the refused
## ground round the cursor is tinted red, and the hotbar's where line says the reason as a sentence and, when the
## cursor's own ground is refused, the way to the nearest buildable ground; a cursor past the reach says so.

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const Ghost := preload("res://kernel/world/build/ghost.gd")
const Hotbar := preload("res://kernel/world/build/hotbar.gd")
const Devices := preload("res://kernel/world/build/build_devices.gd")
const TOOLS := [preload("res://kernel/world/build/tools/blocks_tool.gd"), preload("res://kernel/world/build/tools/sculpt_tool.gd"),
	preload("res://kernel/world/build/tools/paint_tool.gd"), preload("res://kernel/world/build/tools/piece_tool.gd"),
	preload("res://kernel/world/build/tools/stamp_tool.gd"), preload("res://kernel/world/build/tools/water_tool.gd"),
	preload("res://kernel/world/build/tools/path_tool.gd"), preload("res://kernel/world/build/tools/plant_tool.gd"),
	preload("res://kernel/world/build/tools/assembly_tool.gd"), preload("res://kernel/world/build/tools/rules_tool.gd"),
	preload("res://kernel/world/build/tools/command_tool.gd")]   # strip order; seam_lists.gd TOOLS holds the cases to it
const RulesPlay := preload("res://kernel/world/build/rules_play.gd")
const Buildable := preload("res://kernel/world/build/buildable.gd")
const RefusalTint := preload("res://kernel/world/build/refusal_tint.gd")
const FAR := 400.0                      # metres a cursor ray past the reach is asked, to say "out of reach"
const OUT_OF_REACH := "out of reach: aim within 24 m of you (F flies you closer)"
const SELF := "res://kernel/world/build/build_mode.gd"
const REACH := 24.0                     # metres the cursor reaches past the camera's distance to the visitor
const AUTOSAVE_FRAMES := 1800
const HOST_KEYS := [KEY_B, KEY_ESCAPE, KEY_T, KEY_ENTER, KEY_KP_ENTER, KEY_Z, KEY_Y]

var build: RefCounted = null            # home_build.gd
var land: Node3D = null                 # the landscape it hangs under
var active := false
var looking := false
var tools: Array = []                   # TOOLS made, in that order (T cycles them)
var tool_index := 0
var dir := ""                           # where the Home is saved ("" = nothing is saved)
var blocked := ""                       # why nothing may be saved (the build file there could not be read)
var save_error := ""
var frames := 0
var autosave_frames := AUTOSAVE_FRAMES
var cam: Camera3D = null                # set by a test; else the view's visitor's camera
var feet_at: Callable                   # () -> Vector3, set by a test; else the view's visitor's feet
var pointer := Vector2(-1.0, -1.0)      # a pixel set by a test or the hook; negative: the mouse
var hit := {}                           # the last pick (home_build.gd `pick`)
var ghost: Node3D = null
var hotbar: CanvasLayer = null
var _polled: Array = []                 # HOST_KEYS and every tool's `polled()`
var _down := {}                         # polled key / button -> down at the last poll
var _wheel := 0
var _holding := 0                       # the mouse button the current tool holds (a drag), 0: none
var _dirty_at := -1                     # frame of the first unsaved change (-1: none)
var devices: RefCounted = null          # build_devices.gd: TL_BUILD_DEVICES (a test hook)
var play: RefCounted = null             # M6: rules_play.gd, the Home's rules while build mode is off (lane P's)
var _view: Node = null
var _saved_on_exit := false
var bar_hover := {}                     # F2: hotbar.gd `at` under the pointer ({"tool": i} or {"slot": i}), {} none
var where_line := ""                    # F2: the hotbar's where line now
var where: RefCounted = null            # F2: buildable.gd
var tint: MeshInstance3D = null         # F2: refusal_tint.gd
var bar_clicks := 0                     # F2: clicks the hotbar took (figures)

# M1's names for the blocks tool's selection (cases and the state line read them)
var shape: int:
	get: return tools[0].shape
	set(v): tools[0].shape = v
var mat: int:
	get: return tools[0].mat
	set(v): tools[0].mat = v
var turn: int:
	get: return tools[0].turn
	set(v): tools[0].turn = v
var flip: bool:
	get: return tools[0].flip
	set(v): tools[0].flip = v
var reason: String:
	get: return str(tool().status().get("reason", ""))


func _init() -> void:
	_polled = HOST_KEYS.duplicate()
	for s: GDScript in TOOLS:
		var t: RefCounted = s.new()
		t.setup(self)
		tools.append(t)
		for k: int in t.polled():
			if not _polled.has(k):
				_polled.append(k)


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
	tint = RefusalTint.new()
	add_child(tint)
	where = Buildable.new()
	_view = land.get_parent() if land != null else null
	build.dirty_changed.connect(_on_dirty)
	tree_exiting.connect(_on_exit)
	devices = Devices.new(self, OS.get_environment("TL_BUILD_DEVICES"))
	play = RulesPlay.new(self)


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
	tool().selected(true)
	print(JSON.stringify({"schema": "tl.view/1", "kind": "build_mode", "on": true, "frame": frames}, "", false))


func leave(why := "key") -> void:
	if not active:
		return
	_release()
	active = false
	looking = false
	hit = {}
	tool().selected(false)
	ghost.hide_ghost()
	_show_where({})
	bar_hover = {}
	save_now("leave")
	print(JSON.stringify({"schema": "tl.view/1", "kind": "build_mode", "on": false, "why": why, "frame": frames,
		"blocks": int(build.blocks.total)}, "", false))


## The current tool (tools/*.gd, BUILD.md "Tools").
func tool() -> RefCounted:
	return tools[tool_index]


## The tool `step` places on from the current one (T: +1, Shift+T: -1), or the tool called `id`.
func switch_tool(step: int, id := "") -> void:
	var to := posmod(tool_index + step, tools.size())
	if id != "":
		for i: int in tools.size():
			if tools[i].get("id") == id:
				to = i
	if to == tool_index:
		return
	_release()
	tool().selected(false)
	tool_index = to
	tool().selected(true)
	ghost.hide_ghost()
	print(JSON.stringify({"schema": "tl.view/1", "kind": "build_tool", "tool": str(tool().get("id")), "frame": frames}, "", false))


## The code a click of the blocks tool would place now (tools/blocks_tool.gd `code_now`).
func code_now() -> int:
	return tools[0].code_now()


## True while TL_BUILD_DEVICES runs (a tool then prints what each edit did).
func scripted() -> bool:
	return devices != null and not (devices.plan as Dictionary).is_empty()


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
	devices.run(frames)
	for t: RefCounted in tools:
		t.tick(frames)
	_poll()
	build.step()
	play.tick(frames)                          # M6: runs the rules only while not active and no game is on stage
	if _dirty_at >= 0 and frames - _dirty_at >= autosave_frames and _holding == 0:
		save_now("autosave")


func _process(_delta: float) -> void:
	if build == null:
		return
	bar_hover = {}
	if active and not looking and not tool().blocks_input():
		var over: Dictionary = hotbar.at(pointer_px()) if _holding == 0 else {}
		if not over.is_empty():              # F2: the pointer is on the bar: the tool aims at nothing
			if not over.has("bar"):
				bar_hover = over
			hit = {}
			tool().aim({}, _mods())
			ghost.hide_ghost()
			_show_where({})
		else:
			tool().aim(_pick(), _mods())
			var g: Dictionary = tool().ghost_state()
			if g.is_empty():
				ghost.hide_ghost()
			else:
				ghost.show_at(g.cell, int(g.code), str(g.mode))
			_show_where(hit, true)
	else:
		ghost.hide_ghost()
		_show_where({})
	hotbar.refresh(hotbar.state_of(self))


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
	_release()
	save_now("quit")
	if play != null:
		play.stop("quit")
	build.free_all()


func _on_dirty(d: bool) -> void:
	_dirty_at = frames if d else -1


# ------------------------------------------------------------------ input
func _edge(k: int, down: bool) -> bool:
	var was: bool = _down.get(k, false)
	_down[k] = down
	return down and not was


## The held modifiers and buttons a tool reads with a press or an aim.
func _mods() -> Dictionary:
	return {"ctrl": Input.is_physical_key_pressed(KEY_CTRL), "shift": Input.is_physical_key_pressed(KEY_SHIFT),
		"alt": Input.is_physical_key_pressed(KEY_ALT), "lmb": Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),
		"rmb": Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)}


func _poll() -> void:
	var stage := _stage()
	var vp := get_viewport()
	var f: Control = vp.gui_get_focus_owner() if vp != null else null
	var typing := f is LineEdit or f is TextEdit
	var taken: bool = active and tool().blocks_input()
	var e := {}
	for k: int in _polled:
		e[k] = _edge(k, Input.is_physical_key_pressed(k) and not typing and not taken)
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
	if taken:                                   # the tool has the keyboard (M4's bar): nothing else this frame
		_release()
		return
	if e[KEY_B] or e[KEY_ESCAPE]:
		leave("key" if e[KEY_B] else "esc")
		return
	var ctrl := Input.is_physical_key_pressed(KEY_CTRL)
	var shift := Input.is_physical_key_pressed(KEY_SHIFT)
	looking = Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) or Input.is_physical_key_pressed(KEY_ALT)
	if e[KEY_T] and not ctrl:
		switch_tool(-1 if shift else 1)
	elif e[KEY_ENTER] or e[KEY_KP_ENTER]:
		switch_tool(0, "command")
	var t := tool()
	for k: int in t.polled():
		if e.get(k, false):
			var ev := InputEventKey.new()
			ev.keycode = k as Key
			ev.physical_keycode = k as Key
			ev.pressed = true
			ev.shift_pressed = shift
			ev.ctrl_pressed = ctrl
			t.key(ev)
	for i: int in absi(wheel):
		var w := InputEventMouseButton.new()
		w.button_index = MOUSE_BUTTON_WHEEL_DOWN if wheel > 0 else MOUSE_BUTTON_WHEEL_UP
		w.pressed = true
		t.key(w)
	if ctrl and e[KEY_Z]:
		_release()
		if shift: build.redo()
		else: build.undo()
	elif ctrl and e[KEY_Y]:
		_release()
		build.redo()
	if looking:
		_release()
		return
	var over: Dictionary = hotbar.at(pointer_px()) if _holding == 0 else {}
	if not over.is_empty():                     # F2: a press on the bar is the bar's, never the tool's
		if lmb_e:
			_click_bar(over)
		return
	var h := _pick()
	if _holding != 0:
		if not (lmb if _holding == MOUSE_BUTTON_LEFT else rmb):
			_release()
		else:
			t.drag(h)
	if _holding == 0 and lmb_e and t.press(MOUSE_BUTTON_LEFT, _mods()):
		_holding = MOUSE_BUTTON_LEFT
	elif _holding == 0 and rmb_e and t.press(MOUSE_BUTTON_RIGHT, _mods()):
		_holding = MOUSE_BUTTON_RIGHT


## F2: a click on the bar (`over`: hotbar.gd `at`): a tab picks its tool, a slot presses its key for the current tool
## (as the digit key would), a gap between tabs or slots does nothing.
func _click_bar(over: Dictionary) -> void:
	bar_clicks += 1
	var what := "bar"
	if over.has("tool"):
		what = "tool %s" % str(tools[int(over.tool)].get("id"))
		switch_tool(int(over.tool) - tool_index)
	elif over.has("slot"):
		var k := str(over.get("key", ""))
		what = "slot %d (key %s)" % [int(over.slot), k]
		if k.length() == 1 and k.is_valid_int():
			var ev := InputEventKey.new()
			ev.keycode = (KEY_0 + int(k)) as Key
			ev.physical_keycode = ev.keycode
			ev.pressed = true
			tool().key(ev)
	print(JSON.stringify({"schema": "tl.view/1", "kind": "build_bar", "frame": frames, "click": what,
		"tool": str(tool().get("id"))}, "", false))


## F2: the where line and the refusal tint for the cursor's hit `h` ({} none: both cleared). `aiming`: build mode is
## on and the tool aims (a cursor with no hit then asks a longer ray: past the reach, the line says so).
func _show_where(h: Dictionary, aiming := false) -> void:
	if where == null:
		return
	var t := tool()
	var id := str(t.get("id"))
	var why := str(t.status().get("reason", ""))
	if h.is_empty():
		where.update(null, null, "", {}, "", frames)
		tint.hide_tint()
		where_line = OUT_OF_REACH if aiming and _past_reach() else ""
		return
	var land: RefCounted = build.layer("land") if build != null else null
	var foot := Vector2.ZERO
	if id == "stamp" and int(t.get("current")) >= 0:
		var d: Dictionary = t.call("stamp")
		var s: Array = d.get("size", [1, 1, 1])
		foot = Vector2(float(s[2]), float(s[0])) if int(t.get("turn")) % 2 == 1 else Vector2(float(s[0]), float(s[2]))
	where.update(build.protect, land, id, h, why, frames, foot)
	var height := Callable(land, "height_at") if land != null and land.has_method("height_at") else Callable()
	tint.show_cells(where.cells, where.tint_key, height, (h.pos as Vector3).y, where.free)
	where_line = where.line(why)


## True when the cursor's ray, carried FAR past the reach, meets something (the ground or a block out of reach).
func _past_reach() -> bool:
	var r := ray()
	if r.is_empty() or build == null:
		return false
	return not build.pick(r[0], r[0] + r[1] * (reach(r[0]) + FAR)).is_empty()


## The pixel the cursor is at: the test hook's `pointer` (following its world point `at`, as `ray` does), else the
## mouse's (viewport coordinates).
func pointer_px() -> Vector2:
	var c := _cam()
	if devices != null and devices.aim_at != null and c != null:
		pointer = c.unproject_position(devices.aim_at)
	if pointer.x >= 0.0:
		return pointer
	var vp := get_viewport()
	return vp.get_mouse_position() if vp != null else Vector2(-1.0, -1.0)


## The current tool lets go of the button it holds (a drag ends: one batch).
func _release() -> void:
	if _holding != 0:
		var b := _holding
		_holding = 0
		tool().release(b)


# ------------------------------------------------------------------ the cursor
func _pick() -> Dictionary:
	var r := ray()
	hit = {} if r.is_empty() else build.pick(r[0], r[0] + r[1] * reach(r[0]))
	return hit


## [from, direction] of the cursor's ray through the camera as it is drawn (its interpolated pose), or [].
func ray() -> Array:
	var c := _cam()
	var vp := get_viewport()
	if c == null or vp == null:
		return []
	if devices != null and devices.aim_at != null:
		pointer = c.unproject_position(devices.aim_at)
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
func reach(from: Vector3) -> float:
	var f: Variant = feet_at.call() if feet_at.is_valid() else (_visitor().get("feet") if _visitor() != null else null)
	return REACH + (from.distance_to(f as Vector3) if f is Vector3 else 0.0)


func forward() -> Vector3:
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
