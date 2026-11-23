class_name TLHud
extends CanvasLayer
## HUD widgets: score, clock, speed and free labels, bound to live sources and refreshed every frame.
## Split Ticket house instruments and backward-compatible labels. Capability: `ui`.
##
##   var hud := TLHud.create()
##   ctx.root.add_child(hud)
##   hud.add_score(rules, "home", &"top_left")
##   hud.add_clock(rules, &"top")
##   hud.add_speed(car.speed_kmh, "km/h", &"bottom_right")
##   hud.add_label(&"hint", "Space: nitro", &"bottom")
##
## Anchors: top_left, top, top_right, left, center, right, bottom_left, bottom, bottom_right.

const ANCHORS: Dictionary = {
	&"top_left": [Control.PRESET_TOP_LEFT, Vector2(24, 16)], &"top": [Control.PRESET_CENTER_TOP, Vector2(0, 16)],
	&"top_right": [Control.PRESET_TOP_RIGHT, Vector2(-24, 16)], &"left": [Control.PRESET_CENTER_LEFT, Vector2(24, 0)],
	&"center": [Control.PRESET_CENTER, Vector2(0, 0)], &"right": [Control.PRESET_CENTER_RIGHT, Vector2(-24, 0)],
	&"bottom_left": [Control.PRESET_BOTTOM_LEFT, Vector2(24, -16)], &"bottom": [Control.PRESET_CENTER_BOTTOM, Vector2(0, -16)],
	&"bottom_right": [Control.PRESET_BOTTOM_RIGHT, Vector2(-24, -16)],
}

const _STOCK_PATH := "res://style/hud/stock.gd"
const _LAYOUT_PATH := "res://style/hud/layout.gd"
const _SHEET_PATH := "res://style/hud/sheet.gd"

## Kept for packs written against API 1.5.
const INK: Color = Color(0.05, 0.05, 0.08)
const PLATE_ALPHA: float = 0.62
const PLATE_MARGIN: Vector2 = Vector2(18, 8)

var font_size: int = 36
var _widgets: Dictionary = {}      # id -> {label: Label, source: Callable or null}
var _tags: Dictionary = {}         # id -> {node, offset}, outside the anchor stacks
var _cameras: TLCameras
var _sheet                  # The optional style module owns this Control.
var _stock: GDScript
var _layout: GDScript
var _layout_dirty := true
var _inks := {"ink": INK, "paper": Color.WHITE, "marker": Color.WHITE}
var _village_hud := false


func _init() -> void:
	if ResourceLoader.exists(_STOCK_PATH):
		_stock = load(_STOCK_PATH)
		_inks = _stock.colors("signal")


static func create() -> TLHud:
	TLContext.require("ui", "TLHud")
	var h: TLHud = TLHud.new()
	h.name = "TLHud"
	if TLContext.current != null:
		h._cameras = TLContext.current.cameras
		TLContext.current.huds.append(h)
		h.visible = TLContext.current.on_stage      # N7 (N5b patch 2): in a world only the stage pack's HUD is shown
		h._village_hud = not TLContext.current.instance.is_empty()
	return h


## Hides every HUD of one pack (the kernel does this for captures); without an argument, of the pack being called.
static func hide_all(of_pack: TLContext = null) -> void:
	var ctx: TLContext = of_pack if of_pack != null else TLContext.current
	if ctx == null:
		return
	for h: Variant in ctx.huds:
		if is_instance_valid(h):
			(h as TLHud).visible = false


func _ready() -> void:
	get_viewport().size_changed.connect(_resized)
	_resized()


func _resized() -> void:
	_layout_dirty = true
	if _sheet != null:
		var extent := get_viewport().get_visible_rect().size
		_sheet.vertical_clearance = _vertical_clearance(extent)
		_sheet.size = extent


# The village owns the build tag at the top and its leave-game hint at the bottom.
func _vertical_clearance(extent: Vector2) -> Vector2:
	if not _village_hud:
		return Vector2.ZERO
	return Vector2(minf(36, extent.y / 4), minf(64, extent.y / 4))


