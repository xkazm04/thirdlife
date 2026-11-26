extends RefCounted
## SEAM (spark world-sandbox): build mode's blocks tool, M1's hand building moved out of build_mode.gd unchanged:
##   LMB place (a drag places along the cells crossed, ONE batch)    RMB remove (a drag is one batch)
##   wheel or 1-8 shape   Tab / Shift+Tab material (1-9, then M3's 11 brick and 12 plaster, locked until play unlocks them; a window's pane is glass by itself)   R turn (+1 rot)
##   F2 flip (stair, ramp, roof)
## The ghost shows the remove target (red) while RMB is held or Ctrl is down; otherwise the place target (holo, red
## with the reason when `can_place` refuses). A drag keeps to the plane of the surface first pressed: the cursor
## slides on that plane (the ground's height there, a row's top, a wall's side), and every cell it crosses on it gets
## the first cell's level (or wall plane). The default rot is HomeBuild.rot_facing(camera forward); R adds a quarter
## turn. The tool interface is BUILD.md "Tools".

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const Blocks := preload("res://kernel/world/build/blocks.gd")
const DRAG_MAX := 64                    # cells one drag may touch
const MATS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12]   # materials Tab walks (10, glass, is a window's pane; 11 brick and 12 plaster
                                        # are M3's, locked until play unlocks them: unlocks.gd)
const Unlocks := preload("res://kernel/world/build/unlocks.gd")
const TURNS := [Blocks.STAIR, Blocks.RAMP, Blocks.ROOF, Blocks.WINDOW]
const FLIPS := [Blocks.STAIR, Blocks.RAMP, Blocks.ROOF]
const KEY_HELP := "LMB place (drag: a line)   RMB remove   wheel or 1-8 shape   Tab / Shift+Tab material   R turn   F2 flip   Ctrl+Z undo   Ctrl+Y redo   hold MMB or Alt look   T tool   B or Esc leave"

var id := "blocks"
var title := "Blocks"
var host: Node = null                   # build_mode.gd
var shape := Blocks.CUBE
var mat := 3                            # plank
var turn := 0                           # R presses (quarter turns added to the facing rot)
var flip := false
var reason := ""                        # why the ghost's cell is refused ("" = it is not)
var _ghost := {}
var unlocks: RefCounted = null          # M3: what play has unlocked (read again when the tool is picked)
var _drag := {}                         # {"op": "place"|"remove", "axis", "at", "plane", "last": Vector3i, "done": {cell: true}}


func setup(h: Node) -> void:
	host = h
	unlocks = Unlocks.new("")


func polled() -> Array:
	return [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_TAB, KEY_R, KEY_F2]


## Build mode turned on (`on`) or off, or this tool picked or left: a drag ends, the turn starts again.
func selected(on: bool) -> void:
	release(0)
	reason = ""
	_ghost = {}
	if on:
		turn = 0
		unlocks = Unlocks.new(str(host.get("dir")))


func slots() -> Array:
	var out := []
	for i: int in range(1, 9):
		out.append({"key": str(i), "label": Blocks.SHAPE_NAMES[i], "lit": i == shape})
	return out


func status() -> Dictionary:
	var parts := PackedStringArray([Blocks.mat_key(mat).replace("_", " ") + (" (locked)" if locked_mat() != "" else "")])
	if shape in TURNS:
		parts.append("rot %d" % rot_now())
	if shape in FLIPS:
		parts.append("flipped" if flip else "upright")
	return {"swatch": TLStyle.color(Blocks.mat_key(mat)), "info": "   ".join(parts), "reason": reason}


func hint() -> String:
	return KEY_HELP


func blocks_input() -> bool:
	return false


func rot_now() -> int:
	return (HomeBuild.rot_facing(host.forward()) + turn) % 4


## The code a click would place now: the selected shape and material, the rot facing away from the camera plus the
## R turns (shapes that do not turn keep 0), flip only for a stair, ramp or roof.
func code_now() -> int:
	return HomeBuild.code(shape, mat, rot_now() if shape in TURNS else 0, flip and shape in FLIPS)


## M3: "" or the condition that unlocks the selected material.
func locked_mat() -> String:
	return unlocks.locked("mats", mat) if unlocks != null else ""


