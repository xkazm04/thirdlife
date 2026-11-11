extends Control
## N6: the designer panel. Two layers over the game picture: a list of games (short indicative rows) and a sheet for
## the selected game (Brief, Build, Change, Tune). It draws what `job_model.gd` reads from the job directories and
## asks `foreman_door.gd` to start Foreman command lines; it builds nothing itself.

const JobModel = preload("res://ui/job_model.gd")
const Door = preload("res://ui/foreman_door.gd")

const ROW: int = 24
const FS: int = 13
const FS_SMALL: int = 11
const LIST_W: int = 440
const SHEET_W: int = 560
const MARGIN: int = 16
const SECTIONS: PackedStringArray = ["brief", "build", "change", "tune"]

signal job_selected(id: String)
signal action_started(what: String, error: String)

var jobs_root: String = ""
var door: Door
var read_only: bool = false
var jobs: Dictionary = {}            # id -> job picture
var order: PackedStringArray = []    # ids, newest first
var selected: String = ""
var open_sections: Dictionary = {"brief": true, "build": true, "change": false, "tune": false}
var sections_chosen: bool = false    # the player (or --section) decided; do not re-open by phase
var notes_open: bool = false
var new_open: bool = false
var message: String = ""             # one line under the list (what the last action said)
var message_bad: bool = false

var _col: Dictionary = {}
var _stamps: Dictionary = {}         # id -> "mtime:size"
var _alive: Dictionary = {}          # id -> bool
var _poll_left: float = 0.0
var _list_sig: String = ""
var _sheet_sig: String = ""
var _known_ids: Dictionary = {}
var _want_select_sentence: String = ""
var _thumbs: Dictionary = {}         # path -> {tex, stamp}
var _elapsed_labels: Dictionary = {} # id -> Label
var _tune_note: String = ""
var _expanded: Dictionary = {}       # key -> true: texts the player opened

var _list_panel: PanelContainer
var _list_rows: VBoxContainer
var _list_scroll: ScrollContainer
var _status: Label
var _msg: Label
var _count: Label
var _new_holder: VBoxContainer
var _sheet: PanelContainer
var _sheet_body: VBoxContainer
var _sheet_scroll: ScrollContainer
var _sheet_head: VBoxContainer
var _lightbox: Control
var _lightbox_tex: TextureRect
var _lightbox_cap: Label


# ---------------------------------------------------------------- small drawn parts

class Bar extends Control:
	var frac: float = 0.0
	var color: Color = Color.WHITE
	var back: Color = Color(1, 1, 1, 0.12)
	var hollow: bool = false
	func _draw() -> void:
		var h: float = 4.0
		var y: float = roundf((size.y - h) * 0.5)
		draw_rect(Rect2(0, y, size.x, h), back)
		if hollow:
			draw_rect(Rect2(0.5, y + 0.5, size.x - 1.0, h - 1.0), color, false, 1.0)
		elif frac > 0.0:
			draw_rect(Rect2(0, y, maxf(2.0, roundf(size.x * clampf(frac, 0.0, 1.0))), h), color)


class Fold extends Control:
	var open: bool = false
	var color: Color = Color.WHITE
	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var pts: PackedVector2Array
		if open:
			pts = PackedVector2Array([c + Vector2(-4, -2), c + Vector2(4, -2), c + Vector2(0, 3)])
		else:
			pts = PackedVector2Array([c + Vector2(-2, -4), c + Vector2(3, 0), c + Vector2(-2, 4)])
		draw_colored_polygon(pts, color)


class Dot extends Control:
	var color: Color = Color.WHITE
	func _draw() -> void:
		draw_circle(size * 0.5, 3.0, color)


# ---------------------------------------------------------------- set-up

func setup(root: String, the_door: Door, opts: Dictionary = {}) -> void:
	jobs_root = root
	door = the_door
	read_only = bool(opts.get("read_only", false))
	if opts.has("section"):
		show_section(str(opts["section"]))


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_colors()
	theme = _make_theme()
	_build_frame()
	refresh(true)


func _load_colors() -> void:
	var style: Variant = JobModel.read_json(ProjectSettings.globalize_path("res://style/style.json"))
	var pal: Dictionary = {}
	var ink: String = "#1a1024"
	if style is Dictionary:
		pal = (style as Dictionary).get("palette", {})
		ink = str(((style as Dictionary).get("ink", {}) as Dictionary).get("ink", ink))
	var pick: Callable = func(key: String, fallback: String) -> Color: return Color(str(pal.get(key, fallback)))
	_col = {
		"ink": Color(ink),
		"panel": Color(Color(ink), 0.88),
		"raise": Color(Color(ink).lightened(0.10), 0.95),
		"line": Color(pick.call("steel_dark", "#4f4a60"), 0.7),
		"text": pick.call("curb_white", "#f3e8dc"),
		"dim": pick.call("barrier_dark", "#a89aa2"),
		"accent": pick.call("window", "#ffc462"),
		"running": pick.call("yellow", "#f2b230"),
		"done": pick.call("grass", "#86b944"),
		"failed": pick.call("hazard_red", "#d8452e"),
		"paused": pick.call("orange", "#e8742c"),
		"quiet": pick.call("steel_light", "#b6b0c8"),
		"ask": pick.call("cyan", "#52f2ff"),
	}


func state_color(state: String) -> Color:
	match state:
		"running", "verifying", "in flight": return _col["running"]
		"done", "promoted", "made": return _col["done"]
		"failed", "stalled", "no foreman": return _col["failed"]
		"paused", "blocked", "not made": return _col["paused"]
		"approve": return _col["ask"]
	return _col["quiet"]


