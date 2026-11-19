extends Control
## E1: the village from above (boot/village.json), north up, with the new game's ghost: its footprint inside its lot
## ring, its gate toward the road and the dashed path in. Left press places the ghost there (or picks it up when the
## press is inside its ring) and dragging moves it; the wheel and Q / E turn it by 15 degrees. It draws what the model
## says and writes only `at` and `yaw` into it; `changed` tells the workbench to redraw the rest.

signal changed

var model: RefCounted                # editor/editor_model.gd
var col: Dictionary = {}
var font: Font
var bold: Font
var _drag: bool = false
var _grab: Vector2 = Vector2.ZERO    # world offset from the ghost's centre to the press
var _scale: float = 1.0
var _origin: Vector2 = Vector2.ZERO  # screen position of the world point _view.position
var _view: Rect2 = Rect2()           # the world rectangle the map shows
var close_up: bool = false           # false: the whole village; true: the lot and its neighbours at a scale where you show
var _view_c: Vector2 = Vector2.ZERO  # the close-up's centre (follows the ghost, but not while it is dragged)
var read_only: bool = false          # the game sheet: the lot is chosen, nothing moves
var bays: Array = []                 # the game sheet: [{title, state}] in plan order, drawn as the site's bays
const BAY_WORDS: Dictionary = {"queued": "waiting", "running": "building", "verifying": "checking", "blocked": "on hold",
	"promoted": "built", "failed": "failed"}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	clip_contents = true


func _fit() -> void:
	var b: Rect2 = model.bounds
	if close_up and model.placed:
		if not _drag:
			_view_c = model.at
		var half: float = model.lot_radius() + 30.0
		b = Rect2(_view_c - Vector2(half, half), Vector2(half, half) * 2.0)
	_view = b
	if b.size.x <= 0.0 or b.size.y <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		_scale = 1.0
		_origin = Vector2.ZERO
		return
	_scale = minf(size.x / b.size.x, size.y / b.size.y)
	_origin = (size - b.size * _scale) * 0.5


func to_screen(w: Vector2) -> Vector2:
	return _origin + (w - _view.position) * _scale


func to_world(s: Vector2) -> Vector2:
	return _view.position + (s - _origin) / _scale


func _gui_input(event: InputEvent) -> void:
	if model == null or not model.village_ok or read_only:
		return
	_fit()
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				grab_focus()
				var w: Vector2 = to_world(mb.position)
				if model.placed and w.distance_to(model.at) <= model.lot_radius():
					_grab = model.at - w
				else:
					_grab = Vector2.ZERO
					model.place(w)
					changed.emit()
				_drag = true
			else:
				_drag = false
				_fit()
			accept_event()
			queue_redraw()
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if model.placed:
				model.turn(1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
				model.placed_by = "player"
				changed.emit()
				queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion and _drag:
		model.place(to_world((event as InputEventMouseMotion).position) + _grab)
		changed.emit()
		queue_redraw()
		accept_event()
	elif event is InputEventKey and event.pressed and model.placed:
		var k: InputEventKey = event
		if k.keycode == KEY_Q or k.keycode == KEY_E:
			model.turn(-1 if k.keycode == KEY_Q else 1)
			model.placed_by = "player"
			changed.emit()
			queue_redraw()
			accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), col["map"])
	if model == null or not model.village_ok:
		_text(Vector2(16, size.y * 0.5), "The village map could not be read (boot/village.json).", col["ink"], 14)
		return
	_fit()
	# road: dirt with an ink edge, at its width
	var pts: PackedVector2Array = PackedVector2Array()
	for q: Vector2 in model.road:
		pts.append(to_screen(q))
	var rw: float = maxf(4.0, model.road_half_m * 2.0 * _scale)
	draw_polyline(pts, col["ink"], rw + 3.0, true)
	draw_polyline(pts, col["road"], rw, true)
	var errs: Dictionary = {}
	for c: Dictionary in model.checks():
		if c.has("with"):
			errs[c["with"]] = true
	# plots and sites
	for e: Dictionary in model.plots:
		var c: Vector2 = to_screen(e["at"])
		var r: float = float(e["r"]) * _scale
		var hit: bool = errs.has(e["id"])
		if e["kind"] == "site":
			draw_circle(c, r, Color(col["dirt"], 0.55))
			_dashed_circle(c, r, col["hazard"] if hit else col["ink"], 2.0)
			_crane(c)
		else:
			draw_circle(c, r, col["plot"])
			draw_arc(c, r, 0, TAU, 64, col["hazard"] if hit else col["ink"], 3.0 if hit else 1.6, true)
		var label: String = str(e["label"]).replace("_", " ")
		_text(c + Vector2(-_w(label, 11) * 0.5, 4), label, col["ink"], 11)
	# north and the scale bar
	_text(Vector2(size.x - 26, 20), "N", col["ink"], 13, true)
	draw_line(Vector2(size.x - 21, 26), Vector2(size.x - 21, 44), col["ink"], 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(size.x - 21, 22), Vector2(size.x - 25, 30), Vector2(size.x - 17, 30)]), col["ink"])
	var bar_m: float = 10.0 if close_up else 50.0
	var bar: float = bar_m * _scale
	var b0: Vector2 = Vector2(14, size.y - 14)
	draw_line(b0, b0 + Vector2(bar, 0), col["ink"], 3.0)
	draw_line(b0 + Vector2(0, -5), b0 + Vector2(0, 3), col["ink"], 2.0)
	draw_line(b0 + Vector2(bar, -5), b0 + Vector2(bar, 3), col["ink"], 2.0)
	_text(b0 + Vector2(bar + 6, 4), "%d m" % int(bar_m), col["ink"], 11)
	if not model.placed:
		_text(Vector2(16, 24), "Click the map where the game should stand.", col["ink"], 13, true)
		return
	_ghost()


