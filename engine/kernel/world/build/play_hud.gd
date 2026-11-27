extends CanvasLayer
## Lane P (M6 rules and runs, 27 Nov 2026): what a person sees of the Home's rules while he plays them. In the crisp 2D
## look of the menu and the dungeon results card (kernel/dungeon/look_ui.gd: paper cards, a thick ink border, ink
## text), laid out for 1080p and scaled to the window:
##   the run pill    top centre while a run goes: the run's name and its clock (mm:ss.cc from the run's frames)
##   the counters    under it: each counter a rule uses, an icon and its count (a coin token for a name with "coin")
##   the say line    lower third: a rule's `say`, for its frames (a later line replaces it), faded in and out
##   the finish card centre: "Finished" or "New best!", the run's name, its time, the best; it stays CARD_FRAMES
##                   and slides away (a new run or build mode takes it at once); it takes no key: he keeps walking
##   the dip         a teleport or a respawn: the screen dips to ink and back over DIP_FRAMES
##   the E prompt    lane F3 (27 Nov): while his feet are in a zone a rule fires on E, a key cap "E" and what it does
##                   ("open Door 1"), right of his figure just under the screen's centre; it comes in over FADE frames
## Time is physics frames: `tick(frame, state)` is called once per frame by rules_play.gd; nothing reads a clock.
## `lines` holds what is shown, for a case to read.

const UI: GDScript = preload("res://kernel/dungeon/look_ui.gd")
const Faces: GDScript = preload("res://style/hud/faces.gd")
const DESIGN := Vector2(1920, 1080)
const CARD_FRAMES := 300                 # the finish card stays 5 s
const FADE := 12                         # frames a line or a card takes to come in or go
const DIP_FRAMES := 22

var lines := {"run": "", "clock": "", "counters": "", "say": "", "card": "", "prompt": ""}
var _prompt_box: PanelContainer = null
var _prompt: Label = null
var _prompt_from := -1
var _screen: Control = null
var _pill: PanelContainer = null
var _run: Label = null
var _clock: Label = null
var _counters: HBoxContainer = null
var _counter_labels := {}                # counter name -> Label
var _counter_tips := {}                  # counter name -> its word's Label ("coin" / "coins")
var _say_box: PanelContainer = null
var _say: Label = null
var _say_from := -1
var _say_until := -1
var _card: PanelContainer = null
var _card_head: Label = null
var _card_title: Label = null
var _card_time: Label = null
var _card_best: Label = null
var _card_from := -1
var _dip: ColorRect = null
var _dip_from := -1000
var _frame := 0
var _shown := true


func _init() -> void:
	name = "RulesHud"
	layer = 60


func _ready() -> void:
	var k: Dictionary = UI.colors()
	_screen = Control.new()
	_screen.name = "Screen"
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen)
	_dip = ColorRect.new()
	_dip.name = "Dip"
	_dip.color = Color(k["ink"], 0.0)
	_dip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(_dip)
	# the run pill and the counters, top centre
	var top := VBoxContainer.new()
	top.name = "Top"
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.add_theme_constant_override("separation", 10)
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(0, 28)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(top)
	_pill = PanelContainer.new()
	_pill.name = "Pill"
	_pill.add_theme_stylebox_override("panel", _box(k["paper"], k["ink"], 5, 22, 26, 8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pill.add_child(row)
	_run = UI.label("", 26)
	_run.name = "Run"
	_run.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_run)
	_clock = UI.label("00:00.00", 46)
	_clock.name = "Clock"
	_clock.add_theme_font_override("font", _digits())
	row.add_child(_clock)
	top.add_child(_center(_pill))
	_counters = HBoxContainer.new()
	_counters.name = "Counters"
	_counters.alignment = BoxContainer.ALIGNMENT_CENTER
	_counters.add_theme_constant_override("separation", 14)
	top.add_child(_counters)
	# the say line, lower third
	_say_box = PanelContainer.new()
	_say_box.name = "Say"
	_say_box.add_theme_stylebox_override("panel", _box(Color(k["ink"], 0.82), k["paper"], 3, 16, 30, 12))
	_say = UI.label("", 34, false)
	_say.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_say_box.add_child(_say)
	var low := CenterContainer.new()
	low.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	low.offset_top = DESIGN.y * 0.68
	low.mouse_filter = Control.MOUSE_FILTER_IGNORE
	low.add_child(_say_box)
	_screen.add_child(low)
	# the E prompt, under the centre (where his figure stands on the screen)
	_prompt_box = PanelContainer.new()
	_prompt_box.name = "Prompt"
	_prompt_box.add_theme_stylebox_override("panel", _box(k["paper"], k["ink"], 4, 14, 14, 8))
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 14)
	_prompt_box.add_child(prow)
	var cap := PanelContainer.new()
	cap.custom_minimum_size = Vector2(46, 46)
	cap.add_theme_stylebox_override("panel", _box(k["accent"], k["ink"], 4, 9, 0, 0))
	var ek: Label = UI.label("E", 30)
	ek.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ek.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ek.add_theme_font_override("font", _digits())
	cap.add_child(ek)
	prow.add_child(cap)
	_prompt = UI.label("", 30)
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prow.add_child(_prompt)
	var pc := CenterContainer.new()
	pc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pc.offset_top = DESIGN.y * 0.50
	pc.offset_bottom = -DESIGN.y * 0.30
	pc.offset_left = DESIGN.x * 0.24                   # right of his figure, so the door he faces stays in sight
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(_prompt_box)
	_screen.add_child(pc)
	_prompt_box.visible = false
	# the finish card, centre (the results card's look: UI.card, a head line, the title, the counts)
	_card = UI.card()
	_card.name = "FinishCard"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size = Vector2(620, 0)
	_card.add_child(v)
	_card_head = UI.label("", 28)
	_card_title = UI.label("", 52)
	_card_time = UI.label("", 64)
	_card_time.add_theme_font_override("font", _digits())
	_card_best = UI.label("", 28)
	for l: Label in [_card_head, _card_title, _card_time, _card_best]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	var mid := CenterContainer.new()
	mid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mid.offset_bottom = -DESIGN.y * 0.34
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(_card)
	_screen.add_child(mid)
	_fit()
	get_viewport().size_changed.connect(_fit)
	_pill.visible = false
	_say_box.visible = false
	_card.visible = false