func _sb(color: Color, radius: int = 3, pad_h: int = 0, pad_v: int = 0, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	return s


func _make_theme() -> Theme:
	var t: Theme = Theme.new()
	t.default_font_size = FS
	var text: Color = _col["text"]
	var dim: Color = _col["dim"]
	t.set_color("font_color", "Label", text)
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var c: Color = Color(1, 1, 1, 0.07)
		if st == "hover": c = Color(1, 1, 1, 0.13)
		if st == "pressed": c = Color(1, 1, 1, 0.20)
		if st == "disabled": c = Color(1, 1, 1, 0.03)
		var sb: StyleBoxFlat = _sb(c, 3, 10, 2)
		if st == "focus":
			sb = _sb(Color(0, 0, 0, 0), 3, 10, 2, Color(_col["accent"], 0.6), 1)
		t.set_stylebox(st, "Button", sb)
		t.set_stylebox(st, "OptionButton", sb)
	for cname: String in ["Button", "OptionButton"]:
		t.set_color("font_color", cname, text)
		t.set_color("font_hover_color", cname, text)
		t.set_color("font_pressed_color", cname, text)
		t.set_color("font_focus_color", cname, text)
		t.set_color("font_disabled_color", cname, Color(dim, 0.6))
	t.set_stylebox("normal", "LineEdit", _sb(Color(0, 0, 0, 0.35), 3, 8, 2, _col["line"], 1))
	t.set_stylebox("focus", "LineEdit", _sb(Color(0, 0, 0, 0.35), 3, 8, 2, Color(_col["accent"], 0.8), 1))
	t.set_stylebox("read_only", "LineEdit", _sb(Color(0, 0, 0, 0.15), 3, 8, 2, Color(_col["line"], 0.4), 1))
	t.set_color("font_color", "LineEdit", text)
	t.set_color("font_placeholder_color", "LineEdit", Color(dim, 0.75))
	t.set_color("caret_color", "LineEdit", _col["accent"])
	t.set_color("font_uneditable_color", "LineEdit", Color(dim, 0.7))
	t.set_stylebox("panel", "PanelContainer", _sb(_col["panel"], 6, 8, 8, _col["line"], 1))
	t.set_stylebox("panel", "PopupMenu", _sb(Color(_col["ink"], 0.97), 4, 6, 6, _col["line"], 1))
	t.set_stylebox("hover", "PopupMenu", _sb(Color(1, 1, 1, 0.12), 3))
	t.set_color("font_color", "PopupMenu", text)
	t.set_color("font_hover_color", "PopupMenu", text)
	t.set_font_size("font_size", "PopupMenu", FS)
	t.set_stylebox("panel", "TooltipPanel", _sb(Color(_col["ink"], 0.97), 3, 6, 3, _col["line"], 1))
	t.set_color("font_color", "TooltipLabel", text)
	t.set_font_size("font_size", "TooltipLabel", FS_SMALL)
	t.set_stylebox("scroll", "VScrollBar", _sb(Color(0, 0, 0, 0), 3, 3, 0))
	t.set_stylebox("grabber", "VScrollBar", _sb(Color(1, 1, 1, 0.18), 3))
	t.set_stylebox("grabber_highlight", "VScrollBar", _sb(Color(1, 1, 1, 0.3), 3))
	t.set_stylebox("grabber_pressed", "VScrollBar", _sb(Color(1, 1, 1, 0.4), 3))
	var track: StyleBoxFlat = _sb(Color(1, 1, 1, 0.14), 2)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	t.set_stylebox("slider", "HSlider", track)
	var fill: StyleBoxFlat = _sb(_col["accent"], 2)
	fill.content_margin_top = 2
	fill.content_margin_bottom = 2
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_constant("separation", "VBoxContainer", 0)
	t.set_constant("separation", "HBoxContainer", 8)
	return t


# ---------------------------------------------------------------- building blocks

func _label(text: String, color: Color = Color(0, 0, 0, 0), size: int = FS, min_w: int = 0, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = align as HorizontalAlignment
	l.custom_minimum_size = Vector2(min_w, ROW)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	if size != FS:
		l.add_theme_font_size_override("font_size", size)
	if min_w == 0:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## A paragraph held to `lines` lines with an ellipsis; a click opens it and closes it again.
func _para(text: String, lines: int, key: String, color: Color = Color(0, 0, 0, 0)) -> Label:
	var l: Label = Label.new()
	l.text = JobModel.one_line(text) if not _expanded.has(key) else text.strip_edges()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.max_lines_visible = -1 if _expanded.has(key) else lines
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(60, 0)
	l.add_theme_constant_override("line_spacing", 1)
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	l.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if _expanded.has(key):
				_expanded.erase(key)
			else:
				_expanded[key] = true
			_sheet_sig = ""
			refresh(false))
	return l


func _chip(state: String, text: String = "", width: int = 70) -> Label:
	var c: Color = state_color(state)
	var l: Label = _label(text if not text.is_empty() else state, c, FS_SMALL, width, HORIZONTAL_ALIGNMENT_CENTER)
	l.custom_minimum_size = Vector2(width, 18)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.add_theme_stylebox_override("normal", _sb(Color(c, 0.16), 3, 4, 0))
	return l


func _hbox(sep: int = 8) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.custom_minimum_size = Vector2(0, ROW)
	return h


func _rule() -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = _col["line"]
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _spacer(h: int) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _row_button(name_: String, selected_: bool) -> Button:
	var b: Button = Button.new()
	b.name = name_
	b.custom_minimum_size = Vector2(0, ROW)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	b.add_theme_stylebox_override("normal", _sb(Color(_col["accent"], 0.16) if selected_ else Color(0, 0, 0, 0), 3))
	b.add_theme_stylebox_override("hover", _sb(Color(_col["accent"], 0.2) if selected_ else Color(1, 1, 1, 0.07), 3))
	b.add_theme_stylebox_override("pressed", _sb(Color(1, 1, 1, 0.14), 3))
	return b


func _fill_row(b: Button) -> HBoxContainer:
	var h: HBoxContainer = _hbox()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 6
	h.offset_right = -6
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	return h


func _button(text: String, name_: String, primary: bool = false) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.name = name_
	b.custom_minimum_size = Vector2(0, ROW)
	b.focus_mode = Control.FOCUS_NONE
	if primary:
		b.add_theme_stylebox_override("normal", _sb(Color(_col["accent"], 0.85), 3, 12, 2))
		b.add_theme_stylebox_override("hover", _sb(_col["accent"], 3, 12, 2))
		b.add_theme_stylebox_override("pressed", _sb(Color(_col["accent"]).darkened(0.15), 3, 12, 2))
		for k: String in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(k, _col["ink"])
	return b


func _field(placeholder: String, name_: String) -> LineEdit:
	var e: LineEdit = LineEdit.new()
	e.name = name_
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(0, ROW)
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.context_menu_enabled = false
	e.caret_blink = true
	return e


# ---------------------------------------------------------------- the frame (built once)

func _build_frame() -> void:
	_list_panel = PanelContainer.new()
	_list_panel.name = "Games"
	_list_panel.position = Vector2(MARGIN, MARGIN)
	_list_panel.custom_minimum_size = Vector2(LIST_W, 0)
	add_child(_list_panel)
	var v: VBoxContainer = VBoxContainer.new()
	_list_panel.add_child(v)
	var head: HBoxContainer = _hbox()
	head.add_child(_label("GAMES", _col["dim"], FS_SMALL))
	_count = _label("", _col["dim"], FS_SMALL, 200, HORIZONTAL_ALIGNMENT_RIGHT)
	head.add_child(_count)
	v.add_child(head)
	v.add_child(_rule())
	v.add_child(_spacer(2))
	_new_holder = VBoxContainer.new()
	v.add_child(_new_holder)
	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_list_scroll)
	_list_rows = VBoxContainer.new()
	_list_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(_list_rows)
	v.add_child(_spacer(2))
	v.add_child(_rule())
	_msg = _label("", _col["dim"], FS_SMALL)
	_msg.visible = false
	v.add_child(_msg)
	_status = _label("", _col["dim"], FS_SMALL)
	v.add_child(_status)

	_sheet = PanelContainer.new()
	_sheet.name = "Sheet"
	_sheet.position = Vector2(MARGIN + LIST_W + 8, MARGIN)
	_sheet.custom_minimum_size = Vector2(SHEET_W, 0)
	_sheet.visible = false
	add_child(_sheet)
	var sv: VBoxContainer = VBoxContainer.new()
	_sheet.add_child(sv)
	_sheet_head = VBoxContainer.new()
	sv.add_child(_sheet_head)
	_sheet_scroll = ScrollContainer.new()
	_sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sheet_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sv.add_child(_sheet_scroll)
	_sheet_body = VBoxContainer.new()
	_sheet_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet_scroll.add_child(_sheet_body)

	_lightbox = ColorRect.new()
	_lightbox.name = "Lightbox"
	(_lightbox as ColorRect).color = Color(_col["ink"], 0.86)
	_lightbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lightbox.visible = false
	_lightbox.mouse_filter = Control.MOUSE_FILTER_STOP
	_lightbox.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_lightbox.visible = false)
	add_child(_lightbox)
	_lightbox_tex = TextureRect.new()
	_lightbox_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lightbox_tex.offset_left = 48
	_lightbox_tex.offset_top = 32
	_lightbox_tex.offset_right = -48
	_lightbox_tex.offset_bottom = -64
	_lightbox_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lightbox_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_lightbox_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lightbox.add_child(_lightbox_tex)
	_lightbox_cap = _label("", _col["text"], FS, 0, HORIZONTAL_ALIGNMENT_CENTER)
	_lightbox_cap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_lightbox_cap.offset_top = -52
	_lightbox_cap.offset_bottom = -24
	_lightbox_cap.offset_left = 48
	_lightbox_cap.offset_right = -48
	_lightbox.add_child(_lightbox_cap)


