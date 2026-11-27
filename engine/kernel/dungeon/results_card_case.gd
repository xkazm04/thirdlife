extends SceneTree
## Lane K (spark world-sandbox M5, 27 Nov 2026): the results card after a dungeon (selftest block 767), headless. The
## paddle seed is played as a person plays it (frames 0; the Home's trophies in a temporary TL_HOME_BUILD_DIR), left,
## and handed to boot/hub.gd `_on_dungeon_left` with a stand-in boot node. Prints `RESULTS <case> ok|fail <detail>`,
## then `RESULTS ok` (or fail) and `RESULTS DONE`. Frames, not wall clock.
##   win      paddle to 5: the hub shows the card, not the menu; it says "You won", "played 1 time · won 1 · best 5"
##            and "Unlocked: bench, light mast, brick" (unlocks.json first_play and paddle_five, met by this end only);
##            a key in the first HOLD frames does nothing, one after them closes it and the menu is shown
##   again    the same end again: plays 2, wins 2, no "Unlocked" line (nothing newly unlocked)
##   third    left at 0 the third time: "played 3 times · won 2 · best 5", "Results", "Unlocked: plaster" (lane F3, 27 Nov:
##            the street lamp is open from the start, unlocks.json)
##   none     a counted run (frames > 0, nothing recorded): no card, the menu at once; a click closes a card too

const Dungeon := preload("res://kernel/dungeon/dungeon.gd")
const Hub := preload("res://boot/hub.gd")
const Trophies := preload("res://kernel/world/build/trophies.gd")
const Card := preload("res://kernel/dungeon/results_card.gd")
const TMP := "user://tl_results_case"
const BOOT := """extends Node
var dungeon_only := false
var _ending := false
var verb := ""
var opts := {}
var games_dir := ""
var tag := ""
var _frame := 0
var world: Node = null
var menu_mode := true
"""

var ok_all := true
var boot: Node
var hub: RefCounted


func _initialize() -> void:
	call_deferred("run")


