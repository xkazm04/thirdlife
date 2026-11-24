extends Control
## L3 (night of 21 Nov 2026): the Create page, part 1 of 4: its inks, its state and its building blocks (cel keycaps,
## labels, the CRAZY sticker, callouts). The page is split by inheritance to stay under the size ratchet:
## create_kit.gd <- create_design.gd (idea, designing, pitch) <- create_build.gd (building, phase done, done) <- create.gd
## (setup, the job, polling). See create.gd for what the page is.

const Model = preload("res://ui/create/create_model.gd")
const JobModel = preload("res://ui/job_model.gd")
const Door = preload("res://ui/foreman_door.gd")
const Icon = preload("res://ui/create/icon.gd")
const Stock = preload("res://style/hud/stock.gd")

const W: float = 1280.0
const H: float = 720.0

# The page's inks: the night of the menu, the house's cream paper and honey, one colour per state.
const INK := Color("#1b1d32")
const NIGHT := Color("#272b57")
const NIGHT_DEEP := Color("#1c1f43")
const NIGHT_LINE := Color("#3a3f78")
const PAPER := Color("#fdf6e6")
const CREAM := Color("#f3e6c8")
const MUTED := Color("#c7c9ea")
const HONEY := Color("#f6c445")
const HONEY_LIGHT := Color("#ffe7a3")
const CRAZY := Color("#ff4f9a")
const GREEN := Color("#6fd06a")
const BLUE := Color("#62b0ff")
const ORANGE := Color("#ff9b3d")
const RED := Color("#ef5a45")
const GREY := Color("#8d90b8")
const STATE_COLOR: Dictionary = {"passed": GREEN, "building": BLUE, "done": HONEY, "held": ORANGE, "next": GREY,
	"promoted": GREEN, "running": BLUE, "verifying": BLUE, "queued": GREY, "blocked": ORANGE, "failed": RED}

var door: Door = null
var jobs_root: String = ""
var opts: Dictionary = {}
var job_dir: String = ""
var job: Dictionary = {}
var screen: String = "idea"
var sentence: String = ""
var creativity: String = "standard"
var run_through: bool = false
var card_hint: String = ""               # a recipe card id, or "" (the Designer picks)
var drawer_open: bool = false
var taps: Dictionary = {}                 # aspect id -> {choice, note?}: the player's taps not in the log yet
var expanded: String = ""                 # the aspect whose sheet is open
var holding: bool = false                 # the hold note box is open
var surprise_i: int = 0
var waiting_for: String = ""              # the sentence of a `new` this page started, until its job directory appears
var started_at: float = 0.0
var settling: bool = false                # the job waits on a phase but its Foreman still runs (see create.gd)
var busy: String = ""                     # what this page started and waits to see in the log: new, redesign, approve, phase
var busy_mark: int = 0                    # the figure that moves when it arrived (briefs, phase events)
var message: String = ""
var last_launch: PackedStringArray = []
var cards: Dictionary = {}                # recipe card id -> title (the expert's hint)
var showing_games: bool = false           # E4: My games is open (the page's own screen, not one of the log's)
var games_rows: Array = []                # E4: create_model.gd games(), read when My games opens
var menu_list: String = ""                # E4: the person's dungeon list ("" = kernel/dungeon/dungeons.gd user_path())
var _change_box: LineEdit = null
var _change_draft: String = ""            # E4: what is typed in the change box (kept over a rebuild)
var _sent_change: String = ""             # E4: the change this page sent, shown until the log holds it

var _stage: Control = null
var _body: Control = null
var _poll_left: float = 0.0
var _sig: String = ""
var _clock: Label = null
var _alive: Array = []                    # icons that bob while something works
var _pulse: Array = []                    # controls whose border pulses (the phase being built)
var _t: float = 0.0
var _sentence_box: LineEdit = null
var _note_box: LineEdit = null


func _fit() -> void:
	if _stage == null:
		return
	var s: float = minf(size.x / W, size.y / H) if size.x > 0.0 and size.y > 0.0 else 1.0
	_stage.scale = Vector2(s, s)
	_stage.position = ((size - Vector2(W, H) * s) * 0.5).floor()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), NIGHT)
	# a wide diagonal band and a dot grid: the menu's night, not a flat fill
	var s: float = _stage.scale.x if _stage != null else 1.0
	var o: Vector2 = _stage.position if _stage != null else Vector2.ZERO
	var band: PackedVector2Array = [o + Vector2(0, 470) * s, o + Vector2(W, 250) * s, o + Vector2(W, 720) * s, o + Vector2(0, 720) * s]
	draw_colored_polygon(band, NIGHT_DEEP)
	var step: float = 40.0 * s
	var y: float = fmod(o.y, step)
	while y < size.y:
		var x: float = fmod(o.x, step)
		while x < size.x:
			draw_circle(Vector2(x, y), 1.6 * s, NIGHT_LINE)
			x += step
		y += step


func _now() -> float:
	return float(opts["now"]) if opts.has("now") else Time.get_unix_time_from_system()


func _elapsed() -> float:
	var t0: float = started_at
	if not job.is_empty() and float(job.get("first_ts", 0.0)) > 0.0:
		t0 = float(job["first_ts"])
	var mine: Array = Model.person_changes(job)
	if busy == "change":
		t0 = started_at                   # E4: a change round's clock starts at its request
	elif not mine.is_empty() and not Model.changing(job).is_empty():
		t0 = float((mine.back() as Dictionary).get("ts", t0))
	return maxf(0.0, _now() - t0) if t0 > 0.0 else 0.0


