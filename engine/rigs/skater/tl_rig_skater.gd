class_name TLRigSkater
extends TLRigSkaterBody
## thirdjam's skater in our engine (hockey campaign, lane K2): the shipped figure SK_SkaterTB1_P3, its 24-bone
## skeleton, its 202 clips, and its driver.
##
## THE FIGURE'S ENTRY IS THIRDJAM'S: the calls of IJamSkaterVisual (S/JamCore/Public/JamSkaterVisual.h; "S" =
## thirdjam's Game/Source) and the by-name calls its pawn makes, with the same names, arguments and units:
##   SetTeam(TeamId, Colour)  SetNumber(N)  UpdateMotion(Speed, TurnRate, Facing)  SetStickAim(AngleDeg, ReachM)
##   SetHasPuck(bHasPuck)  SetBraking(bOn, Decel)  SetShotCharge(Charge01)  SetFaceoff(bReady)  SetGoalieStance(bOn, Side)
##   ... and the rest of the interface (PlayShoot, PlayCheck, SetKnockedDown, ...), which round 2 takes and counts in
##   `not_ported` without showing anything yet.
## A caller makes the frame's calls and then `tick()`: one world tick of 1/60 s (the Blueprint's Tick, then the
## animation update), never a clock. engine/cores/rink/view/skater_pawn.gd is thirdjam's pawn and makes the calls.
##
## THE DRIVER IS A PORT of thirdjam's shipped Blueprint BP_SkaterVisual_TB1_P3 (HEAD 8dc713c6), function by function
## from its exported graph: engine/rigs/skater/driver-ref/BP_SkaterVisual_TB1_P3.EventGraph.txt. A comment `[Name]`
## names the listing's entry a function ports; variables keep the Blueprint's names. Its animation blueprint is
## TLRigSkaterAnim. Ported in round 2: skating (UpdateMotion, StopTick, SetBraking, the look at the puck), the stick
## (SetStickAim, SK2Tick, SK3Fix, PushAnim), the faceoff stance and draw, the foul reaction (PlayAct). Where the two disagree, the Blueprint wins over thirdjam's ledger.
##
## DEVIATIONS from the Blueprint (each with its reason):
##   - time is the count of ticks / 60 where the Blueprint reads GetTimeSeconds (law: time is physics frames);
##   - WasRecentlyRendered (SK3Fix) is taken as true: a figure nobody sees keeps its stick correction;
##   - the sounds and the brake's particle effect of StopTick are not played (the figure is visual only; the shell's);
##   - the puck the head turns to is given by `set_puck(...)` (the Blueprint finds the puck actor itself);
##   - "is this the human's figure" is given by `set_human(...)` (the Blueprint asks the game mode);
##   - YawCorr and RadCorr of SK3Fix are not computed: the Blueprint computes them and uses neither (RadCorr x 0).
##
## Also kept from round 1, for the review tools: plain clip playback (`play_clip`, `pose_at`), which switches the
## driver off until the next interface call.
## VISUAL ONLY. Faces -Z (the engine's rig convention); the export faces +X, so the body sits under a quarter turn.

## The calls of thirdjam's interface this figure takes and does not show yet (each round ports more; `not_ported`
## counts the ones that arrived). The gym leaves them out of what it gives thirdjam's own figure to compare with.
const NOT_PORTED_CALLS: Array = ["PlayShoot", "PlayCheck", "SetKnockedDown", "PlayPoke", "PlayLift", "PlayPass", "PlayHitReaction", "PlayBoardHit", "SetBoardPin", "PlayStickHit", "PlayStumble", "PlayCheckWindup", "PlayCrossCheck",
	"SetCrossCheckHold", "PlayWhiff"]

var anim: TLRigSkaterAnim
var not_ported: Dictionary = {}       # interface calls taken and not shown yet: name -> count
var _now: float = 0.0                 # GetTimeSeconds: ticks / 60
var _dilation: float = 1.0
var _human: bool = false
var _puck_fr = null                   # the puck in the figure's own frame, Vector2(forward, right) metres, or null
var _no_game_mode: bool = false       # see set_no_game_mode

