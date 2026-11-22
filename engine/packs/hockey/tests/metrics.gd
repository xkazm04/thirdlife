extends RefCounted
## N3 (22 Nov): the five bot metrics of docs/research/HOCKEY-ARCADE.md section 5.5, read from the pack state each frame
## (a test calls observe(s) every tick, then result() into its bot result). Only live frames count (rules running, not
## frozen). A team's possession runs from its first take until the other side takes the puck (its goalie too) or play
## stops; a loose puck in between stays the last holder's team's. Created by a test, no class_name.
##   possession: frames of each finished possession (seconds = /60)
##   passes: released by the side in possession; complete = the next take is by the passer's side
##   shots: by side; slot = released within slot_depth m of the goal line it attacks and |z| <= slot_half; one-timers
##   turnovers: the other side took it; cause = how it left the side (the last release in that possession):
##     poked -> poke, hit -> check, pass -> intercept, lost -> self, bobble -> bobble, dump -> dump, no release -> steal
##     (a goalie's take of a carried puck -> goalie); a shot that ends a possession is no turnover (counted "after_shot")
##   zone: live frames with the puck in each side's offensive zone (|x| >= blue_line on the side it attacks); entries:
##     a possession carrying the puck over its offensive blue line; success = held 120 frames in the zone or a shot from it

const BLUE_LINE := 10.0
const SLOT_DEPTH := 9.0
const SLOT_HALF := 4.0
const ENTRY_HOLD := 120

var team_of: Dictionary = {}
var role_of: Dictionary = {}
var live: int = 0
var cur: String = ""                   # side in possession ("" = nobody since the face-off)
var cur_start: int = 0
var cur_passes: int = 0
var prev_holder: String = ""
var prev_release_frame: int = -1
var take_frame: int = 0
var _last_sig: String = ""
var lengths: Array = []
var per_poss_passes: Array = []
var passes: Dictionary = {"blue": 0, "red": 0}
var complete: Dictionary = {"blue": 0, "red": 0}
var pending_pass: String = ""          # side of a pass in flight not yet resolved
var shots: Dictionary = {"blue": 0, "red": 0}
var slot_shots: Dictionary = {"blue": 0, "red": 0}
var one_timers: Dictionary = {"blue": 0, "red": 0}
var turnovers: Dictionary = {}
var after_shot: int = 0
var oz: Dictionary = {"blue": 0, "red": 0}
var entries: Dictionary = {"blue": 0, "red": 0}
var entries_ok: Dictionary = {"blue": 0, "red": 0}
var _entry_side: String = ""
var _entry_frames: int = 0
var _shots_seen: Dictionary = {}
var _ot_seen: Dictionary = {}
var _passes_seen: Dictionary = {}
var _prev_x: float = 0.0
var _was_live: bool = false
var frame: int = 0
var crowd_sum: int = 0                 # LOOP r1: field skaters within 5 m of the puck, summed over live frames
var crowd4: int = 0                    # live frames with 4 or more of them there (a scrum)
var crowd_roles: Dictionary = {}       # in scrum frames: the AI roles present (roles_now)
var goals_how: Array = []             # each goal: [side, the holder a frame before, the last release kind and by, puck x, z]
var _scores: Dictionary = {}
var _pre: Array = []
var moments: Dictionary = {}           # kind -> the bot frames it happened on (for clips): one_timer, poke, lost, bobble
var _rel_sig: String = ""
var _rel_at: Array = []                # where the last release started (puck x, z) and its receiver
var given: Dictionary = {}           # hits.given at the last live frame (side -> bump/stumble/knockdown/cross)


func _attack_sign(side: String) -> float:
	return 1.0 if side == "blue" else -1.0


func _end(cause: String) -> void:
	if cur != "":
		lengths.append(frame - cur_start)
		per_poss_passes.append(cur_passes)
		if cause != "":
			turnovers[cause] = int(turnovers.get(cause, 0)) + 1
	cur = ""
	cur_passes = 0
	_entry_side = ""


