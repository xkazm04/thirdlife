extends Node3D
## thirdjam's skater pawn, the visual side: a port of AJamSkater (S/JamCore/Private/JamPawns.cpp, HEAD 8dc713c6;
## "S" = thirdjam's Game/Source). It stands between the rink core's snapshot and the figure: once a sim frame
## `apply_sim_frame` turns one skater's state (a dictionary of RinkCore.snapshot()["Skaters"]) into the figure's calls,
## exactly as AJamSkater::ApplySimFrame does (JamPawns.cpp:464-746), and `apply_render` places the pawn between the
## last two sim frames (AJamSkater::ApplyRender, :824-843).
##
## The figure is any object with thirdjam's IJamSkaterVisual calls (same names, same arguments, same units:
## S/JamCore/Public/JamSkaterVisual.h): engine/rigs/skater's TLRigSkater. The by-name calls (PlayStumble, SetBraking,
## PlayCheckWindup, PlayCrossCheck, SetCrossCheckHold, PlayWhiff) go out only to a figure that has them, as
## AJamSkater::CallFigure does (:422-451).
##
## Not the sim's, so not in the snapshot: thirdjam's game mode makes these calls around the pawns, and
## cores/rink/view/skater_show.gd is that part of it (the hit-stop picks, the shown carrier and puck, the play calls
## by name): `begin_hit_stop(frames)` (AJamSkater::BeginHitStop, :228), `set_shown_carrier(state, puck_side)`
## (JamPawns.h:123), `set_aim_recover(frames)` (:109), `note_whiff_take(kind)` (:227).
##
## Space: rink metres. The pawn stands at Vector3(Pos.x, 0, Pos.y) and a figure that faces -Z is turned by
## rotation.y = -Yaw - PI / 2 (the sim's Yaw: 0 faces +x and grows towards +z, JamSim.h:133).
## DEVIATIONS from thirdjam: the JAMVIS / JAMAIM log lines are not written (`calls` records the figure's calls
## instead, when `record` is on); the hit-stop holds the figure by `set_time_dilation` if the figure has it.

# thirdjam's console variables at their defaults (JamPawns.cpp:109-144, :748-757)
const BOARD_BUMP_TAKE: int = 0           # jam.board.BumpTake
const VIS_HIT_TAKE_GUARD: bool = true    # jam.vis.HitTakeGuard
const VIS_HOLD_EARLY: bool = true        # jam.vis.HoldEarly
const VIS_HOLD_EARLY_LEAD: int = 0       # jam.vis.HoldEarlyLead
const VIS_HOLD_OVER_BRAKE: int = 1       # jam.vis.HoldOverBrake
const VIS_WHIFF_TAKE: bool = true        # jam.vis.WhiffTake
const PUCK_CARRY_REACH: float = 1.6      # jam.puck.CarryReach
const PUCK_CARRY_AIM: float = 30.0       # jam.puck.CarryAim
const PUCK_CARRY_AIM_FORE: float = 45.0  # jam.puck.CarryAimFore
# JamPawns.h
const AIM_CLAMP_DEG: float = 70.0            # :92
const AIM_SLEW_DEG_PER_FRAME: float = 15.0   # :93
const HOLD_EARLY_GIVE_UP_FRAMES: int = 20    # JamPawns.cpp:135
const HOLD_WHIFF_DELAY_FRAMES: int = 3       # JamPawns.h:236
const OWN_HIT_TAKE_FOLLOW_FRAMES: int = 10   # JamPawns.cpp:119
const CONTACT_STUMBLE: int = 2               # UJamSim::ContactStumble, JamSim.h:719
const DT: float = 1.0 / 60.0                 # UJamSim::DT, JamSim.h:492

var figure: Object = null
var sim_index: int = -1
var team: int = 0
var record: bool = false
var calls: Array = []        # [[name, [args]], ...] of the last apply_sim_frame, when `record`

