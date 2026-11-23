extends "rink_bot.gd"
## One named set start per contact. The bot reads the previous physics step and presses the player's keys.
## Measured pre-impact speeds and hit frames prevent an incidental collision from passing a row.

const ROWS := ["braced", "head_on", "same_way", "cross_front", "front_1", "front_2_75", "front_4_5",
	"front_6_25", "front_8", "side_8", "carrier", "hold", "grace"]
## H1 build (23 Nov), sheet row A4: the hit law's speeds scale by 9.2 / 12.65, so 6.25 m/s head-on is a knockdown now (ratio 1.12, was
## 0.82), a sprint at 10 m/s into a side-braced man a stumble (0.51) and 8 m/s into his side a stumble (0.42), both with the
## attacker's recoil; S4: the cross-check lands 8 frames after the press (start + 9, was + 11); S9: down 36-126 frames.
const FRONT := ["bump", "stumble", "stumble", "knockdown", "knockdown"]

var rows: Array = []
var start := -1
var baseline := 0
var initial_speed := 0.0
var victim_speed := 0.0
var observed_brace := false
var hit: Dictionary = {}
var down_seen := false
var wake := -1
var again := -1
var held_contact := false
const MIN_SEPARATION := 2.0 * 0.88 - 0.05  # Measured drawn half-width, independent of the collision tuning.
var impacts: Dictionary = {}
var observed_row := ""
var standing_frames := 0

func _distance(a: Dictionary, b: Dictionary) -> float:
	return Vector2(a.pos[0], a.pos[1]).distance_to(Vector2(b.pos[0], b.pos[1]))

func _finish(label: String, ok: bool, detail := "") -> void:
	rows.append({"row": label, "ok": ok, "hit": hit.duplicate(), "att_speed": initial_speed, "vic_speed": victim_speed, "detail": detail})
	ctx.input.release(&"cross")
	ctx.input.release(&"sprint")
	ctx.input.set_axis(&"left", &"right", 0)
	ctx.input.set_axis(&"up", &"down", 0)
	start = -1

