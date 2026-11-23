extends SceneTree
## Cases of hit_read.gd (thirdjam's hit read: the model of presses and hits, the whiff calls, the check's re-time),
## headless:   godot --headless --path engine -s res://cores/rink/view/hit_read_case.gd
## One `PASS name` / `FAIL name: why` line a case, exit 0 / 1. thirdjam's own automation tests, with their expected
## values ("S" = thirdjam's Game/Source, HEAD 8dc713c6):
##   hitread.retime_for   Jam.Hit.Quiet          S/JamGame/Private/HitRead.cpp:1675-1680 (AJamHitRead::RetimeFor)
##   hitread.landed       Jam.Hit.BurstSize      S/JamGame/Private/HitRead.cpp:1296-1313 (the landed check through the model)
##   hitread.miss         Jam.Hit.MissNoBurst    S/JamGame/Private/HitRead.cpp:1342-1385, :1395-1404 (the miss is the sim's own;
##                                               a window that closes with no miss counted; the strip)
##   hitread.whiff_take   Jam.Hit.WhiffTake      S/JamGame/Private/HudNoMarksTests.cpp:129-138 (the take's frames kept, on
##                                               skater_pawn.gd's note_whiff_take / _whiff_take_keeps)
## and two are ours: `hitread.calls` (who is told what on made-up frames: PlayWhiff / PlayCheckWhiff / nothing, the held
## cross-check, the re-time's one frame of fast-forward and its way back) and `hitread.core1800` (the verb gym's match
## segment of the real RinkCore, cores/rink/view/verbs.stream.json, all ten pawns with a figure that only counts).
const HITS := preload("res://cores/rink/view/hit_read.gd")
const SHOW := preload("res://cores/rink/view/skater_show.gd")
const PAWN := preload("res://cores/rink/view/skater_pawn.gd")
const NEEDED: Array = ["Index", "Team", "bHuman", "bCheckThisFrame", "bLiftThisFrame", "WindupFrames", "CheckWindupLeft", "LiftWindupLeft", "CheckWindow", "CrossLiveLeft",
	"ContactBy", "ContactOutcome", "bContactCross", "bCrossBraceHit", "bCrossBraced", "CrossHoldFrames", "ChecksMissed", "KnockFrames", "PenaltyFrames"]

var _fails: Array = []
var _failed: int = 0


## A pawn that only notes what the hit read asks of it.
class StubPawn:
	extends RefCounted
	var sim_index: int = -1
	var figure: Object = null
	var stopped: bool = false
	var calls: Array = []
	var notes: Array = []
	var dilations: Array = []
	var aim_recover: Array = []
	func call_figure(fname: StringName, args: Array) -> bool:
		if figure == null or not figure.has_method(fname):
			return false
		calls.append("%s%s" % [fname, str(args)])
		return true
	func note_whiff_take(kind: int) -> void: notes.append(kind)
	func is_hit_stopped() -> bool: return stopped
	func set_figure_dilation(d: float) -> void: dilations.append(d)
	func set_aim_recover(frames: int) -> void: aim_recover.append(frames)


## Device B's figure: every by-name call of the hit layer.
class FigB:
	extends RefCounted
	func PlayWhiff(_k: int) -> void: pass
	func PlayCheckWhiff() -> void: pass
	func PlayCheckWindup(_n: int) -> void: pass
	func SetWindupTakes(_on: bool, _n: int) -> void: pass


## An older figure: the body check's whiff only, no wind-up takes.
class FigOld:
	extends RefCounted
	func PlayCheckWhiff() -> void: pass


