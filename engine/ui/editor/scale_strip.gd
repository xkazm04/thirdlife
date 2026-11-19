extends Control
## E1: the footprint from the side at true scale beside the 2 m walking figure, and the size in words a player can
## feel: metres, seconds to run across, the lot radius, the worked example's own plot.

var model: RefCounted
var col: Dictionary = {}
var font: Font
var bold: Font


func _draw() -> void:
	var text_w: float = maxf(302, size.x * 0.43)
	var tx: float = size.x - text_w
	draw_rect(Rect2(Vector2.ZERO, size), col["card"])
	draw_rect(Rect2(0, 0, tx - 7, size.y), col["vellum"])
	var grid := Color(col["wood_dark"], 0.13)
	for x: int in range(7, int(tx - 7), 12):
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid, 1)
	for y: int in range(7, int(size.y), 12):
		draw_line(Vector2(0, y), Vector2(tx - 7, y), grid, 1)
	draw_line(Vector2(tx - 7, 0), Vector2(tx - 7, size.y), col["rule"], 1)
	draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), col["rule"], false, 1)
	if model == null or model.recipe.is_empty():
		var ry := size.y * 0.48
		var rw := minf(212, tx * 0.65)
		var rx := (tx - rw) * 0.5
		draw_rect(Rect2(rx+2, ry+3, rw, 19), Color(col["trunk"], 0.23))
		draw_rect(Rect2(rx, ry, rw, 19), col["wood"])
		draw_rect(Rect2(rx, ry, rw, 19), col["wood_dark"], false, 1.4)
		for x: int in range(5, int(rw-3), 5):
			draw_line(Vector2(rx+x, ry), Vector2(rx+x, ry + (9 if x % 20 == 0 else 4)), col["trunk"], 1)
		draw_string(font, Vector2(tx+4, ry+6), "The size shows here once the game has a recipe.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col["dim"])
		return
	var f: Vector3 = model.footprint()
	var long: float = maxf(f.x, f.y)
	var room: Vector2 = Vector2(size.x - text_w - 90.0, size.y - 39.0)
	var s: float = minf(room.x / (long + 6.0), room.y / maxf(f.z, model.walker_m))
	var ground: float = size.y - 12.0
	var x0 := maxf(19, (tx - ((long + 6) * s + 64)) * 0.5)
	draw_line(Vector2(x0-10, ground), Vector2(x0 + (long + 6.0) * s + 10.0, ground), col["ink"], 2.0)
	# the walker, true scale, at the left
	var wx: float = x0 + 1.0 * s
	_walker(Vector2(wx, ground), model.walker_m * s)
	# the venue: its long side and height as a block with a stepped top (stands) when it is taller than 4 m
	var bx: float = x0 + 4.0 * s
	var bw: float = long * s
	var bh: float = f.z * s
	var shape: Dictionary = model.shape()
	var bounds := Rect2(bx, ground - bh, bw, bh)
	_elevation(bounds, shape, s)
	# Engraved dimensions. Leave the plotted box entirely for the elevation.
	var dim_y := 12.0
	draw_line(Vector2(bx, dim_y), Vector2(bx+bw, dim_y), col["trunk"], 1.0)
	for x: float in [bx, bx + bw]:
		draw_line(Vector2(x-2, dim_y+3), Vector2(x+2, dim_y-3), col["ink"], 1.4, true)
	var lt: String = "%d m" % int(round(long))
	var tw := bold.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var mid_x := bx + bw * 0.5
	draw_rect(Rect2(mid_x - tw * 0.5 - 3, 4, tw + 6, 16), col["vellum"])
	draw_string(bold, Vector2(mid_x - tw * 0.5, 16), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col["ink"])
	draw_string(bold, Vector2(bx + bw + 5, ground - bh * 0.5 + 3), "%d m high" % int(round(f.z)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col["ink"])
	draw_string(font, Vector2(wx - 9, ground - model.walker_m * s - 4), "you", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col["ink"])
	# words
	tx += 4
	var y: float = 22.0
	draw_string(bold, Vector2(tx, y), "%d x %d m, %d m high (estimate)" % [int(round(f.x)), int(round(f.y)), int(round(f.z))], HORIZONTAL_ALIGNMENT_LEFT, text_w - 8, 13, col["ink"])
	draw_line(Vector2(tx, y + 6), Vector2(size.x - 9, y + 6), col["rule"], 1)
	y += 22
	draw_string(font, Vector2(tx, y), "about %d s to run across, %d walkers end to end" % [int(round(model.seconds_across())), int(round(long / model.walker_m))], HORIZONTAL_ALIGNMENT_LEFT, text_w - 8, 12, col["ink"])
	y += 19
	draw_string(font, Vector2(tx, y), "lot radius %d m (half the diagonal + 4 m)" % int(model.lot_radius()), HORIZONTAL_ALIGNMENT_LEFT, text_w - 8, 12, col["ink"])
	y += 19
	var n: Dictionary = model.neighbour_like()
	var src: String = str(model.interview().get("footprint", {}).get("source", ""))
	if not n.is_empty():
		draw_string(font, Vector2(tx, y), "the example's own plot \"%s\": radius %d m" % [str(n["label"]), int(n["r"])], HORIZONTAL_ALIGNMENT_LEFT, text_w - 8, 12, col["dim"])
	elif not src.is_empty():
		draw_string(font, Vector2(tx, y), "from " + src, HORIZONTAL_ALIGNMENT_LEFT, text_w - 8, 12, col["dim"])


func _elevation(box: Rect2, shape: Dictionary, scale_m: float) -> void:
	var x := box.position.x
	var y := box.position.y
	var w := box.size.x
	var h := box.size.y
	var bottom := box.end.y
	var edge: Color = col["trunk"]
	var timber: Color = col["wood"]
	var stands: bool = shape.get("stands", false)
	var course: bool = shape.get("shape", "") == "course"
	var deck := clampf(scale_m * 0.8, 1, 5)
	# The long side and highest point are the dimensions of the estimate. Risers,
	# timbers and cross-bracing give those two marks a legible side elevation.
	if stands:
		var left := x + w * 0.11
		var right := x + w * 0.89
		var seat_y := bottom - h * 0.58
		var bay := (right - left) / 6.0
		draw_rect(Rect2(left, seat_y, right-left, bottom-seat_y), Color(col["sand"], 0.55))
		for i: int in 6:
			var x0 := left + i * bay
			draw_line(Vector2(x0, bottom), Vector2(x0 + bay, seat_y), edge, 1.6, true)
			draw_line(Vector2(x0, seat_y), Vector2(x0 + bay, bottom), Color(edge, 0.65), 1, true)
			draw_line(Vector2(x0, seat_y), Vector2(x0, bottom), edge, 1.8, true)
		draw_line(Vector2(right, seat_y), Vector2(right, bottom), edge, 2)
		for i: int in 3:
			var level := seat_y + i * h * 0.076
			draw_line(Vector2(left, level), Vector2(right, level), col["seat"] if i == 1 else edge, maxf(1, deck * 0.56))
		for px: float in [x + w * 0.075, x + w * 0.925]:
			draw_line(Vector2(px, bottom), Vector2(px, y+2), edge, 1.9, true)
			draw_rect(Rect2(px-5, y, 10, 3.5), edge)
			draw_line(Vector2(px-4, y+1), Vector2(px+4, y+1), col["honey"], 1.4)
		draw_rect(Rect2(x, bottom - deck * 2.7, w, deck * 2.7), col["block"])
		draw_rect(Rect2(x, bottom - deck * 2.7, w, deck * 2.7), edge, false, 1)
	elif course:
		var knots := PackedVector2Array([Vector2(x, bottom-2), Vector2(x+w*0.20, bottom-h*0.44),
			Vector2(x+w*0.34, bottom-h*0.44), Vector2(x+w*0.58, y), Vector2(x+w*0.69, y), Vector2(x+w, bottom-3)])
		for i: int in range(1, knots.size()-1):
			var top := knots[i]
			draw_line(top, Vector2(top.x, bottom), edge, 2, true)
			draw_line(top, Vector2(knots[i+1].x, bottom), Color(edge, 0.7), 1.4, true)
		draw_polyline(knots, edge, deck+2, true)
		draw_polyline(knots, timber, deck, true)
	else:
		draw_rect(box, Color(col["block"], 0.72))
		draw_rect(box, edge, false, 1.5)
		var n := maxi(2, roundi(w / maxf(6, scale_m * 5)))
		for i: int in range(1, n):
			var px := x + w * i / n
			draw_line(Vector2(px, y), Vector2(px, bottom), Color(edge, 0.55), 1)
		draw_line(Vector2(x, y+1), Vector2(box.end.x, y+1), timber, 2)
	draw_rect(Rect2(x, bottom-deck, w, deck), col["wood_dark"])
	for i: int in range(0, int(w), 8):
		draw_line(Vector2(x+i, bottom+1), Vector2(x+i-3, bottom+4), col["rule"], 1, true)


func _walker(foot: Vector2, h: float) -> void:
	var head: float = h * 0.13
	var c: Color = col["jacket"]
	var hip: Vector2 = foot + Vector2(0, -h * 0.48)
	var neck: Vector2 = foot + Vector2(0, -h * 0.8)
	var lw: float = maxf(1.5, h * 0.09)
	draw_line(hip, foot + Vector2(-h * 0.12, 0), col["ink"], lw)
	draw_line(hip, foot + Vector2(h * 0.12, 0), col["ink"], lw)
	draw_line(hip, neck, c, lw * 1.8)
	draw_line(neck + Vector2(0, h * 0.04), neck + Vector2(-h * 0.16, h * 0.3), c, lw)
	draw_line(neck + Vector2(0, h * 0.04), neck + Vector2(h * 0.16, h * 0.3), c, lw)
	draw_circle(neck + Vector2(0, -head), head, col["skin"])
	draw_arc(neck + Vector2(0, -head), head, 0, TAU, 16, col["ink"], 1.0, true)
