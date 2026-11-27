extends CanvasLayer
## WP2 + SEAM (spark world-sandbox): build mode's hotbar, bottom centre. While walking nothing shows (boot.gd's key line
## names "B  build"); while building boot hides its key line and this shows, top to bottom: the reason a cell is refused
## (red) and the where line (F2: both over the tabs, so a refusal never moves them), the tool strip (every
## tool's title, the current one lit; T and Shift+T switch), the current tool's slots (its `slots()`: key and label,
## the selected one lit; the blocks tool's are the 8 shapes), the swatch and info line (its `status()`) with the save
## state, and the tool's keys (its `hint()`). English, inline (repo convention).
## Nothing here knows a tool: build_mode.gd hands `refresh` what the tool says (BUILD.md "Tools"), so a lane adds a
## tool without editing this file. Every Control ignores the mouse: clicks belong to build mode.
## `refresh(state)` redraws only when something shown changed.
## F2 (27 Nov 2026 day, playtest #4): the bar answers a click. Build mode asks `at(pixel)` before a tool sees a press:
## a tool tab picks that tool, a slot presses that slot's key for the current tool, a gap between tabs or slots takes
## the click and does nothing, so a click on the bar never builds behind it (its text lines are not buttons:
## a click there goes to the world). The tab or slot under the pointer is lit with a hover border (the state's "hover").
## Under the red reason the where line (amber, buildable.gd `line`): the reason as a sentence and the way to buildable
## ground, or that the cursor is out of reach.

const LIFT := 40                        # px from the bottom of the window to the hotbar's bottom (boot's key line is hidden)

var box: VBoxContainer
var strip: HBoxContainer
var row: HBoxContainer
var tools: Array = []                   # [PanelContainer, Label] per tool in the strip
var slots: Array = []                   # [PanelContainer, Label] per slot of the current tool
var swatch: ColorRect
var info: Label
var reason: Label
var where: Label
var saved: Label
var help: Label
var line: HBoxContainer
var _last := {}
var _lit: StyleBoxFlat
var _dim: StyleBoxFlat
var _hover: StyleBoxFlat
var _lit_hover: StyleBoxFlat
const PAD := 4.0                        # px round the bar's parts that still count as the bar


func _init() -> void:
	name = "BuildHotbar"
	layer = 101
	_dim = _style(Color(0.06, 0.07, 0.1, 0.72), Color(1, 1, 1, 0.18))
	_lit = _style(Color(0.1, 0.22, 0.28, 0.9), TLStyle.color("cyan") if TLStyle.has_key("cyan") else Color(0.2, 0.9, 1.0))
	_hover = _style(Color(0.12, 0.14, 0.2, 0.86), Color(1, 1, 1, 0.75))
	_lit_hover = _style(Color(0.14, 0.3, 0.38, 0.95), Color(1, 1, 1, 0.95))
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
	# F2: the reason and the where line stand over the tabs, so a refusal coming and going never moves the tabs a
	# person is about to click (the box grows upward from its bottom)
	reason = _label(19, Color(1.0, 0.45, 0.4, 1.0))
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(reason)
	where = _label(18, Color(1.0, 0.82, 0.45, 1.0))
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(where)
	strip = _row(4)
	row = _row(6)
	line = _row(10)
	swatch = ColorRect.new()
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.custom_minimum_size = Vector2(26, 26)
	line.add_child(swatch)
	info = _label(19, Color(1, 1, 1, 0.97))
	line.add_child(info)
	saved = _label(17, Color(0.8, 0.95, 0.85, 0.95))
	line.add_child(saved)
	help = _label(15, Color(1, 1, 1, 0.8))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(help)
	box.visible = false


func _row(sep: int) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.add_theme_constant_override("separation", sep)
	box.add_child(r)
	return r


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


## `n` panels in `into` (`list` holds [PanelContainer, Label] pairs), made or freed to fit.
func _fit(into: HBoxContainer, list: Array, n: int, px: int, width: float) -> void:
	while list.size() > n:
		var gone: Array = list.pop_back()
		(gone[0] as Node).queue_free()
		into.remove_child(gone[0])
	while list.size() < n:
		var p := PanelContainer.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.custom_minimum_size = Vector2(width, 0)
		p.add_theme_stylebox_override("panel", _dim)
		var l := _label(px, Color(1, 1, 1, 0.95))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
		into.add_child(p)
		list.append([p, l])


