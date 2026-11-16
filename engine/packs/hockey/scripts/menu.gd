extends RefCounted
## H14: the panel before the first face-off of a match (and after R): the three levels and the five modes, the chosen ones
## marked; 1 2 3 choose the level, A / D (the actions left / right) the mode, Space or the left button starts.
## With no input for menu.auto_start_frames it starts by itself with the choice shown. Created by main.gd, no class_name;
## g = main. Only a person's session uses it (ctx.mode "play", on stage), or a test that presses the keyless action `menu`: every
## verify run (smoke, bots, the village's far games) starts at once as before.

const LEVELS: Array = ["rookie", "pro", "allstar"]
var enabled: bool = false
var open: bool = false
var idle: int = 0
var lv: int = 0
var md: int = 0
var _hud = null


func setup(g) -> void:
	enabled = str(g.ctx.mode) == "play"
	for a: Array in [[&"pick_1", KEY_1], [&"pick_2", KEY_2], [&"pick_3", KEY_3]]:
		g.ctx.input.declare(a[0], [a[1]])
	g.ctx.input.declare(&"menu", [])
	lv = maxi(0, LEVELS.find(g.level_id))
	md = maxi(0, (g.base_tune["modes"] as Array).find(g.mode_id))


## Called by main's _start_match: true when the panel takes the start (it calls g._begin() when he starts).
func hold(g) -> bool:
	if not enabled or not g.ctx.on_stage or g.drill_id != "":     # a world's game nobody is in starts as before
		return false
	open = true
	idle = 0
	_attach(g)
	return true


func _attach(g) -> void:
	if _hud == g.hud:
		return
	_hud = g.hud
	g.hud.add_bound(&"menu", func() -> String: return text(g), &"bottom_left")     # above the game line; grows upwards, clear of the keys' lines at the top
	g.hud.set_plate(&"menu", true)
	g.hud.set_align(&"menu", &"left")


## Every tick before play: true while the panel is open (main then holds everyone still and returns).
func tick(g) -> bool:
	var inp = g.ctx.input
	if not open and inp.just_pressed(&"menu"):
		enabled = true
		g._build(g.mode_id)
		hold(g)
		return true
	if not open:
		return false
	_attach(g)
	var modes: Array = g.base_tune["modes"]
	var moved: bool = false
	for i: int in LEVELS.size():
		if inp.just_pressed(StringName("pick_%d" % (i + 1))):
			lv = i
			moved = true
	if inp.just_pressed(&"left"):
		md = (md + modes.size() - 1) % modes.size()
		moved = true
	if inp.just_pressed(&"right"):
		md = (md + 1) % modes.size()
		moved = true
	idle = 0 if moved else idle + 1
	if inp.just_pressed(&"shoot") or idle >= int(g.base_tune["menu"]["auto_start_frames"]):
		open = false
		var want: String = str(LEVELS[lv])
		g.level_id = want if g.levels.has(want) else "none"
		if str(modes[md]) != g.mode_id:
			g._build(str(modes[md]))
		elif g.brain != null:
			g.brain.red_over = (g.levels[g.level_id]["ai"] as Dictionary).duplicate() if g.levels.has(g.level_id) else {}
		g._begin()
		return true     # the press that started is spent here: the left button is no cross-check on the first frame
	return true


func text(g) -> String:
	if not open:
		return ""
	var left: int = maxi(0, int(g.base_tune["menu"]["auto_start_frames"]) - idle)
	var lines: Array = ["CHOOSE YOUR GAME     Space or left button: start   (by itself in %d s)" % int(ceil(left / 60.0))]
	var row: Array = []
	for i: int in LEVELS.size():
		var lid: String = str(LEVELS[i])
		var name: String = "%d %s" % [i + 1, str(g.levels[lid]["label"]) if g.levels.has(lid) else lid]
		row.append("[ %s ]" % name if i == lv else name)
	lines.append("Level (1 2 3):   " + "    ".join(row))
	lines.append("Mode (A / D):")
	var modes: Array = g.base_tune["modes"]
	for i: int in modes.size():
		var m: Dictionary = g.modes.get(str(modes[i]), {})
		lines.append("%s %s" % ["  >" if i == md else "    ", str(m.get("label", modes[i]))])
	lines.append_array(_wrap(str((g.modes.get(str(modes[md]), {}) as Dictionary).get("about", "")), 72))
	return "\n".join(lines)


## The mode's one line from its data file, broken at spaces into lines of at most width characters.
func _wrap(t: String, width: int) -> Array:
	var out: Array = []
	var cur: String = ""
	for w: String in t.split(" ", false):
		if cur != "" and cur.length() + 1 + w.length() > width:
			out.append(cur)
			cur = w
		else:
			cur = w if cur == "" else cur + " " + w
	if cur != "":
		out.append(cur)
	return out
