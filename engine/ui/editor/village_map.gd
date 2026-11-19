extends "res://ui/editor/map_base.gd"
## E1: the village from above (boot/village.json), north up, with the new game's ghost: its footprint inside its lot
## ring, its gate toward the road and the dashed path in. Left press places the ghost there (or picks it up when the
## press is inside its ring) and dragging moves it; the wheel and Q / E turn it by 15 degrees. It draws what the model
## says and writes only `at` and `yaw` into it; `changed` tells the workbench to redraw the rest.

const Overlay = preload("res://ui/editor/map_overlay.gd")
var proposals: Array = []
var highlight := -1

signal changed
signal lot_clicked(id: String)    # E5 board: a game's lot (plot kind "game") was clicked; id = its job

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	clip_contents = true


func _gui_input(event: InputEvent) -> void:
	if board and model != null and event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_fit()
		var w: Vector2 = to_world((event as InputEventMouseButton).position)
		for lot: Dictionary in model.plots:
			if lot["kind"] == "game" and w.distance_to(lot["at"]) <= model.fence_radius(lot.r):
				lot_clicked.emit(str(lot["job"]))
				accept_event()
				return
	if model == null or not model.village_ok or read_only:
		return
	_fit()
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				grab_focus()
				var w: Vector2 = to_world(mb.position)
				if model.placed and w.distance_to(model.at) <= model.fence_radius(model.lot_radius()):
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
	var screen := Rect2(Vector2.ZERO, size)
	var world := Rect2(to_world(Vector2.ZERO), size / _scale)
	Landscape.paint(self, world, _scale, col)
	_river()
	_road()
	var errs: Dictionary = {}
	for check: Dictionary in model.checks():
		if check.has("with"):
			errs[check["with"]] = true
	var visible_plots: Array[Dictionary] = []
	for lot: Dictionary in model.plots:
		var c := to_screen(lot["at"])
		var r := float(lot["r"]) * _scale
		if not screen.grow(r + (model.FENCE_OUT_M + model.FENCE_GAP_M / 2) * _scale + 8).has_point(c):
			continue
		_plot(c, r, lot, errs.has(lot["id"]))
		visible_plots.append(lot)

	_annotations.clear()
	_furniture()
	if board:
		pass
	elif model.placed:
		_ghost()
	else:
		_tag(Vector2(10, 9), "Click the map where the game should stand.", col["card"], col["ink"], 13)
	# The names are separate from the illustrations. A gate or verdict gets first choice of
	# space, then the neighbouring names can slide to another part of their own plot.
	var compare := not proposals.is_empty() and not close_up
	var neighbours := Overlay.neighbours(self) if compare else []
	for lot: Dictionary in visible_plots:
		if compare and not lot.id in neighbours:
			continue
		var c := to_screen(lot["at"])
		if not screen.has_point(c):
			continue
		var label := str(lot["label"]).replace("_", " ")
		var r := float(lot["r"]) * _scale
		var at := Vector2(c.x - (_w(label, 11, true) + 12) * 0.5, c.y + minf(r * 0.38, 68))
		_tag(at, label, col["honey"] if lot["kind"] == "game" else (col["vellum"] if lot["kind"] == "site" else col["card"]), col["ink"], 11)


## E6: the village's river (the workbench refuses a lot in it), drawn at its width in the palette's water.
func _river() -> void:
	if model.river.size() < 2:
		return
	var pts: PackedVector2Array = PackedVector2Array()
	for q: Vector2 in model.river_samples:
		pts.append(to_screen(q))
	var w: float = maxf(3.0, float(model.river_half_m) * 2.0 * _scale)
	draw_polyline(pts, Color(col["ink"], 0.55), w + 2.0, true)
	draw_polyline(pts, col.get("water", Color("#4a8ac0")), w, true)