func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	if not classic():
		return
	var hs: Dictionary = s.hits
	if observed_row != "" and int(hs.by.b0) > baseline:
		var last: Dictionary = hs.last
		var sample: Dictionary = impacts.get_or_add(int(last.frame), {"row": observed_row, "frames": 0})
		if not hs.get("down", {}).has(last.by) and not hs.get("down", {}).has(last.on):
			var distance := _distance(_sk(last.by), _sk(last.on))
			sample["min_m"] = minf(distance, sample.get("min_m", distance))
			sample.frames += 1
			if start < 0:
				standing_frames += 1
		# Keep the row on the ice through the get-up and half a second of standing contact.
		if start < 0 and standing_frames < 30:
			return
	if rows.size() == ROWS.size():
		done = true
		return
	var label: String = ROWS[rows.size()]
	if start < 0:
		if not hs.get("down", {}).is_empty() or not hs.get("stumbling", {}).is_empty() or s.get("fun", {}).get("stop_left", 0) > 0:
			return
		if observed_row != "":
			# Clear the contact patch for a physics step before teleporting the next pair onto it.
			ctx.input.tap(&"drill_reverse_lane")
			observed_row = ""
			return
		ctx.input.tap(StringName("drill_contact_" + label))
		start = frame
		observed_row = label
		standing_frames = 0
		baseline = int(hs.by.b0)
		hit = {}
		observed_brace = false
		held_contact = false
		down_seen = false
		wake = -1
		again = -1
		return
	var age := frame - start
	var me := _sk("b0")
	var him := _sk("r0")
	if age == 1:
		initial_speed = me.speed
		victim_speed = him.speed
		match label:
			"hold": ctx.input.press(&"cross")
			"cross_front", "grace": ctx.input.tap(&"cross")
			"braced":
				ctx.input.set_axis(&"left", &"right", 1)
				ctx.input.press(&"sprint")
				ctx.input.tap(&"check")
			_:
				ctx.input.set_axis(&"left", &"right", 0)   # L4b: glide through the 12-frame wind-up (an axis left from the last row braked him)
				ctx.input.tap(&"check")
	if hs.get("braced", false) and hs.get("hold_frames", 0) >= 20:
		observed_brace = true
	var n := int(hs.by.b0) - baseline
	if n > 0 and hit.is_empty():
		hit = hs.last.duplicate()
	if label == "carrier":
		if age >= 20:
			_finish(label, n == 0 and s.puck.get("holder", "") == "b0")
	elif label == "hold":
		if n == 0 and age > 20:
			ctx.input.set_axis(&"left", &"right", 1)
		elif n == 1:
			# L4b: r0 now lies where he fell and b0 is kept off him (rule 8): steer round him to r1
			var to_r1: Vector2 = _v(_sk("r1").pos) - _v(me.pos)
			ctx.input.set_axis(&"left", &"right", clampf(to_r1.x, -1, 1))
			ctx.input.set_axis(&"up", &"down", clampf(to_r1.y, -1, 1))
			if _distance(me, _sk("r1")) <= 2.0 * float(s.body_radius) + 0.2:
				held_contact = true
		if held_contact or n > 1 or age > 420:
			_finish(label, n == 1 and observed_brace and hit.get("on") == "r0" and hit.get("held", false) and hit.get("class") in ["stumble", "knockdown"] and hs.get("spent", false) and held_contact,
				"held through frame %d, second opponent in contact %s, hits %d" % [age, held_contact, n])
	elif label == "grace":
		down_seen = down_seen or hs.get("down", {}).has("r0")
		if down_seen and wake < 0 and hs.get("grace", {}).has("r0") and not hs.get("down", {}).has("r0"):
			wake = frame
		if wake >= 0 and again < 0:
			if _distance(me, him) < 2.0 * float(s.body_radius) + 0.85:
				ctx.input.tap(&"cross")
				again = frame
			else:
				ctx.input.set_axis(&"left", &"right", signf(him.pos[0] - me.pos[0]))
		if n >= 2:
			var second: Dictionary = hs.last
			var ok: bool = hit.get("class") == "knockdown" and down_seen and wake >= 0 and int(second.frame) - wake < 120 and second["class"] == "bump" and second.ratio >= 0.4 and not hs.get("stumbling", {}).has("r0")
			_finish(label, ok, "second %s, ratio %.3f, %d frames after get-up" % [second["class"], second.ratio, int(second.frame) - wake])
	elif n > 0:
		var cls: String = hit["class"]
		var ok: bool = hit.on == "r0" and hit.by == "b0"
		var detail := ""
		match label:
			"braced": ok = ok and cls == "stumble" and hit.recoil and hs.get("stumbling", {}).has("b0") and initial_speed > 9.8
			"head_on": ok = ok and cls == "knockdown" and hit.ratio >= 1 and hit.closing > 15.8 and hit.down_frames >= 36 and hit.down_frames <= 126
			"same_way":
				var change := absf(float(him.speed) - victim_speed)
				ok = ok and cls == "bump" and absf(hit.closing) < 0.1 and initial_speed > 7.9 and victim_speed > 7.9 and change < 1.0
				detail = "victim speed change %.3f m/s" % change
			"cross_front": ok = ok and cls == "knockdown" and hit.kind == "cross" and int(hit.frame) == start + 9 and absf(initial_speed - 4.0) < 0.1
			"side_8": ok = ok and cls == "stumble" and hit.recoil and absf(hit.closing - 8.0) < 0.1
			_: ok = ok and cls == FRONT[rows.size() - 4]
		_finish(label, ok, detail)
	if start >= 0 and age > 440:
		_finish(label, false, "timeout, wake %d, pressed again %d, hits %d, last %s" % [wake, again, n, hs.get("last", {})])

func _bot_result() -> Dictionary:
	var ok: bool = done and rows.size() == ROWS.size()
	var failures := PackedStringArray()
	for r: Dictionary in rows:
		if not r.ok:
			ok = false
			failures.append(r.row)
	var minimum := INF
	for sample: Dictionary in impacts.values():
		if sample.frames == 0:
			ok = false
		else:
			minimum = minf(minimum, sample.min_m)
	ok = ok and impacts.size() == 13 and minimum >= MIN_SEPARATION
	var result := {"ok": ok, "summary": "%d contact drills, failed [%s], %d impacts, closest standing %.3f m" % [rows.size(), ", ".join(failures), impacts.size(), minimum], "rows": rows, "impacts": impacts.values()}
	if is_finite(minimum):
		result["min_m"] = minimum
	return result
