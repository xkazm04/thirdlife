extends SceneTree
## Headless checks of the hall's reactions (selftest block 843, lane K6 round 3):
##   godot --headless --path engine --script res://cores/rink/arena/review/react_case.gd
## One line a case, `REACT <case> ok=true|false <detail>`:
##   curves   thirdjam's own pure-curve tests (RinkReactionTests.cpp:113-119, 319-322) and BP_ArenaCrowd's measured cheer
##            (status/AR13-report.md: the scalar at 15 frames after a goal)
##   caps     Build's stanchion walk gives 73 caps whose places and yaws are the baked instances' (1 mm, 0.05 degrees)
##   goal     a goal at -x: the table's lamp and the -x lamp at 9 on the goal's frame, the +x lamp at rest; the -x net
##            bulges on the goal's frame and is deepest within 2 frames, under 15 %; a cap behind the -x goal line hops on
##            the goal's frame; the crowd's -x end rises; everything at rest by frame 120 (RinkReactionTests.cpp:229-281)
##   tj       thirdjam's own log of a played match (review/tj_react_regular_pro.json, 13,620 frames): its goal and board
##            events through these reactions give every JAMRINK react line it logged: the cap, its tilt and hop, the
##            distance, the rattled piece and its roll, the scored end
## TL_REACT_CAP_DEG overrides the caps' 26 degrees (to show `tj` red).

const React := preload("res://cores/rink/arena/rink_react.gd")
const Arena := preload("res://cores/rink/arena/rink_arena.gd")

var rink: Dictionary
var hall: Node


func _init() -> void:
	rink = (JSON.parse_string(FileAccess.get_file_as_string("res://packs/hokej/data/hockey.regular.cartridge.json")) as Dictionary)["game"]["rink"]
	hall = (load("res://cores/rink/arena/arena.scn") as PackedScene).instantiate()
	_curves()
	_caps()
	_goal()
	_tj()
	hall.free()
	quit(0)


func _say(name: String, bad: PackedStringArray, detail: String) -> void:
	print("REACT %s ok=%s %s%s" % [name, str(bad.is_empty()), detail, "" if bad.is_empty() else " " + "; ".join(bad.slice(0, 6))])


func _new() -> RefCounted:
	return React.new(hall, rink, Arena.table(), false)


func _curves() -> void:
	var bad: PackedStringArray = []
	if React.lamp_at(0) != 1.0: bad.append("LampAt(0) %f" % React.lamp_at(0))
	if not React.lamp_at(2) > 0.9: bad.append("LampAt(2) %f" % React.lamp_at(2))
	if React.lamp_at(-1) != 0.0: bad.append("LampAt(-1)")
	if React.lamp_at(React.LAMP_FLASH_FRAMES) != 0.0: bad.append("LampAt(108)")
	for f: int in React.LAMP_FLASH_FRAMES:
		if React.lamp_at(f) <= 0.0:
			bad.append("the lamp is dark inside its flash at %d" % f)
			break
	if React.net_shake_at(React.NET_SHAKE_FRAMES) != 0.0: bad.append("NetShakeAt(54)")
	if React.rattle_at(0, 1.0) != 1.0: bad.append("RattleAt(0, 1)")
	if React.rattle_at(0, 0.5) != 0.5: bad.append("RattleAt(0, 0.5)")
	if React.rattle_at(0, 1.6) != 1.0: bad.append("RattleAt(0, 1.6)")
	if React.rattle_at(React.RATTLE_FRAMES, 1.0) != 0.0: bad.append("RattleAt(18)")
	if React.cap_rock_at(0, 1.0) != 1.0 or React.cap_rock_at(React.CAP_ROCK_FRAMES, 1.0) != 0.0: bad.append("CapRockAt")
	# BP_ArenaCrowd, read every tick from the real Blueprint after a goal (AR13-report.md section 1)
	var tj: Dictionary = {1: 0.036, 2: 0.071, 4: 0.143, 8: 0.286, 14: 0.5, 20: 0.714, 28: 1.0, 60: 1.0, 88: 1.0, 96: 0.6, 100: 0.4, 104: 0.2, 107: 0.05, 108: 0.0, 130: 0.0}
	for f: int in tj:
		if absf(React.cheer_at(f) - float(tj[f])) > 0.0006:
			bad.append("cheer at %d: %.4f, thirdjam %.3f" % [f, React.cheer_at(f), tj[f]])
	_say("curves", bad, "lamp_2=%.3f net_1=%.3f cheer_14=%.3f" % [React.lamp_at(2), React.net_shake_at(1), React.cheer_at(14)])


