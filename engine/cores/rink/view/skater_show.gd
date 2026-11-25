extends RefCounted
## What thirdjam's game mode does around its pawns for the eye, and K1's GAMEMODE.md gives to the figure lane (rows 20
## and 23): the hit-stop (which hit holds the picture, for how many frames, on whom) and the carrier the screen shows
## (FJamPuckShow: whose figure is told it has the puck, where the puck is drawn, the play calls by name). Presentation
## only: it reads RinkCore.snapshot() after a step and writes nothing back. "S" = thirdjam's Game/Source, HEAD 8dc713c6.
##   hit-stop      S/JamCore/Private/JamPawns.cpp:144-232 (HitStopFrames, HitStopFramesFor, HitStopPick, BeginHitStop),
##                 S/JamGame/Private/HokejGameMode.cpp:1753-1775 (HitStopRoute), :1707, :1710, :1748-1750;
##                 the puck's hold S/JamCore/Private/JamPawns.cpp:984-1017 (AJamPuck::BeginHitStop, StepSimFrame, Place)
##   shown carrier S/JamGame/Public/PuckRead.h, S/JamGame/Private/PuckRead.cpp:85-333 (FJamPuckShow)
##   wind-up takes S/JamGame/Private/HitRead.cpp:644-667 (AJamHitRead::TellTakes)
##
## ONE SIM FRAME, in thirdjam's order (HokejGameMode.cpp:1665-1707, :1733-1750):
##   core.step(); snap = core.snapshot()
##   show.step_sim(snap, pawns)          # HitStopRoute, then FJamPuckShow::StepSim: BEFORE the pawns apply the frame
##   pawn.apply_sim_frame(s, frame)      # every pawn
##   show.after_pawns(snap, pawns)       # AJamHitRead::TellTakes, AJamPuck::StepSimFrame
##   pawn.apply_render(s, alpha); figure.tick()        # every pawn (each drawn frame)
##   d = show.render(snap, pawns, alpha) # FJamPuckShow::Render: d["puck"] is where the puck is drawn
## `pawns`: the skater pawns (skater_pawn.gd), any order; each is found by its `sim_index`.
## Space: the pawns' own (rink metres, Vector3(Pos.x, height, Pos.y)); thirdjam's centimetres are metres here.
##
## DEVIATIONS from thirdjam (each with its reason):
##   - PlayCallForPass needs UJamSim::HumanPassTarget (JamSim.cpp:3213: the pass's flight solved against each mate),
##     which the snapshot does not carry. `pass_target_of` (a Callable: human index, stick direction, hold frames ->
##     the mate's index or -1) supplies it; without one no mate calls for the pass. Everything after the target (ahead,
##     open, the two waits) is ported.
##   - UJamSim::CarrierReachM (JamSim.cpp:862) is taken from the cartridge (shot.reach_m, stick.reach_m): a modifier
##     on the shot's reach (an effect on one skater) is not seen.
##   - the carried puck's late tick (AJamPuck::Tick, JamPawns.cpp:959-977: after the frame's animation the puck takes
##     the socket's place again) is not a second step: call `render` after the figures' `tick()` and the socket read
##     is this frame's pose already. Inside a pickup's blend (2 or 4 frames) thirdjam's target is the socket of the
##     pose before; ours is this frame's.
##   - the goal drop runs on thirdjam's world seconds; here on drawn frames / 60 (law: time is physics frames), or on
##     `now_s` when the caller draws more than once a sim frame.
##   - the log lines (JAMHITSTOP, JAMPUCK ...), the probe (jam.puck.Probe), the strips (jam.puck.Capture) and the
##     puck trail's User.Carried are not ported (`trail_carried` says what the trail would be told).
## NOT PORTED (lists in the lane's report): the whiff calls and the re-time of AJamHitRead (HitRead.cpp:754-841), which
## read FJamHitReadModel (the model of presses and hits, HitRead.h and HitRead.cpp:70-640).

