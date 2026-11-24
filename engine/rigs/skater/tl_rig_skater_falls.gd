class_name TLRigSkaterFalls
extends TLRigSkaterWhip
## thirdjam's Blueprint BP_SkaterVisual_TB1_P3, the falls: knockdown, trip, board fall, the lie loops, the get-ups,
## the boards (hit, pin), the wall shift, the mesh's turn while down. The whip, the rink's walls and the small helpers
## are in TLRigSkaterWhip (tl_rig_skater_whip.gd).
## Function by function from engine/rigs/skater/driver-ref/BP_SkaterVisual_TB1_P3.EventGraph.txt: `[Name]` is the
## listing's entry, `L<a>-<b>` its lines; variables keep the Blueprint's names. Figure-side variables are `f.<Name>`.
## Unreal units: centimetres, degrees, seconds; GetTimeSeconds() = f._now. Clip names without "AS_SkaterTB1_P3_".
##
## NOT PORTED here (out of the contact scope, each marked where it would run): dive, slide, wipe, bonk (FallPick's first
## branches, DiveAdopt), equipment (EquipApply), the slide particles (SlideFx), the contact shadow (bShade), sounds, logs.

# ---- the Blueprint's variables (class defaults from the export's defaults.json; "BeginPlay" = [ReceiveBeginPlay] L1241-1254)
var KdCount: int = 0
var KdFront: int = 0
var KdBack: int = 0
var KdSeen: int = 0
var DownKind: int = 0            # 0 fall (front hit), 1 left, 2 right, 3 back, 4 trip, 5..8 board fall front / left / right / back
var DownYaw: float = 0.0
var StartYaw: float = 0.0
var TurnYaw: float = 0.0
var DownAge: int = 0
var DownFrames: int = 0
var DownStart: float = 0.0
var DownRate: float = 0.0
var DownLen: float = 0.0
var UpLen: float = 0.0
var DownHold: float = 0.0
var DownT0: float = 0.0
var HoldAt: float = 9.0          # BeginPlay (class default 0.0)
var HitStr: float = -1.0         # BeginPlay (class default 0.0)
var UpRateS: float = 0.0
var UpAt: float = 0.0
var UpStart: float = 0.0
var UpPlayRate: float = 0.0
var UpBlend: float = 0.083
var UpBlendQ: float = 0.083
var UpCount: int = 0
var UpT0: float = 0.0
var UpEndEst: float = 0.0
var GetUpFrames: int = 0
var GetUpN: int = 0
var LastGap: int = 0
var LastGapS: float = 0.0
var LastKd: String = ""
var bFwd: bool = false
var bSpin: bool = false
var bQuick: bool = false
var bSnap: bool = false
var bLie: bool = false
var bUpEarly: bool = false
var FallSize: int = 0
var LieL: int = 0
var LieF: int = 0
var LieS: float = 0.0
var LieRule: int = 0
var WallYaw: float = 0.0
var WallD: float = 0.0
var WallShift: float = 0.0
var ShiftE: float = 0.0
var DiveKind: int = 0            # 0 none, 1 dive block, 2 slide tackle, 3 the cannon's kick (a weapon: not ported), 4 wipe-out / front dive
var SlideSide: int = 0           # the slide tackle's side (+1 / -1); 5 = the front dive block
var bDiveOwn: bool = false
var BonkT: float = 0.0           # [BonkArm]: a hit by a slide tackle or a weapon just before the knockdown
var BonkKind: int = 0
var bShade: bool = false
var ShadeYaw: float = 0.0
var bPinWant: bool = false
var StumT: float = -10.0         # BeginPlay (class default 0.0)


## [SetTestMode] L1624-1625
func SetTestMode(M: int) -> void:
	UpMode = M


## [WallFix] L1841-1872: a fall towards a wall is turned to a side that is free.
func WallFix(DirX: float, DirZ: float) -> void:
	FindRink()
	if RinkHX > 1.0:
		WallAt(DirX, DirZ)
		if bWall:
			var loc: Vector2 = f.actor_xy_cm()
			if DownKind == 1 or DownKind == 2:
				WallAt(_dcos(f.FacingYaw), _dsin(f.FacingYaw))
				if not bWall:
					DownKind = 3
					DownYaw = f.FacingYaw
				else:
					WallAt(-1.0 * _dcos(f.FacingYaw), -1.0 * _dsin(f.FacingYaw))
					if not bWall:
						DownKind = 0
						DownYaw = f.FacingYaw
					else:
						DownKind = 3
						DownYaw = _datan2(-1.0 * loc.y, -1.0 * loc.x)
			else:
				WallAt(_dcos(f.FacingYaw + 90.0), _dsin(f.FacingYaw + 90.0))
				if not bWall:
					DownKind = 1
					DownYaw = f.FacingYaw
				else:
					WallAt(_dcos(f.FacingYaw - 90.0), _dsin(f.FacingYaw - 90.0))
					if not bWall:
						DownKind = 2
						DownYaw = f.FacingYaw
					else:
						DownKind = 3
						DownYaw = _datan2(-1.0 * loc.y, -1.0 * loc.x)


