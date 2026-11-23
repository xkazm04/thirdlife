class_name TLRigSkaterContact
extends TLRigSkaterFalls
## thirdjam's Blueprint BP_SkaterVisual_TB1_P3, the contact: the body check and its wind-up takes, the misses and
## whiffs, the cross-check (wind, hold, release, whiff), being hit (hit reaction, stumble), and what the event bus
## tells the figure (check, knockdown, lift, deke). Function by function from
## engine/rigs/skater/driver-ref/BP_SkaterVisual_TB1_P3.EventGraph.txt: `[Name]` is the listing's entry, `L<a>-<b>` its
## lines. Falls, get-ups, boards and the whip are in TLRigSkaterFalls; PlayCut, PlayCut1, ChkScan, LiftPlay and the
## reaction clocks (RxGap, LastRxT, LastHitT, RxKind) in TLRigSkaterPuck.
##
## The figure's tick calls, in [ReceiveTick]'s order (L1274-1317): PassHoldTick (puck), WhipTick() while bWhip,
## HoldTick() while bHoldRun, WindHoldTick(0.0) while WindHoldLeft > 0, the look, then ReceiveTickDown(dt).
## [ChkMissTick]'s timer (K2_SetTimer, 0.108 s) is kept as ChkMissAt / TimerTick; it is dead while bAutoCheckMiss is
## false, and nothing in the Blueprint or in thirdjam's C++ sets it.

# ---- the Blueprint's variables (class defaults from the export's defaults.json)
var WhiffT: float = 0.0
var WhiffF: float = 0.0
var WhiffBl: float = 0.0
var WindT0: float = 0.0
var WindN: int = 0
var bWindupTakes: bool = false       # thirdjam's game sets it true on every figure (HitRead.cpp:646-664, jam.hit.BTakes 2)
var WindHoldMon: Dictionary = {}     # a montage instance of f.anim (identity), {} = None
var WindHoldLeft: float = 0.0
var bAutoCheckMiss: bool = false
var bChkWait: bool = false
var ChkBusT: float = -10.0           # class default -10.0
var ChkMissAt: float = -1.0          # ours: when the ChkMissTick timer fires (-1 = not armed)
var bHoldRun: bool = false
var bHoldSeen: bool = false
var bRelNow: bool = false
var HoldW0: float = 0.0
var HoldT0: float = 0.0
var HoldRate: float = 0.0
var HoldOffT: float = 0.0
var StumSpan: float = 18.0           # BeginPlay L1250 (class default 0.0)


# ------------------------------------------------------------------ the body check
## [PlayCheck] L822-833. thirdjam's pawn: JamPawns.cpp:496 (bCheckThisFrame), before PlayCheckWindup (:501).
func PlayCheck() -> void:
	ChkScan()
	if f._now < WhiffT and not f.bDown and not f.bUpRun:
		WhiffT = -10.0                   # a check cuts a whiff
		WindT0 = -10.0
		f.ActPri = 0
	if not f.anim.has_active_montage() or f.ActPri != 7:
		ChkPlay(ChkSide >= 0.0)
		if bAutoCheckMiss and (f._now - ChkBusT) > 0.1:
			bChkWait = true
			ChkMissAt = f._now + 0.108       # K2_SetTimer(ChkMissTick, 0.108, not looping)


## Unreal's timer manager, once a world tick (see NEEDS).
func TimerTick() -> void:
	if ChkMissAt >= 0.0 and f._now >= ChkMissAt:
		ChkMissAt = -1.0
		ChkMissTick()


## [ChkMissTick] L141-145
func ChkMissTick() -> void:
	if bChkWait and not f.bDown and not f.bUpRun and f.ActPri == 7 and f.anim.is_any_montage_playing():
		PlayCheckMiss()
	bChkWait = false


## [ChkPlay] L147-150: the take's size from the closing speed ChkScan found (m/s: 11 and over is the heavy take, an opening gap the light).
func ChkPlay(bRight: bool) -> void:
	ChkSize = 0 if ChkClose < 0.0 else (2 if ChkClose >= 11.0 else 1)
	ChkCut(bRight, 0.0, 0.03)