# ---- thirdjam's console variables at their shipped defaults
const HIT_STOP: int = 3                  # jam.hitstop, JamPawns.cpp:144
const PUCK_SHOW: bool = true             # jam.puck.Show, PuckRead.cpp:14
const PUCK_KEEP: int = 6                 # jam.puck.Keep, :16
const PUCK_SETTLE: int = 0               # jam.puck.Settle, :18
const PUCK_SETTLE_LOOSE: int = 2         # jam.puck.SettleLoose, :20
const PUCK_BLEND_BODY: int = 4           # jam.puck.BlendBody, :22
const PUCK_CALLS: bool = true            # jam.puck.Calls, :24
const PUCK_CARRY_SIDE: bool = false      # jam.puck.CarrySide, :26
const PUCK_MAX_OFF_M: float = 0.0        # jam.puck.MaxOff (cm there), :28
const HIT_B_TAKES: int = 2               # jam.hit.BTakes, HitRead.cpp:43
# ---- FJamPuckShow's constants (PuckRead.h:28-41, :61)
const KEEP_REACH_K: float = 1.35
const BLEND_IN_FRAMES: int = 2
const BLEND_OUT_FRAMES: int = 0
const GOAL_DROP_SECONDS: float = 0.17
const RELEASE_NO_KEEP_FRAMES: int = 30
const SIDE_BAND_M: float = 0.08          # SideBandCm 8
const RECEIVE_EVERY_FRAMES: int = 20
const CALL_EVERY_FRAMES: int = 30
const CALL_SAME_MATE_FRAMES: int = 150
const POSSESS_FRESH_FRAMES: int = 6
const CALL_OPEN_M: float = 2.5           # PuckRead.cpp:206
const CALL_AHEAD_M: float = 3.0
const JUMP_CUT_M: float = 3.0            # PuckRead.cpp:319: a placed puck (a faceoff, a restart) cuts
# ---- the sim's (JamSim.h)
const CONTACT_NONE: int = 0              # UJamSim::ContactNone, JamSim.h:717-720
const CONTACT_BUMP: int = 1
const CONTACT_STUMBLE: int = 2
const CONTACT_DOWN: int = 3
const PHASE_GOAL_PAUSE: int = 1          # EJamSimPhase, JamSim.h:110-116
const PHASE_OVER: int = 2
const SKATER_RADIUS: float = 0.4         # UJamSim::SkaterRadius, JamSim.h:494
const PUCK_HALF_HEIGHT_M: float = 0.04   # AJamPuck::HalfHeightM, JamPawns.cpp:868

## The cartridge's numbers these rules read, with thirdjam's defaults (JamCartridge.h:159, :313, :356, :363, :396-399):
## see `config_of`.
var cfg: Dictionary = {"bump_ratio": 0.4, "down_ratio": 1.0, "down_full_ratio": 3.0, "shot_reach_m": 1.5, "stick_reach_m": 1.2,
	"saucer_half_frames": 8, "power_full_frames": 30}
## UJamSim::HumanPassTarget's stand-in: func(human: int, stick_dir: Vector2, hold_frames: int) -> int. See DEVIATIONS.
var pass_target_of: Callable = Callable()
var trail_carried: int = -1              # AJamPuck::SetTrailCarried's argument (1 carried, 0 loose), -1 not told yet
var last_pick: Dictionary = {}           # the last hit held: hit_stop_pick's answer plus "Frames" and "Frame"

# AHokejGameMode's (HokejGameMode.h:190)
var _hit_stop_start: int = -1
var _hit_stop_end: int = -1
# AJamPuck's hold (JamPawns.h)
var _puck_hold_total: int = 0
var _puck_hold_left: int = 0
var _puck_catch_up_left: int = 0
var _puck_held: Vector3 = Vector3.ZERO
var _puck_last_placed: Vector3 = Vector3.ZERO
var _puck_ever_placed: bool = false
# FJamPuckShow's (PuckRead.h:84-106)
var _shown: int = -1
var _kept: int = 0
var _pending: int = -1
var _pending_frames: int = 0
var _puck_side: int = 0
var _last_frame: int = -1
var _drawn_carrier: int = -1
var _change_frame_f: float = -1e9
var _change_blend: int = BLEND_IN_FRAMES
var _offset_at_change: Vector3 = Vector3.ZERO
var _last_drawn: Vector3 = Vector3.ZERO
var _was_stopped: bool = false
var _stopped_at_s: float = 0.0
var _ever_drawn: bool = false
var _prev_received: PackedInt32Array = PackedInt32Array()
var _last_receive_frame: PackedInt64Array = PackedInt64Array()
var _possess_frame: PackedInt64Array = PackedInt64Array()
var _possess_body: PackedByteArray = PackedByteArray()
var _last_release_frame: PackedInt64Array = PackedInt64Array()
var _charge_sent: Array = []
var _look_figure: Object = null
var _last_call_frame: int = -100000
var _last_call_mate: int = -1
var _draws: int = 0
# AJamHitRead::TellTakes' (HitRead.h)
var _takes_fig: Dictionary = {}          # sim index -> the figure told
var _takes_want: Dictionary = {}


## The numbers of a thirdjam cartridge (the parsed JSON) these rules read; an absent key keeps thirdjam's default
## (JamCartridge.cpp:1112, :1177, :1206, :1212, :1235-1238).
static func config_of(cartridge: Dictionary) -> Dictionary:
	var g: Dictionary = cartridge.get("game", {})
	var ct: Dictionary = g.get("contact", {})
	var ps: Dictionary = g.get("pass", {}) if g.get("pass") is Dictionary else {}
	return {
		"bump_ratio": float(ct.get("bump_ratio", 0.4)), "down_ratio": float(ct.get("down_ratio", 1.0)), "down_full_ratio": float(ct.get("down_full_ratio", 3.0)),
		"shot_reach_m": float((g.get("shot", {}) as Dictionary).get("reach_m", 1.5)), "stick_reach_m": float((g.get("stick", {}) as Dictionary).get("reach_m", 1.2)),
		"saucer_half_frames": int((ps.get("saucer", {}) as Dictionary).get("half_frames", 8)), "power_full_frames": int((ps.get("power", {}) as Dictionary).get("full_frames", 30)),
	}