# ---- the Blueprint's variables (BP_SkaterVisual_TB1_P3; defaults = its class defaults, then [ReceiveBeginPlay])
var SpeedNow: float = 0.0
var FacingYaw: float = 0.0
var LiftN: int = 0
var LiftYaw: float = 0.0
var bDown: bool = false
var bUpRun: bool = false
var bPuck: bool = false
var bFaceoff: bool = false
var bGoalie: bool = false
var GoalieSide: int = 0
var bWeapon: bool = false
var bBoostBeat: bool = false
var bHoldOn: bool = false
var HoldE: float = 0.0
var PassChg: float = 0.0
var ShootCharge: float = 0.0
var ActPri: int = 0
# the stick
var AimStep: float = 0.0
var AimRStep: float = 0.0
var AimSent: float = 0.0
var AimRSent: float = 0.0
var AimLead: float = 0.0
var AimAngleT: float = 0.0
var AimReachT: float = 0.0
var AimDes: float = 0.0
var AimAngle: float = 0.0
var AimOver: float = 0.0
var AimReach: float = 0.0
var AimOffA: float = 0.0
var AimOffR: float = 0.0
var AimW: float = 0.0
var bAimSeen: bool = false
var FixW: float = 0.0
var FixT: float = 0.0
var BladeH: float = 0.0
var StickCorr: float = 0.0
var H0: float = 4.6                   # class default
# the stops
var SpdPrev: float = 0.0
var DecN: int = 0
var DecE: float = 0.0
var StopV0: float = 0.0
var bCand: bool = false
var bStop: bool = false
var bBrkLevel: bool = false
var bBrkOn: bool = false
var bBrkShown: bool = false
var bHum: bool = false
var BrkV0: float = 0.0
var BrkN: int = 0
var BrkT: float = 0.0
var BrkMinF: int = 6                  # [ReceiveBeginPlay]
var BrkMinH: int = 1
var BrkGapH: float = 0.0
var StopV: float = 7.0
var StopGapB: float = 8.0
var StopT: float = -10.0
# the look
var LookYaw: float = 0.0
var LookDbg: float = 0.0
var bNoLook: bool = false


## Builds the figure (TLRigSkaterBody.setup) and its animation blueprint.
func setup(p: Dictionary = {}) -> void:
	super.setup(p)
	anim = TLRigSkaterAnim.new()


# ------------------------------------------------------------------ engine-side inputs (not thirdjam's interface)
## Whether this is the human's figure ([StopTick], [SetBraking]: `GetHumanSkater(GameMode) == GetAttachParentActor()`).
func set_human(on: bool) -> void:
	_human = on


## thirdjam's figure outside its game. [SetBraking] and [StopTick] ask the game mode who the human is through a cast to
## AHokejGameMode, and a Blueprint's execution ends where a cast fails: in a world without that game mode SetBraking
## only notes that brake levels arrive (bBrkLevel) and no stop take ever starts. The oracle's world is such a world
## (tools/skater/driver_oracle.py), so the comparison with it sets this; the game never does.
func set_no_game_mode(on: bool) -> void:
	_no_game_mode = on


## The puck in the figure's own frame, metres: Vector2(forward, right); null = no puck to look at ([LookTick]'s PuckRef).
func set_puck(forward_right) -> void:
	_puck_fr = forward_right


## The hit-stop: thirdjam sets the visual actor's CustomTimeDilation to 0.0001 (AJamSkater::SetVisualTimeDilation):
## while it is under 0.5 a tick does not advance the figure.
func set_time_dilation(dilation: float) -> void:
	_dilation = dilation


# ------------------------------------------------------------------ thirdjam's interface, ported
func _driver() -> void:
	_clip_mode = false


## [SetTeam]. `Colour` is linear RGB, as thirdjam's FLinearColor.
func SetTeam(TeamId: int, Colour: Color) -> void:
	team = TeamId
	set_team_colour(Color(Colour.r, Colour.g, Colour.b).linear_to_srgb())
	# CrestTeam = clamp(TeamId, 0, 1) on the jersey material: the crest is not drawn yet (the look, a later round)