func _process(delta: float) -> void:
	_poll_left -= delta
	if _poll_left <= 0.0:
		_poll_left = 1.0
		refresh(false)
	_fit()


func _fit() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if _lightbox.visible and (_lightbox.size != vp or _lightbox.global_position != Vector2.ZERO):
		# sized by hand: the panel may sit under a CanvasLayer or a parent without a size
		_lightbox.global_position = Vector2.ZERO
		_lightbox.size = vp
	var max_h: float = vp.y - 2.0 * MARGIN
	var rows_h: float = _list_rows.get_combined_minimum_size().y
	_list_scroll.custom_minimum_size.y = minf(rows_h, maxf(ROW * 2.0, max_h - 150.0 - _new_holder.get_combined_minimum_size().y))
	_list_panel.size = Vector2(LIST_W, 0)
	if _sheet.visible:
		var body_h: float = _sheet_body.get_combined_minimum_size().y
		var head_h: float = _sheet_head.get_combined_minimum_size().y
		_sheet_scroll.custom_minimum_size.y = minf(body_h, max_h - head_h - 18.0)
		_sheet.size = Vector2(SHEET_W, 0)


# ---------------------------------------------------------------- reading

func refresh(force: bool) -> void:
	if door != null and door.tick():
		force = true
	var now: float = Time.get_unix_time_from_system()
	var dirs: PackedStringArray = JobModel.list_job_dirs(jobs_root)
	var seen: Dictionary = {}
	for dir: String in dirs:
		var id: String = dir.get_file()
		seen[id] = true
		var p: String = dir.path_join("job.jsonl")
		var stamp: String = "%d:%d" % [FileAccess.get_modified_time(p), _file_size(p)]
		var old: Dictionary = jobs.get(id, {})
		var live: bool = not old.is_empty() and (str(old.get("phase", "")) in JobModel.LIVE_PHASES)
		if force or old.is_empty() or _stamps.get(id, "") != stamp or live:
			var job: Dictionary = JobModel.read_job(dir, now)
			if not bool(job["ok"]) and not old.is_empty() and bool(old.get("ok", false)):
				# the file could not be opened this second (it is being written): keep the last good picture
				job = old
			jobs[id] = job
			_stamps[id] = stamp
		var j: Dictionary = jobs[id]
		if str(j["phase"]) in JobModel.LIVE_PHASES and door != null:
			var alive: bool = door.foreman_alive(dir, int(j.get("lock_pid", 0)))
			if not alive:
				# a lock can be gone for a moment between two Foreman commands: look once more next second
				j["lock_pid"] = JobModel.read_lock(dir)
				alive = door.foreman_alive(dir, int(j["lock_pid"])) or (now - float(j.get("last_ts", 0.0)) < 4.0)
			_alive[id] = alive
			if not alive:
				# a job nobody works on stops counting at its last event
				var lock_pid: int = int(j["lock_pid"])
				j = JobModel.read_job(dir, float(j.get("last_ts", now)))
				j["lock_pid"] = lock_pid
				jobs[id] = j
		else:
			_alive[id] = true
		if not _known_ids.has(id):
			_known_ids[id] = true
			if not _want_select_sentence.is_empty() and Door.clean_text(str(j.get("sentence", ""))) == _want_select_sentence:
				_want_select_sentence = ""
				message = ""
				selected = id
				sections_chosen = false
				job_selected.emit(id)
	for id: String in jobs.keys():
		if not seen.has(id):
			jobs.erase(id)
			if selected == id:
				selected = ""
	var ids: Array = jobs.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ta: float = float(jobs[a].get("first_ts", 0.0))
		var tb: float = float(jobs[b].get("first_ts", 0.0))
		return ta > tb if ta != tb else a > b)
	order = PackedStringArray(ids)
	_draw_list()
	_draw_sheet()
	for id: String in _elapsed_labels.keys():
		if jobs.has(id) and is_instance_valid(_elapsed_labels[id]):
			(_elapsed_labels[id] as Label).text = JobModel.fmt_time(_elapsed(id))


static func _file_size(path: String) -> int:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	var n: int = f.get_length()
	f.close()
	return n


## Time shown for a job: a job whose Foreman is gone stops counting at its last event.
func _elapsed(id: String) -> float:
	var j: Dictionary = jobs.get(id, {})
	if shown_phase(id) == "stalled":
		return maxf(0.0, float(j.get("last_ts", 0.0)) - float(j.get("first_ts", 0.0)))
	return float(j.get("elapsed_s", 0.0))


func _open_questions(j: Dictionary) -> int:
	var n: int = 0
	for q: Dictionary in j.get("questions", []):
		if bool(q["open"]):
			n += 1
	return n


## What the chip says: the job's phase, or `stalled` when a phase that needs a Foreman has none.
func shown_phase(id: String) -> String:
	var j: Dictionary = jobs.get(id, {})
	var phase: String = str(j.get("phase", "unreadable"))
	if phase in JobModel.LIVE_PHASES and not bool(_alive.get(id, true)):
		return "stalled"
	return phase


func select(id: String) -> void:
	if not jobs.has(id):
		return
	selected = id
	_sheet_sig = ""
	_list_sig = ""
	refresh(false)
	job_selected.emit(id)


