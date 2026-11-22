extends "res://ui/create/create_kit.gd"
## L3 (night of 21 Nov 2026): the Create page, part 2 of 4: the screens before the build (idea, designing, the pitch
## and its aspect cards, Tell me more) and what their buttons do.


# ---- 1. idea

func _idea() -> void:
	var head: Label = _label("What do you want to play?", 50, 900, PAPER, W, HORIZONTAL_ALIGNMENT_CENTER)
	_place(head, Vector2(0, 112))
	var box: LineEdit = LineEdit.new()
	box.name = "Sentence"
	box.text = sentence
	box.placeholder_text = "Type your idea"
	box.add_theme_font_override("font", _font(700))
	box.add_theme_font_size_override("font_size", 32)
	box.add_theme_color_override("font_color", INK)
	box.add_theme_color_override("font_placeholder_color", Color(INK, 0.4))
	box.add_theme_color_override("caret_color", INK)
	var sb: StyleBoxFlat = _box(PAPER, INK, 5, 20, 10)
	sb.content_margin_left = 26.0
	sb.content_margin_right = 26.0
	box.add_theme_stylebox_override("normal", sb)
	var sbf: StyleBoxFlat = sb.duplicate()
	sbf.border_color = HONEY.darkened(0.3)
	box.add_theme_stylebox_override("focus", sbf)
	box.position = Vector2(110, 212)
	box.size = Vector2(860, 92)
	box.max_length = 240
	box.text_changed.connect(func(t: String) -> void: sentence = t)
	box.text_submitted.connect(func(_t: String) -> void: go())
	_body.add_child(box)
	_sentence_box = box
	var go_b: Button = _button("Go", "GO", "go", HONEY, Vector2(990, 212), Vector2(180, 92), 40)
	go_b.pressed.connect(go)
	_body.add_child(go_b)
	# surprise chips: a dice that walks the list, and the first five ideas
	var row: Array = []
	var dice: Button = _chip("Surprise", "Surprise me", "dice")
	dice.pressed.connect(func() -> void:
		pick_surprise(surprise_i)
		surprise_i = (surprise_i + 1) % Model.SURPRISES.size())
	row.append(dice)
	for i: int in 5:
		var c: Button = _chip("Chip%d" % i, str(Model.SURPRISES[i][0]), "")
		c.pressed.connect(pick_surprise.bind(i))
		row.append(c)
	var total: float = -12.0
	for c: Button in row:
		total += c.size.x + 12.0
	var x: float = (W - total) * 0.5
	for c: Button in row:
		c.position = Vector2(x, 332)
		x += c.size.x + 12.0
	# Standard / Crazy
	var std: Button = _switch("Standard", "Standard", "check", creativity == "standard", GREEN, Vector2(370, 430))
	std.pressed.connect(set_creativity.bind("standard"))
	var cr: Button = _switch("Crazy", "Crazy", "bolt", creativity == "crazy", CRAZY, Vector2(650, 430))
	cr.pressed.connect(set_creativity.bind("crazy"))
	var line: Label = _label(Model.CREATIVITY_LINE[creativity], 24, 600, CRAZY.lightened(0.35) if creativity == "crazy" else MUTED, W, HORIZONTAL_ALIGNMENT_CENTER)
	line.name = "CreativityLine"
	_place(line, Vector2(0, 520))
	# the expert drawer
	var more: Button = _button("Drawer", "More", "gear", NIGHT_DEEP.lightened(0.15), Vector2(24, 640), Vector2(150, 54), 22, PAPER)
	more.pressed.connect(func() -> void:
		drawer_open = not drawer_open
		_rebuild())
	_body.add_child(more)
	if drawer_open:
		_drawer()
	else:
		_margin_icons()


