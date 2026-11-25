extends RefCounted
## thirdjam's commentator, its words only (lane K5, round 2; the voice is lane K6's). [base README: scripts/hud/captions.gd §1]

const R := preload("rules.gd")
const Lines := preload("commentary_lines.gd")
const GameSkin := preload("skin.gd")
const GATE := 150
const CUT_FLOOR := 30
const MUST_PLAY := 5
const NO_REPEAT := 3
const SECOND_BEAT := 300
const STREAK_WINDOW := 600
const BANK_WINDOW := 60
const PROTECT_WINDOW := 120
const LONG_SHOT_WINDOW := 180
const CHECK_LIGHT := 0.4
const CHECK_SOLID := 0.8
const MASSACRE_WINDOW := 1200
const MASSACRE_COUNT := 3
const AFTER_HIT_WINDOW := 300
const PASS_CATCH_WAIT := 180
const FADE := 30                                   # CommentaryFadeFrames (h:816)
const STOPPAGE := ["period", "period_end", "season_take", "win", "lose"]

var lines: Array = []                              # dicts
var by_event: Dictionary = {}
var rng := RandomNumberGenerator.new()
var length_m: float = 90.0
var width_m: float = 45.0
var score_to_win: int = 3
var pending: Array = []   # FJamCommentaryPicker's state (Reset, cpp:115-148)
var last_start: int = -1000000
var last_end: int = -1000000
var last_seen: int = -1000000
var last_situation: Dictionary = {}
var history: Dictionary = {}
var heard: Dictionary = {}
var last_pick: Dictionary = {}
var prev_score: Array = [0, 0]
var prev_score_ok: bool = false
var lowest_deficit: Array = [0, 0]
var prev_touch: int = -1
var last_shot: int = -1000000
var last_shot_where := Vector2.ZERO
var last_board: int = -1000000
var last_goal: int = -1000000
var last_foul: int = -1000000
var last_drop: int = -1000000
var prev_drop: int = -1000000
var last_check: int = -1000000
var last_check_where := Vector2.ZERO
var human_shots: Array = []
var pass_team: int = -1
var pass_streak: int = 0
var knockdowns_by: Array = [[], []]
var last_team_check: Array = [-1000000, -1000000]
var goal_after_hit: bool = false
var beat_pending: bool = false
var beat: Dictionary = {}
var beat_said: String = ""
var pass_hold: Dictionary = {}                     # JamCommentaryPassCatch
var seed_: int = 0
var shown_line: String = ""   # the strip
var shown_tick: int = -1000000
var shown_dur: int = 0
var picks: int = 0
var bark_hold_until: int = -1000000
var bark_at_human: bool = false
const BARK_YIELD := 150                 # BarkYieldFrames (CommentarySystem.h:30)

var last_rect: Rect2 = Rect2()                        # the plate paint() drew this frame (Rect2() = none)
var team_names: Array = []                            # the skin's team words (lane E1): thirdjam's "blue" / "orange" said as these
var team_plural: Array = [false, false]               # lane E1b: which of them is a plural ("Sharks shoot!"; skin.gd teams_of)


## `rows`: the bank of lines (null = thirdjam's three banks, commentary_lines.gd); `names`: the skin's ... [base README: scripts/hud/captions.gd §2]
func _init(game: Dictionary, seed_value: int, rows: Variant = null, names: Array = [], plural: Array = []) -> void:
	if names.size() == 2:
		var tw: Array = GameSkin.teams_of({"team_names": names, "team_plural": plural} if plural.size() == 2 else {"team_names": names}, game)
		team_names = tw[0]
		team_plural = tw[1]
	var rk: Dictionary = game["rink"]
	length_m = float(rk["length_m"])
	width_m = float(rk["width_m"])
	score_to_win = int((game.get("rules", {}) as Dictionary).get("score_to_win", 0))
	for row: Array in (Lines.LINES if rows == null else rows):
		var id: String = row[0]
		var sit: String = id
		var dot: int = id.rfind(".")
		if dot > 0 and id.substr(dot + 1).is_valid_int():
			sit = id.substr(0, dot)                                    # SituationOf (JamCommentaryData.cpp:16-27)
		var l := {"id": id, "event": row[1], "kind": row[2], "team": row[3], "priority": int(row[4]), "cooldown": int(row[5]),
			"text": row[6], "dur": int(row[7]), "sit": sit, "stop": STOPPAGE.has(row[1]) or sit == "goal.pause"}
		if not by_event.has(l["event"]):
			by_event[l["event"]] = []
		(by_event[l["event"]] as Array).append(lines.size())
		lines.append(l)
	seed_ = seed_value
	_reset()

