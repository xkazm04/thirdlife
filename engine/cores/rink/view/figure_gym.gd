extends Node3D
## The figure gym on the REAL core (hockey campaign, lane K2, round 2): the rink core steps a match from a scripted
## hand (cores/rink/view/gym_hand.json), thirdjam's pawn (skater_pawn.gd) turns the human's state into the figure's
## calls, and the figure (engine/rigs/skater, TLRigSkater) shows them. It counts frames, never a clock. Headless for
## the numbers, windowed for pictures:
##   godot --headless --path engine res://cores/rink/view/figure_gym.tscn -- --out=<dir> [--oracle=<oracle.json>]
##   godot --path engine --position 0,1440 --resolution 1280x720 res://cores/rink/view/figure_gym.tscn -- --out=<dir> --stills=three:3
## Args after `--`:
##   --hand=<file>     the scripted hand (default res://cores/rink/view/gym_hand.json)
##   --out=<dir>       calls.json (per frame: the pawn's place and the figure's calls: the input of
##                     tools/skater/driver_oracle.py, which gives the same calls to thirdjam's own figure in Unreal),
##                     ours.json (per frame: where our figure's bones stand, its driver's variables, the defect measures)
##   --oracle=<file>   thirdjam's own figure's answer to calls.json (oracle.json): compared point by point, frame by frame
##   --stills=cam:every[,cam:every]   PNG stills <cam>_f<frame>.png, the oracle's cameras (side | three | front | back)
##   --still_frames=a,b,c   stills of these frames only
##   --puck=1          the head turns to the core's puck (off by default: the oracle's world has no puck)
##   --every_call=1    calls.json carries every call the pawn made. By default the calls the figure has not ported yet
##                     (TLRigSkater.NOT_PORTED_CALLS) are left out of calls.json and counted in the report, so that
##                     thirdjam's own figure is not shown takes ours cannot answer yet
##   --warm=N          the figure is ticked N times before the first call, as thirdjam's stands in the oracle's world
##                     before its first call (default 0; 240 with --oracle)
##   --all=1           every skater of the match gets a pawn and a figure (ten on the regular cartridge), with the
##                     cost of a frame's calls and ticks (--frames=N to stop early)
##   --break=sink|pop|stretch|cross   a deliberate fault in the figure, to show the defect tests red: the body 3 cm
##                     under the ice; one foreign pose every 150 frames; the right forearm 2 cm longer; the stick
##                     turned 20 degrees about its grip
##   --team2v2=0       keep the cartridge's five a side (default: trimmed to two a side, the schema's least)
## The other skaters play (the core has no mode without bots yet): the report says how near any came and whether the
## human was touched. Prints `tl.skater.figure_gym/1 {...}` last; exit 0 only if every frame ran (and, with --oracle,
## the two figures agree within the tolerances below).

const PAWN := preload("res://cores/rink/view/skater_pawn.gd")
const DEFECTS := preload("res://rigs/skater/review/skater_defects.gd")
const CAMS: Dictionary = {      # [forward, right, up] m of the eye, of the target, field of view: rigs/skater/gym/skater_gym.gd
	"side": [[0.45, 4.6, 1.0], [0.45, 0.0, 0.8], 30.0],
	"three": [[3.6, 2.8, 1.5], [0.35, 0.0, 0.8], 30.0],
	"front": [[5.0, 0.0, 1.0], [0.0, 0.0, 0.8], 30.0],
	"back": [[-3.6, -2.4, 2.0], [0.4, 0.0, 0.8], 30.0],
	"wide": [[-17.0, 0.0, 13.0], [3.0, 0.0, 0.0], 55.0],      # the gym's own: the ice round him (ten skaters), the whole frame
}
const POINTS: Array = ["pelvis", "head", "hand_l", "hand_r", "foot_l", "foot_r", "stick_socket", "puck_socket", "head_socket", "spine_03", "calf_l", "calf_r"]
## Tolerances against thirdjam's own figure (the oracle), centimetres: the worst point of any frame, and the share of
## frames a point may stand further than NEAR_CM.
const ORACLE_WORST_CM: float = 6.0
const NEAR_CM: float = 1.0
const NEAR_SHARE: float = 0.97
## thirdjam's jersey numbers (S/JamGame/Private/HokejGameMode.cpp:439-444)
const NUMBERS: Array = [[7, 13, 42], [9, 21, 88]]

