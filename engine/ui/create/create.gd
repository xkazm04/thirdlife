extends "res://ui/create/create_build.gd"
## L3 (night of 21 Nov 2026): the Create page. A full-screen page of the main menu (L4 mounts res://ui/create/create.tscn
## and calls `open()`; the page emits `closed` when the player goes back). The player says a game in one sentence,
## picks Standard or Crazy, reacts to the Designer's aspect cards, and builds the game in phases it tries and passes.
##
## Everything it shows is read from the job's own log (contracts/JOB.md, "Added 2026-11-20"; ui/job_model.gd); every
## thing it does is a Foreman command line through ui/foreman_door.gd (`new`, `react`, `redesign`, `approve`/`plan`/`run`,
## `phase`, `resume`) or a second game process with `--dungeon=<pack dir>` (COMMON "Try-it seam"). Screens and the rules
## behind them: ui/create/create_model.gd. Drawn on a 1280 x 720 stage scaled to the window (the 720p readability floor:
## no text under 16 px on the stage).
##
## setup(opts) before it enters the tree, or nothing (then `open()` finds the jobs root and the Foreman itself):
##   jobs: <dir>         the jobs root (default: TL_CREATE_JOBS, else <repo>/site above the engine)
##   flags: {..}         the Foreman settings per command (default: TL_CREATE_FLAGS, else res://ui/flags/real.json)
##   dry: true           never start a process: every command line is recorded in door.dry_steps / last_launch
##   now: <unix s>       a fixed clock (fixtures, stills): no polling, the job is read once per show_job()
##   try_stub: <dir>     a pack to try/play when the job's own pack is not there (fixtures)
##   door: {..}          more options for ui/foreman_door.gd setup (selftest 780: res_dir "" and exe, as in an exe)
##   menu_list: <file>   E4: the person's dungeon list Add to menu writes (default: kernel/dungeon/dungeons.gd user_path())
##
## E4 (night of 24-25 Nov 2026): the person's path through iterations. Done: Play, Add to menu (the main menu's
## Dungeons), and a change box (`foreman change`: a new version; a change may grow the game, foreman/src/grow.ts);
## a phase pause's Hold is its change box. My games (top bar): every job of the jobs root, newest first; one reopens
## where its log stands, and a build whose Foreman is gone goes on with Continue.

signal closed

var _logged_screen: String = ""          # N4: the screen last named on the log ("[create] screen: <name>")


func setup(o: Dictionary) -> void:
	opts = o
	jobs_root = str(o.get("jobs", "")).replace("\\", "/").trim_suffix("/")
	menu_list = str(o.get("menu_list", ""))     # E4: "" = the person's list (dungeons.gd user_path)
	door = Door.new()
	var d: Dictionary = {"dry": bool(o.get("dry", false)), "flags": o.get("flags", {}), "flags_name": str(o.get("flags_name", ""))}
	if o.get("door") is Dictionary:
		d.merge(o["door"])                      # N4: a selftest's door options (res_dir + exe: the exe's layout)
	door.setup(jobs_root, d)
	if not door.dry:
		# N4: the exe's log says whether GO can start the Foreman, and why not (the toast alone left no trace)
		print("[create] jobs %s; Foreman %s; starter %s; node %s; settings '%s': %s" % [jobs_root, door.cli_path, door.runner_path,
			door.node_version, door.flags_name, "ready" if door.available else door.problem])


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.size = Vector2(W, H)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	add_child(_stage)
	resized.connect(_fit)
	_read_cards()
	_fit()
	if door == null:
		_setup_from_environment()
	_rebuild()


## L4's menu calls this when the player picks Create.
func open() -> void:
	if door == null:
		_setup_from_environment()
	visible = true
	message = ""
	if not job_dir.is_empty():
		_read_job()
	_rebuild()
	grab_focus()


