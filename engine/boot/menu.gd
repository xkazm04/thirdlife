extends CanvasLayer
## L4 (night of 21 Nov): the main menu of the exe. World / Dungeons / Create / Quit, in the crisp look
## (kernel/dungeon/look_ui.gd), keyboard (arrows or W/S, Enter or Space, Esc back) and mouse. boot.gd makes one each time
## the menu is shown and frees it when the person picks something; it decides what a pick does.
##
##   open(rows, tag, create_ok)   rows: [{title, look?, pack_id?, dir}] ("" dir: this build does not carry it)
##   signals: world, dungeon(index), create, quit
## No class_name; no kernel class is used by name.

signal world
signal dungeon(index: int)
signal create
signal quit

const UI: GDScript = preload("res://kernel/dungeon/look_ui.gd")
const Dungeon: GDScript = preload("res://kernel/dungeon/dungeon.gd")
const TINTS: Array = ["#3a724c", "#dc4238", "#5c6478", "#e8742c", "#754bb6", "#b9794a"]

var rows: Array = []
var _main: Control = null
var _list: Control = null
var _first_main: Button = null
var _first_list: Button = null
var _screen: Control = null
## L4c: the menu is laid out for 1920 x 1080 and scaled to the window (a 1280 x 720 window put the key line over Quit and
## cut the dungeon list): the scale is the smaller of width / 1920 and height / 1080, never above 1; the screen keeps the
## window's shape in those units, so the sky fills it and nothing overlaps.
const DESIGN: Vector2 = Vector2(1920, 1080)


func _init() -> void:
	name = "Menu"
	layer = 90


func open(dungeon_rows: Array, tag: String, create_ok: bool) -> void:
	rows = dungeon_rows
	var root: Control = Control.new()
	root.name = "Screen"
	_screen = root
	add_child(root)
	_fit()
	root.get_viewport().size_changed.connect(_fit)
	root.add_child(UI.sky_backdrop())
	var cols: HBoxContainer = HBoxContainer.new()
	cols.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cols.offset_left = 140
	cols.offset_right = -140
	cols.offset_top = 120
	cols.offset_bottom = -110
	cols.add_theme_constant_override("separation", 90)
	root.add_child(cols)
	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(560, 0)
	left.add_theme_constant_override("separation", 18)
	cols.add_child(left)
	left.add_child(UI.label("Third Life", 96, false))
	left.add_child(UI.label("a world to shape, and games to enter", 30, false))
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	left.add_child(gap)
	_main = VBoxContainer.new()
	_main.name = "Main"
	_main.add_theme_constant_override("separation", 16)
	left.add_child(_main)
	_first_main = _add(_main, "World", "the village: walk, enter its games", func() -> void: world.emit())
	var dn: Button = _add(_main, "Dungeons", "a game on its own: hockey, parkour, ...", _show_list)
	dn.focus_entered.connect(func() -> void: _list.visible = true)      # a preview of the list; Enter goes into it
	if create_ok:
		_add(_main, "Create", "describe a game; the builder makes it", func() -> void: create.emit())
	else:
		var b: Button = _add(_main, "Create (coming tonight)", "", Callable())
		b.disabled = true
		b.focus_mode = Control.FOCUS_NONE
	_add(_main, "Quit", "", func() -> void: quit.emit())
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	_list = _make_list()
	_list.visible = false
	right.add_child(_list)
	for b: Node in _main.get_children():
		if b.name != "Dungeons":
			(b as Control).focus_entered.connect(func() -> void: _list.visible = false)
	var keys: Label = UI.label("arrows or W S  choose      A D  pages      Enter  open      Esc  back", 22, false)
	keys.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	keys.position = Vector2(140, -70)
	keys.offset_top = -70
	keys.offset_bottom = -40
	root.add_child(keys)
	if not tag.is_empty():
		var t: Label = UI.label(tag, 16, false)
		t.name = "BuildTag"
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		t.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		t.offset_left = -360
		t.offset_right = -14
		t.offset_top = 10
		root.add_child(t)
	_first_main.grab_focus.call_deferred()


func _fit() -> void:
	if _screen == null or not _screen.is_inside_tree():
		return
	var vp: Vector2 = _screen.get_viewport().get_visible_rect().size
	var k: float = minf(1.0, minf(vp.x / DESIGN.x, vp.y / DESIGN.y))
	_screen.position = Vector2.ZERO
	_screen.scale = Vector2(k, k)
	_screen.size = vp / k


## The scale the screen is drawn at now (selftest 640 reads it).
func fit_scale() -> float:
	return _screen.scale.x if _screen != null else 1.0


func _add(box: Control, text: String, hint: String, on_press: Callable) -> Button:
	var b: Button = UI.button(text)
	b.name = text.split(" ")[0]
	if not hint.is_empty():
		b.tooltip_text = hint
	if on_press.is_valid():
		b.pressed.connect(on_press)
	box.add_child(b)
	return b


## 26 Nov (the owner: no way "to browse through dozens of games"): the list shows PAGE rows at a time; Previous / Next
## (and Left / Right, A / D, Page Up / Page Down) turn the pages, and the line between them says which page of how many.
const PAGE: int = 5
var page: int = 0
var _rows_box: VBoxContainer = null
var _pager: HBoxContainer = null
var _back: Button = null