# ====================================================================== the hit-stop (pure)
## AJamSkater::HitStopFrames (JamPawns.cpp:147-150).
static func hit_stop_frames() -> int:
	return clampi(HIT_STOP, 0, 6)


## AJamSkater::HitStopFramesFor (JamPawns.cpp:155-164). At base 3: a stumble 1 or 2, a knockdown 2 to 6 by the ratio; a
## bump holds nothing. `outcome`: ContactOutcome (0 none, 1 bump, 2 stumble, 3 down).
static func hit_stop_frames_for(outcome: int, ratio: float, bump_ratio: float, down_ratio: float, down_full_ratio: float, base: int) -> int:
	if base <= 0:
		return 0
	if outcome == CONTACT_NONE:
		return clampi(base, 0, 6)      # a knockdown the model did not resolve (contact.momentum false)
	var at3: float = 0.0
	if outcome == CONTACT_STUMBLE:
		at3 = 2.0 if ratio >= 0.5 * (bump_ratio + down_ratio) - 1e-6 else 1.0
	elif outcome == CONTACT_DOWN:
		at3 = lerpf(2.0, 6.0, clampf((ratio - down_ratio) / maxf(1e-6, down_full_ratio - down_ratio), 0.0, 1.0))
	else:
		return 0                       # a bump
	return clampi(int(floor(at3 * float(base) / 3.0 + 0.5)), 1, 6)     # FMath::RoundToInt32


static func _check_of(events: Array, who: int) -> Dictionary:
	for e: Dictionary in events:
		if String(e.get("Name", "")) == "check" and int(e.get("Who", -1)) == who:
			return e
	return {}


## AJamSkater::HitStopPick (JamPawns.cpp:166-226): the hit the hold is for. `sk`: the snapshot's Skaters, `events`: its
## Events. Returns FJamHitStopPick {Victim (-1 = nothing to hold), Checker, Outcome, Ratio, Strength, Kind}.
static func hit_stop_pick(sk: Array, events: Array, human: int, bump_ratio: float) -> Dictionary:
	var p: Dictionary = {"Victim": -1, "Checker": -1, "Outcome": CONTACT_NONE, "Ratio": 0.0, "Strength": 0.0, "Kind": ""}
	var last_checker: int = -1
	var last_kind: String = ""
	for e: Dictionary in events:
		if String(e.get("Name", "")) == "check":
			last_checker = int(e.get("Who", -1)); last_kind = String(e.get("Kind", ""))
	# 1. a knockdown by a check: the one the human took, else the one it landed
	for e: Dictionary in events:
		if String(e.get("Name", "")) != "knockdown" or String(e.get("Kind", "")) != "check":
			continue
		var who: int = int(e.get("Who", -1))
		var valid: bool = who >= 0 and who < sk.size()
		var resolved: bool = valid and int((sk[who] as Dictionary).get("ContactOutcome", 0)) == CONTACT_DOWN
		var checker: int = int((sk[who] as Dictionary).get("ContactBy", -1)) if (resolved and int((sk[who] as Dictionary).get("ContactBy", -1)) >= 0) else last_checker
		if who != human and checker != human:
			continue
		if int(p["Victim"]) == human:
			continue                   # the human's own fall is already picked
		p["Victim"] = who; p["Checker"] = checker; p["Outcome"] = CONTACT_DOWN if resolved else CONTACT_NONE
		p["Ratio"] = float((sk[who] as Dictionary).get("ContactRatio", 0.0)) if resolved else 0.0
		p["Strength"] = float(e.get("Strength", 0.0))
		p["Kind"] = last_kind
		var ce: Dictionary = _check_of(events, checker)
		if not ce.is_empty():
			p["Kind"] = String(ce.get("Kind", ""))
	if int(p["Victim"]) >= 0:
		return p
	# 2. a stumble (the read-outs name its victim): the one the human took, else the one it landed
	for pass_i: int in range(2):
		if int(p["Victim"]) >= 0:
			break
		for i: int in range(sk.size()):
			var s: Dictionary = sk[i]
			var idx: int = int(s.get("Index", i))
			if int(s.get("ContactOutcome", 0)) != CONTACT_STUMBLE or (idx != human if pass_i == 0 else int(s.get("ContactBy", -1)) != human):
				continue
			p["Victim"] = idx; p["Checker"] = int(s.get("ContactBy", -1)); p["Outcome"] = CONTACT_STUMBLE; p["Ratio"] = float(s.get("ContactRatio", 0.0))
			var ce2: Dictionary = _check_of(events, int(s.get("ContactBy", -1)))
			if not ce2.is_empty():
				p["Strength"] = float(ce2.get("Strength", 0.0))
			p["Kind"] = "stumble"
			break
	if int(p["Victim"]) >= 0:
		return p
	# 3. the human's own bounce: it ran into a skater more stable than itself and is the one who stumbles
	if human >= 0 and human < sk.size() and bool((sk[human] as Dictionary).get("bRecoilThisFrame", false)):
		p["Victim"] = human
		for i: int in range(sk.size()):
			if int((sk[i] as Dictionary).get("ContactBy", -1)) == human:
				p["Checker"] = int((sk[i] as Dictionary).get("Index", i))
		p["Outcome"] = CONTACT_STUMBLE; p["Ratio"] = bump_ratio
		var ce3: Dictionary = _check_of(events, human)
		if not ce3.is_empty():
			p["Strength"] = float(ce3.get("Strength", 0.0))
		p["Kind"] = "bounce"
	return p


