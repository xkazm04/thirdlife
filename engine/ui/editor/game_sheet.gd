extends Control
## E2 (night of 19 Nov): a game in progress, for a game made in the workbench. Three things, in the player's words:
## DECIDED (what the workbench sent: every answer and who gave it; the brief once it is written), OPEN (what waits for
## the player: the brief to approve, a builder's question, a game that stopped), NOW (what the builders are doing:
## one line per package with the site's own state words, the current one first). On the right the game's lot, close
## up, with one bay per package coloured by its state, as the village draws the construction site.
## Reads the job directory (job_model.gd) once a second and the draft the workbench wrote (<jobs>/_editor/*.json);
## acts only through the Foreman door, like the panel.

const Model = preload("res://ui/editor/editor_model.gd")
const VillageMap = preload("res://ui/editor/village_map.gd")
const Look = preload("res://ui/editor/look.gd")
const JobModel = preload("res://ui/job_model.gd")

signal closed

const M: int = 16
const LEFT_W: int = 540
const STATE_WORDS: Dictionary = {"queued": "waiting", "running": "building", "verifying": "checking", "blocked": "on hold",
	"promoted": "built", "failed": "failed"}
const PHASE_WORDS: Dictionary = {"designing": "the brief is being written", "approve": "the brief waits for you",
	"planning": "the plan is being cut", "running": "being built", "paused": "paused", "done": "ready to play",
	"failed": "could not be finished", "cancelled": "discarded", "stalled": "stopped: no Foreman", "unreadable": "unreadable"}

var door: RefCounted
var job_dir: String = ""
var draft: Dictionary = {}
var model: Model
var job: Dictionary = {}
var col: Dictionary = {}
var font: Font
var bold: Font
var message: String = ""
var _poll: float = 0.0
var _sig: String = ""
var _title: Label
var _chip: Label
var _figures: Label
var _decided: VBoxContainer
var _open: VBoxContainer
var _now: VBoxContainer
var _map: VillageMap


## The draft the workbench wrote for this job: the one whose request is the job's sentence ({} when none).
static func find_draft(jobs_root: String, sentence: String) -> Dictionary:
	var dir: String = jobs_root.path_join("_editor")
	var want: String = sentence.replace("\r", " ").replace("\n", " ").replace("\"", "'").strip_edges()
	var files: PackedStringArray = DirAccess.get_files_at(dir) if DirAccess.dir_exists_absolute(dir) else PackedStringArray()
	for f: String in files:
		var d: Variant = JobModel.read_json(dir.path_join(f))
		if d is Dictionary and str((d as Dictionary).get("schema", "")) == "tl.editor-draft/1":
			var req: String = str((d as Dictionary).get("request", "")).replace("\"", "'").strip_edges()
			if req == want:
				return d
	return {}


func setup(the_door: RefCounted, dir: String, the_draft: Dictionary) -> void:
	door = the_door
	job_dir = dir
	draft = the_draft


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	col = Look.colors()
	font = ThemeDB.fallback_font
	var fv: FontVariation = FontVariation.new()
	fv.base_font = font
	fv.variation_embolden = 0.7
	bold = fv
	theme = Look.theme(col, font)
	model = Model.new()
	model.load_all()
	_model_from_draft()
	_build()
	_reload()


## The workbench's model, rebuilt from the draft: the same recipe, answers and lot, so the map draws the same game.
func _model_from_draft() -> void:
	model.set_sentence(str(draft.get("sentence", "")))
	var cid: String = str(draft.get("card", ""))
	for n: String in model.interviews:
		if str((model.interviews[n] as Dictionary).get("card", "")) == cid and (n != "none" or cid.is_empty()):
			model.choose_recipe(n)
	model.answers = (draft.get("answers", {}) as Dictionary).duplicate(true)
	var lot: Dictionary = draft.get("lot", {})
	var a: Array = lot.get("at", [0, 0])
	model.place(Vector2(float(a[0]), float(a[1])))
	model.yaw = deg_to_rad(float(lot.get("yaw_deg", 0.0)))


func _plate(name_: String, title: String, parent: Node) -> VBoxContainer:
	var p: PanelContainer = PanelContainer.new()
	p.name = name_
	parent.add_child(p)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	v.add_child(_label(title, 20, true))
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	v.add_child(body)
	return body