func _caps() -> void:
	var bad: PackedStringArray = []
	var r: RefCounted = _new()
	var n: int = r.cap_at.size()
	if n != 73:
		bad.append("%d caps, thirdjam's log says 73" % n)
	var worst_m: float = 0.0
	var worst_deg: float = 0.0
	for k: int in n:
		var t: Transform3D = r.cap_rest[k]
		var at: Vector2 = r.cap_at[k]
		worst_m = maxf(worst_m, Vector2(t.origin.x, t.origin.z).distance_to(at) + absf(t.origin.y - React.BOARD_HEIGHT_M))
		var bx: Vector3 = t.basis.x
		var yaw_baked: float = rad_to_deg(atan2(bx.z, bx.x))
		worst_deg = maxf(worst_deg, absf(wrapf(yaw_baked - float(r.cap_yaw_deg[k]), -180.0, 180.0)))
	if worst_m > 0.001:
		bad.append("a cap stands %.4f m from Build's place" % worst_m)
	if worst_deg > 0.05:
		bad.append("a cap's yaw is %.3f degrees off Build's" % worst_deg)
	var halves: Array = [0, 0]
	for k: int in n:
		halves[r.cap_side[k]] += 1
	_say("caps", bad, "caps=%d halves=%d+%d worst_m=%.5f worst_deg=%.4f" % [n, halves[0], halves[1], worst_m, worst_deg])


func _goal() -> void:
	var bad: PackedStringArray = []
	var r: RefCounted = _new()
	var g: int = 600
	for f: int in range(0, g):
		r.frame({"Frame": f, "Events": []})
	if r.lamp_now[0] != React.LAMP_TRIM_REST: bad.append("the table's lamp off rest before the goal")
	r.frame({"Frame": g, "Events": [{"Name": "goal", "Kind": "", "Where": Vector2(-41.2, 0.1), "Strength": 1.0}]})
	if not is_equal_approx(float(r.lamp_now[0]), React.LAMP_TRIM_PEAK) or not is_equal_approx(float(r.lamp_now[1]), React.LAMP_TRIM_PEAK):
		bad.append("goal frame: lamps %s" % str(r.lamp_now))
	if float(r.lamp_now[2]) != React.LAMP_TRIM_REST: bad.append("the +x lamp moved")
	var first_net: float = absf((r.net_scale[0] as Vector2).x - 1.0)
	if first_net <= 0.0: bad.append("the net is still on the goal's frame")
	var hop0: bool = false
	for k: int in r.cap_at.size():
		if (r.cap_at[k] as Vector2).x < -r.goal_line_x and r.cap_hop(k) > 0.0:
			hop0 = true
	if not hop0: bad.append("no cap behind the -x goal line hops on the goal's frame")
	var deep: float = first_net
	var deep_at: int = 0
	var cheer_1: float = 0.0
	for f: int in range(g + 1, g + 121):
		r.frame({"Frame": f, "Events": []})
		var d: float = absf((r.net_scale[0] as Vector2).x - 1.0)
		if d > deep:
			deep = d
			deep_at = f - g
		if f == g + 1:
			cheer_1 = r.cheer_now.y
	if deep_at > 2: bad.append("the net is deepest %d frames in" % deep_at)
	if deep <= 0.05 or deep >= 0.15: bad.append("the deepest wobble %.3f" % deep)
	if r.lamp_now[0] != React.LAMP_TRIM_REST or r.lamp_now[1] != React.LAMP_TRIM_REST: bad.append("a lamp is not back by frame 120")
	if r.net_scale[0] != Vector2.ONE: bad.append("the net is not still by frame 120")
	if not r.cap_now.is_empty(): bad.append("caps off rest at frame 120")
	if absf(cheer_1 - 1.0 / 28.0) > 1e-6 or r.cheer_now != Vector2.ZERO: bad.append("the -x crowd: %.3f at +1, %s at +120" % [cheer_1, str(r.cheer_now)])
	_say("goal", bad, "net_first=%.4f deepest=%.4f@%d cheer_1=%.4f" % [first_net, deep, deep_at, cheer_1])


