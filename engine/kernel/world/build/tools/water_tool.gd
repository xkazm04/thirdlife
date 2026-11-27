extends RefCounted
## M5 lane W (spark world-sandbox): build mode's water tool. Point into a hollow (dug with the sculpt tool) and click:
## water fills it up to just under its spill level (water_layer.gd `pour_ops`, water_fill.gd), one batch, one undo.
## Before the click a ghost shows the fill in holo with its cell count and level; the wheel or [ ] lowers and raises the
## level (25 cm a notch, never above the spill's). Pouring into water there already re-levels it (the old body is
## drained in the same batch). 2 (or RMB in either slot) drains the body of water the cursor is over: the ghost shows it
## red. A refusal ("no hollow here: dig one first", "spills: too big", "spills into the river", "spills: game lot") is
## shown in red and nothing is applied. The cursor ray goes through water (it has no collider) to the bed.

const WaterMesh := preload("res://kernel/world/build/water_mesh.gd")
const STEP_CM := 25
const LOWER_MAX := 2400
const KEY_HELP := "LMB pour   1 pour   2 drain   wheel or [ ] level   RMB drain   Ctrl+Z undo   Ctrl+Y redo   hold MMB or Alt look   T tool   B or Esc leave"

var id := "water"
var title := "Water"
var host: Node = null                   # build_mode.gd
var mode := "pour"                      # "pour" | "drain"
var lower_cm := 0                       # how far under the highest level the next pour stands
var reason := ""
var plan := {}                          # the last aim's: {"key", "cell", "ops", "fill", "reason", "body"}
var shown: Node3D = null                # the ghost


func setup(h: Node) -> void:
	host = h


func polled() -> Array:
	return [KEY_1, KEY_2, KEY_BRACKETLEFT, KEY_BRACKETRIGHT]


func selected(on: bool) -> void:
	reason = ""
	plan = {}
	if not on:
		_show(null)


func slots() -> Array:
	return [{"key": "1", "label": "pour", "lit": mode == "pour"}, {"key": "2", "label": "drain", "lit": mode == "drain"}]


func layer() -> RefCounted:
	return host.build.layer("water") if host != null and host.build != null else null


func status() -> Dictionary:
	var s := {"info": info(), "reason": reason}
	var w: Variant = (TLStyle.data.get("water", {}) as Dictionary).get("deep") if TLStyle.data is Dictionary else null
	if w is String:
		s["swatch"] = Color(str(w))
	return s


## The line beside the swatch: what a click would do now.
func info() -> String:
	var low := "   lowered %.2f m" % (lower_cm / 100.0) if lower_cm > 0 else ""
	if mode == "drain":
		var body: Array = plan.get("body", [])
		return "drain: %d cells at %.2f m" % [body.size(), plan.level / 100.0] if not body.is_empty() else "drain: point at water"
	var f: Dictionary = plan.get("fill", {})
	if f.is_empty() or str(f.get("reason", "")) != "":
		return "pour: point into a hollow" + low
	return "pour: %d cells at %.2f m (spill %.2f m)%s" % [(f.cells as Array).size(), int(f.level) / 100.0, int(f.spill) / 100.0, low]


func hint() -> String:
	return KEY_HELP


func blocks_input() -> bool:
	return false


func key(e: InputEvent) -> bool:
	var mb := e as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_level(-STEP_CM if mb.button_index == MOUSE_BUTTON_WHEEL_UP else STEP_CM)
		return true
	var k := e as InputEventKey
	if k == null or not k.pressed:
		return false
	match k.physical_keycode:
		KEY_1:
			mode = "pour"
		KEY_2:
			mode = "drain"
		KEY_BRACKETLEFT:
			_level(STEP_CM)
		KEY_BRACKETRIGHT:
			_level(-STEP_CM)
		_:
			return false
	plan = {}
	return true


func _level(d: int) -> void:
	lower_cm = clampi(lower_cm + d, 0, LOWER_MAX)
	plan = {}


func aim(h: Dictionary, _mode: Dictionary) -> void:
	var l := layer()
	if l == null or not h.has("pos"):
		_show(null)
		reason = ""
		plan = {}
		return
	var p: Vector3 = h.pos
	var cell := Vector2i(floori(p.x / 3.0), floori(p.z / 3.0))
	var k := [cell, lower_cm, mode, host.build.edits.history.size(), host.build.edits.future.size()]
	if plan.get("key") == k:
		return
	plan = _plan(l, cell)
	plan["key"] = k
	reason = str(plan.get("reason", ""))
	_show(plan.get("ghost"))


## What a click at `cell` would do now, and its ghost.
func _plan(l: RefCounted, cell: Vector2i) -> Dictionary:
	if mode == "drain":
		var op: Dictionary = l.drain_op(cell)
		if op.is_empty():
			return {"cell": cell, "ops": [], "body": [], "reason": ""}
		var gone := {}
		for e: Array in op.cells:
			gone[Vector2i(e[0], e[1])] = int(e[2])
		return {"cell": cell, "ops": [op], "body": op.cells, "level": int(op.cells[0][2]), "reason": "",
			"ghost": WaterMesh.ghost({}, gone)}
	var r: Dictionary = l.pour_ops(cell, lower_cm)
	var out := {"cell": cell, "ops": r.ops, "fill": r.fill, "reason": r.reason}
	if str(r.reason) == "":
		var add := {}
		var gone := {}
		for op: Dictionary in r.ops:
			for e: Array in op.cells:
				if op.op == "flood":
					add[Vector2i(e[0], e[1])] = int(e[2])
				else:
					gone[Vector2i(e[0], e[1])] = int(e[2])
		for c: Vector2i in add:
			gone.erase(c)
		out["ghost"] = WaterMesh.ghost(add, gone)
	return out


func _show(n: Variant) -> void:
	if shown != null and is_instance_valid(shown):
		shown.queue_free()
	shown = null
	if n is Node3D and host != null:
		shown = n
		host.add_child(shown)


func ghost_state() -> Dictionary:
	return {}


func press(button: int, _mods: Dictionary) -> bool:
	if not host.hit.has("pos"):
		return false
	var drain := button == MOUSE_BUTTON_RIGHT or mode == "drain"
	if button != MOUSE_BUTTON_LEFT and button != MOUSE_BUTTON_RIGHT:
		return false
	var was := mode
	mode = "drain" if drain else "pour"
	plan = {}
	aim(host.hit, {})
	mode = was
	var ops: Array = plan.get("ops", [])
	if ops.is_empty():
		reason = str(plan.get("reason", "")) if str(plan.get("reason", "")) != "" else ("no water here" if drain else "")
		plan = {}
		return false
	var r: Dictionary = host.build.apply(ops)
	reason = "" if bool(r.ok) else str(r.reason)
	if host.scripted():
		var f: Dictionary = plan.get("fill", {})
		print(JSON.stringify({"schema": "tl.view/1", "kind": "build_edit", "frame": host.frames, "op": "drain" if drain else "pour",
			"cells": (ops[ops.size() - 1].cells as Array).size(), "level": int(f.get("level", plan.get("level", 0))),
			"spill": int(f.get("spill", 0)), "fill_usec": int(f.get("usec", 0)), "ok": bool(r.ok), "reason": str(r.reason)}, "", false))
	plan = {}
	_show(null)
	return false


func drag(_h: Dictionary) -> void:
	pass


func release(_button: int) -> void:
	pass


func dragging() -> bool:
	return false


func tick(_frame: int) -> void:
	pass
