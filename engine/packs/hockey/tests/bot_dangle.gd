extends "rink_bot.gd"
## Enter the turn on an edge, then cut hard across it. The straight control keeps Shift down.

var row := 0
var start := -1
var peak := 0.0
var loss := -1
var lost_by := ""
var kept := true
var rows := []

func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	if start < 0:
		ctx.input.tap(&"drill_dangle_lane")
		start = frame
		peak = 0
		loss = -1
		kept = true
	var age := frame - start
	var heading := 0.0
	if row != 2 and age >= 65:
		heading = 90.0 if age < 93 else 155.0
	var dir := Vector2.RIGHT.rotated(deg_to_rad(heading))
	var throttle := 0.62 if row == 0 else 1.0
	ctx.input.set_axis(&"left", &"right", dir.x * throttle)
	ctx.input.set_axis(&"up", &"down", dir.y * throttle)
	if row == 0:
		ctx.input.release(&"sprint")
	else:
		ctx.input.press(&"sprint")
	if age > 0:
		kept = kept and s.puck.get("holder", "") == "b0"
		peak = maxf(peak, s.possession.get("dangle", 0.0))
		if loss < 0 and s.possession.get("last", {}).get("kind") == "lost":
			lost_by = s.possession.last.by
			loss = int(s.possession.last.frame) - start
	if age == 123:
		var ok := kept and peak > 0.1 and peak < 0.9 * 0.82
		if row == 1:
			ok = not kept and lost_by == "b0" and loss >= 93 and loss <= 123
		elif row == 2:
			ok = kept and peak < 0.01
		rows.append({"ok": ok, "peak": peak, "loss_after_cut": loss - 93 if loss >= 0 else -1, "kept": kept})
		row += 1
		start = -1
		done = row == 3

func _bot_result() -> Dictionary:
	return {"ok": done and rows.all(func(r): return r.ok), "summary": str(rows), "rows": rows}
