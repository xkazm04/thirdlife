extends Control
## E1 (night of 19 Nov): the "New game" workbench. Left: your idea (kept word for word), the recipe it matched and
## why, the questions of that recipe with the engine's proposal and its reason on each. Right: the village from above
## with the game's ghost (drag to place, wheel or Q / E to turn) and the footprint beside the 2 m walker. Bottom: the
## request exactly as "Build it" sends it, what blocks it, "Draft · nothing spent". All of it is drawn from one model
## (editor_model.gd); nothing is written and nothing is started before "Build it".
## Built in code like ui/panel.gd; colours from style/style.json.

const Model = preload("res://ui/editor/editor_model.gd")
const VillageMap = preload("res://ui/editor/village_map.gd")
const PlacePanel = preload("res://ui/editor/place_panel.gd")
const ScaleStrip = preload("res://ui/editor/scale_strip.gd")
const Look = preload("res://ui/editor/look.gd")

signal committed(request: String, error: String)
signal closed
signal edit_hud

const M: int = 16
const LEFT_W: int = 540
const FS: int = 14
const GROUPS: Array = [["who", "Who plays"], ["win", "How it is won"], ["where", "Where and how it looks"]]

var model: Model
var door: RefCounted                 # ui/foreman_door.gd or null
var jobs_root: String = ""
var col: Dictionary = {}
var font: Font
var bold: Font
var message: String = ""
var message_bad: bool = false
var draft_path: String = ""

var _idea: LineEdit
var _examples: HFlowContainer
var _recipe_box: VBoxContainer
var _q_box: VBoxContainer
var _q_scroll: ScrollContainer
var _progress: Label
var _zoom: Button
var _map: VillageMap
var _yaw_note: Label
var _strip: ScaleStrip
var _places: PlacePanel
var _request: Label
var _blocker: Label
var _build: Button
var _footer: Label
var _show_recipes: bool = false
var _sig: String = ""
var rebuilds: Array = []             # process frames at which the chip rows were rebuilt (a read for the drive)


func setup(the_door: RefCounted, root: String) -> void:
	door = the_door
	jobs_root = root


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	model = Model.new()
	model.load_all()
	for e: String in model.load_errors:
		push_warning("[workbench] " + e)
	_load_colors()
	theme = Look.theme(col, font)
	_build_frame()
	refresh()


func _load_colors() -> void:
	col = Look.colors()
	var face := Look.typeface()
	font = Look.weight(face, 480)
	bold = Look.weight(face, 790, 96)


func _sb(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = 6, pad_h: int = 10, pad_v: int = 4) -> StyleBoxFlat:
	return Look.sb(bg, border, bw, radius, pad_h, pad_v)


# ---------------------------------------------------------------- building blocks

