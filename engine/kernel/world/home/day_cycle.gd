extends Node
## Lane DN (day of 27 Nov 2026): day and night in the Home. The clock is a frame of the day (DAY_FRAMES = 86,400: a day
## of 24 minutes at 60 Hz), counted in physics frames; the look at each frame is the style's (style_day.gd day_look: dawn,
## day, dusk, night; the style's own values at noon), written onto the installed rig while the Home is visited in a
## window. The kit's lamps (home/day_lamps.gd, fed by build/piece_draw.gd) burn by the look's "lamps" strength: off by
## day, on one by one at dusk, the CAP nearest the camera live.
##   Keys, in build mode (BUILD.md "Keys"): N  the next of dawn, noon, dusk, night (the clock jumps there)
##                                          H  hold the clock / let it run again
##   Settings: `settings.json` (schema tl.home-settings/1) in the folder the Home's build is saved in (user://home, or
##   TL_HOME_BUILD_DIR), never in build.json: {"schema": "tl.home-settings/1", "day": {"frame": 0..86399, "cycle":
##   "run"|"hold"}}. Unknown keys are errors; a file that cannot be read is never written over. Saved on N and H, every
##   SAVE_EVERY frames while the clock runs, and when the Home goes.
## The cycle is OFF until a folder is opened (`open`: build mode opened one, so a person walks the Home; or a case):
## then no value is written, the clock stands at noon and the lamps are out, so a scripted or headless run draws the
## style's own look. Headless (TLStyle.headless) the clock, the keys, the settings and the lamps' choice all run and
## nothing is drawn or written. While a game is on stage the clock holds and the look eases to noon over EASE frames
## (games keep the look they were made in); dungeons are another scene with their own look. When the Home goes, the
## style's own values are written back (TLStyle.load_style of the same file).

const Day := preload("res://style/day/style_day.gd")
const DAY_FRAMES := 86400
const PHASES := [["night", 0], ["dawn", 21600], ["noon", 43200], ["dusk", 64800]]
const SCHEMA := "tl.home-settings/1"
const FILE := "settings.json"
const SAVE_EVERY := 3600
const LOOK_EVERY := 2                   # physics frames between writes of the look while the clock runs
const EASE := 60

var land: Node3D = null                 # the landscape the Home hangs under
var frame_of_day := 43200
var running := true
var on := false                         # a folder was opened: the cycle draws
var dir := ""
var blocked := ""                       # why nothing is saved (the settings there could not be read)
var frames := 0
var cam: Camera3D = null                # set by a case; else the viewport's camera
var stage_at: Callable                  # () -> int, set by a case; else the view's `stage` (-1: no game on stage)
var lamps: RefCounted = null            # home/day_lamps.gd (the pieces layer's draw)
var stage_w := 0.0                      # 0..1: how far the look has eased to noon for a game on stage
var writes := 0                         # looks written (style_day.gd apply_day calls that wrote something)
var last_look := {}
var label: Label = null
var _down := {}
var _data_seen: Dictionary = {}
var _style_path := ""
var _dirty := true
var _view: Node = null


static func mount(parent: Node3D) -> Node:
	var n: Node = (load("res://kernel/world/home/day_cycle.gd") as GDScript).new()
	n.name = "HomeDay"
	n.set("land", parent)
	parent.add_child(n)
	parent.set_meta(&"tl_home_day", n)
	return n


func _ready() -> void:
	process_physics_priority = 150001          # after build mode (150000)
	_view = land.get_parent() if land != null else null
	_style_path = TLStyle.style_path
	tree_exiting.connect(_on_exit)
	if not TLStyle.headless():
		var cl := CanvasLayer.new()
		cl.layer = 3
		add_child(cl)
		label = Label.new()
		label.anchor_left = 1.0
		label.anchor_right = 1.0
		label.offset_left = -360.0
		label.offset_right = -16.0
		label.offset_top = 12.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_font_size_override(&"font_size", 18)
		label.add_theme_color_override(&"font_outline_color", Color(0.1, 0.07, 0.12))
		label.add_theme_constant_override(&"outline_size", 6)
		label.visible = false
		cl.add_child(label)