static func _center(c: Control) -> Control:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(c)
	return cc


static func _box(fill: Color, border: Color, width: int, radius: int, mx: int, my: int) -> StyleBoxFlat:
	var s: StyleBoxFlat = UI.box(fill, border, width, radius)
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	return s


## The HUD's numbers: Roboto Black with tabular figures, so the clock does not shiver as its digits change.
static func _digits() -> Font:
	var f := FontVariation.new()
	f.base_font = Faces.base("black")
	f.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("tnum"): 1}
	return f


func _fit() -> void:
	if _screen == null or not _screen.is_inside_tree():
		return
	var vp: Vector2 = _screen.get_viewport().get_visible_rect().size
	var k: float = minf(1.0, minf(vp.x / DESIGN.x, vp.y / DESIGN.y))
	_screen.scale = Vector2(k, k)
	_screen.size = vp / k


## A run's frames as mm:ss.cc (hundredths, rounded down: 60 frames a second).
static func clock(frames: int) -> String:
	var f := maxi(frames, 0)
	var cs := f * 100 / 60
	return "%02d:%02d.%02d" % [cs / 6000, (cs / 100) % 60, cs % 100]


# ------------------------------------------------------------------ calls (rules_play.gd, play_facade.gd)
## Once per physics frame while the rules run: the pill and the counters from rules_run.gd `state()`; `used` the
## counters the rules use (rules_layer.gd `counters()`).
func tick(at_frame: int, st: Dictionary, used: Array) -> void:
	_frame = at_frame
	var running := bool(st.get("running", false))
	if _pill != null:
		_pill.visible = running and _shown
		if running:
			_run.text = str(st.get("run", ""))
			_clock.text = clock(int(st.get("frames", 0)))
	lines.run = str(st.get("run", "")) if running else ""
	lines.clock = clock(int(st.get("frames", 0))) if running else ""
	_tick_counters(st.get("counters", {}), used, running)
	_tick_say()
	_tick_card()
	_tick_dip()


func _tick_counters(values: Dictionary, used: Array, running: bool) -> void:
	# Lane F3 (27 Nov, the playtest's "0 coins" on a course with none and "1 coins"): a counter shows once it is above
	# 0 (the first coin taken makes the chip), its word singular at 1 ("1 coin", "2 coins").
	var parts := PackedStringArray()
	for c: String in used:
		if int(values.get(c, 0)) > 0:
			parts.append(count_text(c, int(values.get(c, 0))))
	lines.counters = " ".join(parts) if running or not values.is_empty() else ""
	if _counters == null:
		return
	if _counter_labels.keys() != used:
		for ch: Node in _counters.get_children():
			ch.queue_free()
		_counter_labels.clear()
		_counter_tips.clear()
		for c: String in used:
			_counter_labels[c] = _counter_chip(c)
	_counters.visible = _shown and not used.is_empty() and _any(values)
	for c: String in used:
		var n := int(values.get(c, 0))
		var lab: Label = _counter_labels[c]
		lab.text = str(n)
		var chip: Node = lab.get_parent().get_parent()
		if chip is Control:
			(chip as Control).visible = n > 0
		if _counter_tips.has(c):
			(_counter_tips[c] as Label).text = word_of(c, n)


## "1 coin", "3 coins", "1 hop" (a counter's name, the trailing s dropped at 1; "_" read as a space).
static func count_text(c: String, n: int) -> String:
	return "%d %s" % [n, word_of(c, n)]


static func word_of(c: String, n: int) -> String:
	var w := c.replace("_", " ")
	if n == 1 and w.length() > 1 and w.ends_with("s") and not w.ends_with("ss"):
		w = w.substr(0, w.length() - 1)
	return w


static func _any(values: Dictionary) -> bool:
	for k: String in values:
		if int(values[k]) != 0:
			return true
	return false


