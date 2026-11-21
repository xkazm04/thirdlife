extends RefCounted

## The human's keys and mouse for this frame (the match and the first-minute drill).
func input(g) -> void:
	var carrying: bool = g.api.carrier == "b0"
	if g.ctx.input.just_pressed(&"pass"):
		g.api.try_pass("b0")
	if g.ctx.input.just_pressed(&"poke"):
		g.api.try_poke("b0")
	if g.ctx.input.just_pressed(&"check") and not g.crazy.use_key(g) and not carrying:
		g.hits.try_check("b0")         # L5 crazy: F with an ability ready uses it instead (the right button still checks)

## Read the hold before the other skaters choose a hit on this frame.
func cross_input(g) -> void:
	var carrying: bool = g.api.carrier == "b0"
	if g.ctx.input.just_pressed(&"cross") and not carrying:
		g.hits.try_cross("b0")
	g.hits.hold_input(g.ctx.input.pressed(&"cross"), carrying, g.ctx.input.just_pressed(&"cross"))

func live_input(g) -> void:
	cross_input(g)
	var i: int = g.skate.human_slot
	g.skate.pace(i, g.ctx.input.pressed(&"sprint"), g.skate.intent[i])
	g.api.charge_input(g.ctx.input.pressed(&"shoot"), g.ctx.input.just_pressed(&"shoot"), g.ctx.input.just_released(&"shoot"))

## Sample the cursor before possession and poke resolution. A cursor in the dead zone holds the heading.
func aim(g) -> void:
	var move: Vector2 = g.ctx.input.vector(&"left", &"right", &"up", &"down")
	g.skate.brake("b0", false)
	g.skate.want("b0", Vector3(move.x, 0, move.y))
	var player: TLBiped = g.skaters["b0"]
	var at: Vector3 = player.global_position
	if not g.ctx.input.aim_valid(&"aim"):
		g.stick_heading = Vector3.ZERO
		g.api.stick_dir.erase("b0")
		g.api.aim_at.erase("b0")
		if player.rig != null:
			player.rig.set_param(&"look_at", null)
		return
	var fwd: Vector3 = g.api.fwd_of("b0")
	if g.stick_heading == Vector3.ZERO:
		g.stick_heading = fwd
	var want: Vector3 = g.ctx.input.aim_direction(&"aim", at, Vector3.ZERO)
	if want != Vector3.ZERO:
		var turn: float = deg_to_rad(float(g.tune["aim"]["stick_turn_deg_per_frame"]))
		var ang: float = g.stick_heading.signed_angle_to(want, Vector3.UP)
		g.stick_heading = g.stick_heading.rotated(Vector3.UP, clampf(ang, -turn, turn)).normalized()
	g.api.stick_dir["b0"] = g.stick_heading
	g.api.aim_at["b0"] = g.ctx.input.aim(&"aim")
	if player.rig != null:
		player.rig.set_param(&"look_at", g.ctx.input.aim(&"aim") + Vector3(0, 1.0, 0))
