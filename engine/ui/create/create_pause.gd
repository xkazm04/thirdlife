extends "res://ui/create/create_build.gd"
## E4b (night of 24-25 Nov 2026): the Create page, the pauses a person answers. E5 (real jobs) was stuck twice: a builder
## asked a question and Create showed "Paused" with no way out; a look the critic still found weak held the job
## (`paused: quality`) and Continue ran `resume`, which leaves a hold as it is. Here, over the building screen:
##   a builder's question   the question in plain words, its options as chips (create_model.gd question_options), an
##                          answer box; Answer sends `foreman answer <job> <package> "<words>"` then `resume`
##                          (foreman_door.gd answer: the builder's next round reads the answer)
##   a quality hold         what the critic saw (its reasons, the still it judged) and three choices: Fix it (`foreman
##                          quality <job> retry`: one more revise round, to the package the quality loop names), It's
##                          fine, go on (`quality accept`), Change it (accept + `foreman change` with the person's words)

var _answer_box: LineEdit = null
var _answer_draft: String = ""
var _answer_change: String = ""           # E4c: the package the "Yes, let it" chip allows to change (`answer --change`)
var _q_changing: bool = false             # the quality card's change box is open
var _q_draft: String = ""


func _pause_card() -> bool:
	if str(job.get("phase", "")) != "paused" or busy in ["answer", "quality"]:
		return false
	match str(job.get("pause_kind", "")):
		"question":
			var q: Dictionary = Model.open_question(job)
			if q.is_empty():
				return false
			_question_card(q)
			return true
		"quality":
			var v: Dictionary = Model.quality_view(job)
			if v.is_empty():
				return false
			_quality_card(v)
			return true
	return false


func _card_panel(name_: String, border: Color) -> Panel:
	var card: Panel = Panel.new()
	card.name = name_
	card.add_theme_stylebox_override("panel", _box(PAPER, border, 6, 26, 14))
	card.position = Vector2(90, 262)
	card.size = Vector2(1100, 420)
	_body.add_child(card)
	return card


func _wrapped(text: String, px: int, weight: int, color: Color, at: Vector2, width: float, lines: int, parent: Control) -> Label:
	var l: Label = _label(text, px, weight, color, width)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = lines
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(width, 0)
	l.size = Vector2(width, 0)
	l.position = at
	parent.add_child(l)
	return l


func _box_line(name_: String, placeholder: String, draft: String, at: Vector2, width: float, parent: Control) -> LineEdit:
	var b: LineEdit = LineEdit.new()
	b.name = name_
	b.placeholder_text = placeholder
	b.text = draft
	b.add_theme_font_override("font", _font(650))
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_placeholder_color", Color(INK, 0.45))
	var sb: StyleBoxFlat = _box(Color.WHITE, ORANGE.darkened(0.2), 4, 14)
	sb.content_margin_left = 18.0
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("focus", sb)
	b.position = at
	b.size = Vector2(width, 74)
	b.max_length = 400
	parent.add_child(b)
	return b


# ---- a builder's question

