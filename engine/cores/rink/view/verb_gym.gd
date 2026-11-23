extends Node3D
## The verb gym (hockey campaign, lane K2, rounds 3 and 4): a match segment of the REAL core, five a side with the bots
## playing, the human driven by a recorded raw hand (cores/rink/view/verbs.stream.json: what RinkCore.set_raw_input
## takes, one entry a frame, as K1's cores/rink/tools/rink_rawtrace.gd replays one). Every skater has thirdjam's pawn
## (skater_pawn.gd) and a figure (TLRigSkater), so every verb appears as the simulation produces it: the human's and
## the bots'. It counts frames, never a clock.
##   godot --headless --path engine res://cores/rink/view/verb_gym.tscn -- --out=<dir> [--oracle=<oracle.json>]
##   godot --path engine --position 0,1440 --resolution 1280x720 res://cores/rink/view/verb_gym.tscn -- --out=<dir> --stills=three:3
## Args after `--`:
##   --stream=<file>   the recorded hand (default res://cores/rink/view/verbs.stream.json: {seed, difficulty, frames})
##   --record=<file>   plays the gym's own scripted hand instead (it chases the puck and plays each verb in turn,
##                     reading the snapshot) and writes it as a stream file; --frames=N its length (default 1500)
##   --out=<dir>       calls.json (schema tl.skater.calls/2: per frame and skater the pawn's place and the figure's
##                     calls: the input of tools/skater/driver_oracle.py), ours.json (where our figures' bones stand)
##   --oracle=<file>   thirdjam's own figures' answer to calls.json: compared point by point, skater by skater
##   --stills=cam:every[,cam:every]  --who=<skater index>   PNG stills of one skater (default the human)
##   --every_call=1    calls.json keeps the calls the figure has not ported yet (default: left out and counted)
##   --warm=N          ticks of every figure before the first call (default 240 with --oracle: as the oracle's stand)
## Prints `tl.skater.verb_gym/1 {...}` last; exit 0 only if every frame ran (and, with --oracle, the figures agree).

const PAWN := preload("res://cores/rink/view/skater_pawn.gd")
const SHOW := preload("res://cores/rink/view/skater_show.gd")
const HITS := preload("res://cores/rink/view/hit_read.gd")
const DEFECTS := preload("res://rigs/skater/review/skater_defects.gd")
const CAMS: Dictionary = {      # [forward, right, up] m of the eye, of the target, field of view (figure_gym.gd)
	"side": [[0.45, 4.6, 1.0], [0.45, 0.0, 0.8], 30.0],
	"three": [[3.6, 2.8, 1.5], [0.35, 0.0, 0.8], 30.0],
	"front": [[5.0, 0.0, 1.0], [0.0, 0.0, 0.8], 30.0],
	"back": [[-3.6, -2.4, 2.0], [0.4, 0.0, 0.8], 30.0],
	"wide": [[-17.0, 0.0, 13.0], [3.0, 0.0, 0.0], 55.0],
}
const POINTS: Array = ["pelvis", "head", "hand_l", "hand_r", "foot_l", "foot_r", "stick_socket", "puck_socket", "head_socket", "spine_03", "calf_l", "calf_r"]
const ORACLE_WORST_CM: float = 6.0       # as figure_gym.gd: thirdjam's own figure answers a call on that tick or the next
const NEAR_CM: float = 1.0
const NEAR_SHARE: float = 0.97
const NUMBERS: Array = [[7, 13, 42], [9, 21, 88]]      # HokejGameMode.cpp:439-444
## The events of thirdjam's bus the Blueprint listens to ([OnBusEvent]); the ported ones go into calls.json.
const BUS_EVENTS: Array = ["knockdown", "check", "lift", "deke"]
const BUS_PORTED: Array = ["knockdown", "check", "lift", "deke"]
## One-frame flags and results counted per skater, to say which verbs the run holds.
const VERB_FLAGS: Array = ["bShotThisFrame", "bOneTimerThisFrame", "bPassThisFrame", "bSaucerThisFrame", "bCheckThisFrame", "bPokeThisFrame", "bLiftThisFrame", "bDekeThisFrame", "bSpinThisFrame",
	"bSweepThisFrame", "bBumpThisFrame", "bBoardHitThisFrame", "bRecoilThisFrame", "bFoulThisFrame"]