## [SetNumber]: 0..99; NumberTens / NumberOnes on the jersey and the trim patch (TLRigSkaterLook, lane K7).
func SetNumber(N: int) -> void:
	number = clampi(N, 0, 99)
	look_refresh()


## [SetHasPuck]
func SetHasPuck(bHasPuck: bool) -> void:
	bPuck = bHasPuck


## [UpdateMotion]. Speed m/s, TurnRate rad/s (positive = turning left seen from above), Facing = the yaw of thirdjam's
## FRotator in degrees (pitch and roll are 0).
func UpdateMotion(Speed: float, TurnRate: float, Facing: float) -> void:
	_driver()
	SpeedNow = Speed
	FacingYaw = Facing
	if LiftN > 0:
		LiftN -= 1
	anim.Speed = Speed
	anim.TurnRate = TurnRate
	if bDown:
		_miss("UpdateMotion while down (the fall's turn)")
	# the mesh's relative yaw: 0 + LiftYaw x ... while LiftN > 0 (a stick lift's turn): 0 until the lift is ported
	_shift_tick()
	_stop_tick(Speed, TurnRate)
	_sk2_tick()


## [ShiftTick]: the slide off a wall after a fall. WallShift is only set by the falls: nothing to do until they are ported.
func _shift_tick() -> void:
	pass


## [StopTick]
func _stop_tick(Speed: float, TurnRate: float) -> void:
	var dec: float = (SpdPrev - Speed) * 60.0
	if dec > 12.0:
		if DecN == 0:
			StopV0 = SpdPrev
		DecN += 1
	else:
		DecN = 0
		bCand = false
	DecE = DecE + 0.34 * (dec - DecE)
	SpdPrev = Speed
	if bStop:
		if bDown or bUpRun or ActPri != 5 or not anim.is_any_montage_playing():
			bStop = false
		elif ((bBrkLevel and bBrkOn) or (not bBrkLevel and DecE > 8.0 and Speed > 0.7)) and anim.montage_position() >= 0.266667:
			anim.montage_set_position(anim.montage_position() - 0.2)
	else:
		if not bBrkLevel and DecN >= 3 and (StopV0 - Speed) >= 3.5 and not bCand:
			bCand = true
			if _no_game_mode:
				return          # Cast<HokejGameMode> fails: the function ends here
			if StopV0 >= StopV and (_now - StopT) >= (1.5 if _human else StopGapB) and not bDown and not bUpRun and not bHoldOn \
					and (not anim.is_any_montage_playing() or ActPri <= 3):
				bStop = true
				ActPri = 5
				StopT = _now
				anim.play_slot(&"Stop_Hard_Left" if TurnRate > 0.2 else &"Stop_Hard", 0.06, 0.1)
	if bBrkOn:
		BrkN += 1
	if bBrkLevel and bBrkOn and not bBrkShown and not bStop and BrkV0 >= StopV and BrkN >= (BrkMinH if bHum else BrkMinF) \
			and (_now - StopT) >= (BrkGapH if bHum else StopGapB) and not bDown and not bUpRun and not bHoldOn \
			and (not anim.is_any_montage_playing() or ActPri <= 3):
		bStop = true
		ActPri = 5
		bBrkShown = true
		StopT = _now
		anim.play_slot(&"Stop_Hard_Left" if TurnRate > 0.2 else &"Stop_Hard", 0.06, 0.1)


## [SetBraking]: the sim's reverse brake, a level (by name from the pawn).
func SetBraking(bOn: bool, _Decel: float) -> void:
	bBrkLevel = true
	if _no_game_mode:
		return                  # Cast<HokejGameMode> fails: the function ends here
	bHum = _human
	if bOn:
		BrkV0 = SpdPrev
		BrkN = 0
		BrkT = _now
	else:
		bBrkShown = false
	bBrkOn = bOn