func observe(s: Dictionary) -> void:
	frame += 1
	if team_of.is_empty():
		for k: Dictionary in s.get("skaters", []):
			team_of[str(k["id"])] = str(k["team"])
			role_of[str(k["id"])] = str(k["role"])
	var is_live: bool = str(s.get("state", "")) == "running" and not bool(s.get("frozen", false)) and not s.has("menu") and not s.has("intro")
	var pos: Dictionary = s.get("possession", {})
	# counters move on live frames only; keep them in step on the others so a whistle's frame is not counted later
	var sc: Dictionary = s.get("scores", {})
	for sd: String in sc:
		if int(sc[sd]) > int(_scores.get(sd, 0)) and not _pre.is_empty():
			goals_how.append([sd] + _pre)
	_scores = sc.duplicate()
	var lr: Dictionary = pos.get("last", {})
	if str(lr) != _rel_sig:
		_rel_sig = str(lr)
		_rel_at = [snappedf(float(s["puck"]["pos"][0]), 0.1), snappedf(float(s["puck"]["pos"][1]), 0.1), str(lr.get("to", ""))]
	_pre = [str(s.get("puck", {}).get("holder", "")), str(lr.get("kind", "")), str(lr.get("by", "")), snappedf(float(s["puck"]["pos"][0]), 0.1), snappedf(float(s["puck"]["pos"][1]), 0.1)] + _rel_at
	var shot_ids: Dictionary = s.get("shots", {})
	var ot_ids: Dictionary = pos.get("one_timers", {})
	var pass_ids: Dictionary = pos.get("passes", {})
	if not is_live:
		if _was_live:
			_end("")                   # a goal, a period's end: the possession stops with the whistle
			pending_pass = ""
		_was_live = false
		_shots_seen = shot_ids.duplicate()
		_ot_seen = ot_ids.duplicate()
		_passes_seen = pass_ids.duplicate()
		prev_holder = str(s.get("puck", {}).get("holder", ""))
		_last_sig = str(pos.get("last", {}))
		return
	_was_live = true
	live += 1
	given = (s.get("hits", {}) as Dictionary).get("given", {})
	var px: float = float(s["puck"]["pos"][0])
	var pz: float = float(s["puck"]["pos"][1])
	var holder: String = str(s["puck"].get("holder", ""))
	var last: Dictionary = pos.get("last", {})
	var sig: String = str(last)
	var released_now: bool = sig != _last_sig
	if released_now and str(last.get("kind", "")) in ["poked", "lost", "bobble"]:
		(moments.get_or_add(str(last["kind"]), []) as Array).append(frame)
	_last_sig = sig
	# shots and one-timers
	for id: String in shot_ids:
		var n: int = int(shot_ids[id]) - int(_shots_seen.get(id, 0))
		if n > 0 and team_of.has(id):
			var side: String = team_of[id]
			shots[side] += n
			var gx: float = 26.0 * _attack_sign(side)
			if absf(gx - px) <= SLOT_DEPTH and absf(pz) <= SLOT_HALF:
				slot_shots[side] += n
			if _entry_side == side:
				entries_ok[side] += 1
				_entry_side = ""
	_shots_seen = shot_ids.duplicate()
	for id: String in ot_ids:
		var n2: int = int(ot_ids[id]) - int(_ot_seen.get(id, 0))
		if n2 > 0 and team_of.has(id):
			one_timers[team_of[id]] += n2
			(moments.get_or_add("one_timer", []) as Array).append(frame)
	_ot_seen = ot_ids.duplicate()
	for id: String in pass_ids:
		var n3: int = int(pass_ids[id]) - int(_passes_seen.get(id, 0))
		if n3 > 0 and team_of.has(id):
			var ps: String = team_of[id]
			passes[ps] += n3
			if ps == cur:
				cur_passes += n3
			pending_pass = ps
	_passes_seen = pass_ids.duplicate()
	# possession changes
	if holder != "" and holder != prev_holder:
		var side2: String = str(team_of.get(holder, ""))
		if pending_pass != "":
			if side2 == pending_pass:
				complete[pending_pass] += 1
			pending_pass = ""
		if side2 != cur:
			if cur != "":
				var cause: String = "steal"
				if prev_holder != "" and str(team_of.get(prev_holder, "")) == cur and not released_now:
					cause = "goalie" if role_of.get(holder, "") == "goalie" else "steal"
				else:
					var kind: String = str(last.get("kind", ""))
					cause = {"poked": "poke", "hit": "check", "pass": "intercept", "lost": "self", "bobble": "bobble", "dump": "dump", "shot": ""}.get(kind, "other")
					if kind == "shot":
						after_shot += 1
					elif kind == "bobble" and str(team_of.get(str(last.get("by", "")), "")) != cur:
						cause = "intercept"     # an opponent who bobbled our pass or shot: it was intercepted, not our bobble
				_end(cause)
			cur = side2
			cur_start = frame
			cur_passes = 0
		take_frame = frame
	prev_holder = holder
	# crowding round the puck
	var near: int = 0
	var near_ids: Array = []
	for k: Dictionary in s.get("skaters", []):
		if str(k["role"]) == "goalie":
			continue
		if Vector2(float(k["pos"][0]) - px, float(k["pos"][1]) - pz).length() < 5.0:
			near += 1
			near_ids.append(str(k["id"]))
	crowd_sum += near
	if near >= 4:
		crowd4 += 1
		var rn: Dictionary = s.get("roles_now", {})
		for nid: String in near_ids:
			var r: String = str(rn.get(nid, "human"))
			crowd_roles[r] = int(crowd_roles.get(r, 0)) + 1
	# zones and entries
	for side: String in ["blue", "red"]:
		if px * _attack_sign(side) >= BLUE_LINE:
			oz[side] += 1
	if cur != "":
		var sg: float = _attack_sign(cur)
		if _prev_x * sg < BLUE_LINE and px * sg >= BLUE_LINE:
			entries[cur] += 1
			_entry_side = cur
			_entry_frames = 0
		elif _entry_side == cur:
			if px * sg < BLUE_LINE:
				_entry_side = ""
			else:
				_entry_frames += 1
				if _entry_frames >= ENTRY_HOLD:
					entries_ok[cur] += 1
					_entry_side = ""
	_prev_x = px


func result() -> Dictionary:
	return {"live": live, "lengths": lengths, "poss_passes": per_poss_passes, "passes": passes, "complete": complete,
		"shots": shots, "slot_shots": slot_shots, "one_timers": one_timers, "turnovers": turnovers, "after_shot": after_shot,
		"oz": oz, "entries": entries, "entries_ok": entries_ok, "given": given, "goals_how": goals_how, "moments": moments, "crowd_sum": crowd_sum, "crowd4": crowd4, "crowd_roles": crowd_roles}
