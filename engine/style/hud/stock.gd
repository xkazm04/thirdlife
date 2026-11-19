extends RefCounted
## Spot inks and type for all on-screen instruments. Layout dimensions use a 1280 × 720 design surface.

const THEMES := {
	"signal": {"name": "Signal red", "ink": "#191b32", "paper": "#fff0d8", "accent": "#b63820", "accent_text": "#fff4df", "marker": "#ff8859", "good": "#d6ef8f"},
	"relay": {"name": "Relay blue", "ink": "#122743", "paper": "#e8f1fa", "accent": "#214fab", "accent_text": "#ffffff", "marker": "#94c9ff", "good": "#a7edd9"},
	"night": {"name": "Night meet", "ink": "#192825", "paper": "#f0f8c3", "accent": "#daf270", "accent_text": "#182823", "marker": "#dbf578", "good": "#c2f3de"},
}
const FONT_PATH := "res://style/hud/Archivo.ttf"
static var _face: Font
static var _fonts: Dictionary = {}

static func font(weight: int = 650, width: int = 100) -> Font:
	var key := Vector2i(weight, width)
	if _fonts.has(key):
		return _fonts[key]
	if _face == null:
		if ResourceLoader.exists(FONT_PATH):
			_face = load(FONT_PATH)
		if _face == null:
			var file := FontFile.new()
			_face = file if file.load_dynamic_font(FONT_PATH) == OK else ThemeDB.fallback_font
		if _face is FontFile:
			# Village HUD layers begin hidden. Keep the glyph atlas sharp when a scaled layer comes on stage.
			(_face as FontFile).oversampling = 2.0
	var f := FontVariation.new()
	f.base_font = _face
	var server := TextServerManager.get_primary_interface()
	f.variation_opentype = {server.name_to_tag("wght"): weight, server.name_to_tag("wdth"): width}
	f.opentype_features = {server.name_to_tag("tnum"): 1}
	_fonts[key] = f
	return f

static func colors(theme_id: String) -> Dictionary:
	var result := {}
	for key: String in THEMES[theme_id]:
		if key != "name":
			result[key] = Color(THEMES[theme_id][key])
	return result