# AJamSkater's own state (JamPawns.h:170-250)
var _hold_armed: int = 0
var _hold_total: int = 0
var _hold_left: int = 0
var _catch_up_left: int = 0
var _held_pos: Vector2 = Vector2.ZERO
var _held_yaw: float = 0.0
var _was_down: bool = false
var _had_puck: bool = false
var _was_at_faceoff: bool = false
var _was_pinned: bool = false
var _was_braking: bool = false
var _was_cross_braced: bool = false
var _sim_braced_last: bool = false
var _was_take_grace: bool = false
var _was_stick_lock: bool = false
var _shown_carrier: int = -1
var _carry_puck_side: int = 0
var _last_charge: float = 0.0
var _last_aim_deg: float = 0.0
var _last_aim_reach: float = 0.0
var _sent_aim_deg: float = 0.0
var _sent_reach_m: float = 1.2
var _aim_side: int = 1
var _aim_init: bool = false
var _aim_recover_left: int = 0
var _last_sim_speed: float = 0.0
var _own_hit_take_until: int = -1
var _whiff_take_until: int = -1
var _hold_press_frame: int = -1
var _hold_press_windup: int = 0
var _hold_whiff_at: int = -1
var _frame: int = -1


## AJamSkater::InitSkater + SetupVisual (JamPawns.cpp:395-400, :368-384): SetTeam and SetNumber once, then the
## resting state. `colour` is the team's (game.teams[].colour_hex), `number` the jersey's.
func init_skater(in_sim_index: int, in_team: int, colour: Color, number: int, in_figure: Object) -> void:
	sim_index = in_sim_index
	team = in_team
	figure = in_figure
	_call(&"SetTeam", [team, colour])
	_call(&"SetNumber", [clampi(number, 0, 99)])
	_call(&"SetHasPuck", [false])
	_call(&"SetBoost", [&""])
	_was_down = false
	_had_puck = false
	_was_at_faceoff = false
	_was_pinned = false
	_last_charge = -1.0      # the first apply_sim_frame sends the charge (SetShotCharge goes only on change)
	_last_aim_deg = 0.0
	_last_aim_reach = 0.0


## AJamSkater::BeginHitStop (JamPawns.cpp:228-232).
func begin_hit_stop(frames: int) -> void:
	_hold_armed = clampi(frames, 1, 6)


## AJamSkater::SetShownCarrier (JamPawns.h:123): -1 = the pawn decides by the state's bHasPuck.
func set_shown_carrier(state: int, puck_side: int = 0) -> void:
	_shown_carrier = state
	_carry_puck_side = puck_side


## AJamSkater::SetAimRecover (JamPawns.h:109).
func set_aim_recover(frames: int) -> void:
	_aim_recover_left = maxi(_aim_recover_left, frames)


## AJamSkater::NoteWhiffTake (JamPawns.h:226-227).
func note_whiff_take(kind: int) -> void:
	if _frame >= 0:
		_whiff_take_until = _frame + (16 if kind == 1 else 25)


func sent_aim_deg() -> float:
	return _sent_aim_deg


func sent_reach_m() -> float:
	return _sent_reach_m


# ------------------------------------------------------------------ the figure's calls
func _call(fname: StringName, args: Array) -> void:
	if record:
		calls.append([String(fname), args.duplicate()])
	if figure != null and figure.has_method(fname):
		figure.callv(fname, args)


## AJamSkater::CallFigure (JamPawns.cpp:422-451): by name, only to a figure that has it. Returns whether it went out.
## thirdjam passes doubles and CallFigure turns them into the function's own parameter types; here they go out typed.
func _call_by_name(fname: StringName, args: Array) -> bool:
	if figure == null or not figure.has_method(fname):
		return false
	if record:
		calls.append([String(fname), args.duplicate()])
	figure.callv(fname, args)
	return true


func _whiff_take_keeps() -> bool:
	return VIS_WHIFF_TAKE and _whiff_take_until >= 0 and _frame >= 0 and _frame <= _whiff_take_until


static func _unwind_deg(a: float) -> float:
	return wrapf(a, -180.0, 180.0)


