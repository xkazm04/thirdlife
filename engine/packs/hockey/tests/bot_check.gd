extends "rink_bot.gd"
## L4 director (21 Nov 14:50): the cross-check winds up 10 frames (was thirdjam's 8) so it lands on L2b's cross_check clip hit frame 10.
## Measures the speed ladder against a standing front and side, attacker recoil, carrier lockout and a rear cross.

const SPEEDS: Array = [1.0, 2.75, 4.5, 6.25, 8.0]
const RANK: Dictionary = {"none": 0, "bump": 1, "stumble": 2, "knockdown": 3}
var rows: Array = []                  # [label, drill, speed, key]
var row: int = 0
var phase: String = "start"
var t0: int = 0
var pressed_at: int = -1
var given_before: int = 0
var down_seen: int = 0
var result: Dictionary = {}
var results: Array = []

func _bot_setup(c) -> void:
	super(c)
	for v: float in SPEEDS:
		rows.append(["head-on %.2f m/s" % v, "hit_head_on", v, &"check"])
	for v: float in SPEEDS:
		rows.append(["side %.2f m/s" % v, "hit_side", v, &"check"])
	rows.append(["braced, side, 8.00 m/s", "hit_braced", 8.0, &"check"])
	rows.append(["the carrier checks, 8.00 m/s", "hit_as_carrier", 8.0, &"check"])
	rows.append(["cross-check (C) on a carrier, 2.00 m/s", "cross_carrier", 2.0, &"cross"])

func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	if not classic():
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
		pressed_at = -1
		down_seen = 0
		result = {}
		phase = "run"
		return
	var age: int = frame - t0
	if age < 2:
		if age == 1:
			given_before = int(s.hits.by.b0)
		return
	var me: Dictionary = _sk("b0")
	var him: Dictionary = _sk("r0")
	var spd: float = float(me["speed"])
	# a person keeps his speed: pushes while under it, glides while over it
	ctx.input.set_axis(&"left", &"right", 0.0 if spd >= float(r[2]) else 1.0)
	var d: float = _v(me["pos"]).distance_to(_v(him["pos"]))
	if pressed_at < 0 and s.state == "running" and d <= 2.0 * float(s.body_radius) + 0.18:
		ctx.input.tap(r[3])
		pressed_at = frame
		result["speed_at_press"] = snappedf(spd, 0.01)
		result["frame"] = frame
	var hs: Dictionary = s["hits"]
	if hs.get("down", {}).has("r0"):
		down_seen += 1
	if pressed_at >= 0 and frame - pressed_at == (11 if r[3] == &"cross" else 3):
		var last: Dictionary = hs.get("last", {})
		var fresh: bool = int(s.hits.by.b0) > given_before
		result["class"] = str(last.get("class", "none")) if fresh else "none"
		result["closing"] = float(last.get("closing", 0.0)) if fresh else 0.0
		result["down_frames"] = int(last.get("down_frames", 0)) if fresh else 0
		result["kind"] = last.get("kind", "") if fresh else ""
		result["ratio"] = last.get("ratio", 0.0) if fresh else 0.0
		result["recoil"] = fresh and last.get("recoil", false)
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

func _bot_result() -> Dictionary:
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
			var expected: int = [1, 2, 2, 2, 3][i] if col == 0 else 1
			if rk < prev or rk != expected:
				ok = false
				notes.append("NOT MONOTONE at " + str(x["row"]))
			if str(x.get("class", "")) == "knockdown":
				var dn: int = int(x.get("down_frames", 0))
				if dn < prev_down or dn < 60 or dn > 150:
					ok = false
					notes.append("DOWN FRAMES out of bounds at " + str(x["row"]))
				prev_down = dn
			prev = rk
	if results.size() == rows.size():
		var braced: Dictionary = results[10]
		if str(braced.get("class", "")) != "bump" or not bool(braced.get("braced", false)) or not braced.get("recoil", false):
			ok = false
			notes.append("the braced man did not hold")
		var car: Dictionary = results[11]
		if str(car.get("class", "")) != "none" or str(car.get("holder", "")) != "b0":
			ok = false
			notes.append("the carrier's check did something")
		var cr: Dictionary = results[12]
		if str(cr.get("class", "")) != "stumble" or cr.get("kind") != "cross" or str(cr.get("holder", "")) == "r0" or int(cr.get("down_seen", 0)) > 0:
			ok = false
			notes.append("the cross-check did not take the puck cleanly")
	return {"ok": ok, "summary": "%d check rows, %s" % [results.size(), "all passed" if ok else ", ".join(notes)], "rows": results}