func say(name: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("RESULTS %s %s %s" % [name, "ok" if ok else "fail", detail])


func wait(n: int) -> void:
	for i in n:
		await process_frame


func run() -> void:
	var home := ProjectSettings.globalize_path(TMP.path_join("home"))
	_remove(ProjectSettings.globalize_path(TMP))
	DirAccess.make_dir_recursive_absolute(home)
	OS.set_environment("TL_HOME_BUILD_DIR", home)
	var s := GDScript.new()
	s.source_code = BOOT
	s.reload()
	boot = Node.new()
	boot.set_script(s)
	root.add_child(boot)
	hub = Hub.new(boot)
	var a: Dictionary = await end_of(5, 0)
	var c: Dictionary = await card_of(a, "key")
	say("win", c.shown and c.early_open and c.closed and c.menu and c.head == "You won" and c.counts == "played 1 time   ·   won 1   ·   best 5"
		and c.unlocked == "Unlocked: bench, light mast, brick" and c.node_unlocked,
		"trophies %s; card: %s / %s / %s / %s; a key at frame 2 left it open %s, one at frame %d closed it %s, menu after %s" % [
		str(a.get("trophies")), c.head, c.title, c.counts, c.unlocked, c.early_open, Card.HOLD, c.closed, c.menu])
	var b: Dictionary = await end_of(5, 0)
	c = await card_of(b, "click")
	say("again", c.shown and c.closed and c.menu and c.counts == "played 2 times   ·   won 2   ·   best 5" and c.unlocked == ""
		and not c.node_unlocked, "trophies %s; card: %s / %s; Unlocked line %s (node %s); closed by a click %s" % [
		str(b.get("trophies")), c.head, c.counts, "'%s'" % c.unlocked, c.node_unlocked, c.closed])
	var t: Dictionary = await end_of(0, 0)
	c = await card_of(t, "key")
	say("third", c.shown and c.closed and c.head == "Results" and c.counts == "played 3 times   ·   won 2   ·   best 5"
		and c.unlocked == "Unlocked: plaster", "trophies %s; card: %s / %s / %s" % [str(t.get("trophies")), c.head, c.counts, c.unlocked])
	var n: Dictionary = await end_of(0, 30)
	c = await card_of(n, "key")
	var file: Dictionary = Trophies.read(home).packs.get("seed.paddle", {})
	say("none", not c.shown and c.menu and not n.has("trophies") and str(file) == str({"plays": 3, "wins": 2, "best": 5}),
		"a counted run of 30 frames: trophies key %s, card %s, menu %s; trophies.json %s" % [n.has("trophies"), c.shown, c.menu, str(file)])
	_remove(ProjectSettings.globalize_path(TMP))
	OS.set_environment("TL_HOME_BUILD_DIR", "")
	print("RESULTS %s" % ("ok" if ok_all else "fail"))
	print("RESULTS DONE")
	quit(0 if ok_all else 1)


## The paddle seed opened as a dungeon (a person's play when `counted` is 0), the player's side given `score`, left.
## Returns the dungeon's result; the dungeon is handed to the hub (its `dungeon`), not yet freed.
func end_of(score: int, counted: int) -> Dictionary:
	var d: Node = Dungeon.new()
	boot.add_child(d)
	var ok: bool = await d.call("open", ProjectSettings.globalize_path("res://seeds/seed_paddle"), {"seed": 1, "frames": counted, "title": "Paddle court"})
	if not ok:
		return {"error": str(d.get("problem"))}
	await wait(10)
	var rules: Node = Trophies._find_rules(d)
	if rules != null and score > 0:
		rules.call("add_score", (rules.get("sides") as PackedStringArray)[0], score)
	await wait(2)
	if not bool(d.get("finished")):
		d.call("close", "leave")
	hub.set("dungeon", d)
	return d.get("result")


## Hands the ended dungeon to the hub and reads what it shows; `how` closes the card ("key" or "click").
func card_of(res: Dictionary, how: String) -> Dictionary:
	if hub.get("menu") != null:
		hub.call("_free_menu")
		await wait(2)
	hub.call("_on_dungeon_left", "leave")
	await wait(2)
	var card: Node = hub.get("results")
	var out := {"shown": card != null, "early_open": false, "closed": false, "menu": false, "head": "", "title": "",
		"counts": "", "unlocked": "", "node_unlocked": false}
	if card != null:
		var lines: Dictionary = card.get("lines")
		out.head = str(lines.head)
		out.title = str(lines.title)
		out.counts = str(lines.counts)
		out.unlocked = str(lines.unlocked)
		out.node_unlocked = card.find_child("Unlocked", true, false) != null
		out.menu = hub.get("menu") != null           # must be false while the card is up
		press(how)
		await wait(1)
		out.early_open = is_instance_valid(card) and not bool(card.get("_done"))
		await wait(Card.HOLD)
		press(how)
		await wait(2)
		out.closed = not is_instance_valid(card) or bool(card.get("_done"))
		out.menu = not bool(out.menu) and hub.get("menu") != null and hub.get("results") == null
	else:
		out.menu = hub.get("menu") != null
	await wait(4)                                    # the hub's census of the menu waits 3 frames
	return out


func press(how: String) -> void:
	if how == "click":
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.pressed = true
		m.position = Vector2(10, 10)
		root.push_input(m)
	else:
		var k := InputEventKey.new()
		k.keycode = KEY_SPACE
		k.physical_keycode = KEY_SPACE
		k.pressed = true
		root.push_input(k)
		var up := k.duplicate() as InputEventKey
		up.pressed = false
		root.push_input(up)


func _remove(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f: String in d.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	for sub: String in d.get_directories():
		_remove(path.path_join(sub))
	DirAccess.remove_absolute(path)