## AJamSkater::CarryAimDeg (JamPawns.cpp:759-768).
static func carry_aim_deg(raw_rel_deg: float, prev_sent_deg: float, carrying: bool, floor_back_deg: float, floor_fore_deg: float, puck_side: int) -> float:
	var raw: float = _unwind_deg(raw_rel_deg)
	var fore: float = maxf(floor_fore_deg, 0.0)
	var back: float = maxf(floor_back_deg, 0.0)
	if not carrying or (fore <= 0.0 and back <= 0.0):
		return raw_rel_deg
	if raw >= fore or raw <= -back or absf(raw) > 90.0:
		return raw_rel_deg
	var backhand: bool
	if puck_side < 0:
		backhand = true
	elif puck_side > 0:
		backhand = false
	elif prev_sent_deg < -1.0:
		backhand = raw < 0.4 * fore
	elif prev_sent_deg > 1.0:
		backhand = raw < -0.4 * back
	else:
		backhand = raw < 0.0
	return -back if backhand else fore


## AJamSkater::SmoothAimDeg (JamPawns.cpp:770-790), on this pawn's AimSide / bAimInit.
func _smooth_aim_deg(raw_rel_deg: float, prev: float) -> float:
	var raw: float = _unwind_deg(raw_rel_deg)
	if absf(raw) <= 90.0:
		if absf(raw) > 2.0:
			_aim_side = 1 if raw > 0.0 else -1
	if _aim_side == 0:
		_aim_side = 1
	var target: float = clampf(raw, -AIM_CLAMP_DEG, AIM_CLAMP_DEG) if absf(raw) <= 90.0 else float(_aim_side) * AIM_CLAMP_DEG
	if not _aim_init:
		_aim_init = true
		return target
	var gap: float = target - prev
	var step: float = clampf(gap * 0.35, -AIM_SLEW_DEG_PER_FRAME, AIM_SLEW_DEG_PER_FRAME)
	return target if absf(gap) < 0.05 else prev + step


## AJamSkater::HoldPoseWanted (JamPawns.h:210-215).
static func hold_pose_wanted(early: bool, sim_braced: bool, hold_frames: int, down: bool, frame: int, press_frame: int, windup: int, lead: int, give_up: int) -> bool:
	if sim_braced:
		return true
	if not early or down or hold_frames <= 0 or press_frame < 0 or frame < 0 or windup <= 0:
		return false
	return frame >= press_frame + windup + lead and frame <= press_frame + give_up


## AJamSkater::StumbleFramesFor (JamPawns.cpp:453-457).
static func stumble_frames_for(s: Dictionary) -> int:
	if int(s["KnockFrames"]) > 0 or int(s["StumbleFrames"]) <= 0 or not bool(s["bBumpThisFrame"]):
		return 0
	return int(s["StumbleFrames"]) if (int(s["ContactOutcome"]) == CONTACT_STUMBLE or bool(s["bRecoilThisFrame"])) else 0


static func spin_visual_yaw_deg(s: Dictionary) -> float:
	return float(s.get("SpinVisualYawDeg", 0.0))