## A counter chip: a round gold token (a name with "coin") or the name's first letter in a tile, then the count.
func _counter_chip(c: String) -> Label:
	var k: Dictionary = UI.colors()
	var chip := PanelContainer.new()
	chip.name = "Counter_" + c
	chip.add_theme_stylebox_override("panel", _box(k["paper"], k["ink"], 4, 18, 14, 4))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	chip.add_child(row)
	var icon := PanelContainer.new()
	icon.custom_minimum_size = Vector2(36, 36)
	var round := c.contains("coin")
	icon.add_theme_stylebox_override("panel", _box(k["accent"] if round else k["muted"], k["ink"], 4, 18 if round else 8, 0, 0))
	if not round:
		var m: Label = UI.label(c.substr(0, 1).to_upper(), 22, false)
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.add_child(m)
	row.add_child(icon)
	var n: Label = UI.label("0", 32)
	n.add_theme_font_override("font", _digits())
	row.add_child(n)
	var tip: Label = UI.label(word_of(c, 0), 18)
	_counter_tips[c] = tip
	tip.add_theme_color_override("font_color", k["muted"])
	tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(tip)
	_counters.add_child(chip)
	return n


func say(text: String, frames: int) -> void:
	lines.say = text
	_say_from = _frame
	_say_until = _frame + frames
	if _say != null:
		_say.text = text


func _tick_say() -> void:
	if _say_box == null:
		return
	var on := _say_until > _frame and _shown
	if _say_until >= 0 and _say_until <= _frame:
		lines.say = ""
		_say_until = -1
	_say_box.visible = on
	if on:
		var a := minf(1.0, minf(float(_frame - _say_from + 1) / 6.0, float(_say_until - _frame) / float(FADE)))
		_say_box.modulate.a = clampf(a, 0.0, 1.0)


func finished(run_name: String, frames: int, best_frames: int, new_best: bool) -> void:
	var head := "New best!" if new_best else "Finished"
	var best := "best %s" % clock(best_frames)
	if new_best and _was_best > 0 and _was_best != best_frames:
		best = "best was %s" % clock(_was_best)
	lines.card = "%s | %s | %s | %s" % [head, run_name, clock(frames), best]
	_card_from = _frame
	_say_until = mini(_say_until, _frame + FADE)          # the card is the news now: a line still up fades out
	if _card != null:
		_card_head.text = head
		_card_title.text = run_name
		_card_time.text = clock(frames)
		_card_best.text = best
		var k: Dictionary = UI.colors()
		_card_head.add_theme_color_override("font_color", k["accent_dark"] if new_best else k["ink"])


func _tick_card() -> void:
	if _card == null:
		return
	var age := _frame - _card_from
	var on := _card_from >= 0 and age < CARD_FRAMES and _shown
	_card.visible = on
	if _card_from >= 0 and age >= CARD_FRAMES:
		_card_from = -1
		lines.card = ""
	if on:
		var t_in := clampf(float(age) / float(FADE), 0.0, 1.0)
		var t_out := clampf(float(CARD_FRAMES - age) / float(FADE), 0.0, 1.0)
		var t := minf(t_in, t_out)
		_card.modulate.a = t
		var s := 0.85 + 0.15 * (1.0 - pow(1.0 - t_in, 3.0)) + 0.06 * sin(t_in * PI)
		_card.pivot_offset = _card.size * 0.5
		_card.scale = Vector2(s, s)


var _was_best := 0                       # the run's best when it started (0: none), for "best was" on a new best


## A run started: the card of the last finish goes; the pill's clock is the run's own (tick). `was_best`: the run's
## best before this play (home_records.gd), 0 when it has none.
func started(_run_name: String, was_best := 0) -> void:
	_was_best = was_best
	_card_from = -1
	lines.card = ""


## Build mode came on, a game took the stage, the visit ended: the pill, the line and the card go.
func stopped() -> void:
	_card_from = -1
	_say_until = -1
	lines.card = ""
	lines.say = ""
	lines.run = ""
	lines.clock = ""
	set_prompt("")


## The E prompt's words ("" hides it): rules_play.gd sets it every frame the rules run.
func set_prompt(text: String) -> void:
	if text != lines.prompt:
		_prompt_from = _frame if text != "" else -1
		lines.prompt = text
		if _prompt != null:
			_prompt.text = text
	if _prompt_box == null:
		return
	var on := text != "" and _shown
	_prompt_box.visible = on
	if on:
		_prompt_box.modulate.a = clampf(float(_frame - _prompt_from + 1) / float(FADE), 0.0, 1.0)


func dip() -> void:
	_dip_from = _frame


func _tick_dip() -> void:
	if _dip == null:
		return
	var age := _frame - _dip_from
	var a := 0.0
	if age >= 0 and age < DIP_FRAMES:
		a = 1.0 - float(age) / float(DIP_FRAMES)
		a = a * a
	_dip.color.a = a * 0.92


func show_hud(on: bool) -> void:
	_shown = on
	if not on and _screen != null:
		_pill.visible = false
		_counters.visible = false
		_say_box.visible = false
		_card.visible = false
		_prompt_box.visible = false
		_dip.color.a = 0.0