## The idea screen's margins: a few aspect icons that bob, the kinds of things a game can be made of.
func _margin_icons() -> void:
	var spots: Array = [["player", Vector2(34, 140), 58.0], ["ball", Vector2(70, 430), 50.0], ["twist", Vector2(1186, 128), 56.0],
		["vehicle", Vector2(1196, 440), 52.0], ["crowd", Vector2(1130, 560), 46.0], ["power", Vector2(200, 560), 44.0]]
	for sp: Array in spots:
		var ic: Icon = _icon(str(sp[0]), float(sp[2]), sp[1], _body)
		ic.set_meta("y0", (sp[1] as Vector2).y)
		ic.modulate = Color(1, 1, 1, 0.9)
		_alive.append(ic)


func _drawer() -> void:
	var p: Panel = Panel.new()
	p.name = "DrawerPanel"
	p.add_theme_stylebox_override("panel", _box(NIGHT_DEEP, MUTED, 3, 16))
	p.position = Vector2(190, 596)
	p.size = Vector2(900, 108)
	_body.add_child(p)
	# run-through: a keycap that stays down (the default is up: the build stops after each phase)
	var rt: Button = _button("RunThrough", "Build straight through", "check" if run_through else "pause", GREEN if run_through else CREAM, Vector2(18, 14), Vector2(360, 52), 21)
	rt.toggle_mode = true
	rt.button_pressed = run_through
	rt.toggled.connect(func(on: bool) -> void:
		run_through = on
		_rebuild())
	p.add_child(rt)
	var stops: Label = _label("No stops: you try it at the end" if run_through else "Stops after each phase to try it", 18, 500, MUTED)
	stops.name = "RunThroughLine"
	stops.position = Vector2(24, 74)
	p.add_child(stops)
	var rl: Label = _label("Recipe", 22, 800, PAPER)
	rl.position = Vector2(500, 26)
	p.add_child(rl)
	var ob: OptionButton = OptionButton.new()
	ob.name = "Recipe"
	ob.focus_mode = Control.FOCUS_NONE
	ob.add_theme_font_override("font", _font(750))
	ob.add_theme_font_size_override("font_size", 20)
	for st: String in ["normal", "hover", "pressed"]:
		var sb: StyleBoxFlat = _box(CREAM if st != "hover" else CREAM.lightened(0.1), INK, 3, 12, 6)
		sb.content_margin_left = 14.0
		ob.add_theme_stylebox_override(st, sb)
	ob.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for st: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		ob.add_theme_color_override(st, INK)
	ob.add_item("Designer picks")
	ob.set_item_metadata(0, "")
	var ids: Array = cards.keys()
	ids.sort()
	for id: String in ids:
		ob.add_item(str(cards[id]))
		ob.set_item_metadata(ob.item_count - 1, id)
		if id == card_hint:
			ob.select(ob.item_count - 1)
	ob.position = Vector2(590, 16)
	ob.size = Vector2(290, 52)
	ob.item_selected.connect(func(i: int) -> void: card_hint = str(ob.get_item_metadata(i)))
	p.add_child(ob)


func pick_surprise(i: int) -> void:
	sentence = str(Model.SURPRISES[i % Model.SURPRISES.size()][1])
	if _sentence_box != null:
		_sentence_box.text = sentence
		_sentence_box.caret_column = sentence.length()


func set_creativity(c: String) -> void:
	creativity = c
	_rebuild()


## The recipe hint goes as the card's proposed answers (`--answers`, JOB.md 2026-11-19): the only key `foreman new`
## has that names a card. {} when the Designer picks.
func hint_answers() -> Dictionary:
	if card_hint.is_empty():
		return {}
	var c: Variant = JobModel.read_json("res://cards/%s.json" % card_hint.trim_prefix("card."))
	var out: Dictionary = {}
	if c is Dictionary and (c as Dictionary).get("interview") is Dictionary:
		for q: Variant in ((c as Dictionary)["interview"] as Dictionary).get("questions", []):
			if q is Dictionary and (q as Dictionary).has("key") and (q as Dictionary).has("propose"):
				out[str(q["key"])] = str(q["propose"])
	return out