func _reset() -> void:
	rng.seed = hash([seed_, 0xC0DE, 91])
	pending = []
	last_start = -1000000
	last_end = -1000000
	last_situation = {}
	history = {}
	heard = {}
	last_pick = {}
	prev_score = [0, 0]
	prev_score_ok = false
	lowest_deficit = [0, 0]
	prev_touch = -1
	last_shot = -1000000
	last_board = -1000000
	last_goal = -1000000
	last_foul = -1000000
	last_drop = -1000000
	prev_drop = -1000000
	last_check = -1000000
	human_shots = []
	pass_team = -1
	pass_streak = 0
	knockdowns_by = [[], []]
	last_team_check = [-1000000, -1000000]
	goal_after_hit = false
	beat_pending = false
	beat = {}
	beat_said = ""
	pass_hold = {}

static func suffix(l: Dictionary) -> String:
	var s: String = l["sit"]
	var d: int = s.find(".")
	return s.substr(d + 1) if d >= 0 else ""

static func specificity(l: Dictionary) -> int:                   # cpp:150-163
	var sfx: String = suffix(l)
	var n: int = 0
	if l["kind"] != "":
		n += 1
	if l["team"] != "any":
		n += 1
	if sfx != "" and sfx != "any" and sfx != l["kind"] and sfx != "blue" and sfx != "orange":
		n += 1
	if sfx in ["human", "for", "against", "to_human"]:
		n += 1
	return n

static func _condition_kind(k: String) -> bool:
	return k == "bank" or k == "rim"

## The world of this frame (BuildWorld cpp:706-733).
func world(snap: Dictionary) -> Dictionary:
	var teams: Array = []
	var pos: Array = []
	var early: Array = []
	for s: Dictionary in snap["Skaters"]:
		teams.append(int(s["Team"]))
		pos.append(s["Pos"])
		early.append(int(s.get("DrawFrame", -1)) == -2)
	var me: int = int(snap["HumanIndex"])
	return {"frame": int(snap["Frame"]), "human": me, "teams": teams, "pos": pos, "early": early,
		"touch": int((snap["Puck"] as Dictionary)["LastTouch"]), "pause": int(snap["Phase"]) != 0,
		"score": [int(snap["Score"][0]), int(snap["Score"][1])], "goal_x": length_m * 0.5 - 4.0, "goal_w": 4.0}

static func team_of(w: Dictionary, who: int) -> int:
	return int(w["teams"][who]) if who >= 0 and who < (w["teams"] as Array).size() else -1

static func colour_of(t: int) -> String:
	return "blue" if t == 0 else ("orange" if t == 1 else "any")

static func attack_sign(t: int) -> float:
	return 1.0 if t == 0 else -1.0                                 # AttackGoalX(0) > 0: team 0 attacks +x

