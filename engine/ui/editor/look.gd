extends RefCounted
## E1: the workbench's look: colours from style/style.json (the house palette) and the theme of its controls: cream
## plates with an ink outline, honey for what is chosen and for the one button that spends.

const Presswork = preload("res://ui/editor/presswork.gd")
const TYPEFACE := "res://style/hud/Archivo.ttf"

const JobModel = preload("res://ui/job_model.gd")


static func colors() -> Dictionary:
	var style: Variant = JobModel.read_json(ProjectSettings.globalize_path("res://style/style.json"))
	var pal: Dictionary = (style as Dictionary).get("palette", {}) if style is Dictionary else {}
	var ink: String = str(((style as Dictionary).get("ink", {}) as Dictionary).get("ink", "#1a1024")) if style is Dictionary else "#1a1024"
	var pick: Callable = func(key: String, fallback: String) -> Color: return Color(str(pal.get(key, fallback)))
	var stock: Color = pick.call("curb_white", "#f3e8dc").lerp(pick.call("spark", "#ffe08a"), 0.13)
	stock = stock.lerp(pick.call("white", "#ffffff"), 0.07)
	var wood_dark: Color = pick.call("wood_dark", "#7c4a30")
	var leaf: Color = pick.call("leaf", "#6c9a3c")
	var dry: Color = pick.call("grass_dry", "#bdbb4c")
	return {
		"stamps": {},
		"rail": Color(ink).lerp(pick.call("roof_slate", "#5c4c6c"), 0.07),
		"rule": wood_dark.lerp(stock, 0.56),
		"card": stock.lerp(pick.call("white", "#ffffff"), 0.60),
		"vellum": stock.lerp(pick.call("wood_light", "#e2b472"), 0.27),
		"wood_dark": wood_dark,
		"trunk": pick.call("trunk", "#6c4a3b"),
		"roof": pick.call("roof", "#98443c"),
		"window": pick.call("window", "#ffc462"),
		"stone": pick.call("rock", "#a8998f"),
		"leaf": leaf, "leaf_light": pick.call("leaf_light", "#a9c243"),
		"pine": pick.call("pine", "#2f6b4c"), "pine_light": pick.call("pine_light", "#4c8c58"),
		"meadow_light": dry.lerp(stock, 0.40),
		"meadow_dark": leaf.lerp(dry, 0.42),
		"ink": Color(ink),
		"paper": stock,
		"paper2": pick.call("line_white", "#efe6dc").darkened(0.04),
		"dim": Color(ink).lerp(pick.call("curb_white", "#f3e8dc"), 0.31),
		"honey": pick.call("yellow", "#f2b230"),
		"honey_dark": pick.call("yellow_dark", "#c98720"),
		"hazard": pick.call("hazard_red", "#d8452e").lerp(Color(ink), 0.27),
		"green": pick.call("pine", "#2f6b4c").lerp(Color(ink), 0.14),
		"map": dry.lerp(pick.call("grass", "#86b944"), 0.22),
		"plot": dry.lerp(stock, 0.35),
		"road": pick.call("dirt", "#c99568"),
		"dirt": pick.call("sand", "#dcb88a"),
		"crane": pick.call("yellow", "#f2b230"),
		"block": pick.call("ice", "#e2f2ff").lerp(pick.call("steel_light", "#b6b0c8"), 0.3),
		"jacket": pick.call("jacket", "#d24a3a"),
		"skin": pick.call("skin", "#eab294"),
		"shade": pick.call("roof_slate", "#5c4c6c"),
		"ice": pick.call("ice", "#e2f2ff"),
		"glass": pick.call("glass", "#b4def0"),
		"rink_red": pick.call("rink_red", "#d94242"),
		"rink_blue": pick.call("rink_blue", "#4274d9"),
		"seat": pick.call("seat", "#4a66c8"),
		"tarmac": pick.call("tarmac_light", "#747c90"),
		"sand": pick.call("sand", "#dcb88a"),
		"wood": pick.call("wood_light", "#e2b472"),
		"brick": pick.call("curb_red", "#dc4238"),
		"pitch": pick.call("grass_dark", "#4f8a3e"),
		"concrete": pick.call("concrete", "#cbbdb4"),
		"cone": pick.call("cone", "#f0702c"),
		"bay_queued": pick.call("concrete", "#cbbdb4"),
		"bay_running": pick.call("yellow", "#f2b230"),
		"bay_verifying": pick.call("glass", "#b4def0"),
		"bay_blocked": pick.call("orange", "#e8742c"),
		"bay_promoted": pick.call("leaf_light", "#a9c243"),
		"bay_failed": pick.call("hazard_red", "#d8452e"),
		"water": pick.call("water", "#4a8ac0"),
		"hazard_light": pick.call("hazard_red", "#d8452e").lerp(pick.call("curb_white", "#f3e8dc"), 0.5),
	}


