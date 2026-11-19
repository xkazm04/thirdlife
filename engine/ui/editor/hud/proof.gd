extends Control
## Previewing and picking use the exact bounds the shared instrument sheet drew.
const Sheet = preload("res://style/hud/sheet.gd")
const Layout = preload("res://style/hud/layout.gd")
signal picked(id: String)
signal placed(id: String, anchor: String)

var sheet := Sheet.new()
var selection := ""
var game_id := ""
var _scene := TextureRect.new()
var _marks := Control.new()
var _press := Vector2.ZERO
var _held := ""
var _drag := false
var _cell := -1
var _textures := {}

func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = CURSOR_ARROW
	var ground := ColorRect.new()
	ground.color = Color("#5c6569")
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_scene)
	_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sheet)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_marks)
	_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	resized.connect(_marks.queue_redraw)

func populate(catalog: Array, profile: Dictionary, pack_id: String) -> void:
	game_id = pack_id
	sheet.install(catalog, profile)
	show_phase("run")

func show_phase(phase: String) -> void:
	sheet.set_phase(phase)
	for spec: Dictionary in sheet.catalog:
		var sample: Dictionary = spec.get("finish_sample", spec.sample) if phase == "finish" else spec.sample
		sheet.set_reading(spec.id, sample)
	if game_id == "game.parkour":
		if not _textures.has(phase):
			var path := "res://ui/editor/hud/timber-%s.jpg" % phase
			if ResourceLoader.exists(path):
				_textures[phase] = load(path)
			else:
				var img := Image.new()
				if img.load(path) == OK:
					_textures[phase] = ImageTexture.create_from_image(img)
	_scene.texture = _textures.get(phase) if game_id == "game.parkour" else null
	_marks.queue_redraw()

func _hit(pos: Vector2) -> String:
	var ids := sheet.cards.keys()
	ids.reverse()
	for id: String in ids:
		var card: Control = sheet.cards[id]
		if card.visible and Rect2(card.position, card.size * card.scale).has_point(pos):
			return id
	return ""

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_held = _hit(event.position)
			_press = event.position
			if _held != "":
				picked.emit(_held)
				accept_event()
		else:
			if _drag and _cell >= 0 and Rect2(Vector2.ZERO, size).has_point(event.position):
				placed.emit(_held, Layout.ANCHORS[_cell])
			_held = ""
			_drag = false
			_cell = -1
			_marks.queue_redraw()
	elif event is InputEventMouseMotion:
		if _held != "" and _press.distance_to(event.position) > 4:
			_drag = true
			_cell = clampi(floori(event.position.x * 3 / size.x), 0, 2) + 3 * clampi(floori(event.position.y * 3 / size.y), 0, 2)
			_marks.queue_redraw()
		mouse_default_cursor_shape = CURSOR_DRAG if _drag else (CURSOR_POINTING_HAND if _hit(event.position) != "" else CURSOR_ARROW)

func _draw_marks() -> void:
	var chalk := Color("#fffbed")
	if _drag:
		var cell := size / 3
		var rect := Rect2(Vector2(_cell % 3, floori(_cell / 3.0)) * cell, cell)
		_marks.draw_rect(rect, Color(chalk, 0.25))
		for i: int in [1, 2]:
			_marks.draw_dashed_line(Vector2(cell.x * i, 0), Vector2(cell.x * i, size.y), chalk, 1, 5)
			_marks.draw_dashed_line(Vector2(0, cell.y * i), Vector2(size.x, cell.y * i), chalk, 1, 5)
	elif sheet.cards.has(selection):
		var card: Control = sheet.cards[selection]
		if not card.visible:
			return
		var rect := Rect2(card.position, card.size * card.scale).grow(3)
		for corner: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, Vector2.ONE]:
			var a := rect.position + corner * rect.size
			var dir := Vector2.ONE - 2 * corner
			_marks.draw_line(a, a + Vector2(dir.x * 7, 0), chalk, 2)
			_marks.draw_line(a, a + Vector2(0, dir.y * 7), chalk, 2)

func select(id: String) -> void:
	selection = id
	_marks.queue_redraw()
