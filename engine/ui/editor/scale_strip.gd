extends Control
## E1: the footprint from the side at true scale beside the 2 m walking figure, and the size in words a player can
## feel: metres, seconds to run across, the lot ring, the worked example's own plot.

var model: RefCounted
var col: Dictionary = {}
var font: Font
var bold: Font


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), col["paper"])
	if model == null or model.recipe.is_empty():
		draw_string(font, Vector2(12, size.y * 0.5 + 5), "The size shows here once the game has a recipe.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col["dim"])
		return
	var f: Vector3 = model.footprint()
	var long: float = maxf(f.x, f.y)
	var text_w: float = 300.0
	var room: Vector2 = Vector2(size.x - text_w - 90.0, size.y - 22.0)
	var s: float = minf(room.x / (long + 6.0), room.y / maxf(f.z, model.walker_m))
	var ground: float = size.y - 12.0
	var x0: float = 20.0
	draw_line(Vector2(8, ground), Vector2(x0 + (long + 6.0) * s + 10.0, ground), col["ink"], 2.0)
	# the walker, true scale, at the left
	var wx: float = x0 + 1.0 * s
	_walker(Vector2(wx, ground), model.walker_m * s)
	# the venue: its long side and height as a block with a stepped top (stands) when it is taller than 4 m
	var bx: float = x0 + 4.0 * s
	var bw: float = long * s
	var bh: float = f.z * s
	var poly: PackedVector2Array
	if f.z > 4.0:
		var step: float = bh / 3.0
		poly = PackedVector2Array([Vector2(bx, ground), Vector2(bx, ground - step), Vector2(bx + bw * 0.12, ground - step),
			Vector2(bx + bw * 0.12, ground - bh), Vector2(bx + bw * 0.88, ground - bh), Vector2(bx + bw * 0.88, ground - step),
			Vector2(bx + bw, ground - step), Vector2(bx + bw, ground)])
	else:
		poly = PackedVector2Array([Vector2(bx, ground), Vector2(bx, ground - bh), Vector2(bx + bw, ground - bh), Vector2(bx + bw, ground)])
	draw_colored_polygon(poly, col["block"])
	poly.append(poly[0])
	draw_polyline(poly, col["ink"], 2.0, true)
	# dimension marks
	draw_line(Vector2(bx, 8), Vector2(bx + bw, 8), col["ink"], 1.0)
	draw_line(Vector2(bx, 4), Vector2(bx, 12), col["ink"], 1.0)
	draw_line(Vector2(bx + bw, 4), Vector2(bx + bw, 12), col["ink"], 1.0)
	var lt: String = "%d m" % int(round(long))
	draw_string(bold, Vector2(bx + bw * 0.5 - 14, 22), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col["ink"])
	draw_string(bold, Vector2(bx + bw + 6, ground - bh + 10), "%d m high" % int(round(f.z)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col["ink"])
	draw_string(font, Vector2(wx - 8, ground - model.walker_m * s - 4), "you", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col["ink"])
	# words
	var tx: float = size.x - text_w
	var y: float = 22.0
	draw_string(bold, Vector2(tx, y), "%d x %d m, %d m high (estimate)" % [int(round(f.x)), int(round(f.y)), int(round(f.z))], HORIZONTAL_ALIGNMENT_LEFT, text_w - 8, 13, col["ink"])
	y += 20
	draw_string(font, Vector2(tx, y), "about %d s to run across, %d walkers end to end" % [int(round(model.seconds_across())), int(round(long / model.walker_m))], HORIZONTAL_ALIGNMENT_LEFT, text_w - 8, 12, col["ink"])
	y += 19
	draw_string(font, Vector2(tx, y), "lot ring %d m (half the diagonal + 4 m)" % int(model.lot_radius()), HORIZONTAL_ALIGNMENT_LEFT, text_w - 8, 12, col["ink"])
	y += 19
	var n: Dictionary = model.neighbour_like()
	var src: String = str(model.interview().get("footprint", {}).get("source", ""))
	if not n.is_empty():
		draw_string(font, Vector2(tx, y), "the example's own plot \"%s\": ring %d m" % [str(n["label"]), int(n["r"])], HORIZONTAL_ALIGNMENT_LEFT, text_w - 8, 12, col["dim"])
	elif not src.is_empty():
		draw_string(font, Vector2(tx, y), "from " + src, HORIZONTAL_ALIGNMENT_LEFT, text_w - 8, 12, col["dim"])


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