static func typeface() -> Font:
	# A source checkout can run the shot host before the editor has imported a new font.
	if ResourceLoader.exists(TYPEFACE):
		return load(TYPEFACE)
	var file := FontFile.new()
	if file.load_dynamic_font(TYPEFACE) == OK:
		return file
	return ThemeDB.fallback_font


static func weight(face: Font, value: int, width: int = 100) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = face
	var ts := TextServerManager.get_primary_interface()
	variation.variation_opentype = {ts.name_to_tag("wght"): value, ts.name_to_tag("wdth"): width}
	variation.spacing_top = 1
	variation.spacing_bottom = 1
	return variation


static func sb(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = 6, pad_h: int = 10, pad_v: int = 4) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	return s


static func plate(col: Dictionary, kind: String, symbol: String = "") -> StyleBox:
	var base: StyleBoxFlat
	match kind:
		"rail", "review":
			base = sb(col["rail"], col["ink"], 2, 4, 16, 6 if kind == "rail" else 10)
		"heading", "flag", "blank", "ledger", "index":
			base = sb(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, 0, 0)
			if kind == "flag":
				base.content_margin_left = 31
			elif kind == "heading":
				base.content_margin_left = 13
			elif kind in ["ledger", "index"]:
				base.content_margin_bottom = 3
		"recipe", "notice":
			var tint: Color = col["hazard"] if kind == "notice" else col["honey"]
			base = sb(col["paper"].lerp(tint, 0.12 if kind == "notice" else 0.28), col["rule"], 1, 3, 12, 7)
			base.content_margin_left = 58
		_:
			base = sb(col["paper"], col["ink"], 2, 5, 15, 11)
	if kind in ["paper", "review", "rail"]:
		base.shadow_color = Color(col["ink"], 0.45)
		base.shadow_size = 2
		base.shadow_offset = Vector2(1, 3)
	return Presswork.new(base, col, kind, symbol)


static func keycap(fill: Color, border: Color, selected: bool = false, pad: int = 10, vertical: int = 4) -> StyleBoxFlat:
	var cap := sb(fill, border, 1, 4, pad, vertical)
	cap.border_width_bottom = 3 if selected else 2
	if selected:
		cap.border_width_left = 3
	return cap


const FS: int = 14


static func theme(col: Dictionary, font: Font) -> Theme:
	var t: Theme = Theme.new()
	t.default_font = font
	t.default_font_size = FS
	var ink: Color = col["ink"]
	t.set_color("font_color", "Label", ink)
	t.set_stylebox("panel", "PanelContainer", plate(col, "paper"))
	t.set_stylebox("normal", "LineEdit", sb(col["card"], ink, 2, 3, 10, 6))
	t.set_stylebox("focus", "LineEdit", sb(col["card"], col["wood_dark"], 3, 3, 10, 6))
	t.set_color("font_color", "LineEdit", ink)
	t.set_color("font_placeholder_color", "LineEdit", col["dim"])
	t.set_color("caret_color", "LineEdit", ink)
	t.set_font_size("font_size", "LineEdit", 17)
	for st: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var c: Color = col["card"]
		if st == "hover": c = col["paper"].darkened(0.06)
		if st == "pressed": c = col["honey"]
		var sb: StyleBoxFlat = keycap(c, ink)
		if st == "disabled":
			sb = sb(col["paper"], Color(ink, 0.3), 2, 6, 10, 4)
		if st == "focus":
			sb = sb(Color(0, 0, 0, 0), col["honey_dark"], 2, 6, 10, 4)
		t.set_stylebox(st, "Button", sb)
	t.set_color("font_color", "Button", ink)
	t.set_color("font_hover_color", "Button", ink)
	t.set_color("font_pressed_color", "Button", ink)
	t.set_color("font_focus_color", "Button", ink)
	t.set_color("font_disabled_color", "Button", ink.lerp(col["dim"], 0.77))
	t.set_stylebox("scroll", "VScrollBar", sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 3, 3, 0))
	t.set_stylebox("grabber", "VScrollBar", sb(col["rule"], Color.TRANSPARENT, 0, 2, 4, 4))
	t.set_stylebox("grabber_highlight", "VScrollBar", sb(col["wood_dark"], Color.TRANSPARENT, 0, 2, 4, 4))
	t.set_constant("separation", "VBoxContainer", 6)
	t.set_constant("separation", "HBoxContainer", 8)
	t.set_constant("h_separation", "HFlowContainer", 6)
	t.set_constant("v_separation", "HFlowContainer", 6)
	return t