## WhenHolds (cpp:166-273).
func when_holds(l: Dictionary, e: Dictionary, w: Dictionary) -> bool:
	var sfx: String = suffix(l)
	var t: int = e["team"]
	var o: int = 1 - t if t == 0 or t == 1 else -1
	var human: int = team_of(w, int(w["human"]))
	var sa: Array = e["after"]
	var sb: Array = e["before"]
	var diff: int = int(sa[t]) - int(sa[o]) if t >= 0 and o >= 0 else 0
	var ev: String = e["event"]
	var strength: float = e["strength"]
	var where: Vector2 = e["where"]
	if ev == "pass" and (sfx == "blue" or sfx == "orange"):
		return pass_team == t and pass_streak >= 3
	if ev == "directors_call":
		if sfx.ends_with("_up"):
			return strength >= 0.5
		if sfx.ends_with("_down"):
			return strength < 0.5
		return true
	if sfx == "" or sfx == "any" or sfx == "blue" or sfx == "orange" or (sfx == l["kind"] and not _condition_kind(l["kind"])):
		return true
	match sfx:
		"human": return int(e["who"]) == int(w["human"])
		"to_human": return e["kind"] == "to_%d" % int(w["human"])
		"for": return t == human
		"against": return t >= 0 and t != human
		"hard": return strength >= (0.7 if ev == "board" else 0.8)
		"big": return strength >= 0.8
		"soft": return strength < 0.3
		"light": return strength < CHECK_LIGHT
		"solid": return strength >= CHECK_LIGHT and strength < CHECK_SOLID
		"massacre": return ev == "knockdown" and t >= 0 and o >= 0 and _knockdowns(o, int(e["frame"])) >= MASSACRE_COUNT
		"after_hit": return ev == "goal" and goal_after_hit
		"cross": return e["kind"] == "cross"
		"long":
			if ev == "pass":
				return strength >= 0.8
			if ev == "carry":
				return strength * length_m >= 30.0
			if ev == "goal":
				return int(e["frame"]) - last_shot <= LONG_SHOT_WINDOW and t >= 0 and last_shot_where.x * attack_sign(t) < 0.0
			return t >= 0 and where.x * attack_sign(t) < 0.0
		"close":
			if ev == "shot":
				return t >= 0 and absf(where.x - float(w["goal_x"]) * attack_sign(t)) < 4.5 and absf(where.y) < float(w["goal_w"]) * 0.5 + 2.0
			return absi(int(sa[0]) - int(sa[1])) == 1
		"rim": return absf(where.x) > float(w["goal_x"])
		"boards": return absf(where.x) > length_m * 0.5 - 2.0 or absf(where.y) > width_m * 0.5 - 2.0
		"first": return int(sb[0]) + int(sb[1]) == 0 and int(sa[0]) + int(sa[1]) > 0
		"tie", "tied", "last_10_tied": return int(sa[0]) == int(sa[1])
		"take_tied": return int(sa[0]) == int(sa[1]) and _take_number(e["kind"]) >= 2
		"lead":
			if ev == "period_end":
				return int(sa[0]) != int(sa[1])
			return t >= 0 and int(sb[0]) == int(sb[1]) and diff > 0
		"comeback":
			if ev == "goal":
				return t >= 0 and int(sb[o]) - int(sb[t]) >= 2
			return t >= 0 and int(lowest_deficit[t]) >= 2
		"blowout": return t >= 0 and absi(diff) >= 3
		"last_10_close": return absi(int(sa[0]) - int(sa[1])) == 1
		"match_point": return t >= 0 and score_to_win - int(sa[t]) == 1   # bFirstTo (the regular cartridge)
		"own": return t >= 0 and team_of(w, int(e["who"])) >= 0 and team_of(w, int(e["who"])) != t
		"shutout": return t >= 0 and o >= 0 and int(sa[o]) == 0
		"last_10", "sudden": return true
		"take_n": return _take_number(e["kind"]) >= 4
		"season": return false                                     # no season (bSeasonLastTake)
		"late": return false                                       # first_to: no timer (bLate needs W.bTimer)
		"human_streak":
			var n: int = 0
			for f: int in human_shots:
				if int(e["frame"]) - f <= STREAK_WINDOW:
					n += 1
			return n >= 3
		"bank": return ev == "goal" and int(e["frame"]) - last_board <= BANK_WINDOW
		"after_goal": return last_goal > prev_drop
		"after_foul": return last_foul > prev_drop
		"early": return int(e["who"]) >= 0 and int(e["who"]) < (w["early"] as Array).size() and bool(w["early"][int(e["who"])])
		"strip":
			var prev: int = prev_touch
			return prev >= 0 and team_of(w, prev) >= 0 and team_of(w, prev) != t and (w["pos"][prev] as Vector2).distance_to(where) < 2.0 and int(w["touch"]) != prev
		"protect": return int(e["frame"]) - last_check <= PROTECT_WINDOW and last_check_where.distance_to(where) < 3.0
		"coast": return e["kind"] == "coast"
		"pause": return bool(w["pause"])
	if ev == "pass":
		return pass_team == t and pass_streak >= 3
	return true

