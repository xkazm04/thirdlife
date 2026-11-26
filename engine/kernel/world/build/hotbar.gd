extends CanvasLayer
## WP2 (spark world-sandbox, M1): build mode's hotbar, bottom centre. While walking nothing shows (boot.gd's key line
## names "B  build"); while building boot hides its key line and this shows: the 8 shape slots with their keys and names (the selected one lit), the material's swatch and name, rot
## and flip, the save state, the reason a cell is refused (red), and the keys. English, inline (repo convention).
## Every Control ignores the mouse: clicks belong to build mode (build_mode.gd polls the buttons).
## `refresh(state)` redraws only when something shown changed.

const Blocks := preload("res://kernel/world/build/blocks.gd")
const KEY_HELP := "LMB place (drag: a line)   RMB remove   wheel or 1-8 shape   Tab / Shift+Tab material   R turn   F2 flip   Ctrl+Z undo   Ctrl+Y redo   hold MMB or Alt look   B or Esc leave"
const LIFT := 40                        # px from the bottom of the window to the hotbar's bottom (boot's key line is hidden)

var box: VBoxContainer
var slots: Array = []                   # [PanelContainer, Label] per shape id 1..8
var swatch: ColorRect
var info: Label
var reason: Label
var saved: Label
var help: Label
var _last := {}
var _lit: StyleBoxFlat
var _dim: StyleBoxFlat


func _init() -> void:
	name = "BuildHotbar"
	layer = 101
	_dim = _style(Color(0.06, 0.07, 0.1, 0.72), Color(1, 1, 1, 0.18))
	_lit = _style(Color(0.1, 0.22, 0.28, 0.9), TLStyle.color("cyan") if TLStyle.has_key("cyan") else Color(0.2, 0.9, 1.0))
	box = VBoxContainer.new()
	box.name = "Hotbar"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 4)
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_bottom = -LIFT
	add_child(box)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for id: int in range(1, 9):
		var p := PanelContainer.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.custom_minimum_size = Vector2(84, 0)
		p.add_theme_stylebox_override("panel", _dim)
		var l := _label(16, Color(1, 1, 1, 0.95))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.text = "%d\n%s" % [id, Blocks.SHAPE_NAMES[id]]
		p.add_child(l)
		row.add_child(p)
		slots.append([p, l])
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 10)
	box.add_child(line)
	swatch = ColorRect.new()
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.custom_minimum_size = Vector2(26, 26)
	line.add_child(swatch)
	info = _label(19, Color(1, 1, 1, 0.97))
	line.add_child(info)
	saved = _label(17, Color(0.8, 0.95, 0.85, 0.95))
	line.add_child(saved)
	reason = _label(19, Color(1.0, 0.45, 0.4, 1.0))
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(reason)
	help = _label(15, Color(1, 1, 1, 0.8))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.text = KEY_HELP
	box.add_child(help)
	box.visible = false


func _label(px: int, c: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	return l


static func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(5)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s


## `s`: "building" (the hotbar shows), "shape", "mat", "rot", "flip" (bool or
## absent: the shape takes none), "turns" (the shape shows its rot), "reason" ("" none), "save" (text).
func refresh(s: Dictionary) -> void:
	if s == _last:
		return
	_last = s.duplicate()
	box.visible = bool(s.get("building", false))
	if not box.visible:
		return
	for i: int in slots.size():
		(slots[i][0] as PanelContainer).add_theme_stylebox_override("panel", _lit if i + 1 == int(s.shape) else _dim)
	var mat: int = int(s.mat)
	swatch.color = TLStyle.color(Blocks.mat_key(mat))
	var parts := PackedStringArray([Blocks.mat_key(mat).replace("_", " ")])
	if bool(s.get("turns", false)):
		parts.append("rot %d" % int(s.rot))
	if s.has("flip"):
		parts.append("flipped" if bool(s.flip) else "upright")
	info.text = "   ".join(parts)
	saved.text = str(s.get("save", ""))
	reason.text = str(s.get("reason", ""))
