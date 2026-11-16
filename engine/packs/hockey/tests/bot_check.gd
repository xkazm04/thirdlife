extends Node
## Bot (H2): the check table, played with a person's keys. For each row b0 skates at r0 (a drill's set start),
## pushes D while under the row's speed and glides while over it (as a person holds a pace) and taps F when r0 is inside 1.5 m, as a person times a
## hit. It reads the outcome from the state (hits.last) and counts the frames r0 is down.
## Rows: five speeds from 1 m/s to top speed head-on and from the side; a braced man hit from the side at top speed;
## a check by the carrier (nothing happens); a cross-check (C) on a carrier (he loses the puck, no knockdown).
## ok: both speed columns monotone (more speed never a smaller class), frames down inside the data's bounds,
## the braced man holds, the carrier's check does nothing, the cross-check takes the puck without a knockdown.

var ctx
var s: Dictionary = {}
const SPEEDS: Array = [1.0, 2.75, 4.5, 6.25, 8.0]
const RANK: Dictionary = {"none": 0, "bump": 1, "stumble": 2, "knockdown": 3, "cross": 1}
var rows: Array = []                  # [label, drill, speed, key]
var row: int = 0
var phase: String = "start"
var t0: int = 0
var reached: bool = false
var pressed_at: int = -1
var given_before: int = 0
var down_seen: int = 0
var result: Dictionary = {}
var results: Array = []
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c
	for v: float in SPEEDS:
		rows.append(["head-on %.2f m/s" % v, "hit_head_on", v, &"check"])
	for v: float in SPEEDS:
		rows.append(["side %.2f m/s" % v, "hit_side", v, &"check"])
	rows.append(["braced, side, 8.00 m/s", "hit_braced", 8.0, &"check"])
	rows.append(["the carrier checks, 8.00 m/s", "hit_as_carrier", 8.0, &"check"])
	rows.append(["cross-check (C) on a carrier, 2.00 m/s", "cross_carrier", 2.0, &"cross"])


func _v(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


func _sk(id: String) -> Dictionary:
	for k: Dictionary in s["skaters"]:
		if k["id"] == id:
			return k
	return {}


func _given() -> int:
	var n: int = 0
	var g: Dictionary = s["hits"]["given"]
	for side: String in g:
		for k: String in g[side]:
			n += int(g[side][k])
	return n


func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	if str(s.get("mode", "base")) != "base":
		ctx.input.tap(&"mode_base")      # H3: this bot tests the base game; under another mode param it switches to it first
		return
	if str(s.get("level", "none")) != "none":
		ctx.input.tap(&"level_none")      # H6: this bot measures against the opponents of data/ai.json; the default level is rookie
		return
	if done:
		ctx.input.set_axis(&"left", &"right", 0.0)
		return
	if row >= rows.size():
		done = true
		return
	var r: Array = rows[row]
	if phase == "start":
		ctx.input.set_axis(&"left", &"right", 0.0)
		ctx.input.tap(StringName("drill_" + str(r[1])))
		t0 = frame
		reached = false
		pressed_at = -1
		down_seen = 0
		result = {}
		phase = "run"
		return
	var age: int = frame - t0
	if age < 2:
		if age == 1:
			given_before = _given()
		return
	var me: Dictionary = _sk("b0")
	var him: Dictionary = _sk("r0")
	var spd: float = float(me["speed"])
	if spd >= float(r[2]) - 0.05:
		reached = true
	# a person keeps his speed: pushes while under it, glides while over it
	ctx.input.set_axis(&"left", &"right", 0.0 if spd >= float(r[2]) else 1.0)
	var d: float = _v(me["pos"]).distance_to(_v(him["pos"]))
	if pressed_at < 0 and d <= 1.5:
		ctx.input.tap(r[3])
		pressed_at = frame
		result["speed_at_press"] = snappedf(spd, 0.01)
		result["frame"] = frame
	var hs: Dictionary = s["hits"]
	if hs.get("down", {}).has("r0"):
		down_seen += 1
	if pressed_at >= 0 and frame - pressed_at == 3:
		var last: Dictionary = hs.get("last", {})
		var fresh: bool = _given() > given_before
		result["class"] = str(last.get("class", "none")) if fresh else "none"
		result["closing"] = float(last.get("closing", 0.0)) if fresh else 0.0
		result["down_frames"] = int(last.get("down_frames", 0)) if fresh else 0
		result["braced"] = bool(last.get("braced", false)) if fresh else false
		result["holder"] = str(s["puck"].get("holder", ""))
	if pressed_at >= 0 and (frame - pressed_at > 200 or (frame - pressed_at > 3 and down_seen > 0 and not hs.get("down", {}).has("r0"))):
		_finish()
		return
	if age > 900:
		result["class"] = "not reached"
		_finish()


func _finish() -> void:
	var r: Array = rows[row]
	result["row"] = str(r[0])
	result["down_seen"] = down_seen
	results.append(result.duplicate())
	row += 1
	phase = "start"


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var hits_cfg: Dictionary = {}
	var ok: bool = done and results.size() == rows.size()
	var notes: Array = []
	for col: int in 2:
		var prev: int = -1
		var prev_down: int = 0
		for i: int in SPEEDS.size():
			if col * SPEEDS.size() + i >= results.size():
				break
			var x: Dictionary = results[col * SPEEDS.size() + i]
			var rk: int = int(RANK.get(str(x.get("class", "none")), -1))
			if rk < prev or rk < 1:
				ok = false
				notes.append("NOT MONOTONE at " + str(x["row"]))
			if str(x.get("class", "")) == "knockdown":
				var dn: int = int(x.get("down_frames", 0))
				if dn < prev_down or dn < 30 or dn > 60:
					ok = false
					notes.append("DOWN FRAMES out of bounds at " + str(x["row"]))
				prev_down = dn
			prev = rk
	if results.size() == rows.size():
		var braced: Dictionary = results[10]
		if str(braced.get("class", "")) != "bump" or not bool(braced.get("braced", false)):
			ok = false
			notes.append("the braced man did not hold")
		var car: Dictionary = results[11]
		if str(car.get("class", "")) != "none" or str(car.get("holder", "")) != "b0":
			ok = false
			notes.append("the carrier's check did something")
		var cr: Dictionary = results[12]
		if str(cr.get("class", "")) != "cross" or str(cr.get("holder", "")) == "r0" or int(cr.get("down_seen", 0)) > 0:
			ok = false
			notes.append("the cross-check did not take the puck cleanly")
	var parts: Array = []
	for x: Dictionary in results:
		parts.append("%s: %s (closing %.2f, at %.2f m/s, down %d f, seen down %d f%s, F%d)" % [x.get("row", "?"), x.get("class", "?"), float(x.get("closing", 0.0)),
			float(x.get("speed_at_press", 0.0)), int(x.get("down_frames", 0)), int(x.get("down_seen", 0)), ", braced" if bool(x.get("braced", false)) else "", int(x.get("frame", 0))])
	return {"ok": ok, "summary": " | ".join(parts) + ("; " + "; ".join(notes) if not notes.is_empty() else ""), "rows": results, "cfg": hits_cfg}