func _tj() -> void:
	var bad: PackedStringArray = []
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://cores/rink/arena/review/tj_react_regular_pro.json"))
	var r: RefCounted = _new()
	var deg: float = float(OS.get_environment("TL_REACT_CAP_DEG")) if OS.get_environment("TL_REACT_CAP_DEG") != "" else React.CAP_ROCK_DEG
	var by_frame: Dictionary = {}
	for e: Array in d["events"]:
		if not by_frame.has(int(e[0])):
			by_frame[int(e[0])] = []
		(by_frame[int(e[0])] as Array).append(e)
	var want: Array = d["reacts"]
	var wi: int = 0
	var caps: int = 0
	var rattles: int = 0
	var goals: int = 0
	var worst_tilt: float = 0.0
	var worst_hop: float = 0.0
	var table: Array = []             # [frame, what, ours, thirdjam's log] (TL_REACT_TABLE)
	var t0: int = Time.get_ticks_usec()
	for f: int in range(0, int(d["frames"]) + 1):
		for e: Array in by_frame.get(f, []):
			var n_cap: int = r.cap_rock_reactions
			var n_rat: int = r.rattle_reactions
			var n_goal: int = r.goal_reactions
			r.react(str(e[1]), str(e[2]), Vector2(float(e[3]), float(e[4])), float(e[5]), f)
			for what: String in ["cap", "rattle", "goal"]:
				var grew: bool = (what == "cap" and r.cap_rock_reactions > n_cap) or (what == "rattle" and r.rattle_reactions > n_rat) or (what == "goal" and r.goal_reactions > n_goal)
				if not grew:
					continue
				if wi >= want.size() or int(want[wi]["frame"]) != f or str(want[wi]["what"]) != what:
					bad.append("%s at %d: thirdjam logged %s" % [what, f, JSON.stringify(want[wi]) if wi < want.size() else "nothing more"])
					wi += 1
					continue
				var w: Dictionary = want[wi]
				wi += 1
				match what:
					"cap": table.append([f, "cap", "cap %d, tilt %.2f deg, hop %.2f cm, %.3f m" % [r.last_cap_index, r.cap_tilt(r.last_cap_index), r.cap_hop(r.last_cap_index), r.last_cap_dist],
						"cap %d, tilt %.1f deg, hop %.1f cm, %.2f m" % [w["cap"], w["tilt"], w["hop"], w["dist"]]])
					"rattle": table.append([f, "rattle", "%s %.3f deg" % [React.RATTLE_GROUPS[r.rattle_index], r.rattle_deg], "%s %.2f deg" % [w["piece"], w["roll"]]])
					"goal": table.append([f, "goal", "end %s" % ("+x" if r.goal_end > 0 else "-x"), "end %s" % w["end"]])
				match what:
					"cap":
						caps += 1
						var tilt: float = r.cap_tilt(r.last_cap_index) * deg / React.CAP_ROCK_DEG
						worst_tilt = maxf(worst_tilt, absf(tilt - float(w["tilt"])))
						worst_hop = maxf(worst_hop, absf(r.cap_hop(r.last_cap_index) - float(w["hop"])))
						# the log's own precision: Strength printed to 0.001 (26 x 0.0005 = 0.013 degrees, 0.011 cm), tilt and hop
						# to 0.1 (0.05), the hit's place to 0.1 cm and the distance to 0.01 m (0.005 + 0.001)
						if r.last_cap_index != int(w["cap"]) or absf(tilt - float(w["tilt"])) > 0.064 or absf(r.cap_hop(r.last_cap_index) - float(w["hop"])) > 0.062 or absf(r.last_cap_dist - float(w["dist"])) > 0.0061:
							bad.append("frame %d: cap %d tilt %.1f hop %.1f at %.2f m; thirdjam cap %d tilt %.1f hop %.1f at %.2f m" % [f, r.last_cap_index, tilt,
								r.cap_hop(r.last_cap_index), r.last_cap_dist, w["cap"], w["tilt"], w["hop"], w["dist"]])
					"rattle":
						rattles += 1
						if React.RATTLE_GROUPS[r.rattle_index] != str(w["piece"]) or absf(r.rattle_deg - float(w["roll"])) > 0.0068:   # roll to 0.01 (0.005), Strength 0.001 x 3.5
							bad.append("frame %d: rattle %s %.2f; thirdjam %s %.2f" % [f, React.RATTLE_GROUPS[r.rattle_index], r.rattle_deg, w["piece"], w["roll"]])
					"goal":
						goals += 1
						if ("+x" if r.goal_end > 0 else "-x") != str(w["end"]):
							bad.append("goal at %d: end %d, thirdjam %s" % [f, r.goal_end, w["end"]])
		r.advance(f)
	var us: float = float(Time.get_ticks_usec() - t0) / float(int(d["frames"]) + 1)
	if wi != want.size():
		bad.append("%d of thirdjam's %d reactions answered" % [wi, want.size()])
	if OS.get_environment("TL_REACT_TABLE") != "":
		var fo := FileAccess.open(OS.get_environment("TL_REACT_TABLE"), FileAccess.WRITE)
		fo.store_string(JSON.stringify({"columns": ["frame", "what", "ours", "thirdjam"], "rows": table}))
		fo.close()
	_say("tj", bad, "frames=%d events=%d reactions=%d/%d caps=%d rattles=%d goals=%d worst_tilt=%.3f worst_hop=%.3f us_per_frame=%.1f" % [int(d["frames"]),
		(d["events"] as Array).size(), wi, want.size(), caps, rattles, goals, worst_tilt, worst_hop, us])