var args: Dictionary = {}
var report: Dictionary = {"schema": "tl.skater.verb_gym/1", "ok": false}
var cam: Camera3D
var _plays: int = 0
var _carry: int = 0
var _chases: int = 0
var _hold_until: int = -1
var _had: bool = false
var _press_at: int = -1000


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	TLStyle.install(self, {})
	add_child(TLKit.build("ground_patch", {"size_x": 120.0, "size_z": 60.0, "surface": "ice", "thickness": 0.3}))
	cam = Camera3D.new()
	cam.far = 500.0
	add_child(cam)
	cam.make_current()
	_run.call_deferred()


## The gym's scripted hand, one frame: what RinkCore.set_raw_input takes. It reads the last snapshot: with the puck it
## skates at the far goal and plays, possession by possession, a tap pass, a held pass, a tap shot, a charged shot, a
## deke and a pass, a spin and a shot, a half-charged shot; without it it chases the puck and, next to an opposing
## carrier, pokes, cross-checks, checks and holds the cross-check (90 frames: the brace) in turn; a mate's pass coming
## to him is shot first-time.
func _hand(f: int, s: Dictionary) -> Dictionary:
	var down: PackedStringArray = []
	var pressed: PackedStringArray = []
	var hi: int = int(s["HumanIndex"])
	var me: Dictionary = s["Skaters"][hi]
	var pos: Vector2 = me["Pos"]
	var yaw: float = float(me["Yaw"])
	var puck: Vector2 = s["Puck"]["Pos"]
	var carrier: int = int(s["Carrier"])
	var goal: Vector2 = Vector2(26.0, 0.0)
	var has: bool = carrier == hi
	if has and not _had:
		_plays += 1
		_carry = 0
	_had = has
	var target: Vector2 = puck
	var aim: Vector2 = puck
	if has:
		_carry += 1
		target = goal
		aim = goal
		var k: int = _plays % 7
		var c: int = _carry
		var lmb: bool = (k == 3 and c >= 20 and c < 22) or (k == 4 and c >= 12 and c < 40) or (k == 6 and c >= 40 and c < 42) or (k == 0 and c >= 15 and c < 27)
		var rmb: bool = (k == 1 and c >= 12 and c < 14) or (k == 2 and c >= 10 and c < 34) or (k == 5 and c >= 25 and c < 27)
		if lmb:
			down.append("LeftMouseButton")
			if (k == 3 and c == 20) or (k == 4 and c == 12) or (k == 6 and c == 40) or (k == 0 and c == 15):
				pressed.append("LeftMouseButton")
		if rmb:
			down.append("RightMouseButton")
			if (k == 1 and c == 12) or (k == 2 and c == 10) or (k == 5 and c == 25):
				pressed.append("RightMouseButton")
		if k == 5 and c == 8:
			pressed.append("MouseScrollUp")
			down.append("MouseScrollUp")
		if k == 6 and c == 8:
			pressed.append("E")
			down.append("E")
	else:
		var sk: Array = s["Skaters"]
		if carrier >= 0 and int(sk[carrier]["Team"]) != int(me["Team"]):
			target = sk[carrier]["Pos"]
			if f < _hold_until:
				down.append("LeftMouseButton")      # the cross-check held: the brace
			elif (target - pos).length() < 2.0 and f - _press_at >= 40:
				_press_at = f
				_chases += 1
				var key: String = ["SpaceBar", "LeftMouseButton", "RightMouseButton", "LeftMouseButton"][_chases % 4]
				pressed.append(key)
				down.append(key)
				if _chases % 4 == 3:
					_hold_until = f + 90
		elif carrier >= 0:
			target = (sk[carrier]["Pos"] as Vector2) + Vector2(6.0, 4.0 if pos.y > (sk[carrier]["Pos"] as Vector2).y else -4.0)
			aim = sk[carrier]["Pos"]
		elif int(s["Puck"]["LastTouch"]) >= 0 and int(s["Puck"]["LastTouch"]) != hi and int(sk[int(s["Puck"]["LastTouch"])]["Team"]) == int(me["Team"]) \
				and (puck - pos).length() < 4.0 and f - _press_at >= 40:
			_press_at = f
			pressed.append("LeftMouseButton")
			down.append("LeftMouseButton")
	var d: Vector2 = target - pos
	var dir: Vector2 = d.normalized() if d.length() > 0.2 else Vector2.ZERO
	if d.length() > 6.0:
		down.append("LeftShift")
	var fwd: Vector2 = Vector2(cos(yaw), sin(yaw))
	var right: Vector2 = Vector2(-sin(yaw), cos(yaw))
	var ad: Vector2 = (aim - pos).normalized() if (aim - pos).length() > 0.1 else fwd
	return {"Down": down, "Pressed": pressed, "Axis": Vector2(dir.dot(right), dir.dot(fwd)), "CameraYaw": yaw, "CursorOnIce": true,
		"CursorPx": Vector2(640.0 + 100.0 * sin(f * 0.05), 360.0), "CursorHitM": pos + ad * 2.2, "MouseDeltaPx": Vector2.ZERO, "StickAxis": Vector2.ZERO}