## The figure of the core run: thirdjam's interface and by-name calls, counted.
class FigCount:
	extends Node3D
	var got: Dictionary = {}
	var dil: float = 1.0
	func _n(k: String) -> void:
		got[k] = int(got.get(k, 0)) + 1
	func SetTeam(_t: Variant, _c: Variant) -> void: pass
	func SetNumber(_n0: Variant) -> void: pass
	func SetHasPuck(_b: Variant) -> void: pass
	func SetBoost(_k: Variant) -> void: pass
	func UpdateMotion(_s: Variant, _t: Variant, _f: Variant) -> void: pass
	func SetStickAim(_a: Variant, _r: Variant) -> void: pass
	func SetShotCharge(_c: Variant) -> void: pass
	func PlayShoot(_c: Variant) -> void: pass
	func PlayCheck() -> void: _n("PlayCheck")
	func PlayCheckWindup(n0: Variant) -> void: _n("PlayCheckWindup(%s)" % str(n0))
	func PlayCrossCheck(_n0: Variant) -> void: _n("PlayCrossCheck")
	func SetCrossCheckHold(_b: Variant) -> void: pass
	func PlayWhiff(k: Variant) -> void: _n("PlayWhiff(%d)" % int(k))
	func PlayCheckWhiff() -> void: _n("PlayCheckWhiff")
	func SetKnockedDown(_b: Variant, _x: Variant, _z: Variant, _n0: Variant) -> void: pass
	func PlayStumble(_x: Variant, _z: Variant, _n0: Variant) -> void: pass
	func PlayHitReaction(_x: Variant, _z: Variant) -> void: pass
	func SetBraking(_b: Variant, _d: Variant) -> void: pass
	func PlayBoardHit() -> void: pass
	func SetBoardPin(_b: Variant) -> void: pass
	func PlayStickHit(_b: Variant) -> void: pass
	func PlayPoke(_b: Variant) -> void: pass
	func PlayLift() -> void: pass
	func PlayPass(_s: Variant) -> void: pass
	func SetFaceoff(_b: Variant) -> void: pass
	func PlayFaceoffDraw(_b: Variant) -> void: pass
	func PlayFoulReaction() -> void: pass
	func PlayReceive() -> void: pass
	func SetPassCharge(_c: Variant) -> void: pass
	func PlayCallForPass() -> void: pass
	func SetLookAtPuck(_b: Variant) -> void: pass
	func SetWindupTakes(_b: Variant, _n0: Variant) -> void: _n("SetWindupTakes")
	func set_time_dilation(d: float) -> void:
		dil = d
		if d > 1.5:
			_n("fast_forward")
	func socket_transform(_s: StringName) -> Transform3D:
		return Transform3D(Basis.IDENTITY, Vector3(0.0, 0.03, -0.5))


func _t(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)


func _eq(got: Variant, want: Variant, what: String) -> void:
	var ok: bool = is_equal_approx(float(got), float(want)) if (got is float or want is float) else got == want
	if not ok:
		_fails.append("%s: got %s, want %s" % [what, str(got), str(want)])


func _end(cname: String) -> void:
	if _fails.is_empty():
		print("PASS ", cname)
	else:
		_failed += 1
		print("FAIL ", cname, ": ", "; ".join(PackedStringArray(_fails.slice(0, 4))), (" (+%d more)" % (_fails.size() - 4)) if _fails.size() > 4 else "")
	_fails = []


## JamHitTest::Two (HitRead.cpp:1240-1247): the human at the origin, an opponent 3 m ahead; every field the model reads.
func _two() -> Array:
	var out: Array = []
	for i: int in range(2):
		out.append({"Index": i, "Team": i, "bHuman": i == 0, "Pos": Vector2(3.0 * i, 0.0), "Vel": Vector2.ZERO, "Yaw": 0.0, "bCheckThisFrame": false, "bLiftThisFrame": false,
			"WindupFrames": 0, "CheckWindupLeft": 0, "LiftWindupLeft": 0, "CheckWindow": 0, "CrossLiveLeft": 0, "CrossTarget": -1, "ContactBy": -1, "ContactOutcome": 0,
			"bContactCross": false, "bCrossBraceHit": false, "bCrossBraced": false, "CrossHoldFrames": 0, "ChecksMissed": 0, "KnockFrames": 0, "KnockDir": Vector2.ZERO,
			"PenaltyFrames": 0})
	return out