## [ShiftTick] L1657-1664 (from [UpdateMotion] L1834): the mesh slides off the wall while he lies and back as he gets up.
func ShiftTick() -> void:
	if WallShift != 0.0 or ShiftE != 0.0:
		var want: float = WallShift
		if not (f.bDown and not bUpEarly):
			want = WallShift * (1.0 - clampf((clampf((f._now - UpT0) / maxf(UpEndEst - UpT0, 0.05), 0.0, 1.0) - 0.39) / 0.61, 0.0, 1.0))
		var step: float = maxf(absf(WallShift) / 3.0, 1.0)
		ShiftE = ShiftE + clampf(want - ShiftE, -1.0 * step, step)
		var rel: float = WallYaw - f.actor_yaw_deg()
		f.set_mesh_relative_xy(0.0 + ShiftE * _dcos(rel), 0.0 + ShiftE * _dsin(rel))
		if not f.bDown and not f.bUpRun and absf(ShiftE) < 0.01:
			WallShift = 0.0
			ShiftE = 0.0
			f.set_mesh_relative_xy(0.0, 0.0)


## [UpdateMotion] L1824-1833: the mesh's yaw. Called by the figure's UpdateMotion after LiftN is counted down and the
## animation's Speed / TurnRate are set, before ShiftTick / StopTick / SK2Tick. `Facing` = BreakRotator(Facing).Yaw.
func UpdateMotionMesh(Facing: float) -> void:
	if f.bDown:
		DownAge = DownAge + 1
		var k: float = clampf((f._now - (UpEndEst - 0.05)) / 0.05, 0.0, 1.0) if bUpEarly else 0.0
		f.set_mesh_world_yaw(_rlerp_yaw(StartYaw, DownYaw + TurnYaw * k, minf(1.0, float(DownAge) / 6.0)))
	elif GetUpFrames > 0:
		GetUpFrames = GetUpFrames - 1
		f.set_mesh_world_yaw(_rlerp_yaw(Facing, DownYaw + TurnYaw, float(GetUpFrames) / float(maxi(GetUpN, 1))))
	else:
		var w: float = clampf(minf(float(22 - f.LiftN) / 3.0, float(f.LiftN) / 10.0), 0.0, 1.0) if f.LiftN > 0 else 0.0
		f.set_mesh_yaw_deg(0.0 + f.LiftYaw * w)


# ------------------------------------------------------------------ down
## [SetKnockedDown] L1532-1539. thirdjam's pawn: JamPawns.cpp:536-553 (on the change of KnockFrames > 0).
func SetKnockedDown(bDownIn: bool, DirX: float, DirZ: float, KnockdownFrames: int) -> void:
	if bDownIn and f.bDown and DiveKind != 0 and not bUpEarly:
		DiveAdopt(KnockdownFrames)
	else:
		DownFrames = maxi(KnockdownFrames, 0) if bDownIn else DownFrames
		bDiveOwn = false
		DiveKind = 0 if bDownIn else DiveKind
		KnockDown(bDownIn, DirX, DirZ, false)


## [SetTripped] L1627-1630 (no caller in thirdjam's C++: by name from tests only)
func SetTripped(bDownIn: bool, DirX: float, DirZ: float) -> void:
	if bDownIn:
		DownFrames = 0
	KnockDown(bDownIn, DirX, DirZ, true)


## [SK2Down] L1403-1409
func SK2Down() -> void:
	if f.bDown:
		bPendingShoot = false
		StumbleIn = 0
		f.anim.montage_stop_all(0.15)
	f._push_anim()


