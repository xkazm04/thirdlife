class_name TLRules
extends Node
## Rules as a small state machine with signals: score, clock, periods, laps and checkpoints, win conditions.
## Everything counts physics frames (60 per second). Capability: `rules`.
##
##   var rules := TLRules.create({sides = ["home", "away"], periods = 3, period_seconds = 60, score_to_win = 0})
##   ctx.root.add_child(rules)
##   rules.finished.connect(func(winner, reason): ...)
##   rules.start()                 # in _pack_start
##   rules.add_score("home")       # when a goal trigger fires
##   func _pack_state(): return rules.snapshot()
##
## States: &"idle" -> &"running" <-> &"paused" / &"intermission" -> &"over".

signal state_changed(from: StringName, to: StringName)
signal score_changed(side: String, score: int)
signal period_started(period: int)
signal period_ended(period: int)
signal checkpoint_passed(who: String, index: int)
signal lap_completed(who: String, lap: int, lap_frames: int)
signal finished(winner: String, reason: String)     ## winner "" is a draw; reason: score, laps, time, called

const KEYS: Array = ["sides", "periods", "period_seconds", "intermission_seconds", "score_to_win", "laps_to_win",
	"checkpoints", "sudden_death", "time_limit_seconds"]

var state: StringName = &"idle"
var sides: PackedStringArray = PackedStringArray()   ## competitors: teams, players, cars
var scores: Dictionary = {}                          ## side -> int
var periods: int = 1
var period: int = 1
var period_frames: int = 0            ## length of a period; 0 = no clock
var intermission_frames: int = 0
var clock_frames: int = 0             ## frames played in this period
var total_frames: int = 0             ## frames played in all
var time_limit_frames: int = 0        ## an untimed game (laps, first to N) can still have a limit; 0 = none
var score_to_win: int = 0             ## 0 = not a win condition
var laps_to_win: int = 0              ## 0 = not a win condition
var checkpoints: int = 0              ## checkpoints per lap, passed in order 0..n-1; 0 = laps are counted directly
var sudden_death: bool = false        ## a draw at full time plays on until the next score
var laps: Dictionary = {}             ## who -> laps completed
var next_checkpoint: Dictionary = {}  ## who -> index expected next
var last_lap_frames: Dictionary = {}  ## who -> frames of the last lap
var best_lap_frames: Dictionary = {}  ## who -> frames of the best lap
var winner: String = ""
var reason: String = ""
var _lap_started: Dictionary = {}
var _intermission_left: int = 0
var _overtime: bool = false


## Builds rules from data (usually `ctx.read_json("rules.json")`). Unknown keys are errors.
static func create(config: Dictionary = {}) -> TLRules:
	TLContext.require("rules", "TLRules")
	var r: TLRules = TLRules.new()
	r.name = "TLRules"
	for k: String in config.keys():
		if not KEYS.has(k):
			push_error("TLRules.create: unknown key '%s' (keys: %s)" % [k, ", ".join(PackedStringArray(KEYS))])
	for s: Variant in config.get("sides", []):
		r.add_side(str(s))
	r.periods = maxi(1, int(config.get("periods", 1)))
	r.period_frames = int(round(float(config.get("period_seconds", 0.0)) * 60.0))
	r.intermission_frames = int(round(float(config.get("intermission_seconds", 0.0)) * 60.0))
	r.time_limit_frames = int(round(float(config.get("time_limit_seconds", 0.0)) * 60.0))
	r.score_to_win = int(config.get("score_to_win", 0))
	r.laps_to_win = int(config.get("laps_to_win", 0))
	r.checkpoints = int(config.get("checkpoints", 0))
	r.sudden_death = bool(config.get("sudden_death", false))
	return r


func add_side(side: String) -> void:
	if not sides.has(side):
		sides.append(side)
		scores[side] = 0
		laps[side] = 0
		next_checkpoint[side] = 0


func _set_state(to: StringName) -> void:
	if to != state:
		var from: StringName = state
		state = to
		state_changed.emit(from, to)


## Starts period 1 (or restarts everything after a finish).
func start() -> void:
	period = 1
	clock_frames = 0
	total_frames = 0
	winner = ""
	reason = ""
	_overtime = false
	for s: String in sides:
		scores[s] = 0
		laps[s] = 0
		next_checkpoint[s] = 0
		_lap_started[s] = 0
	_set_state(&"running")
	period_started.emit(period)


func pause() -> void:
	if state == &"running":
		_set_state(&"paused")


func resume() -> void:
	if state == &"paused":
		_set_state(&"running")


func is_running() -> bool:
	return state == &"running"


func is_over() -> bool:
	return state == &"over"