# ------------------------------------------------------------------ AJamSkater::ApplySimFrame (JamPawns.cpp:464-746)
## `s`: one entry of RinkCore.snapshot()["Skaters"]; `frame`: the snapshot's "Frame" (SimFrameForLog).
func apply_sim_frame(s: Dictionary, frame: int) -> void:
	if record:
		calls = []
	if figure == null:
		return
	_frame = frame
	var is_down: bool = int(s["KnockFrames"]) > 0
	var in_box: bool = int(s["PenaltyFrames"]) > 0
	var vel: Vector2 = s["Vel"]
	# :468-493 the hit-stop bookkeeping, one step per sim frame
	var hit_frame: bool = _hold_armed > 0
	if hit_frame:
		_hold_total = _hold_armed
		_hold_left = _hold_armed
		_hold_armed = 0
		_catch_up_left = 0
		_held_pos = s["Pos"]
		_held_yaw = float(s["Yaw"]) + deg_to_rad(spin_visual_yaw_deg(s))
		_set_visual_time_dilation(0.0001)
	elif _hold_left > 0:
		_hold_left -= 1
		if _hold_left == 0:
			_set_visual_time_dilation(1.0)
			_catch_up_left = _hold_total
	elif _catch_up_left > 0:
		_catch_up_left -= 1
	var held: bool = not hit_frame and _hold_left > 0
	# :495-496
	if bool(s["bShotThisFrame"]):
		_call(&"PlayShoot", [float(s["LastShotCharge"])])
	if bool(s["bCheckThisFrame"]):
		_call(&"PlayCheck", [])
	# :499-535 the takes by name, the early hold, the whiff of a released hold
	var windup: int = int(s["WindupFrames"])
	if bool(s["bCheckThisFrame"]) and windup > 0:
		_call_by_name(&"PlayCheckWindup", [windup])
	if bool(s["bLiftThisFrame"]):
		_call_by_name(&"PlayCrossCheck", [windup])
	if (bool(s["bCheckThisFrame"]) or bool(s["bLiftThisFrame"])) and windup > 0:
		_own_hit_take_until = frame + windup + OWN_HIT_TAKE_FOLLOW_FRAMES
	if bool(s["bLiftThisFrame"]) and windup > 0:
		_hold_press_frame = frame
		_hold_press_windup = windup
	var hold_wanted: bool = hold_pose_wanted(VIS_HOLD_EARLY, bool(s["bCrossBraced"]), int(s["CrossHoldFrames"]), is_down, frame, _hold_press_frame,
		_hold_press_windup, VIS_HOLD_EARLY_LEAD, HOLD_EARLY_GIVE_UP_FRAMES)
	if hold_wanted != _was_cross_braced:
		_was_cross_braced = hold_wanted
		_call_by_name(&"SetCrossCheckHold", [_was_cross_braced])
	if VIS_WHIFF_TAKE and not bool(s["bAtFaceoff"]) and not in_box and (_sim_braced_last and not bool(s["bCrossBraced"]) and int(s["CrossHoldFrames"]) == 0 and not is_down) and frame >= 0:
		_hold_whiff_at = frame + HOLD_WHIFF_DELAY_FRAMES
	if bool(s["bCheckThisFrame"]) or bool(s["bLiftThisFrame"]) or bool(s["bCrossBraced"]) or is_down or in_box or bool(s["bAtFaceoff"]) or not VIS_WHIFF_TAKE:
		_hold_whiff_at = -1
	elif _hold_whiff_at >= 0 and frame >= _hold_whiff_at:
		_hold_whiff_at = -1
		if _call_by_name(&"PlayWhiff", [1]):
			note_whiff_take(1)
	_sim_braced_last = bool(s["bCrossBraced"])
	# :536-553 down and up
	if is_down != _was_down:
		_was_down = is_down
		var down_frames: int = maxi(1, int(s["KnockFrames"])) if _was_down else 0
		var kd: Vector2 = s["KnockDir"]
		_call(&"SetKnockedDown", [_was_down, kd.x, kd.y, down_frames])
	# :555-584 a hit taken standing: a stumble (by name) or a bump
	if bool(s["bBumpThisFrame"]) and not is_down:
		var stumble_frames: int = stumble_frames_for(s)
		var bd: Vector2 = s["BumpDir"]
		var stumble_sent: bool = stumble_frames > 0 and _call_by_name(&"PlayStumble", [bd.x, bd.y, stumble_frames])
		var own_take: bool = (VIS_HIT_TAKE_GUARD and stumble_frames <= 0 and (_was_cross_braced or (_own_hit_take_until >= 0 and frame >= 0 and frame <= _own_hit_take_until))) \
			or (stumble_frames <= 0 and _whiff_take_keeps())
		if not stumble_sent and not own_take:
			_call(&"PlayHitReaction", [bd.x, bd.y])
	# :585-609 the reverse brake, a level sent on the change
	var braking_now: bool = (bool(s["bReverseBraking"]) and not vel.is_zero_approx()) and not (VIS_HOLD_OVER_BRAKE == 1 and _was_cross_braced) and not _whiff_take_keeps()
	if braking_now != _was_braking:
		_was_braking = braking_now
		# AJamSkater::BrakeDecelFor (:459-462)
		var decel: float = (maxf(0.0, _last_sim_speed - vel.length()) / DT) if bool(s["bReverseBraking"]) else 0.0
		_call_by_name(&"SetBraking", [_was_braking, decel])
		if VIS_HOLD_OVER_BRAKE == 2 and _was_cross_braced:
			_call_by_name(&"SetCrossCheckHold", [true])
	_last_sim_speed = vel.length()
	# :610-619 the boards
	if bool(s["bBoardHitThisFrame"]):
		if BOARD_BUMP_TAKE != 0 or bool(s["bContactBoard"]) or is_down:
			_call(&"PlayBoardHit", [])
	# :620-660 are log lines of the HUD's read-outs (press results, grace, take grace, stick lock): nothing goes to the figure
	_was_take_grace = int(s["TakeGraceLeft"]) > 0
	_was_stick_lock = int(s["StickLockLeft"]) > 0
	# :661-671 the pin, the stick hit
	if bool(s["bBoardPinned"]) != _was_pinned:
		_was_pinned = bool(s["bBoardPinned"])
		_call(&"SetBoardPin", [_was_pinned])
	if int(s["StickHitResult"]) != 0:
		_call(&"PlayStickHit", [int(s["StickHitResult"]) == 2])
	# :672-678 the carrier flag follows the carrier the screen shows when the shell told it
	var has_puck_now: bool = (_shown_carrier == 1) if _shown_carrier >= 0 else bool(s["bHasPuck"])
	if has_puck_now != _had_puck:
		_had_puck = has_puck_now
		_call(&"SetHasPuck", [_had_puck])
	# :679-690 while held, the continuous calls stay away
	if held:
		_one_shots(s)
		return
	# :691-696 the motion: turn rate positive = turning left seen from above; the sim's yaw grows to the right
	var spin_deg: float = spin_visual_yaw_deg(s)
	var visual_yaw: float = float(s["Yaw"]) + deg_to_rad(spin_deg)
	var spin_rate: float = 0.0
	if int(s["SpinFrames"]) > 0 and int(s["SpinLength"]) > 0:
		spin_rate = float(int(s["SpinDir"])) * 2.0 * PI / (float(int(s["SpinLength"])) * DT)
	_call(&"UpdateMotion", [vel.length(), -float(s["YawRate"]) - spin_rate, rad_to_deg(visual_yaw)])
	# :698-724 the stick aim: the blade relative to the facing, positive = left
	var d: Vector2 = (s["BladePos"] as Vector2) - (s["Pos"] as Vector2)
	var rel: float = wrapf(atan2(d.y, d.x) - visual_yaw, -PI, PI)
	var aim_deg: float = -rad_to_deg(rel)
	var reach: float = d.length()
	_last_aim_deg = aim_deg
	_last_aim_reach = reach
	var aim_for_figure: float = carry_aim_deg(aim_deg, _sent_aim_deg, bool(s["bHuman"]) and _had_puck, PUCK_CARRY_AIM, PUCK_CARRY_AIM_FORE, _carry_puck_side)
	if _aim_recover_left > 0:
		_aim_recover_left -= 1
		if not _had_puck:
			aim_for_figure = 0.0
	_sent_aim_deg = _smooth_aim_deg(aim_for_figure, _sent_aim_deg)
	var carry_reach: float = PUCK_CARRY_REACH if (bool(s["bHuman"]) and _had_puck) else 0.0
	var reach_for_figure: float = carry_reach if carry_reach > 0.0 else reach
	_sent_reach_m = reach_for_figure if is_zero_approx(_sent_reach_m) else _sent_reach_m + (reach_for_figure - _sent_reach_m) * 0.35
	_call(&"SetStickAim", [_sent_aim_deg, _sent_reach_m])
	# :725-735 the shot charge, sent only when it changed
	var charge: float = clampf(float(int(s["ChargeFrames"])) / 30.0, 0.0, 1.0) if int(s["ChargeFrames"]) > 0 else 0.0
	if charge != _last_charge:
		_last_charge = charge
		_call(&"SetShotCharge", [charge])
	_one_shots(s)


