extends Node
## Fire into the same two-man lane with a plain puck, then with an armed shot.
var ctx
var done := false
var rows := []
var peak := {}
var shots := 0
var downs := 0
var speed := 0.0
var held := false
var ranges := {}

## Drive the same start panel as a player. Drill ages begin on the start press.
var panel_frames := 0

## The runner supplies the public input and game-state context.
func _bot_setup(c) -> void:
	ctx = c

## Play the scheduled inputs and sample the resulting physics frames.
func _bot_tick(tick: int) -> void:
	var s: Dictionary = ctx.pack_state()
	if s.has("menu"):
		if s.menu.mode == "shotgun":
			ctx.input.tap(&"shoot")
		elif tick % 2 == 0:
			ctx.input.tap(&"left")
		panel_frames += 1
		return
	var frame := tick - panel_frames
	var age := frame % 110
	var loaded := frame >= 110
	match age:
		0:
			ctx.input.tap(&"menu")
			peak = {}
			speed = 0
		3: ctx.input.tap(&"crazy_shot_line")
		17:
			held = s.get("shoot_ready",false)
			if loaded:
				ctx.input.tap(&"ability")
				ctx.input.tap(&"check")
		20:
			for sk in s.skaters:
				if sk.id in ["r0", "r1"]:
					ranges[sk.id] = sk.pos[0] - s.puck.pos[0]
			ctx.input.tap(&"shoot")
	if age > 20 and s.has("crazy"):
		shots = s.shots.b0
		downs = s.crazy.get("shotgun_downs",0)
		var v: Array = s.puck.vel
		speed = maxf(speed,Vector2(v[0],v[1]).length())
		for id in s.hits.get("down",{}):
			peak[id] = true
	if age == 105:
		rows.append({"ranges":ranges.duplicate(),"shot":held and shots == 1,"down":peak.duplicate(),"count":downs,"speed":speed})
		done = loaded

## Finish after the last observation.
func _bot_done() -> bool:
	return done

## Return the verdict and the measurements that establish it.
func _bot_result() -> Dictionary:
	var ok: bool = done and rows[0].shot and rows[0].down.is_empty() and rows[0].count == 0 and rows[1].shot and rows[1].down.has("r0") and rows[1].down.has("r1") and rows[1].count >= 2 and rows[1].speed > 26
	for row in rows:
		ok = ok and absf(row.ranges.r0 - 5.0) < 0.1 and absf(row.ranges.r1 - 10.0) < 0.1
	return {"ok":ok,"summary":str(rows),"rows":rows}