static func _take_number(kind: String) -> int:
	return int(kind.substr(5)) if kind.begins_with("take_") else 0

func _knockdowns(team: int, frame: int) -> int:
	var n: int = 0
	for f: int in knockdowns_by[team]:
		if f <= frame and frame - f < MASSACRE_WINDOW:
			n += 1
	return n

## Candidates (cpp:275-313).
func candidates(e: Dictionary, w: Dictionary) -> Array:
	var out: Array = []
	for i: int in by_event.get(e["event"], []):
		var l: Dictionary = lines[i]
		if l["kind"] != "" and not _condition_kind(l["kind"]) and l["kind"] != e["kind"]:
			continue
		if l["team"] != "any" and l["team"] != colour_of(int(e["team"])):
			continue
		if l["stop"] and not bool(w["pause"]):
			continue
		if not when_holds(l, e, w):
			continue
		if last_situation.has(l["sit"]) and int(e["frame"]) - int(last_situation[l["sit"]]) < int(l["cooldown"]):
			continue
		out.append(i)
	var per: Dictionary = {}
	for i: int in out:
		per[lines[i]["sit"]] = int(per.get(lines[i]["sit"], 0)) + 1
	for j: int in range(out.size() - 1, -1, -1):
		var l: Dictionary = lines[out[j]]
		var h: Array = history.get(l["sit"], [])
		if h.is_empty():
			continue
		var n: int = per[l["sit"]]
		if (h.has(l["id"]) and n > NO_REPEAT) or (h.back() == l["id"] and n > 1):
			out.remove_at(j)
	return out

func _remember(e: Dictionary, w: Dictionary) -> void:            # cpp:322-342
	var f: int = e["frame"]
	match String(e["event"]):
		"shot":
			last_shot = f
			last_shot_where = e["where"]
			if int(e["team"]) == team_of(w, int(w["human"])):
				human_shots.append(f)
			human_shots = human_shots.filter(func(x: int) -> bool: return f - x <= STREAK_WINDOW)
		"board": last_board = f
		"goal": last_goal = f
		"foul": last_foul = f
		"faceoff":
			if e["kind"] == "drop":
				prev_drop = last_drop
				last_drop = f
		"check":
			last_check = f
			last_check_where = e["where"]
		"pass":
			if int(e["team"]) == pass_team:
				pass_streak += 1
			else:
				pass_team = int(e["team"])
				pass_streak = 1