func go() -> void:
	var s: String = Door.clean_text(sentence)
	if s.is_empty():
		message = "Type an idea first, or tap one."
		_rebuild()
		return
	var err: String = door.new_game(s, hint_answers(), {}, [], {"creativity": creativity, "run_through": run_through})
	if not err.is_empty() and not door.dry:
		message = "The builders cannot start: " + err
		print("[create] GO: " + message)
		_rebuild()
		return
	if not door.dry:
		print("[create] GO: foreman new '%s' started" % s)
	message = ""
	waiting_for = s
	started_at = _now()
	busy = "new"
	_rebuild()


# ---- 2. designing

func _designing() -> void:
	var said: String = sentence if job.is_empty() else str(job.get("sentence", ""))
	var q: Label = _label("“%s”" % said, 40, 800, PAPER, 1080, HORIZONTAL_ALIGNMENT_CENTER)
	q.name = "Said"
	_place(q, Vector2(100, 120))
	var crazy: bool = (creativity if job.is_empty() else str(job.get("creativity", "standard"))) == "crazy"
	if crazy:
		_crazy_badge(Vector2(W * 0.5 - 60, 236), _body, 22)
	_icon_parade(312)
	var t: Label = _label("The designer is thinking", 34, 850, HONEY, W, HORIZONTAL_ALIGNMENT_CENTER)
	t.name = "Thinking"
	_place(t, Vector2(0, 470))
	_clock = _label(JobModel.fmt_time(_elapsed()), 30, 700, MUTED, W, HORIZONTAL_ALIGNMENT_CENTER)
	_clock.name = "Clock"
	_place(_clock, Vector2(0, 520))


## Fifteen aspect icons in a wave: something alive while a model works, and no progress figure it does not have.
func _icon_parade(y: float) -> void:
	var n: int = Icon.ASPECT_ICONS.size()
	var px: float = 64.0
	var gap: float = 14.0
	var x0: float = (W - (px * n + gap * (n - 1))) * 0.5
	for i: int in n:
		var ic: Icon = _icon(Icon.ASPECT_ICONS[i], px, Vector2(x0 + float(i) * (px + gap), y), _body)
		ic.set_meta("y0", y)
		_alive.append(ic)


# ---- 3. pitch + aspect cards

func _pitch() -> void:
	_title_row(84)
	var pitch: String = str(job.get("pitch", ""))
	if pitch.is_empty():                  # a brief before the designer v2: its sentence, in the player's words
		pitch = str(job.get("sentence", ""))
	var p: Label = _label(pitch, 34, 850, PAPER, 1180)
	p.name = "Pitch"
	_place(p, Vector2(50, 122))
	var list: Array = Model.cards_of(job)
	var n: int = list.size()
	var cols: int = 2 if n <= 4 else (3 if n <= 6 else 4)
	var rows: int = int(ceil(float(n) / float(cols)))
	var gap: float = 18.0
	var top: float = 226.0
	var avail: float = 620.0 - top
	var cw: float = (W - 80.0 - gap * float(cols - 1)) / float(cols)
	var ch: float = minf(190.0, (avail - gap * float(rows - 1)) / float(rows))
	for i: int in n:
		var r: int = i / cols
		var c: int = i % cols
		var in_row: int = mini(cols, n - r * cols)
		var x0: float = (W - (cw * float(in_row) + gap * float(in_row - 1))) * 0.5
		_card(list[i], Vector2(x0 + float(c) * (cw + gap), top + float(r) * (ch + gap)), Vector2(cw, ch))
	var hint: Label = _label("Tap a card to change it" if not (job.get("aspects", []) as Array).is_empty() else "", 22, 600, MUTED)
	hint.name = "Hint"
	_place(hint, Vector2(44, 656))
	var red: Button = _button("Redesign", "Redesign", "redo", CREAM, Vector2(W - 560, 636), Vector2(240, 70), 28)
	red.pressed.connect(redesign)
	_body.add_child(red)
	var build: Button = _button("BuildIt", "Build it", "hammer", HONEY, Vector2(W - 300, 636), Vector2(260, 70), 32)
	build.pressed.connect(build_it)
	_body.add_child(build)
	if not expanded.is_empty():
		_sheet()