func show_section(name_: String) -> void:
	sections_chosen = true
	for s: String in SECTIONS:
		open_sections[s] = s == name_ or name_ == "all"
	if name_ == "notes":
		open_sections["build"] = true
		notes_open = true
	_sheet_sig = ""


func _report(err: String) -> void:
	say(err, not err.is_empty())


func say(text: String, bad: bool = false) -> void:
	message = text
	message_bad = bad
	_list_sig = ""


# ---------------------------------------------------------------- layer one: the list

func _draw_list() -> void:
	var foreman_line: String = ""
	var foreman_bad: bool = false
	if door == null:
		foreman_line = "No Foreman door"
	elif read_only:
		foreman_line = "Read only: the panel starts nothing here"
	elif not door.available:
		foreman_line = door.problem
		foreman_bad = true
	else:
		foreman_line = "Foreman ready · node %s%s" % [door.node_version, (" · " + door.flags_name) if not door.flags_name.is_empty() else ""]
	var pending: Array = door.busy_new() if door != null else []
	var new_err: String = door.last_error("new") if door != null else ""
	var sig: String = "%s|%s|%s|%s|%s|%s|%s" % [selected, new_open, foreman_line, message, str(pending), new_err, str(size)]
	for id: String in order:
		var j: Dictionary = jobs[id]
		sig += "|%s:%s:%d:%d:%s:%d" % [id, shown_phase(id), int(j["done"]), int(j["total"]), str(j["title"]), _open_questions(j)]
	if sig == _list_sig:
		return
	_list_sig = sig
	var keep_text: String = ""
	var keep_focus: bool = false
	var old_field: LineEdit = _new_holder.find_child("NewField", true, false) as LineEdit
	if old_field != null:
		keep_text = old_field.text
		keep_focus = old_field.has_focus()
	for c: Node in _new_holder.get_children():
		_new_holder.remove_child(c)
		c.queue_free()
	for c: Node in _list_rows.get_children():
		_list_rows.remove_child(c)
		c.queue_free()
	_elapsed_labels.clear()
	_count.text = "%d" % order.size() if order.size() > 0 else ""
	_status.text = foreman_line
	_status.add_theme_color_override("font_color", _col["failed"] if foreman_bad else _col["dim"])
	_msg.visible = not message.is_empty()
	_msg.text = message
	_msg.add_theme_color_override("font_color", _col["failed"] if message_bad else _col["dim"])

	# the first row: New game...
	var nb: Button = _row_button("NewRow", new_open)
	var nh: HBoxContainer = _fill_row(nb)
	nh.add_child(_label("+", _col["accent"], FS, 10))
	nh.add_child(_label("New game…", _col["text"]))
	nb.pressed.connect(func() -> void:
		new_open = not new_open
		message = ""
		refresh(false)
		var f: LineEdit = _new_holder.find_child("NewField", true, false) as LineEdit
		if f != null and f.editable:
			f.grab_focus())
	_new_holder.add_child(nb)
	if new_open:
		var can: bool = door != null and door.available and not read_only
		var row: HBoxContainer = _hbox(6)
		var field: LineEdit = _field("Describe a game…", "NewField")
		field.text = keep_text
		field.editable = can
		row.add_child(field)
		var go: Button = _button("Design", "NewSend", true)
		go.disabled = not can
		row.add_child(go)
		var submit: Callable = func() -> void: _submit_new(field.text)
		field.text_submitted.connect(func(_t: String) -> void: submit.call())
		go.pressed.connect(submit)
		var wrap: MarginContainer = MarginContainer.new()
		wrap.add_theme_constant_override("margin_top", 3)
		wrap.add_theme_constant_override("margin_bottom", 3)
		wrap.add_child(row)
		_new_holder.add_child(wrap)
		if not can:
			_new_holder.add_child(_label("The Foreman cannot be started (see below)." if not read_only else "Read only: no game can be started from here.", _col["failed"], FS_SMALL))
		elif keep_focus:
			field.grab_focus.call_deferred()
			field.set_caret_column.call_deferred(keep_text.length())
	if not new_err.is_empty():
		_new_holder.add_child(_label(new_err, _col["failed"], FS_SMALL))
	for s: Variant in pending:
		var prow: HBoxContainer = _hbox()
		var pm: MarginContainer = MarginContainer.new()
		pm.add_theme_constant_override("margin_left", 6)
		pm.add_theme_constant_override("margin_right", 6)
		pm.add_child(prow)
		prow.add_child(_label(str(s), _col["dim"]))
		prow.add_child(_chip("designing", "starting"))
		_list_rows.add_child(pm)

	if order.is_empty() and pending.is_empty():
		_list_rows.add_child(_label("Nothing built yet.", _col["dim"]))
	for id: String in order:
		var j: Dictionary = jobs[id]
		var phase: String = shown_phase(id)
		var b: Button = _row_button("Row_" + id, id == selected)
		var h: HBoxContainer = _fill_row(b)
		h.add_child(_label(str(j["title"]), _col["text"]))
		var chip_text: String = phase
		if phase == "approve":
			chip_text = "approve?"
		elif _open_questions(j) > 0 and phase in ["paused", "running"]:
			chip_text = "question"
		elif phase == "paused" and j["pause_kind"] == "budget":
			chip_text = "budget"
		elif phase == "unreadable":
			chip_text = "unreadable"
		h.add_child(_chip("approve" if chip_text == "question" else phase, chip_text))
		var total: int = int(j["total"])
		h.add_child(_label("%d/%d" % [int(j["done"]), total] if total > 0 else "–", _col["dim"], FS, 30, HORIZONTAL_ALIGNMENT_RIGHT))
		var bar: Bar = Bar.new()
		bar.custom_minimum_size = Vector2(64, ROW)
		bar.frac = float(j["done"]) / float(total) if total > 0 else 0.0
		bar.color = state_color(phase)
		bar.hollow = phase == "stalled"
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(bar)
		var el: Label = _label(JobModel.fmt_time(_elapsed(id)), _col["dim"], FS, 50, HORIZONTAL_ALIGNMENT_RIGHT)
		h.add_child(el)
		_elapsed_labels[id] = el
		b.pressed.connect(func() -> void:
			if selected == id:
				selected = ""
				_sheet_sig = ""
				refresh(false)
			else:
				sections_chosen = false
				select(id))
		_list_rows.add_child(b)


func _submit_new(text: String) -> void:
	var err: String = door.new_game(text)
	action_started.emit("new", err)
	if err.is_empty():
		_want_select_sentence = Door.clean_text(text)
		new_open = false
		say("The Designer is writing a brief…")
	else:
		say(err, true)
	refresh(false)


# ---------------------------------------------------------------- layer two: the sheet

