extends "res://ui/create/create_design.gd"

const Dungeons = preload("res://kernel/dungeon/dungeons.gd")
## L3 (night of 21 Nov 2026): the Create page, part 3 of 4: the screens of the build (the phase strip, phase done with
## Try it / Pass / Hold, done, failed, error) and what their buttons do.


# ---- 4. building

func _building() -> void:
	_title_row(84)
	_clock = _label(JobModel.fmt_time(_elapsed()), 24, 700, MUTED, 200, HORIZONTAL_ALIGNMENT_RIGHT)
	_clock.name = "Clock"
	_place(_clock, Vector2(W - 250, 84))
	var s: Array = Model.strip(job)
	if s.is_empty():
		_icon_parade(250)
		var t: Label = _label("Planning the phases", 34, 850, HONEY, W, HORIZONTAL_ALIGNMENT_CENTER)
		t.name = "Planning"
		_place(t, Vector2(0, 400))
		return
	_strip(s, 140.0, 104.0)
	var k: int = int(job.get("phase_now", -1))
	if k < 0 or k >= s.size():
		# every phase passed: the Foreman plays the whole game through once more before it hands it over
		var last: Control = _callout("Last check, then it is yours", Vector2(50, 278), "check", GREEN)
		last.name = "LastCheck"
		_icon_parade(400)
		_design_row(616)
		return
	var cur: Dictionary = s[k]
	if not str(cur["try"]).is_empty():
		var call: Control = _callout("Soon: " + str(cur["try"]), Vector2(50, 278), "play")
		call.name = "TryLine"
	var pk: Array = Model.phase_packages(job)
	var n: int = pk.size()
	var tw: float = minf(360.0, (W - 100.0 - 20.0 * float(n - 1)) / maxf(1.0, float(n)))
	var x0: float = (W - (tw * float(n) + 20.0 * float(n - 1))) * 0.5
	for i: int in n:
		_package_tile(pk[i], Vector2(x0 + float(i) * (tw + 20.0), 392), Vector2(tw, 150))
	_design_row(616)
	if str(job.get("phase", "")) == "paused" and str(job.get("pause_kind", "")) != "phase":
		var why: String = "the builder asks a question" if str(job.get("pause_kind", "")) == "question" else JobModel.one_line(str(job.get("job_reason", "")), 70)
		_callout("Paused: " + why, Vector2(50, 556), "pause", ORANGE)
	elif str(cur["state"]) == "held":
		_callout("Changing: " + JobModel.one_line(str(cur["note"]), 80), Vector2(50, 556), "redo", ORANGE)


## The design being built: one small chip per aspect that was not dropped (its chosen face), so the player sees what
## the phases add up to.
func _design_row(y: float) -> void:
	var items: Array = []
	for a: Variant in job.get("aspects", []):
		if a is Dictionary:
			var c: String = Model.choice_of(job, {}, str((a as Dictionary).get("id", "")))
			if c != "drop":
				items.append([str((a as Dictionary).get("icon", "story")), str(Model.face(a, c)["title"]), bool((a as Dictionary).get("crazy", false))])
	if items.is_empty():
		return
	var chips: Array = []
	var total: float = -12.0
	for it: Array in items:
		var w: float = 62.0 + _text_w(str(it[1]), 18, 800)
		chips.append(w)
		total += w + 12.0
	var x: float = (W - total) * 0.5
	for i: int in items.size():
		var it: Array = items[i]
		var p: Panel = Panel.new()
		p.name = "Design%d" % i
		p.add_theme_stylebox_override("panel", _box(NIGHT_DEEP.lightened(0.12), CRAZY if bool(it[2]) else NIGHT_LINE.lightened(0.3), 3, 24))
		p.position = Vector2(x, y)
		p.size = Vector2(float(chips[i]), 48)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body.add_child(p)
		var ic: Icon = Icon.new(str(it[0]), 36)
		ic.position = Vector2(6, 6)
		ic.size = Vector2(36, 36)
		p.add_child(ic)
		var l: Label = _label(str(it[1]), 18, 800, PAPER)
		l.position = Vector2(50, 11)
		p.add_child(l)
		x += float(chips[i]) + 12.0


