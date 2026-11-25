extends RefCounted
## thirdjam's hit read, the part that reaches a figure: the model of presses and hits (which check or cross-check was
## pressed, whether it landed, missed or stripped the puck) and what the game mode's hit layer does with it for the
## eye: a miss is told to the figure as its whiff take, and a body check that lands inside its wind-up has the
## checker's figure run forward to its contact pose. Presentation only: it reads RinkCore.snapshot() after a step and
## writes nothing back. "S" = thirdjam's Game/Source, HEAD 8dc713c6.
##   the model     S/JamGame/Public/HitRead.h:63 (EJamHitResult), :67-222 (FJamHitReadModel: FPress :119, FHitLog :158),
##                 S/JamGame/Private/HitRead.cpp:146-151 (Reset), :153-329 (Step)
##   the calls     S/JamGame/Private/HitRead.cpp:691-734 (AJamHitRead::StepSim), :738-741 (RetimeFor), :747-752
##                 (JamHitSetFigureDilation), :754-841 (RetimeEarly: the whiff calls, the re-time)
##
## ONE SIM FRAME (HokejGameMode.cpp:1695-1706: the hit read steps after the pawns applied the frame):
##   show.step_sim(snap, pawns)                 # skater_show.gd: hit-stop, shown carrier
##   pawn.apply_sim_frame(s, frame)             # every pawn
##   show.after_pawns(snap, pawns)              # AJamHitRead::TellTakes (SetWindupTakes), the puck's hold
##   hits.step_sim(snap, pawns, core.last_human_input())     # this object: the model, the whiffs, the re-time
##   pawn.apply_render(s, alpha); figure.tick()
## `pawns`: the skater pawns (skater_pawn.gd), any order; each is found by its `sim_index`. The figure calls go out
## through `pawn.call_figure` (recorded in `pawn.show_calls`), the dilation through `pawn.set_figure_dilation`.
##
## DEVIATIONS from thirdjam (each with its reason):
##   - `human_input` is taken and not read: thirdjam's model is fed the sim's skater states and events only
##     (HitRead.cpp:153, :709); nothing of it reads the human's devices. The parameter stays for the caller's sake.
##   - the re-time sets the FIGURE's dilation; thirdjam sets the pawn actor's CustomTimeDilation too (HitRead.cpp:750).
##     Our pawn has no clock of its own.
##   - "the figure was told SetWindupTakes" (TakesOn, HitRead.cpp:663) is read as: the figure has that call and the
##     mode wants it (HIT_B_TAKES 2 = every figure). TellTakes itself is skater_show.gd's `after_pawns`, which runs
##     before this object on the same frame, as TellTakes runs before RetimeEarly (HitRead.cpp:729-730).
##   - a hit's closing speed (FHitLog::ClosingMps) is the check event's Strength x `skater_speed` (game.skater.speed);
##     the caller sets `skater_speed` from the cartridge, 0 when it does not (the read-out is then 0; nothing here
##     reads it).
##   - not kept (they feed the drawn bars, the lean, the pop and the JAMHIT line only: see NOT PORTED): FPress::Target
##     and TipMetFrame, FBurst, FDown, FFlash, FHitLog::BurstM and TipMet, the team colours.
## NOT PORTED (out of this object's scope: nothing of it reaches a figure's calls or its clock): Draw and the bars
## (HitRead.cpp:331-572), LeanFor / CheckLeanDeg (:131-144, :574-593), CheckPop / PopFor (:595-634), StepBraceSet
## (:844-852), LogStick (:854-888), Capture (:901-972), Render (:998-1080: the lean, the pop and the brace's set on the
## drawn figure, FastFwdRenderLeft), the edge arrows (:1130-1236), the JAMHIT log lines, and jam.hit.RetimeTest
## (:786-790: a proof switch, 0 in the game).

