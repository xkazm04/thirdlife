extends StyleBox
## The printed and metalwork details belong to the existing plates. A StyleBox paints behind
## its Control's content and takes no part in picking, focus or layout beyond its margins.

const Art = preload("res://ui/editor/workshop_art.gd")

var stock: StyleBoxFlat
var paint: Dictionary
var finish: String
var emblem: String


func _init(base: StyleBoxFlat, colors: Dictionary, kind: String, symbol: String) -> void:
	stock = base
	paint = colors
	finish = kind
	emblem = symbol if not symbol.is_empty() else kind
	for side: Side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		set_content_margin(side, base.get_content_margin(side))


func _draw(canvas: RID, r: Rect2) -> void:
	stock.draw(canvas, r)
	var p := r.position
	var z := r.end
	match finish:
		"paper", "review", "rail":
			var dark: bool = finish != "paper"
			var hair := Color(paint["sand"] if dark else paint["wood_dark"], 0.48 if dark else 0.3)
			var inset := r.grow(-4)
			var corners := PackedVector2Array([inset.position, Vector2(inset.end.x, inset.position.y), inset.end, Vector2(inset.position.x, inset.end.y)])
			var glaze: Color = paint["wood"] if dark else paint["card"]
			RenderingServer.canvas_item_add_polygon(canvas, corners, PackedColorArray([Color(glaze, 0.04 if dark else 0.55), Color(glaze, 0.02), Color(glaze, 0), Color(glaze, 0)]))
			_line(canvas, Vector2(p.x + 8, p.y + 4), Vector2(z.x - 8, p.y + 4), hair)
			_line(canvas, Vector2(p.x + 8, z.y - 5), Vector2(z.x - 8, z.y - 5), hair)
			if dark:
				for x: float in [p.x + 7, z.x - 7]:
					RenderingServer.canvas_item_add_circle(canvas, Vector2(x, p.y + r.size.y / 2), 2.0, paint["wood"], true)
			else:
				for x: float in [p.x + 6, z.x - 6]:
					_line(canvas, Vector2(x, z.y - 10), Vector2(x, z.y - 5), hair)
		"heading":
			RenderingServer.canvas_item_add_rect(canvas, Rect2(p + Vector2(0, 4), Vector2(5, r.size.y - 8)), paint["honey_dark"])
			_line(canvas, Vector2(p.x + 7, p.y + 4), Vector2(p.x + 7, z.y - 4), paint["wood"])
		"flag":
			var bounds := Rect2(p.x, p.y + (r.size.y - 23) / 2, 31, 23)
			RenderingServer.canvas_item_add_texture_rect(canvas, bounds, Art.stamp("flag", paint).get_rid())
		"recipe", "notice":
			var accent: Color = paint["hazard"] if finish == "notice" else paint["honey_dark"]
			var vignette := Rect2(p + Vector2(10, (r.size.y - 31) * 0.5), Vector2(43, 31))
			RenderingServer.canvas_item_add_texture_rect(canvas, vignette, Art.stamp(emblem, paint).get_rid())
			_line(canvas, Vector2(p.x + 53, p.y + 7), Vector2(p.x + 53, z.y - 7), Color(accent, 0.5))
			RenderingServer.canvas_item_add_rect(canvas, Rect2(p + Vector2(2, 2), Vector2(5, r.size.y - 4)), accent)
			for i: int in 3:
				_line(canvas, Vector2(z.x - 19 + 4 * i, p.y + 8), Vector2(z.x - 16 + 4 * i, p.y + 5), Color(accent, 0.65))
		"index":
			_line(canvas, Vector2(p.x, z.y - 1), Vector2(z.x, z.y - 1), Color(paint["wood"], 0.5))
		"ledger":
			_line(canvas, Vector2(p.x, z.y - 1), Vector2(z.x, z.y - 1), Color(paint["wood_dark"], 0.28))
		"blank":
			# A blind-printed stack of recipe cards on the unused leaf. Only visible while
			# the question area is empty. Keep it clear of example chips at small heights.
			if r.size.y > 116:
				var w := minf(190, minf(r.size.x * 0.4, r.size.y * 0.63))
				var center := r.get_center()
				var mark := Rect2(center - Vector2(w, w * 0.72) * 0.5, Vector2(w, w * 0.72))
				for dx: float in [-1.0, 1.0]:
					_line(canvas, center + Vector2(dx * (w * 0.5 + 4), 0), center + Vector2(dx * (w * 0.5 + 27), 0), paint["rule"])
				RenderingServer.canvas_item_add_texture_rect(canvas, mark, Art.stamp("cards", paint, w).get_rid(), false, Color(paint["paper"], 0.78))


func _line(canvas: RID, a: Vector2, b: Vector2, color: Color) -> void:
	RenderingServer.canvas_item_add_line(canvas, a, b, color, 1, true)