## Install the pack's instrument catalogue and the player's saved layout. An invalid file changes nothing.
func configure_widgets(catalog: Variant, layout: Variant) -> bool:
	if not ResourceLoader.exists(_LAYOUT_PATH) or not ResourceLoader.exists(_SHEET_PATH):
		push_warning("TLHud.configure_widgets: install the HUD style module for editable instruments")
		return false
	_layout = load(_LAYOUT_PATH)
	var error: String = _layout.check_catalog(catalog)
	if error.is_empty():
		error = _layout.check_profile(layout, catalog)
	if not error.is_empty():
		push_error("TLHud: " + error)
		return false
	if _sheet == null:
		_sheet = (load(_SHEET_PATH) as GDScript).new()
		add_child(_sheet)
	_sheet.install(catalog, layout)
	_inks = _stock.colors(layout.get("theme", "signal"))
	for id: StringName in _widgets:
		var w: Dictionary = _widgets[id]
		var label: Label = w.label
		if not w.custom_color:
			label.add_theme_color_override("font_color", _inks.paper)
		label.add_theme_color_override("font_outline_color", _inks.ink)
		if w.plate:
			set_plate(id)
	if is_inside_tree():
		_resized()
	return true


## Supply the live values for one declared instrument. The empty dictionary clears it.
func set_readout(id: StringName, reading: Dictionary) -> void:
	if _sheet == null or not _sheet.cards.has(id):
		push_error("TLHud.set_readout: unknown widget '%s'" % id)
		return
	var card = _sheet.cards[id]
	if card.reading == reading:
		return
	if not reading.is_empty():
		var error: String = _layout.check_reading(card.form, reading)
		if not error.is_empty():
			push_error("TLHud.set_readout: " + error)
			return
	_sheet.set_reading(id, reading)


## Switch between the in-run instruments and the finish board.
func set_phase(phase: StringName) -> void:
	if phase not in [&"run", &"finish"]:
		push_error("TLHud.set_phase: unknown phase '%s'" % phase)
		return
	if _sheet != null:
		_sheet.set_phase(phase)


func _make(id: StringName, anchor: StringName, source: Callable) -> Label:
	if not ANCHORS.has(anchor):
		push_error("TLHud: unknown anchor '%s'" % anchor)
		anchor = &"top_left"
	if _widgets.has(id):
		_widgets[id].source = source
		if _tags.erase(id):
			_widgets[id].anchor = anchor
			_layout_dirty = true
		return _widgets[id].label
	var label := Label.new()
	label.name = String(id)
	label.oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var instrument := String(id).begins_with("score_") or id in [&"clock", &"speed"]
	if _stock != null:
		label.add_theme_font_override("font", _stock.font(830, 86) if instrument else _stock.font(690, 94))
	label.add_theme_font_size_override("font_size", maxi(1, font_size))
	label.add_theme_color_override("font_color", _inks.paper)
	label.add_theme_color_override("font_outline_color", _inks.ink)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_constant_override("line_spacing", 0)
	add_child(label)
	_widgets[id] = {"label": label, "source": source, "anchor": anchor, "fitted": "", "plate": false, "custom_color": false}
	if instrument and _stock != null:
		set_plate(id)
	_layout_dirty = true
	return label


## Ink stock with a printed registration stripe. An empty widget occupies no space.
func set_plate(id: StringName, on: bool = true) -> void:
	if not _widgets.has(id):
		push_error("TLHud.set_plate: no widget '%s'" % id)
		return
	var label: Label = _widgets[id].label
	_widgets[id].plate = on
	_layout_dirty = true
	if not on:
		label.remove_theme_stylebox_override("normal")
		label.add_theme_constant_override("outline_size", 3)
		return
	var box := StyleBoxFlat.new()
	box.bg_color = _inks.ink
	box.border_color = _inks.marker
	box.border_width_left = 3
	box.corner_radius_top_right = 5
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 3
	box.content_margin_bottom = 4
	label.add_theme_stylebox_override("normal", box)
	label.add_theme_constant_override("outline_size", 0)