func _road() -> void:
	var pts := PackedVector2Array()
	for q: Vector2 in model.road_samples:
		pts.append(to_screen(q))
	if pts.size() < 2:
		return
	var rw := maxf(4.0, model.road_half_m * 2.0 * _scale)
	for tip: Vector2 in [pts[0], pts[-1]]:
		draw_circle(tip, (rw + 2.5) * 0.5, col["wood_dark"], true, -1, true)
		draw_circle(tip, rw * 0.5, col["road"], true, -1, true)
	draw_polyline(pts, col["wood_dark"], rw + 2.5, true)
	draw_polyline(pts, col["road"], rw, true)
	for i: int in range(0, pts.size()-1, 8):
		var a := pts[i]
		var b := pts[mini(i+8, pts.size()-1)]
		var n := (b-a).normalized().orthogonal()
		for side: float in [-1.0, 1.0]:
			var rut_offset := n * rw * 0.25 * side
			draw_line(a + rut_offset, b + rut_offset, Color(col["sand"], 0.74), maxf(1.0, rw * 0.15), true)
		var rng := RandomNumberGenerator.new()
		rng.seed = i * 371
		for j: int in ceili(a.distance_to(b) * 0.65 / _scale):
			var pt := a.lerp(b, rng.randf()) + n * rw * rng.randf_range(-0.45, 0.45)
			draw_line(pt, pt + Vector2(rng.randf_range(0.5, 1.4), -0.12) * _scale, Color(col["trunk"], 0.27), clampf(_scale * 0.24, 0.65, 1.4), true)
		# Broken wagon ruts pick out the direction even when zoomed all the way out.
		draw_dashed_line(a + n * rw * 0.32, b + n * rw * 0.32, Color(col["wood_dark"], 0.37), 1.0, maxf(5, rw * 0.57), true, true)


func _plot(c: Vector2, r: float, lot: Dictionary, hit: bool) -> void:
	var site: bool = lot["kind"] == "site"
	var stroke: Color = col["hazard"] if hit else col["trunk"]
	draw_circle(c, r, Color(col["dirt"] if site else col["plot"], 0.82 if site else 0.72), true, -1, true)
	if r > 55:
		# The approach is worn into the meadow and the orchard floor shows through it.
		var worn := PackedVector2Array()
		for i: int in 21:
			var t := i / 20.0
			var local := Vector2(lerpf(-0.78, 0.72, t), 0.29 - 0.16 * sin(t*TAU))
			worn.append(c + local * r)
		draw_polyline(worn, Color(col["sand"], 0.68), r * 0.065, true)
		draw_polyline(worn, Color(col["wood_dark"], 0.13), 1, true)
	draw_arc(c, r * 0.86, 0.15, 2.4, 40, Color(col["wood_dark"], 0.19), maxf(1, r * 0.025), true)
	var fence: float = model.fence_radius(lot.r) * _scale
	_dashed_circle(c, fence + model.FENCE_GAP_M * 0.5 * _scale, Color(col["ink"], 0.65), 1.0)
	_fence(c, fence, stroke, hit)
	var key := str(lot.get("stamp", "site" if site else str(lot["id"])))
	if Art.SYMBOLS.has(key):
		var w := r * 1.52
		# Small illustrations are map symbols. At a larger scale the surrounding scenery
		# becomes visible too, such as the cabin and pines of the house paddle court.
		if r > 60 and key in ["paddle", "parkour", "hockey", "drive"]:
			_stamp("pine", c + Vector2(-0.57, -0.30) * r, r * 0.31)
			_stamp("copse", c + Vector2(0.53, -0.35) * r, r * 0.28)
			if key != "parkour":
				_stamp("cabin", c + Vector2(-0.24, -0.53) * r, r * 0.46)
			_stamp("stone", c + Vector2(0.54, 0.31) * r, r * 0.25)
			w = r * 1.3
		_stamp(key, c - Vector2(0, w * 0.10), w)


func _stamp(key: String, c: Vector2, width: float) -> void:
	var extent := Vector2(width, width * 0.72)
	draw_texture_rect(Art.stamp(key, col, width), Rect2(c - extent * 0.5, extent), false)


