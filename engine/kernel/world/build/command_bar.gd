extends CanvasLayer
## M4 (spark world-sandbox): the command bar's text field, above build mode's hotbar (bottom centre). Shown while the
## person types a sentence: the field has the keyboard (TLInput `keys_taken`: the visitor sees no key, build mode reads
## none), Enter sends (`submitted`), Esc closes it without asking (`cancelled`). A line above the field says where it
## builds and how many calls are left today. English, inline (repo convention). Kernel UI: no material.
## M5 (lane C): the stamp tool's name field is another bar of this script, opened with a text already in it (selected,
## so typing replaces it), at most 60 characters, its own placeholder.

signal submitted(text: String)
signal cancelled

const LIFT := 236                       # px from the window's bottom to the bar's bottom (the hotbar sits under it)
const WIDTH := 720.0
const SENTENCE := "a stone bridge across here ... make this house taller with a slate roof"

var box: VBoxContainer
var title: Label
var line: LineEdit


func _init() -> void:
	name = "CommandBar"
	layer = 102
	box = VBoxContainer.new()
	box.name = "Command"
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_bottom = -LIFT
	box.custom_minimum_size = Vector2(WIDTH, 0)
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	title = Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.9))
	title.add_theme_constant_override("outline_size", 5)
	box.add_child(title)
	line = LineEdit.new()
	line.name = "Sentence"
	line.custom_minimum_size = Vector2(WIDTH, 40)
	line.add_theme_font_size_override("font_size", 20)
	line.placeholder_text = SENTENCE
	line.max_length = 400
	line.text_submitted.connect(func(t: String) -> void: submitted.emit(t))
	line.gui_input.connect(_on_key)
	box.add_child(line)
	box.visible = false


## Shows the field with `head` above it and `text` in it (selected), taking at most `max_len` characters.
func open(head: String, text := "", max_len := 400, hint := SENTENCE) -> void:
	title.text = head
	line.max_length = max_len
	line.placeholder_text = hint
	line.text = text.left(max_len)
	box.visible = true
	line.grab_focus()
	if line.has_method("edit"):
		line.call("edit")
	line.caret_column = line.text.length()
	if not line.text.is_empty():
		line.select_all()


func close() -> void:
	box.visible = false
	if line.has_focus():
		line.release_focus()


func is_open() -> bool:
	return box.visible


func _on_key(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
		line.accept_event()
		cancelled.emit()