## [ChkCut] L97-116. The light takes go through PlayCut1 (blend-out 0.1), the others through PlayCut (0.2).
func ChkCut(bRight: bool, Start: float, BlendIn: float) -> void:
	if bWindupTakes:
		ChkCutWind(bRight, BlendIn)
	elif bRight and ChkSize == 0:
		PlayCut1(&"Check_Deliver_Right_Light", 7, Start, BlendIn)
	elif bRight and ChkSize == 2:
		PlayCut(&"Check_Deliver_Right_Heavy", 7, Start, BlendIn)
	elif bRight:
		PlayCut(&"Check_Deliver_Right", 7, Start, BlendIn)
	elif ChkSize == 0:
		PlayCut1(&"Check_Deliver_Left_Light", 7, Start, BlendIn)
	elif ChkSize == 2:
		PlayCut(&"Check_Deliver_Left_Heavy", 7, Start, BlendIn)
	else:
		PlayCut(&"Check_Deliver_Left", 7, Start, BlendIn)


## [ChkCutWind] L118-139: the takes with their wind-up; a wind started under 0.4 s ago and still playing is kept.
func ChkCutWind(bRight: bool, BlendIn: float) -> void:
	if (f._now - WindT0) < 0.4 and f.ActPri == 7 and f.anim.is_any_montage_playing():
		return
	WindT0 = f._now
	var n: int = WindN if WindN > 0 else 8
	var start: float = float(clampi(10 - n, 0, 10)) / 60.0
	if bRight and ChkSize == 0:
		PlayCut1(&"Check_Deliver_Right_Light_Wind", 7, start, BlendIn)
	elif bRight and ChkSize == 2:
		PlayCut(&"Check_Deliver_Right_Heavy_Wind", 7, start, BlendIn)
	elif bRight:
		PlayCut(&"Check_Deliver_Right_Wind", 7, start, BlendIn)
	elif ChkSize == 0:
		PlayCut1(&"Check_Deliver_Left_Light_Wind", 7, start, BlendIn)
	elif ChkSize == 2:
		PlayCut(&"Check_Deliver_Left_Heavy_Wind", 7, start, BlendIn)
	else:
		PlayCut(&"Check_Deliver_Left_Wind", 7, start, BlendIn)


## [SetWindupTakes] L1652-1654 (by name from thirdjam's HitRead.cpp:662: (true, 8) on every figure)
func SetWindupTakes(bOn: bool, N: int) -> void:
	bWindupTakes = bOn
	WindN = N


## [PlayCheckWindup] L862-871 (by name from the pawn, JamPawns.cpp:501, right after PlayCheck on the same frame): the
## wind take just started is set to the key that leaves `Frames` frames to its contact (key 10); more than 10 frames
## hold its first key for the rest.
func PlayCheckWindup(Frames: int) -> void:
	if bWindupTakes and (f._now - WindT0) < 0.02 and Frames > 0 and f.anim.has_active_montage():
		f.anim.montage_set_position(float(clampi(10 - Frames, 0, 10)) / 60.0)
		if Frames > 10:
			WindHoldMon = f.anim._active_montage()
			WindHoldLeft = float(Frames - 10) / 60.0
		else:
			WindHoldLeft = 0.0


## [WindHoldTick] L1982-1991 (from [ReceiveTick] L1283-1284 while WindHoldLeft > 0): the held take is put back on its
## first key every tick until the hold is spent.
func WindHoldTick(_Dt: float) -> void:
	if f.bDown or f.bUpRun or WindHoldMon.is_empty() or not is_same(f.anim._active_montage(), WindHoldMon):
		WindHoldLeft = 0.0
	else:
		WindHoldLeft = WindHoldLeft - f.anim.montage_position()
		f.anim.montage_set_position(0.0)
		if WindHoldLeft <= 0.0083:
			WindHoldLeft = 0.0