func _fence(c: Vector2, r: float, stroke: Color, hit: bool) -> void:
	var h := clampf(_scale * 1.65, 2.1, 9.5)
	var rail := clampf(_scale * 0.49, 0.95, 2.7)
	var count := clampi(roundi(TAU * r / maxf(10, 8 * _scale)), 12, 55)
	draw_arc(c, r, 0, TAU, 96, Color(col["trunk"], 0.52), rail, true)
	for up: float in [0.27, 0.80]:
		var level := c - Vector2(0, h * up)
		draw_arc(level, r, 0, TAU, 96, stroke, rail + 1.0, true)
		draw_arc(level - Vector2(0, 0.55), r, 0, TAU, 96, col["brick"] if hit else col["wood"], rail, true)
	for j: int in count:
		var foot := c + Vector2.from_angle(TAU * j / count) * r
		var top := foot - Vector2(0, h + rail)
		draw_line(foot, foot + Vector2(h * 0.93, h * 0.29), Color(col["shade"], 0.26), rail + 1.3, true)
		draw_line(foot, top, stroke, rail + 1.4, true)
		draw_line(top, top + Vector2(0, rail), col["sand"], rail + 1.3, true)
	if hit:
		draw_arc(c, r, 0, TAU, 96, col["hazard"], 2.5, true)


func _furniture() -> void:
	var c := Vector2(size.x - 26, 33)
	draw_circle(c, 19.5, Color(col["ink"], 0.27), true, -1, true)
	draw_circle(c - Vector2(1, 1), 18.7, col["vellum"], true, -1, true)
	draw_arc(c - Vector2(1, 1), 18.7, 0, TAU, 40, col["trunk"], 1.4, true)
	_text(c + Vector2(-_w("N", 13, true) * 0.5, -2), "N", col["ink"], 13, true)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, 0), c + Vector2(6, 12), c + Vector2(0, 9), c + Vector2(-6, 12)]), col["ink"])
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, 1), c + Vector2(4, 10), c + Vector2(0, 8)]), col["brick"])
	_annotations.append(Rect2(c - Vector2(22, 22), Vector2(44, 44)))
	var bar_m: float = 10.0 if close_up else 50.0
	var bar := bar_m * _scale
	var label := "%d m" % int(bar_m)
	var b := Vector2(14, size.y - 17)
	var backing := Rect2(b - Vector2(7, 9), Vector2(bar + _w(label, 11, true) + 24, 20))
	draw_rect(backing, col["card"])
	draw_rect(backing, col["trunk"], false, 1)
	draw_rect(Rect2(b - Vector2(0, 1), Vector2(bar, 4)), col["ink"], false, 1)
	draw_rect(Rect2(b - Vector2(0, 1), Vector2(bar * 0.5, 4)), col["ink"])
	_text(b + Vector2(bar + 6, 5), label, col["ink"], 11, true)
	_annotations.append(backing)