# ---- thirdjam's console variables at their shipped defaults
const HIT_RETIME: int = 1                # jam.hit.Retime, HitRead.cpp:63 (1 = run the figure forward, 2 = PlayCheckWindup(1))
const HIT_WHIFF: float = 0.8             # jam.hit.Whiff, HitRead.cpp:57 (read only when the whiff take is off)
const HIT_B_TAKES: int = 2               # jam.hit.BTakes, HitRead.cpp:43
const VIS_WHIFF_TAKE: bool = true        # jam.vis.WhiffTake, JamPawns.cpp:140 (AJamSkater::WhiffTakeOn)
# ---- constants (HitRead.h, JamSim.h)
const MISS_FADE_FRAMES: int = 12         # FJamHitReadModel::MissFadeFrames, HitRead.h:70
const LEAN_BACK_FRAMES: int = 8          # LeanBackFrames, HitRead.h:73
const RETIME_LEAD_FRAMES: int = 2        # AJamHitRead::RetimeLeadFrames, HitRead.h:329
const WHIFF_AIM_FRAMES: int = 30         # AJamHitRead::WhiffAimFrames, HitRead.h:328
const HUMAN_CHECK_WINDOW_FRAMES: int = 12     # UJamSim::HumanCheckWindowFrames, JamSim.h:514
const CHECK_WINDOW_FRAMES: int = 6            # UJamSim::CheckWindowFrames, JamSim.h:510
const CONTACT_STUMBLE: int = 2           # UJamSim::ContactStumble, JamSim.h:719
const CONTACT_DOWN: int = 3              # UJamSim::ContactDown, JamSim.h:720
# EJamHitResult (HitRead.h:63)
enum { RESULT_NONE, RESULT_BUMP, RESULT_STUMBLE, RESULT_DOWN, RESULT_MISS, RESULT_STRIP }
const RESULT_NAMES: Array = ["none", "bump", "stumble", "down", "miss", "strip"]      # HitResultName, HitRead.cpp:678-689

## game.skater.speed (m/s): a check event's Strength is the closing speed over it. Set by the caller; 0 = not given.
var skater_speed: float = 0.0
# ---- FJamHitReadModel's state (HitRead.h:203-220)
var presses: Array = []          # FPress: {Skater, Team, bCross, bHuman, PressFrame, Windup, Window, EndFrame, Result, bStripped}
var frame_logs: Array = []       # FHitLog of the last step: {Frame, Kind, Result, Checker, Victim, bHuman, ClosingMps, Windup, PressToContact}
var hits: int = 0
var misses: int = 0
var strips: int = 0
var _last_cross_press: Array = []
var _prev_missed: Array = []
var _last_frame: int = -1
# ---- AJamHitRead's state (HitRead.h:319)
var _fast_fwd: Dictionary = {}   # sim index -> the figure's clock runs forward this sim frame (FastFwd)


## A new match: FJamHitReadModel::Reset (HitRead.cpp:146-151; PrevMissed is not part of it there either) and the hit
## layer's own fast-forwards. A frame that goes back resets the model by itself (model_step).
func reset() -> void:
	_model_reset()
	_fast_fwd = {}


func _model_reset() -> void:
	presses = []
	frame_logs = []
	_last_cross_press = []
	_last_frame = -1
	hits = 0
	misses = 0
	strips = 0


## AJamHitRead::RetimeFor (HitRead.cpp:738-741): 1 when a check that lands `press_to_contact` frames after a press with
## `windup` frames of wind-up finds the take RETIME_LEAD_FRAMES or more short of its contact pose, else -1.
static func retime_for(press_to_contact: int, windup: int) -> int:
	return 1 if (press_to_contact >= 0 and windup > 0 and windup - press_to_contact >= RETIME_LEAD_FRAMES) else -1


func _running(who: int, cross: bool) -> Dictionary:
	for k: int in range(presses.size() - 1, -1, -1):
		var p: Dictionary = presses[k]
		if int(p["Skater"]) == who and bool(p["bCross"]) == cross and int(p["EndFrame"]) < 0:
			return p
	return {}


