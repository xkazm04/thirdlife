extends SceneTree
## Cases of skater_show.gd (the hit-stop picks, the shown carrier), headless:
##   godot --headless --path engine -s res://cores/rink/view/skater_show_case.gd
## One `PASS name` / `FAIL name: why` line a case, exit 0 / 1. The first three are thirdjam's own automation tests with
## their expected values ("S" = thirdjam's Game/Source, HEAD 8dc713c6):
##   hitstop.frames   Jam.Core.Contact.HitStop      S/JamCore/Private/Tests/JamContactTests.cpp:1388-1432
##   hitstop.pick     Jam.Core.Contact.HitStopPick  S/JamCore/Private/Tests/JamContactTests.cpp:1267-1335
##   puck.show        Jam.Puck.Show                 S/JamGame/Private/PuckRead.cpp:395-514 (its AJamSkater::CarryAimDeg rows
##                                                  run against skater_pawn.gd's carry_aim_deg)
## and two are ours: `show.object` (the per-match object on made-up frames: who is told, the puck's hold and blend) and
## `show.core600` (600 frames of the real RinkCore on K1's recorded raw hand, all ten pawns: no error, one shown carrier
## at most, the drawn puck on his socket or at the sim's place).
const SHOW := preload("res://cores/rink/view/skater_show.gd")
const PAWN := preload("res://cores/rink/view/skater_pawn.gd")

var _fails: Array = []
var _failed: int = 0


## A figure that only counts the by-name calls of the game mode and has a puck socket half a metre ahead.
class Fig:
	extends Node3D
	var got: Dictionary = {}
	func _n(k: String) -> void:
		got[k] = int(got.get(k, 0)) + 1
	func PlayReceive() -> void: _n("PlayReceive")
	func SetPassCharge(_c: float) -> void: _n("SetPassCharge")
	func PlayCallForPass() -> void: _n("PlayCallForPass")
	func SetLookAtPuck(_on: bool) -> void: _n("SetLookAtPuck")
	func SetWindupTakes(_on: bool, _n8: int) -> void: _n("SetWindupTakes")
	func SetHasPuck(on: bool) -> void:
		if on: _n("SetHasPuck(true)")
	func set_time_dilation(d: float) -> void:
		if d < 0.5: _n("held")
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


func _for(outcome: int, ratio: float, base: int) -> int:
	return SHOW.hit_stop_frames_for(outcome, ratio, 0.4, 1.0, 3.0, base)       # FJamContactConfig's defaults: bump 0.4, down 1, full 3


func _f32(x: float) -> float:
	return PackedFloat32Array([x])[0]                                          # thirdjam's read-outs are floats


func _case_frames() -> void:
	var rows: Array = [
		[1, 0.30, 3, 0, "a bump holds nothing"], [2, 0.40, 3, 1, "the lightest stumble: 1"], [2, 0.69, 3, 1, "a stumble under the middle of its band: 1"],
		[2, 0.70, 3, 2, "a stumble from the middle of its band: 2"], [2, 0.99, 3, 2, "the hardest stumble: 2"], [3, 1.00, 3, 2, "a knockdown at down_ratio: 2"],
		[3, 1.40, 3, 3, "a knockdown at 1.4: 3"], [3, 2.00, 3, 4, "a knockdown at 2.0: 4"], [3, 2.34, 3, 5, "a knockdown at 2.34: 5"],
		[3, 3.00, 3, 6, "a knockdown at down_full_ratio: 6"], [3, 4.61, 3, 6, "head-on at full speed: 6"], [0, 0.00, 3, 3, "not resolved: the base"],
		[3, 3.00, 0, 0, "jam.hitstop 0: off"], [2, 0.90, 0, 0, "jam.hitstop 0: off for a stumble too"], [3, 3.00, 6, 6, "jam.hitstop 6: the cap"],
		[2, 0.45, 6, 2, "jam.hitstop 6: the lightest stumble 2"], [2, 0.45, 1, 1, "jam.hitstop 1: never under 1"]]
	for r: Array in rows:
		_eq(_for(int(r[0]), _f32(float(r[1])), int(r[2])), int(r[3]), String(r[4]))
	var last: int = 0
	for i: int in range(40, 501):
		var ratio: float = _f32(float(i) / 100.0)
		var fr: int = _for(3 if ratio >= 1.0 else 2, ratio, 3)
		if fr < last:
			_fails.append("the hold shrinks at ratio %.2f: %d after %d" % [ratio, fr, last])
			break
		last = fr
	_eq(last, 6, "the sweep ends on 6 frames")
	_eq(_for(3, 1.0, 3), 2, "the smallest knockdown holds 2")
	var seen: Array = [false, false, false, false, false, false, false]
	for i: int in range(100, 301):
		seen[clampi(_for(3, _f32(float(i) / 100.0), 3), 0, 6)] = true
	_t(seen[2] and seen[3] and seen[4] and seen[5] and seen[6] and not seen[0] and not seen[1], "2..6 frames each belong to a knockdown between ratio 1.0 and 3.0")
	_eq(SHOW.hit_stop_frames(), 3, "ships: jam.hitstop 3")
	_end("hitstop.frames")


