extends Control
## L3 (night of 21 Nov 2026): one aspect icon of the designer v2 (JOB.md "Added 2026-11-20": the fixed set of 15),
## drawn with lines and shapes, no picture files: a coloured disc with an ink ring and a thick ink glyph, in the cel
## look of the house (flat fills, hard outline). Also the page's few interface glyphs (go, check, pause, play, redo,
## hammer, dice, back, plus, bolt, cross, swap). Unknown names draw a question mark.

const ASPECT_ICONS: PackedStringArray = ["player", "rival", "arena", "goal", "twist", "camera", "power", "time", "crowd",
	"ball", "vehicle", "weapon", "build", "music", "story"]

## The disc colour of each aspect icon: distinct hues at the same lightness, so a row of cards reads as a set.
const DISC: Dictionary = {
	"player": Color("#ffd166"), "rival": Color("#ff8a7a"), "arena": Color("#8fd3ff"), "goal": Color("#b8e986"),
	"twist": Color("#ff9ad5"), "camera": Color("#c3b5ff"), "power": Color("#ffe36e"), "time": Color("#9fe8d8"),
	"crowd": Color("#ffb877"), "ball": Color("#f2f2f2"), "vehicle": Color("#a6c8ff"), "weapon": Color("#d0d6e2"),
	"build": Color("#e9c39b"), "music": Color("#d7a6ff"), "story": Color("#f6e0a8"),
}

var kind: String = "player"
var ink: Color = Color("#1b1d32")
var disc: Color = Color(0, 0, 0, 0)     # transparent = the kind's own colour; set alpha 0 with `bare` for glyph only
var bare: bool = false                   # glyph only, no disc
var glyph_color: Color = Color(0, 0, 0, 0)   # transparent = ink
var spin: float = 0.0                    # radians, for the designing animation