func _raw(e: Dictionary) -> Dictionary:
	var r: Dictionary = {}
	for k: String in e.keys():
		var v: Variant = e[k]
		if k == "Down" or k == "Pressed":
			r[k] = PackedStringArray(v as Array)
		elif v is Array and (v as Array).size() == 2:
			r[k] = Vector2(float(v[0]), float(v[1]))
		else:
			r[k] = v
	return r


func _run() -> void:
	if not ClassDB.class_exists("RinkCore"):
		_done("the rink core is not loaded (RinkCore)")
		return
	var recording: bool = args.has("record")
	var stream: Dictionary = {}
	if not recording:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(String(args.get("stream", "res://cores/rink/view/verbs.stream.json"))))
		if not (parsed is Dictionary):
			_done("no stream at " + String(args.get("stream", "res://cores/rink/view/verbs.stream.json")))
			return
		stream = parsed
	var cart: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://packs/hokej/data/hockey.regular.cartridge.json"))
	var teams: Array = cart["game"]["teams"]
	var core: RefCounted = ClassDB.instantiate("RinkCore")
	var err: String = core.call("load_cartridge", JSON.stringify(cart))
	if err != "":
		_done("cartridge: " + err)
		return
	var seed_n: int = int(args.get("seed", str(int(stream.get("seed", 5)))))
	var difficulty: String = String(args.get("difficulty", String(stream.get("difficulty", "pro"))))
	core.call("set_difficulty", difficulty)
	core.call("set_human_mode", "raw")
	core.call("reset", seed_n)
	var frames: int = int(args.get("frames", "1500")) if recording else mini((stream["frames"] as Array).size(), int(args.get("frames", "100000")))
	var stills: Array = []
	for s: String in String(args.get("stills", "")).split(",", false):
		stills.append([s.split(":")[0], int(s.split(":")[1])])
	var out: String = String(args.get("out", "")).trim_suffix("/")
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
	var warm: int = int(args.get("warm", "240" if args.has("oracle") else "0"))
	var show: RefCounted = SHOW.new()      # the game mode's part around the pawns: hit-stop, the shown carrier, the play calls
	show.set("cfg", SHOW.config_of(cart))
	var hits: RefCounted = HITS.new()      # the game mode's hit read: the whiffs of a miss, the re-time of a check
	hits.set("skater_speed", float(cart["game"]["skater"]["speed"]))
	var pawn_nodes: Array = []
	var pawns: Array = []        # [pawn, figure, the calls of init_skater]
	var human: int = -1
	var who: int = -1
	var recorded: Array = []
	var call_rows: Array = []
	var our_rows: Array = []
	var dropped: Dictionary = {}
	var verbs: Array = []        # per skater: flag -> count
	var events: Dictionary = {}
	var defect_rows: Array = []
	var defects: RefCounted = DEFECTS.new()
	var settle_until: int = 30
	var cost_us: int = 0
	var done: int = 0
	var hit_stops: int = 0
	var rk: Dictionary = cart["game"]["rink"]
	var rink: Vector3 = Vector3(float(rk["length_m"]) * 50.0, float(rk["width_m"]) * 50.0, float(rk["corner_radius_m"]) * 100.0)
	var puck_rows: Array = []
	var puck_node: Node3D = TLKit.build("puck", {"radius": float(cart["game"]["puck"]["radius_m"]), "height": 0.08})      # AJamPuck::InitPuck: 2r across, 0.08 m tall
	add_child(puck_node)
	var whiffs: int = 0
	var retimes: int = 0
	var made_all: Dictionary = {}
	var made_human: Dictionary = {}
	var on_blade: int = 0
	var snap: Dictionary = core.call("snapshot")
	for f: int in range(frames):
		var raw: Dictionary = _hand(f, snap) if recording else _raw(stream["frames"][f])
		if recording:
			var e: Dictionary = {}
			for k: String in raw.keys():
				e[k] = [(raw[k] as Vector2).x, (raw[k] as Vector2).y] if raw[k] is Vector2 else (Array(raw[k] as PackedStringArray) if raw[k] is PackedStringArray else raw[k])
			recorded.append(e)
		core.call("set_raw_input", raw)
		if not bool(core.call("step")):
			break
		snap = core.call("snapshot")
		var sk: Array = snap["Skaters"]
		if pawns.is_empty():
			human = int(snap["HumanIndex"])
			who = int(args.get("who", str(human)))
			var slot_in_team: Dictionary = {}
			var figs: Array = []
			for i: int in range(sk.size()):
				var t: int = int(sk[i]["Team"])
				var slot: int = int(slot_in_team.get(t, 0))
				slot_in_team[t] = slot + 1
				var fig: TLRigSkater = TLRigSkater.new()
				fig.setup({"team": t})
				fig.set_human(i == human)
				fig.set_no_game_mode(args.has("oracle"))
				# the walls the falls ask about ([FindRink]): the ice's half length and half width, the corner radius, cm
				fig.set_rink(rink)
				var pawn: Node3D = PAWN.new()
				add_child(pawn)
				pawn.add_child(fig)
				pawn.set("record", true)
				# the oracle's figures stand at the first frame's places, the puck at its own, before the first call
				pawn.call("apply_render", sk[i], 1.0)
				var pr: Vector2 = (snap["Puck"]["Pos"] as Vector2) - (sk[i]["Pos"] as Vector2)
				var y0: float = float(sk[i]["Yaw"])
				fig.set_puck(Vector2(pr.dot(Vector2(cos(y0), sin(y0))), pr.dot(Vector2(-sin(y0), cos(y0)))))
				for _k: int in range(warm):
					fig.tick()
				pawn.call("init_skater", i, t, Color(String(teams[t]["colour_hex"])).srgb_to_linear(), int(NUMBERS[t][slot]) if slot < 3 else t * 10 + slot + 1, fig)
				pawns.append([pawn, fig, (pawn.get("calls") as Array).duplicate(true)])
				pawn_nodes.append(pawn)
				figs.append(fig)
				verbs.append({})
			for fig: TLRigSkater in figs:
				fig.set_rivals(figs)
		var t0: int = Time.get_ticks_usec()
		var frame_calls: Array = []
		for i: int in range(pawns.size()):
			frame_calls.append((pawns[i][2] as Array).duplicate() if f == 0 else [])
		# thirdjam's bus first (HokejGameMode.cpp:1664 DeliverEvents, before the pawns apply the frame)
		for ev: Dictionary in snap["Events"]:
			var en: String = String(ev["Name"])
			events[en] = int(events.get(en, 0)) + 1
			if not BUS_EVENTS.has(en):
				continue
			var w: Vector2 = (ev["Where"] as Vector2) * 100.0
			for i: int in range(pawns.size()):
				var c: Array = ["OnBusEvent", [en, int(ev["Who"]) == i, w.x, w.y, float(ev["Strength"]), String(ev["Kind"])]]
				(pawns[i][1] as TLRigSkater).OnBusEvent(StringName(en), int(ev["Who"]) == i, w, float(ev["Strength"]), StringName(String(ev["Kind"])))
				if BUS_PORTED.has(en) or args.has("every_call"):
					(frame_calls[i] as Array).append(c)
				else:
					dropped["OnBusEvent " + en] = int(dropped.get("OnBusEvent " + en, 0)) + 1
		# PuckShow.StepSim (:1666), the pawns (:1695), the hit read (:1706); each one's calls in the order made
		var held: Dictionary = show.call("step_sim", snap, pawn_nodes)
		hit_stops += 1 if int(held.get("hit_stop", 0)) > 0 else 0
		for stage: int in range(3):
			for i: int in range(pawns.size()):
				var pawn: Node3D = pawns[i][0]
				if stage == 1:
					pawn.call("apply_sim_frame", sk[i], int(snap["Frame"]))
				var made: Array = pawn.get("calls") if stage == 1 else pawn.get("show_calls")
				for c: Array in made:
					made_all[String(c[0])] = int(made_all.get(String(c[0]), 0)) + 1
					if i == human:
						made_human[String(c[0])] = int(made_human.get(String(c[0]), 0)) + 1
					if args.has("every_call") or not TLRigSkater.NOT_PORTED_CALLS.has(String(c[0])):
						(frame_calls[i] as Array).append(c)
					else:
						dropped[String(c[0])] = int(dropped.get(String(c[0]), 0)) + 1
				if stage != 1:
					pawn.set("show_calls", [])
			if stage == 1:
				show.call("after_pawns", snap, pawn_nodes)
				var read: Dictionary = hits.call("step_sim", snap, pawn_nodes, core.call("last_human_input"))      # HokejGameMode.cpp:1706
				whiffs += (read.get("whiffs", []) as Array).size()
				retimes += (read.get("retimes", []) as Array).size()
		for i: int in range(pawns.size()):
			(pawns[i][0] as Node3D).call("apply_render", sk[i], 1.0)
		# FJamPuckShow::Render (HokejGameMode.cpp:1736): the puck's place, with the sockets of the pose before this tick;
		# the figures' own tick then looks at it ([LookTick] reads the puck actor's place)
		var drawn: Dictionary = show.call("render", snap, pawn_nodes, 1.0, float(f) / 60.0)
		var pk: Vector3 = drawn["puck"]
		for i: int in range(pawns.size()):
			var pn: Node3D = pawns[i][0]
			var ay: float = -(pn.rotation.y + PI * 0.5)
			var rel: Vector2 = Vector2(pk.x - pn.position.x, pk.z - pn.position.z)
			(pawns[i][1] as TLRigSkater).set_puck(Vector2(rel.dot(Vector2(cos(ay), sin(ay))), rel.dot(Vector2(-sin(ay), cos(ay)))))
			(pawns[i][1] as TLRigSkater).tick()
		var on: int = int(drawn.get("drawn_carrier", -1)) if bool(drawn.get("on_blade", false)) else -1
		if on >= 0:
			on_blade += 1
			# AJamPuck::Tick (JamPawns.cpp:959-977): after the frame's animation a carried puck takes the socket's place again
			var sw: Variant = (pawn_nodes[on] as Node3D).call("puck_socket_world")
			puck_node.position = Vector3((sw as Vector3).x, pk.y, (sw as Vector3).z) if sw is Vector3 else pk
		else:
			puck_node.position = pk
		puck_rows.append([[snappedf(pk.x, 0.0001), snappedf(pk.y, 0.0001), snappedf(pk.z, 0.0001)], on])
		cost_us += Time.get_ticks_usec() - t0
		var crow: Array = []
		var orow: Array = []
		for i: int in range(pawns.size()):
			var s: Dictionary = sk[i]
			for fl: String in VERB_FLAGS:
				if bool(s[fl]):
					verbs[i][fl] = int(verbs[i].get(fl, 0)) + 1
			for fl: String in ["PokeResult", "StickHitResult", "DrawResult"]:
				if int(s[fl]) != 0:
					verbs[i]["%s=%d" % [fl, int(s[fl])]] = int(verbs[i].get("%s=%d" % [fl, int(s[fl])], 0)) + 1
			if bool(s["bShotThisFrame"]) and float(s["LastShotCharge"]) > 0.0:
				verbs[i]["shot_charged"] = int(verbs[i].get("shot_charged", 0)) + 1
			for fl: String in ["bCrossBraced", "bBoardPinned"]:
				if bool(s[fl]):
					verbs[i]["frames_" + fl] = int(verbs[i].get("frames_" + fl, 0)) + 1
			for fl: String in ["ChargeFrames", "PassChargeFrames", "KnockFrames", "StumbleFrames", "CrossHoldFrames", "SpinFrames", "PenaltyFrames"]:
				if int(s[fl]) > 0:
					verbs[i]["frames_" + fl] = int(verbs[i].get("frames_" + fl, 0)) + 1
			var pw: Node3D = pawns[i][0]      # where the pawn stands (its hit-stop hold and its spin are in it)
			crow.append({"pos": [pw.position.x, pw.position.z], "yaw": -(pw.rotation.y + PI * 0.5), "calls": _plain(frame_calls[i])})
			var fig: TLRigSkater = pawns[i][1]
			var flat: Array = []
			for p: String in POINTS:
				var v: Vector3 = fig.point_ue(p)
				flat.append_array([snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)])
			orow.append(flat)
		call_rows.append({"f": f, "sk": crow, "puck": puck_rows[-1][0], "puck_on": puck_rows[-1][1]})
		our_rows.append(orow)
		var hf: TLRigSkater = pawns[who][1]
		var an: TLRigSkaterAnim = hf.anim
		var no_take: bool = not an.is_any_montage_playing() and an.bStLoco and float(an._loco_list.w[0]) >= 0.999 and an.state <= TLRigSkaterAnim.SKATE and an.transitions.is_empty() \
			and an.ChargeAlpha <= 0.0 and an.PassW <= 0.0
		var drow: Dictionary = defects.call("measure", hf, no_take and hf.AimW >= 0.99 and hf.FixW >= 0.99 and f > settle_until, no_take)
		drow["f"] = f
		if not no_take or hf.AimW < 0.99:
			settle_until = f + 30
		defect_rows.append(drow)
		for st: Array in stills:
			if f % int(st[1]) == 0 and out != "" and DisplayServer.get_name() != "headless":
				_cam_to(pawns[who][0], String(st[0]))
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
	report["who"] = who
	report["seed"] = seed_n
	report["difficulty"] = difficulty
	report["score"] = snap["Score"]
	report["state_hash"] = String(core.call("state_hash_hex"))
	report["cost_us_per_frame_all_figures"] = snappedf(float(cost_us) / float(maxi(done, 1)), 0.1)
	report["verbs_human"] = verbs[human] if human >= 0 and human < verbs.size() else {}
	var total: Dictionary = {}
	for vd: Dictionary in verbs:
		for k: String in vd.keys():
			total[k] = int(total.get(k, 0)) + int(vd[k])
	report["verbs_all"] = total
	report["events"] = events
	report["calls_made_all"] = made_all
	report["calls_made_human"] = made_human
	report["hit_stops"] = hit_stops
	report["whiffs"] = whiffs
	report["retimes"] = retimes
	report["frames_puck_drawn_on_a_blade"] = on_blade
	report["calls_left_out_of_calls_json"] = dropped
	var np: Dictionary = {}
	var ng: Dictionary = {}
	for row: Array in pawns:
		for k: String in (row[1] as TLRigSkater).not_ported.keys():
			np[k] = int(np.get(k, 0)) + int((row[1] as TLRigSkater).not_ported[k])
		for k: String in (row[1] as TLRigSkater).anim.not_ported.keys():
			ng[k] = int(ng.get(k, 0)) + int((row[1] as TLRigSkater).anim.not_ported[k])
	report["not_ported_calls"] = np
	report["not_ported_graph"] = ng
	report["warm_ticks"] = warm
	if recording:
		_write(String(args["record"]), {"schema": "tl.rink.rawstream/1", "seed": seed_n, "difficulty": difficulty, "frames": recorded})
	if out != "":
		_write(out + "/calls.json", {"schema": "tl.skater.calls/2", "human": human, "who": who, "skaters": pawns.size(), "rink": [rink.x, rink.y, rink.z], "frames": call_rows})
		_write(out + "/ours.json", {"schema": "tl.skater.ours/2", "points": POINTS, "units": "centimetres in the actor's frame, Unreal's axes", "frames": our_rows})
	var verdict: Dictionary = DEFECTS.judge(defect_rows)
	report["defects"] = verdict
	var why: String = "" if done == frames and frames > 0 else "%d of %d frames" % [done, frames]
	if why == "" and not recording and not args.has("frames") and not args.has("seed") and not args.has("stream") and not args.has("who"):
		var broken: String = DEFECTS.gate(verdict, DEFECTS.VERBS_ALLOWED_ORACLE if args.has("oracle") else DEFECTS.VERBS_ALLOWED)
		report["defect_gate"] = "parity (skater_defects.gd %s)" % ("VERBS_ALLOWED_ORACLE" if args.has("oracle") else "VERBS_ALLOWED")
		if broken != "":
			why = "defects: " + broken
	if args.has("oracle") and why == "":
		why = _compare(our_rows, String(args["oracle"]))
	_done(why)


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
	cam.look_at_from_position(pawn.global_transform * Vector3(float(e[1]), float(e[2]), -float(e[0])), pawn.global_transform * Vector3(float(t[1]), float(t[2]), -float(t[0])), Vector3.UP)