## JamHitTest::ClearFrame (HitRead.cpp:1248-1251).
func _clear(s: Array) -> void:
	for x: Dictionary in s:
		x["bCheckThisFrame"] = false
		x["bLiftThisFrame"] = false
		x["WindupFrames"] = 0
		x["ContactBy"] = -1
		x["ContactOutcome"] = 0
		x["bContactCross"] = false
		x["bCrossBraceHit"] = false


func _snap(frame: int, s: Array, events: Array = []) -> Dictionary:
	return {"Frame": frame, "Skaters": s, "Events": events}


func _pawns(fig0: Object, fig1: Object) -> Array:
	var out: Array = []
	for i: int in range(2):
		var p: StubPawn = StubPawn.new()
		p.sim_index = i
		p.figure = fig0 if i == 0 else fig1
		out.append(p)
	return out


func _case_retime_for() -> void:
	_eq(HITS.retime_for(2, 8), 1, "contact on frame 2 of 8: re-timed")
	_eq(HITS.retime_for(6, 8), 1, "contact on frame 6 of 8: re-timed")
	_eq(HITS.retime_for(7, 8), -1, "contact on frame 7 of 8: within a frame, left alone")
	_eq(HITS.retime_for(8, 8), -1, "contact at the wind-up's end: left alone")
	_eq(HITS.retime_for(13, 8), -1, "contact in the window: left alone")
	_eq(HITS.retime_for(0, 0), -1, "no wind-up: nothing to re-time")
	_eq(HITS.RETIME_LEAD_FRAMES, 2, "RetimeLeadFrames")
	_end("hitread.retime_for")


## The landed check of Jam.Hit.BurstSize: the press, four frames of wind-up, the contact at closing 6 m/s.
func _case_landed() -> void:
	var m: RefCounted = HITS.new()
	m.skater_speed = 8.0
	var pawns: Array = _pawns(FigB.new(), FigB.new())
	var s: Array = _two()
	s[0]["bCheckThisFrame"] = true
	s[0]["WindupFrames"] = 4
	s[0]["CheckWindupLeft"] = 4
	m.step_sim(_snap(100, s), pawns)
	var last: Dictionary = {}
	for f: int in range(101, 106):
		_clear(s)
		s[0]["CheckWindupLeft"] = maxi(0, 104 - f)
		s[0]["CheckWindow"] = 0 if int(s[0]["CheckWindupLeft"]) > 0 else 12
		var ev: Array = []
		if f == 105:
			s[1]["ContactBy"] = 0
			s[1]["ContactOutcome"] = 3
			s[1]["KnockFrames"] = 90
			s[1]["KnockDir"] = Vector2(1, 0)
			ev.append({"Name": "check", "Who": 0, "Where": Vector2(1.5, 0), "Strength": 0.75, "Dir": Vector2(1, 0), "Kind": "", "Outcome": "down"})
		last = m.step_sim(_snap(f, s, ev), pawns)
	_eq(m.hits, 1, "one hit")
	_eq(m.misses, 0, "no miss")
	# ours, on the same frames: the hit's log, and nothing sent (the contact came after the wind-up)
	_eq((last["logs"] as Array).size(), 1, "one log on the contact's frame")
	if (last["logs"] as Array).size() == 1:
		var l: Dictionary = last["logs"][0]
		_eq(String(l["Kind"]), "check", "kind")
		_eq(int(l["Result"]), HITS.RESULT_DOWN, "result down")
		_eq(int(l["Checker"]), 0, "checker")
		_eq(int(l["Victim"]), 1, "victim")
		_eq(int(l["Windup"]), 4, "wind-up of the press")
		_eq(int(l["PressToContact"]), 5, "press to contact")
		_eq(float(l["ClosingMps"]), 6.0, "closing speed (0.75 of 8 m/s)")
	_eq((pawns[0] as StubPawn).calls.size(), 0, "no call to the checker's figure")
	_eq((pawns[0] as StubPawn).dilations.size(), 0, "no re-time (5 frames after a 4-frame wind-up)")
	_end("hitread.landed")