## What build mode `m` (build_mode.gd) shows now: its current tool's slots, status and hint, the tool strip, the save
## state. Only the tool interface is read (BUILD.md "Tools").
static func state_of(m: Node) -> Dictionary:
	var s := {"building": bool(m.get("active"))}
	if not s.building:
		return s
	var t: RefCounted = m.call("tool")
	var st: Dictionary = t.status()
	s.tools = (m.get("tools") as Array).map(func(x: RefCounted) -> String: return str(x.get("title")))
	s.tool = int(m.get("tool_index"))
	s.slots = t.slots()
	if st.has("swatch"):
		s.swatch = st.swatch
	s.info = str(st.get("info", ""))
	if bool(st.get("dim", false)):
		s.dim = true
	s.reason = str(st.get("reason", ""))
	s.where = str(m.get("where_line")) if m.get("where_line") != null else ""
	var hv: Variant = m.get("bar_hover")
	if hv is Dictionary and not (hv as Dictionary).is_empty():
		s.hover = (hv as Dictionary).duplicate()
	s.help = t.hint()
	var err := str(m.get("save_error"))
	if not err.is_empty():
		s.save = "save failed: " + err
	elif str(m.get("dir")).is_empty():
		s.save = "not saved (no Home file here)"
	else:
		s.save = "unsaved" if bool((m.get("build") as RefCounted).get("dirty")) else "saved"
	return s


## `s`: "building" (the hotbar shows), "tools" (titles), "tool" (the current one's index), "slots" ([{"key", "label",
## "lit"}]), "swatch" (a Color; absent: none), "info", "dim" (the info line greyed: a tool not built yet), "save",
## "reason" ("" none), "where" (the where line, "" none), "hover" ({"tool": i} or {"slot": i}: lit as hovered), "help".
func refresh(s: Dictionary) -> void:
	if s == _last:
		return
	_last = s.duplicate(true)
	box.visible = bool(s.get("building", false))
	if not box.visible:
		return
	var hv: Dictionary = s.get("hover", {})
	var names: Array = s.get("tools", [])
	_fit(strip, tools, names.size(), 14, 0.0)
	for i: int in names.size():
		(tools[i][1] as Label).text = str(names[i])
		(tools[i][0] as PanelContainer).add_theme_stylebox_override("panel", _look(i == int(s.get("tool", 0)), int(hv.get("tool", -1)) == i))
	strip.visible = names.size() > 1
	var list: Array = s.get("slots", [])
	_fit(row, slots, list.size(), 16, 84.0)
	for i: int in list.size():
		var slot: Dictionary = list[i]
		(slots[i][1] as Label).text = ("%s\n%s" % [slot.key, slot.label]) if str(slot.get("key", "")) != "" else str(slot.label)
		(slots[i][0] as PanelContainer).add_theme_stylebox_override("panel", _look(bool(slot.get("lit", false)), int(hv.get("slot", -1)) == i))
	row.visible = not list.is_empty()
	where.text = str(s.get("where", ""))
	where.visible = where.text != ""
	swatch.visible = s.has("swatch")
	if s.has("swatch"):
		swatch.color = s.swatch
	info.text = str(s.get("info", ""))
	info.modulate = Color(1, 1, 1, 0.55) if bool(s.get("dim", false)) else Color.WHITE
	saved.text = str(s.get("save", ""))
	reason.text = str(s.get("reason", ""))
	help.text = str(s.get("help", ""))


func _look(lit: bool, hovered: bool) -> StyleBoxFlat:
	if hovered:
		return _lit_hover if lit else _hover
	return _lit if lit else _dim


## What of the bar is at pixel `px` (the viewport's coordinates, as the mouse's): {"tool": i} a tool tab, {"slot": i,
## "key": the slot's key} a slot, {"bar": true} the gaps between the tabs or the slots (`parts`, PAD round each),
## {} not the bar (its text lines, or the bar is not shown).
func at(px: Vector2) -> Dictionary:
	if box == null or not box.visible or px.x < 0.0:
		return {}
	if strip.visible:
		for i: int in tools.size():
			if (tools[i][0] as Control).get_global_rect().grow(PAD * 0.5).has_point(px):
				return {"tool": i}
	if row.visible:
		var list: Array = _last.get("slots", [])
		for i: int in slots.size():
			if (slots[i][0] as Control).get_global_rect().grow(PAD * 0.5).has_point(px):
				return {"slot": i, "key": str((list[i] as Dictionary).get("key", "")) if i < list.size() else ""}
	for r: Rect2 in parts():
		if r.has_point(px):
			return {"bar": true}
	return {}


## The rects (pixels, PAD round each) of the bar's buttons: the tool strip and the slot row, the gaps between their
## panels included. Its text lines (reason, where, info, keys) are not buttons: a click there goes to the
## world (they lie over the ground a person aims at; the keys line is as wide as most of the window).
func parts() -> Array:
	var out := []
	for r: HBoxContainer in [strip, row]:
		if r.visible and r.get_child_count() > 0:
			out.append(_children_rect(r).grow(PAD))
	return out


static func _children_rect(c: Control) -> Rect2:
	var r := Rect2()
	var first := true
	for ch: Node in c.get_children():
		var k := ch as Control
		if k == null or not k.visible:
			continue
		var g := k.get_global_rect()
		r = g if first else r.merge(g)
		first = false
	return r