## [KnockDown] L529-630
func KnockDown(bDownIn: bool, DirX: float, DirZ: float, bTrip: bool) -> void:
	var now: float = f._now
	if bDownIn:
		StartYaw = f.FacingYaw
		if DiveKind == 0:
			WhipGo(DirX, DirZ, 0.5)
		var along: float = DirX * _dcos(f.FacingYaw) + DirZ * _dsin(f.FacingYaw)
		bFwd = along >= 0.0
		if bTrip:
			DownKind = 4
			DownYaw = f.FacingYaw
		elif along >= 0.7071:
			DownKind = 3
			DownYaw = _datan2(DirZ, DirX)
		elif along <= -0.7071:
			DownKind = 0
			DownYaw = _datan2(DirZ, DirX) + 180.0
		elif (DirZ * _dcos(f.FacingYaw) - DirX * _dsin(f.FacingYaw)) > 0.0:
			DownKind = 1
			DownYaw = _datan2(DirZ, DirX) - 90.0
		else:
			DownKind = 2
			DownYaw = _datan2(DirZ, DirX) + 90.0
		DownAge = 0
		var bonk: bool = absf(now - BonkT) < 0.02
		if bonk:
			DownKind = 3 if BonkKind == 2 else 0
			DownYaw = f.FacingYaw
		if not bTrip and DiveKind == 0 and not bonk:
			WallFix(DirX, DirZ)
		if DownKind == 0:
			bSpin = (KdFront % 2) == 1
			KdFront = KdFront + 1
		elif DownKind == 3:
			bSpin = (KdBack % 2) == 1
			KdBack = KdBack + 1
		else:
			bSpin = (KdCount % 3) == 1
		DownStart = 0.0 if (bTrip or DiveKind != 0 or (bonk and BonkKind == 1)) else 0.033333
		bQuick = DownFrames > 0 and DownFrames < 90
		bSnap = DownFrames > 0 and DownFrames < 70
		FallSize = 0 if (DownFrames > 0 and DownFrames < 90) else (2 if DownFrames >= 130 else 1)
		TurnYaw = 0.0
		bLie = false
		WallShift = 0.0
		PickLens()
		DownRate = 1.0
		HitStr = -1.0
		UpRateS = maxf(1.0, ((DownLen / DownRate) + UpLen) / maxf(float(DownFrames) / 60.0, 0.1)) if DownFrames > 0 else 1.0
		DownRate = DownRate * UpRateS
		UpAt = ((float(DownFrames) / 60.0) - (UpLen / UpRateS)) if DownFrames > 0 else -1.0
		DownT0 = now
		bUpEarly = false
		f.bUpRun = false
		GetUpFrames = 0
		bPinned = false
		f.bDown = true
		if bEqAny:
			EquipApply()
		SK2Down()
		bSlideFx = true                      # Activate(SlideFx, bReset = true)
		bShade = true
		ShadeYaw = DownYaw
		# ContactShadow: scale (2.2, 0.95, 1), Darkest 0.75, Flat 0.7     (the contact shadow: not ported)
		FallPick(true)
	else:
		if f.bDown:
			LastGap = DownAge
			f.bDown = false
			DiveKind = 0
			bDiveOwn = false
			GetUpN = 54
			bSlideFx = false                 # Deactivate(SlideFx)
			bShade = false
			# ContactShadow: scale (0.5, 0.7, 1), relative (3, 0, 0.4), Darkest 0.45, Flat 0
			GetUpFrames = GetUpN
			LastGapS = now - DownT0
			SK2Down()
			if bUpEarly:
				if (UpEndEst - now) > 0.1:
					GetUpN = 8
					GetUpFrames = 8
					f.anim.montage_set_rate(minf(8.0, maxf(UpPlayRate, 0.5) * ((UpEndEst - now) / 0.1)))
			else:
				UpStart = (UpLen * 0.6667) if DownFrames > 0 else 0.0
				UpPlayRate = 2.0 if DownFrames > 0 else 1.0
				if DownFrames > 0:
					GetUpN = 8
					GetUpFrames = 8
				UpBlend = 0.083
				PlayGetUp()


## [PickLens] L746-751
func PickLens() -> void:
	FallPick(false)
	if bQuick and DownKind < 5:
		SetLen(&"GetUp_Quick", true)
	else:
		SetLen(&"GetUp", true)


## [SetLen] L1541-1545
func SetLen(Anim: StringName, bUp: bool) -> void:
	if bUp:
		UpLen = _len(Anim)
	else:
		DownLen = _len(Anim) - DownStart


## [FallDo] L384-389
func FallDo(Anim: StringName, bPlay: bool, Hold: int) -> void:
	if bPlay:
		HoldAt = float(Hold) / 60.0
		PlayDown(Anim, DownRate)
	else:
		SetLen(Anim, false)


