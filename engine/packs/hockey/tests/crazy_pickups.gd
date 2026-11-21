extends Node
## Verify a natural spawn, slot collection, boost timing, shot correction and actual puck dimensions.
var ctx
var base := false
var zone := false
var first := {}
var last := {}
var expired := false
var ability := false
var done := false
var count := 0
var missed := false
var modifiers := {}
var aim_error := 180.0
var drag_ended := false
var size_ended := false
var aim_ended := false
var goal_direction := Vector2.ZERO

## Drive the same start panel as a player. Drill ages begin on the start press.
var panel_frames := 0

## The runner supplies the public input and game-state context.
func _bot_setup(c) -> void:
	ctx = c

## Play the scheduled inputs and sample the resulting physics frames.
func _bot_tick(tick: int) -> void:
	var s: Dictionary = ctx.pack_state()
	if s.has("menu"):
		if s.menu.mode == "arsenal":
			ctx.input.tap(&"shoot")
		elif tick % 2 == 0:
			ctx.input.tap(&"left")
		panel_frames += 1
		return
	var frame := tick - panel_frames
	if frame == 0:
		base = s.mode == "base" and not s.has("crazy")
		ctx.input.tap(&"menu")
		return
	if not s.has("crazy"):
		return
	var c: Dictionary = s.crazy
	var me: Dictionary = c.skaters.get("b0",{})
	if frame < 121 and not c.pickups.is_empty():
		missed = true
	match frame:
		121:
			for e in c.pickups:
				var z := absf(e.pos[1])
				var x := absf(e.pos[0])
				zone = (x <= 16 and z <= 2 or x <= 22 and z >= 7 and z <= 13) and Vector2(x,z).length() >= 2.5
		123: ctx.input.tap(&"crazy_packages")
		125:
			first = me.duplicate(true)
			ctx.input.press(&"right")
		164: ctx.input.release(&"right")
		424: last = me.duplicate(true)
		425:
			expired = not me.get("boosts",{}).has("speed") and is_equal_approx(me.skate_speed, 9.2) and is_equal_approx(me.skate_accel, 13.8)   # L4 merge: a free skater skates x1.15 (thirdjam free_speed_mult)
			count = c.taken.get("speed",0)
			ctx.input.tap(&"menu")
		428: ctx.input.tap(&"crazy_modifiers")
		430: modifiers = c.puck.duplicate()
		444:
			var pos: Array = s.puck.pos
			goal_direction = (Vector2(26,0) - Vector2(pos[0],pos[1])).normalized()
			ctx.input.tap(&"shoot")
		446:   # L4 merge: the tapped shot leaves on the release, one frame later
			var v: Array = s.puck.vel
			aim_error = absf(rad_to_deg(Vector2(v[0],v[1]).angle_to(goal_direction)))
			if Vector2(v[0],v[1]).length() < 12 or s.shots.b0 != 1:
				aim_error = 180.0
		789: drag_ended = c.puck.get("heavy_puck") == 1
		790: drag_ended = drag_ended and not c.puck.has("drag") and c.puck.max_speed == 30
		909: aim_ended = me.get("boosts",{}).get("precision") == 1
		910: aim_ended = aim_ended and not me.get("boosts",{}).has("precision")
		1029: size_ended = c.puck.get("big_puck") == 1
		1030:
			size_ended = size_ended and absf(c.puck.radius-0.12) < 0.001 and absf(c.puck.collision_radius-0.12) < 0.001
			done = true
	if me.get("held") == "shield" and c.taken.get("shield",0) >= 1:
		ability = true

## Finish after the last observation.
func _bot_done() -> bool:
	return done

## Return the verdict and the measurements that establish it.
func _bot_result() -> Dictionary:
	var ok: bool = done and base and zone and not missed and ability and count >= 1 and expired and first.get("boosts",{}).get("speed") == 300 and last.get("boosts",{}).get("speed") == 1 and is_equal_approx(first.get("skate_speed"), 13.8) and is_equal_approx(first.get("skate_accel"), 20.7) and is_equal_approx(last.get("skate_accel", 0.0), 20.7)   # L4b: the boost does not compound (skate.gd resets accel every frame)
	ok = ok and absf(modifiers.get("radius",0)-0.18) < 0.001 and absf(modifiers.get("collision_radius",0)-0.18) < 0.001 and absf(modifiers.get("drag",0)-0.8) < 0.001 and modifiers.get("max_speed",0) == 15 and drag_ended and size_ended and aim_ended and aim_error < 0.25
	return {"ok":ok,"summary":"base %s, zone %s, shield %s, speed %s, puck %s, aim error %.3f deg, expired speed/heavy/big/aim %s" % [base,zone,ability,first,modifiers,aim_error,[expired,drag_ended,size_ended,aim_ended]]}
