extends CanvasLayer
## M6 lane T (27 Nov 2026): the Rules tool's side card, at the right edge while the tool is current. It reads as text
## what the Home's rules do (the readable form Hypixel Housing's players had to invent: docs/research/sandbox/
## THESIS.md): the selected zone's name and kind, each of its rules as a sentence (rules_layer.gd `describe`) and its
## knobs with their keys; with nothing selected, every rule of the Home (the first LINES) and how many zones and rules
## it holds. English, inline (repo convention). Kernel UI: no material; every Control ignores the mouse.

const WIDTH := 430.0
const LINES := 12

var panel: PanelContainer
var title: Label
var body: Label
var keys: Label
var _last := ""


func _init() -> void:
	name = "RulesCard"
	layer = 101
	panel = PanelContainer.new()
	panel.name = "Card"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_right = -16
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.07, 0.1, 0.78)
	s.border_color = TLStyle.color("cyan") if TLStyle.has_key("cyan") else Color(0.2, 0.9, 1.0)
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", s)
	add_child(panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	title = _label(20, Color(1, 0.96, 0.7))
	box.add_child(title)
	body = _label(16, Color(1, 1, 1, 0.95))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(WIDTH - 24, 0)
	box.add_child(body)
	keys = _label(15, Color(0.75, 0.95, 1.0, 0.95))
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.custom_minimum_size = Vector2(WIDTH - 24, 0)
	box.add_child(keys)
	panel.visible = false


func _label(px: int, c: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	return l


## Shows `c` ({"title", "lines": [String], "keys": String}) or hides the card (`c` empty).
func show_card(c: Dictionary) -> void:
	var k := str(c)
	if k == _last:
		return
	_last = k
	panel.visible = not c.is_empty()
	if c.is_empty():
		return
	title.text = str(c.get("title", ""))
	body.text = "\n".join((c.get("lines", []) as Array).map(func(l: String) -> String: return "- " + l))
	body.visible = not (c.get("lines", []) as Array).is_empty()
	keys.text = str(c.get("keys", ""))
	keys.visible = keys.text != ""


## The card's text for a person reading it (the case reads it back).
func text() -> String:
	return "%s\n%s\n%s" % [title.text, body.text, keys.text] if panel.visible else ""