func _miss_run(m: RefCounted, pawns: Array, count_miss: bool) -> int:
	var s: Array = _two()
	s[1]["Pos"] = Vector2(9, 0)        # nobody within reach
	s[0]["bCheckThisFrame"] = true
	s[0]["WindupFrames"] = 4
	s[0]["CheckWindupLeft"] = 4
	m.step_sim(_snap(10, s), pawns)
	var miss_at: int = -1
	for f: int in range(11, 31):
		_clear(s)
		var wu: int = maxi(0, 14 - f)
		s[0]["CheckWindupLeft"] = wu
		s[0]["CheckWindow"] = 0 if wu > 0 else maxi(0, 26 - f)       # the window: frames 14..25
		if count_miss and f >= 26:
			s[0]["ChecksMissed"] = 1      # the sim counts the miss on the frame the window runs out
		m.step_sim(_snap(f, s), pawns)
		if miss_at < 0 and int(m.misses) > 0:
			miss_at = f
	return miss_at


func _case_miss() -> void:
	var m: RefCounted = HITS.new()
	var pawns: Array = _pawns(FigB.new(), FigB.new())
	var miss_at: int = _miss_run(m, pawns, true)
	_eq(m.misses, 1, "one miss")
	var q: RefCounted = HITS.new()
	var qp: Array = _pawns(FigB.new(), FigB.new())
	_miss_run(q, qp, false)
	_eq(q.misses, 0, "no miss the sim did not count")
	_eq(miss_at, 26, "the miss when the window ran out")
	_eq(m.hits, 0, "no hit")
	# ours, on the same frames: the whiff take is told once, on the miss's frame, and the pawn is told to keep it
	_eq((pawns[0] as StubPawn).calls, ["PlayWhiff[0]"], "PlayWhiff(0) once")
	_eq((pawns[0] as StubPawn).notes, [0], "NoteWhiffTake(0)")
	_eq((qp[0] as StubPawn).calls.size(), 0, "a quiet end: no call")
	# a cross-check whose stick took the puck and whose shove found nobody: the strip, no miss (:1395-1404)
	var x: RefCounted = HITS.new()
	var xp: Array = _pawns(FigB.new(), FigB.new())
	var t: Array = _two()
	t[0]["bLiftThisFrame"] = true
	t[0]["WindupFrames"] = 4
	x.step_sim(_snap(50, t, [{"Name": "lift", "Who": 0, "Where": Vector2.ZERO, "Strength": 1.0, "Dir": Vector2.ZERO, "Kind": "", "Outcome": ""}]), xp)
	for f: int in range(51, 57):
		_clear(t)
		x.step_sim(_snap(f, t), xp)
	_eq(x.strips, 1, "the strip is counted")
	_eq(x.misses, 0, "a strip with no shove is no miss")
	_eq((xp[0] as StubPawn).calls.size(), 0, "a strip: no whiff")
	_end("hitread.miss")


