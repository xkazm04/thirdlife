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
	var k: int = int(job.get("phase_now", -1))
	if Model.version_n(job) > 0 and (busy == "change" or not Model.changing(job).is_empty()):
		# E4: a change on a game that was handed over: its phases stay passed (a re-opened package does not undo them)
		for e: Dictionary in s:
			e["state"] = "passed"
			e["current"] = false
		k = -1
	_strip(s, 140.0, 104.0)
	if _pause_card():
		return                            # E4b: a question or a quality hold: the person answers it here (create_pause.gd)
	_continue_button()
	if k < 0 or k >= s.size():
		# every phase passed: the Foreman plays the whole game through once more before it hands it over; or (E4) a
		# change round on a finished game: what is being changed, and the parts being built for it
		var said: String = Model.changing(job) if busy != "change" else _sent_change
		if said.is_empty():
			var last: Control = _callout("Last check, then it is yours", Vector2(50, 278), "check", GREEN)
			last.name = "LastCheck"
			_icon_parade(400)
		else:
			var ch: Control = _callout("Changing: " + JobModel.one_line(said, 70), Vector2(50, 278), "redo", ORANGE)
			ch.name = "Changing"
			var wk: Array = Model.working_packages(job)
			if wk.is_empty():
				_icon_parade(400)
			var n: int = mini(3, wk.size())
			var tw: float = minf(360.0, (W - 100.0 - 20.0 * float(n - 1)) / maxf(1.0, float(n)))
			var x0: float = (W - (tw * float(n) + 20.0 * float(n - 1))) * 0.5
			for i: int in n:
				_package_tile(wk[i], Vector2(x0 + float(i) * (tw + 20.0), 392), Vector2(tw, 150))
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
		if busy in ["answer", "quality"]:
			_callout("Your answer is sent: the builders go on", Vector2(50, 556), "check", GREEN).name = "Sent"   # E4b
		else:
			_callout("Paused: " + why, Vector2(50, 556), "pause", ORANGE)
	elif str(cur["state"]) == "held":
		_callout("Changing: " + JobModel.one_line(str(cur["note"]), 80), Vector2(50, 556), "redo", ORANGE)
	elif not Model.changing(job).is_empty():
		# E4: a change request (not a hold) on a game whose phases are open again (a grown package joined one)
		var ch: Control = _callout("Changing: " + JobModel.one_line(Model.changing(job), 80), Vector2(50, 556), "redo", ORANGE)
		ch.name = "Changing"


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
	# E4c: on a game on a core the phase's measured figures stand beside the card (create_pause.gd _measured_card)
	var mv: Dictionary = Model.measured_view(job)
	var k: float = 1.0 if mv.is_empty() else 0.8
	card.position = Vector2(140, 250) if mv.is_empty() else Vector2(40, 250)
	card.size = Vector2(1000.0 * k, 400)
	if not mv.is_empty():
		_measured_card(mv, Vector2(860, 250), Vector2(380, 400))
	_body.add_child(card)
	var ready: Label = _label("Phase %d is ready!" % int(e.get("n", 0)), 46, 950, INK, 920.0 * k, HORIZONTAL_ALIGNMENT_CENTER)
	ready.name = "Ready"
	ready.position = Vector2(40, 30)
	card.add_child(ready)
	var tr: Label = _label(str(e.get("try", "")), 30, 700, Color(INK, 0.85), 860.0 * k, HORIZONTAL_ALIGNMENT_CENTER)
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
		nb.position = Vector2(60, 236) * Vector2(k, 1)
		nb.size = Vector2(560.0 * k, 84)
		nb.max_length = 240
		nb.text_submitted.connect(func(_t: String) -> void: send_hold())
		card.add_child(nb)
		_note_box = nb
		var send: Button = _button("SendHold", "Send", "go", ORANGE, Vector2(640.0 * k, 236), Vector2(170.0 * k, 84), 30)
		send.pressed.connect(send_hold)
		card.add_child(send)
		var back: Button = _button("CancelHold", "", "back", CREAM, Vector2(830.0 * k, 236), Vector2(110.0 * k, 84), 30)
		back.pressed.connect(func() -> void:
			holding = false
			_rebuild())
		card.add_child(back)
		return
	var tb: Button = _button("TryIt", "Try it", "play", HONEY, Vector2(60.0 * k, 236), Vector2(330.0 * k, 110), 40)
	tb.pressed.connect(try_it)
	card.add_child(tb)
	var pb: Button = _button("Pass", "Pass", "check", GREEN, Vector2(420.0 * k, 236), Vector2(250.0 * k, 110), 40)
	pb.pressed.connect(pass_phase)
	card.add_child(pb)
	var hb: Button = _button("Hold", "Hold", "hold", ORANGE, Vector2(700.0 * k, 236), Vector2(240.0 * k, 110), 40)
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
	_place(t, Vector2(0, 250))
	var v: int = Model.version_n(job)
	var title: Label = _label(str(job.get("title", "")) + ("  ·  version %d" % v if v > 1 else ""), 34, 800, PAPER, W, HORIZONTAL_ALIGNMENT_CENTER)
	title.name = "GameTitle"
	_place(title, Vector2(0, 334))
	var note: String = Model.change_note(job)
	if not note.is_empty():
		var nl: Label = _label(note, 20, 700, ORANGE, W, HORIZONTAL_ALIGNMENT_CENTER)
		nl.name = "ChangeNote"
		_place(nl, Vector2(0, 380))
	var play: Button = _button("Play", "Play", "play", HONEY, Vector2(W * 0.5 - 330, 414), Vector2(310, 110), 46)
	play.pressed.connect(func() -> void: launch(Model.play_dir(job)))
	_body.add_child(play)
	# E4: one press puts the game in the main menu's Dungeons (the person's own list, kernel/dungeon/dungeons.gd)
	var listed: bool = not Dungeons.user_row(job_dir, menu_list).is_empty()
	var mb: Button = _button("RemoveMenu" if listed else "AddMenu", "In the menu" if listed else "Add to menu", "check" if listed else "plus", GREEN if listed else CREAM,
		Vector2(W * 0.5 + 20, 414), Vector2(310, 110), 30)
	mb.tooltip_text = "Press to take it out of the menu" if listed else "Show it in the main menu's Dungeons"
	mb.pressed.connect(remove_from_menu if listed else add_to_menu)
	_body.add_child(mb)
	_change_row(Vector2(150, 572))