## Ends the game now. `winner_` "" is a draw.
func finish(winner_: String = "", reason_: String = "called") -> void:
	if state == &"over":
		return
	winner = winner_
	reason = reason_
	_set_state(&"over")
	finished.emit(winner, reason)


func add_score(side: String, points: int = 1) -> void:
	if state != &"running":
		return
	if not scores.has(side):
		push_error("TLRules.add_score: unknown side '%s' (sides: %s)" % [side, ", ".join(sides)])
		return
	scores[side] = int(scores[side]) + points
	score_changed.emit(side, int(scores[side]))
	if (score_to_win > 0 and int(scores[side]) >= score_to_win):
		finish(side, "score")
	elif _overtime:
		finish(leader(), "score")


func score(side: String) -> int:
	return int(scores.get(side, 0))


## Reports that `who` passed checkpoint `index`. Out-of-order checkpoints are ignored (returns false).
## Passing the last one completes a lap.
func pass_checkpoint(who: String, index: int) -> bool:
	if state != &"running" or not next_checkpoint.has(who) or index != int(next_checkpoint[who]):
		return false
	checkpoint_passed.emit(who, index)
	if index + 1 >= maxi(1, checkpoints):
		next_checkpoint[who] = 0
		complete_lap(who)
	else:
		next_checkpoint[who] = index + 1
	return true


func complete_lap(who: String) -> void:
	if state != &"running":
		return
	if not laps.has(who):
		push_error("TLRules.complete_lap: unknown side '%s'" % who)
		return
	laps[who] = int(laps[who]) + 1
	var took: int = total_frames - int(_lap_started.get(who, 0))
	_lap_started[who] = total_frames
	last_lap_frames[who] = took
	if not best_lap_frames.has(who) or took < int(best_lap_frames[who]):
		best_lap_frames[who] = took
	lap_completed.emit(who, int(laps[who]), took)
	if laps_to_win > 0 and int(laps[who]) >= laps_to_win:
		finish(who, "laps")


## The side with the highest score ("" when two share the lead or there are no sides).
func leader() -> String:
	var best: String = ""
	var best_score: int = -2147483648
	var tie: bool = false
	for s: String in sides:
		var v: int = int(scores[s])
		if v > best_score:
			best_score = v
			best = s
			tie = false
		elif v == best_score:
			tie = true
	return "" if tie else best


## The sides in race order: most laps first, then most checkpoints of the current lap, then the higher score.
func standings() -> PackedStringArray:
	var order: Array = Array(sides)
	order.sort_custom(func(a: String, b: String) -> bool:
		if int(laps[a]) != int(laps[b]):
			return int(laps[a]) > int(laps[b])
		if int(next_checkpoint[a]) != int(next_checkpoint[b]):
			return int(next_checkpoint[a]) > int(next_checkpoint[b])
		if int(scores[a]) != int(scores[b]):
			return int(scores[a]) > int(scores[b])
		return sides.find(a) < sides.find(b))
	return PackedStringArray(order)


## Seconds left in the period (0 when there is no clock).
func seconds_left() -> float:
	return maxf(0.0, float(period_frames - clock_frames) / 60.0) if period_frames > 0 else 0.0


func seconds_played() -> float:
	return float(total_frames) / 60.0


## "MM:SS" of the time left in the period, or of the time played when there is no period clock.
func clock_text() -> String:
	var s: int = int(ceil(seconds_left())) if period_frames > 0 else int(floor(seconds_played()))
	return "%02d:%02d" % [s / 60, s % 60]


## Everything a bot or `_pack_state()` needs, as plain data.
func snapshot() -> Dictionary:
	return {"state": String(state), "period": period, "clock_frames": clock_frames, "total_frames": total_frames,
		"scores": scores.duplicate(), "laps": laps.duplicate(), "winner": winner, "reason": reason}


func _physics_process(_delta: float) -> void:
	if state == &"intermission":
		_intermission_left -= 1
		if _intermission_left <= 0:
			period += 1
			clock_frames = 0
			_set_state(&"running")
			period_started.emit(period)
		return
	if state != &"running":
		return
	clock_frames += 1
	total_frames += 1
	if time_limit_frames > 0 and total_frames >= time_limit_frames:
		finish(leader(), "time")
		return
	if period_frames > 0 and clock_frames >= period_frames and not _overtime:
		period_ended.emit(period)
		if period < periods:
			if intermission_frames > 0:
				_intermission_left = intermission_frames
				_set_state(&"intermission")
			else:
				period += 1
				clock_frames = 0
				period_started.emit(period)
		elif sudden_death and leader().is_empty():
			_overtime = true
		else:
			finish(leader(), "time")