func _label(text: String, fs: int = FS, b: bool = false, color: Color = Color(0, 0, 0, 0), wrap: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if b:
		l.add_theme_font_override("font", bold)
	if b and fs >= 20:
		l.add_theme_stylebox_override("normal", Look.plate(col, "flag" if color == col["card"] else "heading"))
	elif b and fs <= 12 and not text.is_empty() and text == text.to_upper():
		l.add_theme_stylebox_override("normal", Look.plate(col, "index"))
	if fs != FS:
		l.add_theme_font_size_override("font_size", fs)
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _plate(name_: String) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.name = name_
	return p


## A choice chip. `look`: "player" (chosen by you: honey, bold), "sentence" (from your words: honey), "proposal"
## (the engine's proposal, not yet yours: a dashed-looking honey outline and a "proposed" mark), "" (another option).
func _chip(name_: String, text: String, look: String) -> Button:
	var b: Button = Button.new()
	b.name = name_
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS   # the wheel over a chip still scrolls the questions
	b.add_theme_font_size_override("font_size", 13)
	var ink: Color = col["ink"]
	var sb: StyleBoxFlat
	match look:
		"player", "sentence":
			sb = Look.keycap(col["honey"], ink, true, 11)
			b.add_theme_font_override("font", bold)
		"proposal":
			sb = Look.keycap(col["vellum"], col["honey_dark"], false, 11)
			b.text = text + "  · proposed"
		_:
			sb = Look.keycap(col["card"], col["rule"], false, 11)
	for st: String in ["normal", "hover", "pressed", "focus"]:
		var s: StyleBoxFlat = sb.duplicate()
		if st == "hover":
			s.bg_color = s.bg_color.darkened(0.07)
		b.add_theme_stylebox_override(st, s)
	return b


func _primary(name_: String, text: String) -> Button:
	var b: Button = Button.new()
	b.name = name_
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", bold)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_stylebox_override("normal", Look.keycap(col["honey"], col["wood_dark"], true, 22, 8))
	b.add_theme_stylebox_override("hover", Look.keycap(col["honey"].lerp(col["card"], 0.20), col["wood_dark"], true, 22, 8))
	b.add_theme_stylebox_override("pressed", Look.keycap(col["honey_dark"], col["ink"], true, 22, 8))
	b.add_theme_stylebox_override("disabled", Look.keycap(col["concrete"], col["rule"], false, 22, 8))
	return b


# ---------------------------------------------------------------- the frame

func _build_frame() -> void:
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(col["shade"], 0.26)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = M
	root.offset_top = M
	root.offset_right = -M
	root.offset_bottom = -M
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	# head: a plate with the name of the place and the progress line
	var head: HBoxContainer = HBoxContainer.new()
	root.add_child(head)
	var hp: PanelContainer = _plate("HeadPlate")
	hp.add_theme_stylebox_override("panel", Look.plate(col, "rail"))
	var hh: HBoxContainer = HBoxContainer.new()
	hp.add_child(hh)
	var back: Button = Button.new()
	back.name = "CloseButton"
	back.text = "<"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func() -> void: closed.emit())
	hh.add_child(back)
	hh.add_child(_label("Workbench · New game", 22, true, col["card"]))
	head.add_child(hp)
	var pp: PanelContainer = _plate("ProgressPlate")
	pp.add_theme_stylebox_override("panel", Look.plate(col, "rail"))
	pp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress = _label("", 14, false, col["card"])
	_progress.name = "Progress"
	_progress.clip_text = true
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pp.add_child(_progress)
	head.add_child(pp)
	var hud_button := _chip("HudWorkshop", "HUD workshop", "")
	hud_button.pressed.connect(func() -> void: edit_hud.emit())
	head.add_child(hud_button)

	var mid: HBoxContainer = HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 10)
	root.add_child(mid)

	# left: idea, recipe, questions
	var left: PanelContainer = _plate("Interview")
	left.custom_minimum_size = Vector2(LEFT_W, 0)
	mid.add_child(left)
	var lv: VBoxContainer = VBoxContainer.new()
	left.add_child(lv)
	lv.add_child(_label("Your idea", 24, true))
	_idea = LineEdit.new()
	_idea.name = "IdeaField"
	_idea.placeholder_text = "What do you want to play?"
	_idea.text_changed.connect(func(t: String) -> void:
		model.set_sentence(t)
		refresh())
	lv.add_child(_idea)
	_examples = HFlowContainer.new()
	_examples.name = "Examples"
	lv.add_child(_examples)
	_recipe_box = VBoxContainer.new()
	_recipe_box.name = "RecipeBox"
	lv.add_child(_recipe_box)
	_q_scroll = ScrollContainer.new()
	_q_scroll.name = "QuestionsScroll"
	_q_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_q_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(_q_scroll)
	_q_box = VBoxContainer.new()
	_q_box.name = "Questions"
	_q_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_q_scroll.add_child(_q_box)

	# right: place
	var right: PanelContainer = _plate("Place")
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(right)
	var rv: VBoxContainer = VBoxContainer.new()
	right.add_child(rv)
	var rh: HBoxContainer = HBoxContainer.new()
	rh.add_child(_label("Where it stands", 24, true))
	var hint: Label = _label("Click or drag to place · Q / E to turn", 12, false, col["dim"])
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.clip_text = true
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rh.add_child(hint)
	var find := _chip("FindPlace", "Find a place", "")
	rh.add_child(find)
	_zoom = _chip("CloseUpButton", "Close up", "")
	_zoom.pressed.connect(func() -> void: set_map_zoom(not _map.close_up))
	rh.add_child(_zoom)
	rv.add_child(rh)
	var frame: PanelContainer = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _sb(col["trunk"], col["ink"], 1, 2, 2, 2))
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(frame)
	_map = VillageMap.new()
	_map.name = "Map"
	_map.model = model
	_map.col = col
	_map.font = font
	_map.bold = bold
	_map.changed.connect(refresh)
	frame.add_child(_map)
	_yaw_note = _label("", 12, false, col["dim"], true)
	rv.add_child(_yaw_note)
	_strip = ScaleStrip.new()
	_strip.name = "ScaleStrip"
	_strip.model = model
	_strip.col = col
	_strip.font = font
	_strip.bold = bold
	_strip.custom_minimum_size = Vector2(0, 104)
	rv.add_child(_strip)
	_places = PlacePanel.new()
	_places.setup(self, find)
	rv.add_child(_places)

	# bottom: what will be sent
	var bottom: PanelContainer = _plate("Review")
	bottom.add_theme_stylebox_override("panel", Look.plate(col, "review"))
	root.add_child(bottom)
	var bh: HBoxContainer = HBoxContainer.new()
	bh.add_theme_constant_override("separation", 16)
	bottom.add_child(bh)
	var bv: VBoxContainer = VBoxContainer.new()
	bv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bv.add_theme_constant_override("separation", 2)
	bh.add_child(bv)
	bv.add_child(_label("WHAT THE BUILDERS WILL BE TOLD", 12, true, col["honey"]))
	_request = _label("", 13, false, col["card"], true)
	_request.name = "Request"
	_request.custom_minimum_size = Vector2(0, 36)
	_request.max_lines_visible = 3
	bv.add_child(_request)
	_footer = _label("", 12, false, col["vellum"], true)
	_footer.name = "Footer"
	_footer.max_lines_visible = 2
	bv.add_child(_footer)
	var bb: VBoxContainer = VBoxContainer.new()
	bb.custom_minimum_size = Vector2(260, 0)
	bb.add_theme_constant_override("separation", 4)
	bh.add_child(bb)
	_build = _primary("BuildButton", "Build it")
	_build.pressed.connect(_commit)
	bb.add_child(_build)
	_blocker = _label("", 12, true, col["hazard_light"], true)
	_blocker.name = "Blocker"
	_blocker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bb.add_child(_blocker)