## E4: the change box: what should change, in the person's words, then a new playable build (`foreman change`).
func _change_row(at: Vector2) -> void:
	var cb: LineEdit = LineEdit.new()
	cb.name = "ChangeBox"
	cb.placeholder_text = "What should change? Faster, bigger, a new power..."
	cb.add_theme_font_override("font", _font(650))
	cb.add_theme_font_size_override("font_size", 24)
	cb.add_theme_color_override("font_color", INK)
	cb.add_theme_color_override("font_placeholder_color", Color(INK, 0.45))
	var sb: StyleBoxFlat = _box(Color.WHITE, HONEY.darkened(0.25), 4, 14)
	sb.content_margin_left = 18.0
	cb.add_theme_stylebox_override("normal", sb)
	cb.add_theme_stylebox_override("focus", sb)
	cb.position = at
	cb.size = Vector2(740, 80)
	cb.max_length = 240
	cb.text = _change_draft
	cb.text_changed.connect(func(t: String) -> void: _change_draft = t)
	cb.text_submitted.connect(func(_t: String) -> void: send_change())
	_body.add_child(cb)
	_change_box = cb
	var go_b: Button = _button("SendChange", "Change it", "redo", ORANGE, at + Vector2(760, 0), Vector2(220, 80), 28)
	go_b.pressed.connect(send_change)
	_body.add_child(go_b)