## Observe (cpp:364-457): one event into the pending list with its candidates.
func observe(ev: String, kind: String, who: int, where: Vector2, strength: float, w: Dictionary) -> void:
	_note_frame(int(w["frame"]))
	if ev == "ability" and strength < 0.5:
		return
	var sa: Array = w["score"]
	var e := {"event": ev, "kind": kind, "who": who, "where": where, "strength": strength, "frame": int(w["frame"]),
		"before": prev_score.duplicate() if prev_score_ok else sa.duplicate(), "after": sa.duplicate(), "team": -1, "cands": []}
	if ev == "goal":
		if int(sa[0]) > int(e["before"][0]):
			e["team"] = 0
		elif int(sa[1]) > int(e["before"][1]):
			e["team"] = 1
		else:
			e["team"] = 0 if where.x > 0.0 else 1
	elif ev == "win" or ev == "lose":
		e["team"] = team_of(w, int(w["human"]))
	else:
		e["team"] = team_of(w, who)
	var t: int = e["team"]
	var pass_like: bool = ev == "pass" or ev == "shot"
	if pass_like:
		_remember(e, w)
	if ev == "knockdown" and t >= 0 and t <= 1:
		(knockdowns_by[1 - t] as Array).append(int(e["frame"]))
		knockdowns_by[1 - t] = (knockdowns_by[1 - t] as Array).filter(func(x: int) -> bool: return int(e["frame"]) - x < MASSACRE_WINDOW)
	if ev == "goal":
		goal_after_hit = t >= 0 and t <= 1 and int(e["frame"]) - int(last_team_check[t]) <= AFTER_HIT_WINDOW
	e["cands"] = candidates(e, w)
	if not pass_like:
		_remember(e, w)
	if ev == "check" and t >= 0 and t <= 1:
		last_team_check[t] = int(e["frame"])
	if ev == "goal":
		e["cands"] = (e["cands"] as Array).filter(func(i: int) -> bool: return lines[i]["sit"] != "goal.after_hit")
	if ev == "lift" and kind == "clean":                          # a clean lift offers check.cross (jam.comm.LiftIsCross 1)
		var x: Dictionary = e.duplicate()
		x["event"] = "check"
		x["kind"] = "cross"
		for i: int in candidates(x, w):
			if lines[i]["sit"] == "check.cross":
				(e["cands"] as Array).append(i)
	if ev == "lift" and kind == "miss" and who == int(w["human"]):
		var x2: Dictionary = e.duplicate()
		x2["event"] = "check"
		x2["kind"] = "cross_miss"
		for i: int in candidates(x2, w):
			if lines[i]["sit"] == "check.cross_miss":
				(e["cands"] as Array).append(i)
	if ev == "lift":
		e["cands"] = (e["cands"] as Array).filter(func(i: int) -> bool: return not String(lines[i]["sit"]).begins_with("lift."))
	if ev == "goal" and int(e["frame"]) - last_board <= BANK_WINDOW and bool(w["pause"]):
		for i: int in by_event.get("board", []):
			var l: Dictionary = lines[i]
			if l["sit"] != "board.bank":
				continue
			if last_situation.has(l["sit"]) and int(e["frame"]) - int(last_situation[l["sit"]]) < int(l["cooldown"]):
				continue
			(e["cands"] as Array).append(i)
	if ev == "goal":
		beat_pending = true
		beat = e.duplicate()
		beat["cands"] = []
		beat_said = ""
	pending.append(e)

func _note_frame(f: int) -> void:                                 # NoteFrame (cpp:344-357): a restart resets the booth, not its stream
	if f < last_seen:
		var keep: PackedInt64Array = PackedInt64Array([rng.state])
		_reset()
		rng.state = keep[0]
	last_seen = f

func _gate_open(f: int) -> bool:
	return f - last_start >= GATE and f >= last_end and f >= bark_hold_until

## ObserveBark (CommentarySystem.cpp:449-453, 756-758): a bark this frame; `at_human`: IsBarkAtHuman (cpp:735-742).
func bark(at_human: bool) -> void:
	if at_human:
		bark_at_human = true

func _choose(options: Array) -> int:                              # ChooseAmong (cpp:459-479)
	var best_p: int = -1
	var best_s: int = -1
	for o: Array in options:
		var l: Dictionary = lines[o[0]]
		var s: int = specificity(l)
		if int(l["priority"]) > best_p or (int(l["priority"]) == best_p and s > best_s):
			best_p = int(l["priority"])
			best_s = s
	var top: Array = []
	for i: int in options.size():
		var l: Dictionary = lines[options[i][0]]
		if int(l["priority"]) == best_p and specificity(l) == best_s:
			top.append(i)
	var unheard: Array = top.filter(func(i: int) -> bool: return not heard.has(lines[options[i][0]]["id"]))
	var pool: Array = unheard if not unheard.is_empty() else top
	return pool[rng.randi_range(0, pool.size() - 1)]