func _signature() -> String:
	return "|".join([screen, str(job.get("last_seq", -1)), JSON.stringify(taps), expanded, str(holding), busy, message, str(drawer_open),
		creativity, str(run_through), card_hint, waiting_for, str(job.get("torn", false)), str(settling), str(showing_games)])


# ---------------------------------------------------------------- building blocks

func _font(weight: int, width: int = 100) -> Font:
	return Stock.font(weight, width)


func _label(text: String, px: int, weight: int, color: Color, width: float = 0.0, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", _font(weight, 100))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = width
		l.size.x = width
	return l


func _box(fill: Color, border: Color, bw: int, radius: int, bottom: int = 0) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(bw)
	if bottom > 0:
		s.border_width_bottom = bottom
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	return s


## A cel keycap: fill, a thick ink rim, a deeper bottom rim; an icon at the left; big heavy type.
func _button(name_: String, text: String, icon: String, fill: Color, at: Vector2, sz: Vector2, px: int = 28, fg: Color = INK) -> Button:
	var b: Button = Button.new()
	b.name = name_
	b.text = text
	b.position = at
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", _font(850, 100))
	b.add_theme_font_size_override("font_size", px)
	for st: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.45))
	var normal: StyleBoxFlat = _box(fill, INK, 4, 16, 9)
	var hover: StyleBoxFlat = _box(fill.lightened(0.12), INK, 4, 16, 9)
	var pressed: StyleBoxFlat = _box(fill.darkened(0.08), INK, 4, 16, 4)
	var disabled: StyleBoxFlat = _box(fill.lerp(GREY, 0.6), Color(INK, 0.6), 4, 16, 9)
	for s: StyleBoxFlat in [normal, hover, pressed, disabled]:
		s.content_margin_left = 18.0 + (sz.y * 0.62 if not icon.is_empty() else 0.0)
		s.content_margin_right = 18.0
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if not icon.is_empty():
		var ip: float = sz.y * 0.56
		var ic: Icon = Icon.new(icon, ip)
		ic.bare = true
		ic.glyph_color = fg
		ic.position = Vector2(16.0, 4.0 + (sz.y - 13.0 - ip) * 0.5)
		ic.size = Vector2(ip, ip)
		b.add_child(ic)
	return b


func _icon(kind: String, px: float, at: Vector2, parent: Control) -> Icon:
	var ic: Icon = Icon.new(kind, px)
	ic.position = at
	ic.size = Vector2(px, px)
	parent.add_child(ic)
	return ic


## The CRAZY sticker: magenta, a bolt, tilted.
func _crazy_badge(at: Vector2, parent: Control, px: int = 18) -> Control:
	var holder: Control = Control.new()
	holder.name = "CrazyBadge"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = _box(CRAZY, INK, 3, 10)
	sb.content_margin_left = float(px) + 12.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 1.0
	sb.content_margin_bottom = 1.0
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(_label("CRAZY", px, 900, PAPER))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(p)
	var bolt: Icon = Icon.new("bolt", float(px) + 6.0)
	bolt.bare = true
	bolt.glyph_color = HONEY_LIGHT
	bolt.position = Vector2(5, 0)
	bolt.size = Vector2(px + 6, px + 6)
	holder.add_child(bolt)
	holder.size = p.get_combined_minimum_size()
	holder.position = at
	holder.rotation = deg_to_rad(-5.0)
	parent.add_child(holder)
	return holder


func _text_w(text: String, px: int, weight: int) -> float:
	return _font(weight).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x


func _place(c: Control, at: Vector2, parent: Control = null) -> Control:
	c.position = at
	(parent if parent != null else _body).add_child(c)
	return c


func _chip(name_: String, text: String, icon: String) -> Button:
	var w: float = 40.0 + _text_w(text, 22, 850) + (36.0 if not icon.is_empty() else 0.0)
	var b: Button = _button(name_, text, icon, NIGHT_DEEP.lightened(0.2), Vector2.ZERO, Vector2(w, 54), 22, PAPER)
	(b.get_theme_stylebox("normal") as StyleBoxFlat).border_color = MUTED
	_body.add_child(b)
	return b


func _switch(name_: String, text: String, icon: String, on: bool, color: Color, at: Vector2) -> Button:
	var b: Button = _button(name_, text, icon, color if on else NIGHT_DEEP.lightened(0.12), at, Vector2(260, 76), 32, INK if on else MUTED)
	if not on:
		for st: String in ["normal", "hover"]:
			(b.get_theme_stylebox(st) as StyleBoxFlat).border_color = GREY
	_body.add_child(b)
	return b


func _callout(text: String, at: Vector2, icon: String, col: Color = HONEY) -> Control:
	var p: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = _box(NIGHT_DEEP, col, 3, 14)
	sb.content_margin_left = 64.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(_label(text, 26, 750, PAPER))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(p, at)
	var ic: Icon = Icon.new(icon, 38)
	ic.disc = col
	ic.position = at + Vector2(14, 8)
	ic.size = Vector2(38, 38)
	_body.add_child(ic)
	return p


## The page draws itself again (create.gd).
func _rebuild() -> void:
	pass