# ---------------------------------------------------------------- refresh

func set_map_zoom(close_up: bool) -> void:
	_map.close_up = close_up
	_zoom.text = "Whole village" if close_up else "Close up"
	_map.queue_redraw()


func refresh() -> void:
	_place_if_needed()
	var sig: String = "%s|%s|%s|%s|%s|%s|%s|%s" % [model.sentence, model.recipe, model.recipe_by, str(model.answers),
		str(model.matches), _show_recipes, model.placed, str(model.footprint())]
	if sig != _sig:
		_sig = sig
		rebuilds.append(Engine.get_process_frames())   # read by the drive (ui/editor/drive_editor.gd chips)
		_fill_examples()
		_fill_recipe()
		_fill_questions()
	_fill_progress()
	_places.refresh()
	_yaw_note.text = model.yaw_note()
	_yaw_note.visible = not _yaw_note.text.is_empty()
	_fill_review()
	_map.queue_redraw()
	_strip.queue_redraw()


func _clear(box: Node) -> void:
	for c: Node in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _fill_examples() -> void:
	_clear(_examples)
	_examples.visible = model.sentence.is_empty()
	_q_scroll.add_theme_stylebox_override("panel", Look.plate(col, "blank") if model.recipe.is_empty() else StyleBoxEmpty.new())
	if not _examples.visible:
		return
	var ex: Array = [["ExampleHockey", "ice hockey, three against three, against the computer"],
		["ExampleCourse", "a Takeshi's castle obstacle course with jumps and a slide"],
		["ExampleArena", "an arena where I fight waves of goblins with a sword"]]
	_examples.add_child(_label("for example:", 12, false, col["dim"]))
	for e: Array in ex:
		var b: Button = _chip(str(e[0]), str(e[1]), "")
		b.pressed.connect(func() -> void:
			_idea.text = str(e[1])
			_idea.text_changed.emit(_idea.text))
		_examples.add_child(b)