## The phase strip: one chip per phase, joined by a rail; colour for state, a glyph for passed and held.
func _strip(s: Array, y: float, h: float) -> void:
	var n: int = s.size()
	var gap: float = 26.0
	var cw: float = (W - 100.0 - gap * float(n - 1)) / float(n)
	var rail: ColorRect = ColorRect.new()
	rail.color = NIGHT_LINE.lightened(0.2)
	rail.position = Vector2(80, y + h * 0.5 - 4)
	rail.size = Vector2(W - 160, 8)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(rail)
	for i: int in n:
		var e: Dictionary = s[i]
		var st: String = str(e["state"])
		var col: Color = STATE_COLOR.get(st, GREY)
		var chip: Panel = Panel.new()
		chip.name = "Phase%d" % (i + 1)
		var on: bool = bool(e["current"]) or st == "done"
		chip.add_theme_stylebox_override("panel", _box(col if st != "next" else NIGHT_DEEP.lightened(0.1), INK if st != "next" else GREY, 5 if on else 4, 18, 10 if on else 4))
		chip.position = Vector2(50 + float(i) * (cw + gap), y)
		chip.size = Vector2(cw, h)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body.add_child(chip)
		var glyph: String = {"passed": "check", "held": "hold", "done": "play"}.get(st, "")
		var num: Icon = Icon.new(glyph if not glyph.is_empty() else "dot", 52)
		num.disc = PAPER if st != "next" else NIGHT_DEEP
		num.ink = INK if st != "next" else GREY
		num.position = Vector2(16, (h - 52) * 0.5 - 3)
		num.size = Vector2(52, 52)
		chip.add_child(num)
		if glyph.is_empty():
			var nl: Label = _label(str(e["n"]), 30, 900, INK if st != "next" else GREY, 52, HORIZONTAL_ALIGNMENT_CENTER)
			nl.position = Vector2(16, (h - 52) * 0.5 + 4)
			chip.add_child(nl)
		var tl: Label = _label(str(e["title"]), 25 if cw > 300 else 21, 900, INK if st != "next" else MUTED, cw - 96)
		tl.name = "PhaseTitle"
		tl.position = Vector2(82, (h - tl.get_minimum_size().y) * 0.5 - 4)
		chip.add_child(tl)
		if st == "building" or st == "held":
			# a ring around the chip breathes while its phase is built (the chip itself stays solid)
			var aura: Panel = Panel.new()
			aura.name = "Aura%d" % (i + 1)
			var asb: StyleBoxFlat = _box(Color(0, 0, 0, 0), col.lightened(0.35), 5, 24)
			aura.add_theme_stylebox_override("panel", asb)
			aura.position = chip.position - Vector2(9, 9)
			aura.size = chip.size + Vector2(18, 18)
			aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_body.add_child(aura)
			_body.move_child(aura, chip.get_index())
			_pulse.append(aura)


func _package_tile(p: Dictionary, at: Vector2, sz: Vector2) -> void:
	var st: String = str(p["state"])
	var col: Color = STATE_COLOR.get(st, GREY)
	var tile: Panel = Panel.new()
	tile.name = "Pkg_" + str(p["id"])
	tile.add_theme_stylebox_override("panel", _box(PAPER, INK, 4, 16, 8))
	tile.position = at
	tile.size = sz
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(tile)
	var band: Panel = Panel.new()
	var bsb: StyleBoxFlat = _box(col, INK, 0, 0)
	bsb.corner_radius_top_left = 14
	bsb.corner_radius_bottom_left = 14
	band.add_theme_stylebox_override("panel", bsb)
	band.position = Vector2(4, 4)
	band.size = Vector2(18, sz.y - 12)
	tile.add_child(band)
	var glyph: String = {"promoted": "check", "failed": "cross", "blocked": "hold", "queued": "time"}.get(st, "build")
	var ic: Icon = Icon.new(glyph, 54)
	ic.disc = col
	ic.position = Vector2(36, 18)
	ic.size = Vector2(54, 54)
	tile.add_child(ic)
	if st in ["running", "verifying"]:
		ic.set_meta("y0", 18.0)
		_alive.append(ic)
	var tl: Label = _label(str(p["title"]), 23, 850, INK, sz.x - 120)
	tl.position = Vector2(104, 18)
	tile.add_child(tl)
	var word: String = {"promoted": "Done", "running": "Building", "verifying": "Checking", "queued": "Waiting", "blocked": "Waiting", "failed": "Failed"}.get(st, st)
	if int(p["round"]) > 1 and st in ["running", "verifying", "queued"]:
		word += " again"
	var wl: Label = _label(word, 20, 700, col.darkened(0.35))
	wl.position = Vector2(36, sz.y - 46)
	tile.add_child(wl)


# ---- 5. phase done

