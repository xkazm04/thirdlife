extends RefCounted
## M6 round 3, lane A6 (27 Nov 2026): build mode's Shapes tool, the hand's way to the assemblies the LLM writes
## (contracts/BUILD.md "Assemblies (M6, round 3)"; the thesis: the hand can do everything the LLM can). The person
## picks a kind, sees it as a ghost where the cursor is, and builds it as ONE batch (one undo):
##   1-6 kind (wall, tower, house, stair, bridge, platform)   wheel height (steps for a stair)   [ ] the kind's options
##   R turn the front   Tab / Shift+Tab material / trim   LMB a corner: a click builds the shape there at its size, a drag
##   sets the footprint from that corner to the cursor (on the corner's level), release builds it
## The ghost is a dry run of the expanded assemble (home_build.gd `preview`): holo where it builds, the count of blocks
## left out and why in the hotbar (protected or occupied cells: the place ops' own reasons). The op is exactly an
## LLM's assemble, so what the hand builds and what a model builds are the same blocks (selftest 794 `assembly.tool`).
## Interface: BUILD.md "Tools".

const Blocks := preload("res://kernel/world/build/blocks.gd")
const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const Assembly := preload("res://kernel/world/build/assembly.gd")
const PreviewMesh := preload("res://kernel/world/build/preview_mesh.gd")
const Unlocks := preload("res://kernel/world/build/unlocks.gd")
const MATS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12]
## Each kind's options in the order ] walks them (the first: none), and the size a click builds.
const PRESETS := {
	"wall": [{}, {"crenels": true}, {"door": -1, "windows": 3}, {"door": -1, "windows": 3, "crenels": true}],
	"tower": [{"stairs": "outside", "crenels": true}, {"stairs": "inside", "crenels": true, "windows": 3}, {"crenels": true, "windows": 3}, {}],
	"house": [{}, {"windows": 4}, {"windows": 0}], "stair": [{}], "bridge": [{}], "platform": [{}]}
const SIZES := {"wall": [7, 3, 1], "tower": [7, 10, 1], "house": [7, 4, 5], "stair": [2, 5, 1], "bridge": [3, 1, 9], "platform": [5, 1, 5]}
const DEFAULT_MATS := {"wall": [1, 2], "tower": [1, 2], "house": [3, 6], "stair": [1, 2], "bridge": [1, 4], "platform": [3, 4]}
const KEY_HELP := "1-6 kind   wheel height   [ ] options   R turn   Tab / Shift+Tab material / trim   LMB build here (drag: the footprint)   Ctrl+Z undo   hold MMB or Alt look   T tool   B or Esc leave"

var id := "shapes"
var title := "Shapes"
var host: Node = null                   # build_mode.gd
var kind := "tower"
var sizes := SIZES.duplicate(true)      # kind -> [w, h, d] the person last set
var preset := {}                        # kind -> index in PRESETS
var mats := DEFAULT_MATS.duplicate(true)
var turn := 0                           # R presses added to the facing rot
var reason := ""
var last := {}                          # the last build: {"op", "applied", "refused"} (the case reads it)
var unlocks: RefCounted = null
var preview: Node3D = null
var _shown := ""                        # the op drawn in `preview` (JSON)
var _left := []                         # the ghost's refused [[i, reason]]
var _cursor := Vector3i.ZERO
var _has_cursor := false
var _drag := {}                         # {"from": Vector3i, "to": Vector3i}


func setup(h: Node) -> void:
	host = h
	unlocks = Unlocks.new("")


func polled() -> Array:
	return [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_BRACKETLEFT, KEY_BRACKETRIGHT, KEY_R, KEY_TAB]


func selected(on: bool) -> void:
	_drag = {}
	reason = ""
	_has_cursor = false
	if on:
		turn = 0
		unlocks = Unlocks.new(str(host.get("dir")))
	_hide()


func slots() -> Array:
	var out := []
	for i: int in Assembly.KINDS.size():
		out.append({"key": str(i + 1), "label": Assembly.KINDS[i], "lit": Assembly.KINDS[i] == kind})
	return out