func _draw_sheet() -> void:
	if selected.is_empty() or not jobs.has(selected):
		_sheet.visible = false
		_sheet_sig = ""
		return
	var j: Dictionary = jobs[selected]
	var phase: String = shown_phase(selected)
	if not sections_chosen:
		open_sections["brief"] = phase in ["designing", "approve", "planning", "unreadable"]
		open_sections["build"] = not bool(open_sections["brief"])
		open_sections["change"] = false
		open_sections["tune"] = false
	var busy: String = door.busy(str(j["dir"])) if door != null else ""
	var err: String = door.last_error(str(j["dir"])) if door != null else ""
	var sig: String = "%s|%d|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [selected, int(j["last_seq"]), phase, busy, err, str(open_sections), notes_open,
		str(j["torn"]), str(_expanded.keys()), "", str((j["params"] as Array).size())]
	if sig == _sheet_sig:
		_update_live_figures(j)
		return
	_sheet_sig = sig
	# keep what the player is typing
	var kept: Dictionary = {}
	for n: String in ["ChangeField", "AnswerField"]:
		var f: LineEdit = _sheet_body.find_child(n, true, false) as LineEdit
		if f != null:
			kept[n] = {"text": f.text, "focus": f.has_focus(), "caret": f.caret_column}
	var scroll_at: int = _sheet_scroll.scroll_vertical
	for c: Node in _sheet_head.get_children():
		_sheet_head.remove_child(c)
		c.queue_free()
	for c: Node in _sheet_body.get_children():
		_sheet_body.remove_child(c)
		c.queue_free()
	_sheet.visible = true

	# header: title, chip, figures; then one line that says what is going on
	var head: HBoxContainer = _hbox()
	var title: Label = _label(str(j["title"]), _col["text"], 15)
	head.add_child(title)
	head.add_child(_chip(phase, "approve?" if phase == "approve" else phase))
	var fig: Label = _label(_head_figures(j), _col["dim"], FS, 150, HORIZONTAL_ALIGNMENT_RIGHT)
	fig.name = "HeadFigures"
	head.add_child(fig)
	_sheet_head.add_child(head)
	var line: Dictionary = _status_line(j, phase, busy, err)
	var sl: HBoxContainer = _hbox(6)
	var dot: Dot = Dot.new()
	dot.custom_minimum_size = Vector2(10, ROW)
	dot.color = line["color"]
	sl.add_child(dot)
	var st: Label = _label(str(line["text"]), line["color"] if bool(line["strong"]) else _col["dim"])
	st.name = "StatusLine"
	sl.add_child(st)
	if bool(line.get("resume", false)) and not read_only:
		var rb: Button = _button("Resume", "ResumeButton")
		rb.pressed.connect(func() -> void:
			var e: String = door.resume(str(j["dir"]), int(j["total"]) > 0, not str(j["job_state"]).is_empty())
			action_started.emit("resume", e)
			_report(e)
			refresh(true))
		sl.add_child(rb)
	_sheet_head.add_child(sl)
	_sheet_head.add_child(_rule())

	_section("brief", "BRIEF", _brief_summary(j), func(box: VBoxContainer) -> void: _fill_brief(box, j, phase, busy))
	_section("build", "BUILD", _build_summary(j), func(box: VBoxContainer) -> void: _fill_build(box, j, phase, busy))
	_section("change", "CHANGE", _change_summary(j), func(box: VBoxContainer) -> void: _fill_change(box, j, phase, busy))
	_section("tune", "TUNE", _tune_summary(j), func(box: VBoxContainer) -> void: _fill_tune(box, j))

	for n: String in kept.keys():
		var f: LineEdit = _sheet_body.find_child(n, true, false) as LineEdit
		if f != null:
			f.text = str(kept[n]["text"])
			if bool(kept[n]["focus"]) and f.editable:
				f.grab_focus.call_deferred()
				f.set_caret_column.call_deferred(int(kept[n]["caret"]))
	_sheet_scroll.set_deferred("scroll_vertical", scroll_at)


func _update_live_figures(j: Dictionary) -> void:
	var fig: Label = _sheet_head.find_child("HeadFigures", true, false) as Label
	if fig != null:
		fig.text = _head_figures(j)


func _head_figures(j: Dictionary) -> String:
	return "%s · %s tok" % [JobModel.fmt_time(_elapsed(str(j["id"]))), JobModel.fmt_tokens(int(j["tokens_in"]) + int(j["tokens_out"]))]


func _status_line(j: Dictionary, phase: String, busy: String, err: String) -> Dictionary:
	var open_change: String = ""
	for c: Dictionary in j["changes"]:
		if c["outcome"] == "in flight":
			open_change = str(c["text"])
	if not err.is_empty():
		return {"text": err, "color": _col["failed"], "strong": true, "resume": phase == "stalled"}
	match phase:
		"unreadable":
			return {"text": "This job cannot be read: %s" % str(j["error"]), "color": _col["failed"], "strong": true}
		"stalled":
			var lock: int = int(j.get("lock_pid", 0))
			var why: String = "process %d is gone" % lock if lock > 0 else "nothing holds its lock"
			return {"text": "No Foreman is working on this job (%s)." % why, "color": _col["failed"], "strong": true, "resume": true}
		"failed", "cancelled":
			return {"text": str(j["fail_line"]), "color": _col["failed"], "strong": phase == "failed"}
		"approve":
			return {"text": "The brief waits for you: approve it or discard it.", "color": _col["ask"], "strong": true}
		"paused":
			if j["pause_kind"] == "question":
				return {"text": "Paused: a builder waits for your answer (see Build).", "color": _col["ask"], "strong": true}
			if j["pause_kind"] == "budget":
				return {"text": "Paused on budget: %s" % JobModel.one_line(str(j["budget_reason"]) if j["budget_state"] == "paused" else str(j["job_reason"]), 90), "color": _col["paused"], "strong": true, "resume": true}
			return {"text": "Paused: %s" % JobModel.one_line(str(j["job_reason"]), 90), "color": _col["paused"], "strong": true, "resume": true}
	if phase == "running" and _open_questions(j) > 0:
		return {"text": "A builder asks a question (see Build); the other packages go on.", "color": _col["ask"], "strong": true}
	if not open_change.is_empty() and phase == "running":
		return {"text": "Change in flight: %s" % JobModel.one_line(open_change, 90), "color": _col["running"], "strong": false}
	if j.get("torn", false):
		return {"text": str(j["activity"]) + " (a line is being written)", "color": state_color(phase), "strong": false}
	return {"text": str(j["activity"]), "color": state_color(phase), "strong": false}


func _section(key: String, title: String, summary: String, fill: Callable) -> void:
	var open: bool = bool(open_sections.get(key, false))
	var b: Button = _row_button("Sec_" + key, false)
	var h: HBoxContainer = _fill_row(b)
	h.offset_left = 0
	var tri: Fold = Fold.new()
	tri.open = open
	tri.color = _col["dim"]
	tri.custom_minimum_size = Vector2(12, ROW)
	tri.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tri)
	h.add_child(_label(title, _col["text"] if open else _col["dim"], FS_SMALL, 60))
	h.add_child(_label(summary, _col["dim"], FS_SMALL, 0, HORIZONTAL_ALIGNMENT_RIGHT))
	b.pressed.connect(func() -> void:
		sections_chosen = true
		open_sections[key] = not open
		_sheet_sig = ""
		refresh(false))
	_sheet_body.add_child(b)
	if open:
		var m: MarginContainer = MarginContainer.new()
		m.add_theme_constant_override("margin_left", 12)
		m.add_theme_constant_override("margin_right", 6)
		m.add_theme_constant_override("margin_top", 2)
		m.add_theme_constant_override("margin_bottom", 8)
		var box: VBoxContainer = VBoxContainer.new()
		box.name = "Body_" + key
		box.add_theme_constant_override("separation", 2)
		m.add_child(box)
		_sheet_body.add_child(m)
		fill.call(box)
	_sheet_body.add_child(_rule())