## Ours: who is told what.
func _case_calls() -> void:
	# a body check's miss on a figure without PlayWhiff: PlayCheckWhiff
	var m: RefCounted = HITS.new()
	var pawns: Array = _pawns(FigOld.new(), FigB.new())
	_miss_run(m, pawns, true)
	_eq((pawns[0] as StubPawn).calls, ["PlayCheckWhiff[]"], "PlayCheckWhiff to a figure without PlayWhiff")
	_eq((pawns[0] as StubPawn).notes, [0], "the take is noted")
	# a figure with neither: nothing, and nothing noted
	m = HITS.new()
	pawns = _pawns(RefCounted.new(), FigB.new())
	_miss_run(m, pawns, true)
	_eq((pawns[0] as StubPawn).calls.size() + (pawns[0] as StubPawn).notes.size(), 0, "a figure without the calls gets nothing")
	_eq(m.misses, 1, "the model still counts the miss")
	# a pressed cross-check that meets nobody: PlayWhiff(1) when its live window ends
	for held: int in range(2):
		m = HITS.new()
		pawns = _pawns(FigB.new(), FigB.new())
		var s: Array = _two()
		s[0]["bLiftThisFrame"] = true
		s[0]["WindupFrames"] = 8
		s[0]["LiftWindupLeft"] = 8
		m.step_sim(_snap(200, s), pawns)
		var at: int = -1
		for f: int in range(201, 230):
			_clear(s)
			s[0]["LiftWindupLeft"] = maxi(0, 208 - f)
			s[0]["CrossLiveLeft"] = 0 if f < 208 else maxi(0, 214 - f)      # the live window: frames 208..213
			if held == 1 and f >= 213:
				s[0]["CrossHoldFrames"] = f - 200     # he still holds the button: a brace is coming
			var out: Dictionary = m.step_sim(_snap(f, s), pawns)
			if at < 0 and not (out["whiffs"] as Array).is_empty():
				at = f
		_eq(m.misses, 1, "a cross-check's miss is counted (held %d)" % held)
		_eq(at, 214, "on the frame its live window is over (held %d)" % held)
		if held == 0:
			_eq((pawns[0] as StubPawn).calls, ["PlayWhiff[1]"], "PlayWhiff(1)")
			_eq((pawns[0] as StubPawn).notes, [1], "NoteWhiffTake(1)")
		else:
			_eq((pawns[0] as StubPawn).calls.size() + (pawns[0] as StubPawn).notes.size(), 0, "held: no whiff from the hit read (the release's is the pawn's)")
	# the re-time: a check that lands 2 frames into a wind-up of 8
	for variant: int in range(3):       # 0: device B's figure; 1: hit-stopped on the next frame; 2: a figure never told the takes
		m = HITS.new()
		pawns = _pawns(FigB.new() if variant < 2 else FigOld.new(), FigB.new())
		var s2: Array = _two()
		s2[0]["bCheckThisFrame"] = true
		s2[0]["WindupFrames"] = 8
		s2[0]["CheckWindupLeft"] = 8
		m.step_sim(_snap(300, s2), pawns)
		_clear(s2)
		s2[0]["CheckWindupLeft"] = 7
		m.step_sim(_snap(301, s2), pawns)
		_clear(s2)
		s2[0]["CheckWindupLeft"] = 6
		s2[1]["ContactBy"] = 0
		s2[1]["ContactOutcome"] = 2
		var out2: Dictionary = m.step_sim(_snap(302, s2, [{"Name": "check", "Who": 0, "Where": Vector2(1.5, 0), "Strength": 0.5, "Dir": Vector2(1, 0), "Kind": "", "Outcome": "stumble"}]), pawns)
		var p0: StubPawn = pawns[0]
		if variant == 2:
			_eq(p0.dilations.size(), 0, "no re-time on a figure without the wind-up takes")
			continue
		_eq(out2["retimes"], [[0, 6, "fast_forward"]], "re-timed: 6 frames short")
		_eq(p0.dilations, [6.0], "the figure's clock at 6 for this sim frame")
		_eq(p0.calls.size(), 0, "mode 1: no PlayCheckWindup(1)")
		p0.stopped = variant == 1
		_clear(s2)
		m.step_sim(_snap(303, s2), pawns)
		_eq(p0.dilations, [6.0, 0.0001 if variant == 1 else 1.0], "and back on the next: the hold's stand-still in a hit-stop, else its own clock")
		m.step_sim(_snap(304, s2), pawns)
		_eq(p0.dilations.size(), 2, "once")
	# a frame that goes back is a new match
	m = HITS.new()
	pawns = _pawns(FigB.new(), FigB.new())
	_miss_run(m, pawns, true)
	m.step_sim(_snap(5, _two()), pawns)
	_eq(int(m.misses) + int(m.hits) + (m.presses as Array).size(), 0, "the frame went back: the model starts over")
	_end("hitread.calls")