func _label(text: String, fs: int = 14, b: bool = false, color: Color = Color(0, 0, 0, 0), wrap: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if b:
		l.add_theme_font_override("font", bold)
	if fs != 14:
		l.add_theme_font_size_override("font_size", fs)
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _button(name_: String, text: String, primary: bool) -> Button:
	var b: Button = Button.new()
	b.name = name_
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if primary:
		b.add_theme_font_override("font", bold)
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_stylebox_override("normal", Look.sb(col["honey"], col["ink"], 3, 8, 18, 6))
		b.add_theme_stylebox_override("hover", Look.sb(col["honey"].lightened(0.1), col["ink"], 3, 8, 18, 6))
		b.add_theme_stylebox_override("pressed", Look.sb(col["honey_dark"], col["ink"], 3, 8, 18, 6))
		b.add_theme_stylebox_override("disabled", Look.sb(col["paper"].darkened(0.08), Color(col["ink"], 0.3), 3, 8, 18, 6))
	return b


func _build() -> void:
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(col["shade"], 0.35)
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
	var head: PanelContainer = PanelContainer.new()
	head.add_theme_stylebox_override("panel", Look.sb(col["paper"], col["ink"], 3, 8, 14, 6))
	root.add_child(head)
	var hh: HBoxContainer = HBoxContainer.new()
	head.add_child(hh)
	var back: Button = _button("GamesButton", "< Games", false)
	back.pressed.connect(func() -> void: closed.emit())
	hh.add_child(back)
	_title = _label("", 20, true)
	hh.add_child(_title)
	_chip = Label.new()
	_chip.name = "StateChip"
	_chip.add_theme_font_override("font", bold)
	_chip.add_theme_font_size_override("font_size", 13)
	hh.add_child(_chip)
	_figures = Label.new()
	_figures.add_theme_font_size_override("font_size", 12)
	_figures.add_theme_color_override("font_color", col["dim"])
	hh.add_child(_figures)
	var mid: HBoxContainer = HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 10)
	root.add_child(mid)
	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(LEFT_W, 0)
	left.add_theme_constant_override("separation", 10)
	mid.add_child(left)
	_open = _plate("OpenPlate", "Open", left)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var dp: PanelContainer = PanelContainer.new()
	dp.name = "DecidedPlate"
	dp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(dp)
	var dv: VBoxContainer = VBoxContainer.new()
	dp.add_child(dv)
	dv.add_child(_label("Decided", 20, true))
	dv.add_child(scroll)
	_decided = VBoxContainer.new()
	_decided.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_decided.add_theme_constant_override("separation", 2)
	scroll.add_child(_decided)
	var right: PanelContainer = PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(right)
	var rv: VBoxContainer = VBoxContainer.new()
	right.add_child(rv)
	rv.add_child(_label("On its lot", 20, true))
	var frame: PanelContainer = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", Look.sb(col["ink"], col["ink"], 0, 6, 2, 2))
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(frame)
	_map = VillageMap.new()
	_map.name = "LotMap"
	_map.model = model
	_map.col = col
	_map.font = font
	_map.bold = bold
	_map.read_only = true
	_map.close_up = true
	frame.add_child(_map)
	rv.add_child(_label("Now", 20, true))
	_now = VBoxContainer.new()
	_now.name = "Now"
	_now.add_theme_constant_override("separation", 2)
	_now.custom_minimum_size = Vector2(0, 120)
	rv.add_child(_now)


func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = 1.0
		_reload()


func _reload() -> void:
	job = JobModel.read_job(job_dir)
	var phase: String = str(job.get("phase", "unreadable"))
	if phase in JobModel.LIVE_PHASES and door != null and not bool(door.call("foreman_alive", job_dir, JobModel.read_lock(job_dir))):
		phase = "stalled" if not _starting() else phase
	job["shown"] = phase
	var derr: String = str(door.call("last_error", job_dir)) if door != null else ""
	var sig: String = "%s|%d|%s|%s|%s" % [phase, int(job.get("n_events", 0)), message, _starting(), derr]
	_figures.text = "  %s · %s tokens" % [_clock(float(job.get("elapsed_s", 0))), _k(int(job.get("tokens_in", 0)) + int(job.get("tokens_out", 0)))]
	if sig == _sig:
		return
	_sig = sig
	_title.text = str(job.get("title", "")) if not str(job.get("title", "")).is_empty() else str(draft.get("sentence", ""))
	_chip.text = " %s " % str(PHASE_WORDS.get(phase, phase))
	_chip.add_theme_color_override("font_color", col["hazard"] if phase in ["failed", "stalled", "cancelled"] else (col["green"] if phase == "done" else col["ink"]))
	_fill_open(phase)
	_fill_decided()
	_fill_now()
	var bays: Array = []
	for id: String in job.get("order", []):
		var p: Dictionary = (job["packages"] as Dictionary)[id]
		bays.append({"title": str(p["title"]), "state": str(p["state"])})
	_map.bays = bays
	_map.queue_redraw()


