extends RefCounted
## The rule dial (H3), moved out of main.gd (its 600-line limit). Created by main.gd, no class_name; g = main.

## The rule dial (H3): T opens it once a period (the match pauses); A/D choose a dial, W/S move it one step for both
## teams and close it; T again closes it unchanged. Bots never open it. -> true while it is open (nothing else runs).
func tick(g) -> bool:
	var names: Array = g.tune["dial"]["names"]
	if not g.dial_open:
		if g.ctx.input.just_pressed(&"dial"):
			if g.dial_used.has(g.rules.period):
				g.dial_refused += 1
				g.rule_line = "One rule change a period: the next one in period %d" % (g.rules.period + 1)
			elif g.rules.is_running() and not g.frozen:
				g.dial_open = true
				g.dial_sel = 0
				g.rules.pause()
				return true
		return false
	if g.ctx.input.just_pressed(&"dial"):
		g.dial_open = false
		g.rules.resume()
		return false
	if g.ctx.input.just_pressed(&"left"):
		g.dial_sel = (g.dial_sel + names.size() - 1) % names.size()
	if g.ctx.input.just_pressed(&"right"):
		g.dial_sel = (g.dial_sel + 1) % names.size()
	var step: int = 0
	if g.ctx.input.just_pressed(&"up"):
		step = 1
	elif g.ctx.input.just_pressed(&"down"):
		step = -1
	if step != 0:
		var n: String = str(names[g.dial_sel])
		var now: int = clampi(int(g.dials[n]) + step, int(g.tune["dial"]["min"]), int(g.tune["dial"]["max"]))
		if now != int(g.dials[n]):
			g.dials[n] = now
			g.dial_used[g.rules.period] = "%s %+d" % [n, step]
			apply(g)
			g.rule_line = "Period %d: %s %s for both teams (now %+d)" % [g.rules.period, str(g.tune["dial"]["labels"][g.dial_sel]), "up" if step > 0 else "down", now]
		g.dial_open = false
		g.rules.resume()
	return g.dial_open


func text(g) -> String:
	if not g.dial_open:
		return ""
	var lines: Array = ["RULE DIAL"]
	var names: Array = g.tune["dial"]["names"]
	for i: int in names.size():
		lines.append("%s %s %+d" % [">" if i == g.dial_sel else " ", str(g.tune["dial"]["labels"][i]), int(g.dials[str(names[i])])])
	lines.append("A/D choose   W/S one step   T close")
	return "\n".join(lines)


## The dials act on both teams: skate speed, shot speed, ice grip (sideways grip), bot sharpness.
func apply(g) -> void:
	var per: Array = g.tune["dial"]["per_step"]
	var sk_speed: float = float(g.tune["skater"]["skate_speed"]) * (1.0 + float(per[0]) * int(g.dials["skate"]))
	var grip: float = float(g.tune["skater"]["skate_lateral_grip"]) * (1.0 + float(per[2]) * int(g.dials["grip"]))
	for id: String in g.order:
		g.api.base_speed[id] = sk_speed
		(g.skaters[id] as TLBiped).skate_lateral_grip = grip
	g.api.speed = float(g.tune["shoot"]["speed"]) * (1.0 + float(per[1]) * int(g.dials["shot"]))
	if g.brain != null:
		g.brain.sharpness = float(per[3]) * int(g.dials["sharpness"])
