class_name TLRigSkaterPuck
extends RefCounted
## The puck verbs of thirdjam's skater driver: the part of BP_SkaterVisual_TB1_P3 that plays shots, passes, the
## receive, the poke, the stick lift, the deke and what a stick's hit does to the carrier. Ported function by function
## from engine/rigs/skater/driver-ref/BP_SkaterVisual_TB1_P3.EventGraph.txt; `[Name]` names the listing's entry.
## Internal to engine/rigs/skater: TLRigSkater owns one (`takes`) and hands it the interface's calls. The Blueprint's
## variables that round 2 already declared live on the figure (`f.bDown`, `f.ActPri`, ...); the ones these verbs add
## live here, under the Blueprint's names. `f.anim` is the animation blueprint, `f._now` GetTimeSeconds (ticks / 60).
##
## What is NOT here: the spin has no take (thirdjam turns the figure by the pawn's facing: SpinVisualYawDeg); a
## one-timer is a shot like any other for the figure; SetTakeGrace and SetStickLock ([LayerTick]) have no caller in
## thirdjam's source at HEAD 8dc713c6 and are not ported.
## DEVIATIONS: sounds are not played; the log lines (Log, RxLog) are not written; the other figures [ChkScan] reads are
## given by TLRigSkater.set_rivals (the Blueprint finds every BP_SkaterVisual_TB1_P3 actor of the world).

var f: TLRigSkater

# ---- the Blueprint's variables these verbs add (class defaults, then [ReceiveBeginPlay])
var bPendingShoot: bool = false
var PendingShootAge: int = 0
var StumbleIn: int = 0
var StumbleT0: float = 0.0
var PassHoldW: float = 0.0
var PassLast: float = 0.0
var PassLastT: float = 0.0
var PassMon: int = 0                  # the take PlayPass started (0 = none: IsValid(PassMon) false)
var LiftPlayT: float = -10.0          # [ReceiveBeginPlay]
var LiftEvT: float = 0.0
var RxGap: float = 0.35               # [ReceiveBeginPlay]
var LastRxT: float = -10.0            # [ReceiveBeginPlay]
var LastHitT: float = 0.0
var RxKind: int = 0
var bPinned: bool = false
var PinT: float = 0.0
var ChkClose: float = 0.0
var ChkBest: float = 0.0
var ChkSide: float = 0.0
var ChkSize: int = 0


func _init(figure: TLRigSkater) -> void:
	f = figure


func _free_for(pri: int) -> bool:
	return not f.bDown and not f.bUpRun and (not f.anim.is_any_montage_playing() or pri >= f.ActPri)


## [PlayCut]: a take with its own blend-in, 0.2 s out.
func PlayCut(Anim: StringName, Pri: int, Start: float, BlendIn: float) -> void:
	if _free_for(Pri):
		f.ActPri = Pri
		f.anim.play_slot(Anim, BlendIn, 0.2, 1.0, Start)


## [PlayCut1]: the same, 0.1 s out.
func PlayCut1(Anim: StringName, Pri: int, Start: float, BlendIn: float) -> void:
	if _free_for(Pri):
		f.ActPri = Pri
		f.anim.play_slot(Anim, BlendIn, 0.1, 1.0, Start)


## [ChargeMix]: the held shot's wind-up and the held pass's layer.
func ChargeMix() -> void:
	f.anim.ChargeTime = f.ShootCharge * 0.26667
	f.anim.ChargeAlpha = clampf(f.ShootCharge * 5.0, 0.0, 1.0)
	f.anim.PassW = maxf(f.PassChg, PassHoldW) * (0.0 if (f.bDown or f.bUpRun) else 1.0)
	f._push_anim()


## [SetShotCharge]
func SetShotCharge(Charge01: float) -> void:
	f.ShootCharge = clampf(Charge01, 0.0, 1.0)
	ChargeMix()


## [SetPassCharge] (by name from the game mode's puck show, PuckRead.cpp:172-185)
func SetPassCharge(Charge01: float) -> void:
	f.PassChg = clampf(Charge01, 0.0, 1.0)
	if f.PassChg > 0.0:
		PassLast = f.PassChg
		PassLastT = f._now
	ChargeMix()


## [PlayShoot]: a charged shot is the slap from where the wind-up stood; a tap is the wrist shot one call later
## ([SK2Tick]).
func PlayShoot(Charge: float) -> void:
	if Charge > 0.0:
		bPendingShoot = false
		f._play_act(&"Shot_Slap", 4, 1.0, minf(Charge, f.ShootCharge) * 0.26667)
	else:
		bPendingShoot = true
		PendingShootAge = 0


## [SK2Tick], its two takes: the wrist shot of a tap, the short stumble after a missed poke.
func sk2_takes() -> void:
	if bPendingShoot:
		if PendingShootAge >= 1:
			bPendingShoot = false
			f._play_act(&"Shot_Wrist", 4, 1.0, 0.0)
		else:
			PendingShootAge = 1
	if StumbleIn > 0 and (f._now - StumbleT0) >= 0.095:
		StumbleIn = 0
		PlayCut(&"Stumble_Short", 3, maxf(0.0, (f._now - StumbleT0) - 0.1), 0.0)