func _phase_done() -> void:
	_title_row(84)
	var s: Array = Model.strip(job)
	_strip(s, 128.0, 84.0)
	var e: Dictionary = Model.waiting(job)
	var card: Panel = Panel.new()
	card.name = "PhaseCard"
	card.add_theme_stylebox_override("panel", _box(PAPER, INK, 6, 26, 14))
	card.position = Vector2(140, 250)
	card.size = Vector2(1000, 400)
	_body.add_child(card)
	var ready: Label = _label("Phase %d is ready!" % int(e.get("n", 0)), 46, 950, INK, 920, HORIZONTAL_ALIGNMENT_CENTER)
	ready.name = "Ready"
	ready.position = Vector2(40, 30)
	card.add_child(ready)
	var tr: Label = _label(str(e.get("try", "")), 30, 700, Color(INK, 0.85), 860, HORIZONTAL_ALIGNMENT_CENTER)
	tr.name = "Try"
	tr.position = Vector2(70, 104)
	card.add_child(tr)
	if holding:
		var nb: LineEdit = LineEdit.new()
		nb.name = "HoldNote"
		nb.placeholder_text = "What should change?"
		nb.add_theme_font_override("font", _font(650))
		nb.add_theme_font_size_override("font_size", 26)
		nb.add_theme_color_override("font_color", INK)
		nb.add_theme_color_override("font_placeholder_color", Color(INK, 0.4))
		var sb: StyleBoxFlat = _box(Color.WHITE, ORANGE.darkened(0.2), 4, 14)
		sb.content_margin_left = 18.0
		nb.add_theme_stylebox_override("normal", sb)
		nb.add_theme_stylebox_override("focus", sb)
		nb.position = Vector2(60, 236)
		nb.size = Vector2(560, 84)
		nb.max_length = 240
		nb.text_submitted.connect(func(_t: String) -> void: send_hold())
		card.add_child(nb)
		_note_box = nb
		var send: Button = _button("SendHold", "Send", "go", ORANGE, Vector2(640, 236), Vector2(170, 84), 30)
		send.pressed.connect(send_hold)
		card.add_child(send)
		var back: Button = _button("CancelHold", "", "back", CREAM, Vector2(830, 236), Vector2(110, 84), 30)
		back.pressed.connect(func() -> void:
			holding = false
			_rebuild())
		card.add_child(back)
		return
	var tb: Button = _button("TryIt", "Try it", "play", HONEY, Vector2(60, 236), Vector2(330, 110), 40)
	tb.pressed.connect(try_it)
	card.add_child(tb)
	var pb: Button = _button("Pass", "Pass", "check", GREEN, Vector2(420, 236), Vector2(250, 110), 40)
	pb.pressed.connect(pass_phase)
	card.add_child(pb)
	var hb: Button = _button("Hold", "Hold", "hold", ORANGE, Vector2(700, 236), Vector2(240, 110), 40)
	hb.pressed.connect(func() -> void:
		holding = true
		_rebuild()
		if _note_box != null:
			_note_box.grab_focus())
	card.add_child(hb)


func try_it() -> void:
	launch(Model.try_dir(job))


func pass_phase() -> void:
	var e: Dictionary = Model.waiting(job)
	var err: String = door.phase(job_dir, "pass", "", door.foreman_alive(job_dir, int(job.get("lock_pid", 0))))
	_after_phase(err, e)


func send_hold() -> void:
	var note: String = _note_box.text if _note_box != null else ""
	if Door.clean_text(note).is_empty():
		message = "Say what should change first."
		_rebuild()
		return
	var e: Dictionary = Model.waiting(job)
	var err: String = door.phase(job_dir, "hold", note, door.foreman_alive(job_dir, int(job.get("lock_pid", 0))))
	_after_phase(err, e)


func _after_phase(err: String, _e: Dictionary) -> void:
	if not err.is_empty() and not door.dry:
		message = err
	else:
		message = ""
		busy = "phase"
		busy_mark = (job.get("phase_events", []) as Array).size()
		holding = false
	_rebuild()


## A second game process with the pack as a dungeon (COMMON "Try-it seam"; L4's kernel/dungeon/dungeons.gd owns it).
func launch(pack_dir: String) -> void:
	var dir: String = pack_dir
	if not FileAccess.file_exists(dir.path_join("pack.json")) and opts.has("try_stub"):
		dir = str(opts["try_stub"])
	if not FileAccess.file_exists(dir.path_join("pack.json")):
		message = "Nothing to play yet: no pack at %s" % dir
		_rebuild()
		return
	last_launch = Dungeons.launch_args(dir)
	if door.dry:
		print("[create] launch (dry): %s %s" % [OS.get_executable_path(), " ".join(last_launch)])
		return
	var pid: int = Dungeons.launch(dir)        # L4's seam: a second process of this executable, --dungeon=<dir>
	message = "" if pid > 0 else "The game could not be started."
	_rebuild()