## [PlayCheckMiss] L835-843
func PlayCheckMiss() -> void:
	bChkWait = false
	if f.bDown or f.bUpRun:
		return
	f.ActPri = 7
	WhiffT = f._now + 0.4
	f.anim.play_slot(&"Stumble_Back", 0.1, 0.15, 1.0, 0.033)


## [PlayCheckWhiff] L845-860
func PlayCheckWhiff() -> void:
	if f.bDown or f.bUpRun:
		return
	if f.SpeedNow < 4.0:
		PlayCheckMiss()                  # slow: the miss, not the whiff
	elif f.anim.has_active_montage() and f.ActPri == 7 and (f._now - WindT0) < 0.7:
		WhiffF = maxf((f.anim.montage_position() * 60.0) - 10.0, 0.0)
		WhiffBl = 0.05 if ChkSize == 1 else 0.083
		WhiffGo()
	else:
		WhiffF = 0.0
		WhiffBl = 0.083
		WhiffGo()


## [WhiffGo] L1938-1945
func WhiffGo() -> void:
	f.ActPri = 7
	WhiffT = f._now + 0.45
	if ChkSide >= 0.0:
		f.anim.play_slot(&"Check_Whiff_Right", WhiffBl, 0.2, 1.0, WhiffF / 60.0)
	else:
		f.anim.play_slot(&"Check_Whiff_Left", WhiffBl, 0.2, 1.0, WhiffF / 60.0)


## [PlayWhiff] L1220-1224 (by name: HitRead.cpp:811 on the sim's miss, Kind 0 body check / 1 cross-check; the pawn,
## JamPawns.cpp:534, PlayWhiff(1) for a hold released on nobody)
func PlayWhiff(Kind: int) -> void:
	if Kind == 1:
		PlayCrossWhiff()
	else:
		PlayCheckWhiff()


# ------------------------------------------------------------------ the cross-check
## [PlayCrossCheck] L873-880 (by name from the pawn, JamPawns.cpp:504, on bLiftThisFrame)
func PlayCrossCheck(Frames: int) -> void:
	WhiffT = -10.0
	if bHoldSeen and (f.bHoldOn or (f._now - HoldOffT) < 0.1):
		CrossRelease(1)
	elif bWindupTakes:
		CrossWind(Frames)


## [CrossWind] L181-194
func CrossWind(Frames: int) -> void:
	if f.bDown or f.bUpRun:
		return
	f.ActPri = 6
	LiftPlayT = f._now
	var n: int = Frames if Frames > 0 else (WindN if WindN > 0 else 8)
	f.anim.play_slot(&"CrossCheck_Wind", 0.05, 0.15, 1.0, float(clampi(10 - n, 0, 10)) / 60.0)
	if n > 10:
		WindHoldMon = f.anim._active_montage()
		WindHoldLeft = float(n - 10) / 60.0
	else:
		WindHoldLeft = 0.0


## [CrossRelease] L165-179. Why: 1 = PlayCrossCheck while the hold is (or was 0.1 s ago) on, 2 = the bus's check event.
func CrossRelease(_Why: int) -> void:
	if f.bHoldOn:
		HoldW0 = f.HoldE
		HoldT0 = f._now
		HoldRate = 20.0
		f.bHoldOn = false
		HoldOffT = f._now
		bHoldRun = true
	if f.bDown or f.bUpRun:
		return
	f.ActPri = 6
	LiftPlayT = f._now
	f.anim.play_slot(&"CrossCheck_Release", 0.05, 0.15, 1.0, 0.0)


## [SetCrossCheckHold] L1506-1518 (by name from the pawn, JamPawns.cpp:518, on the change of the hold pose wanted)
func SetCrossCheckHold(bOn: bool) -> void:
	if bOn != f.bHoldOn:
		HoldW0 = f.HoldE
		HoldT0 = f._now
		HoldRate = 10.0
		f.bHoldOn = bOn
		bHoldSeen = true
		bHoldRun = true
		if not bOn:
			HoldOffT = f._now