func _skaters() -> Array:
	var sk: Array = []
	for i: int in range(6):
		sk.append({"Index": i, "ContactOutcome": 0, "ContactRatio": 0.0, "ContactBy": -1, "bRecoilThisFrame": false})
	return sk


func _ev(ename: String, who: int, strength: float, kind: String) -> Dictionary:
	return {"Name": ename, "Who": who, "Strength": strength, "Kind": kind}


func _case_pick() -> void:
	var human: int = 0
	# 1
	var sk: Array = _skaters()
	sk[human]["ContactOutcome"] = 2; sk[human]["ContactRatio"] = _f32(0.8); sk[human]["ContactBy"] = 4
	var p: Dictionary = SHOW.hit_stop_pick(sk, [_ev("check", 4, 0.45, "side_l")], human, 0.4)
	_t(p["Victim"] == human and p["Checker"] == 4 and p["Outcome"] == 2 and is_equal_approx(p["Ratio"], _f32(0.8)), "1 a stumble the human takes: victim, checker, outcome, ratio")
	_t(is_equal_approx(p["Strength"], 0.45) and p["Kind"] == "stumble", "1 its check event's strength and the kind stumble")
	_eq(_for(p["Outcome"], p["Ratio"], 3), 2, "1 held 2 frames")
	# 2
	sk = _skaters()
	sk[human]["ContactOutcome"] = 2; sk[human]["ContactRatio"] = 0.5; sk[human]["ContactBy"] = 4
	sk[2]["ContactOutcome"] = 3; sk[2]["ContactRatio"] = 2.0; sk[2]["ContactBy"] = 5
	p = SHOW.hit_stop_pick(sk, [_ev("check", 4, 0.3, "side_l"), _ev("check", 5, 0.9, "front"), _ev("knockdown", 2, 0.9, "check")], human, 0.4)
	_t(p["Victim"] == human and p["Checker"] == 4 and p["Outcome"] == 2, "2 a bot-on-bot knockdown and a stumble of the human: the stumble is picked")
	_t(is_equal_approx(p["Strength"], 0.3) and _for(p["Outcome"], p["Ratio"], 3) == 1, "2 its own strength, 1 frame")
	# 3
	sk = _skaters()
	sk[human]["ContactOutcome"] = 3; sk[human]["ContactRatio"] = _f32(1.4); sk[human]["ContactBy"] = 4
	sk[2]["ContactOutcome"] = 3; sk[2]["ContactRatio"] = 3.0; sk[2]["ContactBy"] = 5
	p = SHOW.hit_stop_pick(sk, [_ev("check", 4, 0.5, "side_l"), _ev("knockdown", human, 0.5, "check"), _ev("check", 5, 1.0, "front"), _ev("knockdown", 2, 1.0, "check")], human, 0.4)
	_t(p["Victim"] == human and p["Checker"] == 4 and p["Kind"] == "side_l" and is_equal_approx(p["Strength"], 0.5) and is_equal_approx(p["Ratio"], _f32(1.4)), "3 two knockdowns: the human's fall is picked, not the last one")
	_eq(_for(p["Outcome"], p["Ratio"], 3), 3, "3 held 3 frames")
	# 4
	sk = _skaters()
	sk[2]["ContactOutcome"] = 3; sk[2]["ContactRatio"] = 2.0; sk[2]["ContactBy"] = 5
	_eq(SHOW.hit_stop_pick(sk, [_ev("check", 5, 0.9, "front"), _ev("knockdown", 2, 0.9, "check")], human, 0.4)["Victim"], -1, "4 a knockdown between two bots holds nothing")
	# 5
	sk = _skaters()
	sk[3]["ContactOutcome"] = 3; sk[3]["ContactRatio"] = _f32(2.34); sk[3]["ContactBy"] = human
	var ev: Array = [_ev("check", human, 0.8, "front"), _ev("knockdown", 3, 0.8, "check")]
	p = SHOW.hit_stop_pick(sk, ev, human, 0.4)
	_t(p["Victim"] == 3 and p["Checker"] == human and p["Outcome"] == 3 and p["Kind"] == "front" and _for(p["Outcome"], p["Ratio"], 3) == 5, "5 a knockdown the human lands: 5 frames")
	var q: Dictionary = SHOW.hit_stop_pick(_skaters(), ev, human, 0.4)
	_t(q["Victim"] == 3 and q["Checker"] == human and q["Outcome"] == 0 and _for(q["Outcome"], q["Ratio"], 3) == 3, "5 contact.momentum false: the check event names the checker, the base holds")
	# 6
	sk = _skaters()
	sk[human]["bRecoilThisFrame"] = true
	sk[3]["ContactOutcome"] = 1; sk[3]["ContactBy"] = human
	p = SHOW.hit_stop_pick(sk, [], human, 0.4)
	_t(p["Victim"] == human and p["Checker"] == 3 and p["Kind"] == "bounce" and _for(p["Outcome"], p["Ratio"], 3) == 1, "6 the human's bounce: with the skater it bounced off, 1 frame")
	_eq(SHOW.hit_stop_pick(_skaters(), [_ev("knockdown", human, 1.0, "shotgun")], human, 0.4)["Victim"], -1, "6 a knockdown by the shotgun is not a check")
	_end("hitstop.pick")