var args: Dictionary = {}
var report: Dictionary = {"schema": "tl.skater.figure_gym/1", "ok": false}
var cam: Camera3D


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("style"):
		TLStyle.load_style(String(args["style"]))
	TLStyle.install(self, {})
	add_child(TLKit.build("ground_patch", {"size_x": 120.0, "size_z": 60.0, "surface": "ice", "thickness": 0.3}))
	cam = Camera3D.new()
	cam.far = 500.0
	add_child(cam)
	cam.make_current()
	_run.call_deferred()


func _jersey(t: int, slot: int) -> int:
	return int(NUMBERS[t][slot]) if slot < 3 and t < 2 else clampi(t * 10 + slot + 1, 0, 99)


func _run() -> void:
	var hand: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(String(args.get("hand", "res://cores/rink/view/gym_hand.json"))))
	var cart: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://packs/hokej/data/hockey.regular.cartridge.json"))
	var teams: Array = cart["game"]["teams"]
	if String(args.get("team2v2", "1")) != "0" and not args.has("all"):
		teams[0]["skaters"] = (teams[0]["skaters"] as Array).slice(0, 2)
		teams[1]["skaters"] = (teams[1]["skaters"] as Array).slice(0, 2)
	if not ClassDB.class_exists("RinkCore"):
		_done("the rink core is not loaded (RinkCore): build it and list res://cores/rink/rink_core.gdextension in .godot/extension_list.cfg")
		return
	var core: RefCounted = ClassDB.instantiate("RinkCore")
	var err: String = core.call("load_cartridge", JSON.stringify(cart))
	if err != "":
		_done("cartridge: " + err)
		return
	core.call("set_difficulty", String(args.get("difficulty", String(hand.get("difficulty", "rookie")))))
	core.call("set_human_mode", "input")
	core.call("reset", int(args.get("seed", str(int(hand.get("seed", 1))))))
	# the frames of the hand
	var inputs: Array = []
	var seg_at: Array = []
	for seg: Dictionary in hand["segments"]:
		var n: int = int(seg["n"])
		for i: int in range(n):
			inputs.append([seg, float(i) / float(maxi(n - 1, 1))])
			seg_at.append(String(seg.get("name", "")))
	var frames: int = mini(inputs.size(), int(args.get("frames", str(inputs.size()))))
	var all: bool = args.has("all")
	var pawns: Array = []
	var figures: Array = []
	var human: int = -1
	var stills: Array = []
	for s: String in String(args.get("stills", "")).split(",", false):
		stills.append([s.split(":")[0], int(s.split(":")[1])])
	var still_frames: Array = []        # --still_frames=a,b,c: only these frames (the `every` of --stills is then not used)
	for s: String in String(args.get("still_frames", "")).split(",", false):
		still_frames.append(int(s))
	var out: String = String(args.get("out", "")).trim_suffix("/")
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
	var call_rows: Array = []
	var our_rows: Array = []
	var last_yaw: float = 0.0
	var min_other: float = INF
	var touched: int = 0
	var cost_us: int = 0
	var blade_lo: float = INF
	var blade_hi: float = -INF
	var skate_lo: float = INF
	var done: int = 0
	var defects: RefCounted = DEFECTS.new()
	var defect_rows: Array = []
	var settle_until: int = 30
	var brk: String = String(args.get("break", ""))
	var dropped: Dictionary = {}
	var warm: int = int(args.get("warm", "240" if args.has("oracle") else "0"))
	for f: int in range(frames):
		var seg: Dictionary = inputs[f][0]
		var u: float = inputs[f][1]
		var inp: Dictionary = {}
		if seg.has("move"):
			inp["Move"] = Vector2(float(seg["move"][0]), float(seg["move"][1]))
		if seg.has("stick_rel_deg"):
			var a: Array = seg["stick_rel_deg"]
			var deg: float = float(a[0]) if a.size() == 1 else lerpf(float(a[0]), float(a[1]), u)
			var ln: float = 1.0
			if seg.has("stick_len"):
				ln = lerpf(float(seg["stick_len"][0]), float(seg["stick_len"][1]), u) if seg["stick_len"] is Array else float(seg["stick_len"])
			var fwd: Vector2 = Vector2(cos(last_yaw), sin(last_yaw))
			var right: Vector2 = Vector2(-sin(last_yaw), cos(last_yaw))
			inp["Stick"] = (fwd * cos(deg_to_rad(deg)) - right * sin(deg_to_rad(deg))) * ln
		if bool(seg.get("sprint", false)):
			inp["bSprint"] = true
		if bool(seg.get("brake", false)):
			inp["bBrake"] = true
		core.call("set_human_input", inp)
		core.call("step")
		var snap: Dictionary = core.call("snapshot")
		var sk: Array = snap["Skaters"]
		if pawns.is_empty():
			human = int(snap["HumanIndex"])
			var slot_in_team: Dictionary = {}
			for i: int in range(sk.size()):
				if not all and i != human:
					continue
				var t: int = int(sk[i]["Team"])
				var slot: int = int(slot_in_team.get(t, 0))
				slot_in_team[t] = slot + 1
				var fig: TLRigSkater = TLRigSkater.new()
				fig.setup({"team": t})
				fig.set_human(i == human)
				fig.set_no_game_mode(args.has("oracle"))       # the oracle's world has no thirdjam game mode
				if i == human:
					match brk:
						"sink": fig.debug_sink_m = 0.03
						"stretch": fig.debug_stretch_m = 0.02
						"cross": fig.debug_stick_yaw_deg = 20.0
				var pawn: Node3D = PAWN.new()
				add_child(pawn)
				pawn.add_child(fig)
				pawn.set("record", i == human)
				var hex: Color = Color(String(teams[t]["colour_hex"]))
				if i == human:
					for _k: int in range(warm):
						fig.tick()
				pawn.call("init_skater", i, t, hex.srgb_to_linear(), _jersey(t, slot), fig)
				pawns.append([i, pawn, fig])
		var hs: Dictionary = sk[human]
		var t0: int = Time.get_ticks_usec()
		var first_calls: Array = []
		for row: Array in pawns:
			var s: Dictionary = sk[int(row[0])]
			var pawn: Node3D = row[1]
			var fig: TLRigSkater = row[2]
			if int(row[0]) == human and f == 0:
				first_calls = (pawn.get("calls") as Array).duplicate(true)      # SetTeam, SetNumber, SetHasPuck, SetBoost of init_skater
			pawn.call("apply_sim_frame", s, int(snap["Frame"]))
			pawn.call("apply_render", s, 1.0)
			if args.has("puck") and int(row[0]) == human:
				var rel: Vector2 = (snap["Puck"]["Pos"] as Vector2) - (s["Pos"] as Vector2)
				var yaw: float = float(s["Yaw"])
				fig.set_puck(Vector2(rel.dot(Vector2(cos(yaw), sin(yaw))), rel.dot(Vector2(-sin(yaw), cos(yaw)))))
			fig.tick()
		cost_us += Time.get_ticks_usec() - t0
		last_yaw = float(hs["Yaw"])
		for i: int in range(sk.size()):
			if i != human:
				min_other = minf(min_other, ((sk[i]["Pos"] as Vector2) - (hs["Pos"] as Vector2)).length())
		if bool(hs["bBumpThisFrame"]) or int(hs["KnockFrames"]) > 0 or int(hs["StumbleFrames"]) > 0:
			touched += 1
		var hp: Node3D = null
		var hf: TLRigSkater = null
		for row: Array in pawns:
			if int(row[0]) == human:
				hp = row[1]
				hf = row[2]
		var calls: Array = []
		for c: Array in first_calls + (hp.get("calls") as Array):
			if args.has("every_call") or not TLRigSkater.NOT_PORTED_CALLS.has(String(c[0])):
				calls.append(c)
			else:
				dropped[String(c[0])] = int(dropped.get(String(c[0]), 0)) + 1
		call_rows.append({"f": f, "seg": seg_at[f], "pos": [(hs["Pos"] as Vector2).x, (hs["Pos"] as Vector2).y], "yaw": float(hs["Yaw"]), "calls": _plain(calls)})
		var row_o: Dictionary = {"f": f, "seg": seg_at[f], "speed": snappedf((hs["Vel"] as Vector2).length(), 0.001), "has_puck": bool(hs["bHasPuck"])}
		for p: String in POINTS:
			var v: Vector3 = hf.point_ue(p)
			row_o[p] = [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]
		var an: TLRigSkaterAnim = hf.anim
		row_o["v"] = {"AimAngle": snappedf(hf.AimAngle, 0.001), "AimReach": snappedf(hf.AimReach, 0.0001), "AimW": snappedf(hf.AimW, 0.0001), "AimOffA": snappedf(hf.AimOffA, 0.001),
			"AimOffR": snappedf(hf.AimOffR, 0.0001), "AimOver": snappedf(hf.AimOver, 0.001), "StickCorr": snappedf(hf.StickCorr, 0.001), "BladeH": snappedf(hf.BladeH, 0.001),
			"FixW": snappedf(hf.FixW, 0.001), "bStop": hf.bStop, "ActPri": hf.ActPri, "DecE": snappedf(hf.DecE, 0.001), "LookYaw": snappedf(hf.LookYaw, 0.001),
			"state": TLRigSkaterAnim.STATE_NAMES[an.state], "montages": an.montages.size()}
		# the defect measures of the frame
		if brk == "pop" and f % 150 == 149:
			hf.pose_at(&"Fall", 20.0)          # one frame of a foreign pose; the next call returns to the driver
		var no_take: bool = not an.is_any_montage_playing() and an.bStLoco and float(an._loco_list.w[0]) >= 0.999 and an.state <= TLRigSkaterAnim.SKATE and an.transitions.is_empty()
		var drow: Dictionary = defects.call("measure", hf, no_take and hf.AimW >= 0.99 and hf.FixW >= 0.99 and f > settle_until, no_take)
		drow["f"] = f
		if not no_take or hf.AimW < 0.99:
			settle_until = f + 30              # the stick settles on the ice over the half second after a take or a stance
		defect_rows.append(drow)
		row_o["d"] = drow
		our_rows.append(row_o)
		for st: Array in stills:
			var wanted: bool = f % int(st[1]) == 0 if still_frames.is_empty() else still_frames.has(f)
			if wanted and out != "" and DisplayServer.get_name() != "headless":
				_cam_to(hp, String(st[0]))
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var img: Image = get_viewport().get_texture().get_image()
				img.convert(Image.FORMAT_RGB8)
				var h: int = img.get_height()
				if String(st[0]) != "wide":
					img = img.get_region(Rect2i((img.get_width() - h) / 2, 0, h, h))
				img.save_png("%s/%s_f%04d.png" % [out, st[0], f])
		done += 1
	report["frames_asked"] = frames
	report["frames_done"] = done
	report["skaters"] = pawns.size()
	report["human"] = human
	report["nearest_other_m"] = snappedf(min_other, 0.01)
	report["frames_touched"] = touched
	report["cost_us_per_frame_all_figures"] = snappedf(float(cost_us) / float(maxi(done, 1)), 0.1)
	var hfig: TLRigSkater = null
	for row: Array in pawns:
		if int(row[0]) == human:
			hfig = row[2]
	report["not_ported_calls"] = hfig.not_ported if hfig != null else {}
	report["calls_left_out_of_calls_json"] = dropped
	report["warm_ticks"] = warm
	report["not_ported_graph"] = hfig.anim.not_ported if hfig != null else {}
	if out != "":
		_write(out + "/calls.json", {"schema": "tl.skater.calls/1", "hand": String(args.get("hand", "res://cores/rink/view/gym_hand.json")), "frames": call_rows})
		_write(out + "/ours.json", {"schema": "tl.skater.ours/1", "units": "centimetres in the actor's frame, Unreal's axes (x forward, y right, z up)", "frames": our_rows})
	var verdict: Dictionary = DEFECTS.judge(defect_rows)
	report["defects"] = verdict
	var why: String = "" if done == frames and frames > 0 else "%d of %d frames" % [done, frames]
	# the defect gate holds the default run (the whole hand, the human alone drawn, thirdjam's game around the figure)
	if why == "" and not all and not args.has("frames") and not args.has("seed") and not args.has("hand") and not args.has("puck"):
		var broken: String = DEFECTS.gate(verdict, DEFECTS.GYM_ALLOWED_ORACLE if args.has("oracle") else DEFECTS.GYM_ALLOWED)
		report["defect_gate"] = "parity (skater_defects.gd %s)" % ("GYM_ALLOWED_ORACLE" if args.has("oracle") else "GYM_ALLOWED")
		if broken != "":
			why = "defects: " + broken
	if args.has("oracle") and why == "":
		why = _compare(our_rows, String(args["oracle"]))
	_done(why)


