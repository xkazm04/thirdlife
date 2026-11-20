extends RefCounted
## L4: the crisp look of the 2D screens (the main menu, the load screen, the pause card). No class_name; loaded by path.
## The colours are read from the crisp style file itself (style/style_crisp.json: its sky and palette), so the menu
## stays in the crisp look whatever look a dungeon installs. Flat fills, a thick ink border, ink outlines on text: the
## cel idea in 2D. Nothing here is a material, a light or an environment.

const CRISP: String = "res://style/style_crisp.json"

static var _c: Dictionary = {}


## {ink, paper, accent, accent_dark, sky_top, sky_mid, sky_low, shade, muted}
static func colors() -> Dictionary:
	if not _c.is_empty():
		return _c
	var pal: Dictionary = {}
	var sky: Dictionary = {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(CRISP)) if FileAccess.file_exists(CRISP) else null
	if d is Dictionary:
		pal = (d as Dictionary).get("palette", {})
		sky = (d as Dictionary).get("sky", {})
	var c := func(src: Dictionary, k: String, fb: String) -> Color:
		return Color(str(src.get(k, fb)))
	_c = {"ink": c.call(pal, "black", "#2b2532"), "paper": c.call(pal, "curb_white", "#f3e8dc"),
		"accent": c.call(pal, "yellow", "#f2b230"), "accent_dark": c.call(pal, "yellow_dark", "#c98720"),
		"sky_top": c.call(sky, "zenith", "#754bb6"), "sky_mid": c.call(sky, "mid", "#e177a7"),
		"sky_low": c.call(sky, "horizon", "#ffbd84"), "shade": c.call(sky, "cloud_ink", "#5a3470"),
		"muted": c.call(pal, "stone_dark", "#7e7480")}
	return _c


## A full-rect vertical gradient of the crisp sky (zenith, mid, horizon), as a TextureRect.
static func sky_backdrop() -> TextureRect:
	var k: Dictionary = colors()
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	g.colors = PackedColorArray([k["sky_top"], k["sky_mid"], k["sky_low"]])
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.width = 8
	t.height = 256
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	var r: TextureRect = TextureRect.new()
	r.name = "Sky"
	r.texture = t
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func box(fill: Color, border: Color, width: int = 5, radius: int = 14) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


## A card: paper fill, ink border.
static func card() -> PanelContainer:
	var k: Dictionary = colors()
	var p: PanelContainer = PanelContainer.new()
	var s: StyleBoxFlat = box(k["paper"], k["ink"], 6, 18)
	s.shadow_color = Color(k["ink"], 0.35)
	s.shadow_size = 0
	s.shadow_offset = Vector2(8, 8)
	s.content_margin_left = 36
	s.content_margin_right = 36
	s.content_margin_top = 28
	s.content_margin_bottom = 28
	p.add_theme_stylebox_override("panel", s)
	return p


## Big ink-outlined text in paper (a title over the sky) or ink text (on a card).
static func label(text: String, size: int, on_card: bool = true) -> Label:
	var k: Dictionary = colors()
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if on_card:
		l.add_theme_color_override("font_color", k["ink"])
	else:
		l.add_theme_color_override("font_color", k["paper"])
		l.add_theme_color_override("font_outline_color", k["ink"])
		l.add_theme_constant_override("outline_size", maxi(4, size / 6))
	return l


## A menu button: paper with an ink border; focused or hovered, the accent fill. Keyboard and mouse both work.
static func button(text: String, size: int = 34) -> Button:
	var k: Dictionary = colors()
	var b: Button = Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", k["ink"])
	b.add_theme_color_override("font_hover_color", k["ink"])
	b.add_theme_color_override("font_focus_color", k["ink"])
	b.add_theme_color_override("font_pressed_color", k["ink"])
	b.add_theme_color_override("font_disabled_color", Color(k["ink"], 0.45))
	b.add_theme_stylebox_override("normal", box(k["paper"], k["ink"]))
	b.add_theme_stylebox_override("hover", box(k["accent"], k["ink"]))
	b.add_theme_stylebox_override("focus", box(k["accent"], k["ink"], 7))
	b.add_theme_stylebox_override("pressed", box(k["accent_dark"], k["ink"]))
	b.add_theme_stylebox_override("disabled", box(Color(k["paper"], 0.6), Color(k["ink"], 0.4)))
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, size * 2)
	return b


## A square tile with one or two letters: the icon of a dungeon that has no still yet.
static func monogram(text: String, tint: Color, side: int = 120) -> PanelContainer:
	var k: Dictionary = colors()
	var p: PanelContainer = PanelContainer.new()
	p.custom_minimum_size = Vector2(side, side)
	p.add_theme_stylebox_override("panel", box(tint, k["ink"], 5, 12))
	var l: Label = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", side / 2)
	l.add_theme_color_override("font_color", k["paper"])
	l.add_theme_color_override("font_outline_color", k["ink"])
	l.add_theme_constant_override("outline_size", 10)
	p.add_child(l)
	return p
