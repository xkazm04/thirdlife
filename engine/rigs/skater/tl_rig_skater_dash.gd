class_name TLRigSkaterDash
extends TLRigSkaterToys
## thirdjam's Blueprint BP_SkaterVisual_TB1_P3, the dash: a start, a loop of strides at the dash's rate, and its ends
## (the plain end handed over to the stride, a bump that breaks the loop, a skid, a wipe-out). From
## engine/rigs/skater/driver-ref/BP_SkaterVisual_TB1_P3.EventGraph.txt; `[Name]` is the listing's entry. The last class
## of the figure's `takes` chain. NEVER SENT BY THIRDJAM'S GAME (see TLRigSkaterToys): the sandbox step would call it.
##
## The dash runs on Unreal timers (K2_SetTimer by function name), so this file also holds the timer manager's rules
## (UE 5.9 Engine/Private/TimerManager.cpp, "TM"): a timer set while the world's timers have been ticked this frame
## expires at InternalTime + time (TM:709-711); one set earlier in the frame waits and gets the frame's time added
## after the timers ran (TM:719-722, :1377-1388); the world ticks its timers after its actors (LevelTick.cpp:1818), with
## the world's own delta; a timer fires when InternalTime is PAST its time (TM:1212), a looping one once for every
## period that passed (TM:1235, :1348). Setting a timer of the same function again replaces it.
## DEVIATION: a call that comes between two ticks sets its timer as thirdjam's game would within the frame (it waits
## for the frame's timer tick); in the oracle's world the calls are made after the world's tick, where Unreal counts
## from the tick before: `f._no_game_mode` (the oracle's switch) takes that rule. Sounds are not played.

var bDash: bool = false
var bBoostLv: bool = false
var DashRate: float = 0.0
var DashN: int = 0
var DashStep: int = 0            # 1 start, 2 loop, 3 end, 4 bump, 5 skid, 6 skid held on the brake
var DashMont: int = 0            # the take's id (0 = none)
var DashEndT: float = 0.0
var SkidT0: float = 0.0
var SkidSway: float = 1.5        # class default
var _tm: float = 0.0             # FTimerManager::InternalTime
var _timers: Dictionary = {}     # function -> [expire time, period, looping, waiting]
var _in_timers: bool = false
const DASH_LOOP_S: float = 0.4   # GetPlayLength(AS_SkaterTB1_P3_Dash_Loop), the asset all three reads name


# ------------------------------------------------------------------ Unreal's timers
func set_timer(fn: StringName, time: float, looping: bool = false) -> void:
	if time <= 0.0:
		_timers.erase(fn)
		return
	var active: bool = _in_timers or f._no_game_mode
	_timers[fn] = [(_tm + time) if active else time, time, looping, not active]


func clear_timer(fn: StringName) -> void:
	_timers.erase(fn)


## FTimerManager::Tick, once a world tick, after the actors (the figure calls it at the end of its tick).
func timers_step(dt: float) -> void:
	_tm += dt
	_in_timers = true
	var due: Array = []
	for fn: StringName in _timers.keys():
		var t: Array = _timers[fn]
		if not bool(t[3]) and _tm > float(t[0]):
			due.append(fn)
	for fn: StringName in due:
		if not _timers.has(fn):
			continue
		var t: Array = _timers[fn]
		var n: int = 1
		if bool(t[2]):
			n = int((_tm - float(t[0])) / float(t[1])) + 1
			t[0] = float(t[0]) + float(n) * float(t[1])
		else:
			_timers.erase(fn)
		for _i: int in range(n):
			call(fn)
	_in_timers = false
	for fn: StringName in _timers.keys():
		var t: Array = _timers[fn]
		if bool(t[3]):
			t[0] = float(t[0]) + _tm
			t[3] = false


# ------------------------------------------------------------------ the dash
## [PlayDash] L910-911: `Frames` of dash = a start of 10 frames and whole loops of 24, played at the rate that fits.
func PlayDash(Frames: int) -> void:
	var loops: int = maxi(1, floori((float(Frames) - 10.0) / 24.0 + 0.5))
	DashBegin(clampf((10.0 + 24.0 * float(loops)) / float(maxi(Frames, 1)), 0.7, 1.4), loops)