func _setup_from_environment() -> void:
	var o: Dictionary = opts.duplicate()
	if not o.has("jobs"):
		var env: String = OS.get_environment("TL_CREATE_JOBS")
		if not env.is_empty():
			o["jobs"] = env
		else:
			var cli: String = Door.find_cli(Door.disk_dir())   # N4: res:// is no disk folder in an exe
			o["jobs"] = cli.get_base_dir().get_base_dir().get_base_dir().path_join("site") if not cli.is_empty() else OS.get_user_data_dir().path_join("site")
	if not o.has("flags"):
		var path: String = OS.get_environment("TL_CREATE_FLAGS")
		if path.is_empty():
			path = "res://ui/flags/real.json"          # res:// reads from the pack file of an exported build too
		var f: Variant = JobModel.read_json(path)
		if f is Dictionary:
			o["flags"] = (f as Dictionary).get("flags", {})
			o["flags_name"] = str((f as Dictionary).get("name", ""))
	setup(o)


func _read_cards() -> void:
	cards.clear()
	var dir: String = "res://cards"
	if not DirAccess.dir_exists_absolute(dir):
		return
	var files: PackedStringArray = DirAccess.get_files_at(dir)
	files.sort()
	for f: String in files:
		if f.ends_with(".json"):
			var c: Variant = JobModel.read_json(dir.path_join(f))
			if c is Dictionary and (c as Dictionary).has("id"):
				cards[str(c["id"])] = str((c as Dictionary).get("title", c["id"])).get_slice(":", 0)


# ---------------------------------------------------------------- the job

## Follow this job directory (fixtures, stills, the page's own job after Go).
func show_job(dir: String) -> void:
	job_dir = dir
	showing_games = false
	_sent_change = ""
	_change_draft = ""
	busy = ""
	waiting_for = ""
	message = ""
	taps.clear()
	expanded = ""
	holding = false
	_read_job()
	_rebuild()


func _read_job() -> void:
	if job_dir.is_empty():
		job = {}
		return
	job = JobModel.read_job(job_dir, _now())
	screen = Model.screen_of(job)
	# a verdict is refused while a Foreman holds the job: Pass and Hold wait until it has let go (seen 21 Nov: the
	# log said phase_done a moment before the process that wrote it ended)
	settling = screen == "phase_done" and door != null and door.foreman_alive(job_dir, int(job.get("lock_pid", 0)))
	# what this page started shows until the log answers it
	match busy:
		"redesign":
			if int(job.get("briefs", 0)) > busy_mark:
				busy = ""
				taps.clear()
		"approve":
			if not str(job.get("approved_by", "")).is_empty():
				busy = ""
				taps.clear()
		"phase":
			if (job.get("phase_events", []) as Array).size() > busy_mark:
				busy = ""
				holding = false
		"change":
			# E4: the log holds the request and the Foreman has taken it (or already finished it)
			var mine: Array = Model.person_changes(job)
			if (job.get("changes", []) as Array).size() > busy_mark and (screen != "done" or (not mine.is_empty() and str((mine.back() as Dictionary).get("outcome", "")) != "in flight")):
				busy = ""
				_sent_change = ""
		"continue":
			if door != null and door.busy(job_dir).is_empty():
				busy = ""
	_follow_menu_row()


func _process(delta: float) -> void:
	_t += delta
	for i: int in _alive.size():
		var ic: Control = _alive[i]
		if is_instance_valid(ic):
			ic.position.y = float(ic.get_meta("y0", ic.position.y)) + sin(_t * 3.2 + float(i) * 0.55) * 12.0
	for c: Variant in _pulse:
		if is_instance_valid(c):
			(c as CanvasItem).modulate = Color(1, 1, 1, 0.15 + 0.85 * (0.5 + 0.5 * sin(_t * 4.0)))
	if _clock != null and is_instance_valid(_clock):
		_clock.text = JobModel.fmt_time(_elapsed())
	if opts.has("now") or not is_visible_in_tree():
		return                            # a fixed clock reads nothing; a hidden page (the menu closed it) waits
	_poll_left -= delta
	if _poll_left > 0.0:
		return
	_poll_left = 0.5
	_poll()


