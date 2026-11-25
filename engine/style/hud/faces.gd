extends RefCounted
## K5 (hokej screen): the faces of a sports HUD, read by TLHudLayer. Roboto as Unreal 5.9 ships it (Engine/Content/Slate/Fonts,
## Apache License 2.0, ROBOTO_License.txt beside it): the four faces thirdjam's HUD draws in (FJamUiStyle::Font over
## FCoreStyle's Roboto; FJamMenuLook::Font over device B's F_Hokej_Display, whose Bold face is Roboto Bold Condensed).
## Face names: regular, bold, bold_condensed, black. Tracking (1/1000 em, Unreal's LetterSpacing) becomes glyph spacing.

const FILES := {
	"regular": "res://style/hud/Roboto-Regular.ttf",
	"bold": "res://style/hud/Roboto-Bold.ttf",
	"bold_condensed": "res://style/hud/Roboto-BoldCondensed.ttf",
	"black": "res://style/hud/Roboto-Black.ttf",
}
static var _base: Dictionary = {}
static var _var: Dictionary = {}


static func base(face: String) -> Font:
	if _base.has(face):
		return _base[face]
	var path: String = FILES.get(face, FILES["bold"])
	var f: Font = null
	if ResourceLoader.exists(path):
		f = load(path)
	if f == null:
		var file := FontFile.new()
		f = file if file.load_dynamic_font(path) == OK else ThemeDB.fallback_font
	if f is FontFile:
		(f as FontFile).oversampling = 2.0
	_base[face] = f
	return f


## The face with `spacing_px` added after every glyph (Unreal's tracking at the drawn size).
static func font(face: String, spacing_px: int = 0) -> Font:
	if spacing_px == 0:
		return base(face)
	var key := "%s|%d" % [face, spacing_px]
	if _var.has(key):
		return _var[key]
	var v := FontVariation.new()
	v.base_font = base(face)
	v.spacing_glyph = spacing_px
	_var[key] = v
	return v
