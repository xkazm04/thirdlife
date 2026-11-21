extends Node
## Compare the same high-speed check with and without protection and sample both ends of its timer.
var ctx
var done := false
var rows := []
var left := []
var impact := {}
var speed := 0.0

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
	var age := frame % 391
	var protected := frame < 391
	match age:
		0: ctx.input.tap(&"menu")
		3: ctx.input.tap(&"crazy_rush_shield" if protected else &"crazy_rush")
		10:
			if protected:
				ctx.input.tap(&"ability")
				ctx.input.tap(&"check")
		61:   # L4 merge: the press is at 58 now (wider bodies meet sooner); his speed three frames after it
			for sk in s.skaters:
				if sk.id == "r0":
					speed = sk.speed
		76:
			impact = {"speed":speed,"carrier":s.puck.get("holder",""),"tries":s.hits.tries.r0,"landed":s.hits.by.r0,"blocks":s.crazy.get("shield_blocks",0)}
	if protected and age in [11,370,371]:
		left.append(s.crazy.skaters.get("b0",{}).get("shield_frames",0))
	if age == 382:
		rows.append(impact)
		done = not protected

## Finish after the last observation.
func _bot_done() -> bool:
	return done

## Return the verdict and the measurements that establish it.
func _bot_result() -> Dictionary:
	var ok: bool = done and left == [360,1,0] and rows[0].tries == 1 and rows[0].speed > 3 and rows[0].carrier == "b0" and rows[0].landed == 0 and rows[0].blocks == 1 and rows[1].tries == 1 and rows[1].speed > 3 and rows[1].carrier != "b0" and rows[1].landed == 1
	return {"ok":ok,"summary":"%s | expiry %s" % [rows,left],"rows":rows}