# ---- 6. done, failed, error

func _done() -> void:
	# the game's own aspects in an arc over the title (a stock ring for a job without aspects)
	var ring: Array = []
	for a: Variant in job.get("aspects", []):
		if a is Dictionary and Model.choice_of(job, {}, str((a as Dictionary).get("id", ""))) != "drop":
			ring.append(str((a as Dictionary).get("icon", "story")))
	if ring.is_empty():
		ring = ["player", "goal", "power", "crowd", "music", "arena", "twist"]
	var n: int = ring.size()
	for i: int in n:
		var a: float = deg_to_rad(-160.0 + 140.0 * (float(i) / maxf(1.0, float(n - 1))))
		var ic: Icon = _icon(ring[i], 78, Vector2(W * 0.5 - 39 + cos(a) * 480.0, 300 + sin(a) * 210.0), _body)
		ic.set_meta("y0", ic.position.y)
		_alive.append(ic)
	var t: Label = _label("Your game is ready", 62, 950, HONEY, W, HORIZONTAL_ALIGNMENT_CENTER)
	t.name = "Ready"
	_place(t, Vector2(0, 290))
	var title: Label = _label(str(job.get("title", "")), 36, 800, PAPER, W, HORIZONTAL_ALIGNMENT_CENTER)
	title.name = "GameTitle"
	_place(title, Vector2(0, 378))
	var play: Button = _button("Play", "Play", "play", HONEY, Vector2(W * 0.5 - 170, 470), Vector2(340, 120), 50)
	play.pressed.connect(func() -> void: launch(Model.play_dir(job)))
	_body.add_child(play)


func _failed() -> void:
	var card: Panel = Panel.new()
	card.name = "FailCard"
	card.add_theme_stylebox_override("panel", _box(PAPER, RED, 6, 26, 14))
	card.position = Vector2(190, 170)
	card.size = Vector2(900, 380)
	_body.add_child(card)
	var ic: Icon = Icon.new("cross", 96)
	ic.disc = RED
	ic.position = Vector2(402, 30)
	ic.size = Vector2(96, 96)
	card.add_child(ic)
	var designing: bool = (job.get("brief", {}) as Dictionary).is_empty()
	var t: Label = _label("The designer got stuck" if designing else "This build stopped", 46, 950, INK, 820, HORIZONTAL_ALIGNMENT_CENTER)
	t.name = "Stopped"
	t.position = Vector2(40, 146)
	card.add_child(t)
	# in a person's words: the part that could not be made, by its title (no package ids, no causes)
	var why: String = str(job.get("job_reason", ""))
	for id: Variant in job.get("order", []):
		var p: Dictionary = (job.get("packages", {}) as Dictionary).get(str(id), {})
		if str(p.get("state", "")) == "failed" and str(p.get("cause", "")) != "cancelled":
			why = "The builders could not get \u201c%s\u201d to work." % str(p.get("title", id))
			break
	var w: Label = _label(JobModel.one_line(why, 90), 22, 600, Color(INK, 0.75), 820, HORIZONTAL_ALIGNMENT_CENTER)
	w.name = "Why"
	w.position = Vector2(40, 214)
	card.add_child(w)
	var again: Button = _button("TryAgain", "Try again", "redo", HONEY, Vector2(300, 280), Vector2(300, 76), 30)
	again.pressed.connect(func() -> void:
		sentence = str(job.get("sentence", sentence))
		creativity = str(job.get("creativity", creativity))
		new_idea())
	card.add_child(again)


func _error() -> void:
	var t: Label = _label("This game cannot be read", 44, 950, PAPER, W, HORIZONTAL_ALIGNMENT_CENTER)
	t.name = "Unreadable"
	_place(t, Vector2(0, 260))
	var w: Label = _label(JobModel.one_line(str(job.get("error", "")), 90), 22, 600, MUTED, W, HORIZONTAL_ALIGNMENT_CENTER)
	_place(w, Vector2(0, 330))


## Back to the sentence box (the job goes on by itself; its site shows it in the village).
func new_idea() -> void:
	job_dir = ""
	job = {}
	screen = "idea"
	taps.clear()
	expanded = ""
	holding = false
	busy = ""
	waiting_for = ""
	message = ""
	_rebuild()