## The one-shots both branches end with (JamPawns.cpp:682-688 and :736-745).
func _one_shots(s: Dictionary) -> void:
	if int(s["PokeResult"]) != 0:
		_call(&"PlayPoke", [int(s["PokeResult"]) > 0])
	if bool(s["bLiftThisFrame"]) and not _whiff_take_keeps():
		_call(&"PlayLift", [])
	if bool(s["bPassThisFrame"]):
		_call(&"PlayPass", [float(s["LastPassStrength"])])
	if bool(s["bAtFaceoff"]) != _was_at_faceoff:
		_was_at_faceoff = bool(s["bAtFaceoff"])
		_call(&"SetFaceoff", [_was_at_faceoff])
	if int(s["DrawResult"]) != 0:
		_call(&"PlayFaceoffDraw", [int(s["DrawResult"]) > 0])
	if bool(s["bFoulThisFrame"]):
		_call(&"PlayFoulReaction", [])


## AJamSkater::SetVisualTimeDilation (JamPawns.cpp:234): the figure's clock stands (almost) still during the hit-stop.
func _set_visual_time_dilation(dilation: float) -> void:
	if figure != null and figure.has_method(&"set_time_dilation"):
		if record:
			calls.append(["set_time_dilation", [dilation]])      # not a call of the interface: the actor's CustomTimeDilation
		figure.call(&"set_time_dilation", dilation)


