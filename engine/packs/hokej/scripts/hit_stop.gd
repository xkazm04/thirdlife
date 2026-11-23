extends RefCounted
## thirdjam's hit-stop, presentation only (K3 round 3; GAMEMODE.md row 20: "K2's pawn and K3's camera"). S = thirdjam HEAD
## 8dc713c6 Game/Source. On a knockdown or a stumble that involves the human, the camera (and, here, the two figures and the
## puck) hold the hit frame for 1-6 frames while the sim runs on: AHokejGameMode::HitStopRoute (JamGame/Private/
## HokejGameMode.cpp:1753-1775), AJamSkater::HitStopPick / HitStopFramesFor (JamCore/Private/JamPawns.cpp:144-224), and the
## presentation push skipped while held (HokejGameMode.cpp:1708). jam.hitstop 3 (JamPawns.cpp:144). The figures' own hold
## (AJamSkater::BeginHitStop, HoldArmed) is the pawn's: lane K2 replaces the stand-in hold.

const BASE: int = 3                     # jam.hitstop default (JamPawns.cpp:144-145)
const NONE: int = 0                     # UJamSim::ContactNone / Bump / Stumble / Down (JamSim.h:717-720)
const BUMP: int = 1
const STUMBLE: int = 2
const DOWN: int = 3

var start: int = -1
var end_frame: int = -1
var victim: int = -1
var checker: int = -1
var contact: Dictionary = {}            # FJamContactConfig: BumpRatio 0.4, DownRatio 1.0, DownFullRatio 3.0 (JamCartridge.h:396-399)


func _init(contact_cfg: Dictionary) -> void:
	contact = contact_cfg


## AJamSkater::HitStopFramesFor (JamPawns.cpp:157-167).
func frames_for(outcome: int, ratio: float) -> int:
	if outcome == NONE:
		return clampi(BASE, 0, 6)
	var at3: float = 0.0
	if outcome == STUMBLE:
		at3 = 2.0 if ratio >= 0.5 * (float(contact["BumpRatio"]) + float(contact["DownRatio"])) - 1e-6 else 1.0
	elif outcome == DOWN:
		at3 = lerpf(2.0, 6.0, clampf((ratio - float(contact["DownRatio"])) / maxf(1e-6, float(contact["DownFullRatio"]) - float(contact["DownRatio"])), 0.0, 1.0))
	else:
		return 0
	return clampi(roundi(at3 * BASE / 3.0), 1, 6)


## AJamSkater::HitStopPick (JamPawns.cpp:169-224): [victim, checker, outcome, ratio].
static func pick(sk: Array, events: Array, human: int, bump_ratio: float) -> Array:
	var last_checker: int = -1
	for e: Dictionary in events:
		if String(e["Name"]) == "check":
			last_checker = int(e["Who"])
	var v: int = -1
	var c: int = -1
	var outcome: int = NONE
	var ratio: float = 0.0
	for e: Dictionary in events:                                    # 1. a knockdown by a check
		if String(e["Name"]) != "knockdown" or String(e["Kind"]) != "check":
			continue
		var who: int = int(e["Who"])
		var resolved: bool = who >= 0 and who < sk.size() and int(sk[who]["ContactOutcome"]) == DOWN
		var chk: int = int(sk[who]["ContactBy"]) if resolved and int(sk[who]["ContactBy"]) >= 0 else last_checker
		if who != human and chk != human:
			continue
		if v == human:
			continue
		v = who
		c = chk
		outcome = DOWN if resolved else NONE
		ratio = float(sk[who]["ContactRatio"]) if resolved else 0.0
	if v >= 0:
		return [v, c, outcome, ratio]
	for pass_i: int in 2:                                          # 2. a stumble: the human's own, else one it landed
		for s: Dictionary in sk:
			if int(s["ContactOutcome"]) != STUMBLE or (int(s["Index"]) != human if pass_i == 0 else int(s["ContactBy"]) != human):
				continue
			return [int(s["Index"]), int(s["ContactBy"]), STUMBLE, float(s["ContactRatio"])]
	if human >= 0 and human < sk.size() and bool(sk[human]["bRecoilThisFrame"]):   # 3. the human's own bounce
		var by: int = -1
		for s: Dictionary in sk:
			if int(s["ContactBy"]) == human:
				by = int(s["Index"])
		return [human, by, STUMBLE, bump_ratio]
	return [-1, -1, NONE, 0.0]


## AHokejGameMode::HitStopRoute (HokejGameMode.cpp:1753-1775), called after the sim stepped (cpp:1665).
func route(snap: Dictionary) -> void:
	var f: int = int(snap["Frame"])
	if BASE <= 0 or f <= end_frame:
		return
	var p: Array = pick(snap["Skaters"], snap["Events"], int(snap["HumanIndex"]), float(contact["BumpRatio"]))
	if int(p[0]) < 0:
		return
	var hold: int = frames_for(int(p[2]), float(p[3]))
	if hold <= 0:
		return
	victim = p[0]
	checker = p[1]
	start = f
	end_frame = start + hold - 1


## The presentation frame is held: the frame after the hit's, through its end (HokejGameMode.cpp:1708).
func held(frame: int) -> bool:
	return frame > start and frame <= end_frame