## Jam.Hit.WhiffTake's rows on the pawn (JamPawns.h:226-229).
func _case_whiff_take() -> void:
	var p: Node3D = PAWN.new()
	p.set("_frame", 1000)
	p.call("note_whiff_take", 1)
	_eq(int(p.get("_whiff_take_until")), 1016, "cross-check whiff: 16 frames kept")
	_t(bool(p.call("_whiff_take_keeps")), "the frame it is sent: kept")
	p.set("_frame", 1016)
	_t(bool(p.call("_whiff_take_keeps")), "its last frame: kept")
	p.set("_frame", 1017)
	_t(not bool(p.call("_whiff_take_keeps")), "a frame after: not kept")
	p.set("_frame", 1000)
	p.call("note_whiff_take", 0)
	_eq(int(p.get("_whiff_take_until")), 1025, "body check whiff: 25 frames kept")
	var q: Node3D = PAWN.new()
	q.set("_frame", 1000)
	_t(not bool(q.call("_whiff_take_keeps")), "no whiff sent: nothing kept")
	q.set("_frame", -1)
	q.call("note_whiff_take", 1)
	_t(not bool(q.call("_whiff_take_keeps")), "no sim frame known: nothing kept")
	p.free()
	q.free()
	_end("hitread.whiff_take")