## K5. How the lines of a label of several lines sit inside it (and inside its plate): &"left", &"center" or &"right".
## Default: left (as every label was).
func set_align(id: StringName, align: StringName) -> void:
	if not _widgets.has(id):
		push_error("TLHud.set_align: no widget '%s'" % id)
		return
	var label: Label = (_widgets[id] as Dictionary)["label"]
	match align:
		&"left":
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		&"center":
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		&"right":
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_:
			push_error("TLHud.set_align: '%s' is left, center or right" % align)


## A free label. Change it later with `set_text(id, text)`.
func add_label(id: StringName, text: String, anchor: StringName = &"top_left") -> void:
	_make(id, anchor, Callable()).text = text


## Centre a text widget just above a local-space point on a target, using this pack's active view.
func add_tag(id: StringName, node: Node3D, text: String = "", offset: Vector3 = Vector3(0, 2.3, 0)) -> void:
	var label := _make(id, &"top_left", Callable())
	label.text = text
	label.hide()
	_tags[id] = {"node": node, "offset": offset}
	_layout_dirty = true


## K5 (1.20). A painter layer (TLHudLayer) in layout units over the whole screen, drawn under this HUD's labels; the
## same id gives the same layer. A pack draws its own screen furniture with it (plates, rings on the ground, bars, a
## minimap, chevrons) without making Controls of its own.
func add_layer(id: StringName, unit_h: float = 1080.0) -> TLHudLayer:
	var name_ := "layer_" + String(id)
	var have := get_node_or_null(NodePath(name_))
	if have is TLHudLayer:
		return have
	var lay := TLHudLayer.new()
	lay.name = name_
	lay.unit_h = unit_h
	lay._cameras = _cameras
	add_child(lay)
	move_child(lay, 0)
	return lay


var _paused_handler: Callable = Callable()


## K5 (1.24). `handler(frame: int)` runs once a drawn frame while the frame has the pack paused (the pack's own tick
## is frozen then): a pack that owns its pause card (ctx.own_pause) draws the card in it. One handler per HUD.
func on_paused(handler: Callable) -> void:
	_paused_handler = handler


## Kernel side (the frame): one drawn frame of a pause.
func _paused_tick(frame: int) -> void:
	if _paused_handler.is_valid():
		_paused_handler.call(frame)


## Remove an anchored text widget or a tag and release its label.
func remove_widget(id: StringName) -> void:
	if not _widgets.has(id):
		return
	var label: Label = _widgets[id].label
	remove_child(label)
	label.queue_free()
	_widgets.erase(id)
	_tags.erase(id)
	_layout_dirty = true


## Set a text widget's ink to a Color or palette key. An empty key restores the HUD's paper.
func set_color(id: StringName, color: Variant) -> void:
	if not _widgets.has(id):
		push_error("TLHud.set_color: no widget '%s'" % id)
		return
	var ink: Color
	var custom := true
	if color is Color:
		ink = color
	elif color is String or color is StringName:
		var key := String(color)
		custom = not key.is_empty()
		ink = _inks.paper
		if not key.is_empty():
			var style := TLStandin.ext("TLStyle")
			if style == null or not style.call("has_key", key):
				push_error("TLHud.set_color: unknown palette key '%s'" % key)
				return
			ink = style.call("color", key)
	else:
		push_error("TLHud.set_color: expected a Color or palette key")
		return
	_widgets[id].custom_color = custom
	(_widgets[id].label as Label).add_theme_color_override("font_color", ink)


func set_text(id: StringName, text: String) -> void:
	if _widgets.has(id):
		((_widgets[id] as Dictionary)["label"] as Label).text = text
	else:
		push_error("TLHud.set_text: no widget '%s'" % id)


## The text a widget shows right now (bots and tests can read the HUD).
func text_of(id: StringName) -> String:
	return ((_widgets[id] as Dictionary)["label"] as Label).text if _widgets.has(id) else ""


## The score of one side of a TLRules, kept up to date. Widget id: "score_<side>".
func add_score(rules: TLRules, side: String, anchor: StringName = &"top_left", caption: String = "") -> void:
	var shown: String = caption if not caption.is_empty() else side
	_make(StringName("score_" + side), anchor, func() -> String: return "%s %d" % [shown, rules.score(side)])


