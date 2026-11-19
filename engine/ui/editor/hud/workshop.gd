extends Control
## Player-facing proof desk, opened from the village or the New game workbench.
const Model = preload("res://ui/editor/hud/model.gd")
const Proof = preload("res://ui/editor/hud/proof.gd")
const Layout = preload("res://style/hud/layout.gd")
const Stock = preload("res://style/hud/stock.gd")
const Look = preload("res://ui/editor/look.gd")

signal closed
const INK := Color("#1b1d32")
const DESK := Color("#e6dece")
const PAPER := Color("#faf5e9")
const RULE := Color("#b7b1a5")
const DIM := Color("#515360")
const RED := Color("#a63424")
const HONEY := Color("#f4c664")

var model := Model.new()
var games: Array = []
var read_only := false
var selected := ""
var _game_index := -1
var _surface := Control.new()
var _game := OptionButton.new()
var _save := Button.new()
var _play := Button.new()
var _message := Label.new()
var _proof := Proof.new()
var _roster := VBoxContainer.new()
var _anchors := {}
var _choices := {}
var _sizes := {}
var _themes := {}
var _phases := {}
var _show := {}
var _position_label: Label
var _confirm := ConfirmationDialog.new()
var _after_discard: Callable

func setup(available: Array, dry: bool) -> void:
	games = available
	read_only = dry

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = DESK
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_surface)
	_surface.oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	_surface.theme = Look.theme(Look.colors(), Stock.font(540))
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 0)
	_surface.add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_header(layout)
	var body := MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "top", "right", "bottom"]:
		body.add_theme_constant_override("margin_" + side, 20 if side in ["left", "right"] else 16)
	layout.add_child(body)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	body.add_child(columns)
	_preview_column(columns)
	_inspector(columns)
	add_child(_confirm)
	_confirm.title = "Discard layout changes?"
	_confirm.dialog_text = "Your changes have not been saved with the game."
	_confirm.ok_button_text = "Discard changes"
	_confirm.confirmed.connect(func() -> void: _after_discard.call())
	resized.connect(_fit)
	_fit()
	_open(0)

func _fit() -> void:
	var factor := maxf(0.1, minf(size.x / 1280.0, size.y / 720.0))
	_surface.size = size / factor
	_surface.scale = Vector2.ONE * factor

func _text(value: String, px: int, color: Color = INK, weight: int = 600, narrow: int = 100) -> Label:
	var l := Label.new()
	l.text = value
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", Stock.font(weight, narrow))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	return l

func _panel(parent: Control, color: Color, xpad: int, ypad: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Look.sb(color, RULE, 1, 0, xpad, ypad))
	parent.add_child(p)
	return p

func _button(text_: String, action: Callable, hint := "") -> Button:
	var b := Button.new()
	b.text = text_
	b.tooltip_text = hint
	b.add_theme_font_override("font", Stock.font(690))
	b.pressed.connect(action)
	_style(b, false)
	return b

func _style(b: Button, active: bool, color: Color = PAPER) -> void:
	var bg := INK if active else color
	var fg := PAPER if active else INK
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var fill := bg
		if state == "hover":
			fill = bg.lerp(HONEY, 0.17)
		b.add_theme_stylebox_override(state, Look.sb(fill, INK if active else RULE, 1, 2, 10, 5))
		b.add_theme_color_override("font_color" if state == "normal" else "font_" + state + "_color", fg)
	b.add_theme_color_override("font_focus_color", fg)
	var focus := Look.sb(Color.TRANSPARENT, HONEY.darkened(0.18), 2, 2, 0, 0)
	b.add_theme_stylebox_override("focus", focus)

func _spacer(parent: Control) -> void:
	var s := Control.new()
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(s)