func _case_core() -> void:
	if not ClassDB.class_exists("RinkCore"):
		_fails.append("RinkCore is not registered")
		_end("hitread.core1800")
		return
	var cart_text: String = FileAccess.get_file_as_string("res://packs/hokej/data/hockey.regular.cartridge.json")
	var cart: Variant = JSON.parse_string(cart_text)
	var stream: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://cores/rink/view/verbs.stream.json"))
	var core: RefCounted = ClassDB.instantiate("RinkCore")
	var err: String = core.call("load_cartridge", cart_text)
	if err != "" or not (stream is Dictionary) or not (cart is Dictionary):
		_fails.append("cartridge or stream: %s" % err)
		_end("hitread.core1800")
		return
	core.call("set_difficulty", String(stream.get("difficulty", "pro")))
	core.call("set_human_mode", "raw")
	core.call("reset", int(stream.get("seed", 5)))
	var show: RefCounted = SHOW.new()
	show.cfg = SHOW.config_of(cart)
	var hits: RefCounted = HITS.new()
	hits.skater_speed = float(cart["game"]["skater"]["speed"]) if (cart["game"] as Dictionary).has("skater") and (cart["game"]["skater"] as Dictionary).has("speed") else 0.0
	var pawns: Array = []
	var figs: Array = []
	var frames: int = 0
	var whiffs: Array = []
	var retimes: Array = []
	var logs: Dictionary = {}
	var missing: Array = []
	var fast_frames: int = 0
	var bad_back: int = 0
	for entry: Variant in (stream["frames"] as Array):
		var raw: Dictionary = {}
		for k: Variant in (entry as Dictionary).keys():
			var v: Variant = entry[k]
			if k == "Down" or k == "Pressed":
				raw[k] = PackedStringArray(v)
			elif v is Array and (v as Array).size() == 2:
				raw[k] = Vector2(float(v[0]), float(v[1]))
			else:
				raw[k] = v
		core.call("set_raw_input", raw)
		if not bool(core.call("step")):
			break
		var snap: Dictionary = core.call("snapshot")
		var sk: Array = snap["Skaters"]
		if pawns.is_empty():
			for key: String in NEEDED:
				if not (sk[0] as Dictionary).has(key):
					missing.append(key)
			for i: int in range(sk.size()):
				var fig: FigCount = FigCount.new()
				var pawn: Node3D = PAWN.new()
				pawn.add_child(fig)
				pawn.call("init_skater", i, int(sk[i]["Team"]), Color.WHITE, i, fig)
				pawns.append(pawn)
				figs.append(fig)
		if not missing.is_empty():
			break
		# every figure that was run forward last frame is back on this one, before anything else is told
		var was_fast: Array = []
		for i: int in range(figs.size()):
			was_fast.append((figs[i] as FigCount).dil > 1.5)
		show.call("step_sim", snap, pawns)
		for i: int in range(pawns.size()):
			(pawns[i] as Node3D).call("apply_sim_frame", sk[i], int(snap["Frame"]))
		show.call("after_pawns", snap, pawns)
		var out: Dictionary = hits.call("step_sim", snap, pawns, core.call("last_human_input"))
		for i: int in range(pawns.size()):
			(pawns[i] as Node3D).call("apply_render", sk[i], 1.0)
			var d: float = (figs[i] as FigCount).dil
			if d > 1.5:
				fast_frames += 1
			if bool(was_fast[i]) and d > 1.5 and not _has_retime(out["retimes"], i):
				bad_back += 1
		for w: Array in out["whiffs"]:
			whiffs.append("f%d s%d %s" % [int(snap["Frame"]), int(w[0]), String(w[2])])
		for r: Array in out["retimes"]:
			retimes.append("f%d s%d short %d %s" % [int(snap["Frame"]), int(r[0]), int(r[1]), String(r[2])])
		for l: Dictionary in out["logs"]:
			var key: String = "%s %s" % [String(l["Kind"]), String(HITS.RESULT_NAMES[int(l["Result"])])]
			logs[key] = int(logs.get(key, 0)) + 1
		frames += 1
	_t(missing.is_empty(), "the snapshot lacks %s" % str(missing))
	_eq(frames, 1800, "frames")
	_eq(String(core.call("state_hash_hex")), "3ba801e4fee31b2b", "the verb gym's match (state hash)")
	_eq(bad_back, 0, "a fast-forward lasts one sim frame")
	_eq(fast_frames, retimes.size(), "one fast-forwarded frame a re-time")
	var told: Dictionary = {}
	for fig: FigCount in figs:
		for k: String in fig.got.keys():
			told[k] = int(told.get(k, 0)) + int(fig.got[k])
	var by_hits: Dictionary = {"PlayWhiff(0)": 0, "PlayWhiff(1)": 0, "none (held)": 0, "PlayCheckWhiff": 0, "none": 0}
	for w: String in whiffs:
		for k: String in by_hits.keys():
			if w.ends_with(" " + k):
				by_hits[k] = int(by_hits[k]) + 1
	_eq(int(told.get("PlayCheckWhiff", 0)), 0, "PlayCheckWhiff is not sent to a figure that has PlayWhiff")
	_t(int(told.get("PlayWhiff(0)", 0)) == int(by_hits["PlayWhiff(0)"]), "every PlayWhiff(0) is the hit read's")
	_t(int(told.get("PlayWhiff(1)", 0)) >= int(by_hits["PlayWhiff(1)"]), "PlayWhiff(1): the hit read's and the pawn's (a hold released on nobody)")
	print("tl.rink.hit_read_case/1 ", JSON.stringify({"frames": frames, "state_hash": core.call("state_hash_hex"), "hits": hits.hits, "misses": hits.misses, "strips": hits.strips,
		"logs": logs, "whiffs_by_the_hit_read": by_hits, "whiffs": whiffs, "retimes": retimes, "figures_told": told,
		"PlayWhiff(1)_by_the_pawn": int(told.get("PlayWhiff(1)", 0)) - int(by_hits["PlayWhiff(1)"])}))
	for p: Node3D in pawns:
		p.free()
	_end("hitread.core1800")


func _has_retime(retimes: Array, who: int) -> bool:
	for r: Array in retimes:
		if int(r[0]) == who:
			return true
	return false


func _init() -> void:
	_case_retime_for()
	_case_landed()
	_case_miss()
	_case_calls()
	_case_whiff_take()
	_case_core()
	print("hit_read_case: %d failed" % _failed)
	quit(1 if _failed > 0 else 0)