# ====================================================================== the shown carrier (pure; PuckRead.cpp:44-83, PuckRead.h:45-74)
## FJamPuckShow::ShownCarrier (PuckRead.cpp:44-54). Returns [the shown carrier, the frames kept] (thirdjam's InOutKept).
static func shown_carrier(prev: int, sim_carrier: int, last_touch: int, prev_can_act: bool, prev_released: bool, prev_dist_m: float, prev_reach_m: float, keep_frames: int, kept: int) -> Array:
	if sim_carrier >= 0:
		return [sim_carrier, 0]
	if prev >= 0 and keep_frames > 0 and kept < keep_frames and last_touch == prev and prev_can_act and not prev_released and prev_dist_m <= prev_reach_m * KEEP_REACH_K:
		return [prev, kept + 1]
	return [-1, 0]


## FJamPuckShow::Settled (PuckRead.cpp:56-63). Returns [the shown carrier, pending, pending frames].
static func settled(prev: int, wanted: int, prev_holds: bool, new_plays: bool, settle_frames: int, settle_loose_frames: int, pending: int, pending_frames: int) -> Array:
	var need: int = settle_loose_frames if prev < 0 else settle_frames
	if need <= 0 or wanted < 0 or wanted == prev or (prev >= 0 and not prev_holds) or new_plays:
		return [wanted, -1, 0]
	if pending != wanted:
		pending = wanted; pending_frames = 0
	pending_frames += 1
	if pending_frames > need:
		return [wanted, -1, 0]
	return [prev, pending, pending_frames]


## FJamPuckShow::Capped (PuckRead.cpp:65-70): the drawn puck no further than max_off from the sim's, in the plane
## (x, z here); the socket's height stays. 0 = on the socket.
static func capped(sim: Vector3, socket: Vector3, max_off_m: float) -> Vector3:
	if max_off_m <= 0.0:
		return socket
	var off: Vector2 = Vector2(socket.x - sim.x, socket.z - sim.z).limit_length(max_off_m)
	return Vector3(sim.x + off.x, socket.y, sim.z + off.y)


## FJamPuckShow::SideFor (PuckRead.h:40): `local_right_m` = the puck across his line, + his right.
static func side_for(local_right_m: float, prev: int) -> int:
	return -1 if local_right_m > SIDE_BAND_M else (1 if local_right_m < -SIDE_BAND_M else prev)


## FJamPuckShow::Drawn (PuckRead.cpp:72-77): the target plus what is left of the offset at the change of hands.
static func drawn(target: Vector3, offset_at_change: Vector3, since_change: float, blend_frames: int) -> Vector3:
	var k: float = 1.0 if blend_frames <= 0 else clampf(since_change / float(blend_frames), 0.0, 1.0)
	var left: float = (1.0 - k) * (1.0 - k)      # eased out: most of the way in the first frame
	return target + offset_at_change * left


## FJamPuckShow::ShownWhile (PuckRead.h:60).
static func shown_while(shown: int, play_stopped: bool) -> int:
	return -1 if play_stopped else shown


## FJamPuckShow::PickupBlendFrames (PuckRead.h:63).
static func pickup_blend_frames(possess_body: bool, body_frames: int) -> int:
	return maxi(body_frames, BLEND_IN_FRAMES) if possess_body else BLEND_IN_FRAMES


## FJamPuckShow::GoalDropCm (PuckRead.h:66), in metres.
static func goal_drop(above_m: float, since_s: float) -> float:
	var u: float = clampf(since_s / GOAL_DROP_SECONDS, 0.0, 1.0)
	return maxf(0.0, above_m) * (1.0 - u * u)


## FJamPuckShow::PassCharge01 (PuckRead.h:68).
static func pass_charge01(charge_frames: int, full_frames: int) -> float:
	return 0.0 if charge_frames <= 0 else clampf(float(charge_frames) / float(maxi(full_frames, 1)), 0.0, 1.0)


