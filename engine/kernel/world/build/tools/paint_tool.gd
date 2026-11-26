extends RefCounted
## M2 (spark world-sandbox): build mode's paint tool. The round brush (land_brush.gd: radius 1..8 cells of 3 m, wheel
## or [ ]) paints the 3 m cells whose centres it covers with the selected ground material; held LMB keeps painting
## where the cursor goes. 1-8 pick the paint (contracts/BUILD.md's names), 0 or Backspace the eraser ("valley": the
## ground's own material again). A held stroke is ONE op and one undo step (land_layer.gd `stroke_*`). Cells in a
## protected area are left alone and the hotbar names the reason. Grass grows from the paint (the ground's shader draws
## tufts where the paint is a grass), so dirt and sand are bare and the grasses carry it.

const LandBrush := preload("res://kernel/world/build/land_brush.gd")
const PAINTS := ["grass", "grass_dark", "grass_dry", "dirt", "sand", "stone", "rock_warm", "cliff"]
const KEY_HELP := "LMB paint   1-8 paint   0 or Backspace eraser   wheel or [ ] brush   Ctrl+Z undo   Ctrl+Y redo   hold MMB or Alt look   T tool   B or Esc leave"

var id := "paint"
var title := "Paint"
var host: Node = null                   # build_mode.gd
var brush: RefCounted = LandBrush.new()
var paint := "dirt"
var reason := ""
var _held := false
var _at: Variant = null


func setup(h: Node) -> void:
	host = h
	brush.setup(h)
	brush.radius = 2


func polled() -> Array:
	return [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_0, KEY_BACKSPACE, KEY_BRACKETLEFT, KEY_BRACKETRIGHT]


func selected(on: bool) -> void:
	release(0)
	reason = ""
	if not on:
		brush.hide()


func slots() -> Array:
	var out := []
	for i: int in PAINTS.size():
		out.append({"key": str(i + 1), "label": PAINTS[i].replace("_", " "), "lit": PAINTS[i] == paint})
	out.append({"key": "0", "label": "eraser", "lit": paint == "valley"})
	return out


func status() -> Dictionary:
	var s := {"info": "%s   brush %d (%d m)" % ["eraser (the valley's own ground)" if paint == "valley" else paint.replace("_", " "),
		brush.radius, int(brush.metres())], "reason": reason}
	if paint != "valley" and TLStyle.has_key(paint):
		s["swatch"] = TLStyle.color(paint)
	return s


func hint() -> String:
	return KEY_HELP


func blocks_input() -> bool:
	return false


func key(e: InputEvent) -> bool:
	if brush.resize(e):
		return true
	var k := e as InputEventKey
	if k == null or not k.pressed:
		return false
	var code: int = k.physical_keycode
	if code >= KEY_1 and code <= KEY_8:
		paint = PAINTS[code - KEY_1]
	elif code == KEY_0 or code == KEY_BACKSPACE:
		paint = "valley"
	else:
		return false
	return true


func aim(h: Dictionary, _mode: Dictionary) -> void:
	_at = h.get("pos")
	if _at == null:
		brush.show_ring(null)
		if not _held:
			reason = ""
		return
	if not _held:
		reason = brush.first_refusal(_at, "paint")
	brush.show_ring(_at, reason != "" and not _held)


func ghost_state() -> Dictionary:
	return {}


func press(button: int, _mods: Dictionary) -> bool:
	if button != MOUSE_BUTTON_LEFT or not host.hit.has("pos"):
		return false
	_held = true
	reason = ""
	brush.forget()
	brush.layer().stroke_begin("paint")
	_work(host.hit.pos)
	return true


func drag(h: Dictionary) -> void:
	if _held and h.has("pos"):
		_work(h.pos)


func release(_button: int) -> void:
	if not _held:
		return
	_held = false
	var op: Dictionary = brush.layer().stroke_end()
	if op.is_empty():
		return
	var r: Dictionary = host.build.apply(op)
	if not bool(r.ok):
		reason = str(r.reason)
	if host.scripted():
		print(JSON.stringify({"schema": "tl.view/1", "kind": "build_edit", "frame": host.frames, "op": "paint", "paint": paint,
			"cells": (op.cells as Array).size(), "ok": bool(r.ok), "reason": str(r.reason)}, "", false))


func dragging() -> bool:
	return _held


func _work(at: Vector3) -> void:
	var l: RefCounted = brush.layer()
	var r: float = brush.metres()
	l.begin_asking(Rect2(at.x - r - 6.0, at.z - r - 6.0, 2.0 * r + 12.0, 2.0 * r + 12.0))
	for e: Array in brush.under(at, true):
		var c: Vector2i = e[0]
		var why: String = brush.refusal(c, "paint")
		if why != "":
			reason = why
			continue
		if l.store.paint_at(c) != paint:
			l.stroke_paint(c, paint)
	l.end_asking()


func tick(_frame: int) -> void:
	pass