## [SetStickAim]. AngleDeg: 0 = forward, positive = to the left; ReachM: centre to blade.
func SetStickAim(AngleDeg: float, ReachM: float) -> void:
	_driver()
	var a: float = clampf(AngleDeg, -70.0, 70.0)
	var r: float = clampf(ReachM, 1.0, 1.6)
	AimStep = (a - AimSent) if bAimSeen else 0.0
	AimRStep = (r - AimRSent) if bAimSeen else 0.0
	AimSent = a
	AimRSent = r
	if absf(AimStep) > 15.5:
		AimLead = 0.0
	elif absf(AimStep) < 14.9:
		AimLead = AimStep * 0.65
	else:
		AimLead = signf(AimStep) * 12.4
	if bAimSeen and absf(AimStep) <= 15.5:
		AimAngleT = clampf(a + AimLead, AimAngleT - 15.0, AimAngleT + 15.0)
	else:
		AimAngleT = a + AimLead
	AimReachT = clampf(r + AimRStep * 0.65, 1.0, 1.6)
	AimDes = AimAngleT - AimOffA
	AimAngle = clampf(AimDes, -63.0, 70.0)
	AimOver = clampf(AimDes - AimAngle, -12.0, 12.0)
	AimReach = clampf(AimReachT - AimOffR, 1.0, 1.6)
	bAimSeen = true
	_push_anim()


## [SK2Tick]: where the puck socket stood against the aim that drew it is learned (AimOffA, AimOffR) while the aim is
## the whole upper body and steady; the aim layer's weight moves 0.15 a call.
func _sk2_tick() -> void:
	if bAimSeen and AimW > 0.99 and not anim.is_any_montage_playing() and HoldE < 0.01 and PassChg < 0.01 and absf(AimStep) < 1.5 and absf(AimRStep) < 0.02:
		var puck: Vector3 = _puck_socket_ue()
		# the mesh's yaw minus the puck socket's bearing from the actor (Unreal yaws grow to the right): how far left it stands
		var left_deg: float = _mesh_yaw_deg() - rad_to_deg(atan2(puck.y, puck.x))
		AimOffA = clampf(AimOffA + 0.3 * (clampf(wrapf(left_deg - AimDes, -180.0, 180.0), -25.0, 25.0) - AimOffA), -25.0, 25.0)
		AimOffR = clampf(AimOffR + 0.3 * (clampf(Vector2(puck.x, puck.y).length() / 100.0 - AimReach, -0.3, 0.3) - AimOffR), -0.3, 0.3)
	var want: float = 1.0 if (bAimSeen and not (bDown or bFaceoff or bGoalie)) else 0.0
	AimW = AimW + clampf(want - AimW, -0.15, 0.15)
	# (bPendingShoot, StumbleIn: the wrist shot and the stumble, with their rounds)
	_sk3_fix()
	_push_anim()


## [SK3Fix]: the stick is pitched about its grip until the blade's heel stands H0 (4.6 cm) over the ice, at most 12
## degrees, and yawed by what the aim wants past the blend space's end (AimOver).
func _sk3_fix() -> void:
	if _now == FixT:
		return
	FixW = minf(1.0, FixW + maxf(_now - FixT, 0.0) / 0.15)
	FixT = _now
	var heel: Vector3 = _stick_vec_ue(HEEL_ON_STICK_UE)          # grip to heel, the actor's frame, cm
	var grip: Vector3 = _bone_ue(TLRigSkaterPose.STICK)
	BladeH = grip.z + heel.z
	var err: float = H0 - BladeH
	var err_db: float = 0.0 if absf(err) < 0.3 else err
	var len_xy: float = maxf(Vector2(heel.x, heel.y).length(), 30.0)
	if AimW > 0.5 and not anim.is_any_montage_playing() and HoldE < 0.01 and PassChg < 0.01:
		StickCorr = clampf(StickCorr + 0.2 * (err_db * 57.2958 / len_xy), -12.0, 12.0)
	else:
		StickCorr = StickCorr * 0.8
	var k: float = (1.0 - clampf(HoldE, 0.0, 1.0)) * (1.0 - clampf(PassChg, 0.0, 1.0))
	# the pitch axis: level and square to the stick, in the mesh component's own axes
	var axis_w: Vector3 = Vector3(heel.y, -heel.x, 0.0)            # Cross((x, y, 0), (0, 0, 1))
	axis_w = axis_w.normalized() if axis_w.length() > 1e-4 else Vector3.ZERO
	var axis_c: Vector3 = axis_w.rotated(Vector3(0, 0, 1), -deg_to_rad(_mesh_yaw_deg()))     # InverseTransformDirection(mesh)
	var q_pitch: Quaternion = TLRigSkaterPose.ue_axis_angle_quat(axis_c, StickCorr * AimW * FixW * k)
	var q_yaw: Quaternion = TLRigSkaterPose.ue_axis_angle_quat(Vector3(0, 0, 1), -AimOver * AimW * k + debug_stick_yaw_deg)
	anim.StickRot = q_yaw * q_pitch                                 # ComposeRotators(A, B): A first, then B
	anim.StickOff = Vector3.ZERO                                    # Normal(heel) x (0 x RadCorr x ...)