## JSON-plain copies of the calls' arguments (a Color becomes [r, g, b], a StringName a String).
func _plain(calls: Array) -> Array:
	var out: Array = []
	for c: Array in calls:
		var a: Array = []
		for v: Variant in c[1] as Array:
			if v is Color:
				a.append([(v as Color).r, (v as Color).g, (v as Color).b])
			elif v is StringName:
				a.append(String(v))
			else:
				a.append(v)
		out.append([c[0], a])
	return out


func _write(path: String, data: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func _cam_to(pawn: Node3D, which: String) -> void:
	var c: Array = CAMS.get(which, CAMS["three"])
	cam.fov = float(c[2])
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	var e: Array = c[0]
	var t: Array = c[1]
	# [forward, right, up] in the pawn's frame: the figure faces -Z of the pawn, its right is +X
	cam.look_at_from_position(pawn.global_transform * Vector3(float(e[1]), float(e[2]), -float(e[0])), pawn.global_transform * Vector3(float(t[1]), float(t[2]), -float(t[0])), Vector3.UP)


## Ours against thirdjam's own figure, the same frame, the same points (centimetres).
func _compare(ours: Array, path: String) -> String:
	var o: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (o is Dictionary) or not (o as Dictionary).has("frames"):
		return "no oracle at " + path
	var theirs: Array = o["frames"]
	if (o as Dictionary).has("points"):
		# the tracked golden: a frame is one flat row, three numbers a point in the order of "points"
		var names: Array = o["points"]
		var rows: Array = []
		for flat: Array in theirs:
			var d: Dictionary = {}
			for i: int in range(names.size()):
				d[String(names[i])] = [flat[i * 3], flat[i * 3 + 1], flat[i * 3 + 2]]
			rows.append(d)
		theirs = rows
	var n: int = mini(ours.size(), theirs.size())
	var worst: float = 0.0
	var worst_at: String = ""
	var near: int = 0
	var by_point: Dictionary = {}
	var by_seg: Dictionary = {}
	for f: int in range(n):
		var frame_worst: float = 0.0
		for p: String in POINTS:
			if not (theirs[f] as Dictionary).has(p):
				continue
			var a: Array = ours[f][p]
			var b: Array = theirs[f][p]
			var d: float = Vector3(float(a[0]) - float(b[0]), float(a[1]) - float(b[1]), float(a[2]) - float(b[2])).length()
			frame_worst = maxf(frame_worst, d)
			by_point[p] = maxf(float(by_point.get(p, 0.0)), d)
			if d > worst:
				worst = d
				worst_at = "frame %d (%s) %s" % [f, ours[f]["seg"], p]
		if frame_worst <= NEAR_CM:
			near += 1
		var sg: String = String(ours[f]["seg"])
		by_seg[sg] = maxf(float(by_seg.get(sg, 0.0)), frame_worst)
	for k: String in by_point.keys():
		by_point[k] = snappedf(float(by_point[k]), 0.01)
	for k: String in by_seg.keys():
		by_seg[k] = snappedf(float(by_seg[k]), 0.01)
	report["oracle"] = {"frames_compared": n, "frames_ours": ours.size(), "frames_theirs": theirs.size(), "worst_cm": snappedf(worst, 0.01), "worst_at": worst_at,
		"frames_within_%.1f_cm" % NEAR_CM: near, "share_within": snappedf(float(near) / float(maxi(n, 1)), 0.0001),
		"worst_cm_by_point": by_point, "worst_cm_by_segment": by_seg, "tolerance_worst_cm": ORACLE_WORST_CM, "tolerance_share": NEAR_SHARE}
	if n != ours.size() or n != theirs.size():
		return "the oracle has %d frames, ours %d" % [theirs.size(), ours.size()]
	if worst > ORACLE_WORST_CM or float(near) / float(maxi(n, 1)) < NEAR_SHARE:
		return "ours and thirdjam's figure differ: worst %.2f cm at %s, %d of %d frames within %.1f cm" % [worst, worst_at, near, n, NEAR_CM]
	return ""


func _done(err: String) -> void:
	report["ok"] = err == ""
	if err != "":
		report["error"] = err
	print("%s skater figure gym" % ("PASS" if err == "" else "FAIL"))
	print("tl.skater.figure_gym/1 " + JSON.stringify(report))
	get_tree().quit(0 if err == "" else 1)
