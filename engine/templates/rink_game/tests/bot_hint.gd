extends Node
## A game's own hint line never covers the commentator's caption (lane H2b, 25 Nov). G1's Arsenal drew
## "F: BUBBLE  Green spots reload it" as its own bottom label, over the caption for the first ten seconds of every match.
## The base now has a slot for it (scripts/hud/hint.gd; a game sets ctx.root's meta "rink_hint", screen.gd hands it on).
## Headless, as tests/bot_hud_rules.gd in hokej does: a recorded match of the game's cartridge (its human played by thirdjam's
## playerbot), every snapshot fed to the pack's own hud.gd through a layer that records what it is asked to draw, three
## screen shapes in turn (16:9, 4:3, 21:9 in layout units), a hint on every frame (a short one and a long one in turn).
## Each frame: the hint is drawn, and its plate does not touch the caption's plate (text boxes grown by the plates'
## margins), nor the faceoff hint's. And the top view (one frame in four drawn with ui "top_view", as screen.gd says when the
## "top" camera is the one seen): no ring on the ice in it (the rings are the follow camera's; E1b's top stills drew yours as a
## large ellipse off the figure), rings as before in the others. Not in pack.json's tests (selftest block 868 runs it).

const FRAMES: int = 9000
const HINTS: Array = ["F: BUBBLE  Green spots reload it", "F: BUBBLE NOW  A rival is closing: press F and the bubble throws him off"]
const SHAPES: Array = [Vector2(1920, 1080), Vector2(1440, 1080), Vector2(2520, 1080)]

var ctx
var Hud
var core
var hud
var lay
var done: bool = false
var n: int = 0
var both: int = 0
var drawn: int = 0
var caption_frames: int = 0
var fails: Array = []
var rings_follow: int = 0
var rings_top: int = 0
const RINGS: Array = ["you_ring", "carrier_ring", "you_have_ring", "loose_ring"]   # true when drawn (false: held back in the top view)


## A layer that keeps what it was asked to draw: each text with its box.
class Rec:
	extends RefCounted
	var ops: Array = []
	var size: Vector2 = Vector2(1920, 1080)
	func clear() -> void: ops.clear()
	func extent() -> Vector2: return size
	func measure(s: String, pt: float, _face: String = "bold", _tr: int = 0) -> Vector2: return Vector2(s.length() * pt * 0.6, pt * 4.0 / 3.0 * 1.17)
	func box(_p: Vector2, _s: Vector2, _f: Color, _r: float = 0.0, _e: Color = Color(), _ew: float = 0.0, _a: float = 0.0) -> void: pass
	func text(p: Vector2, s: String, pt: float, _c: Color, _o: Dictionary = {}) -> Rect2:
		var r := Rect2(p, measure(s, pt))
		ops.append([s, r])
		return r
	func ring(_r: Rect2, _c: Color, _b: float = 0.0, _e: float = 0.0, _ec: Color = Color()) -> void: pass
	func chevron(_p: Vector2, _s: float, _c: Color, _e: Color = Color(), _ew: float = 0.0, _a: float = 0.0, _al: Vector2 = Vector2()) -> void: pass
	func polygon(_p: PackedVector2Array, _c: Color) -> void: pass
	func line(_a: Vector2, _b: Vector2, _c: Color, _w: float = 1.0) -> void: pass
	func image(_t: Texture2D, _r: Rect2, _c: Color = Color.WHITE) -> void: pass
	func minimap(_p: Vector2, _s: Vector2, _f: Vector2, _d: Array) -> void: pass
	func project(w: Vector3) -> Vector3: return Vector3(size.x * 0.5 + w.x * 20.0, 540.0 + w.z * 20.0, 30.0)
	func camera_local(w: Vector3) -> Vector3: return Vector3(w.x, w.z, -30.0)
	func eye() -> Vector3: return Vector3(0, 30, 0)
	func ground_ring(c: Vector3, r: float, _n: float = 0.5) -> Rect2: return Rect2(Vector2(size.x * 0.5 + (c.x - r) * 20.0, 540.0 + (c.z - r) * 20.0), Vector2(r, r) * 40.0)
	## The plate round a text drawn at p - (16, 6) (the caption's, the hint's and the faceoff hint's margins).
	func plate_of(s: String) -> Rect2:
		for o: Array in ops:
			if String(o[0]) == s:
				var r: Rect2 = o[1]
				return Rect2(r.position - Vector2(16, 6), r.size + Vector2(32, 12))
		return Rect2()


func _bot_setup(c) -> void:
	ctx = c
	Hud = ctx.load_script("scripts/hud/hud.gd")


func _bot_tick(frame: int) -> void:
	if done:
		return
	if frame == 0:
		var m: Dictionary = ctx.read_json("match.json")
		var cart_file: String = String(m.get("cartridge", "hockey.regular.cartridge.json"))
		core = ctx.cores.open("rink", cart_file)
		core.set_difficulty(String(m.get("difficulty", "pro")))
		core.set_human_mode("playerbot")
		core.reset(ctx.seed)
		lay = Rec.new()
		hud = Hud.new(lay, (ctx.read_json(cart_file) as Dictionary)["game"], "pro", ctx.seed, (ctx.read_json("hud_barks.json") as Dictionary)["lines"])
		return
	for i: int in 8:
		var going: bool = core.step()
		_feed(core.snapshot())
		if not going or n >= FRAMES:
			done = true
			return


func _feed(snap: Dictionary) -> void:
	n += 1
	lay.size = SHAPES[n % SHAPES.size()]
	var text: String = HINTS[(n / 600) % HINTS.size()]
	hud.frame(snap, {"with_puck": bool((snap["Controls"] as Dictionary).get("ButtonsWithPuck", false)), "held": {}, "press": false, "saucer": false,
		"braced": false, "paused": false, "stamina01": 1.0, "pack_hint": text, "top_view": n % 4 == 3})
	var sh: Dictionary = hud.shown
	for k: String in RINGS:
		if bool(sh.get(k, false)):
			if n % 4 == 3:
				rings_top += 1
			else:
				rings_follow += 1
			break
	if String(sh.get("pack_hint", "")) != text:
		if fails.size() < 8:
			fails.append("frame %d (%s): the hint was not drawn" % [n, str(lay.size)])
		return
	drawn += 1
	var hp: Rect2 = lay.plate_of(text)
	for k: String in ["caption", "faceoff_hint"]:
		if not sh.has(k):
			continue
		if k == "caption":
			caption_frames += 1
		var cp: Rect2 = lay.plate_of(String(sh[k]))
		if cp.size == Vector2.ZERO:
			continue
		if k == "caption":
			both += 1
		if hp.intersects(cp) and fails.size() < 8:
			fails.append("frame %d (%s): the hint %s touches the %s %s" % [n, str(lay.size), str(hp), k, str(cp)])


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	return {"ok": done and fails.is_empty() and drawn == n and both > 100 and rings_top == 0 and rings_follow > 100,
		"summary": "hint drawn on %d of %d frames, beside a caption on %d (caption frames %d), over three screen shapes; rings on %d follow frames, %d top-view frames%s" % [
			drawn, n, both, caption_frames, rings_follow, rings_top, "" if fails.is_empty() else "; FAILS: " + "; ".join(fails)],
		"frames": n}