# ---- Brief

func _brief_summary(j: Dictionary) -> String:
	var est: Dictionary = j["estimate"]
	if est.is_empty():
		return "being written"
	return "est. %d packages · %d min · %s tok" % [int(est.get("packages", 0)), int(est.get("wallMinutes", 0)), JobModel.fmt_tokens(int(est.get("tokens", 0)))]


func _kv(box: VBoxContainer, key: String, value: Control) -> void:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var k: Label = _label(key, _col["dim"], FS, 62)
	k.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if value is Label and (value as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
		k.custom_minimum_size.y = 0
		k.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	h.add_child(k)
	h.add_child(value)
	box.add_child(h)


func _fill_brief(box: VBoxContainer, j: Dictionary, phase: String, busy: String) -> void:
	box.add_child(_para("“%s”" % str(j["sentence"]), 3, "sentence"))
	box.add_child(_spacer(4))
	var brief: Dictionary = j["brief"]
	if brief.is_empty():
		box.add_child(_label("The Designer has not answered yet." if phase != "failed" else "No brief was written.", _col["dim"]))
		return
	for key: String in ["rules", "arena", "ai", "controls", "mood"]:
		if brief.has(key):
			var p: Label = _para(str(brief[key]), 2, "brief." + key)
			p.add_theme_constant_override("line_spacing", 1)
			_kv(box, key, p)
	var est: Dictionary = j["estimate"]
	var est_text: String = "%d packages · about %d min · %s tokens" % [int(est.get("packages", 0)), int(est.get("wallMinutes", 0)), JobModel.fmt_tokens(int(est.get("tokens", 0)))]
	_kv(box, "estimate", _label(est_text, _col["text"]))
	if int(j["total"]) > 0:
		_kv(box, "so far", _label("%d of %d packages · %s · %s tokens" % [int(j["done"]), int(j["total"]), JobModel.fmt_time(float(j["elapsed_s"])),
			JobModel.fmt_tokens(int(j["tokens_in"]) + int(j["tokens_out"]))], _col["text"]))
	if phase == "approve":
		box.add_child(_spacer(4))
		var h: HBoxContainer = _hbox()
		var ok: Button = _button("Approve and build", "ApproveButton", true)
		var no: Button = _button("Discard", "DiscardButton")
		var can: bool = door != null and door.available and not read_only and busy.is_empty()
		ok.disabled = not can
		no.disabled = not can
		ok.pressed.connect(func() -> void:
			var e: String = door.approve(str(j["dir"]))
			action_started.emit("approve", e)
			_report(e)
			refresh(true))
		no.pressed.connect(func() -> void:
			var e: String = door.discard(str(j["dir"]))
			action_started.emit("discard", e)
			_report(e)
			refresh(true))
		h.add_child(ok)
		h.add_child(no)
		if not can:
			h.add_child(_label("starting…" if not busy.is_empty() else ("read only" if read_only else door.problem), _col["dim"], FS_SMALL))
		box.add_child(h)
	elif not str(j["approved_by"]).is_empty():
		_kv(box, "approved", _label("by %s%s" % [str(j["approved_by"]), (" · billing: " + str(j["billing"])) if not str(j["billing"]).is_empty() else ""], _col["dim"]))


# ---- Build

func _build_summary(j: Dictionary) -> String:
	if int(j["total"]) == 0:
		return "no plan yet"
	var open_q: int = 0
	for q: Dictionary in j["questions"]:
		if bool(q["open"]):
			open_q += 1
	var s: String = "%d of %d packages · %d pictures" % [int(j["done"]), int(j["total"]), _picture_count(j)]
	if open_q > 0:
		s = "%d question%s · %s" % [open_q, "" if open_q == 1 else "s", s]
	return s


func _picture_sets(j: Dictionary) -> Array:
	var sets: Array = []
	for m: Dictionary in j["milestones"]:
		var verdict: String = ""
		if str(m["summary"]).contains("NOT ok"):
			verdict = "critic: not ok"
		elif str(m["summary"]).contains("critic (V5) ok"):
			verdict = "critic: ok"
		sets.append({"name": str(m["milestone"]), "captures": m["captures"], "summary": str(m["summary"]), "verdict": verdict})
	for n: Dictionary in j["notes"]:
		var t: String = str(n["text"])
		if bool(n["own"]) and t.contains("pictures of the pack as it is promoted"):
			var caps: Array = []
			for f: String in t.get_slice(": ", t.get_slice_count(": ") - 1).split(", "):
				if f.strip_edges().ends_with(".png"):
					caps.append(f.strip_edges())
			var nth: String = t.get_slice("promoted the ", 1).get_slice(" ", 0)
			sets.append({"name": "after change" if nth.is_empty() else "promotion " + nth.left(1), "captures": caps, "summary": "the pack as promoted again after a change request", "verdict": ""})
	return sets


func _picture_count(j: Dictionary) -> int:
	var n: int = 0
	for s: Dictionary in _picture_sets(j):
		n += (s["captures"] as Array).size()
	return n


func _fill_build(box: VBoxContainer, j: Dictionary, phase: String, busy: String) -> void:
	if int(j["total"]) == 0:
		box.add_child(_label("No plan yet: packages appear here once the Planner has cut the game." if phase != "approve" else "Nothing is built before you approve the brief.", _col["dim"]))
		return
	# column heads
	var hh: HBoxContainer = _hbox()
	hh.custom_minimum_size.y = 18
	for col: Array in [["package", 0], ["state", 70], ["rnd", 26], ["time", 58], ["tokens", 50]]:
		var l: Label = _label(str(col[0]), Color(_col["dim"], 0.7), FS_SMALL, int(col[1]), HORIZONTAL_ALIGNMENT_LEFT if int(col[1]) == 0 else (HORIZONTAL_ALIGNMENT_CENTER if col[0] == "state" else HORIZONTAL_ALIGNMENT_RIGHT))
		l.custom_minimum_size.y = 18
		hh.add_child(l)
	box.add_child(hh)
	for id: String in j["order"]:
		var p: Dictionary = (j["packages"] as Dictionary).get(id, {})
		if p.is_empty():
			continue
		var h: HBoxContainer = _hbox()
		var names: HBoxContainer = _hbox(8)
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idl: Label = _label(id, _col["text"], FS, 0)
		idl.size_flags_stretch_ratio = 0.8
		names.add_child(idl)
		var tl: Label = _label(str(p["title"]), _col["dim"], FS, 0)
		tl.size_flags_stretch_ratio = 1.4
		names.add_child(tl)
		h.add_child(names)
		var pst: String = str(p["state"])
		h.add_child(_chip(pst, "built" if pst == "promoted" else pst))
		h.add_child(_label("%d" % int(p["round"]), _col["dim"], FS, 26, HORIZONTAL_ALIGNMENT_RIGHT))
		h.add_child(_label(JobModel.fmt_minutes(float(p["work_s"])), _col["dim"], FS, 58, HORIZONTAL_ALIGNMENT_RIGHT))
		h.add_child(_label(JobModel.fmt_tokens(int(p["tokens_in"]) + int(p["tokens_out"])), _col["dim"], FS, 50, HORIZONTAL_ALIGNMENT_RIGHT))
		box.add_child(h)
		if pst == "failed" and not str(p["cause"]).is_empty():
			box.add_child(_para("%s: %s" % [str(p["cause"]).replace("_", " "), str(p["detail"])], 1, "fail." + id, _col["failed"]))
	# questions
	for q: Dictionary in j["questions"]:
		box.add_child(_spacer(4))
		if bool(q["open"]):
			_question_block(box, j, q, busy, phase)
		else:
			_kv(box, "asked", _para("%s: %s" % [str(q["package"]), str(q["text"])], 1, "q.%d" % int(q["seq"]), _col["dim"]))
			_kv(box, "answer", _para(str(q["answer"]), 1, "a.%d" % int(q["seq"]), _col["dim"]))
	# pictures
	var sets: Array = _picture_sets(j)
	if not sets.is_empty():
		box.add_child(_spacer(4))
	for s: Dictionary in sets:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var side: VBoxContainer = VBoxContainer.new()
		side.custom_minimum_size = Vector2(96, 0)
		side.add_child(_label(str(s["name"]).replace("_", " "), _col["text"], FS, 96))
		if not str(s["verdict"]).is_empty():
			var vl: Label = _label(str(s["verdict"]), _col["paused"] if str(s["verdict"]).contains("not") else _col["done"], FS_SMALL, 96)
			vl.custom_minimum_size.y = 16
			side.add_child(vl)
		row.add_child(side)
		for rel: Variant in s["captures"]:
			row.add_child(_thumb(str(j["dir"]).path_join(str(rel)), "%s · %s" % [str(s["name"]).replace("_", " "), str(rel).get_file()]))
		box.add_child(row)
		box.add_child(_spacer(2))
	# builder notes, folded away
	var notes: Array = j["notes"]
	if not notes.is_empty():
		var nb: Button = _row_button("NotesFold", false)
		var nh: HBoxContainer = _fill_row(nb)
		nh.offset_left = 0
		var tri: Fold = Fold.new()
		tri.open = notes_open
		tri.color = _col["dim"]
		tri.custom_minimum_size = Vector2(12, ROW)
		tri.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nh.add_child(tri)
		nh.add_child(_label("Builder notes (%d)" % notes.size(), _col["dim"], FS))
		nb.pressed.connect(func() -> void:
			notes_open = not notes_open
			_sheet_sig = ""
			refresh(false))
		box.add_child(nb)
		if notes_open:
			for n: Dictionary in notes:
				var who: String = "foreman" if bool(n["own"]) else "%s r%d" % [str(n["package"]), int(n["round"])]
				var h2: HBoxContainer = HBoxContainer.new()
				h2.add_theme_constant_override("separation", 8)
				var wl: Label = _label(who, _col["dim"], FS_SMALL, 110)
				wl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
				h2.add_child(wl)
				h2.add_child(_para(str(n["text"]).trim_prefix("[foreman] "), 2, "note.%d" % int(n["seq"])))
				box.add_child(h2)


func _question_block(box: VBoxContainer, j: Dictionary, q: Dictionary, busy: String, phase: String) -> void:
	var frame: PanelContainer = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _sb(Color(_col["ask"], 0.07), 3, 8, 6, Color(_col["ask"], 0.45), 1))
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	frame.add_child(v)
	v.add_child(_label("%s asks" % str(q["package"]), _col["ask"], FS_SMALL))
	v.add_child(_para(str(q["text"]), 4, "q.%d" % int(q["seq"])))
	var working: bool = phase in JobModel.LIVE_PHASES
	var can: bool = door != null and door.available and not read_only and busy.is_empty()
	var field: LineEdit = _field("Your answer…", "AnswerField")
	field.editable = can
	v.add_child(field)
	var h: HBoxContainer = _hbox()
	var pick: OptionButton = OptionButton.new()
	pick.name = "AnswerChange"
	pick.custom_minimum_size = Vector2(0, ROW)
	pick.focus_mode = Control.FOCUS_NONE
	pick.add_item("answer only")
	for id: String in j["order"]:
		if id != str(q["package"]):
			pick.add_item("let it change %s" % id)
			pick.set_item_metadata(pick.item_count - 1, id)
	pick.disabled = not can
	h.add_child(pick)
	var pad: Control = Control.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(pad)
	var send: Button = _button("Answer", "AnswerSend", true)
	send.disabled = not can
	h.add_child(send)
	v.add_child(h)
	if not can:
		var why: String = "Read only here." if read_only else ("Sending…" if not busy.is_empty() else door.problem)
		v.add_child(_label(why, _col["dim"], FS_SMALL))
	var go: Callable = func() -> void:
		var meta: Variant = pick.get_item_metadata(pick.selected) if pick.selected >= 0 else null
		var alive: bool = door.foreman_alive(str(j["dir"]), int(j.get("lock_pid", 0)))
		var e: String = door.answer(str(j["dir"]), str(q["package"]), field.text, str(meta) if meta != null else "", alive)
		action_started.emit("answer", e)
		if e.is_empty():
			field.text = ""
			say("")
		else:
			say(e, true)
		refresh(true)
	send.pressed.connect(go)
	field.text_submitted.connect(func(_t: String) -> void: go.call())
	box.add_child(frame)