## [PushAnim]
func _push_anim() -> void:
	anim.AimAngle = AimAngle
	anim.AimReach = AimReach
	anim.T1 = clampf((AimReach - 1.0) * 3.3333333, 0.0, 1.0)
	anim.T2 = clampf((AimReach - 1.3) * 6.6666667, 0.0, 1.0)
	anim.T3 = clampf((AimReach - 1.45) * 6.6666667, 0.0, 1.0)
	anim.AimW = 1.0 if (bWeapon or bBoostBeat) else AimW
	anim.ChargeAlpha = 0.0 if bDown else anim.ChargeAlpha
	anim.bStLoco = bDown or not (bFaceoff or bGoalie)
	anim.bStFace = bFaceoff
	anim.bStHold = GoalieSide == 0
	anim.bStRight = GoalieSide > 0


## [SetShotCharge] + [ChargeMix]: the wind-up of a held shot. The variables are kept; the pose (TwoWayBlend_1) is not ported.
func SetShotCharge(Charge01: float) -> void:
	ShootCharge = clampf(Charge01, 0.0, 1.0)
	anim.ChargeTime = ShootCharge * 0.26667
	anim.ChargeAlpha = clampf(ShootCharge * 5.0, 0.0, 1.0)
	_push_anim()
	if ShootCharge > 0.0:
		_miss("SetShotCharge")


## [SetFaceoff]
func SetFaceoff(bReady: bool) -> void:
	bFaceoff = bReady
	_push_anim()


## [SetGoalieStance]
func SetGoalieStance(bOn: bool, Side: int) -> void:
	bGoalie = bOn
	GoalieSide = clampi(Side, -1, 1)
	_push_anim()


## [LookTick]: chest and head turn to the puck, 60 degrees at most, when he does not carry it.
func _look_tick(dt: float) -> void:
	LookDbg = 0.0
	if _puck_fr != null:
		var spine: Vector3 = _bone_ue(BONE_SPINE_03)
		var to: Vector2 = Vector2((_puck_fr as Vector2).x * 100.0 - spine.x, (_puck_fr as Vector2).y * 100.0 - spine.y)
		if not bNoLook and not bPuck and not bDown and not bUpRun and not bGoalie and not bFaceoff \
				and not (anim.is_any_montage_playing() and ActPri >= 5) and to.length() > 60.0:
			LookDbg = wrapf(rad_to_deg(atan2(to.y, to.x)) - _mesh_yaw_deg(), -180.0, 180.0)
			if absf(LookDbg) > 150.0:
				LookDbg = 60.0 if LookYaw >= 0.0 else -60.0
			else:
				LookDbg = clampf(LookDbg, -60.0, 60.0)
	LookYaw = LookYaw + (LookDbg - LookYaw) * clampf(dt * (25.0 if (bDown or bUpRun) else 8.0), 0.0, 1.0)
	anim.LookRot1 = TLRigSkaterPose.ue_rotator_quat(0.0, LookYaw * 0.4, 0.0)       # MakeRotator(0, 0, LookYaw x 0.4): yaw
	anim.LookRot2 = TLRigSkaterPose.ue_rotator_quat(0.0, LookYaw * 0.6, 0.0)
	anim.bReady = not bPuck