func send_change() -> void:
	var text: String = Door.clean_text(_change_box.text if _change_box != null else "")
	if text.is_empty():
		message = "Say what should change first."
		_rebuild()
		return
	var err: String = door.change(job_dir, text)
	if not err.is_empty() and not door.dry:
		message = err
	else:
		message = ""
		busy = "change"
		busy_mark = (job.get("changes", []) as Array).size()
		_sent_change = text
		started_at = _now()
		_change_draft = ""
	_rebuild()


func add_to_menu() -> void:
	var err: String = Dungeons.add_user(Model.play_dir(job), str(job.get("title", "My game")), job_dir, menu_list)
	message = "" if err.is_empty() else "Not added to the menu: " + err
	if err.is_empty():
		print("[create] menu: added %s (%s)" % [str(job.get("title", "")), Model.play_dir(job)])
	_rebuild()


func remove_from_menu() -> void:
	var err: String = Dungeons.remove_user(job_dir, menu_list)
	message = "" if err.is_empty() else "Not taken out of the menu: " + err
	_rebuild()


## E4: a game in the menu plays its newest version: after a change is made, its row moves to the new promotion.
func _follow_menu_row() -> void:
	if screen != "done" or job_dir.is_empty():
		return
	var row: Dictionary = Dungeons.user_row(job_dir, menu_list)
	if not row.is_empty() and str(row["pack"]) != Model.play_dir(job).replace("\\", "/").trim_suffix("/"):
		Dungeons.add_user(Model.play_dir(job), str(row["title"]), job_dir, menu_list)


## E4: a job whose Foreman is gone (the window was closed, it was reopened from My games) builds on with Continue.
## E4b: create_pause.gd draws the card of a pause a person answers (a builder's question, a quality hold); true when drawn.
func _pause_card() -> bool:
	return false


## E4c: create_pause.gd draws the phase's measured figures beside the phase card.
func _measured_card(_v: Dictionary, _at: Vector2, _sz: Vector2) -> void:
	pass


func _continue_button() -> void:
	if door == null or busy != "" or str(job.get("pause_kind", "")) in ["question", "quality"]:
		return
	if not str(job.get("phase", "")) in ["planning", "running", "paused"] or door.foreman_alive(job_dir, int(job.get("lock_pid", 0))):
		return
	var b: Button = _button("Continue", "Continue", "play", HONEY, Vector2(W - 290, 556), Vector2(240, 56), 24)
	b.pressed.connect(continue_build)
	_body.add_child(b)


func continue_build() -> void:
	var started_before: bool = not str(job.get("job_state", "")).is_empty()
	var err: String = door.resume(job_dir, not (job.get("order", []) as Array).is_empty(), started_before)
	message = "" if err.is_empty() or door.dry else err
	if err.is_empty() and not door.dry:
		busy = "continue"
	_rebuild()


# ---- E4: My games

## 26 Nov (the owner: "Create has no pagination, so I cannot access the games"): My games shows GAMES_PAGE games a page;
## Newer and Older (and Page Up / Page Down) turn the pages, and the line between them says which page of how many.
const GAMES_PAGE: int = 5


func open_games() -> void:
	showing_games = true
	games_page = 0
	games_rows = Model.games(jobs_root) if not jobs_root.is_empty() else []
	_rebuild()