func _title_row(y: float) -> void:
	var t: Label = _label(str(job.get("title", "")), 26, 900, HONEY)
	t.name = "Title"
	_place(t, Vector2(50, y - 10))
	if str(job.get("creativity", "standard")) == "crazy":
		var w: float = t.get_minimum_size().x
		_crazy_badge(Vector2(50 + w + 18, y - 8), _body, 18)


func _card(a: Dictionary, at: Vector2, sz: Vector2) -> void:
	var id: String = str(a.get("id", ""))
	var read_only: bool = bool(a.get("read_only", false))
	var choice: String = "keep" if read_only else Model.choice_of(job, taps, id)
	var f: Dictionary = Model.face(a, choice)
	var kind: String = str(f["kind"])
	# the hard shadow of a cel sticker
	var shadow: Panel = Panel.new()
	shadow.add_theme_stylebox_override("panel", _box(Color(0.05, 0.05, 0.12, 0.85), Color(0, 0, 0, 0), 0, 18))
	shadow.position = at + Vector2(7, 8)
	shadow.size = sz
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(shadow)
	var b: Button = Button.new()
	b.name = "Card_" + id
	b.position = at
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	var fill: Color = PAPER if kind == "keep" else (HONEY_LIGHT if kind == "swap" else Color("#b9bbd3"))
	var border: Color = CRAZY if bool(a.get("crazy", false)) and kind != "drop" else INK
	b.add_theme_stylebox_override("normal", _box(fill, border, 5, 18))
	b.add_theme_stylebox_override("hover", _box(fill.lightened(0.25), border, 5, 18))
	b.add_theme_stylebox_override("pressed", _box(fill.darkened(0.06), border, 5, 18))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if not read_only:
		b.pressed.connect(tap.bind(id))
	_body.add_child(b)
	var ipx: float = minf(72.0, sz.y * 0.42)
	var ic: Icon = _icon(str(a.get("icon", "story")), ipx, Vector2(16, 16), b)
	if kind == "drop":
		ic.modulate = Color(1, 1, 1, 0.45)
	var tw: float = sz.x - ipx - 44.0
	var title: Label = _label(str(f["title"]), 26 if sz.x > 330 else 23, 900, INK if kind != "drop" else Color(INK, 0.5), tw)
	title.name = "CardTitle"
	title.position = Vector2(ipx + 30, 14)
	b.add_child(title)
	var line: Label = _label(str(f["line"]), 19 if sz.x > 330 else 17, 560, Color(INK, 0.82 if kind != "drop" else 0.4), tw)
	line.name = "CardLine"
	line.position = Vector2(ipx + 30, 14 + title.get_minimum_size().y + 2)
	b.add_child(line)
	if kind == "drop":
		var strike: ColorRect = ColorRect.new()
		strike.color = RED
		strike.position = Vector2(ipx + 26, 14 + title.get_minimum_size().y * 0.55)
		strike.size = Vector2(minf(tw, _text_w(str(f["title"]), 26 if sz.x > 330 else 23, 900) + 8.0), 5)
		strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(strike)
		var x: Icon = Icon.new("cross", 40)
		x.bare = true
		x.glyph_color = RED
		x.position = Vector2(20 + ipx * 0.5 - 20, 16 + ipx * 0.5 - 20)
		x.size = Vector2(40, 40)
		b.add_child(x)
	elif kind == "swap":
		var sw: Icon = Icon.new("swap", 30)
		sw.disc = HONEY
		sw.position = Vector2(16 + ipx - 22, 16 + ipx - 22)
		sw.size = Vector2(30, 30)
		b.add_child(sw)
	# the choice dots: keep, each alternative, drop; the one that stands is big and filled
	if not read_only:
		var opts_: PackedStringArray = Model.choices(a)
		var dx: float = 22.0
		for k: int in opts_.size():
			var dot: Control = _dot(opts_[k], opts_[k] == choice)
			dot.position = Vector2(18 + float(k) * dx, sz.y - 30)
			b.add_child(dot)
		var more: Button = _button("More_" + id, "", "plus", CREAM, Vector2(sz.x - 54, sz.y - 54), Vector2(42, 42), 18)
		(more.get_theme_stylebox("normal") as StyleBoxFlat).border_width_bottom = 5
		for s: String in ["normal", "hover", "pressed"]:
			(more.get_theme_stylebox(s) as StyleBoxFlat).content_margin_left = 0
		var mi: Control = more.get_child(0)
		mi.custom_minimum_size = Vector2(24, 24)
		mi.position = Vector2(9, 7)
		mi.size = Vector2(24, 24)
		more.pressed.connect(expand.bind(id))
		b.add_child(more)
		if not Model.note_of(job, taps, id).is_empty():
			var nb: Icon = Icon.new("story", 26)
			nb.disc = HONEY
			nb.position = Vector2(sz.x - 88, sz.y - 46)
			nb.size = Vector2(26, 26)
			nb.name = "NoteMark"
			b.add_child(nb)
	if bool(a.get("crazy", false)):
		_crazy_badge(Vector2(sz.x - 178, sz.y - 46), b, 17)