## FJamHitReadModel::Step (HitRead.cpp:153-329), without what only the bars read. `sk`: snapshot["Skaters"], `events`:
## snapshot["Events"], after the step of `frame`.
func model_step(frame: int, sk: Array, events: Array) -> void:
	if frame <= _last_frame:
		_model_reset()                 # a restart or a new match: the frame went back (:155)
	_last_frame = frame
	frame_logs = []
	var n: int = sk.size()
	if _last_cross_press.size() != n:
		_last_cross_press = []
		_last_cross_press.resize(n)
		_last_cross_press.fill(-100000)
	for i: int in range(n):
		if bool(sk[i]["bLiftThisFrame"]):
			_last_cross_press[i] = frame
	# the presses of this frame (:179-208)
	for i: int in range(n):
		var s: Dictionary = sk[i]
		for pass_i: int in range(2):
			var cross: bool = pass_i == 1
			if not bool(s["bLiftThisFrame"] if cross else s["bCheckThisFrame"]):
				continue
			var old: Dictionary = _running(i, cross)
			if not old.is_empty():
				old["EndFrame"] = frame      # a new press replaces a running one quietly
				old["Result"] = RESULT_NONE
			var windup: int = int(s["WindupFrames"]) if int(s["WindupFrames"]) > 0 else int(s["LiftWindupLeft"] if cross else s["CheckWindupLeft"])
			presses.append({"Skater": i, "Team": clampi(int(s["Team"]), 0, 1), "bCross": cross, "bHuman": bool(s["bHuman"]), "PressFrame": frame, "Windup": windup,
				"Window": 0 if cross else (HUMAN_CHECK_WINDOW_FRAMES if bool(s["bHuman"]) else CHECK_WINDOW_FRAMES), "EndFrame": -1, "Result": RESULT_NONE, "bStripped": false})
	# a stick lift that took the puck: the lifter's press knows it stripped (:222-229)
	for e: Dictionary in events:
		if String(e["Name"]) != "lift" or float(e["Strength"]) < 0.5:
			continue
		strips += 1
		var lp: Dictionary = _running(int(e["Who"]), true)
		if not lp.is_empty():
			lp["bStripped"] = true
	# the hits of this frame: every victim whose read-outs name the man who hit him (:230-268)
	var checkers_seen: Dictionary = {}
	for v: int in range(n):
		var vs: Dictionary = sk[v]
		var by: int = int(vs["ContactBy"])
		if by < 0 or int(vs["ContactOutcome"]) <= 0 or by >= n:
			continue
		var a: Dictionary = sk[by]
		var braced: bool = bool(vs["bCrossBraceHit"])
		var cross_hit: bool = braced or bool(vs["bContactCross"])
		var ev: Dictionary = {}
		for e: Dictionary in events:
			if String(e["Name"]) == "check" and int(e["Who"]) == int(a["Index"]):
				ev = e
				break
		var closing: float = float(ev["Strength"]) * skater_speed if not ev.is_empty() else 1.5
		var r: int = RESULT_DOWN if int(vs["ContactOutcome"]) >= CONTACT_DOWN else (RESULT_STUMBLE if int(vs["ContactOutcome"]) == CONTACT_STUMBLE else RESULT_BUMP)
		checkers_seen[int(a["Index"])] = true
		hits += 1
		var log: Dictionary = {"Frame": frame, "Kind": "braced" if braced else ("cross" if cross_hit else "check"), "Result": r, "Checker": int(a["Index"]), "Victim": v,
			"bHuman": bool(a["bHuman"]) or bool(vs["bHuman"]), "ClosingMps": closing if not ev.is_empty() else 0.0, "Windup": 0, "PressToContact": -1}
		var p: Dictionary = {} if braced else _running(int(a["Index"]), cross_hit)
		if not p.is_empty():
			p["EndFrame"] = frame
			p["Result"] = r
			log["Windup"] = int(p["Windup"])
			log["PressToContact"] = frame - int(p["PressFrame"])
		frame_logs.append(log)
	# a check event no read-out names (the momentum model off, a hip check) (:269-286)
	for e: Dictionary in events:
		var who: int = int(e["Who"])
		if String(e["Name"]) != "check" or checkers_seen.has(who) or who < 0 or who >= n:
			continue
		checkers_seen[who] = true
		hits += 1
		var r2: int = RESULT_STUMBLE if String(e.get("Outcome", "")) == "stumble" else RESULT_DOWN
		var log2: Dictionary = {"Frame": frame, "Kind": "check", "Result": r2, "Checker": who, "Victim": -1, "bHuman": bool(sk[who]["bHuman"]),
			"ClosingMps": float(e["Strength"]) * skater_speed, "Windup": 0, "PressToContact": -1}
		var p2: Dictionary = _running(who, false)
		if not p2.is_empty():
			p2["EndFrame"] = frame
			p2["Result"] = r2
			log2["Windup"] = int(p2["Windup"])
			log2["PressToContact"] = frame - int(p2["PressFrame"])
		frame_logs.append(log2)
	# the presses that came to nothing: a body check whose window ran out, a cross-check whose wind-up ran out with no
	# shove landed (:287-309)
	for p: Dictionary in presses:
		var who: int = int(p["Skater"])
		if int(p["EndFrame"]) >= 0 or who < 0 or who >= n:
			continue
		var s: Dictionary = sk[who]
		var cross: bool = bool(p["bCross"])
		var in_box: bool = int(s["PenaltyFrames"]) > 0
		var down: bool = int(s["KnockFrames"]) > 0
		# a body check's miss is the sim's own (ChecksMissed grew); a window that closed with no miss counted ends quietly
		var missed_now: bool = not cross and who < _prev_missed.size() and int(s["ChecksMissed"]) > int(_prev_missed[who])
		if (cross or not missed_now) and in_box:
			p["EndFrame"] = frame
			p["Result"] = RESULT_NONE
			continue
		if cross and down:
			p["EndFrame"] = frame
			p["Result"] = RESULT_NONE
			continue
		var over: bool = false
		if not cross:
			over = missed_now or (frame > int(p["PressFrame"]) and int(s["CheckWindupLeft"]) == 0 and int(s["CheckWindow"]) == 0)
		else:
			# lane A215: the miss is the live window's end (contact.cross_live_frames)
			over = frame >= int(p["PressFrame"]) + int(p["Windup"]) and int(s["LiftWindupLeft"]) == 0 and int(s["CrossLiveLeft"]) == 0
		if not over:
			continue
		p["EndFrame"] = frame
		if not cross and not missed_now:
			p["Result"] = RESULT_NONE
			continue
		p["Result"] = RESULT_STRIP if bool(p["bStripped"]) else RESULT_MISS
		if int(p["Result"]) == RESULT_MISS:
			misses += 1
		frame_logs.append({"Frame": frame, "Kind": "cross" if cross else "check", "Result": int(p["Result"]), "Checker": who, "Victim": -1, "bHuman": bool(p["bHuman"]),
			"ClosingMps": 0.0, "Windup": int(p["Windup"]), "PressToContact": -1})
	_prev_missed = []
	for i: int in range(n):
		_prev_missed.append(int(sk[i]["ChecksMissed"]))
	# forget what has finished drawing (:323-326)
	var keep: int = maxi(MISS_FADE_FRAMES, LEAN_BACK_FRAMES) + 2
	var live: Array = []
	for p: Dictionary in presses:
		if not (int(p["EndFrame"]) >= 0 and frame - int(p["EndFrame"]) > keep):
			live.append(p)
	presses = live


