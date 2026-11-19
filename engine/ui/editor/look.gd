extends RefCounted
## E1: the workbench's look: colours from style/style.json (the house palette) and the theme of its controls: cream
## plates with an ink outline, honey for what is chosen and for the one button that spends.

const JobModel = preload("res://ui/job_model.gd")


static func colors() -> Dictionary:
	var style: Variant = JobModel.read_json(ProjectSettings.globalize_path("res://style/style.json"))
	var pal: Dictionary = (style as Dictionary).get("palette", {}) if style is Dictionary else {}
	var ink: String = str(((style as Dictionary).get("ink", {}) as Dictionary).get("ink", "#1a1024")) if style is Dictionary else "#1a1024"
	var pick: Callable = func(key: String, fallback: String) -> Color: return Color(str(pal.get(key, fallback)))
	return {
		"ink": Color(ink),
		"paper": pick.call("curb_white", "#f3e8dc"),
		"paper2": pick.call("line_white", "#efe6dc").darkened(0.04),
		"dim": Color(ink).lerp(pick.call("curb_white", "#f3e8dc"), 0.45),
		"honey": pick.call("yellow", "#f2b230"),
		"honey_dark": pick.call("yellow_dark", "#c98720"),
		"hazard": pick.call("hazard_red", "#d8452e"),
		"green": pick.call("grass_dark", "#4f8a3e"),
		"map": pick.call("grass", "#86b944").lerp(pick.call("curb_white", "#f3e8dc"), 0.35),
		"plot": pick.call("grass_dry", "#bdbb4c").lerp(pick.call("curb_white", "#f3e8dc"), 0.45),
		"road": pick.call("dirt", "#c99568"),
		"dirt": pick.call("sand", "#dcb88a"),
		"crane": pick.call("yellow", "#f2b230"),
		"block": pick.call("ice", "#e2f2ff").lerp(pick.call("steel_light", "#b6b0c8"), 0.3),
		"jacket": pick.call("jacket", "#d24a3a"),
		"skin": pick.call("skin", "#eab294"),
		"shade": pick.call("roof_slate", "#5c4c6c"),
		"ice": pick.call("ice", "#e2f2ff"),
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
		"hazard_light": pick.call("hazard_red", "#d8452e").lerp(pick.call("curb_white", "#f3e8dc"), 0.5),
	}


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


const FS: int = 14


static func theme(col: Dictionary, font: Font) -> Theme:
	var t: Theme = Theme.new()
	t.default_font = font
	t.default_font_size = FS
	var ink: Color = col["ink"]
	t.set_color("font_color", "Label", ink)
	t.set_stylebox("panel", "PanelContainer", sb(col["paper"], ink, 3, 10, 16, 12))
	t.set_stylebox("normal", "LineEdit", sb(Color.WHITE, ink, 2, 6, 10, 6))
	t.set_stylebox("focus", "LineEdit", sb(Color.WHITE, col["honey_dark"], 3, 6, 10, 6))
	t.set_color("font_color", "LineEdit", ink)
	t.set_color("font_placeholder_color", "LineEdit", col["dim"])
	t.set_color("caret_color", "LineEdit", ink)
	t.set_font_size("font_size", "LineEdit", 17)
	for st: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var c: Color = col["paper"]
		if st == "hover": c = col["paper"].darkened(0.06)
		if st == "pressed": c = col["honey"]
		var sb: StyleBoxFlat = sb(c, ink, 2, 6, 10, 4)
		if st == "disabled":
			sb = sb(col["paper"], Color(ink, 0.3), 2, 6, 10, 4)
		if st == "focus":
			sb = sb(Color(0, 0, 0, 0), col["honey_dark"], 2, 6, 10, 4)
		t.set_stylebox(st, "Button", sb)
	t.set_color("font_color", "Button", ink)
	t.set_color("font_hover_color", "Button", ink)
	t.set_color("font_pressed_color", "Button", ink)
	t.set_color("font_focus_color", "Button", ink)
	t.set_color("font_disabled_color", "Button", Color(ink, 0.4))
	t.set_stylebox("scroll", "VScrollBar", sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 3, 3, 0))
	t.set_stylebox("grabber", "VScrollBar", sb(Color(ink, 0.25), Color(0, 0, 0, 0), 0, 3))
	t.set_stylebox("grabber_highlight", "VScrollBar", sb(Color(ink, 0.4), Color(0, 0, 0, 0), 0, 3))
	t.set_constant("separation", "VBoxContainer", 6)
	t.set_constant("separation", "HBoxContainer", 8)
	t.set_constant("h_separation", "HFlowContainer", 6)
	t.set_constant("v_separation", "HFlowContainer", 6)
	return t