func _case_puck_show() -> void:
	_t(SHOW.PUCK_SHOW and SHOW.PUCK_CALLS, "ships: the shown carrier and the play calls")
	var r: Array = SHOW.shown_carrier(-1, 3, 3, false, false, 0.0, 0.0, 6, 0)
	_eq(r[0], 3, "the sim's carrier is the shown one")
	r = SHOW.shown_carrier(3, 7, 7, true, false, 1.0, 1.6, 6, r[1])
	_eq(r[0], 7, "a change of hands the sim names is taken at once")
	_eq(r[1], 0, "nothing kept while the sim names him")
	r = SHOW.shown_carrier(7, -1, 7, true, false, 1.9, 1.6, 6, r[1])
	_eq(r[0], 7, "a one-frame drop-out is bridged")
	_eq(r[1], 1, "one frame kept")
	for i: int in range(5):
		r = SHOW.shown_carrier(7, -1, 7, true, false, 1.9, 1.6, 6, r[1])
	_eq(r[1], 6, "six frames kept")
	_eq(SHOW.shown_carrier(7, -1, 7, true, false, 1.9, 1.6, 6, r[1])[0], -1, "the seventh frame shows nobody")
	_eq(SHOW.shown_carrier(7, -1, 7, false, false, 1.0, 1.6, 6, 0)[0], -1, "down or hit: not kept")
	_eq(SHOW.shown_carrier(7, -1, 7, true, true, 1.0, 1.6, 6, 0)[0], -1, "he shot or passed: not kept")
	_eq(SHOW.shown_carrier(7, -1, 2, true, false, 1.0, 1.6, 6, 0)[0], -1, "another man touched it: not kept")
	_eq(SHOW.shown_carrier(7, -1, 7, true, false, 1.6 * SHOW.KEEP_REACH_K + 0.01, 1.6, 6, 0)[0], -1, "the puck beyond 1.35 of his reach: not kept")
	_eq(SHOW.shown_carrier(7, -1, 7, true, false, 1.0, 1.6, 0, 0)[0], -1, "jam.puck.Keep 0: the sim's carrier exactly")
	_eq(SHOW.shown_carrier(-1, -1, 7, true, false, 1.0, 1.6, 6, 0)[0], -1, "nobody before, nobody now")
	_eq(SHOW.PUCK_SETTLE, 0, "ships: a stick-to-stick change is shown at once")
	var s: Array = [0, -1, 0]
	for i: int in range(4):
		s = SHOW.settled(3, 7, true, false, 4, 2, s[1], s[2])
		_eq(s[0], 3, "the first four frames of another stick: the man before is still shown")
	s = SHOW.settled(3, 7, true, false, 4, 2, s[1], s[2])
	_eq(s[0], 7, "the fifth: the new man")
	_eq(s[2], 0, "and the count is cleared")
	s = SHOW.settled(3, 7, true, false, 4, 2, s[1], s[2]); s = SHOW.settled(3, 7, true, false, 4, 2, s[1], s[2])
	s = SHOW.settled(3, 3, true, false, 4, 2, s[1], s[2])
	_eq(s[0], 3, "back to the man before within the four")
	_eq(s[1], -1, "and nothing is pending")
	for i: int in range(3):
		s = SHOW.settled(3, 7, true, false, 4, 2, s[1], s[2])
	s = SHOW.settled(3, 5, true, false, 4, 2, s[1], s[2])
	_eq(s[0], 3, "a third man starts his own count")
	_eq(s[2], 1, "his first frame")
	_eq(SHOW.settled(-1, 7, false, false, 4, 0, -1, 0)[0], 7, "jam.puck.SettleLoose 0: from a loose puck at once")
	_eq(SHOW.PUCK_SETTLE_LOOSE, 2, "ships: a loose puck is shown on a stick after 2 frames")
	s = SHOW.settled(-1, 7, false, false, 4, 2, -1, 0)
	_eq(s[0], -1, "a loose puck touched: nobody shown on the first frame")
	s = SHOW.settled(-1, 7, false, false, 4, 2, s[1], s[2])
	_eq(s[0], -1, "nor on the second")
	s = SHOW.settled(-1, 7, false, false, 4, 2, s[1], s[2])
	_eq(s[0], 7, "the third: his")
	s = SHOW.settled(-1, 7, false, false, 4, 2, s[1], s[2])
	s = SHOW.settled(-1, -1, false, false, 4, 2, s[1], s[2])
	_eq(s[0], -1, "a touch of one frame and loose again: never shown")
	_eq(s[1], -1, "and nothing is pending after it")
	_eq(SHOW.settled(-1, 0, false, true, 4, 2, s[1], s[2])[0], 0, "the human holding a play on a loose puck: at once")
	_eq(SHOW.settled(3, -1, true, false, 4, 2, -1, 0)[0], -1, "to a loose puck: at once")
	_eq(SHOW.settled(3, 7, false, false, 4, 2, -1, 0)[0], 7, "the man before is down, hit or released it: at once")
	_eq(SHOW.settled(3, 7, true, true, 4, 2, -1, 0)[0], 7, "the new man holds or releases a play: at once")
	_eq(SHOW.settled(3, 7, true, false, 0, 2, -1, 0)[0], 7, "jam.puck.Settle 0: at once")
	# the drawn place (thirdjam's cm vectors (x, y, z) are (x, z, y) x 0.01 here; the rules are the same in any unit)
	var blade: Vector3 = Vector3(1.0, 0.04, 0.0)
	var off: Vector3 = Vector3(0.6, 0.0, 0.0)
	_t(SHOW.drawn(blade, off, 0.0, SHOW.BLEND_IN_FRAMES).is_equal_approx(blade + off), "the frame of the pickup: still where it was drawn")
	_t(SHOW.drawn(blade, off, 1.0, SHOW.BLEND_IN_FRAMES).distance_to(blade) < 0.5 * off.length(), "a frame later: most of the way")
	_t(SHOW.drawn(blade, off, float(SHOW.BLEND_IN_FRAMES), SHOW.BLEND_IN_FRAMES).is_equal_approx(blade), "after the blend: on the blade")
	_t(SHOW.drawn(blade, off, 0.0, 0).is_equal_approx(blade), "no blend frames: on the blade at once")
	_eq(SHOW.PUCK_BLEND_BODY, 4, "ships: a take by the skates or the body runs to the blade over 4 frames")
	_eq(SHOW.pickup_blend_frames(false, 4), SHOW.BLEND_IN_FRAMES, "the stick took it: two frames")
	_eq(SHOW.pickup_blend_frames(true, 4), 4, "the skates or the body took it: four")
	_eq(SHOW.pickup_blend_frames(true, 0), SHOW.BLEND_IN_FRAMES, "never shorter than a stick take")
	_eq(SHOW.shown_while(3, true), -1, "play stopped: nobody is shown as carrier")
	_eq(SHOW.shown_while(3, false), 3, "play on: the shown carrier stands")
	_eq(SHOW.goal_drop(0.9, 0.0), 0.9, "a goal: the drawn puck starts at the height it crossed the line at")
	_t(SHOW.goal_drop(0.9, 0.5 * SHOW.GOAL_DROP_SECONDS) > 0.6, "half way through the drop: most of the height still")
	_eq(SHOW.goal_drop(0.9, SHOW.GOAL_DROP_SECONDS), 0.0, "after the drop: on the ice")
	_eq(SHOW.goal_drop(0.9, 5.0), 0.0, "and it stays there")
	_t(SHOW.BLEND_IN_FRAMES == 2 and SHOW.BLEND_OUT_FRAMES == 0, "a pickup blends over two frames; a release does not")
	_t(SHOW.drawn(blade, off, 0.0, SHOW.BLEND_OUT_FRAMES).is_equal_approx(blade), "a released puck: at the sim's place on the frame of the release")
	# AJamSkater::CarryAimDeg (the pawn's)
	_eq(float(PAWN.PUCK_CARRY_AIM), 30.0, "ships: the carry floor is 30 degrees")
	_eq(float(PAWN.PUCK_CARRY_REACH), 1.6, "ships: the carried stick reaches 1.6 m")
	var aims: Array = [[5.0, 0.0, false, 0, 5.0, "not carrying: the aim as it is"], [1.0, 0.0, true, 0, 45.0, "a hair to the forehand: the forehand floor"],
		[-1.0, 0.0, true, 0, -30.0, "a hair to the backhand: the backhand floor"], [-8.0, 45.0, true, 0, 45.0, "on the forehand, a little to the backhand: stays"],
		[-15.0, 45.0, true, 0, -30.0, "on the forehand, clearly to the backhand: crosses"], [10.0, -30.0, true, 0, -30.0, "on the backhand, a little to the forehand: stays"],
		[20.0, -30.0, true, 0, 45.0, "on the backhand, clearly to the forehand: crosses"], [47.0, 45.0, true, 0, 47.0, "outside the forehand floor: as it is"],
		[-33.0, -30.0, true, 0, -33.0, "outside the backhand floor: as it is"], [6.0, 45.0, true, -1, -30.0, "the sim's puck on his right: the backhand floor"],
		[-6.0, -30.0, true, 1, 45.0, "the sim's puck on his left: the forehand floor"]]
	for a: Array in aims:
		_eq(PAWN.carry_aim_deg(float(a[0]), float(a[1]), bool(a[2]), 30.0, 45.0, int(a[3])), float(a[4]), String(a[5]))
	_eq(PAWN.carry_aim_deg(0.0, 0.0, true, 0.0, 0.0, 0), 0.0, "both floors at 0: off")
	_eq(SHOW.side_for(0.20, 1), -1, "the puck 20 cm to his right: the right side")
	_eq(SHOW.side_for(0.05, 1), 1, "the puck 5 cm to his right: the side of before")
	_eq(SHOW.side_for(-0.20, -1), 1, "the puck 20 cm to his left: the left side")
	_t(SHOW.capped(Vector3(1, 0.04, 0), Vector3(1, 0.04, 0.3), 0.45).is_equal_approx(Vector3(1, 0.04, 0.3)), "a socket 30 cm from the sim's puck: on the socket")
	_t(SHOW.capped(Vector3(1, 0.04, 0), Vector3(1, 0.04, 0.9), 0.45).is_equal_approx(Vector3(1, 0.04, 0.45)), "a socket 90 cm from it: 45 cm on the way")
	_t(SHOW.capped(Vector3(1, 0.04, 0), Vector3(1, 0.04, 0.9), 0.0).is_equal_approx(Vector3(1, 0.04, 0.9)), "the cap at 0: on the socket")
	_eq(SHOW.PUCK_MAX_OFF_M, 0.0, "ships: no cap")
	_t(not SHOW.PUCK_CARRY_SIDE, "ships: the floor's side is the stick's own")
	_eq(SHOW.pass_charge01(0, 30), 0.0, "no hold: 0")
	_eq(SHOW.pass_charge01(-1, 30), 0.0, "a lost puck's negative count: 0")
	_eq(SHOW.pass_charge01(15, 30), 0.5, "half the hold: 0.5")
	_eq(SHOW.pass_charge01(30, 30), 1.0, "the full hold: 1")
	_eq(SHOW.pass_charge01(45, 30), 1.0, "past it: 1")
	_t(SHOW.may_call(1000, -100000, 3, -1), "the first ask")
	_t(not SHOW.may_call(1010, 1000, 4, 3), "another mate 10 frames later: too soon")
	_t(SHOW.may_call(1000 + SHOW.CALL_EVERY_FRAMES, 1000, 4, 3), "another mate half a second later")
	_t(not SHOW.may_call(1060, 1000, 3, 3), "the same mate a second later: not yet")
	_t(SHOW.may_call(1000 + SHOW.CALL_SAME_MATE_FRAMES, 1000, 3, 3), "the same mate after 2.5 s")
	_t(not SHOW.may_call(5000, 1000, -1, 3), "nobody to call")
	_end("puck.show")