func _ghost() -> void:
	var ok: bool = model.fits()
	var c: Vector2 = to_screen(model.at)
	var r: float = model.fence_radius(model.lot_radius()) * _scale
	var tint: Color = col["honey"] if ok else col["hazard"]
	draw_circle(c, r, Color(tint, 0.36), true, -1, true)
	# Keep the requested lot radius visible inside its surveyed fence.
	draw_arc(c, model.lot_radius() * _scale, 0, TAU, 72, Color(col["paper"], 0.48), 1.0, true)
	draw_arc(c, r, 0, TAU, 72, col["ink"], 4.0, true)
	draw_arc(c, r, 0, TAU, 72, tint, 2.0, true)
	for i: int in 4:
		var peg := c + Vector2.from_angle(i * PI / 2) * r
		draw_rect(Rect2(peg - Vector2(2.5, 2.5), Vector2(5, 5)), col["ink"])
		draw_rect(Rect2(peg - Vector2(1.5, 1.5), Vector2(3, 3)), tint)
	if ring_before > 0.0 and absf(ring_before - model.lot_radius()) > 0.5:
		_dashed_circle(c, ring_before * _scale, col["ink"], 2.0)
		_tag(c + Vector2(-ring_before * _scale * 0.7 - 60.0, ring_before * _scale * 0.7), "now: ring %d m" % int(ring_before), col["paper"], col["ink"])
	_dashed_circle(c, r + model.FENCE_GAP_M * 0.5 * _scale, col["ink"], 1.0)
	# footprint, turned by yaw
	var f: Vector3 = model.footprint()
	var hx: float = f.x * 0.5
	var hz: float = f.y * 0.5
	var poly: PackedVector2Array = _rect(-hx, -hz, hx, hz)
	var shadow := poly.duplicate()
	for i: int in shadow.size():
		shadow[i] += Vector2(1.7, 2.7) * clampf(_scale, 0.8, 2.4)
	draw_colored_polygon(shadow, Color(col["shade"], 0.45))
	draw_colored_polygon(poly, col["vellum"])
	if bays.is_empty():
		_footprint(hx, hz, model.shape())
	else:
		_bays(hx, hz)
	poly.append(poly[0])
	draw_polyline(poly, col["ink"], 2.0, true)
	if not ok:
		_clearance_hatching(c, r)
	Overlay.places(self)
	# gate and path
	var g: Vector2 = model.gate()
	var q: Vector2 = model.road_point(model.at)
	_dashed_line(to_screen(g), to_screen(q), col["ink"], 2.0)
	var gs: Vector2 = c + model.at.direction_to(q) * r
	Overlay.entrance(self, gs, to_screen(q) - gs)
	if close_up or proposals.is_empty():
		_tag(gs + Vector2(8, -8), "gate · %d m path" % roundi(model.path_m()), col["paper"], col["ink"])
	if close_up:
		# you, at true scale, standing on the path outside the gate
		var dir: Vector2 = (q - g).normalized() if q.distance_to(g) > 0.1 else Vector2(0, 1)
		var you: Vector2 = to_screen(g + dir * 3.0)
		var rr: float = maxf(2.0, 0.3 * _scale)
		var h := maxf(5, model.walker_m * _scale)
		draw_line(you - Vector2(0, h * 0.5), you + Vector2(rr * 0.4, 0), col["ink"], maxf(1.5, h * 0.2), true)
		draw_circle(you - Vector2(0, h * 0.58), rr + 0.8, col["ink"], true, -1, true)
		draw_circle(you - Vector2(0, h * 0.58), rr, col["jacket"], true, -1, true)
		draw_circle(you - Vector2(0, h * 0.88), maxf(1, h * 0.15), col["skin"], true, -1, true)
		_tag(you + Vector2(-_w("you (2 m)", 12, true) - 22.0, -10), "you (2 m)", col["paper"], col["ink"])
	if not close_up and not proposals.is_empty():
		return  # the ranked rows carry the verdict while comparing sites
	# what is wrong, written by the ring
	var lines: PackedStringArray = []
	for ch: Dictionary in model.checks():
		lines.append(str(ch["text"]))
	# the verdict sits on the side of the ring away from the gate, so the two tags never meet
	var away: Vector2 = (c - gs).normalized() if gs.distance_to(c) > 0.5 else Vector2(0, 1)
	var at: Vector2 = c + away * (r + 6.0) + Vector2(-20, -10)
	if lines.is_empty():
		_tag(at, "fits", col["green"], col["card"])
	else:
		_tag(at, lines[0], col["hazard"] if not ok else col["honey"], col["paper"] if not ok else col["ink"])


## Hatch only the shared ground. Work entirely in drawing space so neither the check nor
## the measured position of a lot changes with the width or spacing of the ink strokes.
func _clearance_hatching(c: Vector2, r: float) -> void:
	var ring := _circle_polygon(c, r)
	for lot: Dictionary in model.plots:
		var center := to_screen(lot["at"])
		var radius: float = model.fence_radius(lot.r) * _scale
		if c.distance_to(center) < r + radius:
			for patch: PackedVector2Array in Geometry2D.intersect_polygons(ring, _circle_polygon(center, radius)):
				_hatch(patch)
	for i: int in range(1, model.road_samples.size()):
		var a := to_screen(model.road_samples[i-1])
		var b := to_screen(model.road_samples[i])
		var n: Vector2 = (b - a).normalized().orthogonal() * model.road_half_m * _scale
		if a.distance_squared_to(b) < 0.01 or c.distance_to(Geometry2D.get_closest_point_to_segment(c, a, b)) > r + n.length():
			continue
		for patch: PackedVector2Array in Geometry2D.intersect_polygons(ring, PackedVector2Array([a-n, b-n, b+n, a+n])):
			_hatch(patch)