func _ghost() -> void:
	var ok: bool = model.fits()
	var c: Vector2 = to_screen(model.at)
	var r: float = model.lot_radius() * _scale
	var tint: Color = col["honey"] if ok else col["hazard"]
	draw_circle(c, r, Color(tint, 0.22))
	draw_arc(c, r, 0, TAU, 72, col["ink"], 4.0, true)
	draw_arc(c, r, 0, TAU, 72, tint, 2.0, true)
	# footprint, turned by yaw
	var f: Vector3 = model.footprint()
	var hx: float = f.x * 0.5
	var hz: float = f.y * 0.5
	var poly: PackedVector2Array = _rect(-hx, -hz, hx, hz)
	draw_colored_polygon(poly, Color(col["paper"], 0.92))
	if bays.is_empty():
		_footprint(hx, hz, model.shape())
	else:
		_bays(hx, hz)
	poly.append(poly[0])
	draw_polyline(poly, col["ink"], 2.0, true)
	# gate and path
	var g: Vector2 = model.gate()
	var q: Vector2 = model.road_point(model.at)
	_dashed_line(to_screen(g), to_screen(q), col["ink"], 2.0)
	var gs: Vector2 = to_screen(g)
	draw_rect(Rect2(gs - Vector2(5, 5), Vector2(10, 10)), col["paper"])
	draw_rect(Rect2(gs - Vector2(5, 5), Vector2(10, 10)), col["ink"], false, 2.0)
	_tag(gs + Vector2(8, -8), "gate · %d m path" % int(model.path_m()), col["paper"], col["ink"])
	if close_up:
		# you, at true scale, standing on the path outside the gate
		var dir: Vector2 = (q - g).normalized() if q.distance_to(g) > 0.1 else Vector2(0, 1)
		var you: Vector2 = to_screen(g + dir * 3.0)
		var rr: float = maxf(2.0, 0.3 * _scale)
		draw_circle(you, rr + 1.5, col["ink"])
		draw_circle(you, rr, col["jacket"])
		_tag(you + Vector2(-_w("you (2 m)", 12, true) - 22.0, -10), "you (2 m)", col["paper"], col["ink"])
	# what is wrong, written by the ring
	var lines: PackedStringArray = []
	for ch: Dictionary in model.checks():
		lines.append(str(ch["text"]))
	# the verdict sits on the side of the ring away from the gate, so the two tags never meet
	var away: Vector2 = (c - gs).normalized() if gs.distance_to(c) > 0.5 else Vector2(0, 1)
	var at: Vector2 = c + away * (r + 6.0) + Vector2(-20, -10)
	if lines.is_empty():
		_tag(at, "fits", col["green"], col["paper"])
	else:
		_tag(at, lines[0], col["hazard"] if not ok else col["honey"], col["paper"] if not ok else col["ink"])


## A rectangle in the footprint's own metres (x along its first size), turned and placed with the ghost.
func _rect(x0: float, z0: float, x1: float, z1: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]:
		out.append(_lp(p))
	return out


func _lp(p: Vector2) -> Vector2:
	return to_screen(model.at + p.rotated(model.yaw))


