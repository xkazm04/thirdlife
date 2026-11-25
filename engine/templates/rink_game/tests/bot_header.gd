extends Node
## The header and the ability plate say the game's own rules and words (lane H2d, 25 Nov). G1's Arsenal plays a three-minute
## clock (game.rules.mode "timer"), and the base's header said "PERIOD 1" over an empty line where "FIRST TO 5" stood; its
## pack called the shotgun a CANNON while the base's plate said SHOTGUN.
## Headless, as tests/bot_hint.gd: a recorded match of the game's cartridge (data/match.json; selftest block 868's copy gives
## it a clock and a shotgun held from the start), every snapshot fed to two of the base's own hud.gd through a recording
## layer: one with the game's rules, one with the same game on first to 5. Each play frame:
##   - the clock game's header line is the time left (rules.gd format_timer of the snapshot's TimerLeft), never empty, and it
##     counts down over the match; the first-to game's line is "FIRST TO 5";
##   - the ability plate, while the human holds a trick, says the skin's word for it (skin.gd ability_names) and the core's
##     id for a kind the skin leaves out.
## Not in pack.json's tests (selftest block 868 registers it in its copy).

const FRAMES: int = 6000

var ctx
var Hud
var R
var Ability
var core
var hud_clock
var hud_first
var lay
var done: bool = false
var n: int = 0
var clock_lines: int = 0
var first_lines: int = 0
var plates: int = 0
var first_clock: String = ""
var last_clock: String = ""
var names: Dictionary = {}
var fails: Array = []


class Rec:
	extends RefCounted
	func clear() -> void: pass
	func extent() -> Vector2: return Vector2(1920, 1080)
	func measure(s: String, pt: float, _face: String = "bold", _tr: int = 0) -> Vector2: return Vector2(s.length() * pt * 0.6, pt * 4.0 / 3.0 * 1.17)
	func box(_p: Vector2, _s: Vector2, _f: Color, _r: float = 0.0, _e: Color = Color(), _ew: float = 0.0, _a: float = 0.0) -> void: pass
	func text(p: Vector2, s: String, pt: float, _c: Color, _o: Dictionary = {}) -> Rect2: return Rect2(p, measure(s, pt))
	func ring(_r: Rect2, _c: Color, _b: float = 0.0, _e: float = 0.0, _ec: Color = Color()) -> void: pass
	func chevron(_p: Vector2, _s: float, _c: Color, _e: Color = Color(), _ew: float = 0.0, _a: float = 0.0, _al: Vector2 = Vector2()) -> void: pass
	func polygon(_p: PackedVector2Array, _c: Color) -> void: pass
	func line(_a: Vector2, _b: Vector2, _c: Color, _w: float = 1.0) -> void: pass
	func image(_t: Texture2D, _r: Rect2, _c: Color = Color.WHITE) -> void: pass
	func minimap(_p: Vector2, _s: Vector2, _f: Vector2, _d: Array) -> void: pass
	func project(w: Vector3) -> Vector3: return Vector3(960.0 + w.x * 20.0, 540.0 + w.z * 20.0, 30.0)
	func camera_local(w: Vector3) -> Vector3: return Vector3(w.x, w.z, -30.0)
	func eye() -> Vector3: return Vector3(0, 30, 0)
	func ground_ring(c: Vector3, r: float, _n: float = 0.5) -> Rect2: return Rect2(Vector2(960.0 + (c.x - r) * 20.0, 540.0 + (c.z - r) * 20.0), Vector2(r, r) * 40.0)


func _bot_setup(c) -> void:
	ctx = c
	Hud = ctx.load_script("scripts/hud/hud.gd")
	R = ctx.load_script("scripts/hud/rules.gd")
	Ability = ctx.load_script("scripts/hud/ability.gd")


func _bot_tick(frame: int) -> void:
	if done:
		return
	if frame == 0:
		var m: Dictionary = ctx.read_json("match.json")
		var cart_file: String = String(m.get("cartridge", "hockey.regular.cartridge.json"))
		var game: Dictionary = (ctx.read_json(cart_file) as Dictionary)["game"]
		var skin: Dictionary = ctx.read_json("skin.json")
		names = skin.get("ability_names", {})
		core = ctx.cores.open("rink", cart_file)
		core.set_difficulty("pro")
		core.set_human_mode("playerbot")
		core.reset(ctx.seed)
		lay = Rec.new()
		var barks: Array = (ctx.read_json("hud_barks.json") as Dictionary)["lines"]
		hud_clock = Hud.new(lay, game, "pro", ctx.seed, barks, skin)
		var first: Dictionary = game.duplicate(true)
		first["rules"] = {"mode": "first_to", "score_to_win": 5}
		hud_first = Hud.new(lay, first, "pro", ctx.seed, barks, skin)
		if String((game.get("rules", {}) as Dictionary).get("mode", "")) != "timer":
			fails.append("the copy's cartridge is not on a clock (game.rules.mode %s)" % str((game.get("rules", {}) as Dictionary).get("mode", "")))
		return
	for i: int in 8:
		var going: bool = core.step()
		_feed(core.snapshot())
		if not going or n >= FRAMES:
			done = true
			return


func _feed(snap: Dictionary) -> void:
	n += 1
	var ui: Dictionary = {"with_puck": false, "held": {}, "press": false, "saucer": false, "braced": false, "paused": false, "stamina01": 1.0}
	hud_clock.frame(snap, ui)
	hud_first.frame(snap, ui)
	var sc: Dictionary = hud_clock.shown
	var sf: Dictionary = hud_first.shown
	if not sc.has("rule"):
		return
	var want: String = R.format_timer(int(snap["TimerLeft"]))
	if String(sc["rule"]) != want or want == "":
		if fails.size() < 6: fails.append("frame %d: the clock game's header says '%s', the time left is %s" % [n, String(sc["rule"]), want])
	else:
		clock_lines += 1
		if first_clock == "": first_clock = want
		last_clock = want
	if String(sf.get("rule", "")) == "FIRST TO 5":
		first_lines += 1
	elif fails.size() < 6:
		fails.append("frame %d: the first-to game's header says '%s'" % [n, String(sf.get("rule", ""))])
	if sc.has("ability"):
		var me: Dictionary = snap["Skaters"][int(snap["HumanIndex"])]
		var slot: int = int(me.get("AbilitySlot", -1))
		var abilities: Array = (hud_clock.ability.abilities as Array)
		var kind: String = String((abilities[slot] as Dictionary).get("kind", "")) if slot >= 0 and slot < abilities.size() else String(me.get("AbilityArmed", "shield" if int(me.get("ShieldFrames", 0)) > 0 else ""))
		var word: String = String(names.get(kind, kind.replace("_", " "))).to_upper()
		if String(sc["ability"]).begins_with("F: %s  " % word):
			plates += 1
		elif fails.size() < 6:
			fails.append("frame %d: the plate says '%s' for %s (the skin's word: %s)" % [n, String(sc["ability"]), kind, word])


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var counted: bool = first_clock != "" and last_clock != "" and first_clock != last_clock
	return {"ok": done and fails.is_empty() and clock_lines > 1000 and first_lines > 1000 and plates > 100 and counted,
		"summary": "clock header on %d frames (%s down to %s), FIRST TO 5 on %d, the plate in the skin's words on %d (names %s)%s" % [
			clock_lines, first_clock, last_clock, first_lines, plates, JSON.stringify(names), "" if fails.is_empty() else "; FAILS: " + "; ".join(fails)],
		"frames": n}