func _header(parent: Control) -> void:
	var head := _panel(parent, INK, 20, 12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	head.add_child(row)
	var back := _button("‹", request_close, "Back to the creator")
	back.name = "Back"
	back.custom_minimum_size = Vector2(38, 34)
	back.add_theme_font_size_override("font_size", 23)
	row.add_child(back)
	row.add_child(_text("HUD workshop", 31, PAPER, 870, 85))
	_spacer(row)
	row.add_child(_text("Game", 13, PAPER))
	_game.name = "Game"
	for item: Dictionary in games:
		_game.add_item(item.title)
	_game.item_selected.connect(func(index: int) -> void:
		_game.select(_game_index)
		_leave(func() -> void: _open(index)))
	_game.custom_minimum_size.x = 207
	_style(_game, false)
	row.add_child(_game)
	_save.name = "SaveLayout"
	_save.text = "Save layout"
	_save.add_theme_font_override("font", Stock.font(780))
	_style(_save, false, HONEY)
	_save.pressed.connect(_save_layout)
	row.add_child(_save)
	_play.name = "PlayGame"
	_play.text = "Play game"
	_play.add_theme_font_override("font", Stock.font(780))
	_style(_play, false, HONEY)
	_play.pressed.connect(_play_game)
	row.add_child(_play)

func _preview_column(parent: Control) -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	parent.add_child(column)
	var print_frame := _panel(column, PAPER, 12, 10)
	print_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	print_frame.add_child(body)
	var bar := HBoxContainer.new()
	body.add_child(bar)
	bar.add_child(_text("Live preview", 21, INK, 810, 90))
	_spacer(bar)
	for phase: String in ["run", "finish"]:
		var b := _button("During run" if phase == "run" else "At finish", func() -> void: _change_phase(phase))
		b.name = "Phase_" + phase
		bar.add_child(b)
		_phases[phase] = b
	var surround := _panel(body, INK, 1, 1)
	surround.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var aspect := AspectRatioContainer.new()
	aspect.ratio = 16.0 / 9.0
	surround.add_child(aspect)
	_proof.name = "Preview"
	aspect.add_child(_proof)
	_proof.picked.connect(_select)
	_proof.placed.connect(func(id: String, anchor: String) -> void:
		_select(id)
		_edit("anchor", anchor))
	body.add_child(_text("Drag a widget into position, or choose a spot in the grid.", 13, DIM, 530))
	var stocks := _panel(column, PAPER, 13, 11)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	stocks.add_child(row)
	row.add_child(_text("Theme", 19, INK, 800, 90))
	for id: String in Stock.THEMES:
		var b := _button(Stock.THEMES[id].name, func() -> void:
			model.profile["theme"] = id
			_changed())
		b.name = "Theme_" + id
		b.custom_minimum_size = Vector2(142, 35)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var swatch := Stock.colors(id)
		b.draw.connect(func() -> void:
			var x := 9.0
			for color: Color in [swatch.ink, swatch.paper, swatch.accent]:
				b.draw_rect(Rect2(x, (b.size.y - 20) / 2, 11, 20), color)
				x += 11)
		row.add_child(b)
		_themes[id] = b

func _inspector(parent: Control) -> void:
	var right := _panel(parent, PAPER, 15, 14)
	right.custom_minimum_size.x = 315
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	right.add_child(v)
	var title := HBoxContainer.new()
	v.add_child(title)
	title.add_child(_text("Widgets", 26, INK, 850, 86))
	_spacer(title)
	title.add_child(_text("Visible", 12, DIM))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	_roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster.add_theme_constant_override("separation", 3)
	scroll.add_child(_roster)
	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 1
	rule.color = RULE
	v.add_child(rule)
	_position_label = _text("Position", 16, INK, 740)
	v.add_child(_position_label)
	var map := GridContainer.new()
	map.name = "Position"
	map.columns = 3
	map.add_theme_constant_override("h_separation", 2)
	map.add_theme_constant_override("v_separation", 2)
	v.add_child(map)
	var arrows := ["↖", "↑", "↗", "←", "•", "→", "↙", "↓", "↘"]
	for anchor: String in Layout.ANCHORS:
		var where := anchor.replace("_", " ").capitalize()
		var b := _button(arrows[Layout.ANCHORS.find(anchor)], func() -> void: _edit("anchor", anchor), where)
		b.name = "Anchor_" + anchor
		b.accessibility_name = where
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		map.add_child(b)
		_anchors[anchor] = b
	v.add_child(_text("Size", 16, INK, 740))
	var sizes := HBoxContainer.new()
	v.add_child(sizes)
	for id: String in Layout.SIZES:
		var b := _button(id.capitalize(), func() -> void: _edit("size", id))
		b.name = "Size_" + id
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sizes.add_child(b)
		_sizes[id] = b
	_message.add_theme_font_override("font", Stock.font(620))
	_message.add_theme_font_size_override("font_size", 13)
	_message.add_theme_color_override("font_color", DIM)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.y = 32
	v.add_child(_message)

func _open(index: int) -> void:
	if index < 0 or index >= games.size():
		_lock("No games with editable widgets were found.")
		return
	_game_index = index
	_game.select(index)
	model = Model.new()
	var item: Dictionary = games[index]
	var error := model.open_game(item.dir)
	if error != "":
		_lock(error)
		return
	_proof.populate(model.catalog, model.profile, item.id)
	_roster_rows()
	selected = model.catalog[0].id
	for spec: Dictionary in model.catalog:
		if spec.form == "cue":
			selected = spec.id
			break
	_message.text = "Preview only" if read_only else "Saved with this game"
	_refresh()

func _lock(error: String) -> void:
	_message.text = error
	_message.add_theme_color_override("font_color", RED)
	_save.disabled = true
	_play.disabled = true
	for controls: Dictionary in [_choices, _show, _anchors, _sizes, _themes, _phases]:
		for b: Button in controls.values():
			b.disabled = true
	_proof.visible = false

func _roster_rows() -> void:
	for old: Node in _roster.get_children():
		_roster.remove_child(old)
		old.queue_free()
	_choices.clear()
	_show.clear()
	for spec: Dictionary in model.catalog:
		var id: String = spec.id
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		_roster.add_child(row)
		var b := _button(spec.title, func() -> void: _select(id))
		b.name = "Widget_" + id
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 34
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		_choices[id] = b
		var eye := _button("", func() -> void:
			_select(id)
			_edit("visible", not bool(_proof.sheet.settings[id].visible)))
		eye.name = "Visible_" + id
		eye.custom_minimum_size.x = 36
		eye.draw.connect(func() -> void:
			var center := eye.size * 0.5
			var on: bool = _proof.sheet.settings[id].visible
			var points := PackedVector2Array([center + Vector2(-8, 0), center + Vector2(-4, -4),
				center + Vector2(0, -5), center + Vector2(4, -4), center + Vector2(8, 0),
				center + Vector2(4, 4), center + Vector2(0, 5), center + Vector2(-4, 4), center + Vector2(-8, 0)])
			eye.draw_polyline(points, DIM, 1.4, true)
			if on:
				eye.draw_circle(center, 2.5, INK, true, -1, true)
			else:
				eye.draw_line(center + Vector2(-7, 7), center + Vector2(7, -7), RED, 2, true))
		row.add_child(eye)
		_show[id] = eye

func _select(id: String) -> void:
	selected = id
	for spec: Dictionary in model.catalog:
		if spec.id == id and spec.get("phase", "run") != "both":
			_proof.show_phase(spec.get("phase", "run"))
			break
	_refresh()

func _change_phase(phase: String) -> void:
	_proof.show_phase(phase)
	for spec: Dictionary in model.catalog:
		if spec.get("phase", "run") == phase:
			selected = spec.id
			break
	_refresh()

func _edit(key: String, value: Variant) -> void:
	model.set_option(selected, key, value)
	_changed()

func _changed() -> void:
	_proof.sheet.apply(model.profile)
	_message.text = "Preview only" if read_only else ("Unsaved changes" if model.dirty() else "Saved with this game")
	_refresh()

func _refresh() -> void:
	var settings: Dictionary = _proof.sheet.settings[selected]
	_proof.visible = true
	_proof.select(selected)
	_position_label.text = "%s  ·  %s" % [_choices[selected].text, str(settings.anchor).replace("_", " ").capitalize()]
	_message.add_theme_color_override("font_color", DIM)
	for id: String in _choices:
		_style(_choices[id], id == selected)
		var eye: Button = _show[id]
		var on: bool = _proof.sheet.settings[id].visible
		eye.tooltip_text = ("Hide " if on else "Show ") + _choices[id].text
		eye.accessibility_name = eye.tooltip_text
		eye.queue_redraw()
	for id: String in _sizes:
		_sizes[id].disabled = false
		_style(_sizes[id], settings.size == id)
	for id: String in _anchors:
		_anchors[id].disabled = false
		_style(_anchors[id], settings.anchor == id)
	for id: String in _phases:
		_phases[id].disabled = false
		_style(_phases[id], id == _proof.sheet.phase)
	for id: String in _themes:
		_themes[id].disabled = false
		_style(_themes[id], id == model.profile.get("theme", "signal"))
	_save.disabled = read_only or not model.dirty()
	_style(_save, false, PAPER if not _save.disabled else Color("#d2cdbf"))
	_play.disabled = read_only
	_play.text = "Save & play" if model.dirty() else "Play game"
	_style(_play, false, HONEY if not read_only else Color("#d2cdbf"))

func _save_layout() -> void:
	if read_only or not model.dirty():
		return
	var error := model.save()
	_refresh()
	_message.text = error if error != "" else "Layout saved with this game"
	_message.add_theme_color_override("font_color", RED if error != "" else DIM)

func _play_game() -> void:
	if read_only:
		return
	if model.dirty():
		_save_layout()
		if model.dirty():
			return
	var window := get_window()
	var args := PackedStringArray(["--windowed", "--resolution", "%dx%d" % [window.size.x, window.size.y],
		"--position", "%d,%d" % [window.position.x, window.position.y],
		"--path", ProjectSettings.globalize_path("res://"), "res://kernel/host/host.tscn",
		"--", "worker", "--mode=play", "--pack=" + model.game_dir])
	var pid := OS.create_process(OS.get_executable_path(), args)
	_message.text = "Game opened in a new window" if pid > 0 else "Could not start the game"
	_message.add_theme_color_override("font_color", DIM if pid > 0 else RED)

func _leave(action: Callable) -> void:
	if model.dirty() and not read_only:
		_after_discard = action
		_confirm.popup_centered()
	else:
		action.call()

func request_close() -> void:
	_leave(func() -> void: closed.emit())