## [FallPick] L391-458
func FallPick(bPlay: bool) -> void:
	if DiveKind == 1 and DownKind == 1:
		FallDo(&"Dive_Block_Left", bPlay, 37)
	elif DiveKind == 1:
		FallDo(&"Dive_Block_Right", bPlay, 37)
	elif DiveKind == 2:
		SlidePick(bPlay)
	elif DiveKind == 3:
		FallDo(&"Cannon_Kick", bPlay, 23)
	elif DiveKind == 4:
		WipePick(bPlay)
	elif absf(f._now - BonkT) < 0.02:
		BonkPick(bPlay)
	elif DownKind == 4:
		FallDo(&"Trip", bPlay, 19)
	elif DownKind == 1:
		if FallSize == 0:
			FallDo(&"Knockdown_Left_Light", bPlay, 13)
		elif FallSize == 2:
			FallDo(&"Knockdown_Left_Heavy", bPlay, 28)
		elif bSpin:
			FallDo(&"Knockdown_Left_B", bPlay, 21)
		else:
			FallDo(&"Knockdown_Left", bPlay, 18)
	elif DownKind == 2:
		if FallSize == 0:
			FallDo(&"Knockdown_Right_Light", bPlay, 13)
		elif FallSize == 2:
			FallDo(&"Knockdown_Right_Heavy", bPlay, 28)
		elif bSpin:
			FallDo(&"Knockdown_Right_B", bPlay, 23)
		else:
			FallDo(&"Knockdown_Right", bPlay, 18)
	elif DownKind == 3:
		if FallSize == 0:
			FallDo(&"Knockdown_Back_Light", bPlay, 13)
		elif FallSize == 2:
			FallDo(&"Knockdown_Back_Heavy", bPlay, 28)
		elif bSpin:
			FallDo(&"Knockdown_Back_B", bPlay, 25)
		else:
			FallDo(&"Knockdown_Back", bPlay, 19)
	else:
		if FallSize == 0:
			FallDo(&"Fall_Light", bPlay, 13)
		elif FallSize == 2:
			FallDo(&"Fall_Heavy", bPlay, 28)
		elif bSpin:
			FallDo(&"Fall_B", bPlay, 24)
		else:
			FallDo(&"Fall", bPlay, 18)


## [DiveAdopt] L298-302: the sim's knockdown arrives while he lies in his own dive: the dive takes its length.
func DiveAdopt(N: int) -> void:
	bDiveOwn = false
	DownFrames = roundi((f._now - DownT0) * 60.0) + N
	UpAt = (float(DownFrames) / 60.0) - (UpLen / UpRateS)


## [SlidePick] L1673-1677
func SlidePick(bPlay: bool) -> void:
	FallDo(&"Slide_Tackle_Right" if SlideSide < 0 else &"Slide_Tackle_Left", bPlay, 19)


## [WipePick] L1993-1997
func WipePick(bPlay: bool) -> void:
	if SlideSide == 5:
		FallDo(&"Dive_Block_Front", bPlay, 35)
	else:
		FallDo(&"Dash_Wipeout", bPlay, 20)


## [BonkPick] L75-82
func BonkPick(bPlay: bool) -> void:
	if BonkKind == 2:
		FallDo(&"Fall_Legs_Front", bPlay, 19)
	elif BonkKind == 3:
		FallDo(&"Fall_Legs_Back", bPlay, 19)
	else:
		FallDo(&"Fall_Bonk", bPlay, 14)


## [PlayDown] L930-937. The blend-in is 0 while the hit-stop holds the figure (CustomTimeDilation < 0.01).
func PlayDown(Anim: StringName, Rate: float) -> void:
	f.ActPri = 9
	f.anim.play_slot(Anim, 0.0 if f._dilation < 0.01 else 0.03, 0.0, Rate, DownStart)
	DownHold = _len(Anim) - 0.004        # GetPlayLength(the dynamic montage) - 0.004
	KdCount = KdCount + 1
	LastKd = "AS_SkaterTB1_P3_" + String(Anim)


