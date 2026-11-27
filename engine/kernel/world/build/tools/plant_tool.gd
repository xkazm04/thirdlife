extends RefCounted
## M5 lane L (spark world-sandbox): build mode's plant tool. The round brush (land_brush.gd: radius 1..8 cells of 3 m,
## wheel or [ ]) paints growth on the 3 m cells whose centres it covers; held LMB keeps growing where the cursor goes:
##   1 meadow   2 flowers   3 tall grass   0 or Backspace clear (the ground's own growth: `valley`)
## A held stroke is ONE `plant` op and one undo step (plants_layer.gd `stroke_*`). The growth is drawn by the ground's
## shader (the land mesh's density channel), never by instances. Two more slots scatter kit parts in the brush disc:
##   4 trees   5 bushes
## a press puts seeded `put` ops from plant_scatter.gd `scatter(...)` (lane P writes it; its stub gives none, and the
## info line says so); held and moved, the brush scatters again each time it has moved a radius, all in one batch (one
## Ctrl+Z). Cells in a protected area are left alone and the hotbar names the reason.

const LandBrush := preload("res://kernel/world/build/land_brush.gd")
const PlantScatter := preload("res://kernel/world/build/plant_scatter.gd")
const SLOTS := ["meadow", "flowers", "tall_grass", "trees", "bushes"]
const PER_100M2 := {"trees": 0.8, "bushes": 2.5}     # plants per 100 m2 a scatter asks for
const KEY_HELP := "LMB grow (held: a stroke)   1 meadow  2 flowers  3 tall grass  4 trees  5 bushes   0 or Backspace clear   wheel or [ ] brush   Ctrl+Z undo   Ctrl+Y redo   hold MMB or Alt look   T tool   B or Esc leave"

var id := "plant"
var title := "Plants"
var host: Node = null                   # build_mode.gd
var brush: RefCounted = LandBrush.new()
var slot := "meadow"                    # a growth name, "valley" (clear), "trees" or "bushes"
var reason := ""
var note := ""                          # what the last scatter did (info line)
var _held := false
var _last: Variant = null               # a scatter stroke: where the brush last scattered
var _seed := 1
var _batch := false


func setup(h: Node) -> void:
	host = h
	brush.setup(h)
	brush.radius = 3


func polled() -> Array:
	return [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_0, KEY_BACKSPACE, KEY_BRACKETLEFT, KEY_BRACKETRIGHT]


func selected(on: bool) -> void:
	release(0)
	reason = ""
	if not on:
		brush.hide()


func slots() -> Array:
	var out := []
	for i: int in SLOTS.size():
		out.append({"key": str(i + 1), "label": SLOTS[i].replace("_", " "), "lit": SLOTS[i] == slot})
	out.append({"key": "0", "label": "clear", "lit": slot == "valley"})
	return out


func scattering() -> bool:
	return slot == "trees" or slot == "bushes"


func status() -> Dictionary:
	var what := "clear (the ground's own growth)" if slot == "valley" else slot.replace("_", " ")
	if scattering():
		what += " (%.1f per 100 m2)" % float(PER_100M2[slot])
	var s := {"info": "%s   brush %d (%d m)%s" % [what, brush.radius, int(brush.metres()), ("   " + note) if note != "" else ""], "reason": reason}
	var key: String = {"meadow": "grass", "flowers": "neon_pink", "tall_grass": "grass_dark", "trees": "leaf", "bushes": "leaf"}.get(slot, "")
	if key != "" and TLStyle.has_key(key):
		s["swatch"] = TLStyle.color(key)
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
	if code >= KEY_1 and code <= KEY_5:
		slot = SLOTS[code - KEY_1]
	elif code == KEY_0 or code == KEY_BACKSPACE:
		slot = "valley"
	else:
		return false
	note = ""
	return true


func aim(h: Dictionary, _mode: Dictionary) -> void:
	var at: Variant = h.get("pos")
	if at == null:
		brush.show_ring(null)
		if not _held:
			reason = ""
		return
	if not _held:
		reason = brush.first_refusal(at, "plant")
	brush.show_ring(at, reason != "" and not _held)


func ghost_state() -> Dictionary:
	return {}


func press(button: int, _mods: Dictionary) -> bool:
	if button != MOUSE_BUTTON_LEFT or not host.hit.has("pos"):
		return false
	_held = true
	reason = ""
	brush.forget()
	if scattering():
		host.build.begin_batch("hand")
		_batch = true
		_last = null
		_scatter(host.hit.pos)
	else:
		_plants().stroke_begin()
		_grow(host.hit.pos)
	return true


func drag(h: Dictionary) -> void:
	if not _held or not h.has("pos"):
		return
	if scattering():
		if _last == null or Vector2(h.pos.x - _last.x, h.pos.z - _last.z).length() >= brush.metres():
			_scatter(h.pos)
	else:
		_grow(h.pos)


func release(_button: int) -> void:
	if not _held:
		return
	_held = false
	if _batch:
		_batch = false
		host.build.end_batch()
		return
	var op: Dictionary = _plants().stroke_end()
	if op.is_empty():
		return
	var r: Dictionary = host.build.apply(op)
	if not bool(r.ok):
		reason = str(r.reason)
	if host.scripted():
		print(JSON.stringify({"schema": "tl.view/1", "kind": "build_edit", "frame": host.frames, "op": "plant", "growth": slot,
			"cells": (op.cells as Array).size(), "ok": bool(r.ok), "reason": str(r.reason)}, "", false))


func dragging() -> bool:
	return _held


func _plants() -> RefCounted:
	return host.build.layer("plants")


func _grow(at: Vector3) -> void:
	var pl: RefCounted = _plants()
	var land: RefCounted = brush.layer()
	var r: float = brush.metres()
	land.begin_asking(Rect2(at.x - r - 6.0, at.z - r - 6.0, 2.0 * r + 12.0, 2.0 * r + 12.0))
	for e: Array in brush.under(at, true):
		var c: Vector2i = e[0]
		var why: String = brush.refusal(c, "plant")
		if why != "":
			reason = why
			continue
		if pl.growth_at(c) != slot:
			pl.stroke_grow(c, slot)
	land.end_asking()


## One scatter in the brush disc at `at`: the seeded put ops of plant_scatter.gd, applied in the open batch.
func _scatter(at: Vector3) -> void:
	_last = at
	_seed += 1
	var kind := "tree" if slot == "trees" else "bush"
	var ops: Array = PlantScatter.scatter(host.build, at, brush.metres(), kind, float(PER_100M2[slot]), hash([roundi(at.x), roundi(at.z), _seed]))
	if ops.is_empty():
		note = "no %s scattered here (plant_scatter.gd gave none)" % slot
		return
	var r: Dictionary = host.build.apply(ops)
	note = "%d %s put" % [int(r.get("applied", 0)), slot]
	if not bool(r.ok):
		reason = str(r.reason)
	if host.scripted():
		print(JSON.stringify({"schema": "tl.view/1", "kind": "build_edit", "frame": host.frames, "op": "put", "scatter": kind,
			"puts": ops.size(), "applied": int(r.get("applied", 0)), "ok": bool(r.ok), "reason": str(r.reason)}, "", false))


func tick(_frame: int) -> void:
	pass