## [HoldTick] L478-505 (from [ReceiveTick] L1281-1282 while bHoldRun): the hold layer's weight and its three poses' times.
func HoldTick() -> void:
	var now: float = f._now
	f.HoldE = clampf(HoldW0 + ((1.0 if f.bHoldOn else -1.0) * ((now - HoldT0) * HoldRate)), 0.0, 1.0)
	f.anim.HoldW = f.HoldE * (0.0 if (f.bDown or f.bUpRun) else 1.0)
	f.anim.bHoldIn = f.bHoldOn and (now - HoldT0) < 0.1
	f.anim.bHoldOut = false
	f.anim.HoldInT = minf(now - HoldT0, 0.1)
	f.anim.HoldOutT = minf(now - HoldT0, 0.1)
	f.anim.HoldLoopT = fmod(maxf((now - HoldT0) - 0.1, 0.0), 0.9833)
	if not f.bHoldOn and f.HoldE <= 0.0:
		bHoldRun = false
	if f.bHoldOn and f.anim.has_active_montage() and f.ActPri == 6 and f.anim.montage_length() > 0.5 and f.anim.montage_position() >= 0.165:
		# the hold cuts the wind at contact
		HoldT0 = now - 0.1
		HoldW0 = 0.0
		f.ActPri = 0
		f.anim.montage_stop_all(0.1)             # Montage_Stop(0.1, the current active montage)
	if f.bHoldOn and f.bStop and f.ActPri == 5 and f.anim.has_active_montage():
		# the hold keeps over a stop take
		f.bStop = false
		f.ActPri = 0
		f.anim.montage_stop_all(0.1)


## [PlayCrossWhiff] L882-896. Both takes are played with BlendOutTriggerTime 0 (the blend-out starts at the clip's end).
func PlayCrossWhiff() -> void:
	if f.bDown or f.bUpRun:
		return
	if f.anim.has_active_montage() and f.ActPri == 6 and (f._now - LiftPlayT) < 0.7:
		WhiffF = maxf((f.anim.montage_position() * 60.0) - (3.0 if f.anim.montage_length() < 0.45 else 10.0), 0.0)
		f.ActPri = 7
		WhiffT = f._now + 0.3
		f.anim.play_slot(&"CrossCheck_Whiff", 0.05, 0.1, 1.0, WhiffF / 60.0, 1, 0.0)
	else:
		f.ActPri = 7
		WhiffT = f._now + 0.3
		f.anim.play_slot(&"CrossCheck_Whiff", 0.067, 0.1, 1.0, 0.0, 1, 0.0)


# ------------------------------------------------------------------ being hit
## [PlayHitReaction] L1029-1049. thirdjam's pawn: JamPawns.cpp:555-584 (a bump taken standing, when no stumble went out).
func PlayHitReaction(DirX: float, DirZ: float) -> void:
	var now: float = f._now
	if not f.bDown:
		WhipGo(DirX, DirZ, 0.0)
	if f.bDown or f.bUpRun or (now - LastHitT) < 0.6 or (now - LastRxT) < RxGap:
		return
	LastHitT = now
	LastRxT = now
	RxKind = 3
	if (DirX * _dcos(f.FacingYaw) + DirZ * _dsin(f.FacingYaw)) >= 0.7071:
		PlayCut1(&"Check_Hit_Back", 6, 0.0, 0.05)
	elif (DirZ * _dcos(f.FacingYaw) - DirX * _dsin(f.FacingYaw)) > 0.0:
		PlayCut1(&"Check_Hit_Left", 6, 0.0, 0.05)
	else:
		PlayCut1(&"Check_Hit_Right", 6, 0.0, 0.05)


## [PlayStumble] L1146-1154 (by name from the pawn, JamPawns.cpp:566): the take is stretched over `Frames` (32 keys of it).
func PlayStumble(DirX: float, DirZ: float, Frames: int) -> void:
	if not f.bDown:
		WhipGo(DirX, DirZ, 1.0)
	StumSpan = 32.0
	PlayStumbleNow(DirX, DirZ, Frames)
	StumSpan = 18.0