## [BoardFall] L3-62: a knockdown on the frame he met the boards falls against the wall (from [PlayBoardHit]).
func BoardFall() -> void:
	var loc: Vector2 = f.actor_xy_cm()
	KdCount = KdCount - 1
	var cx: float = absf(loc.x) - (RinkHX - RinkR)
	var cy: float = absf(loc.y) - (RinkHY - RinkR)
	if cx > 0.0 and cy > 0.0:
		WallYaw = _datan2(signf(loc.y) * cy, signf(loc.x) * cx)
		WallD = RinkR - sqrt(cx * cx + cy * cy)
	elif (RinkHX - absf(loc.x)) < (RinkHY - absf(loc.y)):
		WallYaw = 0.0 if loc.x > 0.0 else 180.0
		WallD = RinkHX - absf(loc.x)
	else:
		WallYaw = 90.0 if loc.y > 0.0 else -90.0
		WallD = RinkHY - absf(loc.y)
	TurnYaw = 0.0
	if _dcos(WallYaw - f.FacingYaw) >= 0.7071:
		DownKind = 5
		DownYaw = WallYaw
		TurnYaw = 90.0
	elif _dcos(WallYaw - f.FacingYaw) <= -0.7071:
		DownKind = 8
		DownYaw = WallYaw + 180.0
		TurnYaw = -90.0
	elif _dsin(WallYaw - f.FacingYaw) < 0.0:
		DownKind = 6
		DownYaw = WallYaw + 90.0
	else:
		DownKind = 7
		DownYaw = WallYaw - 90.0
	WallShift = 0.0 if UpMode == 4 else clampf(WallD - 35.0, -15.0, 30.0)
	DownStart = 0.033333
	HoldAt = 0.366667 if (DownKind == 5 or DownKind == 8) else 0.35
	bLie = false
	PickLens()
	SetLen(_board_fall_clip(DownKind), false)       # L39-48
	DownRate = 1.0
	UpRateS = maxf(1.0, (DownLen + UpLen) / maxf(float(DownFrames) / 60.0, 0.1)) if DownFrames > 0 else 1.0
	DownRate = UpRateS
	UpAt = ((float(DownFrames) / 60.0) - (UpLen / UpRateS)) if DownFrames > 0 else -1.0
	ShadeYaw = DownYaw
	PlayDown(_board_fall_clip(DownKind), DownRate)  # L54-63


## [PlayLie] L1051-1077: the lie loop (108 keys), entered at a key chosen so that the loop ends where the get-up starts.
func PlayLie() -> void:
	LieL = (ceili((((DownT0 + UpAt) - f._now) * 60.0) - 0.01) + 0) if UpAt >= 0.0 else 0
	var rule: bool = (LieRule == 1 or (UpMode % 32) >= 8) and LieL >= 24 and LieL <= 84
	if rule:
		LieF = clampi(93 - LieL, 39, 69)
	elif LieL < 16:
		LieF = 0
	elif LieL < 24:
		LieF = 15 - LieL
	elif LieL <= 84:
		LieF = clampi(39 - LieL, -15, 15)
	else:
		LieF = clampi(93 - LieL, -15, 15)
	LieS = float((LieF + 108) % 108) / 60.0
	f.anim.play_slot(_lie_clip(DownKind), 0.03, 0.0, 1.0, LieS, 1000)      # ActPri is not written here (stays 9)


## [PlayUp] L1179-1187
func PlayUp(Anim: StringName) -> void:
	f.ActPri = 6
	f.anim.play_slot(Anim, UpBlend, 0.05, maxf(UpPlayRate, 0.5), UpStart)
	UpCount = UpCount + 1
	f.bUpRun = true
	UpT0 = f._now
	UpEndEst = f._now + ((_len(Anim) - UpStart) / maxf(UpPlayRate, 0.5))


## The four timings of a get-up, as each DownKind's branch of [PlayGetUp] picks them (suffix "" / "_Side_Left" / ...).
func _up_pick(suffix: String) -> void:
	if UpMode == 1 and bQuick:
		PlayUp(StringName("GetUp_Late" + suffix))
	elif UpMode == 2 and not bQuick:
		PlayUp(StringName("GetUp_LateLong" + suffix))
	elif bSnap:
		PlayUp(StringName("GetUp_Snap" + suffix))
	elif bQuick:
		PlayUp(StringName("GetUp_Quick" + suffix))
	else:
		PlayUp(StringName("GetUp" + suffix))


## [PlayGetUp] L945-1027
func PlayGetUp() -> void:
	if DownKind == 5:
		PlayUp(&"GetUp_LateLong_Wall" if UpMode == 2 else &"GetUp_Wall")
	elif DownKind == 6:
		PlayUp(&"GetUp_LateLong_Wall_Left" if UpMode == 2 else &"GetUp_Wall_Left")
	elif DownKind == 7:
		PlayUp(&"GetUp_LateLong_Wall_Right" if UpMode == 2 else &"GetUp_Wall_Right")
	elif DownKind == 8:
		PlayUp(&"GetUp_LateLong_Wall_Back" if UpMode == 2 else &"GetUp_Wall_Back")
	elif DownKind == 1:
		_up_pick("_Side_Left")
	elif DownKind == 2 or DownKind == 4:
		_up_pick("_Side_Right")
	elif DownKind >= 3:
		_up_pick("_Front")
	else:
		_up_pick("")