func _poll() -> void:
	if door == null:
		return
	if door.tick():
		var err: String = door.last_error(job_dir if not job_dir.is_empty() else "new")
		if not err.is_empty():
			message = err
			print("[create] the Foreman stopped: " + err)
			busy = ""
			waiting_for = ""
	if not waiting_for.is_empty() and not jobs_root.is_empty():
		for d: String in JobModel.list_job_dirs(jobs_root):
			var j: Dictionary = JobModel.read_job(d)
			if Door.clean_text(str(j.get("sentence", ""))) == waiting_for and float(j.get("first_ts", 0.0)) >= started_at - 30.0:
				waiting_for = ""
				busy = ""
				job_dir = d
				break
	if not job_dir.is_empty():
		_read_job()
	_rebuild_if_changed()


func _rebuild_if_changed() -> void:
	if _signature() != _sig:
		_rebuild()


# ---------------------------------------------------------------- screens

func _rebuild() -> void:
	if _stage == null:
		return
	if _body != null:
		# out of the tree now, freed later: a button of the old body may be the one whose signal rebuilt the page
		_stage.remove_child(_body)
		_body.queue_free()
	_alive.clear()
	_pulse.clear()
	_clock = null
	_sentence_box = null
	_note_box = null
	_body = Control.new()
	_body.name = "Body"
	_body.size = Vector2(W, H)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_body)
	var shown: String = shown_screen()
	if shown != _logged_screen and door != null and not door.dry:
		_logged_screen = shown
		print("[create] screen: %s%s" % [shown, (" (" + job_dir + ")") if not job_dir.is_empty() else ""])
	_top_bar(shown)
	match shown:
		"idea": _idea()
		"designing": _designing()
		"pitch": _pitch()
		"building": _building()
		"phase_done": _phase_done()
		"done": _done()
		"failed": _failed()
		"error": _error()
		"games": _games()
	if not message.is_empty():
		_toast(message)
	_sig = _signature()


## What is on screen: the log's screen, or what this page started and waits for.
func shown_screen() -> String:
	if showing_games:
		return "games"
	if busy == "change" and screen == "done":
		return "building"                # E4: the change is sent, the Foreman has not written it yet
	if job_dir.is_empty():
		return "designing" if not waiting_for.is_empty() else "idea"
	if busy == "redesign" and screen == "pitch":
		return "designing"
	if busy == "approve" and screen == "pitch":
		return "building"
	if busy == "phase" and screen == "phase_done":
		return "building"
	if screen == "phase_done" and settling:
		return "building"                # the log waits on a phase, the Foreman that wrote it has not let go yet
	return screen


func _top_bar(shown: String) -> void:
	var back: Button = _button("Back", "Menu", "back", CREAM, Vector2(24, 18), Vector2(150, 54), 22)
	back.pressed.connect(func() -> void: closed.emit())
	_body.add_child(back)
	var mark: Label = _label("CREATE", 34, 950, HONEY)
	mark.add_theme_font_override("font", _font(950, 125))
	_place(mark, Vector2(196, 22))
	if shown != "idea":
		var again: Button = _button("NewIdea", "New idea", "plus", CREAM, Vector2(W - 214, 18), Vector2(190, 54), 22)
		again.pressed.connect(new_idea)
		_body.add_child(again)
	if shown != "games":
		# E4: every game this jobs root holds, newest first; one opens where it stands
		var mine: Button = _button("MyGames", "My games", "story", CREAM, Vector2(W - 424 if shown != "idea" else W - 214, 18), Vector2(190, 54), 22)
		mine.pressed.connect(open_games)
		_body.add_child(mine)


func _toast(text: String) -> void:
	var p: PanelContainer = PanelContainer.new()
	p.name = "Toast"
	var sb: StyleBoxFlat = _box(RED, INK, 3, 12)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(_label(JobModel.one_line(text, 110), 18, 700, PAPER))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(p, Vector2(420, 24))


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	if (event as InputEventKey).keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	if not expanded.is_empty():
		close_sheet()
	elif holding:
		holding = false
		_rebuild()
	elif showing_games:
		showing_games = false
		_rebuild()
	else:
		closed.emit()