## The clock of a TLRules as MM:SS (time left in the period, or time played when there is no period clock). Id "clock".
func add_clock(rules: TLRules, anchor: StringName = &"top") -> void:
	_make(&"clock", anchor, func() -> String:
		return rules.clock_text() + ("  P%d" % rules.period if rules.periods > 1 else ""))


## A speed read-out from any Callable that returns a number (`car.speed_kmh`, `skater.speed`). Id "speed".
func add_speed(source: Callable, unit: String = "km/h", anchor: StringName = &"bottom_right") -> void:
	_make(&"speed", anchor, func() -> String: return "%d %s" % [int(round(float(source.call()))), unit])


## Any text from a Callable that returns a String, refreshed every frame.
func add_bound(id: StringName, source: Callable, anchor: StringName = &"top_left") -> void:
	_make(id, anchor, source)


func _physics_process(_delta: float) -> void:
	for w: Dictionary in _widgets.values():
		var label: Label = w.label
		var source: Callable = w.source
		if source.is_valid():
			label.text = str(source.call())
		if label.text != w.fitted:
			w.fitted = label.text
			_layout_dirty = true
	if _layout_dirty:
		_arrange_labels()
		_layout_dirty = false


func _arrange_labels() -> void:
	var extent := get_viewport().get_visible_rect().size
	var ratio := minf(extent.x / 1280.0, extent.y / 720.0)
	var margin := Vector2(22, 19) * ratio
	var room := extent - margin * 2
	var clearance := _vertical_clearance(extent)
	var lower_margin := maxf(margin.y, clearance.y)
	margin.y = maxf(margin.y, clearance.x)
	room.y = extent.y - margin.y - lower_margin
	var stacks := {}
	for id: StringName in _widgets:
		if _tags.has(id):
			continue
		var w: Dictionary = _widgets[id]
		var label: Label = w.label
		label.visible = not label.text.is_empty()
		if label.visible:
			label.reset_size()
			if not stacks.has(w.anchor):
				stacks[w.anchor] = []
			stacks[w.anchor].append(label)
	for anchor: StringName in stacks:
		var group: Array = stacks[anchor]
		# A positive inset marks the left/top edge, a negative one the right/bottom edge.
		var alignment := (Vector2.ONE - (ANCHORS[anchor][1] as Vector2).sign()) * 0.5
		if alignment.y == 1:
			group.reverse() # The first bottom widget keeps the bottom edge when more widgets appear.
		var height := 4.0 * (group.size() - 1)
		var width := 1.0
		for label: Label in group:
			height += label.size.y
			width = maxf(width, label.size.x)
		var fit := minf(ratio, minf(room.x / width, room.y / maxf(1, height)))
		var y := margin.y + (room.y - height * fit) * alignment.y
		for label: Label in group:
			label.scale = Vector2.ONE * fit
			label.position = Vector2(margin.x + (room.x - label.size.x * fit) * alignment.x, y).round()
			y += (4.0 + label.size.y) * fit


func _process(_delta: float) -> void:
	if not visible or _tags.is_empty():
		return
	var cam := _cameras.active if is_instance_valid(_cameras) else null
	var rect := get_viewport().get_visible_rect()
	var fit := minf(rect.size.x / 1280.0, rect.size.y / 720.0)
	for id: StringName in _tags:
		var label: Label = _widgets[id].label
		label.visible = _place_tag(label, _tags[id], cam, rect, fit)


func _place_tag(label: Label, tag: Dictionary, cam: Camera3D, rect: Rect2, fit: float) -> bool:
	if not is_instance_valid(cam) or not cam.is_inside_tree() or not is_instance_valid(tag.node):
		return false
	var target: Node3D = tag.node
	if label.text.is_empty() or not target.is_inside_tree():
		return false
	var point: Vector3 = target.global_transform * tag.offset
	if cam.is_position_behind(point):
		return false
	var screen := cam.unproject_position(point)
	if not rect.has_point(screen):
		return false
	label.reset_size()
	label.scale = Vector2.ONE * fit
	label.position = (screen - label.size * fit * Vector2(0.5, 1.0)).round()
	return true