# ------------------------------------------------------------------ AJamSkater::ApplyRender (JamPawns.cpp:824-843)
## Places the pawn between the last two sim frames: `alpha` 0 = the previous frame, 1 = this one.
func apply_render(s: Dictionary, alpha: float) -> void:
	var p: Vector2 = (s["PrevPos"] as Vector2).lerp(s["Pos"] as Vector2, alpha)
	var dyaw: float = wrapf(float(s["Yaw"]) - float(s["PrevYaw"]), -PI, PI)
	var yaw: float = float(s["PrevYaw"]) + dyaw * alpha + deg_to_rad(spin_visual_yaw_deg(s))
	# (a boxed skater's seat, BoxSeat, is the shell's: not ported here)
	if _hold_left > 0:
		_place(_held_pos, _held_yaw)
		return
	if _catch_up_left > 0 and _hold_total > 0:
		var w: float = clampf((float(_hold_total - _catch_up_left) + alpha) / float(_hold_total), 0.0, 1.0)
		_place(_held_pos.lerp(p, w), lerp_angle(_held_yaw, yaw, w))
		return
	_place(p, yaw)


func _place(p: Vector2, yaw: float) -> void:
	position = Vector3(p.x, 0.0, p.y)
	rotation = Vector3(0.0, -yaw - PI * 0.5, 0.0)


# ------------------------------------------------------------------ for the game mode's presentation (skater_show.gd)
## The figure's calls the show object made by name since the caller last emptied this list, when `record` is on:
## [[name, [args]], ...]. (`calls` is the pawn's own frame and is emptied by apply_sim_frame; the show's calls go
## out before and after it: FJamPuckShow::StepSim, AJamHitRead::TellTakes.)
var show_calls: Array = []


## AJamSkater::CallFigure (JamPawns.cpp:422-451) for the game mode's by-name calls (PlayReceive, SetPassCharge,
## PlayCallForPass, SetLookAtPuck, SetWindupTakes): only to a figure that has the call. Returns whether it went out.
func call_figure(fname: StringName, args: Array) -> bool:
	if figure == null or not figure.has_method(fname):
		return false
	if record:
		show_calls.append([String(fname), args.duplicate()])
	figure.callv(fname, args)
	return true


## AJamSkater::IsHitStopped (JamPawns.h:135).
func is_hit_stopped() -> bool:
	return _hold_left > 0


## AJamSkater::IsToldHasPuck (JamPawns.h:126): what the figure was last told.
func is_told_has_puck() -> bool:
	return _had_puck


## AJamSkater::GetPuckSocketWorld (JamPawns.cpp:813-820): where the figure's puck_socket stands, in the space the pawn
## stands in (its parent's; the world when it is in the tree), or null for a figure without `socket_transform`.
func puck_socket_world() -> Variant:
	if figure == null or not figure.has_method(&"socket_transform"):
		return null
	var local: Transform3D = figure.call(&"socket_transform", &"puck_socket")
	var fig_xf: Transform3D = (figure as Node3D).transform if figure is Node3D else Transform3D.IDENTITY
	if is_inside_tree():
		return global_transform * (fig_xf * local.origin)
	return transform * (fig_xf * local.origin)