func _question_card(q: Dictionary) -> void:
	var card: Panel = _card_panel("QuestionCard", BLUE)
	_icon("story", 64, Vector2(30, 24), card)
	var h: Label = _label("A builder asks you", 34, 950, INK, 900)
	h.name = "AskTitle"
	h.position = Vector2(110, 22)
	card.add_child(h)
	var who: Label = _label("about “%s”" % str(q["title"]), 20, 700, Color(INK, 0.6), 900)
	who.position = Vector2(112, 66)
	card.add_child(who)
	var text: Label = _wrapped(str(q["text"]), 22, 650, INK, Vector2(40, 108), 1020, 4, card)
	text.name = "Question"
	var opts: PackedStringArray = Model.question_options(str(q["text"]))
	var x: float = 40.0
	var widen: String = Model.scope_package(job, q)
	if not widen.is_empty():
		# E4c: a question that asks for a package's scope: one chip says yes (`foreman answer ... --change <package>`)
		var yes: Button = _button("LetIt", "Yes, let it", "check", GREEN, Vector2(x, 234), Vector2(220, 52), 20)
		yes.tooltip_text = "Let “%s” change those files" % widen
		yes.pressed.connect(func() -> void:
			pick_option("Yes, let it change what it needs.")
			_answer_change = widen)
		card.add_child(yes)
		x += 234.0
	var n: int = mini(opts.size(), 3) if widen.is_empty() else 0      # a scope question: its yes is the chip, the rest is words
	for i: int in n:
		var w: float = minf(minf(500.0, 70.0 + _text_w(opts[i], 20, 800)), (1060.0 - x) / float(n - i) - 14.0)
		var chip: Button = _button("Option%d" % i, JobModel.one_line(opts[i], 48), "", HONEY_LIGHT, Vector2(x, 234), Vector2(w, 52), 20)
		chip.clip_text = true
		chip.size = Vector2(w, 52)                  # again: the size set before clip_text was held to the text's width
		chip.pressed.connect(pick_option.bind(opts[i]))
		card.add_child(chip)
		x += w + 14.0
	_answer_box = _box_line("AnswerBox", "Your answer, in your own words", _answer_draft, Vector2(40, 310), 760, card)
	_answer_box.text_changed.connect(func(t: String) -> void: _answer_draft = t)
	_answer_box.text_submitted.connect(func(_t: String) -> void: send_answer())
	var send: Button = _button("SendAnswer", "Answer", "go", GREEN, Vector2(820, 310), Vector2(240, 74), 30)
	send.pressed.connect(send_answer)
	card.add_child(send)


func pick_option(text: String) -> void:
	_answer_draft = text
	_answer_change = ""
	if _answer_box != null:
		_answer_box.text = text


func send_answer() -> void:
	var q: Dictionary = Model.open_question(job)
	var text: String = Door.clean_text(_answer_box.text if _answer_box != null else _answer_draft)
	if q.is_empty() or text.is_empty():
		message = "Write the answer first, or tap one."
		_rebuild()
		return
	var err: String = door.answer(job_dir, str(q["package"]), text, _answer_change, door.foreman_alive(job_dir, int(job.get("lock_pid", 0))))
	if not err.is_empty() and not door.dry:
		message = err
	else:
		message = ""
		busy = "answer"
		busy_mark = int(q["seq"])
		_answer_draft = ""
		print("[create] answer to %s: %s%s" % [str(q["package"]), text, (" (--change %s)" % _answer_change) if not _answer_change.is_empty() else ""])
		_answer_change = ""
	_rebuild()


# ---- a quality hold

func _quality_card(v: Dictionary) -> void:
	var card: Panel = _card_panel("QualityCard", ORANGE)
	var h: Label = _label("The critic is not happy yet", 34, 950, INK, 640)
	h.name = "QualityTitle"
	h.position = Vector2(40, 22)
	card.add_child(h)
	var still_w: float = 0.0
	if not str(v["still"]).is_empty():
		var img: Image = Image.load_from_file(str(v["still"]))
		if img != null and not img.is_empty():
			var tr: TextureRect = TextureRect.new()
			tr.name = "Still"
			tr.texture = ImageTexture.create_from_image(img)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.position = Vector2(740, 20)
			tr.size = Vector2(340, 192)
			card.add_child(tr)
			still_w = 360.0
	var y: float = 78.0
	var reasons: PackedStringArray = v["reasons"]
	if reasons.is_empty():
		reasons = ["It still looks weak after two tries."]
	for i: int in reasons.size():
		var r: Label = _wrapped("• " + reasons[i], 21, 650, INK, Vector2(40, y), 1020.0 - still_w, 2, card)
		r.name = "Reason%d" % i
		y += 46.0
	if _q_changing:
		var cb: LineEdit = _box_line("QualityChange", "What should be different? In your words", _q_draft, Vector2(40, 310), 760, card)
		cb.text_changed.connect(func(t: String) -> void: _q_draft = t)
		cb.text_submitted.connect(func(_t: String) -> void: send_quality_change())
		var send: Button = _button("SendQualityChange", "Change it", "redo", ORANGE, Vector2(820, 310), Vector2(240, 74), 28)
		send.pressed.connect(send_quality_change)
		card.add_child(send)
		return
	var fix: Button = _button("FixIt", "Fix it", "redo", ORANGE, Vector2(40, 310), Vector2(300, 84), 30)
	fix.tooltip_text = "One more try by the builders, with the critic's notes"
	fix.pressed.connect(quality_answer.bind("retry"))
	card.add_child(fix)
	var fine: Button = _button("ItsFine", "It's fine, go on", "check", GREEN, Vector2(360, 310), Vector2(360, 84), 28)
	fine.pressed.connect(quality_answer.bind("accept"))
	card.add_child(fine)
	var ch: Button = _button("ChangeIt", "Change it", "plus", CREAM, Vector2(740, 310), Vector2(320, 84), 28)
	ch.pressed.connect(func() -> void:
		_q_changing = true
		_rebuild())
	card.add_child(ch)