# ------------------------------------------------------------------ the settings
## Reads the settings in `d` (none there: noon, running) and saves there from now on; the cycle is on. Returns "" or
## what is wrong with the file (it is then not written over).
func open(d: String) -> String:
	dir = d
	on = true
	_dirty = true
	var why := ""
	var path := d.path_join(FILE)
	if FileAccess.file_exists(path):
		why = read_settings(FileAccess.get_file_as_string(path))
	blocked = "" if why == "" else "the Home's settings could not be read (%s): they are not saved until the file is moved away" % why
	print(JSON.stringify({"schema": "tl.view/1", "kind": "home_day_load", "dir": d, "ok": why == "", "reason": why,
		"frame": frame_of_day, "cycle": "run" if running else "hold"}, "", false))
	if why != "":
		push_error("[day] " + blocked)
	return why


## Applies a settings text; "" or why it is refused (then nothing is changed).
func read_settings(text: String) -> String:
	var doc: Variant = JSON.parse_string(text)
	var why := settings_error(doc)
	if why != "":
		return why
	frame_of_day = int(doc.day.frame)
	running = str(doc.day.cycle) == "run"
	return ""


static func settings_error(doc: Variant) -> String:
	if not (doc is Dictionary):
		return "not a JSON object"
	for k: String in doc:
		if k != "schema" and k != "day":
			return "unknown key '%s'" % k
	if str(doc.get("schema", "")) != SCHEMA:
		return "schema is not %s" % SCHEMA
	if not (doc.get("day") is Dictionary):
		return "day is missing"
	for k: String in doc.day:
		if k != "frame" and k != "cycle":
			return "unknown key 'day.%s'" % k
	var f: Variant = doc.day.get("frame")
	if not (f is float or f is int) or float(f) != floorf(float(f)) or float(f) < 0.0 or float(f) >= DAY_FRAMES:
		return "day.frame must be a whole number 0..%d" % (DAY_FRAMES - 1)
	if not ["run", "hold"].has(str(doc.day.get("cycle", ""))):
		return "day.cycle must be \"run\" or \"hold\""
	return ""


func settings() -> Dictionary:
	return {"schema": SCHEMA, "day": {"frame": frame_of_day, "cycle": "run" if running else "hold"}}


## Writes the settings now. "" or what went wrong.
func save(why: String) -> String:
	if dir.is_empty():
		return ""
	if not blocked.is_empty():
		return blocked
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir) if dir.begins_with("user://") else dir)
	var f := FileAccess.open(dir.path_join(FILE), FileAccess.WRITE)
	if f == null:
		push_error("[day] the Home's settings were not saved: error %d" % FileAccess.get_open_error())
		return "error %d" % FileAccess.get_open_error()
	f.store_string(JSON.stringify(settings(), " ", false) + "\n")
	f.close()
	print(JSON.stringify({"schema": "tl.view/1", "kind": "home_day_save", "why": why, "frame": frame_of_day,
		"cycle": "run" if running else "hold"}, "", false))
	return ""


# ------------------------------------------------------------------ the clock
## The clock as a fraction of a day (0 midnight, 0.5 noon).
func t() -> float:
	return float(frame_of_day) / DAY_FRAMES


## "HH:MM" of the clock.
func clock() -> String:
	var m := frame_of_day * 1440 / DAY_FRAMES
	return "%02d:%02d" % [m / 60, m % 60]


## What the clock shows, by the look's own timeline: night (19:12-04:48), dawn (to 07:30), day (to 16:30), dusk.
func phase_name() -> String:
	var x := t()
	if x < 0.2 or x >= 0.8:
		return "night"
	if x < 0.3125:
		return "dawn"
	if x < 0.6875:
		return "day"
	return "dusk"