## FJamPuckShow::MayCall (PuckRead.h:70).
static func may_call(frame: int, last_call_frame: int, mate: int, last_mate: int) -> bool:
	return mate >= 0 and frame - last_call_frame >= (CALL_SAME_MATE_FRAMES if mate == last_mate else CALL_EVERY_FRAMES)


## UJamSim::CarrierReachM (JamSim.cpp:862-869) from the cartridge's numbers (no modifiers: see DEVIATIONS).
func carrier_reach_m() -> float:
	return maxf(float(cfg["shot_reach_m"]), SKATER_RADIUS + maxf(0.0, float(cfg["stick_reach_m"]))) + 0.05


# ====================================================================== the per-match object
## FJamPuckShow::Reset (PuckRead.cpp:79-82) and the game mode's hit-stop frames (a restart, a new match).
func reset() -> void:
	_hit_stop_start = -1; _hit_stop_end = -1
	_puck_hold_total = 0; _puck_hold_left = 0; _puck_catch_up_left = 0; _puck_ever_placed = false
	_shown = -1; _kept = 0; _pending = -1; _pending_frames = 0; _puck_side = 0; _last_frame = -1
	_drawn_carrier = -1; _change_frame_f = -1e9; _change_blend = BLEND_IN_FRAMES
	_offset_at_change = Vector3.ZERO; _last_drawn = Vector3.ZERO
	_was_stopped = false; _stopped_at_s = 0.0; _ever_drawn = false
	_prev_received = PackedInt32Array(); _last_receive_frame = PackedInt64Array(); _charge_sent = []
	_possess_frame = PackedInt64Array(); _possess_body = PackedByteArray(); _last_release_frame = PackedInt64Array()
	_look_figure = null; _last_call_frame = -100000; _last_call_mate = -1
	trail_carried = -1; last_pick = {}


func get_shown() -> int:
	return _shown


static func _pawn_of(pawns: Array, index: int) -> Object:
	for a: Variant in pawns:
		if a != null and int((a as Object).get("sim_index")) == index:
			return a
	return null


## Once per sim step, after the core stepped and BEFORE the pawns' apply_sim_frame: AHokejGameMode::HitStopRoute
## (HokejGameMode.cpp:1753-1775), then FJamPuckShow::StepSim (PuckRead.cpp:85-232). Returns {"hit_stop": the frames
## the hit holds (0 = none), "shown": the carrier the screen shows}.
func step_sim(snap: Dictionary, pawns: Array) -> Dictionary:
	var frame: int = int(snap["Frame"])
	if frame <= _last_frame:
		reset()                        # a restart or a new match: the frame went back
	var hold: int = _hit_stop_route(snap, pawns)
	_puck_show_step(snap, pawns)
	return {"hit_stop": hold, "shown": _shown}


## AHokejGameMode::HitStopRoute (HokejGameMode.cpp:1753-1775).
func _hit_stop_route(snap: Dictionary, pawns: Array) -> int:
	var base: int = hit_stop_frames()
	var frame: int = int(snap["Frame"])
	if base <= 0 or frame <= _hit_stop_end:
		return 0
	var human: int = int(snap["HumanIndex"])
	var pick: Dictionary = hit_stop_pick(snap["Skaters"], snap.get("Events", []), human, float(cfg["bump_ratio"]))
	if int(pick["Victim"]) < 0:
		return 0
	var hold: int = hit_stop_frames_for(int(pick["Outcome"]), float(pick["Ratio"]), float(cfg["bump_ratio"]), float(cfg["down_ratio"]), float(cfg["down_full_ratio"]), base)
	if hold <= 0:
		return 0
	for a: Variant in pawns:
		if a != null and (int((a as Object).get("sim_index")) == int(pick["Victim"]) or int((a as Object).get("sim_index")) == int(pick["Checker"])):
			(a as Object).call(&"begin_hit_stop", hold)
	_puck_begin_hit_stop(hold)
	_hit_stop_start = frame; _hit_stop_end = frame + hold - 1
	last_pick = pick.duplicate(); last_pick["Frames"] = hold; last_pick["Frame"] = frame
	return hold


## The camera's alpha (HokejGameMode.cpp:1748-1750): while the hit frame is held the camera sits on the hit frame's pose.
func camera_alpha(frame: int, alpha: float) -> float:
	return 1.0 if (frame >= _hit_stop_start and frame <= _hit_stop_end) else alpha


## HokejGameMode.cpp:1710: while the figures hold the hit frame, the presentation frame (camera pose, HUD, radar) is
## not pushed; the hit frame itself is.
func presentation_held(frame: int) -> bool:
	return frame > _hit_stop_start and frame <= _hit_stop_end