func _footprint(hx: float, hz: float, sh: Dictionary) -> void:
	var long_x: bool = hx >= hz
	var ix: float = hx
	var iz: float = hz
	if bool(sh.get("stands", false)):
		Overlay.spectators(self, hx, hz, long_x)
		var band: float = 4.0
		if long_x:
			draw_colored_polygon(_rect(-hx * 0.8, -hz, hx * 0.8, -hz + band), col["seat"])
			draw_colored_polygon(_rect(-hx * 0.8, hz - band, hx * 0.8, hz), col["seat"])
			iz = hz - band
		else:
			draw_colored_polygon(_rect(-hx, -hz * 0.8, -hx + band, hz * 0.8), col["seat"])
			draw_colored_polygon(_rect(hx - band, -hz * 0.8, hx, hz * 0.8), col["seat"])
			ix = hx - band
	if bool(sh.get("stands", false)) and _scale > 1.1:
		# Individually ink the risers, leaving the stands inside their measured band.
		for side: float in [-1.0, 1.0]:
			for j: int in [1, 2, 3]:
				if long_x:
					_line(Vector2(-hx * 0.79, side * (hz - j)), Vector2(hx * 0.79, side * (hz - j)), col["ice"] if j == 1 else col["tarmac"], 0.85)
				else:
					_line(Vector2(side * (hx - j), -hz * 0.79), Vector2(side * (hx - j), hz * 0.79), col["ice"] if j == 1 else col["tarmac"], 0.85)
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
			var circle_r := minf(ix, iz) * 0.24 * _scale
			draw_arc(_lp(Vector2.ZERO), circle_r, 0, TAU, 36, col["rink_blue"], w, true)
			for end_: float in [-1, 1]:
				for side: float in [-1, 1]:
					var dot := _lp(a * la * 0.59 * end_ + n * 0.45 * side)
					draw_arc(dot, circle_r * 0.77, 0, TAU, 28, Color(col["rink_red"], 0.76), maxf(0.85, w * 0.64), true)
					draw_circle(dot, maxf(0.8, w), col["rink_red"])
			_line(-n, n, col["rink_red"], w + 1.0)
			_line(a * la * 0.33 - n, a * la * 0.33 + n, col["rink_blue"], w)
			_line(-a * la * 0.33 - n, -a * la * 0.33 + n, col["rink_blue"], w)
			for sgn: float in [-1.0, 1.0]:
				var gc: Vector2 = a * sgn * (la - 3.0)
				draw_colored_polygon(_rect(gc.x - 1.0, gc.y - 1.0, gc.x + 1.0, gc.y + 1.0), col["rink_red"])
			_teams(a, la, minf(ix, iz), true)
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
			_teams(a, la, minf(ix, iz), sh["shape"] == "court")
		"track":
			var outer: PackedVector2Array = _round(ix, iz, minf(ix, iz))
			var surface: Color = {"ice": col["block"], "dirt": col["road"]}.get(model.value("road")["id"], col["tarmac"])
			draw_colored_polygon(outer, surface)
			var lane := _round(maxf(1, ix-5), maxf(1, iz-5), maxf(1, minf(ix, iz)-5))
			lane.append(lane[0])
			draw_polyline(lane, col["card"], maxf(0.8, w * 0.65), true)
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
			_course(a, la, minf(ix, iz), w)
		"arena":
			var r: float = minf(ix, iz)
			draw_circle(to_screen(model.at), r * _scale, col["sand"])
			draw_arc(to_screen(model.at), r * _scale, 0, TAU, 64, col["wood_dark"], w, true)
			_dashed_circle(to_screen(model.at), r * _scale * 0.88, col["vellum"], w)
			_line(Vector2(-r * 0.12, 0), Vector2(r * 0.12, 0), col["wood_dark"], w)
			_line(Vector2(0, -r * 0.12), Vector2(0, r * 0.12), col["wood_dark"], w)
		_:
			var p: PackedVector2Array = _rect(-ix, -iz, ix, iz)
			draw_colored_polygon(p, col["sand"])
			var n: Vector2 = a.orthogonal() * minf(ix, iz) * 0.8
			var wall: Vector2 = a * (la - 2.0)
			draw_colored_polygon(PackedVector2Array([_lp(wall - n), _lp(wall + a * 1.5 - n), _lp(wall + a * 1.5 + n), _lp(wall + n)]), col["brick"])


