extends "rink_bot.gd"
## N3 carrier sprint is 1.012 x base x 1.15, with 80% of a free skater's thrust.
## Two skaters in one straight lane. The drill supplies the carrier's forward and Shift inputs.
## Both use the match skate step. The driving hand supplies the defender's input.

var phase := "start"
var since := 0
var drained := -1
var refilled := -1
var caught := -1
var free_peak := 0.0
var carry_peak := 0.0
var start_gap := 0.0
var ticks_ok := true
var clean_chase := true

func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	var me: Dictionary = s.skaters[0]
	var bar: int = s.skate.stamina.b0
	var age := frame - since
	match phase:
		"start":
			ctx.input.tap(&"drill_sprint_lane")
			ctx.input.set_axis(&"left", &"right", 1.0)
			ctx.input.press(&"sprint")
			since = frame
			phase = "sprint"
		"sprint":
			free_peak = maxf(free_peak, me.speed)
			ticks_ok = ticks_ok and bar == maxi(0, 64800 - 360 * age) and s.skate.get("sprinting", {}).has("b0")
			if bar == 0:
				drained = age
				ctx.input.release(&"sprint")
				ctx.input.set_axis(&"left", &"right", 0.0)
				since = frame
				phase = "recover"
		"recover":
			ticks_ok = ticks_ok and bar == mini(64800, 180 * age) and not s.skate.get("sprinting", {}).has("b0")
			if bar == s.skate.stamina_full:
				refilled = age
				ctx.input.tap(&"drill_sprint_chase")
				ctx.input.set_axis(&"left", &"right", 1.0)
				ctx.input.press(&"sprint")
				since = frame
				phase = "chase"
		"chase":
			var carrier: Dictionary
			for sk: Dictionary in s.skaters:
				if sk.id == "r0":
					carrier = sk
					break
			var gap: float = carrier.pos[0] - me.pos[0]
			if age == 1:
				start_gap = gap
			carry_peak = maxf(carry_peak, carrier.speed)
			var both: Dictionary = s.skate.get("sprinting", {})
			clean_chase = clean_chase and both.has("b0") and both.has("r0") and s.puck.get("holder", "") == "r0" \
				and absf(carrier.pos[1] - me.pos[1]) < 0.05 and absf(carrier.pos[0]) < 26.0
			if gap <= 2.0 * float(s.body_radius) + float(me.speed) / 60.0:
				ctx.input.tap(&"check")
				caught = age
				phase = "contact"
		"contact":
			var hit: Dictionary = s.hits.get("last", {})
			clean_chase = clean_chase and hit.get("by") == "b0" and hit.get("on") == "r0" and hit.get("frame") == since + caught
			done = true
	if frame > 900:
		done = true

func _bot_result() -> Dictionary:
	var ok := done and ticks_ok and absf(free_peak - 10.58) <= 0.2 and absi(drained - 180) <= 2 and absi(refilled - 360) <= 2 \
		and clean_chase and start_gap >= 5.9 and absf(carry_peak - 8.0 * 1.012 * 1.15) <= 0.2 and carry_peak <= 1.012 * 1.15 * 8.0 and caught > 0 and caught <= 300
	return {"ok": ok, "summary": "free %.3f m/s, drain/refill %d/%d frames, carrier %.3f m/s, catch from %.2f m in %d frames" % [free_peak, drained, refilled, carry_peak, start_gap, caught],
		"free_speed": free_peak, "drain": drained, "refill": refilled, "carrier_speed": carry_peak, "catch_frame": caught, "ticks": ticks_ok, "both_sprinting": clean_chase}

