extends Control
## One printed instrument. All measurements are in the local ticket's units.
const Stock = preload("res://style/hud/stock.gd")
const CAPTION_PX := 18
const CUE_PX := 29
const TIMING_WIDTH := 234.0
const KEY_PX := 18
const KEY_ROW_WIDTH := 332.0
var form: String
var title: String
var reading: Dictionary = {}
var inks: Dictionary
var heavy := Stock.font(900, 80)
var number := Stock.font(820, 87)
var label := Stock.font(740, 95)
var body := Stock.font(570, 100)
var _cue_width: float
var _key_positions: Array[Vector2] = []

func setup(spec: Dictionary, colors: Dictionary) -> void:
	form = spec.form
	title = spec.title
	inks = colors
	oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_reading(next: Dictionary) -> void:
	if reading == next:
		return
	reading = next.duplicate(true)
	measure()
	queue_redraw()

func measure() -> void:
	if reading.is_empty():
		return
	match form:
		"bib":
			size = Vector2(79 + maxf(80, _width(label, reading.name, 19)), 42)
		"cue":
			_cue_width = clampf(_width(heavy, reading.value, CUE_PX) + 2, 150, 330)
			var lines := heavy.get_multiline_string_size(reading.value, HORIZONTAL_ALIGNMENT_LEFT, _cue_width, CUE_PX)
			size = Vector2(_cue_width + 36, 33 + lines.y)
		"split": size = Vector2(TIMING_WIDTH, 76)
		"timer": size = Vector2(TIMING_WIDTH, 56)
		"progress":
			var count_text := "%02d / %02d" % [reading.done, reading.total]
			var heading_width := _width(number, count_text, 26) + 14 + _width(label, title.to_upper(), CAPTION_PX)
			size = Vector2(maxf(242, 24 + heading_width), 56)
		"keys":
			_key_positions.clear()
			var x := 7.0
			var y := 5.0
			var width := 8.0
			for pair: Array in reading.pairs:
				var advance := _key_width(pair)
				if x > 7 and x + advance > KEY_ROW_WIDTH:
					x = 7
					y += 27
				_key_positions.append(Vector2(x, y))
				x += advance
				width = maxf(width, x)
			size = Vector2(width, y + 29)
		"results": size = Vector2(350, 154 + 31 * reading.rows.size())

func _width(face: Font, value: String, px: int) -> float:
	return ceilf(face.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)

func _key_width(pair: Array) -> float:
	return _width(label, pair[0], KEY_PX) + 10 + _width(body, pair[1], KEY_PX) + 15

func _type(x: float, baseline: float, value: String, face: Font, px: int, color: Color) -> void:
	draw_string(face, Vector2(x, baseline), value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)

func _right(x: float, baseline: float, value: String, face: Font, px: int, color: Color) -> void:
	_type(x - _width(face, value, px), baseline, value, face, px, color)

func _rect(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)

func _plate(color: Color, cut: float = 0, tear: float = -1) -> void:
	var points := PackedVector2Array([Vector2.ZERO, Vector2(size.x - cut, 0)])
	if cut > 0:
		points.append(Vector2(size.x, cut))
	if tear > 0:
		points.append_array(PackedVector2Array([Vector2(size.x, tear - 5), Vector2(size.x - 4, tear - 3),
			Vector2(size.x - 5, tear), Vector2(size.x - 4, tear + 3), Vector2(size.x, tear + 5)]))
	points.append_array(PackedVector2Array([size, Vector2(0, size.y)]))
	if tear > 0:
		points.append_array(PackedVector2Array([Vector2(0, tear + 5), Vector2(4, tear + 3),
			Vector2(5, tear), Vector2(4, tear - 3), Vector2(0, tear - 5)]))
	draw_set_transform(Vector2(1, 2))
	draw_colored_polygon(points, Color(inks.ink, 0.76))
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(points, color)