func quality_answer(verdict: String) -> void:
	var note: String = "the person asks for one more try" if verdict == "retry" else "the person plays it as it is"
	var err: String = door.quality(job_dir, verdict, note, door.foreman_alive(job_dir, int(job.get("lock_pid", 0))))
	_after_quality(err)


func send_quality_change() -> void:
	var text: String = Door.clean_text(_q_draft)
	if text.is_empty():
		message = "Say what should be different first."
		_rebuild()
		return
	_after_quality(door.quality_change(job_dir, text, door.foreman_alive(job_dir, int(job.get("lock_pid", 0)))))


func _after_quality(err: String) -> void:
	if not err.is_empty() and not door.dry:
		message = err
	else:
		message = ""
		busy = "quality"
		_q_changing = false
		_q_draft = ""
	_rebuild()


# ---- E4c: the phase pause's measured figures (a game on a core)

func _measured_card(v: Dictionary, at: Vector2, sz: Vector2) -> void:
	var defects: Array = v["defects"]
	var card: Panel = Panel.new()
	card.name = "MeasuredCard"
	card.add_theme_stylebox_override("panel", _box(PAPER, RED if not defects.is_empty() else GREEN, 6, 26, 14))
	card.position = at
	card.size = sz
	_body.add_child(card)
	var t: Label = _label("Measured", 30, 950, INK, sz.x - 60)
	t.position = Vector2(30, 22)
	card.add_child(t)
	var sub: Label = _label("bots played it, beside hokej", 18, 700, Color(INK, 0.6), sz.x - 60)
	sub.position = Vector2(30, 62)
	card.add_child(sub)
	if not bool(v["measured"]):
		_wrapped("It could not be measured this time.", 22, 700, Color(INK, 0.7), Vector2(30, 110), sz.x - 60, 2, card)
		return
	var rows: Array = [["Goals", "a match", float(v["goals"]), float(v["house_goals"]), ""], ["Match", "lasts", float(v["minutes"]), float(v["house_minutes"]), " min"]]
	var y: float = 104.0
	for i: int in rows.size():
		var r: Array = rows[i]
		var big: Label = _label(("%s %s: %s" % [r[0], r[1], _fig(float(r[2]), str(r[4]))]), 24, 850, INK, sz.x - 60)
		big.name = "Measured%d" % i
		big.position = Vector2(30, y)
		card.add_child(big)
		var house: Label = _label("hokej: %s" % _fig(float(r[3]), str(r[4])), 19, 700, Color(INK, 0.6), sz.x - 60)
		house.name = "House%d" % i
		house.position = Vector2(30, y + 34)
		card.add_child(house)
		y += 78.0
	for i: int in mini(2, defects.size()):
		var d: Label = _wrapped(str(defects[i]), 19, 800, RED.darkened(0.15), Vector2(30, y), sz.x - 60, 2, card)
		d.name = "Defect%d" % i
		y += 52.0


func _fig(x: float, unit: String) -> String:
	if x < 0.0:
		return "?"
	return ("%.1f" % x).trim_suffix(".0") + unit