## Resolve (cpp:505-597, no barks: ours has no bark bubbles): at most one line starts. Returns the line started or {}.
func resolve(w: Dictionary) -> Dictionary:
	var f: int = w["frame"]
	_note_frame(f)
	var started: Dictionary = {}
	if bark_at_human:   # the booth yields to a bark at the human (cpp:520-534): nothing starts, a line older than half a second is cut; a priority-5 call plays on
		bark_hold_until = maxi(bark_hold_until, f + BARK_YIELD)
		if f < last_end and f - last_start >= CUT_FLOOR:
			last_end = f
		var must_pending: bool = false
		for e: Dictionary in pending:
			for i: int in e["cands"]:
				if int(lines[i]["priority"]) >= MUST_PLAY:
					must_pending = true
		if not must_pending:
			bark_at_human = false
			_close(w)
			return started
	bark_at_human = false
	if beat_pending and (not bool(w["pause"]) or f - int(beat["frame"]) > SECOND_BEAT):
		beat_pending = false
	var options: Array = []
	for si: int in pending.size():
		for i: int in pending[si]["cands"]:
			options.append([i, si])
	var from_beat: bool = false
	if options.is_empty() and beat_pending and _gate_open(f):
		beat["frame"] = f
		var mood: Array = []
		var pause_: Array = []
		for i: int in candidates(beat, w):
			var sit: String = lines[i]["sit"]
			if sit == "goal.blue" or sit == "goal.orange" or sit == beat_said:
				continue
			(pause_ if sit == "goal.pause" else mood).append([i, -1])
		options = mood if not mood.is_empty() else pause_
		from_beat = not options.is_empty()
	if not options.is_empty():
		var pick: int = _choose(options)
		var li: int = options[pick][0]
		var ev: String = pending[options[pick][1]]["event"] if int(options[pick][1]) >= 0 else String(beat["event"])
		var go: bool = true
		if not _gate_open(f):
			var must: bool = not from_beat and int(lines[li]["priority"]) >= MUST_PLAY and not (f < last_end and int(last_pick.get("priority", 0)) >= MUST_PLAY)
			var hit_ev: bool = ev == "check" or ev == "knockdown"
			var last_hit: bool = last_pick.get("event", "") == "check" or last_pick.get("event", "") == "knockdown"
			var hit_call: bool = not from_beat and not must and hit_ev and not last_hit and f >= bark_hold_until and int(lines[li]["priority"]) >= int(last_pick.get("priority", 0))
			go = must or hit_call
			if go:
				last_end = f                                         # the playing line is cut
		if go:
			var l: Dictionary = lines[li]
			last_start = f
			last_end = f + int(l["dur"])
			last_situation[l["sit"]] = f
			var h: Array = history.get(l["sit"], [])
			h.append(l["id"])
			if h.size() > NO_REPEAT:
				h.remove_at(0)
			history[l["sit"]] = h
			heard[l["id"]] = true
			last_pick = {"id": l["id"], "event": ev, "priority": int(l["priority"]), "frame": f, "text": l["text"], "dur": int(l["dur"])}
			picks += 1
			started = last_pick
			if ev == "goal" and not from_beat:
				beat_said = l["sit"]
			if from_beat:
				beat_pending = false
	_close(w)
	return started

## Close (cpp:507-519): this frame's score and possession become the next frame's "before".
func _close(w: Dictionary) -> void:
	for t: int in 2:
		lowest_deficit[t] = maxi(int(lowest_deficit[t]), int(w["score"][1 - t]) - int(w["score"][t]))
	prev_score = (w["score"] as Array).duplicate()
	prev_score_ok = true
	var tt: int = team_of(w, int(w["touch"]))
	if tt >= 0 and tt != pass_team:
		pass_team = tt
		pass_streak = 0
	prev_touch = int(w["touch"])
	pending = []