## A rounded rectangle (or a stadium) in footprint metres.
func _round(hx: float, hz: float, r: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	r = minf(r, minf(hx, hz))
	var cs: Array = [Vector2(hx - r, hz - r), Vector2(-hx + r, hz - r), Vector2(-hx + r, -hz + r), Vector2(hx - r, -hz + r)]
	for i: int in 4:
		for k: int in 7:
			var a: float = PI * 0.5 * i + PI * 0.5 * k / 6.0
			out.append(_lp(cs[i] + Vector2(cos(a), sin(a)) * r))
	return out


func _line(a: Vector2, b: Vector2, color: Color, w: float) -> void:
	draw_line(_lp(a), _lp(b), color, w, true)


## What the game is, seen from above, by its shape: a rink, a pitch, a court, a track, a slalom, a course, an arena,
## a yard. Drawn inside the footprint; stands as bands along the long sides when an answer adds them.
func _footprint(hx: float, hz: float, sh: Dictionary) -> void:
	var long_x: bool = hx >= hz
	var ix: float = hx
	var iz: float = hz
	if bool(sh.get("stands", false)):
		var band: float = 4.0
		if long_x:
			draw_colored_polygon(_rect(-hx * 0.8, -hz, hx * 0.8, -hz + band), col["seat"])
			draw_colored_polygon(_rect(-hx * 0.8, hz - band, hx * 0.8, hz), col["seat"])
			iz = hz - band
		else:
			draw_colored_polygon(_rect(-hx, -hz * 0.8, -hx + band, hz * 0.8), col["seat"])
			draw_colored_polygon(_rect(hx - band, -hz * 0.8, hx, hz * 0.8), col["seat"])
			ix = hx - band
	var apron: float = 3.5
	ix = maxf(1.0, ix - apron)
	iz = maxf(1.0, iz - apron)
	var a: Vector2 = Vector2(1, 0) if ix >= iz else Vector2(0, 1)   # the play area's long axis
	var la: float = maxf(ix, iz)
	var w: float = 1.0 if _scale < 2.0 else 2.0
	match str(sh.get("shape", "yard")):
		"rink":
			var p: PackedVector2Array = _round(ix, iz, minf(ix, iz) * 0.33)
			draw_colored_polygon(p, col["ice"])
			p.append(p[0])
			draw_polyline(p, col["ink"], w, true)
			var n: Vector2 = a.orthogonal() * minf(ix, iz)
			_line(-n, n, col["rink_red"], w + 1.0)
			_line(a * la * 0.33 - n, a * la * 0.33 + n, col["rink_blue"], w)
			_line(-a * la * 0.33 - n, -a * la * 0.33 + n, col["rink_blue"], w)
			for sgn: float in [-1.0, 1.0]:
				var gc: Vector2 = a * sgn * (la - 3.0)
				draw_colored_polygon(_rect(gc.x - 1.0, gc.y - 1.0, gc.x + 1.0, gc.y + 1.0), col["rink_red"])
		"pitch", "court":
			var p: PackedVector2Array = _rect(-ix, -iz, ix, iz)
			draw_colored_polygon(p, col["pitch"] if sh["shape"] == "pitch" else col["concrete"])
			p.append(p[0])
			draw_polyline(p, col["paper"], w, true)
			var n: Vector2 = a.orthogonal() * minf(ix, iz)
			_line(-n, n, col["paper"], w)
			for sgn: float in [-1.0, 1.0]:
				var gc: Vector2 = a * sgn * (la - 1.0)
				draw_colored_polygon(_rect(gc.x - 1.2, gc.y - 1.2, gc.x + 1.2, gc.y + 1.2), col["paper"])
		"track":
			var outer: PackedVector2Array = _round(ix, iz, minf(ix, iz))
			draw_colored_polygon(outer, col["tarmac"])
			var inner: PackedVector2Array = _round(maxf(1.0, ix - 10.0), maxf(1.0, iz - 10.0), minf(ix, iz) - 10.0)
			draw_colored_polygon(inner, col["map"])
			outer.append(outer[0])
			draw_polyline(outer, col["ink"], w, true)
			_line(Vector2(0, -iz), Vector2(0, -iz + 10.0), col["paper"], w + 1.0)
		"slalom":
			var p: PackedVector2Array = _rect(-ix, -iz, ix, iz)
			draw_colored_polygon(p, col["tarmac"])
			for k: int in 7:
				var t: float = -la + 2.0 * la * (k + 0.5) / 7.0
				var off: float = (minf(ix, iz) * 0.5) * (1.0 if k % 2 == 0 else -1.0)
				var cp: Vector2 = a * t + a.orthogonal() * off
				draw_circle(_lp(cp), maxf(2.0, 0.8 * _scale), col["cone"])
		"course":
			var p: PackedVector2Array = _rect(-ix, -iz, ix, iz)
			draw_colored_polygon(p, col["wood"])
			for k: int in 5:
				var t: float = -la + 2.0 * la * (k + 1) / 6.0
				var n: Vector2 = a.orthogonal() * minf(ix, iz)
				var q0: Vector2 = a * (t - 1.5)
				var q1: Vector2 = a * (t + 1.5)
				draw_colored_polygon(PackedVector2Array([_lp(q0 - n), _lp(q1 - n), _lp(q1 + n), _lp(q0 + n)]), col["map"] if k % 2 == 0 else col["hazard_light"])
			var fn: Vector2 = a.orthogonal() * minf(ix, iz)
			_line(a * (la - 1.0) - fn, a * (la - 1.0) + fn, col["paper"], w + 2.0)
		"arena":
			var r: float = minf(ix, iz)
			draw_circle(to_screen(model.at), r * _scale, col["sand"])
			draw_arc(to_screen(model.at), r * _scale, 0, TAU, 48, col["ink"], w, true)
		_:
			var p: PackedVector2Array = _rect(-ix, -iz, ix, iz)
			draw_colored_polygon(p, col["sand"])
			var n: Vector2 = a.orthogonal() * minf(ix, iz) * 0.8
			var wall: Vector2 = a * (la - 2.0)
			draw_colored_polygon(PackedVector2Array([_lp(wall - n), _lp(wall + a * 1.5 - n), _lp(wall + a * 1.5 + n), _lp(wall + n)]), col["brick"])


## The site as the village draws it (kernel/world/site/draw.gd): one bay per package in plan order along the long side,
## coloured and named by its state word.
func _bays(hx: float, hz: float) -> void:
	var long_x: bool = hx >= hz
	var la: float = maxf(hx, hz)
	var lw: float = minf(hx, hz)
	var n: int = bays.size()
	for i: int in n:
		var b: Dictionary = bays[i]
		var t0: float = -la + 2.0 * la * i / n + 1.0
		var t1: float = -la + 2.0 * la * (i + 1) / n - 1.0
		var st: String = str(b.get("state", "queued"))
		var c: Color = col.get("bay_" + st, col["paper"])
		var poly: PackedVector2Array = _rect(t0, -lw + 2.0, t1, lw - 2.0) if long_x else _rect(-lw + 2.0, t0, lw - 2.0, t1)
		draw_colored_polygon(poly, c)
		poly.append(poly[0])
		draw_polyline(poly, col["ink"], 2.0, true)
		var mid: Vector2 = _lp(Vector2((t0 + t1) * 0.5, 0) if long_x else Vector2(0, (t0 + t1) * 0.5))
		var word: String = "%d %s" % [i + 1, BAY_WORDS.get(st, st)]
		_text(mid - Vector2(_w(word, 11, true) * 0.5, -4), word, col["ink"], 11, true)


func _tag(at: Vector2, text: String, bg: Color, fg: Color) -> void:
	var w: float = _w(text, 12, true) + 12.0
	var p: Vector2 = at
	p.x = clampf(p.x, 4.0, size.x - w - 4.0)
	p.y = clampf(p.y, 4.0, size.y - 24.0)
	draw_rect(Rect2(p, Vector2(w, 20)), bg)
	draw_rect(Rect2(p, Vector2(w, 20)), col["ink"], false, 2.0)
	_text(p + Vector2(6, 15), text, fg, 12, true)


func _crane(c: Vector2) -> void:
	draw_line(c + Vector2(-6, 8), c + Vector2(-6, -10), col["crane"], 3.0)
	draw_line(c + Vector2(-10, -10), c + Vector2(12, -10), col["crane"], 3.0)
	draw_line(c + Vector2(10, -10), c + Vector2(10, -2), col["ink"], 1.0)


func _dashed_circle(c: Vector2, r: float, color: Color, w: float) -> void:
	var n: int = 36
	for i: int in n:
		if i % 2 == 0:
			draw_arc(c, r, TAU * i / n, TAU * (i + 1) / n, 4, color, w, true)


func _dashed_line(a: Vector2, b: Vector2, color: Color, w: float) -> void:
	var d: float = a.distance_to(b)
	if d < 1.0:
		return
	var steps: int = int(d / 6.0)
	for i: int in range(0, steps, 2):
		draw_line(a.lerp(b, float(i) / steps), a.lerp(b, minf(1.0, float(i + 1) / steps)), color, w)


func _w(text: String, fs: int, b: bool = false) -> float:
	return (bold if b else font).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


func _text(at: Vector2, text: String, color: Color, fs: int, b: bool = false) -> void:
	draw_string(bold if b else font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