func _dot(choice: String, on: bool) -> Control:
	var d: Icon = Icon.new("cross" if choice == "drop" else "dot", 16)
	d.size = Vector2(16, 16)
	if choice == "drop":
		d.bare = true
		d.glyph_color = RED if on else Color(INK, 0.3)
		d.scale = Vector2(1.15, 1.15) if on else Vector2(0.8, 0.8)
	else:
		d.disc = (GREEN if choice == "keep" else HONEY) if on else Color(1, 1, 1, 0.01)
		d.ink = INK if on else Color(INK, 0.35)
		d.bare = false
		if on:
			d.scale = Vector2(1.25, 1.25)
			d.position -= Vector2(2, 2)
	return d


## One tap: keep -> each alternative -> drop -> keep.
func tap(aspect_id: String) -> void:
	for a: Variant in job.get("aspects", []):
		if a is Dictionary and str((a as Dictionary).get("id", "")) == aspect_id:
			var t: Dictionary = (taps.get(aspect_id, {}) as Dictionary).duplicate()
			t["choice"] = Model.next_choice(a, Model.choice_of(job, taps, aspect_id))
			taps[aspect_id] = t
	_rebuild()


func choose(aspect_id: String, choice: String) -> void:
	var t: Dictionary = (taps.get(aspect_id, {}) as Dictionary).duplicate()
	t["choice"] = choice
	taps[aspect_id] = t
	_rebuild()


func expand(aspect_id: String) -> void:
	expanded = aspect_id
	_rebuild()