func _state(i: int, team: int, pos: Vector2) -> Dictionary:
	return {"Index": i, "Team": team, "bHuman": i == 0, "Pos": pos, "PrevPos": pos, "Yaw": 0.0, "BladePos": pos + Vector2(1.2, 0.0), "CanAct": true, "IsDown": false,
		"bShotThisFrame": false, "bPassThisFrame": false, "ChargeFrames": 0, "PassChargeFrames": 0, "PassesReceived": 0,
		"ContactOutcome": 0, "ContactRatio": 0.0, "ContactBy": -1, "bRecoilThisFrame": false}


func _snap(frame: int, carrier: int, puck: Vector2, sk: Array, events: Array = []) -> Dictionary:
	return {"Frame": frame, "Phase": 0, "HumanIndex": 0, "Carrier": carrier, "Skaters": sk, "Events": events,
		"Puck": {"Pos": puck, "PrevPos": puck, "Z": 0.0, "PrevZ": 0.0, "LastTouch": carrier}}


## A pawn of the real script that takes the show's calls; its apply_sim_frame is not run here (made-up states).
func _pawn(i: int, pos: Vector2) -> Array:
	var pawn: Node3D = PAWN.new()
	var fig: Fig = Fig.new()
	pawn.add_child(fig)
	pawn.set("sim_index", i)
	pawn.set("figure", fig)
	pawn.set("record", true)
	pawn.position = Vector3(pos.x, 0.0, pos.y)
	pawn.rotation = Vector3(0.0, -PI * 0.5, 0.0)          # yaw 0: the figure's -Z looks along +x
	return [pawn, fig]