# ------------------------------------------------------------------ the boards
## [PlayBoardHit] L767-787. thirdjam's pawn: JamPawns.cpp:610-619 (after SetKnockedDown, PlayStumble / PlayHitReaction).
func PlayBoardHit() -> void:
	var now: float = f._now
	FindRink()
	var loc: Vector2 = f.actor_xy_cm()
	if not f.bDown or absf(now - DownT0) < 0.001:
		var near_x: bool = (RinkHX - absf(loc.x)) < (RinkHY - absf(loc.y))
		WhipGo(signf(loc.x) if near_x else 0.0, 0.0 if near_x else signf(loc.y), 0.5)
	if f.bDown and absf(now - DownT0) < 0.001:
		BoardFall()
	elif absf(now - StumT) < 0.001:
		pass                                 # a stumble started on this frame keeps its take
	elif not f.bDown and not f.bUpRun and absf(now - LastHitT) < 0.001:
		f._play_act(&"Board_Hit", 6, 1.0, 0.0)
	elif f.bDown or f.bUpRun or (now - LastHitT) < 0.6:
		pass
	else:
		f._play_act(&"Board_Hit", 6, 1.0, 0.0)
		LastHitT = now


## [PinOn] L753-759
func PinOn() -> void:
	bPinned = true
	bPinWant = false
	PinT = f._now
	f.ActPri = 6
	f.anim.play_slot(&"Board_Pin", 0.15, 0.25, 1.0, 0.0, 1000)


## [SetBoardPin] L1441-1459. thirdjam's pawn: JamPawns.cpp:661-665 (on the change of bBoardPinned).
func SetBoardPin(bOn: bool) -> void:
	if not bOn:
		bPinWant = false
	if bOn and not f.bDown and (f._now - LastRxT) < RxGap:
		bPinWant = true
	elif bOn and not f.bDown and not f.bUpRun and (not f.anim.is_any_montage_playing() or f.ActPri <= 6):
		PinOn()
	elif not bOn and bPinned:
		bPinned = false
		if f.ActPri <= 6 and not f.bDown and not f.bUpRun:
			f.anim.montage_stop_all(0.25)


# ------------------------------------------------------------------ [ReceiveTick], the down part
## [ReceiveTick] L1297-1316, in its order: the waiting pin, the lie and the hold of a fall's last key, the early get-up,
## the end of a get-up. (L1291-1296, the contact shadow under a lying figure: not ported.)
func ReceiveTickDown(DeltaSeconds: float) -> void:
	var now: float = f._now
	if bPinWant and (now - LastRxT) >= RxGap and not f.bDown and not f.bUpRun and (not f.anim.is_any_montage_playing() or f.ActPri <= 6):
		PinOn()
	if f.bDown:
		if bDiveOwn and (now - DownT0) >= ((float(DownFrames) - 0.5) / 60.0):
			bDiveOwn = false
			KnockDown(false, 0.0, 0.0, false)
		if not bUpEarly and not bLie and f.anim.has_active_montage() and (f.anim.montage_position() + DeltaSeconds * DownRate) >= HoldAt:
			bLie = true
			PlayLie()
		if not bUpEarly and not bLie and f.anim.has_active_montage() and (f.anim.montage_position() + DeltaSeconds * DownRate) >= DownHold:
			f.anim.montage_pause()
		if not bUpEarly and UpAt >= 0.0 and ((now - DownT0) + 0.008) >= UpAt:
			bUpEarly = true
			UpPlayRate = UpRateS
			UpStart = maxf(0.0, ((now - DownT0) - UpAt) * UpRateS)
			if bLie and DownKind < 5:
				UpBlend = 0.0 if (not bQuick or DownKind == 0) else UpBlendQ
			else:
				UpBlend = 0.083
			PlayGetUp()
	if f.bUpRun:
		if f.anim.has_active_montage() and f.anim.montage_active_is_playing() and (now - UpT0) > 0.0:
			UpEndEst = now + ((f.anim.montage_length() - f.anim.montage_position()) / maxf(UpPlayRate, 0.5))
		else:
			f.bUpRun = false