## The little jerseys follow the players-per-side answer already shown in the interview.
func _teams(along: Vector2, half: float, across: float, sticks: bool) -> void:
	var count := int(str(model.value("players")["id"]))
	if count not in [2, 3, 5]:
		return
	var formation := [Vector2(0.18, -0.20), Vector2(0.57, 0.35), Vector2(0.65, -0.56),
		Vector2(0.30, 0.66), Vector2(0.83, -0.04)]
	var h := clampf(2.15 * _scale, 2.7, 18)
	for team: float in [-1.0, 1.0]:
		var jersey: Color = col["rink_blue"] if team > 0 else col["brick"]
		for i: int in count:
			var spot: Vector2 = formation[i]
			var foot := _lp((along * half * spot.x + along.orthogonal() * across * spot.y) * team)
			draw_line(foot, foot + Vector2(h*0.60, h*0.15), Color(col["shade"], 0.33), maxf(1, h*0.28), true)
			draw_line(foot - Vector2(0, h*0.34), foot + Vector2(team*h*0.29, 0), col["ink"], maxf(1, h*0.26), true)
			draw_circle(foot-Vector2(0,h*0.48), h*0.30, col["ink"], true, -1, true)
			draw_circle(foot-Vector2(0,h*0.50), h*0.24, jersey, true, -1, true)
			if _scale > 1.45:
				draw_circle(foot-Vector2(team*h*0.10,h*0.83), h*0.17, col["ink"], true, -1, true)
				draw_circle(foot-Vector2(team*h*0.10,h*0.87), h*0.13, col["paper"], true, -1, true)
				if sticks:
					var blade := foot - along.rotated(model.yaw) * team * h * 0.7
					draw_line(foot - Vector2(0, h*0.42), blade, col["trunk"], 1.1, true)
					draw_line(blade, blade + Vector2(h*0.22, 0), col["trunk"], 1.1, true)