## N: the clock jumps to the next of dawn, noon, dusk, night.
func step_phase() -> void:
	var to: int = PHASES[0][1]
	for p: Array in PHASES:
		if int(p[1]) > frame_of_day:
			to = p[1]
			break
	frame_of_day = to
	_dirty = true
	save("key")


## H: hold the clock, or let it run again.
func toggle_hold() -> void:
	running = not running
	save("key")


func _physics_process(_delta: float) -> void:
	frames += 1
	var bm: Node = land.get_meta(&"tl_build_mode") if land != null and land.has_meta(&"tl_build_mode") else null
	if not on and bm != null and str(bm.get("dir")) != "":
		open(str(bm.get("dir")))
	if lamps == null:
		_find_lamps()
	var staged := _stage() >= 0
	if on and running and not staged:
		frame_of_day = (frame_of_day + 1) % DAY_FRAMES
		if frames % SAVE_EVERY == 0:
			save("every")
	_poll(bm)
	var target := 1.0 if staged else 0.0
	if stage_w != target:
		stage_w = move_toward(stage_w, target, 1.0 / EASE)
		_dirty = true
	_draw()
	if label != null:
		label.visible = on and bm != null and bool(bm.get("active"))
		if label.visible:
			label.text = "%s  %s%s    N next  ·  H %s" % [clock(), phase_name(), "" if running else " (held)", "run" if not running else "hold"]


func _poll(bm: Node) -> void:
	var active: bool = bm != null and bool(bm.get("active"))
	var taken: bool = active and bool((bm.call("tool") as RefCounted).call("blocks_input"))
	var vp := get_viewport()
	var f: Control = vp.gui_get_focus_owner() if vp != null else null
	var typing := f is LineEdit or f is TextEdit
	for k: int in [KEY_N, KEY_H]:
		var down := Input.is_physical_key_pressed(k) and active and not taken and not typing and on
		var was: bool = _down.get(k, false)
		_down[k] = down
		if down and not was and not Input.is_physical_key_pressed(KEY_CTRL):
			if k == KEY_N:
				step_phase()
			else:
				toggle_hold()


## The look now, written when the cycle is on and the window draws (every LOOK_EVERY frames while it moves, at once
## after a key, a stage change or another style load); the lamps every frame.
func _draw() -> void:
	if not on:
		return
	var moving := running and _stage() < 0
	var restyled := not is_same(TLStyle.data, _data_seen)
	if _dirty or restyled or (moving and frames % LOOK_EVERY == 0) or last_look.is_empty():
		_dirty = false
		_data_seen = TLStyle.data
		var lk: Dictionary = Day.day_look(t())
		if stage_w > 0.0:
			lk = Day.mix(lk, Day.day_look(0.5), stage_w)
		last_look = lk
		if Day.has_day() and TLStyle.style_path == _style_path and Day.apply_day(land, lk) > 0:
			writes += 1
	if lamps != null:
		var c := _cam()
		# a style with no day section (classic) has no night: its lamps burn as they did before the clock (always)
		var g: float = float(last_look.get("lamps", 0.0)) if Day.has_day() else 1.0
		lamps.call("update", g, c.global_position if c != null else Vector3.ZERO)


func _find_lamps() -> void:
	var b: Variant = land.get_meta(&"tl_build") if land != null and land.has_meta(&"tl_build") else null
	var layer: Variant = (b as RefCounted).call("layer", "pieces") if b is RefCounted else null
	if layer is RefCounted:
		lamps = (layer as RefCounted).get("draw").get("lamps") if (layer as RefCounted).get("draw") != null else null


func _cam() -> Camera3D:
	if cam != null:
		return cam
	var vp := get_viewport()
	return vp.get_camera_3d() if vp != null else null


func _stage() -> int:
	if stage_at.is_valid():
		return int(stage_at.call())
	var s: Variant = _view.get("stage") if _view != null else null
	return int(s) if s != null else -1


func _on_exit() -> void:
	save("quit")
	if writes > 0 and not TLStyle.headless() and TLStyle.style_path == _style_path:
		TLStyle.load_style(_style_path)          # the style's own values back for whatever is drawn next (the menu)