## AJamPuck::BeginHitStop (JamPawns.cpp:984-993): called before the hit frame's StepSimFrame, which counts one down.
func _puck_begin_hit_stop(frames: int) -> void:
	if frames <= 0:
		return
	_puck_hold_total = clampi(frames, 1, 6); _puck_hold_left = _puck_hold_total + 1; _puck_catch_up_left = 0
	_puck_held = _puck_last_placed       # (never placed: thirdjam holds the actor's own place; here the last drawn, zero before any)


## AJamPuck::Place (JamPawns.cpp:1004-1017): the hold, then the catch-up to the live place.
func _puck_place(live: Vector3, alpha: float) -> Vector3:
	var loc: Vector3 = live
	if _puck_hold_left > 0:
		loc = _puck_held
	elif _puck_catch_up_left > 0 and _puck_hold_total > 0:
		var w: float = clampf((float(_puck_hold_total - _puck_catch_up_left) + alpha) / float(_puck_hold_total), 0.0, 1.0)
		loc = _puck_held.lerp(live, w)
	_puck_last_placed = loc; _puck_ever_placed = true
	return loc


## FJamPuckShow::StepSim (PuckRead.cpp:85-232).
func _puck_show_step(snap: Dictionary, pawns: Array) -> void:
	var frame: int = int(snap["Frame"])
	_last_frame = frame
	var sk: Array = snap["Skaters"]
	var puck: Dictionary = snap["Puck"]
	var n: int = sk.size()
	var sim_carrier: int = int(snap["Carrier"])
	var human: int = int(snap["HumanIndex"])
	if PUCK_SHOW:
		if _last_release_frame.size() != n:
			_last_release_frame.resize(n); _last_release_frame.fill(-100000)
		if _possess_frame.size() != n:
			_possess_frame.resize(n); _possess_frame.fill(-100000)
			_possess_body.resize(n); _possess_body.fill(0)
		for e: Dictionary in snap.get("Events", []):
			var who: int = int(e.get("Who", -1))
			if String(e.get("Name", "")) != "possess" or who < 0 or who >= n:
				continue
			_possess_frame[who] = frame; _possess_body[who] = 1 if String(e.get("Kind", "")) == "body" else 0
		for i: int in range(n):
			if bool(sk[i]["bShotThisFrame"]) or bool(sk[i]["bPassThisFrame"]):
				_last_release_frame[i] = frame
		var can: bool = false; var released: bool = false; var dist: float = 0.0; var reach: float = 0.0
		if _shown >= 0 and _shown < n:
			var s: Dictionary = sk[_shown]
			can = bool(s["CanAct"])
			released = frame - _last_release_frame[_shown] < RELEASE_NO_KEEP_FRAMES
			dist = (s["Pos"] as Vector2).distance_to(puck["Pos"] as Vector2)
			reach = carrier_reach_m()
		var before: int = _shown
		var r: Array = shown_carrier(_shown, sim_carrier, int(puck["LastTouch"]), can, released, dist, reach, maxi(0, PUCK_KEEP), _kept)
		var wanted: int = int(r[0])
		_kept = int(r[1])
		var new_plays: bool = wanted >= 0 and wanted < n and (bool(sk[wanted]["bShotThisFrame"]) or bool(sk[wanted]["bPassThisFrame"]) \
			or (wanted == human and (int(sk[wanted]["ChargeFrames"]) > 0 or int(sk[wanted]["PassChargeFrames"]) > 0)))
		var st: Array = settled(before, wanted, can and not released, new_plays, maxi(0, PUCK_SETTLE), maxi(0, PUCK_SETTLE_LOOSE), _pending, _pending_frames)
		_shown = int(st[0]); _pending = int(st[1]); _pending_frames = int(st[2])
		var play_stopped: bool = int(snap["Phase"]) == PHASE_GOAL_PAUSE or int(snap["Phase"]) == PHASE_OVER
		if play_stopped and _shown >= 0:
			_shown = shown_while(_shown, play_stopped); _kept = 0; _pending = -1; _pending_frames = 0
		# the side of his line the sim's puck is on (his own frame), for the carry floor
		if _shown >= 0 and _shown < n:
			var c: Dictionary = sk[_shown]
			var rel: Vector2 = (puck["Pos"] as Vector2) - (c["Pos"] as Vector2)
			var right: Vector2 = Vector2(-sin(float(c["Yaw"])), cos(float(c["Yaw"])))
			_puck_side = side_for(rel.dot(right), _puck_side)
		else:
			_puck_side = 0
		for a: Variant in pawns:
			if a != null:
				var mine: bool = int((a as Object).get("sim_index")) == _shown
				(a as Object).call(&"set_shown_carrier", 1 if mine else 0, _puck_side if (PUCK_CARRY_SIDE and mine) else 0)
	else:
		_shown = sim_carrier; _kept = 0; _pending = -1; _pending_frames = 0
		for a: Variant in pawns:
			if a != null:
				(a as Object).call(&"set_shown_carrier", -1, 0)     # the pawn decides by the state's bHasPuck
	if not PUCK_CALLS:
		return
	# device B's play calls, by name: a figure without one gets nothing (PuckRead.cpp:150-195)
	if _prev_received.size() != n:
		_prev_received.resize(n)
		for i: int in range(n):
			_prev_received[i] = int(sk[i]["PassesReceived"])
		_charge_sent = []; _charge_sent.resize(n); _charge_sent.fill(false)
		_last_receive_frame.resize(n); _last_receive_frame.fill(-100000)
	var half: int = maxi(0, int(cfg["saucer_half_frames"]))
	var full: int = maxi(int(cfg["power_full_frames"]), half) if int(cfg["power_full_frames"]) > 0 else maxi(half, 1)
	for a: Variant in pawns:
		if a == null:
			continue
		var i: int = int((a as Object).get("sim_index"))
		if i < 0 or i >= n:
			continue
		var s2: Dictionary = sk[i]
		var fig: Object = (a as Object).get("figure")
		# SetLookAtPuck(false) once on the human's figure; again when the figure is another
		if i == human and fig != null and _look_figure != fig:
			_look_figure = fig
			(a as Object).call(&"call_figure", &"SetLookAtPuck", [false])
		# SetPassCharge: every frame a pass is held with the puck, 0 once when the hold ends
		var charge: float = pass_charge01(int(s2["PassChargeFrames"]), full)
		if charge > 0.0:
			(a as Object).call(&"call_figure", &"SetPassCharge", [charge])
			_charge_sent[i] = true
		elif bool(_charge_sent[i]):
			_charge_sent[i] = false
			(a as Object).call(&"call_figure", &"SetPassCharge", [0.0])
		# PlayReceive: the frame a mate's pass is seated on this skater
		if int(s2["PassesReceived"]) > _prev_received[i] and frame - _last_receive_frame[i] >= RECEIVE_EVERY_FRAMES:
			_last_receive_frame[i] = frame
			(a as Object).call(&"call_figure", &"PlayReceive", [])
		_prev_received[i] = int(s2["PassesReceived"])
	# PlayCallForPass: while the human carries, the mate his pass would go to now asks for it, if he is ahead of where
	# the human looks and no opponent stands within CALL_OPEN_M of him (PuckRead.cpp:196-224)
	if human >= 0 and human < n and _shown == human and bool(sk[human]["CanAct"]) and pass_target_of.is_valid():
		var h: Dictionary = sk[human]
		var stick: Vector2 = (h["BladePos"] as Vector2) - (h["Pos"] as Vector2)
		stick = stick.normalized() if stick.length() > 1e-4 else Vector2.ZERO
		var t: int = -1 if stick == Vector2.ZERO else int(pass_target_of.call(human, stick, maxi(0, int(h["PassChargeFrames"]))))
		if t >= 0 and t < n and t != human and int(sk[t]["Team"]) == int(h["Team"]) and bool(sk[t]["CanAct"]):
			var fw: Vector2 = Vector2(cos(float(h["Yaw"])), sin(float(h["Yaw"])))
			var open: bool = ((sk[t]["Pos"] as Vector2) - (h["Pos"] as Vector2)).dot(fw) >= CALL_AHEAD_M
			for o: Dictionary in sk:
				if open and int(o["Team"]) != int(h["Team"]) and not bool(o["IsDown"]) and (o["Pos"] as Vector2).distance_to(sk[t]["Pos"] as Vector2) < CALL_OPEN_M:
					open = false
			if open and may_call(frame, _last_call_frame, t, _last_call_mate):
				var mate: Object = _pawn_of(pawns, t)
				if mate != null:
					mate.call(&"call_figure", &"PlayCallForPass", [])
					_last_call_frame = frame; _last_call_mate = t
	# the puck trail's User.Carried, on each change of the shown possession (PuckRead.cpp:229-231)
	trail_carried = 1 if _shown >= 0 else 0


