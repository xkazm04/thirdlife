extends CanvasLayer
## Lane K (spark world-sandbox M5, 27 Nov 2026): the results card a person sees after leaving a dungeon, before the menu.
## No class_name; boot/hub.gd loads it by path. In the menu's crisp look (look_ui.gd): the sky, one card.
##
## Its data is the dungeon's `result.trophies` (dungeon.gd `close`, from what kernel/world/build/trophies.gd `record`
## just wrote to `<home>/trophies.json`): {title, plays, wins, best?, won?, unlocked?}. `unlocked` lists what THIS end
## newly unlocked for building ("parts:light_mast", "mats:12": the rules of unlocks.json met after the record and not
## before), so a second identical end shows no "Unlocked" line. No `trophies` (a counted run, a test's dungeon, a load
## that was refused or stopped: nothing was recorded): no card (`wanted`).
## Closed by any key or a click, after HOLD frames (the key that left the dungeon never closes it); no clock, no timer.
##   var c = load("res://kernel/dungeon/results_card.gd").new(); parent.add_child(c); c.open(result); c.closed -> menu

signal closed

const UI: GDScript = preload("res://kernel/dungeon/look_ui.gd")
const Blocks: GDScript = preload("res://kernel/world/build/blocks.gd")
const DESIGN: Vector2 = Vector2(1920, 1080)       # as boot/menu.gd: laid out for 1080p, scaled down to the window
const HOLD: int = 12                              # drawn frames before a key or a click closes it
const KIND_ORDER: Array = ["parts", "stamps", "shapes", "mats"]

var lines: Dictionary = {}                        # what the card says (`text_of`), for a case to read
var _screen: Control = null
var _frames: int = 0
var _done: bool = false


func _init() -> void:
	name = "Results"
	layer = 95


## True when a dungeon's result has something to show (trophies were recorded for this end).
static func wanted(result: Dictionary) -> bool:
	return typeof(result.get("trophies")) == TYPE_DICTIONARY and not (result.trophies as Dictionary).is_empty()


## dungeon.gd `close`: the card's data from the entry `record` wrote, the locks before it and after it
## (unlocks.gd `locks()`: {"kind:id": condition}) and the pack's trophies before it (unlocks.gd `of`).
static func of_play(title: String, entry: Dictionary, before: Dictionary, after: Dictionary, was: Dictionary) -> Dictionary:
	var out := {"title": title, "plays": int(entry.get("plays", 0)), "wins": int(entry.get("wins", 0))}
	if entry.has("best"):
		out["best"] = int(entry.best)
	if int(entry.get("wins", 0)) > int(was.get("wins", 0)):
		out["won"] = true
	var fresh := []
	for kind: String in KIND_ORDER:
		for key: String in before:
			if key.begins_with(kind + ":") and not after.has(key):
				fresh.append(key)
	if not fresh.is_empty():
		out["unlocked"] = fresh
	return out


## A person's name for an unlocked key: "parts:light_mast" -> "light mast", "mats:12" -> "plaster".
static func name_of(key: String) -> String:
	var kind := key.get_slice(":", 0)
	var id := key.get_slice(":", 1)
	match kind:
		"mats":
			return str(Blocks.MAT_KEYS.get(int(id), id)).replace("_", " ")
		"shapes":
			return str(Blocks.SHAPE_NAMES.get(int(id), id)).replace("_", " ")
		"stamps":
			return "%s stamp" % id.replace("_", " ")
	return id.replace("_", " ")


## The card's lines: {title, head, counts, unlocked ("" when nothing new), keys}.
static func text_of(t: Dictionary) -> Dictionary:
	var counts := PackedStringArray(["played %d %s" % [int(t.plays), "time" if int(t.plays) == 1 else "times"],
		"won %d" % int(t.wins)])
	if t.has("best"):
		counts.append("best %d" % int(t.best))
	var names := PackedStringArray()
	for k: Variant in t.get("unlocked", []):
		names.append(name_of(str(k)))
	return {"title": str(t.get("title", "")), "head": "You won" if t.get("won", false) == true else "Results",
		"counts": "   ·   ".join(counts), "unlocked": ("Unlocked: " + ", ".join(names)) if not names.is_empty() else "",
		"keys": "any key or click: back to the menu"}


func open(result: Dictionary) -> void:
	lines = text_of(result.get("trophies", {}))
	var root := Control.new()
	root.name = "Screen"
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen = root
	add_child(root)
	_fit()
	root.get_viewport().size_changed.connect(_fit)
	root.add_child(UI.sky_backdrop())
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	var card: PanelContainer = UI.card()
	card.name = "Card"
	cc.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.custom_minimum_size = Vector2(820, 0)
	card.add_child(v)
	v.add_child(_named(UI.label(str(lines.head), 26), "Head"))
	v.add_child(_named(UI.label(str(lines.title), 52), "Title"))
	v.add_child(_named(UI.label(str(lines.counts), 30), "Counts"))
	if str(lines.unlocked) != "":
		var tile: PanelContainer = PanelContainer.new()
		tile.name = "Unlocked"
		var k: Dictionary = UI.colors()
		tile.add_theme_stylebox_override("panel", UI.box(Color(k["accent"], 0.3), k["ink"], 3, 12))   # not the button's fill
		var u: Label = UI.label(str(lines.unlocked), 30)
		u.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var hint: Label = UI.label("new in the Home's build tools", 20)
		var uv := VBoxContainer.new()
		uv.add_child(u)
		uv.add_child(hint)
		tile.add_child(uv)
		v.add_child(tile)
	var back: Button = UI.button("Back to the menu", 30)
	back.name = "Back"
	back.pressed.connect(close)
	v.add_child(back)
	v.add_child(_named(UI.label(str(lines.keys), 20), "Keys"))
	back.grab_focus.call_deferred()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print(JSON.stringify({"schema": "thirdlife.exe/1", "kind": "results_card", "title": lines.title, "counts": lines.counts,
		"unlocked": lines.unlocked}, "", false))


static func _named(c: Control, n: String) -> Control:
	c.name = n
	return c


func _fit() -> void:
	if _screen == null or not _screen.is_inside_tree():
		return
	var vp: Vector2 = _screen.get_viewport().get_visible_rect().size
	var k: float = minf(1.0, minf(vp.x / DESIGN.x, vp.y / DESIGN.y))
	_screen.scale = Vector2(k, k)
	_screen.size = vp / k


func _process(_d: float) -> void:
	_frames += 1


## Ends the card once: `closed` is emitted and the card frees itself.
func close() -> void:
	if _done:
		return
	_done = true
	print("[results] closed after %d frames" % _frames)
	closed.emit()
	queue_free()


## Every key and mouse button goes to the card while it is up (its button never takes one by itself, so the HOLD holds
## for Enter and Space as well); a press after HOLD frames closes it.
func _input(event: InputEvent) -> void:
	if _done or not (event is InputEventKey or event is InputEventMouseButton):
		return
	get_viewport().set_input_as_handled()
	var k := event as InputEventKey
	var m := event as InputEventMouseButton
	if _frames >= HOLD and ((k != null and k.pressed and not k.echo) or (m != null and m.pressed)):
		close()
