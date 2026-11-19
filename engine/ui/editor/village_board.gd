extends Control
## E5 (night of 19 Nov, round 3): the editor's home. The village from above with every game on its lot, named and
## told in the construction site's own words (being designed, waits for you, building 1 of 2, ready to play, could not
## be finished), beside a list of the same games. A click on a game's lot or its row opens the game sheet; "New game"
## opens the workbench; "Jobs list" shows the designer panel (it stays the way to every job, also those made in one
## line, which have no lot). Reads what the panel already reads (panel.jobs, refreshed once a second) and the drafts
## the workbench wrote; draws with the workbench's map (village_map.gd, board mode); starts nothing itself.

const Model = preload("res://ui/editor/editor_model.gd")
const VillageMap = preload("res://ui/editor/village_map.gd")
const Look = preload("res://ui/editor/look.gd")
const GameSheet = preload("res://ui/editor/game_sheet.gd")

signal new_game
signal open_game(id: String)
signal jobs_list

const M: int = 16
const STAMPS: Dictionary = {"card.team_possession": "hockey", "card.knock_down": "wall", "card.timed_drive": "drive",
	"card.two_sides_ball": "paddle"}

var panel: Control                   # ui/panel.gd: its jobs and their shown phase
var jobs_root: String = ""
var model: Model
var col: Dictionary = {}
var font: Font
var bold: Font
var games: Array = []                # [{id, title, words, state, draft, lot: bool}], newest first
var _base_plots: Array = []
var _sig: String = ""
var _poll: float = 0.0
var _map: VillageMap
var _list: VBoxContainer
var _count: Label


func setup(the_panel: Control, root: String) -> void:
	panel = the_panel
	jobs_root = root


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	col = Look.colors()
	var face: Font = Look.typeface()
	font = Look.weight(face, 480)
	bold = Look.weight(face, 790, 96)
	theme = Look.theme(col, font)
	model = Model.new()
	model.load_all()
	_base_plots = model.plots.duplicate(true)
	_build()
	reload()


## In words a player knows, from the site's own state words: what the game is doing now.
static func words(job: Dictionary, shown: String) -> String:
	var done: int = int(job.get("done", 0))
	var total: int = int(job.get("total", 0))
	match shown:
		"designing": return "being designed"
		"approve": return "waits for you"
		"planning": return "being planned"
		"running": return "building %d of %d" % [done, total] if total > 0 else "building"
		"paused": return "waits for your answer" if str(job.get("pause_kind", "")) == "question" else "paused"
		"done": return "ready to play"
		"failed": return "could not be finished"
		"cancelled": return "discarded"
		"stalled": return "stopped"
	return shown


## The games the board shows, from the panel's jobs: those made in the workbench stand on their lot.
func collect() -> Array:
	var out: Array = []
	var jobs: Dictionary = panel.get("jobs") if panel != null else {}
	var order: PackedStringArray = panel.get("order") if panel != null else PackedStringArray()
	for id: String in order:
		var j: Dictionary = jobs[id]
		var shown: String = str(panel.call("shown_phase", id))
		var d: Dictionary = GameSheet.find_draft(jobs_root, str(j.get("sentence", "")))
		var title: String = str(j.get("title", ""))
		if title.is_empty():
			title = str(d.get("sentence", j.get("sentence", id)))
		out.append({"id": id, "title": title, "words": words(j, shown), "state": shown, "draft": d, "lot": not d.is_empty()})
	return out


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
	head.name = "HomeHead"
	head.add_theme_stylebox_override("panel", Look.sb(col["ink"], col["ink"], 3, 8, 14, 6))
	root.add_child(head)
	var hh: HBoxContainer = HBoxContainer.new()
	hh.add_theme_constant_override("separation", 10)
	head.add_child(hh)
	var t: Label = _label("Your village · the games", 20, true, col["paper"])
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(t)
	var jl: Button = _button("JobsListButton", "Jobs list", false)
	jl.pressed.connect(func() -> void: jobs_list.emit())
	hh.add_child(jl)
	var ng: Button = _button("NewGameButton", "+ New game", true)
	ng.pressed.connect(func() -> void: new_game.emit())
	hh.add_child(ng)
	var mid: HBoxContainer = HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 10)
	root.add_child(mid)
	var left: PanelContainer = PanelContainer.new()
	left.name = "GamesPlate"
	left.custom_minimum_size = Vector2(340, 0)
	mid.add_child(left)
	var lv: VBoxContainer = VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	left.add_child(lv)
	var lh: HBoxContainer = HBoxContainer.new()
	lh.add_child(_label("Your games", 20, true))
	_count = _label("", 12, false, col["dim"])
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lh.add_child(_count)
	lv.add_child(lh)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "GamesList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	var right: PanelContainer = PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(right)
	var rv: VBoxContainer = VBoxContainer.new()
	right.add_child(rv)
	var rh: HBoxContainer = HBoxContainer.new()
	rh.add_child(_label("The village", 20, true))
	var hint: Label = _label("click a game's lot to open it", 12, false, col["dim"])
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rh.add_child(hint)
	rv.add_child(rh)
	var frame: PanelContainer = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", Look.sb(col["ink"], col["ink"], 0, 6, 2, 2))
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(frame)
	_map = VillageMap.new()
	_map.name = "HomeMap"
	_map.model = model
	_map.col = col
	_map.font = font
	_map.bold = bold
	_map.read_only = true
	_map.board = true
	_map.lot_clicked.connect(func(id: String) -> void: open_game.emit(id))
	frame.add_child(_map)


