extends "rink_bot.gd"
## L4b: the body check's wind-up (thirdjam JamSim.cpp:1968-2177; JamCartridge.h:461,479). b0 glides at 4.5 m/s toward a
## standing r0 from 1.6 m between the bodies and presses F at once. The press winds up 12 frames (the body_check clip's hit
## frame, RIGS.md), the human is drawn up to 1.0 m toward his man, and the hit must land on the clip's hit frame (+-1).
## Then the same from 0.33 m: they meet inside the wind-up, and the hit lands at the meeting (a late press is still a hit).

var row := 0
var t0 := -1
var end_at := -1
var base_hits := 0
var rows: Array = []
var next_at := 0                      # a landed check costs 40 frames of recovery before the next press


func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	if not classic():
		return
	if row >= 2:
		done = true
		return
	if t0 < 0:
		if frame < next_at:
			return
		ctx.input.set_axis(&"left", &"right", 0)
		ctx.input.tap(&"drill_windup_front" if row == 0 else &"drill_contact_front_4_5")
		t0 = frame
		end_at = -1
		base_hits = int(s.hits.by.b0)
		return
	var age := frame - t0
	if age == 1:
		ctx.input.tap(&"check")
	var w: Dictionary = s.hits.get("windups", {})
	if w.has("b0") and end_at < 0:
		end_at = int(w.b0.end)
	if int(s.hits.by.b0) > base_hits:
		var hit: Dictionary = s.hits.last
		rows.append({"class": hit["class"], "hit": int(hit.frame), "end": end_at, "early": end_at - int(hit.frame)})
		row += 1
		t0 = -1
		next_at = frame + 60
		return
	if age > 120:
		rows.append({"class": "none", "hit": -1, "end": end_at, "early": 99})
		row += 1
		t0 = -1


func _bot_result() -> Dictionary:
	var ok: bool = done and rows.size() == 2 and rows[0]["class"] != "none" and absi(int(rows[0].early)) <= 1 		and rows[1]["class"] != "none" and int(rows[1].early) > 1
	return {"ok": ok, "summary": "from 1.6 m: %s; from 0.33 m: %s (early = frames before the clip's hit frame)" % [rows[0] if rows.size() > 0 else {}, rows[1] if rows.size() > 1 else {}], "rows": rows}