func _games() -> void:
	var t: Label = _label("My games", 46, 950, HONEY, W, HORIZONTAL_ALIGNMENT_CENTER)
	t.name = "GamesTitle"
	_place(t, Vector2(0, 92))
	if games_rows.is_empty():
		var none: Label = _label("Nothing made yet: say a game and press Go.", 26, 700, MUTED, W, HORIZONTAL_ALIGNMENT_CENTER)
		none.name = "NoGames"
		_place(none, Vector2(0, 300))
		return
	var pages: int = ceili(float(games_rows.size()) / GAMES_PAGE)
	games_page = clampi(games_page, 0, pages - 1)
	var first: int = games_page * GAMES_PAGE
	var n: int = mini(GAMES_PAGE, games_rows.size() - first)
	for i: int in n:
		var g: Dictionary = games_rows[first + i]
		var in_menu: bool = not Dungeons.user_row(str(g["dir"]), menu_list).is_empty()
		var row: Button = _button("Game%d" % i, "", "", PAPER, Vector2(140, 168 + float(i) * 88), Vector2(1000, 76), 24)
		row.tooltip_text = str(g["sentence"])
		row.pressed.connect(open_game.bind(str(g["dir"])))
		_body.add_child(row)
		var glyph: String = {"done": "play", "phase_done": "hold", "failed": "cross", "pitch": "story", "designing": "time"}.get(str(g["screen"]), "build")
		var ic: Icon = Icon.new(glyph, 52)
		ic.disc = {"done": GREEN, "phase_done": ORANGE, "failed": RED}.get(str(g["screen"]), BLUE)
		ic.position = Vector2(14, 12)
		ic.size = Vector2(52, 52)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
		var tl: Label = _label(JobModel.one_line(str(g["title"]), 34), 26, 850, INK, 470)
		tl.name = "GameName"
		tl.position = Vector2(84, 18)
		row.add_child(tl)
		var behind: bool = str(g["screen"]) == "done" and int(g.get("behind", 0)) > 0
		var builds: String = "  ·  %d builds" % int(g["builds"]) if int(g.get("builds", 1)) > 1 else ""
		var wl: Label = _label(str(g["word"]) + builds + ("  ·  in the menu" if in_menu else ""), 21, 700, Color(INK, 0.7), 420 - (210 if behind else 0), HORIZONTAL_ALIGNMENT_RIGHT)
		wl.name = "GameState"
		wl.position = Vector2(560, 24)
		row.add_child(wl)
		if behind:
			# H2: the base got better after this game was made: one control moves it to the newest base (foreman rebase)
			var nb: Button = _button("Base%d" % i, "Newest base", "redo", HONEY, Vector2(784, 10), Vector2(204, 56), 20)
			nb.tooltip_text = "Move this game to the newest base: its cartridge, rules, skin and match stay; it plays as it is until the new version has passed its checks."
			nb.pressed.connect(move_to_base.bind(str(g["dir"]), str(g["title"])))
			row.add_child(nb)
	if pages > 1:
		var at: float = 168 + GAMES_PAGE * 88 + 14
		var pl: Label = _label("Page %d of %d  ·  %d games" % [games_page + 1, pages, games_rows.size()], 22, 700, MUTED, W, HORIZONTAL_ALIGNMENT_CENTER)
		pl.name = "GamesPage"
		_place(pl, Vector2(0, at + 14))
		if games_page > 0:
			var nb: Button = _button("GamesNewer", "Newer", "back", CREAM, Vector2(140, at), Vector2(200, 56), 22)
			nb.pressed.connect(games_turn.bind(-1))
			_body.add_child(nb)
		if games_page < pages - 1:
			var ob: Button = _button("GamesOlder", "Older", "arrow", CREAM, Vector2(940, at), Vector2(200, 56), 22)
			ob.pressed.connect(games_turn.bind(1))
			_body.add_child(ob)


## Turns My games a page (-1 newer, +1 older).
func games_turn(by: int) -> void:
	games_page += by
	_rebuild()


## H2 (25 Nov): a finished game moves to the newest base (foreman_door.gd rebase). My games stays open; its row says
## "Moving to the newest base" while the Foreman verifies, then "Ready, version n+1" (or the old version, with a note).
func move_to_base(dir: String, title: String) -> void:
	var err: String = door.rebase(dir)
	message = err if not err.is_empty() and not door.dry else "Moving “%s” to the newest base: it plays as it is until the new version has passed its checks." % JobModel.one_line(title, 40)
	games_rows = Model.games(jobs_root) if not jobs_root.is_empty() else []
	_rebuild()


## Reopens a game at the state its log is in: play and change it, pass a waiting phase, continue a stopped build.
func open_game(dir: String) -> void:
	showing_games = false
	print("[create] my games: open %s" % dir)
	call("show_job", dir)              # create.gd (the subclass) reads the job


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
	showing_games = false
	_sent_change = ""
	_change_draft = ""
	_rebuild()