func _label(text: String, fs: int = 14, b: bool = false, color: Color = Color(0, 0, 0, 0)) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if b:
		l.add_theme_font_override("font", bold)
	if fs != 14:
		l.add_theme_font_size_override("font_size", fs)
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	return l


func _button(name_: String, text: String, primary: bool) -> Button:
	var b: Button = Button.new()
	b.name = name_
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", bold)
	b.add_theme_font_size_override("font_size", 15)
	var bg: Color = col["honey"] if primary else col["paper"]
	b.add_theme_stylebox_override("normal", Look.sb(bg, col["ink"], 2, 8, 16, 5))
	b.add_theme_stylebox_override("hover", Look.sb(bg.lightened(0.1), col["ink"], 2, 8, 16, 5))
	b.add_theme_stylebox_override("pressed", Look.sb(col["honey_dark"], col["ink"], 2, 8, 16, 5))
	return b


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_poll -= delta
	if _poll <= 0.0:
		_poll = 1.0
		reload()


func reload() -> void:
	games = collect()
	var sig: String = str(games.map(func(g: Dictionary) -> String: return "%s:%s:%s" % [g["id"], g["words"], g["lot"]]))
	if sig == _sig:
		return
	_sig = sig
	# the map: the village's own plots, then one lot per workbench game, drawn like the village draws a plot
	var plots: Array = _base_plots.duplicate(true)
	for g: Dictionary in games:
		if not bool(g["lot"]):
			continue
		var lot: Dictionary = (g["draft"] as Dictionary).get("lot", {})
		var a: Array = lot.get("at", [0, 0])
		var built: bool = g["state"] == "done"
		plots.append({"id": "game:" + str(g["id"]), "job": str(g["id"]), "label": "%s · %s" % [_short(str(g["title"])), str(g["words"])],
			"pack": "", "at": Vector2(float(a[0]), float(a[1])), "r": float(lot.get("radius", 20)), "kind": "game",
			"stamp": STAMPS.get(str((g["draft"] as Dictionary).get("card", "")), "parkour") if built else "site"})
	model.plots = plots
	_map.queue_redraw()
	# the list
	for c: Node in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_count.text = "%d" % games.size()
	if games.is_empty():
		_list.add_child(_label("No games yet. \"+ New game\" opens the workbench: say what you want to play, answer a few questions, put it on a lot.", 13))
		(_list.get_child(0) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		(_list.get_child(0) as Label).clip_text = false
	for g: Dictionary in games:
		var b: Button = Button.new()
		b.name = "Game_" + str(g["id"])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_stylebox_override("normal", Look.sb(col["paper"], Color(col["ink"], 0.35), 1, 6, 8, 4))
		b.add_theme_stylebox_override("hover", Look.sb(Color(col["honey"], 0.25), col["ink"], 1, 6, 8, 4))
		b.add_theme_stylebox_override("pressed", Look.sb(Color(col["honey"], 0.4), col["ink"], 1, 6, 8, 4))
		var v: VBoxContainer = VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 10
		v.offset_right = -8
		v.offset_top = 4
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		b.add_child(v)
		v.add_child(_label(str(g["title"]), 13, true))
		var state_c: Color = col["hazard"] if g["state"] in ["failed", "stalled", "cancelled"] else (col["green"] if g["state"] == "done" else col["honey_dark"].darkened(0.3))
		v.add_child(_label(str(g["words"]) + ("" if bool(g["lot"]) else " · no lot (made in one line): opens in the jobs list"), 12, false, state_c))
		var id: String = str(g["id"])
		b.pressed.connect(func() -> void: open_game.emit(id))
		_list.add_child(b)


static func _short(t: String) -> String:
	return t if t.length() <= 28 else t.left(26).strip_edges() + "…"