## Timber obstacles read as a run of landings, a bridge and a ramp in the course's own
## coordinates. The plan rotates with the measured footprint in both map views.
func _course(along: Vector2, half: float, across: float, pen: float) -> void:
	var side := along.orthogonal()
	var lane := PackedVector2Array([_lp(-along*half - side*across), _lp(along*half - side*across),
		_lp(along*half + side*across), _lp(-along*half + side*across)])
	draw_colored_polygon(lane, col["sand"])
	for k: int in 5:
		var t := lerpf(-0.78, 0.77, k / 4.0)
		var center := along * half * t
		var depth := half * (0.17 if k in [0, 4] else 0.11)
		var width := across * (0.93 if k in [0, 4] else 0.48)
		if k in [1, 3]:
			center += side * across * (0.44 if k == 1 else -0.44)
		var d := along * depth
		var w := side * width
		var points := PackedVector2Array([_lp(center-d-w), _lp(center+d-w), _lp(center+d+w), _lp(center-d+w)])
		var shade := points.duplicate()
		for j: int in shade.size():
			shade[j] += Vector2(1, 1.3) * _scale
		draw_colored_polygon(shade, Color(col["trunk"], 0.45))
		draw_colored_polygon(points, col["wood"])
		points.append(points[0])
		draw_polyline(points, col["wood_dark"], pen, true)
		for j: int in range(1, 5):
			var board := center + d * (j * 0.4 - 1)
			_line(board-w, board+w, col["wood_dark"], pen * 0.65)
		if k == 4:
			_line(center-d-w, center+d-w, col["paper"], pen * 1.5)
			_line(center-d+w, center+d+w, col["paper"], pen * 1.5)
	var finish := along * half * 0.97
	for stripe: int in 8:
		var start := side * across * (stripe * 0.25 - 1)
		_line(finish + start, finish + start + side * across * 0.25, col["ink"] if stripe % 2 == 0 else col["paper"], pen * 2)


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
		draw_colored_polygon(poly, col["concrete"].lerp(c, 0.43))
		# A boarded platform, a coloured fascia and square post caps for each package.
		var cross := lw - 2.0
		for joist: int in range(1, ceili((t1 - t0) / 3.0)):
			var t := t0 + joist * 3.0
			draw_line(_bay_point(t, -cross, long_x), _bay_point(t, cross, long_x), Color(col["trunk"], 0.30), 1, true)
		var fascia := PackedVector2Array([_bay_point(t0, -cross, long_x), _bay_point(t1, -cross, long_x),
			_bay_point(t1, -cross * 0.65, long_x), _bay_point(t0, -cross * 0.65, long_x)])
		draw_colored_polygon(fascia, c)
		for k: int in range(1, 5):
			var t := lerpf(t0, t1, k / 5.0)
			draw_line(_bay_point(t, -cross, long_x), _bay_point(t, -cross * 0.65, long_x), Color(col["trunk"], 0.45), 1, true)
		poly.append(poly[0])
		draw_polyline(poly, col["ink"], 2.0, true)
		for corner: Vector2 in poly.slice(0, 4):
			var post := clampf(_scale * 0.9, 2, 5)
			draw_rect(Rect2(corner - Vector2.ONE * post, Vector2.ONE * post * 2), col["trunk"])
			draw_rect(Rect2(corner - Vector2.ONE * post, Vector2.ONE * post * 1.3), col["wood"])
		_bay_fittings(t0, t1, cross, long_x, st)
		var mid: Vector2 = _lp(Vector2((t0 + t1) * 0.5, 0) if long_x else Vector2(0, (t0 + t1) * 0.5))
		var word: String = "%d %s" % [i + 1, BAY_WORDS.get(st, st)]
		_tag(mid - Vector2((_w(word, 12, true) + 12) * 0.5, 10), word, c, col["ink"])


func _bay_fittings(t0: float, t1: float, cross: float, long_x: bool, state: String) -> void:
	# Pallets sit at the near end. As a package progresses, an upright and its
	# diagonal braces are inked in along the back of the bay, clear of the status sign.
	var width := (t1 - t0) * _scale
	if width < 26:
		return
	var pallet := _bay_point(lerpf(t0, t1, 0.28), cross * 0.59, long_x)
	_stamp("pallet", pallet, minf(width * 0.45, cross * _scale * 0.72))
	if state == "queued":
		return
	var rise := Vector2(0, -minf(cross * 0.34, 3.4) * _scale)
	var rail: Color = col["wood_dark"] if state == "promoted" else col["tarmac"]
	var beam := clampf(_scale * 0.4, 1.0, 2.2)
	for i: int in 3:
		var a := _bay_point(lerpf(t0, t1, (i + 0.18) / 3.3), -cross * 0.8, long_x)
		var b := _bay_point(lerpf(t0, t1, (i + 1.18) / 3.3), -cross * 0.8, long_x)
		draw_line(a, a + rise, rail, beam + 0.8, true)
		draw_line(a, b + rise, rail, beam, true)
		draw_line(a + rise, b + rise, col["wood"], beam + 1.2, true)
		draw_line(b, b + rise, rail, beam + 0.8, true)


func _bay_point(along: float, across: float, long_x: bool) -> Vector2:
	return _lp(Vector2(along, across) if long_x else Vector2(across, along))