## [DashBegin] L196-213
func DashBegin(Rate: float, Loops: int) -> void:
	if f.bDown or f.bUpRun:
		return
	DashRate = Rate
	DashN = Loops
	bDash = true
	DashStep = 1
	# (bWeaponShown: WeaponShow(false), StickHide(false): the weapons are not ported)
	f.ActPri = 3
	DashMont = f.anim.play_slot(&"Dash_Start", 0.067, 0.0, Rate, 0.0)
	DashEndT = f._now + ((0.166667 + (DASH_LOOP_S * float(Loops))) / Rate)
	set_timer(&"DashNext", 0.15 / Rate)


## [DashCut] L215-224
func DashCut(bA: bool, AnimA: StringName, AnimB: StringName, BlendIn: float, BlendOut: float, Pri: int) -> void:
	f.ActPri = Pri
	DashMont = f.anim.play_slot(AnimA if bA else AnimB, BlendIn, BlendOut, 1.0, 0.0)


## [DashLoopGo] L226-236
func DashLoopGo() -> void:
	DashStep = 2
	f.ActPri = 3
	DashMont = f.anim.play_slot(&"Dash_Carry" if f.bPuck else &"Dash_Loop", 0.0, 0.0, DashRate, 0.0, DashN)
	set_timer(&"DashNext", ((DASH_LOOP_S * float(DashN)) - 0.016667) / DashRate)


## [DashNext] L238-283 (the timer's function)
func DashNext() -> void:
	if (f.bDown or f.bUpRun) or DashStep == 0:
		DashStep = 0
		clear_timer(&"DashNext")
	elif DashStep == 1:
		DashLoopGo()
	elif DashStep == 4:
		DashLoopGo()
	elif DashStep == 2:
		EndDash(0, 0.0, 0.0)
	elif DashStep == 3:
		DashStep = 0
		f.ActPri = 1
		DashMont = f.anim.play_slot(&"Stride", 0.0, 0.2, 1.0, 0.566667)      # the hand-over to the stride at its key 34
	elif DashStep == 5 and f.bBrkOn:
		f.anim.montage_pause_id(DashMont)
		DashStep = 6
		SkidT0 = f._now
		set_timer(&"DashNext", 0.016667, true)
	elif DashStep == 5:
		DashStep = 0
	elif DashStep == 6 and (not f.bBrkOn or (f._now - SkidT0) > 2.0):
		f.anim.montage_resume_id(DashMont)
		DashStep = 0
		clear_timer(&"DashNext")
	elif DashStep == 6:
		f.anim.montage_set_position_id(DashMont, (8.0 + (SkidSway * sin(7.854 * (f._now - SkidT0)))) / 60.0)


## [EndDash] L333-365. Reason: 0 its time is up, 1 a skid (DirZ >= 0: to the left), 2 a bump (the loop goes on),
## 3 a wipe-out (a fall of his own), 4 a light wipe-out.
func EndDash(Reason: int, _DirX: float, DirZ: float) -> void:
	bDash = Reason == 2
	if f.bDown or f.bUpRun:
		DashStep = 0
	elif Reason == 3:
		DashStep = 0
		SlideSide = 0
		DiveGo(4, _dcos(f.FacingYaw), _dsin(f.FacingYaw), 0, 86)
	elif Reason == 2:
		DashStep = 4
		DashCut(DirZ >= 0.0, &"Dash_Bump_Left", &"Dash_Bump_Right", 0.05, 0.0, 3)
		DashN = maxi(1, floori((((DashEndT - f._now) - 0.15) * DashRate) / DASH_LOOP_S + 0.5))
		set_timer(&"DashNext", 0.133333)
	elif Reason == 1:
		DashStep = 5
		DashCut(DirZ >= 0.0, &"Dash_Skid_Left", &"Dash_Skid", 0.06, 0.15, 4)
		set_timer(&"DashNext", 0.116667)
	elif Reason == 4:
		DashStep = 0
		DashCut(true, &"Dash_Wipeout_Light", &"Dash_Wipeout_Light", 0.05, 0.15, 4)
	else:
		DashStep = 3
		DashCut(true, &"Dash_End", &"Dash_End", 0.1, 0.0, 3)
		set_timer(&"DashNext", 0.183333)


## [SetBoostLevel] L1485-1491: a dash that lasts while the boost is on. (Ported; not in the compared run.)
func SetBoostLevel(bOn: bool, SpeedScale: float) -> void:
	if bOn:
		bBoostLv = true
		DashBegin(clampf(SpeedScale, 0.9, 1.3), 1000)
	else:
		bBoostLv = false
		EndDash(0, 0.0, 0.0)