## [PlayStumbleNow] L1156-1177
func PlayStumbleNow(DirX: float, DirZ: float, Frames: int) -> void:
	var now: float = f._now
	if absf(now - StumT) < 0.001:
		return                           # a stumble already started on this frame
	if f.bDown or f.bUpRun:
		return
	LastHitT = now
	LastRxT = now
	RxKind = 3
	StumT = now
	f.bStop = false
	var along: float = DirX * _dcos(f.FacingYaw) + DirZ * _dsin(f.FacingYaw)
	if along >= 0.7071:
		StumPlay(&"Stumble_Back", Frames)
	elif along <= -0.7071:
		StumPlay(&"Stumble_Front", Frames)
	elif (DirZ * _dcos(f.FacingYaw) - DirX * _dsin(f.FacingYaw)) > 0.0:
		StumPlay(&"Stumble_Left", Frames)
	else:
		StumPlay(&"Stumble_Right", Frames)


## [StumPlay] L1775-1778: no guard (a stumble takes the slot whatever plays).
func StumPlay(Anim: StringName, Frames: int) -> void:
	f.ActPri = 8
	f.anim.play_slot(Anim, 0.03, 0.1, StumSpan / float(maxi(Frames, 4)), 0.0)


# ------------------------------------------------------------------ the event bus
## [OnBusEvent] L690-739, whole (it replaces TLRigSkaterPuck.bus_event). thirdjam's game mode sends every sim event of
## the frame to every figure before the pawns apply the frame (HokejGameMode.cpp:1488-1500 DeliverEvents, :1664).
## `me`: the event's Who is this figure's skater; `where_cm`: its place in the world, cm (UJamSim::ToWorld).
func bus_event(event: StringName, me: bool, where_cm: Vector2, strength: float, kind: StringName) -> void:
	var now: float = f._now
	var loc: Vector2 = f.actor_xy_cm()
	var d: Vector2 = where_cm - loc
	if event == &"knockdown":
		if me:
			HitStr = clampf(strength, 0.0, 1.0)
			if f.bDown and DownAge <= 1:
				DownRate = DownRate * (0.95 + 0.2 * HitStr)
				HitStr = -1.0
				f.anim.montage_set_rate(DownRate)
	if event == &"check":
		if me:
			bChkWait = false
			ChkBusT = now
			bRelNow = bHoldSeen and (f.bHoldOn or (now - HoldOffT) < 0.1)
			if bRelNow:
				CrossRelease(2)
			if not bRelNow and (not f.anim.has_active_montage() or f.ActPri != 7 or f.anim.montage_position() < 0.0667):
				if not (f.anim.has_active_montage() and f.ActPri == 7):
					ChkSize = 0 if strength < 0.35 else (2 if strength >= 0.7 else 1)
				ChkCut((d.y * _dcos(f.FacingYaw) - d.x * _dsin(f.FacingYaw)) >= 0.0, 0.1, 0.0)
	if event == &"knockdown":
		KdSeen = KdSeen + 1
		if me:
			LieRule = KdSeen % 2
			WhipStr(strength)
	if event == &"check":
		if me:
			WhipK = 0.0
			WhipGoS(d.x, d.y, 0.4 * clampf(strength, 0.0, 1.0))
		elif d.length() < 150.0:
			WhipStr(strength)
	if event == &"lift":
		if me and strength > 0.5:
			f.LiftYaw = clampf(wrapf(_datan2(d.y, d.x) - f.FacingYaw, -180.0, 180.0), -60.0, 60.0)
			LiftEvT = now
			if (now - LiftPlayT) < 0.05:
				f.LiftN = 22
	if event == &"deke":
		if me:
			PlayCut1(&"Deke_Right" if kind == &"right" else &"Deke_Left", 4, 0.0, 0.05)