## [ReceiveTick]: of its ticks only the look runs in round 2 (the others belong to the pass, the whip, the stick lock,
## the hold, the weapons, the falls and get-ups).
func _receive_tick(dt: float) -> void:
	_look_tick(dt)


# ------------------------------------------------------------------ the interface's calls not ported yet
func _miss(what: String) -> void:
	not_ported[what] = int(not_ported.get(what, 0)) + 1


func SetBoost(_Kind: StringName) -> void:
	if String(_Kind) != "":
		_miss("SetBoost")


func PlayShoot(_Charge: float) -> void:
	_miss("PlayShoot")


func PlayCheck() -> void:
	_miss("PlayCheck")


func SetKnockedDown(_bDown: bool, _DirX: float, _DirZ: float, _KnockdownFrames: int) -> void:
	_miss("SetKnockedDown")


func PlayPoke(_bClean: bool) -> void:
	_miss("PlayPoke")


func PlayLift() -> void:
	_miss("PlayLift")


func PlayPass(_Strength: float) -> void:
	_miss("PlayPass")


## [PlayAct]: a take on the slot, unless he is down or getting up or a take of a higher priority runs.
func _play_act(clip_name: StringName, pri: int, rate: float, start: float) -> void:
	if not bDown and not bUpRun and (not anim.is_any_montage_playing() or pri >= ActPri):
		ActPri = pri
		anim.play_slot(clip_name, 0.08, 0.2, rate, start)


## [PlayFaceoffDraw]: the centre's draw, slower when lost.
func PlayFaceoffDraw(bWon: bool) -> void:
	_driver()
	_play_act(&"Faceoff_Draw", 2, 1.0 if bWon else 0.7, 0.0)


## [PlayFoulReaction]
func PlayFoulReaction() -> void:
	_driver()
	_play_act(&"Foul_Reaction", 5, 1.0, 0.0)


func PlayHitReaction(_DirX: float, _DirZ: float) -> void:
	_miss("PlayHitReaction")


func PlayBoardHit() -> void:
	_miss("PlayBoardHit")


func SetBoardPin(_bOn: bool) -> void:
	if _bOn:
		_miss("SetBoardPin")


func PlayStickHit(_bLifted: bool) -> void:
	_miss("PlayStickHit")


func PlayStumble(_DirX: float, _DirZ: float, _Frames: int) -> void:
	_miss("PlayStumble")


func PlayCheckWindup(_Frames: int) -> void:
	_miss("PlayCheckWindup")


func PlayCrossCheck(_Frames: int) -> void:
	_miss("PlayCrossCheck")


func SetCrossCheckHold(_bOn: bool) -> void:
	if _bOn:
		_miss("SetCrossCheckHold")


func PlayWhiff(_Kind: int) -> void:
	_miss("PlayWhiff")


# ------------------------------------------------------------------ ticking and posing
## Advances one physics frame: the animation's update and the pose, then the Blueprint's own Tick.
## (In clip mode, round 1: the first tick after `play_clip` shows key 0; each later tick moves `clip_rate` keys. A
## looping clip of N keys has a period of N - 1 ticks at rate 1.)
func tick() -> void:
	if _clip_mode:
		_tick_clip()
		return
	if _dilation < 0.5:
		return
	_now += DT
	# The mesh's animation update comes before the Blueprint's own Tick in thirdjam's world: what [ReceiveTick] writes
	# to the animation (bReady, the look) is seen by the graph one tick later. Measured against thirdjam's figure: a
	# SetHasPuck moves BlendListByBool_0 on the second tick after the call, not the first.
	anim.update(DT)
	_show(anim.evaluate())
	_receive_tick(DT)