## Ours against thirdjam's own figures: every frame, every skater, every point (centimetres). The oracle's file:
## {"points": [...], "frames": [[flat row per skater] ...]} (tools/skater/driver_oracle.py, schema tl.skater.oracle/2).
func _compare(ours: Array, path: String) -> String:
	var o: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (o is Dictionary) or not (o as Dictionary).has("frames") or not (o as Dictionary).has("points"):
		return "no oracle at " + path
	var theirs: Array = o["frames"]
	var names: Array = o["points"]
	var n: int = mini(ours.size(), theirs.size())
	var worst: float = 0.0
	var worst_at: String = ""
	var near: int = 0
	var rows: int = 0
	var by_skater: Array = []
	var far_by_skater: Array = []
	var kept: Array = o.get("skaters_kept", [])      # a tracked golden holds some skaters only (tools/skater/oracle_golden.py)
	for f: int in range(n):
		for j: int in range((theirs[f] as Array).size()):
			var i: int = int(kept[j]) if j < kept.size() else j
			if i >= (ours[f] as Array).size():
				continue
			while by_skater.size() <= i:
				by_skater.append(0.0)
				far_by_skater.append(0)
			var a: Array = ours[f][i]
			var b: Array = theirs[f][j]
			var row_worst: float = 0.0
			for k: int in range(POINTS.size()):
				var q: int = names.find(POINTS[k])
				if q < 0:
					continue
				var d: float = Vector3(float(a[k * 3]) - float(b[q * 3]), float(a[k * 3 + 1]) - float(b[q * 3 + 1]), float(a[k * 3 + 2]) - float(b[q * 3 + 2])).length()
				if d > row_worst:
					row_worst = d
				if d > worst:
					worst = d
					worst_at = "frame %d skater %d %s" % [f, i, POINTS[k]]
			rows += 1
			if row_worst <= NEAR_CM:
				near += 1
			else:
				far_by_skater[i] = int(far_by_skater[i]) + 1
			by_skater[i] = snappedf(maxf(float(by_skater[i]), row_worst), 0.01)
	report["oracle"] = {"frames_compared": n, "frames_ours": ours.size(), "frames_theirs": theirs.size(), "rows_compared": rows, "worst_cm": snappedf(worst, 0.01), "worst_at": worst_at,
		"rows_within_%.1f_cm" % NEAR_CM: near, "share_within": snappedf(float(near) / float(maxi(rows, 1)), 0.0001), "worst_cm_by_skater": by_skater, "rows_over_by_skater": far_by_skater,
		"tolerance_worst_cm": ORACLE_WORST_CM, "tolerance_share": NEAR_SHARE}
	if n != ours.size() or n != theirs.size():
		return "the oracle has %d frames, ours %d" % [theirs.size(), ours.size()]
	if worst > ORACLE_WORST_CM or float(near) / float(maxi(rows, 1)) < NEAR_SHARE:
		return "ours and thirdjam's figures differ: worst %.2f cm at %s, %d of %d rows within %.1f cm" % [worst, worst_at, near, rows, NEAR_CM]
	return ""


func _done(err: String) -> void:
	report["ok"] = err == ""
	if err != "":
		report["error"] = err
	print("%s skater verb gym" % ("PASS" if err == "" else "FAIL"))
	print("tl.skater.verb_gym/1 " + JSON.stringify(report))
	get_tree().quit(0 if err == "" else 1)