func status() -> Dictionary:
	var s: Array = size_now()
	var parts := PackedStringArray(["%s %d x %d x %d" % [kind, s[0], s[1], s[2]], Blocks.mat_key(int(mats[kind][0])).replace("_", " ")
		+ " / " + Blocks.mat_key(int(mats[kind][1])).replace("_", " ")])
	var o := opts_now()
	if not o.is_empty():
		parts.append(", ".join(PackedStringArray(o.keys().map(func(k: String) -> String:
			return k if typeof(o[k]) == TYPE_BOOL else "%s %s" % [k, str(o[k])]))))
	if not _left.is_empty():
		parts.append("%d left out: %s" % [_left.size(), str(_left[0][1])])
	return {"swatch": TLStyle.color(Blocks.mat_key(int(mats[kind][0]))), "info": "   ".join(parts), "reason": reason}


func hint() -> String:
	return KEY_HELP


func blocks_input() -> bool:
	return false


func size_now() -> Array:
	return sizes[kind]


## The kind's options now ({} none); a wall's door goes in its middle.
func opts_now() -> Dictionary:
	var list: Array = PRESETS[kind]
	var o: Dictionary = (list[int(preset.get(kind, 0)) % list.size()] as Dictionary).duplicate()
	if o.has("door"):
		o.door = int(size_now()[0]) / 2
	if kind == "house" and o.has("windows"):              # a count: no more than the front holds
		o.windows = mini(int(o.windows), Assembly.house_windows_max(int(size_now()[0])))
	return o


## The rot that turns the front toward the camera, plus the R presses.
func rot_now() -> int:
	var f: Vector3 = host.forward() if host != null and host.has_method("forward") else Vector3.FORWARD
	return (HomeBuild.rot_facing(f) + 2 + turn) % 4


## The assemble the tool would build now: at the cursor (a click), or over the dragged footprint.
func op_now() -> Dictionary:
	var r := rot_now()
	var s: Array = size_now().duplicate()
	var at := _cursor
	if not _drag.is_empty():
		var a: Vector3i = _drag.from
		var b: Vector3i = _drag.to
		var x0 := mini(a.x, b.x)
		var x1 := maxi(a.x, b.x)
		var z0 := mini(a.z, b.z)
		var z1 := maxi(a.z, b.z)
		var ex := mini(x1 - x0 + 1, Assembly.SIZE_MAX)
		var ez := mini(z1 - z0 + 1, Assembly.SIZE_MAX)
		x1 = x0 + ex - 1
		z1 = z0 + ez - 1
		at = [Vector3i(x0, a.y, z0), Vector3i(x0, a.y, z1), Vector3i(x1, a.y, z1), Vector3i(x1, a.y, z0)][r]
		var across := ex if r % 2 == 0 else ez     # along the shape's local x
		var deep := ez if r % 2 == 0 else ex       # along its local z
		match kind:
			"tower":
				s[0] = mini(across, deep)
			"wall", "stair":
				s[0] = across
			_:
				s[0] = across
				s[2] = deep
		sizes[kind] = s
	var op := {"op": "assemble", "kind": kind, "at": [at.x, at.y, at.z], "size": s, "rot": r, "mat": int(mats[kind][0])}
	if int(mats[kind][1]) != int(mats[kind][0]):
		op["trim"] = int(mats[kind][1])
	var o := opts_now()
	if not o.is_empty():
		op["opts"] = o
	return op


## The expanded ops of `op_now()` on the Home's ground (blocks_layer.gd `expand_input`), or [] with `reason` set.
func ops_now() -> Array:
	var e: Dictionary = host.build.expand_input([op_now()])
	if not (e.refused as Array).is_empty():
		reason = str(e.refused[0][1])
		return []
	return e.ops