func _thumb(path: String, caption: String) -> Control:
	var b: Button = Button.new()
	b.name = "Thumb_" + path.get_file().get_basename()
	b.custom_minimum_size = Vector2(128, 72)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", _sb(Color(0, 0, 0, 0.4), 2, 0, 0, _col["line"], 1))
	b.add_theme_stylebox_override("hover", _sb(Color(0, 0, 0, 0.4), 2, 0, 0, _col["accent"], 1))
	b.add_theme_stylebox_override("pressed", _sb(Color(0, 0, 0, 0.4), 2, 0, 0, _col["accent"], 1))
	var tex: Texture2D = _thumb_texture(path)
	if tex == null:
		var l: Label = _label("no picture", _col["dim"], FS_SMALL, 0, HORIZONTAL_ALIGNMENT_CENTER)
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.add_child(l)
		b.disabled = true
		return b
	var tr: TextureRect = TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.offset_left = 1
	tr.offset_top = 1
	tr.offset_right = -1
	tr.offset_bottom = -1
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(tr)
	b.pressed.connect(func() -> void: open_picture(path, caption))
	return b


func _thumb_texture(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var stamp: int = FileAccess.get_modified_time(path)
	if _thumbs.has(path) and int(_thumbs[path]["stamp"]) == stamp:
		return _thumbs[path]["tex"]
	var img: Image = Image.new()
	if img.load(path) != OK:
		return null
	img.resize(256, int(256.0 * float(img.get_height()) / float(maxi(1, img.get_width()))), Image.INTERPOLATE_LANCZOS)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_thumbs[path] = {"tex": tex, "stamp": stamp}
	return tex


func open_picture(path: String, caption: String) -> void:
	var img: Image = Image.new()
	if img.load(path) != OK:
		return
	_lightbox_tex.texture = ImageTexture.create_from_image(img)
	_lightbox_cap.text = caption + "  ·  click to close"
	_lightbox.visible = true


# ---- Change

func _change_summary(j: Dictionary) -> String:
	var n: int = (j["changes"] as Array).size()
	if n == 0:
		return "no requests"
	var flying: int = 0
	for c: Dictionary in j["changes"]:
		if c["outcome"] == "in flight":
			flying += 1
	return "%d request%s%s" % [n, "" if n == 1 else "s", " · 1 in flight" if flying > 0 else ""]


func _fill_change(box: VBoxContainer, j: Dictionary, phase: String, busy: String) -> void:
	var why: String = ""
	if int(j["done"]) == 0:
		why = "A change can be asked for once the first package is built."
	elif read_only:
		why = "Read only: no request can be sent from here."
	elif door == null or not door.available:
		why = door.problem if door != null else "No Foreman."
	elif not busy.is_empty() or (phase in JobModel.LIVE_PHASES):
		why = "The Foreman is busy with this job; a request can be sent when it stops."
	elif phase == "cancelled":
		why = "This job was discarded."
	var h: HBoxContainer = _hbox(6)
	var field: LineEdit = _field("What should be different?", "ChangeField")
	field.editable = why.is_empty()
	h.add_child(field)
	var send: Button = _button("Send", "ChangeSend", true)
	send.disabled = not why.is_empty()
	h.add_child(send)
	box.add_child(h)
	if not why.is_empty():
		box.add_child(_label(why, _col["dim"], FS_SMALL))
	var go: Callable = func() -> void:
		var e: String = door.change(str(j["dir"]), field.text)
		action_started.emit("change", e)
		if e.is_empty():
			field.text = ""
			say("")
		else:
			say(e, true)
		refresh(true)
	send.pressed.connect(go)
	field.text_submitted.connect(func(_t: String) -> void: go.call())
	var changes: Array = j["changes"]
	if not changes.is_empty():
		box.add_child(_spacer(4))
	for i: int in range(changes.size() - 1, -1, -1):
		var c: Dictionary = changes[i]
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_para(str(c["text"]), 1, "change.%d" % int(c["seq"])))
		var owner_l: Label = _label(str(c["owner"]) if not str(c["owner"]).is_empty() else "–", _col["dim"], FS_SMALL, 96, HORIZONTAL_ALIGNMENT_RIGHT)
		owner_l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(owner_l)
		var outcome: String = str(c["outcome"])
		if outcome == "in flight" and shown_phase(str(j["id"])) != "running":
			outcome = "no foreman" if shown_phase(str(j["id"])) == "stalled" else "waiting"
		var label: String = outcome
		if outcome == "made" and not str(c["version"]).is_empty():
			label = "made · " + str(c["version"])
		var chip: Label = _chip(outcome, label, 92)
		chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(chip)
		box.add_child(row)