## [PlayPass]: the snap from 0.0834 s in; the charge layer stays under it for its first frames ([PassHoldTick]).
func PlayPass(_Strength: float) -> void:
	bPendingShoot = false
	PassHoldW = PassLast if (f._now - PassLastT) <= 0.1 else 0.0
	PassLast = 0.0
	f.PassChg = 0.0
	if _free_for(3):
		f.ActPri = 3
		PassMon = f.anim.play_slot(&"Pass_Snap", 0.0333, 0.05, 1.0, 0.0834, 1, 0.0)
	else:
		PassHoldW = 0.0
	ChargeMix()


## [PassHoldTick] (from [ReceiveTick] while PassHoldW > 0)
func PassHoldTick() -> void:
	if PassMon == 0 or not f.anim.montage_is_playing(PassMon) or f.anim.montage_position_of(PassMon) >= 0.1217:
		PassHoldW = 0.0
		ChargeMix()


## [PlayReceive] (by name from the puck show, PuckRead.cpp:187-194)
func PlayReceive() -> void:
	if _free_for(3):
		f.ActPri = 3
		f.anim.play_slot(&"Receive", 0.03, 0.06, 1.0, 0.0)


## [PlayCallForPass] (by name from the puck show, PuckRead.cpp:197-222)
func PlayCallForPass() -> void:
	if _free_for(2):
		f.ActPri = 2
		f.anim.play_slot(&"CallForPass", 0.05, 0.12, 1.0, 0.0)


## [PlayPoke]: the poke; a MISSED one is followed by the short stumble 0.095 s later ([SK2Tick]).
## (StumbleIn = SelectInt(0, 1, bClean): 0 when clean. Read the other way round at first; thirdjam's figure showed it.)
func PlayPoke(bClean: bool) -> void:
	f._play_act(&"Poke", 3, 1.0, 0.0)
	StumbleIn = 0 if bClean else 1
	StumbleT0 = f._now


## [ChkScan]: the nearest opposing figure: how far, on which side, how fast the two close (m/s along the line between
## them). Read by the lift here and by the checks.
func ChkScan() -> void:
	ChkClose = 0.0
	ChkBest = 100000.0
	ChkSide = 0.0
	var me: Vector2 = f.actor_xy_cm()
	for o: TLRigSkater in f.rivals:
		if o == null or not is_instance_valid(o) or o.team == f.team:
			continue
		var d: Vector2 = o.actor_xy_cm() - me
		if d.length() < ChkBest:
			ChkBest = d.length()
			var cf: float = cos(deg_to_rad(f.FacingYaw))
			var sf: float = sin(deg_to_rad(f.FacingYaw))
			ChkSide = d.y * cf - d.x * sf
			ChkClose = (d.x * (f.SpdPrev * cf - o.SpdPrev * cos(deg_to_rad(o.FacingYaw))) + d.y * (f.SpdPrev * sf - o.SpdPrev * sin(deg_to_rad(o.FacingYaw)))) / maxf(d.length(), 1.0)


## [LiftPlay]: light when the two part, heavy when they close at 11 m/s or more.
func LiftPlay() -> void:
	ChkSize = 0 if ChkClose < 0.0 else (2 if ChkClose >= 11.0 else 1)
	if ChkSize == 0:
		PlayCut1(&"Lift_Light", 6, 0.0, 0.03)
	elif ChkSize == 2:
		PlayCut1(&"Lift_Heavy", 6, 0.0, 0.03)
	else:
		PlayCut1(&"Lift", 6, 0.0, 0.03)


## [PlayLift]
func PlayLift() -> void:
	if (f._now - LiftPlayT) >= RxGap:
		if _free_for(6):
			bPinned = false
			LiftPlayT = f._now
			if (f._now - LiftEvT) < 0.05:
				f.LiftN = 22
		ChkScan()
		LiftPlay()


## [PlayStickHit]: the carrier's reaction to the stick that took his puck (a poke, or a lift).
func PlayStickHit(bLifted: bool) -> void:
	var kind: int = 2 if bLifted else 1
	if f.bDown or f.bUpRun or (bPinned and (f._now - PinT) < RxGap) or (f._now - LastRxT) < (RxGap if RxKind == kind else 0.45):
		return
	LastHitT = f._now
	LastRxT = f._now
	RxKind = kind
	PlayCut1(&"Lift_Hit" if bLifted else &"Poke_Hit", 6, 0.0, 0.03)


## [OnBusEvent], the puck verbs' part: thirdjam's event bus (the sim's events of the frame, delivered by the game mode
## before the pawns apply the frame: HokejGameMode.cpp:1488-1546, :1664). `me`: the event's Who is this figure's
## skater. `where_cm`: the event's place, world centimetres (rink x, rink z).
func bus_event(event: StringName, me: bool, where_cm: Vector2, strength: float, kind: StringName) -> void:
	if event == &"lift" and me and strength > 0.5:
		var d: Vector2 = where_cm - f.actor_xy_cm()
		f.LiftYaw = clampf(wrapf(rad_to_deg(atan2(d.y, d.x)) - f.FacingYaw, -180.0, 180.0), -60.0, 60.0)
		LiftEvT = f._now
		if (f._now - LiftPlayT) < 0.05:
			f.LiftN = 22
	if event == &"deke" and me:
		PlayCut1(&"Deke_Right" if kind == &"right" else &"Deke_Left", 4, 0.0, 0.05)
