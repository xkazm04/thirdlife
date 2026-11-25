extends SceneTree
# Lane H2 (25 Nov), item 3: a two-way probe for two drawing faults seen in last night's stills (E5c / E5e): corner bumpers
# drawn across the rounded boards, and #7 drawn climbing over a net. Is it the base's drawing, or does the core put the
# bodies there? The core side, from a whole match on the game's own cartridge (bots on both teams, the human's seat played by
# thirdjam's playerbot):
#   NET     every skater on every frame against the core's own net hull (UJamSim::CollideSkaterStatic: a box GoalLineX ..
#           GoalLineX + NetDepth deep, GoalWidthM wide, the skater's radius 0.4 kept out): how deep any body ever is inside it
#   BUMPER  every skater's and the puck's closest approach to each bumper's centre, against the disc the base draws
#           (rink_toys.gd: diameter = size, the core's contact JamSim.cpp:2265-2276: Size * 0.5 + R)
#   BOARDS  the bumper discs themselves against the rink's rounded rectangle (L x W, corner radius): how far each crosses
#           the boards (a cartridge can place them so; nothing refuses it)
#   godot --headless --path engine --script res://cores/rink/tools/rink_cage_probe.gd -- --cart=<file> [--seeds=1-3] [--level=pro]
# Prints CAGE lines; read-outs only (no PASS / FAIL: a probe).

const R := 0.4            # UJamSim::SkaterRadius (JamSim.h:494)
const NET_DEPTH := 1.5    # UJamSim::NetDepth (JamSim.h:506)


func _init() -> void:
	var cart_path := ""
	var s0 := 1
	var s1 := 3
	var level := "pro"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cart="): cart_path = a.substr(7)
		if a.begins_with("--level="): level = a.substr(8)
		if a.begins_with("--seeds="):
			var p: PackedStringArray = a.substr(8).split("-")
			s0 = int(p[0]); s1 = int(p[p.size() - 1])
	var text := FileAccess.get_file_as_string(cart_path)
	if text.is_empty():
		print("CAGE could not read %s" % cart_path); quit(2); return
	var cart: Dictionary = JSON.parse_string(text)
	var rk: Dictionary = cart["game"]["rink"]
	var L := float(rk.get("length_m", 61.0))
	var W := float(rk.get("width_m", 26.0))
	var cr := float(rk.get("corner_radius_m", 5.0))
	var gw := float(rk.get("goal_width_m", 4.0))
	var gl := L * 0.5 - 4.0
	var bumpers: Array = (rk.get("obstacles", []) as Array).filter(func(o: Dictionary) -> bool: return String(o.get("kind", "")) in ["bumper", "pillar"])
	print("CAGE rink %.1f x %.1f, corner %.1f, goal line %.2f, goal width %.1f, %d round obstacles" % [L, W, cr, gl, gw, bumpers.size()])
	# BOARDS: each disc against the rounded rectangle (64 points on its rim)
	for o: Dictionary in bumpers:
		var c := Vector2(float(o["x"]), float(o["z"]))
		var r := float(o["size"]) * 0.5
		var worst := 0.0
		for i in 64:
			var p := c + Vector2(cos(TAU * i / 64.0), sin(TAU * i / 64.0)) * r
			worst = maxf(worst, _outside(p, L * 0.5, W * 0.5, cr))
		print("CAGE BOARDS %s at (%.2f, %.2f) d %.1f: crosses the boards by %.2f m" % [o["kind"], c.x, c.y, r * 2.0, worst])
	var net_worst := 0.0
	var net_where := ""
	var net_frames := 0
	var near: Array = []
	var near_puck: Array = []
	for o in bumpers:
		near.append(1e9); near_puck.append(1e9)
	var frames := 0
	for seed in range(s0, s1 + 1):
		var core: Object = ClassDB.instantiate("RinkCore")
		var err: String = core.call("load_cartridge", text)
		if err != "":
			print("CAGE the core refuses the cartridge: %s" % err); quit(1); return
		core.call("set_difficulty", level)
		core.call("set_human_mode", "playerbot")
		core.call("reset", seed)
		while core.call("step"):
			frames += 1
			var s: Dictionary = core.call("snapshot")
			var any := false
			for k: Dictionary in s["Skaters"]:
				if bool(k["InBox"]): continue
				var p: Vector2 = k["Pos"]
				for side in [-1.0, 1.0]:
					var x0: float = gl if side > 0 else -gl - NET_DEPTH
					var x1: float = gl + NET_DEPTH if side > 0 else -gl
					var dx := maxf(maxf(x0 - p.x, p.x - x1), 0.0)
					var dy := maxf(maxf(-gw * 0.5 - p.y, p.y - gw * 0.5), 0.0)
					var out := Vector2(dx, dy).length()
					var inside := 0.0
					if dx == 0.0 and dy == 0.0:
						inside = R + minf(minf(p.x - x0, x1 - p.x), minf(p.y + gw * 0.5, gw * 0.5 - p.y))
					else:
						inside = R - out
					if inside > 0.02:
						any = true
						if inside > net_worst:
							net_worst = inside
							net_where = "seed %d frame %d skater %d at (%.2f, %.2f)%s" % [seed, int(s["Frame"]), int(k["Index"]), p.x, p.y, " (down)" if bool(k["IsDown"]) else ""]
				for i in bumpers.size():
					var c := Vector2(float(bumpers[i]["x"]), float(bumpers[i]["z"]))
					near[i] = minf(near[i], p.distance_to(c))
			var pk: Vector2 = s["Puck"]["Pos"]
			for i in bumpers.size():
				near_puck[i] = minf(near_puck[i], pk.distance_to(Vector2(float(bumpers[i]["x"]), float(bumpers[i]["z"]))))
			if any: net_frames += 1
	print("CAGE NET %d frames, %d with a body more than 2 cm inside a net hull (body radius counted); deepest %.3f m: %s" % [frames, net_frames, net_worst, net_where if net_where != "" else "none"])
	for i in bumpers.size():
		var r := float(bumpers[i]["size"]) * 0.5
		print("CAGE BUMPER %d drawn radius %.2f: closest skater centre %.3f m (core contact radius %.2f + 0.40), closest puck %.3f m" % [i, r, near[i], r, near_puck[i]])
	quit(0)


## How far a point lies outside the rink's rounded rectangle (0 inside).
static func _outside(p: Vector2, hx: float, hz: float, cr: float) -> float:
	var qx := absf(p.x) - (hx - cr)
	var qz := absf(p.y) - (hz - cr)
	if qx > 0.0 and qz > 0.0:
		return maxf(0.0, Vector2(qx, qz).length() - cr)
	return maxf(0.0, maxf(absf(p.x) - hx, absf(p.y) - hz))