## Once per sim step AFTER the pawns' apply_sim_frame: AJamHitRead::TellTakes (HitRead.cpp:644-667: SetWindupTakes(true,
## 8) by name, once a figure, mode 2 = every figure, the human's too), then AJamPuck::StepSimFrame (JamPawns.cpp:995-1002;
## HokejGameMode.cpp:1706-1707).
func after_pawns(snap: Dictionary, pawns: Array) -> void:
	var sk: Array = snap["Skaters"]
	for a: Variant in pawns:
		if a == null:
			continue
		var i: int = int((a as Object).get("sim_index"))
		if i < 0 or i >= sk.size():
			continue
		var fig: Object = (a as Object).get("figure")
		var want: bool = HIT_B_TAKES == 2 or (HIT_B_TAKES == 1 and not bool(sk[i]["bHuman"]))
		if _takes_fig.get(i, null) == fig and bool(_takes_want.get(i, false)) == want:
			continue                   # thirdjam's slots start as (no figure, false): a first figure is always told
		_takes_fig[i] = fig; _takes_want[i] = want
		(a as Object).call(&"call_figure", &"SetWindupTakes", [want, 8])
	if _puck_hold_left > 0:
		_puck_hold_left -= 1
		if _puck_hold_left == 0:
			_puck_catch_up_left = _puck_hold_total
	elif _puck_catch_up_left > 0:
		_puck_catch_up_left -= 1