func _init(k: String = "player", px: float = 64.0) -> void:
	kind = k
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_kind(k: String) -> void:
	kind = k
	queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var c: Vector2 = size * 0.5
	var u: float = s / 100.0                  # glyphs are drawn in a 100 x 100 box around the centre
	var w: float = maxf(2.0, 6.0 * u)         # the ink line
	if not bare:
		var fill: Color = disc if disc.a > 0.0 else DISC.get(kind, Color("#eeeeee"))
		draw_circle(c, s * 0.5 - w * 0.5, fill)
		draw_arc(c, s * 0.5 - w * 0.5, 0, TAU, 48, ink, w, true)
	var g: Color = glyph_color if glyph_color.a > 0.0 else ink
	draw_set_transform(c, spin, Vector2(u, u))
	_glyph(kind, g, 6.0 if not bare else 9.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _line(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	draw_line(a, b, col, w, true)
	draw_circle(a, w * 0.5, col)
	draw_circle(b, w * 0.5, col)


func _poly(points: PackedVector2Array, col: Color, w: float, closed: bool = true) -> void:
	var p: PackedVector2Array = points.duplicate()
	if closed:
		p.append(points[0])
	draw_polyline(p, col, w, true)
	for v: Vector2 in points:
		draw_circle(v, w * 0.5, col)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var pts: PackedVector2Array = []
	for i: int in 41:
		var a: float = float(i) / 40.0 * TAU
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, w, true)


func _glyph(k: String, g: Color, w: float) -> void:
	match k:
		"player":
			draw_circle(Vector2(0, -16), 11, g)
			_poly(PackedVector2Array([Vector2(-17, 24), Vector2(-14, 4), Vector2(14, 4), Vector2(17, 24)]), g, w)
			draw_colored_polygon(PackedVector2Array([Vector2(-17, 24), Vector2(-14, 4), Vector2(14, 4), Vector2(17, 24)]), g)
		"rival":
			draw_circle(Vector2(-13, -12), 9, g)
			draw_circle(Vector2(15, -12), 9, g)
			draw_colored_polygon(PackedVector2Array([Vector2(-27, 22), Vector2(-24, 2), Vector2(-3, 2), Vector2(-1, 22)]), g)
			draw_colored_polygon(PackedVector2Array([Vector2(1, 22), Vector2(4, 2), Vector2(26, 2), Vector2(29, 22)]), g)
			_line(Vector2(-8, -30), Vector2(8, -24), g, w * 0.8)
			_line(Vector2(8, -30), Vector2(-8, -24), g, w * 0.8)
		"arena":
			_ellipse(Vector2(0, 0), 33, 22, g, w)
			_ellipse(Vector2(0, 0), 15, 8, g, w * 0.8)
			_line(Vector2(0, -22), Vector2(0, -8), g, w * 0.7)
			_line(Vector2(0, 8), Vector2(0, 22), g, w * 0.7)
		"goal":
			_line(Vector2(-16, 30), Vector2(-16, -30), g, w)
			draw_colored_polygon(PackedVector2Array([Vector2(-16, -30), Vector2(24, -20), Vector2(-16, -6)]), g)
		"twist":
			var pts: PackedVector2Array = []
			for i: int in 40:
				var a: float = float(i) / 39.0 * TAU * 1.6
				var r: float = 4.0 + float(i) * 0.7
				pts.append(Vector2(cos(a), sin(a)) * r)
			draw_polyline(pts, g, w, true)
			draw_circle(pts[pts.size() - 1], w * 0.9, g)
		"camera":
			draw_colored_polygon(PackedVector2Array([Vector2(-28, -14), Vector2(28, -14), Vector2(28, 20), Vector2(-28, 20)]), g)
			draw_colored_polygon(PackedVector2Array([Vector2(-10, -14), Vector2(-5, -22), Vector2(9, -22), Vector2(14, -14)]), g)
			draw_circle(Vector2(0, 3), 11, DISC.get("camera", Color.WHITE) if not bare else Color.WHITE)
			draw_circle(Vector2(0, 3), 5, g)
		"power", "bolt":
			draw_colored_polygon(PackedVector2Array([Vector2(6, -32), Vector2(-18, 4), Vector2(-2, 4), Vector2(-8, 32), Vector2(18, -6), Vector2(2, -6)]), g)
		"time":
			draw_arc(Vector2.ZERO, 27, 0, TAU, 40, g, w, true)
			_line(Vector2.ZERO, Vector2(0, -17), g, w)
			_line(Vector2.ZERO, Vector2(12, 6), g, w)
		"crowd":
			for x: float in [-22.0, 0.0, 22.0]:
				var y: float = -4.0 if x == 0.0 else 4.0
				draw_circle(Vector2(x, y - 12), 7.5, g)
				draw_colored_polygon(PackedVector2Array([Vector2(x - 10, y + 22), Vector2(x - 8, y + 2), Vector2(x + 8, y + 2), Vector2(x + 10, y + 22)]), g)
		"ball":
			draw_arc(Vector2.ZERO, 27, 0, TAU, 40, g, w, true)
			draw_arc(Vector2(-34, 0), 27, -0.9, 0.9, 16, g, w * 0.8, true)
			draw_arc(Vector2(34, 0), 27, PI - 0.9, PI + 0.9, 16, g, w * 0.8, true)
		"vehicle":
			draw_colored_polygon(PackedVector2Array([Vector2(-32, 12), Vector2(-30, -2), Vector2(-14, -4), Vector2(-6, -18), Vector2(16, -18), Vector2(24, -4), Vector2(32, 0), Vector2(32, 12)]), g)
			draw_circle(Vector2(-17, 14), 9, g)
			draw_circle(Vector2(18, 14), 9, g)
			draw_circle(Vector2(-17, 14), 4, Color.WHITE)
			draw_circle(Vector2(18, 14), 4, Color.WHITE)
		"weapon":
			draw_colored_polygon(PackedVector2Array([Vector2(-4, 12), Vector2(-4, -28), Vector2(0, -34), Vector2(4, -28), Vector2(4, 12)]), g)
			_line(Vector2(-14, 12), Vector2(14, 12), g, w)
			_line(Vector2(0, 14), Vector2(0, 28), g, w * 1.1)
		"build":
			for row: int in 3:
				var y: float = 16.0 - float(row) * 15.0
				var off: float = 0.0 if row % 2 == 0 else 10.0
				for col: int in 3:
					var x: float = -30.0 + off + float(col) * 20.0
					if x + 18.0 > 32.0:
						continue
					draw_rect(Rect2(x, y - 6, 18, 12), g)
		"music":
			draw_circle(Vector2(-12, 18), 9, g)
			draw_circle(Vector2(16, 12), 9, g)
			_line(Vector2(-4, 18), Vector2(-4, -24), g, w)
			_line(Vector2(24, 12), Vector2(24, -30), g, w)
			draw_colored_polygon(PackedVector2Array([Vector2(-4, -24), Vector2(24, -30), Vector2(24, -20), Vector2(-4, -14)]), g)
		"story":
			draw_colored_polygon(PackedVector2Array([Vector2(-30, -18), Vector2(-2, -12), Vector2(-2, 24), Vector2(-30, 18)]), g)
			draw_colored_polygon(PackedVector2Array([Vector2(2, -12), Vector2(30, -18), Vector2(30, 18), Vector2(2, 24)]), g)
		# ---- interface glyphs
		"dot":
			pass
		"go", "arrow":
			_line(Vector2(-22, 0), Vector2(20, 0), g, w * 1.3)
			_poly(PackedVector2Array([Vector2(4, -16), Vector2(22, 0), Vector2(4, 16)]), g, w * 1.3, false)
		"back":
			_line(Vector2(22, 0), Vector2(-18, 0), g, w * 1.3)
			_poly(PackedVector2Array([Vector2(-2, -16), Vector2(-20, 0), Vector2(-2, 16)]), g, w * 1.3, false)
		"check":
			_poly(PackedVector2Array([Vector2(-22, 2), Vector2(-6, 18), Vector2(24, -16)]), g, w * 1.4, false)
		"cross", "drop":
			_line(Vector2(-18, -18), Vector2(18, 18), g, w * 1.4)
			_line(Vector2(18, -18), Vector2(-18, 18), g, w * 1.4)
		"pause", "hold":
			draw_rect(Rect2(-17, -20, 11, 40), g)
			draw_rect(Rect2(6, -20, 11, 40), g)
		"play":
			draw_colored_polygon(PackedVector2Array([Vector2(-14, -22), Vector2(22, 0), Vector2(-14, 22)]), g)
		"redo":
			draw_arc(Vector2.ZERO, 22, -PI * 0.9, PI * 0.55, 32, g, w * 1.2, true)
			draw_colored_polygon(PackedVector2Array([Vector2(-30, -14), Vector2(-12, -14), Vector2(-24, 2)]).duplicate(), g)
		"hammer":
			draw_colored_polygon(PackedVector2Array([Vector2(-24, -24), Vector2(10, -24), Vector2(14, -16), Vector2(10, -8), Vector2(-24, -8)]), g)
			_line(Vector2(-4, -8), Vector2(-4, 28), g, w * 1.4)
		"dice":
			draw_colored_polygon(PackedVector2Array([Vector2(-24, -24), Vector2(24, -24), Vector2(24, 24), Vector2(-24, 24)]), g)
			var pip: Color = ink if g.get_luminance() > 0.5 else Color.WHITE
			for p: Vector2 in [Vector2(-12, -12), Vector2(12, -12), Vector2(0, 0), Vector2(-12, 12), Vector2(12, 12)]:
				draw_circle(p, 5, pip)
		"plus":
			_line(Vector2(-18, 0), Vector2(18, 0), g, w * 1.3)
			_line(Vector2(0, -18), Vector2(0, 18), g, w * 1.3)
		"swap":
			_line(Vector2(-22, -9), Vector2(18, -9), g, w)
			_poly(PackedVector2Array([Vector2(8, -19), Vector2(20, -9), Vector2(8, 1)]), g, w, false)
			_line(Vector2(22, 9), Vector2(-18, 9), g, w)
			_poly(PackedVector2Array([Vector2(-8, -1), Vector2(-20, 9), Vector2(-8, 19)]), g, w, false)
		"gear":
			draw_arc(Vector2.ZERO, 14, 0, TAU, 24, g, w * 1.2, true)
			for i: int in 8:
				var a: float = float(i) / 8.0 * TAU
				_line(Vector2(cos(a), sin(a)) * 18.0, Vector2(cos(a), sin(a)) * 27.0, g, w * 1.2)
		_:
			draw_arc(Vector2(0, -10), 14, PI, TAU + 0.6, 20, g, w, true)
			_line(Vector2(6, 2), Vector2(0, 10), g, w)
			draw_circle(Vector2(0, 24), w * 0.8, g)