func _fill_recipe() -> void:
	_clear(_recipe_box)
	if model.recipe.is_empty():
		if not model.sentence.is_empty():
			_recipe_box.add_child(_label("A few more words, and the workbench finds the recipe that fits.", 13, false, col["dim"], true))
		return
	var p: PanelContainer = PanelContainer.new()
	p.name = "RecipeChip"
	var iv: Dictionary = model.interview()
	if model.has_card():
		var emblem: String = {"track": "drive", "slalom": "drive", "yard": "wall"}.get(model.shape().get("shape", ""), "recipe")
		p.add_theme_stylebox_override("panel", Look.plate(col, "recipe", emblem))
		var v: VBoxContainer = VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		p.add_child(v)
		var c: Dictionary = model.card()
		var t: String = str(c.get("title", iv.get("card", "")))
		v.add_child(_label("RECIPE · " + t.get_slice(":", 0), 15, true, Color(0, 0, 0, 0), true))
		var why: String = ""
		for m: Dictionary in model.matches:
			if m["name"] == model.recipe:
				why = "matched your words: " + ", ".join(PackedStringArray(m["words"]))
		if model.recipe_by == "player":
			why = "you chose it"
		v.add_child(_label("%s · plays like %s" % [why, str(iv.get("example", ""))], 12, false, Color(0, 0, 0, 0), true))
	else:
		p.add_theme_stylebox_override("panel", Look.plate(col, "notice"))
		var v: VBoxContainer = VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		p.add_child(v)
		v.add_child(_label("No recipe fits this game yet", 15, true))
		v.add_child(_label("It can still be built from your words alone: expect more questions from the builders, a longer build, and a real chance it does not finish. The questions below are the ones every game has.", 12, false, Color(0, 0, 0, 0), true))
	_recipe_box.add_child(p)
	var row: HFlowContainer = HFlowContainer.new()
	var other: Button = _chip("OtherRecipes", "Other recipes" if not _show_recipes else "Hide recipes", "")
	other.pressed.connect(func() -> void:
		_show_recipes = not _show_recipes
		_sig = ""
		refresh())
	row.add_child(other)
	if _show_recipes:
		for n: String in model.interview_order:
			var label: String = "None of these" if n == "none" else str(model.cards.get(str(model.interviews[n].get("card", "")), {}).get("title", n)).get_slice(":", 0)
			var b: Button = _chip("Recipe_" + n, label, "player" if n == model.recipe else "")
			b.pressed.connect(func() -> void:
				model.choose_recipe(n)
				_show_recipes = false
				_place_if_needed()
				refresh())
			row.add_child(b)
	_recipe_box.add_child(row)


func _fill_questions() -> void:
	_clear(_q_box)
	if model.recipe.is_empty():
		return
	for g: Array in GROUPS:
		var qs: Array = []
		for q: Dictionary in model.questions():
			if q["group"] == g[0]:
				qs.append(q)
		if qs.is_empty():
			continue
		_q_box.add_child(_label(str(g[1]).to_upper(), 12, true, col["wood_dark"]))
		for q: Dictionary in qs:
			var key: String = q["key"]
			var v: Dictionary = model.value(key)
			_q_box.add_child(_label(str(q["ask"]), 15, true))
			var flow: HFlowContainer = HFlowContainer.new()
			for o: Dictionary in q["options"]:
				var look: String = ""
				if str(o["id"]) == str(v["id"]):
					look = str(v["by"])
				var b: Button = _chip("Opt_%s_%s" % [key, str(o["id"])], str(o["label"]), look)
				var oid: String = str(o["id"])
				b.pressed.connect(func() -> void:
					model.answer(key, oid)
					refresh())
				flow.add_child(b)
			_q_box.add_child(flow)
			var note: String
			match str(v["by"]):
				"proposal": note = "Proposed: " + str(q["reason"])
				"sentence": note = "From your words \"%s\"" % str(v.get("words", ""))
				_: note = "Yours." + ("" if str(v.get("took", "")) != "proposal" else " (you took the proposal: %s)" % str(q["reason"]))
			_q_box.add_child(_label(note, 12, false, col["dim"] if str(v["by"]) != "proposal" else col["wood_dark"], true))
	var row: HFlowContainer = HFlowContainer.new()
	row.name = "AfterQuestions"
	var left: int = model.left_to_proposal().size()
	if left > 0:
		var take: Button = _chip("TakeProposals", "Take the %d proposal%s" % [left, "" if left == 1 else "s"], "")
		take.pressed.connect(func() -> void:
			model.take_proposals()
			refresh())
		row.add_child(take)
	var vs: Array = model.interview().get("variants", [])
	for i: int in vs.size():
		var b: Button = _chip("Variant_%d" % i, "+ " + str((vs[i] as Dictionary)["ask"]), "")
		var idx: int = i
		b.pressed.connect(func() -> void:
			model.apply_variant(idx)
			refresh())
		row.add_child(b)
	_q_box.add_child(row)