# ---- Tune

func _tune_summary(j: Dictionary) -> String:
	if str(j["pack_dir"]).is_empty():
		return "no promoted pack"
	var n: int = (j["params"] as Array).size()
	return "%d value%s" % [n, "" if n == 1 else "s"] if n > 0 else "nothing declared"


func _fill_tune(box: VBoxContainer, j: Dictionary) -> void:
	if str(j["pack_dir"]).is_empty():
		box.add_child(_label("Nothing to tune yet: this game has no promoted pack.", _col["dim"]))
		return
	var params: Array = j["params"]
	if params.is_empty():
		box.add_child(_label("This pack declares no tunable values (its pack.json has no “params”).", _col["dim"]))
		return
	for p: Dictionary in params:
		var h: HBoxContainer = _hbox()
		h.add_child(_label(str(p.get("label", p.get("name", "?"))), _col["text"], FS, 250))
		var lo: float = float(p.get("min", 0.0))
		var hi: float = float(p.get("max", 1.0))
		var step: float = float(p.get("step", 0.0))
		var s: HSlider = HSlider.new()
		s.name = "Tune_" + str(p.get("name", "x"))
		s.min_value = lo
		s.max_value = hi
		s.step = step if step > 0.0 else (hi - lo) / 100.0
		s.value = float(p["value"])
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.custom_minimum_size = Vector2(120, 16)
		s.focus_mode = Control.FOCUS_NONE
		s.editable = bool(p["ok"]) and not read_only
		h.add_child(s)
		var val: Label = _label(_fmt_value(float(p["value"]), step), _col["text"], FS, 56, HORIZONTAL_ALIGNMENT_RIGHT)
		h.add_child(val)
		box.add_child(h)
		if not bool(p["ok"]):
			box.add_child(_label(str(p["error"]), _col["failed"], FS_SMALL))
		s.value_changed.connect(func(v: float) -> void:
			val.text = _fmt_value(v, step)
			var e: String = JobModel.write_param(str(j["pack_dir"]), p, v)
			p["value"] = v
			_tune_note = ("Not written: " + e) if not e.is_empty() else "Written to %s." % str(p.get("file", ""))
			var note: Label = box.find_child("TuneNote", true, false) as Label
			if note != null:
				note.text = _tune_line(j)
				note.add_theme_color_override("font_color", _col["failed"] if not e.is_empty() else _col["dim"]))
	box.add_child(_spacer(2))
	var note: Label = _label(_tune_line(j), _col["dim"], FS_SMALL)
	note.name = "TuneNote"
	box.add_child(note)
	var where: Label = _label("Pack: %s" % str(j["pack_dir"]).trim_prefix(str(j["dir"]) + "/"), Color(_col["dim"], 0.7), FS_SMALL)
	box.add_child(where)


func _tune_line(_j: Dictionary) -> String:
	var base: String = "Read only here." if read_only else "A change takes effect at the next start of the game."
	return (_tune_note + " " + base) if not _tune_note.is_empty() else base


static func _fmt_value(v: float, step: float) -> String:
	if step >= 1.0 and step == floorf(step):
		return str(int(roundf(v)))
	if step >= 0.1:
		return "%.1f" % v
	return "%.2f" % v
