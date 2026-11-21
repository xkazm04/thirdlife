extends "rink_bot.gd"
## L4b: nobody stands in a man who is down (thirdjam DownedRadiusM). b0 floors a standing r0 head-on (contact_head_on), then
## skates on through where r0 lies. While r0 is down, b0's centre must stay at least his radius + 0.45 m from
## r0's lying body (the segment from his feet to his head, hits.lying) once the fall is over (20 frames), and b0 must get
## past him (go round).

var t0 := -1
var floored := false
var min_gap := 99.0
var first_gap := 99.0
var samples := 0
var past := false
var start_x := 0.0


func _seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0 if ab.length_squared() < 1e-6 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	if not classic():
		return
	if t0 < 0:
		ctx.input.tap(&"drill_contact_head_on")
		t0 = frame
		return
	var age := frame - t0
	if age == 1:
		ctx.input.tap(&"check")
	var lying: Dictionary = s.hits.get("lying", {})
	if lying.has("r0"):
		floored = true
		var l: Array = lying.r0
		var keep: float = float(s.body_radius) + 0.6 - 0.15   # his capsule edge stays 0.45 m off the lying centre line (drawn ~0.4 m half-thick)
		var gap: float = _seg(_pos("b0"), Vector2(l[0], l[1]), Vector2(l[2], l[3])) - keep
		samples += 1
		if samples > 20:
			min_gap = minf(min_gap, gap)       # after his fall (the clip swings him down over ~15 frames) and the first push-out
		else:
			first_gap = minf(first_gap, gap)
		ctx.input.set_axis(&"left", &"right", 1)          # skate on, straight through where he lies
		past = past or _pos("b0").x > maxf(l[0], l[2]) + 0.5
	elif floored:
		done = true
	if age > 400:
		done = true


func _bot_result() -> Dictionary:
	var ok: bool = done and floored and samples > 30 and min_gap >= 0.0 and past
	return {"ok": ok, "summary": "floored %s, %d frames down, closest to his lying body %+.3f m beyond the keep distance after 20 frames (%+.3f during the fall), got past %s" % [floored, samples, min_gap, first_gap, past]}