## True while a command this sheet (or the panel) started on this job is still running in the door.
func _starting() -> bool:
	return door != null and not str(door.call("busy", job_dir)).is_empty()


static func _clock(s: float) -> String:
	return "%d:%02d" % [int(s) / 60, int(s) % 60]


static func _k(n: int) -> String:
	return "%.1fk" % (n / 1000.0) if n < 1000000 else "%.2fM" % (n / 1000000.0)


func _clear(box: Node) -> void:
	for c: Node in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _fill_decided() -> void:
	_clear(_decided)
	for q: Dictionary in model.questions():
		var v: Dictionary = model.value(q["key"])
		var o: Dictionary = model.option(q, str(v["id"]))
		var who: String = {"player": "yours", "sentence": "from your words", "proposal": "left to the proposal"}.get(str(v["by"]), "")
		var h: HBoxContainer = HBoxContainer.new()
		var k: Label = _label(str(q["ask"]), 13, false, col["dim"])
		k.custom_minimum_size = Vector2(250, 0)
		k.size_flags_horizontal = Control.SIZE_FILL
		h.add_child(k)
		h.add_child(_label(str(o.get("label", v["id"])), 13, true))
		h.add_child(_label(who, 12, false, col["honey_dark"].darkened(0.2) if v["by"] == "proposal" else col["dim"]))
		_decided.add_child(h)
	var lot: Dictionary = draft.get("lot", {})
	var fp: Dictionary = draft.get("footprint", {})
	if not lot.is_empty():
		var s: Array = fp.get("size_m", [0, 0])
		_decided.add_child(_label("Lot at %d, %d · ring %d m · %d x %d m (estimate until it is built)" % [int((lot["at"] as Array)[0]), int((lot["at"] as Array)[1]), int(lot.get("radius", 0)), int(s[0]), int(s[1])], 12, false, col["dim"], true))
	var brief: Dictionary = job.get("brief", {})
	if not brief.is_empty():
		_decided.add_child(_label("THE BRIEF THE DESIGNER WROTE", 11, true, col["dim"]))
		for key: String in ["rules", "arena", "ai", "controls", "mood"]:
			if brief.has(key):
				var h: HBoxContainer = HBoxContainer.new()
				var k: Label = _label(key, 13, false, col["dim"])
				k.custom_minimum_size = Vector2(80, 0)
				k.size_flags_horizontal = Control.SIZE_FILL
				h.add_child(k)
				h.add_child(_label(str(brief[key]), 13))
				_decided.add_child(h)