func _pawn_of(pawns: Array, who: int) -> Object:
	for a: Variant in pawns:
		if a != null and int((a as Object).get("sim_index")) == who:
			return a
	return null


## TakesOn[who] (HitRead.cpp:663): the figure was told SetWindupTakes(true, 8). See DEVIATIONS.
func _takes_on(pawn: Object, human: bool) -> bool:
	var fig: Variant = pawn.get("figure")
	var want: bool = HIT_B_TAKES == 2 or (HIT_B_TAKES == 1 and not human)
	return want and fig != null and (fig as Object).has_method(&"SetWindupTakes")


## AJamHitRead::StepSim (HitRead.cpp:691-734), the model's step and RetimeEarly (:754-841). Call it once a sim frame
## AFTER the pawns applied the frame and after skater_show.gd's `after_pawns`. `human_input`: RinkCore.last_human_input()
## (not read: see DEVIATIONS). Returns what it did this frame: {"logs": the frame's hit logs, "whiffs": [[skater, kind,
## call]], "retimes": [[skater, short_frames, how]], "hits", "misses", "strips" (the running counts)}.
func step_sim(snap: Dictionary, pawns: Array, _human_input: Dictionary = {}) -> Dictionary:
	var frame: int = int(snap["Frame"])
	var sk: Array = snap["Skaters"]
	model_step(frame, sk, snap["Events"])
	var whiffs: Array = []
	var retimes: Array = []
	# last frame's fast-forwards end here: back to the hold's stand-still while the hit-stop runs, else to the
	# figure's own clock (:757-764)
	for a: Variant in pawns:
		if a == null:
			continue
		var i: int = int((a as Object).get("sim_index"))
		if not bool(_fast_fwd.get(i, false)):
			continue
		_fast_fwd[i] = false
		(a as Object).call(&"set_figure_dilation", 0.0001 if bool((a as Object).call(&"is_hit_stopped")) else 1.0)
	# a miss is told to the figure by name (:791-830)
	if VIS_WHIFF_TAKE:
		# lane A224: PlayWhiff(Kind) first (0 body check, 1 cross-check), PlayCheckWhiff only for a figure without it;
		# the pawn keeps its other calls off the take while it runs (NoteWhiffTake). A cross-check whose live window
		# ended because he braces (or still holds the button) is not a miss yet: its whiff is the release on nobody
		# (the pawn's own, AJamSkater::ApplySimFrame).
		for l: Dictionary in frame_logs:
			if int(l["Result"]) != RESULT_MISS:
				continue
			var who: int = int(l["Checker"])
			var cross: bool = String(l["Kind"]) == "cross"
			if cross and who >= 0 and who < sk.size() and (bool(sk[who]["bCrossBraced"]) or int(sk[who]["CrossHoldFrames"]) > 0):
				whiffs.append([who, 1, "none (held)"])
				continue
			var pawn: Object = _pawn_of(pawns, who)
			if pawn == null:
				continue
			var sent: bool = pawn.call(&"call_figure", &"PlayWhiff", [1 if cross else 0])
			var sent_check: bool = not sent and not cross and bool(pawn.call(&"call_figure", &"PlayCheckWhiff", []))
			if sent or sent_check:
				pawn.call(&"note_whiff_take", 1 if cross else 0)
			whiffs.append([who, 1 if cross else 0, ("PlayWhiff(%d)" % (1 if cross else 0)) if sent else ("PlayCheckWhiff" if sent_check else "none")])
	elif HIT_WHIFF > 0.0:
		# main 94bb5b48's calls (:817-830): PlayCheckWhiff first, and a cross-check's stick sent back to the front
		for l: Dictionary in frame_logs:
			if int(l["Result"]) != RESULT_MISS:
				continue
			var pawn: Object = _pawn_of(pawns, int(l["Checker"]))
			if pawn == null:
				continue
			var cross: bool = String(l["Kind"]) == "cross"
			var sent_check: bool = not cross and bool(pawn.call(&"call_figure", &"PlayCheckWhiff", []))
			var sent: bool = sent_check or bool(pawn.call(&"call_figure", &"PlayWhiff", [1 if cross else 0]))
			if cross:
				pawn.call(&"set_aim_recover", WHIFF_AIM_FRAMES)
			whiffs.append([int(l["Checker"]), 1 if cross else 0, "PlayCheckWhiff" if sent_check else ("PlayWhiff" if sent else "none")])
	# the re-time: a body check that landed inside its wind-up (:832-840)
	if HIT_RETIME != 0:
		for l: Dictionary in frame_logs:
			var r: int = int(l["Result"])
			if String(l["Kind"]) != "check" or not (r == RESULT_BUMP or r == RESULT_STUMBLE or r == RESULT_DOWN):
				continue
			var who: int = int(l["Checker"])
			var pawn: Object = _pawn_of(pawns, who)
			if retime_for(int(l["PressToContact"]), int(l["Windup"])) < 0 or pawn == null or not _takes_on(pawn, who < sk.size() and bool(sk[who]["bHuman"])):
				continue
			var short_frames: int = int(l["Windup"]) - int(l["PressToContact"])
			# Send (:766-784)
			var how: String = "none"
			if HIT_RETIME >= 2:
				if bool(pawn.call(&"call_figure", &"PlayCheckWindup", [1])):
					how = "PlayCheckWindup(1)"
			else:
				_fast_fwd[who] = true
				pawn.call(&"set_figure_dilation", float(clampi(short_frames, 1, 10)))
				how = "fast_forward"
			retimes.append([who, short_frames, how])
	return {"logs": frame_logs, "whiffs": whiffs, "retimes": retimes, "hits": hits, "misses": misses, "strips": strips}
