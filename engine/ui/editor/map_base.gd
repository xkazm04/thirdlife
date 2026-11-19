extends Control
## E1: the map's state and its small drawing helpers (world <-> screen, footprint-space shapes, tags, text),
## split out of village_map.gd (its size is ratcheted); village_map.gd extends it and draws the map.

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
var read_only: bool = false          # the game sheet: the lot is chosen, nothing moves
var ring_before: float = 0.0         # the game sheet: the ring as it stands while a change is only picked (dashed)
var board: bool = false             # E5: the home board: no ghost; a click on a game's lot says which (lot_clicked)
var bays: Array = []                 # the game sheet: [{title, state}] in plan order, drawn as the site's bays
const BAY_WORDS: Dictionary = {"queued": "waiting", "running": "building", "verifying": "checking", "blocked": "on hold",
	"promoted": "built", "failed": "failed"}


const Landscape = preload("res://ui/editor/map_landscape.gd")
const Art = preload("res://ui/editor/workshop_art.gd")
var _annotations: Array[Rect2] = []  # screen-space ink reserved by higher-priority callouts


func _fit() -> void:
	# The verdict under the map may wrap as the ghost moves. Keep the press-time
	# transform through release so that this reflow cannot move the drop point.
	if _drag:
		return
	var b: Rect2 = model.bounds
	if close_up and model.placed:
		var half: float = model.lot_radius() + 30.0
		b = Rect2(model.at - Vector2(half, half), Vector2(half, half) * 2.0)
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


func _circle_polygon(c: Vector2, r: float) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for i: int in 72:
		poly.append(c + Vector2.from_angle(TAU * i / 72) * r)
	return poly


func _hatch(patch: PackedVector2Array) -> void:
	if patch.size() < 3:
		return
	draw_colored_polygon(patch, Color(col["hazard"], 0.20))
	var bounds := Rect2(patch[0], Vector2.ZERO)
	for pt: Vector2 in patch:
		bounds = bounds.expand(pt)
	for x: int in range(floori(bounds.position.x - bounds.size.y), ceili(bounds.end.x), 7):
		var start := Vector2(x, bounds.end.y + 1)
		var end := start + Vector2(bounds.size.y + 2, -bounds.size.y - 2)
		for line: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([start, end]), patch):
			if line.size() >= 2:
				draw_polyline(line, Color(col["hazard"], 0.78), 1.8, true)


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
func _tag(at: Vector2, text: String, bg: Color, fg: Color, fs: int = 12) -> void:
	var extent := Vector2(_w(text, fs, true) + 12, fs + 8)
	var chosen := Rect2(at, extent)
	var best := INF
	for offset: Vector2 in [Vector2.ZERO, Vector2(0, -extent.y-4), Vector2(0, extent.y+4),
			Vector2(-extent.x-10, 0), Vector2(extent.x+10, 0), Vector2(0, -2*extent.y-8), Vector2(0, 2*extent.y+8)]:
		var trial := Rect2((at + offset).clamp(Vector2(4, 4), (size - extent - Vector2(4, 4)).max(Vector2(4, 4))).round(), extent)
		var cost := offset.length() * 0.001
		for used: Rect2 in _annotations:
			cost += used.grow(2).intersection(trial).get_area()
		if cost < best:
			best = cost
			chosen = trial
		if is_zero_approx(cost):
			break
	_annotations.append(chosen)
	draw_rect(Rect2(chosen.position + Vector2(1, 2), extent), Color(col["ink"], 0.32))
	draw_rect(chosen, bg)
	draw_rect(chosen, col["trunk"], false, 1.2)
	_text(chosen.position + Vector2(6, fs + 2), text, fg, fs, true)


func _dashed_circle(c: Vector2, r: float, color: Color, w: float) -> void:
	var n: int = 36
	for i: int in n:
		if i % 2 == 0:
			draw_arc(c, r, TAU * i / n, TAU * (i + 1) / n, 4, color, w, true)


func _dashed_line(a: Vector2, b: Vector2, color: Color, w: float) -> void:
	var d: float = a.distance_to(b)
	if d < 1.0:
		return
	var steps: int = maxi(1, ceili(d / 5.0))
	for i: int in range(0, steps, 2):
		draw_line(a.lerp(b, float(i) / steps), a.lerp(b, minf(1.0, float(i + 1) / steps)), color, w)


func _w(text: String, fs: int, b: bool = false) -> float:
	return (bold if b else font).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


func _text(at: Vector2, text: String, color: Color, fs: int, b: bool = false) -> void:
	draw_string(bold if b else font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
