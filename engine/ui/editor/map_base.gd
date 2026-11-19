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
var radius_before := 0.0             # the game sheet compares a pending change with the current lot
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


static func _plot_half(lot: Dictionary) -> Vector2:
	return lot.pad_size * 0.5 if lot.has("pad_size") else Vector2.ONE * float(lot.r)


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
	return Transform2D(model.yaw, to_screen(model.at)) * _rounded_points(Vector2(hx, hz) * _scale, r * _scale)


static func _rounded_points(half_size: Vector2, r: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var hx := half_size.x
	var hz := half_size.y
	r = minf(r, minf(hx, hz))
	var cs: Array = [Vector2(hx - r, hz - r), Vector2(-hx + r, hz - r), Vector2(-hx + r, -hz + r), Vector2(hx - r, -hz + r)]
	for i: int in 4:
		for k: int in 7:
			var a: float = PI * 0.5 * i + PI * 0.5 * k / 6.0
			out.append(cs[i] + Vector2(cos(a), sin(a)) * r)
	return out


## The flat footprint fades into the meadow along a rounded shoulder.
func _pad(at: Vector2, half_size: Vector2, yaw: float, tint: Color) -> void:
	var frame := Transform2D(yaw, to_screen(at))
	var corner := minf(5.0, minf(half_size.x, half_size.y) * 0.2)
	var shoulder := clampf(minf(half_size.x, half_size.y) * 0.3, 4.0, 10.0)
	var inner := frame * _rounded_points(half_size * _scale, corner * _scale)
	var outer := frame * _rounded_points((half_size + Vector2.ONE * shoulder) * _scale, (corner + shoulder) * _scale)
	draw_colored_polygon(inner, tint)
	var clear := Color(tint, 0.0)
	var tones := PackedColorArray([tint, tint, clear, clear])
	for i in inner.size():
		var j := (i + 1) % inner.size()
		draw_polygon(PackedVector2Array([inner[i], inner[j], outer[j], outer[i]]), tones)


## The village spur starts at r + 0.5. The two rails stand across it at r + 3.6, with its centre open.
func _approach(at: Vector2, radius: float, road: Vector2, proposed := false) -> Vector2:
	var dir := at.direction_to(road)
	var gate := to_screen(at + dir * model.edge_radius(radius))
	if dir == Vector2.ZERO or model.road_samples.is_empty():
		return gate
	var start := to_screen(at + dir * (radius + 0.5))
	var end := to_screen(road)
	var width := maxf(2.0, model.road_half_m * 1.6 * _scale)
	draw_line(start, end, Color(col.wood_dark, 0.65), width + 1.2, true)
	draw_line(start, end, col.sand if proposed else col.road, width, true)
	if proposed:
		_dashed_line(start, end, col.wood_dark, 1.1)
	var side := dir.orthogonal() * _scale
	var gap: float = model.road_half_m * 0.8 + 2.0
	var length := clampf(radius * 0.24, 4.0, 10.0)
	var pen := clampf(_scale * 0.4, 0.85, 2.0)
	var reach := side * (gap + length)
	_annotations.append(Rect2(gate - reach, Vector2.ZERO).expand(gate + reach).grow(pen + 1.0))
	for hand: float in [-1.0, 1.0]:
		var a := gate + side * hand * gap
		var b := a + side * hand * length
		draw_line(a, b, col.trunk, pen + 1.8, true)
		draw_line(a, b, col.wood, pen, true)
		for post: Vector2 in [a, b]:
			draw_circle(post, pen + 0.65, col.trunk, true, -1, true)
	return gate


func _line(a: Vector2, b: Vector2, color: Color, w: float) -> void:
	draw_line(_lp(a), _lp(b), color, w, true)


## If a crowded label shifts away, join it to the symbol it identifies.
func _tag(at: Vector2, text: String, bg: Color, fg: Color, fs: int = 12, anchor := Vector2.INF) -> void:
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
	if anchor.is_finite():
		var end := anchor.clamp(chosen.position, chosen.end)
		if anchor.distance_to(end) > 6.0:
			draw_line(anchor, end, col.trunk, 1.1, true)
			draw_circle(anchor, 1.7, col.trunk, true, -1, true)
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