func key(e: InputEvent) -> bool:
	if e is InputEventMouseButton:
		var bi: int = (e as InputEventMouseButton).button_index
		if bi == MOUSE_BUTTON_WHEEL_UP or bi == MOUSE_BUTTON_WHEEL_DOWN:
			shape = posmod(shape - 1 + (1 if bi == MOUSE_BUTTON_WHEEL_DOWN else -1), 8) + 1
			return true
		return false
	var k := e as InputEventKey
	if k == null or not k.pressed:
		return false
	var code: int = k.physical_keycode
	if code >= KEY_1 and code <= KEY_8:
		shape = code - KEY_1 + 1
	elif code == KEY_TAB:
		mat = MATS[posmod(MATS.find(mat) + (-1 if k.shift_pressed else 1), MATS.size())]
	elif code == KEY_R:
		turn = (turn + 1) % 4
	elif code == KEY_F2:
		flip = not flip
	else:
		return false
	return true


# ------------------------------------------------------------------ the cursor
func aim(h: Dictionary, mode: Dictionary) -> void:
	if h.is_empty():
		_ghost = {}
		reason = ""
		return
	if bool(mode.get("rmb", false)) or bool(mode.get("ctrl", false)):
		reason = ""
		_ghost = {} if h.remove == HomeBuild.NO_CELL else {"cell": h.remove, "code": 0, "mode": "remove"}
		return
	var c := code_now()
	reason = locked_mat()
	reason = "locked: " + reason if reason != "" else host.build.can_place(h.place, c)
	_ghost = {"cell": h.place, "code": c, "mode": "place" if reason.is_empty() else "refused"}


func ghost_state() -> Dictionary:
	return _ghost


# ------------------------------------------------------------------ edits
## A press starts a drag where the cursor is (host.hit). Returns true when it holds the button (a drag started).
func press(button: int, _mods: Dictionary) -> bool:
	var h: Dictionary = host.hit
	if button == MOUSE_BUTTON_LEFT and h.has("place") and locked_mat() != "":
		reason = "locked: " + locked_mat()
		return false
	if button == MOUSE_BUTTON_LEFT and h.has("place"):
		_start("place", h.place, h)
		return true
	if button == MOUSE_BUTTON_RIGHT and h.has("remove") and h.remove != HomeBuild.NO_CELL:
		_start("remove", h.remove, h)
		return true
	return false


## The drag keeps to the plane of the surface first pressed: through the press point, across the axis of its normal
## (the cursor slides along that surface; every cell it crosses is on the first cell's layer).
func _start(op: String, c: Vector3i, h: Dictionary) -> void:
	var a: Vector3 = (h.normal as Vector3).abs()
	var axis := 0 if a.x >= a.y and a.x >= a.z else (1 if a.y >= a.z else 2)
	host.build.begin_batch("hand")
	_drag = {"op": op, "axis": axis, "at": c[axis], "plane": float((h.pos as Vector3)[axis]), "last": c, "done": {}}
	_edit(c)


func release(_button: int) -> void:
	if not _drag.is_empty():
		host.build.end_batch()
		_drag = {}


func dragging() -> bool:
	return not _drag.is_empty()


## The cell under the cursor on the drag's plane; every cell on the line from the last one to it is edited.
func drag(_h: Dictionary) -> void:
	if _drag.is_empty():
		return
	var ray: Array = host.ray()
	if ray.is_empty():
		return
	var ax: int = _drag.axis
	var from: Vector3 = ray[0]
	var d: Vector3 = ray[1]
	if absf(d[ax]) < 0.0001:
		return
	var t := (float(_drag.plane) - from[ax]) / d[ax]
	if t <= 0.0 or t > host.reach(from):
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
		r = host.build.place(c, code_now())
	elif host.build.code_at(c) != 0:
		r = host.build.remove(c)
	else:
		return
	if not bool(r.ok):
		reason = str(r.reason)
	if host.scripted():                        # the test hook says what each edit did
		print(JSON.stringify({"schema": "tl.view/1", "kind": "build_edit", "frame": host.frames, "op": _drag.op, "at": [c.x, c.y, c.z],
			"code": code_now() if _drag.op == "place" else 0, "ok": bool(r.ok), "reason": str(r.reason)}, "", false))


func tick(_frame: int) -> void:
	pass
