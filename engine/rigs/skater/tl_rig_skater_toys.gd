class_name TLRigSkaterToys
extends TLRigSkaterContact
## thirdjam's Blueprint BP_SkaterVisual_TB1_P3, what its GAME sends of the last family: the goal's celebration
## (PlayCelebrate), the boost glow (SetBoost) and the held ability's equipment (SetBoostEquipped, EquipApply, EquipTick).
## From engine/rigs/skater/driver-ref/BP_SkaterVisual_TB1_P3.EventGraph.txt; `[Name]` is the listing's entry. The last
## class of the figure's `takes` chain (Puck <- Whip <- Falls <- Contact <- Toys).
##
## NEVER SENT BY THIRDJAM'S GAME: the dash (PlayDash, SetBoostLevel), the dives and the slide tackle (PlayDiveBlock,
## PlayDiveBlockFront, PlayDiveBlockHit, PlaySlideTackle, PlaySlideTackleHit), the weapons (SetWeapon, PlayWeapon,
## PlayWeaponHit) and PlayBoostPickup are reached in the Blueprint only from [SK26Do] (L1321-1396), its own test
## dispatcher, which only [SK26Test] calls, and nothing in thirdjam's source at HEAD 8dc713c6 calls SK26Test or any of
## these by name. They are takes thirdjam built and never wired: the sandbox step's own rules would call them.
## Of them the dives and the slide tackle ARE ported below (and held to thirdjam's figure by calling them on both);
## the dash, the weapons and PlayBoostPickup are NOT ported.
## WHAT HAS NO POSE is kept as state for whoever draws it (the meshes and the material are not exported yet):
##   jersey_emissive   the jersey material's scalar "Emissive" (JerseyMID): 3.0 while boosted, 2.0 otherwise
##   equip_shown()     which of the four props is shown, and on which bone thirdjam hangs it

# ---- the Blueprint's variables (class defaults)
var bEqShotgun: bool = false
var bEqHip: bool = false
var bEqShield: bool = false
var bEqSlow: bool = false
var bEqHid: bool = false
var jersey_emissive: float = 2.0


## [PlayCelebrate] L805-820 (by name from JamBoostLook::CelebrateGoal, S/JamCore/Effects/JamPickupActor.cpp:654-679, with
## the take's index: 0 arms up, 1 stick raise, 2 knee glide for the scorer, 3 for his nearest mate).
func PlayCelebrate(Which: int) -> void:
	if f.bDown or f.bUpRun:
		return
	f.ActPri = 6
	var clip: StringName = &"Celebrate_ArmsUp"
	if Which == 1:
		clip = &"Celebrate_StickRaise"
	elif Which == 2:
		clip = &"Celebrate_KneeGlide"
	elif Which == 3:
		clip = &"Celebrate_Mate"
	f.anim.play_slot(clip, 0.15, 0.25, 1.0, 0.0)


## [SetBoost] L1461-1465 (the interface's: an effect boost on this skater, HokejGameMode.cpp:1696-1703; "" = none).
func SetBoost(Kind: StringName) -> void:
	jersey_emissive = 3.0 if String(Kind) != "" else 2.0


## [SetBoostEquipped] L1467-1483 (by name from AJamBoostAura::Sync, JamPickupActor.cpp:587-593, on a change of the
## held ability: (old, false), then (new, true)).
func SetBoostEquipped(Kind: StringName, bOn: bool) -> void:
	match String(Kind):
		"shotgun": bEqShotgun = bOn
		"hip_check": bEqHip = bOn
		"shield": bEqShield = bOn
		"slow_puck": bEqSlow = bOn
	bEqAny = bEqShotgun or bEqHip or bEqShield or bEqSlow
	EquipApply()


## [EquipApply] L367-372: the props are hidden while he is down or getting up.
func EquipApply() -> void:
	bEqHid = f.bDown or f.bUpRun


## [EquipTick] L379-382 (from [ReceiveTick] while bEqAny)
func EquipTick() -> void:
	if (f.bDown or f.bUpRun) != bEqHid:
		EquipApply()


## What [EquipShow] shows now: prop -> the bone it hangs on (thirdjam's components BoostShotgun, BoostHip, BoostShield,
## BoostSlow, attached to the mesh at that socket with their own relative places).
func equip_shown() -> Dictionary:
	var out: Dictionary = {}
	if bEqShotgun and not bEqHid:
		out[&"shotgun"] = &"spine_03"
	if bEqHip and not bEqHid:
		out[&"hip_check"] = &"pelvis"
	if bEqShield and not bEqHid:
		out[&"shield"] = &"spine_03"
	if bEqSlow and not bEqHid:
		out[&"slow_puck"] = &"head"
	return out


# ------------------------------------------------------------------ the dives and the slide tackle (never sent by thirdjam's game)
## [DiveGo] L304-313: a dive is a knockdown of his own making: the fall's take by its kind, its own release after
## `Frames` (64 and more) or the kind's own length `Def`.
func DiveGo(Kind: int, DX: float, DY: float, Frames: int, Def: int) -> void:
	if f.bDown or f.bUpRun:
		return
	DiveKind = Kind
	bDiveOwn = true
	DownFrames = Frames if Frames >= 64 else Def
	KnockDown(true, DX, DY, false)


## [PlayDiveBlock] L913-914: to the side the direction points to, across his facing.
func PlayDiveBlock(DirX: float, DirZ: float, Frames: int) -> void:
	var side: bool = (DirZ * _dcos(f.FacingYaw) - DirX * _dsin(f.FacingYaw)) >= 0.0
	DiveGo(1, (-1.0 if side else 1.0) * _dsin(f.FacingYaw), (1.0 if side else -1.0) * _dcos(f.FacingYaw), Frames, 103)


## [PlayDiveBlockFront] L916-918
func PlayDiveBlockFront(_DirX: float, _DirZ: float, Frames: int) -> void:
	SlideSide = 5
	DiveGo(4, _dcos(f.FacingYaw), _dsin(f.FacingYaw), Frames, 101)


## [PlayDiveBlockHit] L920-928: the puck hits the lying blocker.
func PlayDiveBlockHit() -> void:
	if f.bDown and DiveKind == 1 and bLie and not bUpEarly:
		bLie = false
		HoldAt = 0.166667
		DiveHitPlay(DownKind == 1)


## [DiveHitPlay] L315-319
func DiveHitPlay(bLeft: bool) -> void:
	f.anim.play_slot(&"Dive_Block_Hit_Left" if bLeft else &"Dive_Block_Hit_Right", 0.067, 0.0, 1.0, 0.0)


## [PlaySlideTackle] L1125-1127
func PlaySlideTackle(Frames: int, Side: int) -> void:
	SlideSide = Side
	DiveGo(2, -1.0 * _dcos(f.FacingYaw), -1.0 * _dsin(f.FacingYaw), Frames, 85)


## [PlaySlideTackleHit] L1129-1130: the tackled man's legs go, forward or back by where the hit came from.
func PlaySlideTackleHit(DirX: float, DirZ: float) -> void:
	BonkArm(2 if (DirX * _dcos(f.FacingYaw) + DirZ * _dsin(f.FacingYaw)) < 0.0 else 3)


## [BonkArm] L64-73: the knockdown that follows within 0.02 s falls by this kind ([FallPick] -> [BonkPick]).
func BonkArm(K: int) -> void:
	BonkKind = K
	BonkT = f._now
	if f.bDown and absf(f._now - DownT0) < 0.02:
		DownKind = 3 if K == 2 else 0
		DownYaw = f.FacingYaw
		bLie = false
		DownStart = 0.0 if K == 1 else 0.033333
		FallPick(true)
