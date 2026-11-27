extends RefCounted
## M2 (spark world-sandbox): build mode's sculpt tool. A round brush on the 3 m lattice (land_brush.gd: radius 1..8
## cells, wheel or [ ]), its ring on the ground. Held LMB works the ground under it every physics frame, with a soft
## falloff, in the selected way:
##   1 raise (Shift: lower)   2 lower (Shift: raise)   3 flatten to the height under the first press   4 smooth
## A held stroke is ONE op and one undo step: the land layer records each vertex's height at its first touch and its
## last (land_layer.gd `stroke_*`). Vertices in a protected area are left alone and the hotbar names the reason; a
## vertex stops 24 m from the ground's own height ("height limit"). F and S are not used: they are flight and walking
## back (kernel/runner/visit.gd), which still work while building.

const LandBrush := preload("res://kernel/world/build/land_brush.gd")
const MODES := ["raise", "lower", "flatten", "smooth"]
const RATE_CM := 6.0                     # cm per physics frame at the brush's centre (raise, lower): 3.6 m/s
const FLATTEN := 0.18                    # of the way to the flat height per frame at the centre
const SMOOTH := 0.25                     # of the way to the neighbours' mean per frame at the centre
const ROUND := 0.04                      # raise and lower also move this much of the way to the neighbours' mean (shoulders round)
const LIMIT_CM := 2400
const KEY_HELP := "LMB work the ground (Shift: the other way)   1 raise  2 lower  3 flatten  4 smooth   wheel or [ ] brush   Ctrl+Z undo   Ctrl+Y redo   hold MMB or Alt look   T tool   B or Esc leave"

var id := "sculpt"
var title := "Sculpt"
var host: Node = null                   # build_mode.gd
var brush: RefCounted = LandBrush.new()
var mode := 0
var reason := ""
var _held := false
var _invert := false
var _flat_cm := 0
var _acc := {}                          # Vector2i -> float cm: the stroke's heights (they move by less than a cm a frame at the rim)
var _at: Variant = null                 # where the cursor meets the ground (null: nowhere)
var frames := 0                         # frames worked in the stroke now
var _plane_y := 0.0                     # the height of the first press: the stroke keeps to that level plane
var _centre: Variant = null             # where the brush works now (the ring is drawn there while held)


func setup(h: Node) -> void:
	host = h
	brush.setup(h)


func polled() -> Array:
	return [KEY_1, KEY_2, KEY_3, KEY_4, KEY_BRACKETLEFT, KEY_BRACKETRIGHT]


func selected(on: bool) -> void:
	release(0)
	reason = ""
	if not on:
		brush.hide()


func slots() -> Array:
	var out := []
	for i: int in MODES.size():
		out.append({"key": str(i + 1), "label": MODES[i], "lit": i == mode})
	return out


func status() -> Dictionary:
	return {"info": "%s   brush %d (%d m)" % [MODES[mode], brush.radius, int(brush.metres())], "reason": reason}


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
	if code >= KEY_1 and code <= KEY_4:
		mode = code - KEY_1
		return true
	return false


func aim(h: Dictionary, _mode: Dictionary) -> void:
	_at = h.get("pos")
	if _at == null:
		brush.show_ring(null)
		if not _held:
			reason = ""
		return
	if not _held:
		reason = brush.first_refusal(_at, "land")
	brush.show_ring(_centre if _held and _centre != null else _at, reason != "" and not _held)


func ghost_state() -> Dictionary:
	return {}


func press(button: int, mods: Dictionary) -> bool:
	if button != MOUSE_BUTTON_LEFT or not host.hit.has("pos"):
		return false
	var l: RefCounted = brush.layer()
	_held = true
	_invert = bool(mods.get("shift", false))
	_acc = {}
	frames = 0
	reason = ""
	brush.forget()
	var p: Vector3 = host.hit.pos
	_flat_cm = roundi(float(l.height_at(p.x, p.z)) * 100.0)
	_plane_y = p.y
	l.stroke_begin("land")
	_work(p)
	return true


## Each physics frame while LMB is held: the brush works where the cursor meets the ground now.
## Each physics frame while LMB is held: the brush works where the cursor's ray meets the level plane of the first
## press (land_brush.gd `on_plane`), so a still cursor keeps the brush still while the ground rises or sinks under it.
func drag(h: Dictionary) -> void:
	if not _held:
		return
	var p: Variant = brush.on_plane(_plane_y)
	if p == null and h.has("pos"):
		p = h.pos
	if p != null:
		_work(p)


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
		print(JSON.stringify({"schema": "tl.view/1", "kind": "build_edit", "frame": host.frames, "op": "land", "mode": MODES[mode],
			"verts": (op.verts as Array).size(), "frames": frames, "ok": bool(r.ok), "reason": str(r.reason)}, "", false))


func dragging() -> bool:
	return _held


func _work(at: Vector3) -> void:
	_centre = at
	var l: RefCounted = brush.layer()
	frames += 1
	var way := mode
	if _invert and way < 2:
		way = 1 - way
	var list: Array = brush.under(at, false, way == 2)
	var r: float = brush.metres()
	l.begin_asking(Rect2(at.x - r - 6.0, at.z - r - 6.0, 2.0 * r + 12.0, 2.0 * r + 12.0))
	for e: Array in list:
		var v: Vector2i = e[0]
		var why: String = brush.refusal(v, "land")
		if why != "":
			reason = why
			continue
		var now: float = _acc.get(v, float(l.cm_at(v)))
		var f: float = e[1]
		var to := now
		match way:
			0, 1:
				to = now + (RATE_CM if way == 0 else -RATE_CM) * f + (_mean(l, v) - now) * ROUND * f
			2: to = now + (_flat_cm - now) * minf(1.0, FLATTEN * f)
			3: to = now + (_mean(l, v) - now) * minf(1.0, SMOOTH * f)
		var wet: String = l.water_refusal(v, roundi(to)) if way != 0 else ""
		if wet != "":
			reason = wet
			continue
		var base: int = l.ground().base_cm(v)
		if absf(to - base) > LIMIT_CM:
			to = clampf(to, base - LIMIT_CM, base + LIMIT_CM)
			reason = "height limit (24 m from the ground's own %.1f m)" % (base / 100.0)
		_acc[v] = to
		var cm := roundi(to)
		if cm != l.cm_at(v):
			l.stroke_set(v, cm)
	l.end_asking()


## The mean of the four neighbours of `v` (cm), as the stroke has them now.
func _mean(l: RefCounted, v: Vector2i) -> float:
	var mean := 0.0
	for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		mean += float(_acc.get(v + o, float(l.cm_at(v + o))))
	return mean / 4.0


func tick(_frame: int) -> void:
	pass
