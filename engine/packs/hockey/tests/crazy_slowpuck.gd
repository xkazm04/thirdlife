extends Node
## Measure a slow release against a plain one and the consecutive frames around wake-up.
var ctx
var done := false
var rows := []
var row := {}

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
	var age := frame % 155
	var slow := frame >= 155
	match age:
		0:
			row = {}
			ctx.input.tap(&"menu")
		3: ctx.input.tap(&"crazy_slow" if slow else &"crazy_open_ice")
		16:
			if slow:
				ctx.input.tap(&"ability")
				ctx.input.tap(&"check")
		20: ctx.input.tap(&"shoot")
	if age - 1 in [21,140,141]:   # L4 merge: a tapped shot leaves on the release (charge shot, thirdjam StepCharge), one frame later
		var v: Array = s.puck.vel
		row[str(age - 1)] = Vector2(v[0],v[1]).length()
		row["left"+str(age - 1)] = s.crazy.puck.get("slow_puck",0)
	if age == 148:
		row.shots = s.shots.b0
		rows.append(row)
		done = slow

## Finish after the last observation.
func _bot_done() -> bool:
	return done

## Return the verdict and the measurements that establish it.
func _bot_result() -> Dictionary:
	var ok: bool = done and rows[0].shots == 1 and rows[1].shots == 1 and absf(rows[1]["21"]/maxf(0.01,rows[0]["21"])-0.5) < 0.025 and rows[1].left21 == 120 and rows[1].left140 == 1 and rows[1].left141 == 0 and absf(rows[1]["141"]/maxf(0.01,rows[1]["140"])-2.0) < 0.035
	return {"ok":ok,"summary":str(rows),"rows":rows}