## One sim frame of the booth (HandleBusEvent + HandleSimFrame, cpp:756-808): the frame's events, the ... [base README: scripts/hud/captions.gd §3]
func step(snap: Dictionary, extra: Array) -> Dictionary:
	var w: Dictionary = world(snap)
	var sk: Array = snap["Skaters"]
	for x: Array in extra:
		observe(x[0], x[1], -1, Vector2.ZERO, 0.0, w)
	for e: Dictionary in snap["Events"]:
		var name_: String = e["Name"]
		if name_ in ["bark", "signal"]:
			continue
		if name_ == "pass":                                          # held until a mate receives it (jam.comm.PassOnCatch 1)
			var who: int = int(e["Who"])
			if who >= 0 and who < sk.size():
				var team: int = int((sk[who] as Dictionary)["Team"])
				pass_hold = {"e": e, "frame": int(w["frame"]), "team": team, "received": _team_received(sk, team)}
			continue
		observe(name_, String(e["Kind"]), int(e["Who"]), e["Where"], float(e["Strength"]), w)
	if not pass_hold.is_empty():
		if int(w["frame"]) < int(pass_hold["frame"]) or int(w["frame"]) - int(pass_hold["frame"]) > PASS_CATCH_WAIT:
			pass_hold = {}
		elif _team_received(sk, int(pass_hold["team"])) > int(pass_hold["received"]):
			var pe: Dictionary = pass_hold["e"]
			pass_hold = {}
			observe("pass", String(pe["Kind"]), int(pe["Who"]), pe["Where"], float(pe["Strength"]), w)
	return resolve(w)

static func _team_received(sk: Array, team: int) -> int:
	var n: int = 0
	for s: Dictionary in sk:
		if int(s["Team"]) == team:
			n += int(s.get("PassesReceived", 0))
	return n

## The strip's opacity Age ticks into a line of `dur` frames (CommentaryOpacityFor with HoldFrames 0, h:819-827).
static func opacity(age: int, dur: int) -> float:
	if age < 0:
		return 0.0
	if age <= dur:
		return 1.0
	var fade: int = age - dur
	return 0.0 if fade >= FADE else 1.0 - float(fade) / float(FADE)

## Paints the strip (docked 24 over the bottom edge; under the scoreboard when the dock would lie on his figure, ClearDown 1).
func paint(lay, vw: float, vh: float, tick: int, paused: bool, hidden: bool, human_box: Rect2, labels: Array = []) -> String:
	last_rect = Rect2()
	if shown_line == "" or paused or hidden:
		return ""
	var a: float = opacity(tick - shown_tick, mini(shown_dur, last_end - int(last_pick.get("frame", 0))))
	if a <= 0.0:
		return ""
	var wrap: float = clampf(vw - 600.0, 560.0, 880.0)
	var sz: Vector2 = lay.measure(shown_line, R.LINE_PT, "regular")
	sz.x = minf(sz.x, wrap)
	var plate := Vector2(16 + sz.x + 16, 6 + sz.y + 6)
	var tl := Vector2(vw * 0.5 - plate.x * 0.5, vh - 24.0 - plate.y)
	if human_box.size != Vector2.ZERO and Rect2(tl, plate).grow(6.0).intersects(human_box):
		tl.y = 112.0                                                 # CaptionPlace: the row under the scoreboard (y 112) when it ends above VH / 3
		if tl.y + plate.y > vh / 3.0:
			return ""
	for lb: Rect2 in labels:                                         # the one-line rule: a distance label wins (HUDOneLine.cpp:88-114)
		if Rect2(tl, plate).intersects(lb):
			return ""
	var fill := R.ML_PANEL
	fill.a = 0.72 * a
	last_rect = Rect2(tl, plate)                                     # lane H2b: where it is (hint.gd keeps a game's hint off it)
	lay.box(tl, plate, fill, 4.0, Color(1, 1, 1, 0.12 * a), 1.0)
	lay.text(tl + Vector2(16, 6), shown_line, R.LINE_PT, R.ML_TEXT_DIM, {"face": "regular", "alpha": a, "shadow": Vector2(0, 1), "shadow_color": Color(0, 0, 0, 0.45)})
	return shown_line

## A new line on the strip (UpdateCommentary cpp:1470-1478).
func show(line: Dictionary, tick: int) -> void:
	shown_line = line["text"] if team_names.is_empty() else GameSkin.team_words(String(line["text"]), team_names, team_plural)
	shown_tick = tick
	shown_dur = int(line["dur"])