func key(e: InputEvent) -> bool:
	if e is InputEventMouseButton:
		var bi: int = (e as InputEventMouseButton).button_index
		if bi == MOUSE_BUTTON_WHEEL_UP or bi == MOUSE_BUTTON_WHEEL_DOWN:
			var s: Array = size_now()
			var hi := 1 if kind in ["bridge", "platform"] else Assembly.SIZE_MAX
			s[1] = clampi(int(s[1]) + (1 if bi == MOUSE_BUTTON_WHEEL_UP else -1), 1, hi)
			_shown = ""
			return true
		return false
	var k := e as InputEventKey
	if k == null or not k.pressed:
		return false
	var code: int = k.physical_keycode
	if code >= KEY_1 and code <= KEY_6:
		kind = Assembly.KINDS[code - KEY_1]
	elif code == KEY_BRACKETRIGHT or code == KEY_BRACKETLEFT:
		preset[kind] = posmod(int(preset.get(kind, 0)) + (1 if code == KEY_BRACKETRIGHT else -1), (PRESETS[kind] as Array).size())
	elif code == KEY_R:
		turn = (turn + 1) % 4
	elif code == KEY_TAB:
		var slot := 1 if k.shift_pressed else 0
		mats[kind][slot] = MATS[posmod(MATS.find(int(mats[kind][slot])) + 1, MATS.size())]
	else:
		return false
	_shown = ""
	return true


# ------------------------------------------------------------------ the cursor and the ghost
func aim(h: Dictionary, _mode: Dictionary) -> void:
	if not _drag.is_empty():
		return
	if h.is_empty() or not h.has("place"):
		_has_cursor = false
		_hide()
		return
	_cursor = h.place
	_has_cursor = true
	_ghost()


func ghost_state() -> Dictionary:
	return {}


## Draws the dry run of the shape now (only when it changed): holo where it builds; `_left` the refused place ops.
func _ghost() -> void:
	var op := op_now()
	var key_s := JSON.stringify(op)
	if key_s == _shown and preview != null and is_instance_valid(preview) and preview.visible:
		return
	_shown = key_s
	reason = ""
	var ops := ops_now()
	if preview == null or not is_instance_valid(preview):
		preview = PreviewMesh.new()
		host.add_child(preview)
	if ops.is_empty():
		preview.visible = false
		_left = []
		return
	var r: Dictionary = host.build.preview(ops)
	_left = r.refused
	preview.call("show_stores", r.store, r.removed)
	preview.visible = true


func _hide() -> void:
	if preview != null and is_instance_valid(preview):
		preview.visible = false
	_shown = ""
	_left = []


# ------------------------------------------------------------------ edits
## LMB: the corner of the footprint (the cursor's place cell); the ghost follows the drag; `release` builds.
func press(button: int, _mods: Dictionary) -> bool:
	var h: Dictionary = host.hit
	if button != MOUSE_BUTTON_LEFT or not h.has("place"):
		return false
	var locked := ""
	for m: int in mats[kind]:
		if locked == "" and unlocks != null:
			locked = unlocks.locked("mats", m)
	if locked != "":
		reason = "locked: " + locked
		return false
	_cursor = h.place
	_has_cursor = true
	_drag = {"from": h.place, "to": h.place, "moved": false}
	_ghost()
	return true


func drag(h: Dictionary) -> void:
	if _drag.is_empty() or not h.has("place"):
		return
	var c: Vector3i = h.place
	var to := Vector3i(c.x, (_drag.from as Vector3i).y, c.z)
	if to != _drag.to:
		_drag.to = to
		_drag.moved = true
		_ghost()


## The button went up (or the host cut the hold): a click builds the shape at its size, a drag over its footprint;
## ONE batch. Leaving the tool or build mode mid-drag builds nothing (`selected`).
func release(button: int) -> void:
	if _drag.is_empty():
		return
	var was := _drag
	if not bool(was.moved):
		_drag = {}
	var op := op_now()
	var ops := ops_now()
	_drag = {}
	if button != MOUSE_BUTTON_LEFT or ops.is_empty():
		return
	host.build.begin_batch("hand")
	var r: Dictionary = host.build.apply(ops)
	host.build.end_batch()
	last = {"op": op, "applied": int(r.applied), "refused": (r.refused as Array).size()}
	reason = "" if (r.refused as Array).is_empty() else "%d left out: %s" % [(r.refused as Array).size(), str(r.refused[0][1])]
	_shown = ""
	if host.scripted():
		print(JSON.stringify({"schema": "tl.view/1", "kind": "build_assembly", "frame": host.frames, "op": op, "applied": int(r.applied),
			"refused": (r.refused as Array).size()}, "", false))


func dragging() -> bool:
	return not _drag.is_empty()


func tick(_frame: int) -> void:
	if preview != null and is_instance_valid(preview) and preview.visible and (not bool(host.get("active")) or host.call("tool") != self or bool(host.get("looking"))):
		_hide()
