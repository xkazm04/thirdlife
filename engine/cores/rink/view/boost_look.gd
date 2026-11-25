extends RefCounted
## What thirdjam's game does around its pawns for the toys (lane A188 there), as far as it reaches a figure:
## the goal's celebration (JamBoostLook::CelebrateGoal) and the held ability's equipment (AJamBoostAura::Sync).
## Presentation only: it reads RinkCore.snapshot() and calls the figures by name through their pawns
## (skater_pawn.gd `call_figure`). "S" = thirdjam's Game/Source, HEAD 8dc713c6.
##   celebration  S/JamCore/Effects/JamPickupActor.cpp:622-679 (CelebrateKind, PickScorer, CelebrateGoal), called for
##                every goal event inside the game mode's DeliverEvents (S/JamGame/Private/HokejGameMode.cpp:1504)
##   equipment    S/JamCore/Effects/JamPickupActor.cpp:455-466 (HeldKindFor), :564-594 (Sync: the figure call on a change),
##                called every drawn frame after the pawns are placed (HokejGameMode.cpp:1744)
## ONE SIM FRAME:
##   boost.deliver_events(snap, pawns)     # with the bus events, before skater_show's step_sim
##   ... the pawns apply the frame ...
##   boost.sync(snap, pawns)               # after the pawns
## `pawns`: the skater pawns, any order; each is found by its `sim_index`. `abilities`: the kinds of the cartridge's
## game.abilities[], by slot (`abilities_of`).
##
## DEVIATIONS from thirdjam:
##   - the scoring team is the one whose score rose on this step (thirdjam: the team that attacks the net on the
##     puck's side, UJamSim::AttackGoalX, which turns with bNetsSwapped: not in the snapshot). The same team unless
##     the sim scored nothing on a goal event.
##   - the figure call is SetBoostEquipped(Kind, bOn): thirdjam tries "SetBoost" first and takes the first of the two
##     that has (a name, a bool); thirdjam's own figure has SetBoost(Kind) alone under that name, as ours.
##   - NOT PORTED: the waist ring of light (AJamBoostAura's own mesh, shown only for a figure that did not take the
##     call) and jam.boost.Preview.
##   - the EFFECT boost's glow (IJamSkaterVisual::SetBoost(Kind) from UJamEffectSystem::GetBoostKindFor, HokejGameMode.cpp:
##     1696-1703, every frame there) is ported since the snapshot's `Boosts` (RinkCore 1.4, lane H2b): the figure is called
##     on a change of the kind only ("" = none; a skater never boosted is never called, so hokej's figures are untouched).

const CELEBRATE_KINDS: Array = ["arms_up", "stick_raise", "knee_glide"]      # JamPickupActor.cpp:624

var abilities: Array = []            # the cartridge's ability kinds by slot
var celebrations: Array = []         # [[frame, scorer, mate, kind, mate's kind]] so far
var _figure_kind: Dictionary = {}    # AJamBoostAura::FigureKind by skater (an aura exists once he held something)
var _prev_score: Array = [0, 0]
var _boost_kind: Dictionary = {}     # the effect boost each skater's figure was last told (SetBoost), by skater


## The kinds of game.abilities[] by slot.
static func abilities_of(cartridge: Dictionary) -> Array:
	var out: Array = []
	for a: Dictionary in (cartridge.get("game", {}) as Dictionary).get("abilities", []):
		out.append(String(a.get("kind", "")))
	return out


func reset() -> void:
	_figure_kind = {}
	_boost_kind = {}
	_prev_score = [0, 0]
	celebrations = []


## JamBoostLook::CelebrateKind (:622-628).
static func celebrate_kind(goal_count: int, scorer: bool) -> String:
	var i: int = ((goal_count % 3) + 3) % 3
	if scorer:
		return CELEBRATE_KINDS[i]
	return CELEBRATE_KINDS[2] if i == 1 else CELEBRATE_KINDS[1]


## JamBoostLook::PickScorer (:630-653): [scorer, mate]. `teams`: a skater's team, -1 for one in the box.
static func pick_scorer(teams: Array, pos: Array, scoring_team: int, who: int, where_m: Vector2) -> Array:
	var scorer: int = who if (who >= 0 and who < teams.size() and int(teams[who]) == scoring_team) else -1
	if scorer < 0:
		var best: float = 1e18
		for i: int in range(teams.size()):
			if int(teams[i]) != scoring_team:
				continue
			var d: float = (pos[i] as Vector2).distance_squared_to(where_m)
			if d < best:
				best = d
				scorer = i
	if scorer < 0:
		return [-1, -1]
	var mate: int = -1
	var best2: float = 1e18
	for i: int in range(teams.size()):
		if i == scorer or int(teams[i]) != scoring_team:
			continue
		var d2: float = (pos[i] as Vector2).distance_squared_to(pos[scorer] as Vector2)
		if d2 < best2:
			best2 = d2
			mate = i
	return [scorer, mate]