func _draw() -> void:
	if reading.is_empty():
		return
	var ink: Color = inks.ink
	var paper: Color = inks.paper
	match form:
		"bib":
			_plate(ink)
			_rect(0, 0, 49, size.y, inks.accent)
			_type(8, 32, reading.value, heavy, 31, inks.accent_text)
			_type(60, 16, title.to_upper(), label, CAPTION_PX, inks.marker)
			_type(60, 36, reading.name, label, 19, paper)
		"cue":
			_plate(paper, 12)
			_rect(0, 0, 4, size.y, inks.accent)
			_type(14, 19, title.to_upper(), label, CAPTION_PX, ink)
			var rule_start := 22 + _width(label, title.to_upper(), CAPTION_PX)
			if rule_start < size.x - 19:
				draw_line(Vector2(rule_start, 13), Vector2(size.x - 19, 13), Color(ink, 0.44), 1)
			draw_multiline_string(heavy, Vector2(13, 25 + heavy.get_ascent(CUE_PX)), reading.value,
				HORIZONTAL_ALIGNMENT_LEFT, _cue_width, CUE_PX, -1, ink)
		"split":
			_plate(ink, 8)
			_type(12, 29, reading.name.to_upper(), label, CAPTION_PX, paper)
			_right(size.x - 12, 33, reading.value, number, 32, paper)
			_rect(0, 43, size.x, 33, paper)
			_type(12, 66, "BEST", label, CAPTION_PX, ink)
			_type(65, 67, reading.best, number, 23, ink)
			if reading.delta != "":
				var bg: Color = inks.good if not str(reading.delta).begins_with("+") else inks.accent
				var fg: Color = ink if not str(reading.delta).begins_with("+") else inks.accent_text
				_rect(135, 43, size.x - 135, 33, bg)
				_right(size.x - 10, 68, reading.delta, number, 25, fg)
		"timer":
			_plate(ink)
			_type(12, 20, title.to_upper(), label, CAPTION_PX, inks.marker)
			_type(12, 48, reading.value, number, 28, paper)
			draw_line(Vector2(119, 9), Vector2(119, 47), Color(paper, 0.35))
			_right(size.x - 12, 20, "RUN BEST", label, CAPTION_PX, paper)
			_right(size.x - 12, 48, reading.best, number, 23, paper)
		"progress":
			_plate(ink)
			_type(12, 27, "%02d / %02d" % [reading.done, reading.total], number, 26, paper)
			_right(size.x - 12, 26, title.to_upper(), label, CAPTION_PX, paper)
			var count := mini(int(reading.total), 24)
			var step := (size.x - 34) / maxi(count - 1, 1)
			var radius := minf(5.5, step * 0.36)
			for i: int in count:
				var pos := Vector2(17 + i * step, 42)
				var marked := i < roundi(float(reading.done) * count / reading.total)
				draw_circle(pos, radius, inks.marker if marked else Color(paper, 0.8), marked, -1 if marked else 1.5, true)
		"keys":
			_plate(ink)
			for i: int in reading.pairs.size():
				var pair: Array = reading.pairs[i]
				var pos := _key_positions[i]
				var cap := _width(label, pair[0], KEY_PX) + 10
				_rect(pos.x, pos.y, cap, 24, ink.lerp(paper, 0.13))
				draw_rect(Rect2(pos, Vector2(cap, 24)), Color(paper, 0.54), false, 1)
				_type(pos.x + 5, pos.y + 18, pair[0], label, KEY_PX, paper)
				_type(pos.x + cap + 5, pos.y + 18, pair[1], body, KEY_PX, paper)
		"results":
			_draw_results()

func _draw_results() -> void:
	var ink: Color = inks.ink
	var paper: Color = inks.paper
	_plate(paper, 12, size.y - 39)
	_rect(0, 0, 7, 76, inks.accent)
	_type(17, 23, "COURSE RESULT", label, CAPTION_PX, ink)
	_type(15, 62, reading.name, heavy, 42, ink)
	_right(size.x - 16, 23, "RUN TIME  /  S", label, CAPTION_PX, ink)
	_right(size.x - 16, 61, reading.value, number, 35, ink)
	_rect(0, 76, size.x, 30, ink)
	_type(17, 97, "STAGE", label, CAPTION_PX, paper)
	_right(243, 97, "SPLIT", label, CAPTION_PX, paper)
	_right(333, 97, "BEST", label, CAPTION_PX, paper)
	var y := 106.0
	for i: int in reading.rows.size():
		var row: Array = reading.rows[i]
		_type(16, y + 23, "%02d" % (i + 1), number, CAPTION_PX, Color(ink, 0.78))
		_type(48, y + 23, row[0], label, 19, ink)
		_right(243, y + 23, row[1], number, 23, ink)
		_right(333, y + 23, row[2], body, 21, ink)
		y += 31
		draw_line(Vector2(15, y), Vector2(333, y), Color(ink, 0.19))
	draw_dashed_line(Vector2(6, y + 9), Vector2(size.x - 6, y + 9), Color(ink, 0.62), 1, 4)
	_type(16, y + 35, "PERSONAL BEST", label, CAPTION_PX, ink)
	_right(size.x - 17, y + 36, reading.best, number, 24, ink)