## AJamPuck::LiveRenderCm (JamPawns.cpp:920-942): where the sim has the puck between its last two frames, height included.
static func puck_live(puck: Dictionary, alpha: float) -> Vector3:
	var a: float = clampf(alpha, 0.0, 1.0)
	var p: Vector2 = (puck["PrevPos"] as Vector2).lerp(puck["Pos"] as Vector2, alpha)
	return Vector3(p.x, PUCK_HALF_HEIGHT_M + maxf(0.0, float(puck["PrevZ"]) + (float(puck["Z"]) - float(puck["PrevZ"])) * a), p.y)


## Each drawn frame, after the pawns' apply_render and the figures' tick: FJamPuckShow::Render (PuckRead.cpp:279-333).
## Returns {"puck": where the puck is drawn (the pawns' space), "shown": the shown carrier, "drawn_carrier": the man
## whose blade it is drawn on (-1 = at the sim's place), "on_blade": the blend is done and it sits on his socket,
## "held": the hit-stop holds it}. `now_s`: seconds for the goal drop (default: drawn frames / 60).
func render(snap: Dictionary, pawns: Array, alpha: float, now_s: float = -1.0) -> Dictionary:
	var puck: Dictionary = snap["Puck"]
	var frame_f: float = float(int(snap["Frame"])) + alpha
	_draws += 1
	if now_s < 0.0:
		now_s = float(_draws) / 60.0
	var sim_at: Vector3 = puck_live(puck, alpha)
	var placed: Vector3
	var on_blade: bool = false
	if not PUCK_SHOW:
		# package H34's block (PuckRead.cpp:290-301): at the sim's carrier's socket when the figure has one
		var carrier: int = int(snap["Carrier"])
		var cp: Object = _pawn_of(pawns, carrier)
		var sock: Variant = cp.call(&"puck_socket_world") if cp != null else null
		if sock != null:
			_last_drawn = Vector3((sock as Vector3).x, PUCK_HALF_HEIGHT_M, (sock as Vector3).z)
			placed = _puck_place(_last_drawn, 1.0)
			on_blade = true
		else:
			_last_drawn = sim_at
			placed = _puck_place(sim_at, alpha)
		_drawn_carrier = carrier; _ever_drawn = true
	else:
		var sp: Object = _pawn_of(pawns, _shown)
		var sock2: Variant = sp.call(&"puck_socket_world") if sp != null else null
		var has_socket: bool = sock2 != null
		var now: int = _shown if has_socket else -1
		var target: Vector3 = capped(sim_at, Vector3((sock2 as Vector3).x, PUCK_HALF_HEIGHT_M, (sock2 as Vector3).z), PUCK_MAX_OFF_M) if has_socket else sim_at
		if now != _drawn_carrier:
			# a change of hands: what the drawn puck is off its new place by runs out over the blend; a placed puck cuts
			_offset_at_change = (_last_drawn - target) if _ever_drawn else Vector3.ZERO
			if _offset_at_change.length_squared() > JUMP_CUT_M * JUMP_CUT_M:
				_offset_at_change = Vector3.ZERO
			_change_frame_f = frame_f
			var body_take: bool = now >= 0 and now < _possess_frame.size() and int(snap["Frame"]) - _possess_frame[now] <= POSSESS_FRESH_FRAMES and _possess_body[now] != 0
			_change_blend = pickup_blend_frames(body_take, PUCK_BLEND_BODY) if now >= 0 else BLEND_OUT_FRAMES
			_drawn_carrier = now
		_last_drawn = drawn(target, _offset_at_change, frame_f - _change_frame_f, _change_blend)
		# after a goal the sim's puck hangs at the height it crossed the line at: the drawn one drops into the net
		var stopped: bool = int(snap["Phase"]) == PHASE_GOAL_PAUSE or int(snap["Phase"]) == PHASE_OVER
		if stopped and not _was_stopped:
			_stopped_at_s = now_s
		_was_stopped = stopped
		if stopped and now < 0:
			_last_drawn.y = PUCK_HALF_HEIGHT_M + goal_drop(_last_drawn.y - PUCK_HALF_HEIGHT_M, now_s - _stopped_at_s)
		placed = _puck_place(_last_drawn, alpha)
		_ever_drawn = true
		on_blade = has_socket and frame_f - _change_frame_f >= float(_change_blend)
	return {"puck": placed, "shown": _shown, "drawn_carrier": _drawn_carrier, "on_blade": on_blade, "held": _puck_hold_left > 0}