func _case_object() -> void:
	var show: RefCounted = SHOW.new()
	var sk: Array = [_state(0, 0, Vector2(0, 0)), _state(1, 0, Vector2(8, 0)), _state(2, 1, Vector2(4, 3))]
	var rows: Array = [_pawn(0, Vector2(0, 0)), _pawn(1, Vector2(8, 0)), _pawn(2, Vector2(4, 3))]
	var pawns: Array = [rows[0][0], rows[1][0], rows[2][0]]
	var socket0: Vector3 = Vector3(0.5, SHOW.PUCK_HALF_HEIGHT_M, 0.0)
	# a loose puck: nobody shown, drawn at the sim's place
	var puck_at: Vector2 = Vector2(0.9, 0.2)
	show.step_sim(_snap(1, -1, puck_at, sk), pawns)
	show.after_pawns(_snap(1, -1, puck_at, sk), pawns)
	var d: Dictionary = show.render(_snap(1, -1, puck_at, sk), pawns, 1.0)
	_t((d["puck"] as Vector3).is_equal_approx(Vector3(0.9, 0.04, 0.2)) and d["shown"] == -1, "a loose puck: at the sim's place, nobody shown")
	_eq((rows[0][1] as Fig).got.get("SetLookAtPuck", 0), 1, "SetLookAtPuck(false) once on the human's figure")
	_eq((rows[1][1] as Fig).got.get("SetLookAtPuck", 0), 0, "... and on no other")
	_eq((rows[2][1] as Fig).got.get("SetWindupTakes", 0), 1, "SetWindupTakes(true, 8) once on every figure")
	_t((pawns[0].get("show_calls") as Array).size() == 2, "the pawn records the show's calls apart from its own (show_calls)")
	# the sim names the human: shown after SettleLoose frames (the third), then the puck runs to his socket over 2 frames
	var shown_at: int = -1
	for f: int in range(2, 8):
		show.step_sim(_snap(f, 0, puck_at, sk), pawns)
		if shown_at < 0 and show.get_shown() == 0:
			shown_at = f
		show.after_pawns(_snap(f, 0, puck_at, sk), pawns)
		d = show.render(_snap(f, 0, puck_at, sk), pawns, 1.0)
		if f == shown_at:
			_t((d["puck"] as Vector3).is_equal_approx(Vector3(0.9, 0.04, 0.2)) and not bool(d["on_blade"]), "the frame of the pickup: still where it was drawn")
		if f == shown_at + 1:
			_t((d["puck"] as Vector3).distance_to(socket0) < 0.5 * Vector3(0.9, 0.04, 0.2).distance_to(socket0), "a frame later: most of the way to the blade")
	_eq(shown_at, 4, "a loose puck is shown on his stick on the third frame the sim names him")
	_t((d["puck"] as Vector3).is_equal_approx(socket0) and bool(d["on_blade"]) and d["drawn_carrier"] == 0, "after the blend: on his puck_socket")
	_eq((rows[0][1] as Fig).got.get("SetWindupTakes", 0), 1, "the wind-up takes are told once, not every frame")
	# a held pass: SetPassCharge every frame, 0 once at its end; a mate's reception: PlayReceive once
	sk[0]["PassChargeFrames"] = 15
	show.step_sim(_snap(8, 0, puck_at, sk), pawns)
	show.step_sim(_snap(9, 0, puck_at, sk), pawns)
	sk[0]["PassChargeFrames"] = 0
	sk[0]["bPassThisFrame"] = true
	show.step_sim(_snap(10, -1, puck_at, sk), pawns)
	_eq(show.get_shown(), -1, "he passed: the puck is let go at once")
	sk[0]["bPassThisFrame"] = false
	show.step_sim(_snap(11, -1, puck_at, sk), pawns)
	_eq((rows[0][1] as Fig).got.get("SetPassCharge", 0), 3, "SetPassCharge on the two held frames and 0 once after")
	sk[1]["PassesReceived"] = 1
	show.step_sim(_snap(12, 1, Vector2(8.5, 0), sk), pawns)
	sk[1]["PassesReceived"] = 2
	show.step_sim(_snap(13, 1, Vector2(8.5, 0), sk), pawns)
	_eq((rows[1][1] as Fig).got.get("PlayReceive", 0), 1, "PlayReceive once a reception (a second count within 20 frames is the same catch)")
	# PlayCallForPass with a target given: the mate 8 m ahead and open asks; the same mate not again within 150 frames
	show.pass_target_of = func(_h: int, _dir: Vector2, _hold: int) -> int: return 1
	for f: int in range(14, 60):
		show.step_sim(_snap(f, 0, puck_at, sk), pawns)
	_eq((rows[1][1] as Fig).got.get("PlayCallForPass", 0), 1, "the mate the pass would go to calls once (the same mate again after 150 frames)")
	show.pass_target_of = Callable()
	# a knockdown the human lands on skater 2: both hold 5 frames, the puck too, the camera sits on the hit frame
	sk[2]["ContactOutcome"] = 3; sk[2]["ContactRatio"] = 2.34; sk[2]["ContactBy"] = 0
	var hit: Array = [_ev("check", 0, 0.8, "front"), _ev("knockdown", 2, 0.8, "check")]
	show.step_sim(_snap(99, -1, Vector2(2, 2), sk), pawns)
	show.after_pawns(_snap(99, -1, Vector2(2, 2), sk), pawns)
	var before: Vector3 = show.render(_snap(99, -1, Vector2(2, 2), sk), pawns, 1.0)["puck"]
	_t(before.is_equal_approx(Vector3(2.0, 0.04, 2.0)), "a released puck is drawn at the sim's place at once")
	var res: Dictionary = show.step_sim(_snap(100, -1, Vector2(2.5, 2), sk, hit), pawns)
	_eq(res["hit_stop"], 5, "a knockdown at ratio 2.34 the human lands holds 5 frames")
	_eq(int(pawns[0].get("_hold_armed")), 5, "the checker's pawn is told (begin_hit_stop)")
	_eq(int(pawns[2].get("_hold_armed")), 5, "the victim's pawn is told")
	_eq(int(pawns[1].get("_hold_armed")), 0, "a third skater is not")
	show.after_pawns(_snap(100, -1, Vector2(2.5, 2), sk, hit), pawns)
	d = show.render(_snap(100, -1, Vector2(2.5, 2), sk, hit), pawns, 1.0)
	_t(bool(d["held"]) and (d["puck"] as Vector3).is_equal_approx(before), "the puck holds where it was last drawn")
	_t(is_equal_approx(show.camera_alpha(100, 0.3), 1.0) and is_equal_approx(show.camera_alpha(104, 0.3), 1.0) and is_equal_approx(show.camera_alpha(105, 0.3), 0.3), "the camera sits on the hit frame for frames 100..104")
	_t(not show.presentation_held(100) and show.presentation_held(101) and show.presentation_held(104) and not show.presentation_held(105), "the hit frame is pushed, the four after are not")
	sk[2]["ContactOutcome"] = 0
	var held_frames: int = 1
	var caught_up: int = -1
	for f: int in range(101, 112):
		var sn: Dictionary = _snap(f, -1, Vector2(2.5, 2), sk)
		_eq(show.step_sim(sn, pawns)["hit_stop"], 0, "no second hold")
		show.after_pawns(sn, pawns)
		d = show.render(sn, pawns, 1.0)
		if bool(d["held"]):
			held_frames += 1
		elif caught_up < 0 and (d["puck"] as Vector3).is_equal_approx(Vector3(2.5, 0.04, 2.0)):
			caught_up = f
	_eq(held_frames, 5, "the puck is held for the 5 frames")
	_eq(caught_up, 109, "and is back at the live place 5 frames after the hold (the catch-up)")
	# a goal pause: nobody is shown
	show.step_sim(_snap(120, 0, puck_at, sk), pawns); show.step_sim(_snap(121, 0, puck_at, sk), pawns); show.step_sim(_snap(122, 0, puck_at, sk), pawns)
	_eq(show.get_shown(), 0, "shown again")
	var gp: Dictionary = _snap(123, 0, puck_at, sk)
	gp["Phase"] = 1
	show.step_sim(gp, pawns)
	_eq(show.get_shown(), -1, "play stopped (the goal pause): nobody is shown as carrier")
	# a restart: the frame goes back, the state is new
	show.step_sim(_snap(1, -1, puck_at, sk), pawns)
	_t(show.get_shown() == -1 and not show.presentation_held(1), "a restart (the frame went back): reset")
	for row: Array in rows:
		(row[0] as Node).free()
	_end("show.object")