func _sheet() -> void:
	var a: Dictionary = {}
	for x: Variant in job.get("aspects", []):
		if x is Dictionary and str((x as Dictionary).get("id", "")) == expanded:
			a = x
	if a.is_empty():
		expanded = ""
		return
	var scrim: Button = Button.new()
	scrim.name = "Scrim"
	scrim.focus_mode = Control.FOCUS_NONE
	scrim.add_theme_stylebox_override("normal", _box(Color(0.05, 0.05, 0.12, 0.72), Color(0, 0, 0, 0), 0, 0))
	scrim.add_theme_stylebox_override("hover", _box(Color(0.05, 0.05, 0.12, 0.72), Color(0, 0, 0, 0), 0, 0))
	scrim.add_theme_stylebox_override("pressed", _box(Color(0.05, 0.05, 0.12, 0.72), Color(0, 0, 0, 0), 0, 0))
	scrim.position = Vector2.ZERO
	scrim.size = Vector2(W, H)
	scrim.pressed.connect(close_sheet)
	_body.add_child(scrim)
	var p: Panel = Panel.new()
	p.name = "Sheet"
	p.add_theme_stylebox_override("panel", _box(PAPER, CRAZY if bool(a.get("crazy", false)) else INK, 6, 22, 12))
	p.position = Vector2(170, 90)
	p.size = Vector2(940, 560)
	_body.add_child(p)
	_icon(str(a.get("icon", "story")), 96, Vector2(30, 28), p)
	var t: Label = _label(str(a.get("title", "")), 40, 900, INK)
	t.position = Vector2(146, 36)
	p.add_child(t)
	if bool(a.get("crazy", false)):
		_crazy_badge(Vector2(146 + t.get_minimum_size().x + 20, 44), p, 18)
	var d: Label = _label(str(a.get("detail", "")), 22, 520, Color(INK, 0.86), 860)
	d.name = "Detail"
	d.position = Vector2(40, 146)
	p.add_child(d)
	var choice: String = Model.choice_of(job, taps, expanded)
	var opts_: PackedStringArray = Model.choices(a)
	# one key per choice: keep and drop are words; an alternative shows its title and its line
	var bw: float = (860.0 - 14.0 * float(opts_.size() - 1)) / float(opts_.size())
	for k: int in opts_.size():
		var o: String = opts_[k]
		var label: String = "Keep" if o == "keep" else ("Drop" if o == "drop" else str(Model.face(a, o)["title"]))
		var col: Color = (GREEN if o == "keep" else (RED if o == "drop" else HONEY)) if o == choice else CREAM
		var b: Button = _button("Pick_" + o, "", "check" if o == choice else "", col, Vector2(40 + float(k) * (bw + 14.0), 290), Vector2(bw, 128), 21)
		b.pressed.connect(choose.bind(expanded, o))
		p.add_child(b)
		var left: float = 50.0 if o == choice else 16.0
		var tl: Label = _label(label, 21, 900, INK, bw - left - 10.0)
		tl.position = Vector2(left, 10)
		b.add_child(tl)
		if o != "keep" and o != "drop":
			var ll: Label = _label(str(Model.face(a, o)["line"]), 17, 560, Color(INK, 0.8), bw - left - 12.0)
			ll.position = Vector2(left, 14 + tl.get_minimum_size().y)
			b.add_child(ll)
		var glyph: Node = b.get_child(0) if b.get_child_count() > 0 and b.get_child(0) is Icon else null
		if glyph != null:
			(glyph as Control).custom_minimum_size = Vector2(28, 28)
			(glyph as Control).position = Vector2(14, 14)
			(glyph as Control).size = Vector2(28, 28)
	var nb: LineEdit = LineEdit.new()
	nb.name = "Note"
	nb.placeholder_text = "Your note for the designer"
	nb.text = Model.note_of(job, taps, expanded)
	nb.add_theme_font_override("font", _font(600))
	nb.add_theme_font_size_override("font_size", 22)
	nb.add_theme_color_override("font_color", INK)
	nb.add_theme_color_override("font_placeholder_color", Color(INK, 0.4))
	var sb: StyleBoxFlat = _box(Color.WHITE, INK, 3, 12)
	sb.content_margin_left = 16.0
	nb.add_theme_stylebox_override("normal", sb)
	nb.add_theme_stylebox_override("focus", sb)
	nb.position = Vector2(40, 446)
	nb.size = Vector2(600, 60)
	nb.max_length = 200
	nb.text_changed.connect(func(text: String) -> void:
		var t2: Dictionary = (taps.get(expanded, {"choice": Model.choice_of(job, taps, expanded)}) as Dictionary).duplicate()
		t2["note"] = text
		taps[expanded] = t2
		_sig = _signature())
	p.add_child(nb)
	_note_box = nb
	var ok: Button = _button("SheetDone", "Done", "check", HONEY, Vector2(670, 442), Vector2(230, 68), 28)
	ok.pressed.connect(close_sheet)
	p.add_child(ok)


func close_sheet() -> void:
	expanded = ""
	_rebuild()


func redesign() -> void:
	if job_dir.is_empty():
		return
	var err: String = door.redesign(job_dir, Model.pending(job, taps))
	if not err.is_empty() and not door.dry:
		message = err
	else:
		message = ""
		busy = "redesign"
		busy_mark = int(job.get("briefs", 0))
	_rebuild()


func build_it() -> void:
	if job_dir.is_empty():
		return
	var err: String = door.approve_v2(job_dir, Model.pending(job, taps))
	if not err.is_empty() and not door.dry:
		message = err
	else:
		message = ""
		busy = "approve"
	_rebuild()