## AJamBoostAura::HeldKindFor (:455-466): the held kind, else the armed one after its last charge, else a running shield.
static func held_kind(s: Dictionary, kinds: Array) -> String:
	var slot: int = int(s["AbilitySlot"])
	if slot >= 0 and slot < kinds.size():
		return String(kinds[slot])
	if String(s["AbilityArmed"]) != "":
		return String(s["AbilityArmed"])
	if int(s["ShieldFrames"]) > 0:
		return "shield"
	return ""


func _pawn_of(pawns: Array, i: int) -> Object:
	for p: Object in pawns:
		if int(p.get("sim_index")) == i:
			return p
	return null


## Who celebrates (JamPickupActor.cpp:654-679 + JamSim.cpp:4424 ScoreGoal): the goal event's Who is Puck.LastTouch, the last skater
## who touched the puck, NOT necessarily the one who shot; he is the scorer when he skates for the scoring team, else the scoring
## team's skater nearest the puck; his nearest mate takes the mate's take. A mate's goal after the human's pass is the mate's.
## JamBoostLook::CelebrateGoal (:654-679) for every goal event of the frame: the scorer plays the take of the goal
## count (0 arms up, 1 stick raise, 2 knee glide), his nearest mate the mate's take (3). Returns the calls taken.
func deliver_events(snap: Dictionary, pawns: Array) -> int:
	var score: Array = snap["Score"]
	var took: int = 0
	for ev: Dictionary in snap["Events"]:
		if String(ev["Name"]) != "goal":
			continue
		var sk: Array = snap["Skaters"]
		var teams: Array = []
		var pos: Array = []
		for s: Dictionary in sk:
			teams.append(-1 if int(s["PenaltyFrames"]) > 0 else int(s["Team"]))
			pos.append(s["Pos"])
		var where_m: Vector2 = ev["Where"]
		var scoring: int = 0 if where_m.x > 0.0 else 1
		if int(score[0]) > int(_prev_score[0]):
			scoring = 0
		elif int(score[1]) > int(_prev_score[1]):
			scoring = 1
		var picked: Array = pick_scorer(teams, pos, scoring, int(ev["Who"]), where_m)
		var count: int = int(score[0]) + int(score[1])
		for pass_i: int in range(2):
			var idx: int = int(picked[pass_i])
			if idx < 0:
				continue
			var pawn: Object = _pawn_of(pawns, idx)
			# AJamBoostAura::CallPlayCelebrate (:500-520): a figure whose PlayCelebrate takes a number gets the take's index
			if pawn != null and bool(pawn.call(&"call_figure", &"PlayCelebrate", [(((count % 3) + 3) % 3) if pass_i == 0 else 3])):
				took += 1
		celebrations.append([int(snap["Frame"]), int(picked[0]), int(picked[1]), celebrate_kind(count, true), celebrate_kind(count, false)])
	_prev_score = [int(score[0]), int(score[1])]
	return took


## AJamBoostAura::Sync, the figure's part (:564-594): on a change of what a skater holds, (old, false) then (new, true).
func sync(snap: Dictionary, pawns: Array) -> void:
	var sk: Array = snap["Skaters"]
	var boosts: Array = snap.get("Boosts", [])
	for p: Object in pawns:
		var i: int = int(p.get("sim_index"))
		if i < 0 or i >= sk.size():
			continue
		var bk: String = String(boosts[i]) if i < boosts.size() else ""
		if bk != String(_boost_kind.get(i, "")):          # the effect boost's glow (HokejGameMode.cpp:1696-1703), on a change
			p.call(&"call_figure", &"SetBoost", [StringName(bk)])
			_boost_kind[i] = bk
		var held: String = held_kind(sk[i], abilities)
		if not _figure_kind.has(i):
			if held == "":
				continue             # the aura is made on the first hold only
			_figure_kind[i] = ""
		var was: String = String(_figure_kind[i])
		if held != was:
			if was != "":
				p.call(&"call_figure", &"SetBoostEquipped", [StringName(was), false])
			if held != "":
				p.call(&"call_figure", &"SetBoostEquipped", [StringName(held), true])
			_figure_kind[i] = held