func _make_list() -> Control:
	var card: PanelContainer = UI.card()
	card.name = "Dungeons"
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	v.add_child(UI.label("Dungeons", 48))
	v.add_child(UI.label("each game alone: its own camera, HUD and look; the world is unloaded", 20))
	_rows_box = VBoxContainer.new()
	_rows_box.name = "Rows"
	_rows_box.add_theme_constant_override("separation", 14)
	v.add_child(_rows_box)
	_pager = HBoxContainer.new()
	_pager.name = "Pager"
	_pager.add_theme_constant_override("separation", 18)
	v.add_child(_pager)
	_back = UI.button("Back", 26)
	_back.name = "Back"
	_back.pressed.connect(_show_main)
	v.add_child(_back)
	_fill_page()
	return card


func pages() -> int:
	return maxi(1, ceili(float(rows.size()) / PAGE))


## Turns the list a page (-1 back, +1 on) and puts the focus on its first game.
func turn(by: int) -> void:
	var to: int = clampi(page + by, 0, pages() - 1)
	if to == page:
		return
	page = to
	_fill_page()
	_first_list.grab_focus()


func _fill_page() -> void:
	for c: Node in _rows_box.get_children() + _pager.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()
	_first_list = null
	if rows.is_empty():
		_rows_box.add_child(UI.label("no dungeon is listed (engine/boot/dungeons.json)", 24))
	for i: int in range(page * PAGE, mini(rows.size(), (page + 1) * PAGE)):
		var r: Dictionary = rows[i]
		var line: HBoxContainer = HBoxContainer.new()
		line.add_theme_constant_override("separation", 18)
		line.add_child(_icon(r, i))
		var b: Button = UI.button("%s
%s" % [str(r["title"]), "made by you in Create" if r.get("mine", false) == true else "look: " + str(r.get("look", "default"))], 26)   # E4: the person's own
		b.name = "Dungeon%d" % i
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 96)
		b.clip_text = true                                   # a long title ends in "..." and never widens the card
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text = str(r["title"])
		if str(r.get("dir", "")).is_empty():
			b.text = "%s
not in this build" % str(r["title"])
			b.disabled = true
		else:
			b.pressed.connect(func() -> void: dungeon.emit(i))
			if _first_list == null:
				_first_list = b
		line.add_child(b)
		_rows_box.add_child(line)
	if pages() > 1:
		var prev: Button = UI.button("Previous", 24)
		prev.name = "Previous"
		prev.disabled = page == 0
		prev.pressed.connect(turn.bind(-1))
		_pager.add_child(prev)
		var at: Label = UI.label("page %d of %d  ·  %d games" % [page + 1, pages(), rows.size()], 22)
		at.name = "Page"
		at.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		at.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_pager.add_child(at)
		var nxt: Button = UI.button("Next", 24)
		nxt.name = "Next"
		nxt.disabled = page == pages() - 1
		nxt.pressed.connect(turn.bind(1))
		_pager.add_child(nxt)
	if _first_list == null:
		_first_list = _back


## The still the person last saw in that dungeon (user://dungeon_stills), else a letter tile.
func _icon(r: Dictionary, i: int) -> Control:
	var p: String = Dungeon.still_path(str(r.get("pack_id", ""))) if not str(r.get("pack_id", "")).is_empty() else ""
	if not p.is_empty() and FileAccess.file_exists(p):
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(p))
		if img != null and not img.is_empty():
			var tr: TextureRect = TextureRect.new()
			tr.texture = ImageTexture.create_from_image(img)
			tr.custom_minimum_size = Vector2(170, 96)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			return tr
	var words: PackedStringArray = str(r["title"]).split(" ", false)
	var mono: String = (words[0].left(1) + (words[1].left(1) if words.size() > 1 and words[1].length() > 0 and words[1][0] != "|" and words[1][0] != ":" else "")).to_upper()
	var tile: PanelContainer = UI.monogram(mono, Color(str(TINTS[i % TINTS.size()])), 96)
	tile.custom_minimum_size = Vector2(170, 96)
	return tile


func _show_list() -> void:
	_list.visible = true
	_first_list.grab_focus()


func _show_main() -> void:
	_list.visible = false
	_first_main.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var f: Control = get_viewport().gui_get_focus_owner()
	match k.keycode:
		KEY_ESCAPE:
			if _list.visible:
				_show_main()
				get_viewport().set_input_as_handled()
		KEY_W, KEY_S:                            # the walker's keys move the focus too
			if f != null:
				var nb: Control = f.find_valid_focus_neighbor(SIDE_TOP if k.keycode == KEY_W else SIDE_BOTTOM)
				if nb != null:
					nb.grab_focus()
				get_viewport().set_input_as_handled()
		KEY_RIGHT, KEY_D:
			if f != null and f.get_parent() == _main and f.name == "Dungeons":
				_show_list()
				get_viewport().set_input_as_handled()
			elif f != null and _list.is_ancestor_of(f):
				turn(1)
				get_viewport().set_input_as_handled()
		KEY_LEFT, KEY_A, KEY_PAGEUP:
			if f != null and _list.is_ancestor_of(f):
				turn(-1)
				get_viewport().set_input_as_handled()
		KEY_PAGEDOWN:
			if f != null and _list.is_ancestor_of(f):
				turn(1)
				get_viewport().set_input_as_handled()
