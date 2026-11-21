extends Node
## Measure a plain check and two loaded checks from rest, across and along the victim's blades.
var ctx
var done := false
var rows := []
var origin := Vector2.ZERO
var pace := 0.0
var peak := 0
var dropped := false

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
	var age := frame % 150
	var loaded := frame >= 150
	var pos := Vector2.ZERO
	for sk in s.skaters:
		if sk.id == "r0":
			pos = Vector2(sk.pos[0],sk.pos[1])
	match age:
		0:
			ctx.input.tap(&"menu")
			peak = 0
			dropped = false
		3: ctx.input.tap(&"crazy_hip_side" if frame >= 300 else (&"crazy_hip_loaded" if loaded else &"crazy_hip"))
		12:
			origin = pos
			pace = s.skaters[0].speed
			ctx.input.tap(&"check")
			ctx.input.tap(&"ability")
		13: dropped = s.puck.get("holder","") != "r0"
	if age > 12:
		peak = maxi(peak,int(s.hits.get("down",{}).get("r0",0)))
	if age == 144:
		rows.append({"pace":pace,"travel":pos.distance_to(origin),"down_with_rise":peak,"dropped":dropped,"hits":s.crazy.get("hip_checks",0),"ordinary":s.hits.by.b0})
		done = frame >= 300

## Finish after the last observation.
func _bot_done() -> bool:
	return done

## Return the verdict and the measurements that establish it.
func _bot_result() -> Dictionary:
	var ok: bool = done and rows[0].ordinary == 1 and rows[0].down_with_rise == 0 and rows[0].pace < 0.5
	for r in rows.slice(1):
		ok = ok and r.pace < 0.5 and r.hits == 1 and r.dropped and r.down_with_rise == 113 and absf(r.travel-3.0) <= 0.5
	return {"ok":ok,"summary":str(rows),"rows":rows}