func _fill_progress() -> void:
	var parts: PackedStringArray = []
	parts.append("Idea: " + ("-" if model.sentence.is_empty() else "yours"))
	if model.recipe.is_empty():
		parts.append("Recipe: -")
	elif model.has_card():
		parts.append("Recipe: " + str(model.card().get("title", "")).get_slice(":", 0))
	else:
		parts.append("Recipe: none fits")
	var n: int = model.questions().size()
	if n > 0:
		parts.append("%d of %d decided" % [model.decided_count(), n])
	if not model.placed:
		parts.append("Place: not chosen")
	elif model.fits():
		parts.append("Place: fits")
	else:
		parts.append("Place: does not fit")
	_progress.text = "   ·   ".join(parts)


func _fill_review() -> void:
	_request.text = model.request() if not model.sentence.is_empty() else "Nothing yet: start with your idea, top left."
	var est: Dictionary = model.interview().get("estimate", {})
	var foot: String = "Draft"
	if not est.is_empty():
		foot += " · estimate %d packages, about %d min (%s)" % [int(est.get("packages", 0)), int(est.get("minutes", 0)), str(est.get("source", "a guess"))]
	var left: PackedStringArray = model.left_to_proposal()
	if not left.is_empty():
		foot += " · left to the proposal: " + ", ".join(left)
	if model.placed:
		foot += " · lot at %d, %d, radius %d m" % [int(model.at.x), int(model.at.y), int(model.lot_radius())]
	_footer.text = foot
	var why: String = model.blocker()
	if not message.is_empty():
		_blocker.text = message
		_blocker.add_theme_color_override("font_color", col["hazard_light"] if message_bad else col["meadow_light"])
	else:
		_blocker.text = why
		_blocker.add_theme_color_override("font_color", col["hazard_light"])
	_build.disabled = not why.is_empty()


## While the player has not placed the game by hand, the ghost stands on the first free place by the road for its
## current size (it follows the size); once the player places it, only the player moves it.
func _place_if_needed() -> void:
	if model.recipe.is_empty() or not model.village_ok:
		return
	if not model.placed or (model.placed_by == "auto" and model.placement_key() != model.auto_key):
		model.place(model.first_free(), "auto")


# ---------------------------------------------------------------- commit

func _commit() -> void:
	if not model.blocker().is_empty():
		return
	var d: Dictionary = model.draft()
	var slug: String = model.sentence.to_lower().replace(" ", "-").validate_filename().left(40)
	var dir: String = jobs_root.path_join("_editor") if not jobs_root.is_empty() else ProjectSettings.globalize_path("user://editor")
	DirAccess.make_dir_recursive_absolute(dir)
	draft_path = dir.path_join("%s-%d.json" % [slug, int(Time.get_unix_time_from_system())])
	var f: FileAccess = FileAccess.open(draft_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d, "  ") + "\n")
		f.close()
	var answers := model.answer_ids()
	var err: String = "no Foreman door" if door == null else str(door.call("new_game", d["request"], answers, d["lot"], model.place_calls))
	if err.is_empty():
		message = "The builders are starting. Your draft: " + draft_path.get_file()
		message_bad = false
	else:
		message = "The builders cannot be started: %s. Your draft is kept (%s)." % [err, draft_path.get_file()]
		message_bad = true
	refresh()
	committed.emit(model.request(), err)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		closed.emit()
		accept_event()