func _case_core() -> void:
	if not ClassDB.class_exists("RinkCore"):
		_fails.append("RinkCore is not registered")
		_end("show.core600")
		return
	var cart_text: String = FileAccess.get_file_as_string("res://cores/rink/native/content/Cartridges/hockey.regular.cartridge.json")
	var stream: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://cores/rink/proof/rawhand.seed5.600.stream.json"))
	var core: RefCounted = ClassDB.instantiate("RinkCore")
	var err: String = core.call("load_cartridge", cart_text)
	if err != "" or not (stream is Array):
		_fails.append("cartridge or stream: %s" % err)
		_end("show.core600")
		return
	core.call("set_difficulty", "pro")
	core.call("set_human_mode", "raw")
	core.call("reset", 5)
	var show: RefCounted = SHOW.new()
	show.cfg = SHOW.config_of(JSON.parse_string(cart_text))
	var pawns: Array = []
	var figs: Array = []
	var frames: int = 0
	var shown_frames: int = 0
	var on_blade: int = 0
	var worst_blade: float = 0.0
	var worst_loose: float = 0.0
	var loose_frames: int = 0
	var blend_frames: int = 0
	var holds: int = 0
	var hold_frames: int = 0
	var changes: int = 0
	var flag_wrong: int = 0
	var sim_carry: int = 0
	var sim_carry_shown: int = 0
	var last_shown: int = -1
	var carry_stopped: int = 0
	var carry_waiting: int = 0
	var bridged: int = 0
	var catching: int = 0
	for entry: Variant in (stream as Array):
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
			for i: int in range(sk.size()):
				var pawn: Node3D = PAWN.new()
				var fig: Fig = Fig.new()
				root.add_child(pawn)
				pawn.add_child(fig)
				pawn.call("init_skater", i, int(sk[i]["Team"]), Color(0.1, 0.2, 0.8), i + 1, fig)
				pawns.append(pawn)
				figs.append(fig)
		var res: Dictionary = show.call("step_sim", snap, pawns)
		if int(res["hit_stop"]) > 0:
			holds += 1
			hold_frames += int(res["hit_stop"])
		var told: int = 0
		for i: int in range(pawns.size()):
			(pawns[i] as Node3D).call("apply_sim_frame", sk[i], int(snap["Frame"]))
			if bool((pawns[i] as Node3D).call("is_told_has_puck")):
				told += 1
				if i != int(res["shown"]):
					flag_wrong += 1
		if told > 1 or (int(res["shown"]) >= 0 and told != 1):
			flag_wrong += 1
		show.call("after_pawns", snap, pawns)
		for i: int in range(pawns.size()):
			(pawns[i] as Node3D).call("apply_render", sk[i], 1.0)
		var d: Dictionary = show.call("render", snap, pawns, 1.0)
		frames += 1
		var shown: int = int(d["shown"])
		if shown != last_shown:
			changes += 1
			last_shown = shown
		var stopped: bool = int(snap["Phase"]) == 1 or int(snap["Phase"]) == 2
		if int(snap["Carrier"]) >= 0:
			sim_carry += 1
			if shown == int(snap["Carrier"]):
				sim_carry_shown += 1
			elif stopped:
				carry_stopped += 1
			elif shown < 0:
				carry_waiting += 1
		elif shown >= 0:
			bridged += 1
		var puck_at: Vector3 = d["puck"]
		var sim_at: Vector3 = SHOW.puck_live(snap["Puck"], 1.0)
		if bool(d["held"]):
			pass
		elif (show.get("_puck_catch_up_left") as int) > 0:
			catching += 1              # the hit-stop's catch-up: between the held place and the live one
		elif int(d["drawn_carrier"]) >= 0:
			shown_frames += 1
			var sock: Vector3 = (pawns[int(d["drawn_carrier"])] as Node3D).call("puck_socket_world")
			var off: float = Vector2(puck_at.x - sock.x, puck_at.z - sock.z).length()
			if bool(d["on_blade"]):
				on_blade += 1
				worst_blade = maxf(worst_blade, off)
			else:
				blend_frames += 1
		else:
			loose_frames += 1
			worst_loose = maxf(worst_loose, Vector2(puck_at.x - sim_at.x, puck_at.z - sim_at.z).length())     # in the plane: after a goal the drawn puck drops to the ice
	var calls: Dictionary = {}
	for fig: Fig in figs:
		for k: String in fig.got.keys():
			calls[k] = int(calls.get(k, 0)) + int(fig.got[k])
	_eq(frames, 600, "600 frames stepped")
	_eq(flag_wrong, 0, "the figure told it has the puck is the shown carrier, one at most")
	_t(worst_blade < 1e-4, "on the blade the drawn puck is on his puck_socket (worst %.5f m)" % worst_blade)
	_t(worst_loose < 1e-4, "with nobody shown the drawn puck is at the sim's place (worst %.5f m)" % worst_loose)
	_t(shown_frames > 0 and loose_frames > 0, "the run has both carried (%d) and loose (%d) frames" % [shown_frames, loose_frames])
	_eq(int(calls.get("SetWindupTakes", 0)), figs.size(), "SetWindupTakes once a figure")
	_eq(int(calls.get("SetLookAtPuck", 0)), 1, "SetLookAtPuck once")
	print("tl.skater.show_case/1 ", JSON.stringify({"frames": frames, "drawn_on_a_man": shown_frames, "on_blade": on_blade, "in_blend": blend_frames, "loose": loose_frames,
		"shown_changes": changes, "sim_carry_frames": sim_carry, "sim_carry_shown_same": sim_carry_shown, "sim_carry_play_stopped": carry_stopped, "sim_carry_not_shown_yet": carry_waiting,
		"shown_with_no_sim_carrier": bridged, "catch_up_frames": catching, "hit_stops": holds, "hit_stop_frames": hold_frames,
		"last_pick": show.get("last_pick"), "calls": calls, "state_hash": core.call("state_hash_hex")}))
	for p: Node3D in pawns:
		p.free()
	_end("show.core600")


func _init() -> void:
	_case_frames()
	_case_pick()
	_case_puck_show()
	_case_object()
	_case_core()
	print("skater_show_case: %d failed" % _failed)
	quit(1 if _failed > 0 else 0)