func _fill_open(phase: String) -> void:
	_clear(_open)
	var can: bool = door != null and bool(door.get("available"))
	if _starting() and phase in ["approve", "stalled", "paused", "designing"]:
		_open.add_child(_label("Sending to the builders…", 14, true, col["dim"]))
		return
	match phase:
		"designing", "planning":
			_open.add_child(_label("Nothing waits for you: " + str(PHASE_WORDS[phase]) + ".", 14, false, Color(0, 0, 0, 0), true))
		"approve":
			_open.add_child(_label("The brief waits for you. Below under Decided: what you chose, and what the Designer wrote from it.", 14, false, Color(0, 0, 0, 0), true))
			var h: HBoxContainer = HBoxContainer.new()
			var ok: Button = _button("ApproveButton", "Approve and build", true)
			ok.disabled = not can
			ok.pressed.connect(func() -> void: _act(str(door.call("approve", job_dir))))
			h.add_child(ok)
			var no: Button = _button("DiscardButton", "Discard", false)
			no.disabled = not can
			no.pressed.connect(func() -> void: _act(str(door.call("discard", job_dir))))
			h.add_child(no)
			_open.add_child(h)
		"stalled":
			_open.add_child(_label("No Foreman is working on this game.", 14, true, col["hazard"]))
			var r: Button = _button("ResumeButton", "Resume", true)
			r.disabled = not can
			r.pressed.connect(func() -> void: _act(str(door.call("resume", job_dir, int(job.get("total", 0)) > 0, not str(job.get("job_state", "")).is_empty()))))
			_open.add_child(r)
		"failed", "cancelled":
			_open.add_child(_label("This game could not be finished. " + str(job.get("fail_line", "")), 14, false, col["hazard"], true))
		"done":
			_open.add_child(_label("Nothing waits for you: the game is built and verified. Its lot is kept in the draft; the village does not yet put a workbench game on the lot you chose (a proposal in this lane's report), so it is played from its pack for now.", 14, false, Color(0, 0, 0, 0), true))
		_:
			_open.add_child(_label("Nothing waits for you: the builders are at work.", 14, false, Color(0, 0, 0, 0), true))
	for q: Dictionary in job.get("questions", []):
		if bool(q["open"]):
			_question(q, can)
	if not message.is_empty():
		_open.add_child(_label(message, 12, true, col["hazard"], true))
	var derr: String = str(door.call("last_error", job_dir)) if door != null else ""
	if not derr.is_empty():
		_open.add_child(_label("The builders stopped: " + derr, 12, true, col["hazard"], true))
	if not can and door != null:
		_open.add_child(_label("The builders cannot be started: " + str(door.get("problem")), 12, false, col["dim"], true))


func _question(q: Dictionary, can: bool) -> void:
	var p: Dictionary = (job["packages"] as Dictionary).get(str(q["package"]), {})
	_open.add_child(_label("The builder of \"%s\" asks:" % str(p.get("title", q["package"])), 13, true))
	_open.add_child(_label(str(q["text"]), 13, false, Color(0, 0, 0, 0), true))
	var h: HBoxContainer = HBoxContainer.new()
	var f: LineEdit = LineEdit.new()
	f.name = "AnswerField"
	f.placeholder_text = "Your answer…"
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.add_theme_font_size_override("font_size", 14)
	f.editable = can
	h.add_child(f)
	var send: Button = _button("AnswerSend", "Answer", true)
	send.disabled = not can
	send.pressed.connect(func() -> void:
		var alive: bool = bool(door.call("foreman_alive", job_dir, JobModel.read_lock(job_dir)))
		_act(str(door.call("answer", job_dir, str(q["package"]), f.text, "", alive))))
	h.add_child(send)
	_open.add_child(h)


func _act(err: String) -> void:
	message = err
	_sig = ""
	_reload()


func _fill_now() -> void:
	_clear(_now)
	var order: Array = job.get("order", [])
	if order.is_empty():
		_now.add_child(_label("No bays yet: the site gets one per package once the plan is cut.", 13, false, col["dim"], true))
		return
	var ids: Array = order.duplicate()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return _rank(a) < _rank(b) or (_rank(a) == _rank(b) and order.find(a) < order.find(b)))
	for id: String in ids:
		var p: Dictionary = (job["packages"] as Dictionary)[id]
		var st: String = str(p["state"])
		var h: HBoxContainer = HBoxContainer.new()
		var chip: Label = Label.new()
		chip.text = " %d %s " % [order.find(id) + 1, STATE_WORDS.get(st, st)]
		chip.custom_minimum_size = Vector2(110, 0)
		chip.add_theme_font_override("font", bold)
		chip.add_theme_font_size_override("font_size", 12)
		var bg: StyleBoxFlat = Look.sb(col.get("bay_" + st, col["paper"]), col["ink"], 1, 4, 4, 1)
		chip.add_theme_stylebox_override("normal", bg)
		h.add_child(chip)
		h.add_child(_label(str(p["title"]), 13))
		var mins: float = float(p.get("work_s", 0.0)) / 60.0
		h.add_child(_label("%.1f min" % mins if mins > 0.05 else "", 12, false, col["dim"]))
		_now.add_child(h)


func _rank(id: String) -> int:
	var st: String = str(((job["packages"] as Dictionary)[id] as Dictionary)["state"])
	return {"running": 0, "verifying": 0, "blocked": 1, "failed": 2, "queued": 3, "promoted": 4}.get(st, 5)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		closed.emit()
		accept_event()
