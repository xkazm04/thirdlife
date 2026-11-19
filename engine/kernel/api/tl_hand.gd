class_name TLHand
extends RefCounted
## A person's hand for a bot. A bot decides what it wants (an intent) and tells the hand; the hand presses the pack's
## declared actions through `ctx.input` the way a person would: some frames late, taps of human length, a release
## that comes late and now and then a button still held after the situation changed, steering on the keys a person
## has (8 ways on W A S D, overshooting a turn) and short stretches of doing nothing at all. Capability: `input`.
##
##   var hand: TLHand = TLHand.create(ctx, "regular")          # in _bot_setup
##   hand.set_axis(&"left", &"right", wanted)                   # in _bot_tick: intents, as often as you like
##   hand.tick()                                                # last line of _bot_tick: the hand acts
##
## Why: a bot that sends perfect verbs measures the game for nobody (engine/seeds/README.md, "A bot is not a person").
## The profile `perfect` is a bot's hand of today: every call goes straight to ctx.input on the frame it is made,
## nothing is drawn, so a bot ported onto the helper keeps its result and its state hash.
##
## Randomness: the hand draws from its own generator, seeded from the run's seed (`ctx.seed`), the profile name and
## `stream`. It never draws from `ctx.rng`, so the game's own seeded choices (serves, spawns) are the same under every
## hand and two hands compare on the same game. Same pack + seed + frames + profile = same state hash.

## The profiles. Frame ranges are [min, max], inclusive, at 60 frames a second; a chance is per event, a lapse rate
## per minute of play. The numbers and their reasons are in engine/kernel/API.md, section "TLHand".
const PROFILES: Dictionary = {
	"perfect": {},
	"sharp": {"reaction": [4, 7], "tap": [4, 6], "release_late": [0, 2], "stick_chance": 0.02, "stick": [6, 12],
		"overshoot": [1, 3], "lapses_per_minute": 1.0, "lapse": [8, 15], "aim_lag": [4, 8], "aim_miss": 0.15, "aim_speed": 40.0,
		"aim_settle": 12.0, "aim_jump": 1.0},
	"regular": {"reaction": [8, 13], "tap": [5, 8], "release_late": [2, 6], "stick_chance": 0.05, "stick": [10, 24],
		"overshoot": [3, 7], "lapses_per_minute": 3.0, "lapse": [15, 30], "aim_lag": [8, 16], "aim_miss": 0.3, "aim_speed": 25.0,
		"aim_settle": 8.0, "aim_jump": 1.0},
	"newcomer": {"reaction": [14, 23], "tap": [6, 9], "release_late": [4, 10], "stick_chance": 0.12, "stick": [18, 40],
		"overshoot": [6, 12], "lapses_per_minute": 6.0, "lapse": [24, 48], "aim_lag": [14, 26], "aim_miss": 0.6, "aim_speed": 15.0,
		"aim_settle": 5.0, "aim_jump": 1.0},
}
## A wish of strength at least ON presses a key; once pressed it stays wished until the strength falls below OFF.
const ON: float = 0.35
const OFF: float = 0.15
const _RANGES: Array = ["reaction", "tap", "release_late", "stick", "overshoot", "lapse", "aim_lag"]
const _NUMBERS: Array = ["stick_chance", "lapses_per_minute", "aim_miss", "aim_speed", "aim_settle", "aim_jump"]

## The profile's name ("perfect", "sharp", "regular", "newcomer").
var profile: String = "perfect"
## The profile's numbers as used (the named profile with the caller's overrides).
var params: Dictionary = {}

var _ctx: TLContext
var _rng: RandomNumberGenerator = null
var _keys: Dictionary = {}          # action -> {want, seen, down, queue: [[due, on, extra]], min_up, group}
var _order: Array[StringName] = []  # actions in the order the bot first named them (the order the hand acts in)
var _lapse_end: int = -1            # the hand is away until this frame (exclusive)
var _aim: Variant = null            # the last aim target the bot asked for
var _aims: Dictionary = {}          # K4: aim -> {want, wanted, seen, seen_any, cursor, shown, follow_at, miss}
var _aim_order: Array[StringName] = []
var _n: Dictionary = {"intents": 0, "decisions": 0, "presses": 0, "releases": 0, "taps": 0, "reaction_frames": 0,
	"held_late_frames": 0, "sticks": 0, "overshoots": 0, "lapses": 0, "lapse_frames": 0, "lengthened": 0, "aims": 0, "stops": 0,
	"taps_lost": 0, "aim_targets": 0, "aim_lag_frames": 0}


## A hand for `ctx` with a named profile. `overrides` replaces profile numbers (same keys as PROFILES, plus `stream`:
## an integer that gives a second hand in the same run its own draws). An unknown profile or key is an error.
static func create(ctx: TLContext, profile_name: String = "regular", overrides: Dictionary = {}) -> TLHand:
	TLContext.require("input", "TLHand")
	var h: TLHand = TLHand.new()
	h._ctx = ctx
	if not PROFILES.has(profile_name):
		push_error("TLHand: unknown profile '%s' (known: %s)" % [profile_name, ", ".join(PackedStringArray(PROFILES.keys()))])
		profile_name = "perfect"
	h.profile = profile_name
	h.params = (PROFILES[profile_name] as Dictionary).duplicate(true)
	var stream: int = 0
	for k: String in overrides.keys():
		if k == "stream":
			stream = int(overrides[k])
		elif _RANGES.has(k) or _NUMBERS.has(k):
			if profile_name == "perfect":
				push_error("TLHand: the profile 'perfect' takes no numbers ('%s')" % k)
			else:
				h.params[k] = overrides[k]
		else:
			push_error("TLHand: unknown key '%s' (known: stream, %s)" % [k, ", ".join(PackedStringArray(_RANGES + _NUMBERS))])
	if profile_name != "perfect":
		h._rng = RandomNumberGenerator.new()
		h._rng.seed = hash("tl.hand|%s|%d|%d" % [profile_name, int(ctx.seed), stream])
	return h


## The names of the profiles.
static func profiles() -> PackedStringArray:
	return PackedStringArray(PROFILES.keys())


## True for the profile `perfect` (every call goes straight to ctx.input).
func is_perfect() -> bool:
	return _rng == null


# ---- intents: what the bot wants. Call them in _bot_tick, as often as you like; then tick() ---------------------------

## Wants the action held down (until release()). A strength below ON is not a press for a person.
func press(action: StringName, value: float = 1.0) -> void:
	_n["intents"] += 1
	if is_perfect():
		_ctx.input.press(action, value)
		return
	_want(action, value)


## Wants the action up.
func release(action: StringName) -> void:
	_n["intents"] += 1
	if is_perfect():
		_ctx.input.release(action)
		return
	_want(action, 0.0)


## One press of `frames` frames. A person's tap is never shorter than the profile's `tap` range.
func tap(action: StringName, frames: int = 1) -> void:
	_n["intents"] += 1
	if is_perfect():
		_ctx.input.tap(action, frames)
		return
	var k: Dictionary = _key(action)
	if _away():
		_n["taps_lost"] += 1                         # K4: counted (stats()["taps_lost"]): a tap a lapse swallowed
		return                                       # not seen: the hand was somewhere else
	var reaction: int = _draw("reaction")
	var due: int = _after(k, int(_ctx.frame) + reaction)
	var length: int = maxi(frames, _draw("tap"))
	_n["reaction_frames"] += reaction
	(k["queue"] as Array).append([due, true, 0])
	(k["queue"] as Array).append([due + length, false, -1])     # -1: the end of a tap (not if the key is wanted held)
	_n["taps"] += 1
	_n["decisions"] += 1


## A two-action axis, -1..1. A person has two keys: the strength becomes one key down or none (ON / OFF).
func set_axis(negative: StringName, positive: StringName, value: float) -> void:
	_n["intents"] += 1
	if is_perfect():
		_ctx.input.set_axis(negative, positive, value)
		return
	_want(negative, maxf(0.0, -value), negative, positive)
	_want(positive, maxf(0.0, value), negative, negative)


## A direction on four actions (x right, y down, as TLInput.vector). A person has 8 ways on W A S D: the direction is
## quantised to the nearest of them; a turn lets go of the old key some frames late (the profile's `overshoot`).
func steer(left: StringName, right: StringName, up: StringName, down: StringName, direction: Vector2) -> void:
	_n["intents"] += 1
	if is_perfect():
		_ctx.input.set_axis(left, right, direction.x)
		_ctx.input.set_axis(up, down, direction.y)
		return
	var on: bool = (_key(left)["want"] or _key(right)["want"] or _key(up)["want"] or _key(down)["want"])
	var x: int = 0
	var y: int = 0
	if direction.length() >= (OFF if on else ON):
		var sector: float = roundf(direction.angle() / (PI / 4.0)) * (PI / 4.0)
		x = int(roundf(cos(sector)))
		y = int(roundf(sin(sector)))
	_want(left, 1.0 if x < 0 else 0.0, left, right)
	_want(right, 1.0 if x > 0 else 0.0, left, left)
	_want(up, 1.0 if y < 0 else 0.0, left, down)
	_want(down, 1.0 if y > 0 else 0.0, left, up)


## Wants every action the hand has touched up.
func release_all() -> void:
	_n["intents"] += 1
	if is_perfect():
		_ctx.input.release_all()
		return
	for a: StringName in _order:
		_want(a, 0.0)


## Where the bot wants to point an aim (a point on the ground; a declared aim, ctx.input.declare_aim). Call it every
## tick the bot wants to point (a moving target: every tick). Under `perfect` it goes straight to `ctx.input.set_aim`
## on the same tick. K4, under a person's profile the hand moves the game's aim as a cursor: a target that jumped more
## than `aim_jump` metres is followed only after a reaction (`aim_lag` frames; the cursor stays where it was), then the
## cursor travels at most `aim_speed` m/s on the ground and slows near its goal (it closes `aim_settle` of the rest
## each second), and its goal is the target plus a miss drawn per target (up to `aim_miss` metres, any side). A target
## that moves on without jumping is tracked with no new reaction (and no new miss). During a lapse the cursor stays.
func set_aim(action: StringName, point: Vector3) -> void:
	_n["intents"] += 1
	_n["aims"] += 1
	_aim = [action, point]
	if is_perfect():
		_ctx.input.set_aim(action, point)
		return
	if not _aims.has(action):
		_aims[action] = {"want": point, "wanted": true, "seen": Vector3.ZERO, "seen_any": false, "cursor": Vector3.ZERO,
			"shown": false, "follow_at": 0, "miss": Vector3.ZERO}
		_aim_order.append(action)
	(_aims[action] as Dictionary)["want"] = point
	(_aims[action] as Dictionary)["wanted"] = true


## K4. The bot no longer points this aim: under `perfect` the game's aim is cleared on the same tick; a person's
## hand takes the cursor away at its next look (not during a lapse).
func clear_aim(action: StringName) -> void:
	_n["intents"] += 1
	if is_perfect():
		_ctx.input.clear_aim(action)
		return
	if _aims.has(action):
		(_aims[action] as Dictionary)["wanted"] = false


# ---- the hand acts --------------------------------------------------------------------------------------------------

## Call once per frame, as the last line of _bot_tick: the hand sees the intents of this frame (unless it is away) and
## presses or releases what is due. Under `perfect` it does nothing (the calls went through already).
func tick() -> void:
	if is_perfect():
		return
	var frame: int = int(_ctx.frame)
	if frame >= _lapse_end and _rng.randf() < float(params["lapses_per_minute"]) / 3600.0:
		var length: int = _draw("lapse")
		_lapse_end = frame + length
		_n["lapses"] += 1
		_n["lapse_frames"] += length
	if not _away():
		_perceive(frame)
	for a: StringName in _order:
		_apply(a, _keys[a], frame)
	for a: StringName in _aim_order:
		_aim_step(a, _aims[a], frame, _away())


## What the hand did, for a bot's result: the proof that the mechanism ran (zeros under `perfect`, except intents).
func stats() -> Dictionary:
	var out: Dictionary = _n.duplicate()
	out["profile"] = profile
	out["mean_reaction_frames"] = snappedf(float(_n["reaction_frames"]) / maxf(1.0, float(_n["decisions"])), 0.01)
	out["mean_aim_lag_frames"] = snappedf(float(_n["aim_lag_frames"]) / maxf(1.0, float(_n["aim_targets"])), 0.01)
	return out


# ---- inside ---------------------------------------------------------------------------------------------------------

func _key(action: StringName) -> Dictionary:
	if not _keys.has(action):
		_keys[action] = {"want": false, "seen": false, "down": false, "queue": [], "min_up": 0, "group": action, "opposite": &""}
		_order.append(action)
	return _keys[action]


## `group`: the keys of one hand's steering (a turn inside it overshoots); `opposite`: the key a person never holds
## together with this one (left and right): this one goes down only after that one is up.
func _want(action: StringName, value: float, group: StringName = &"", opposite: StringName = &"") -> void:
	var k: Dictionary = _key(action)
	if group != &"":
		k["group"] = group
	if opposite != &"":
		k["opposite"] = opposite
	k["want"] = value >= ON or (bool(k["want"]) and value > OFF)


func _away() -> bool:
	return int(_ctx.frame) < _lapse_end


func _draw(name: String) -> int:
	var r: Array = params[name]
	return _rng.randi_range(int(r[0]), int(r[1]))


## The frame of a new change of this key: never before one already queued.
func _after(k: Dictionary, due: int) -> int:
	var q: Array = k["queue"]
	return maxi(due, int(q[q.size() - 1][0]) + 1) if not q.is_empty() else due


## One decision for everything that changed since the hand last looked: one reaction for all of it.
func _perceive(frame: int) -> void:
	var changed: Array[StringName] = []
	var turning: Dictionary = {}          # group -> true when a key of the group goes down in this decision
	for a: StringName in _order:
		var k: Dictionary = _keys[a]
		if bool(k["want"]) != bool(k["seen"]):
			changed.append(a)
			if bool(k["want"]):
				turning[k["group"]] = true
	if changed.is_empty():
		return
	# A reaction is to something new: a key to go down (a start, or a turn). A stop of a movement the hand made
	# itself is feed-forward: a person lets go about when they meant to, `release_late` frames late, not a reaction later.
	var reaction: int = 0
	if not turning.is_empty():
		reaction = _draw("reaction")
		_n["decisions"] += 1
		_n["reaction_frames"] += reaction
	for a: StringName in changed:
		var k: Dictionary = _keys[a]
		k["seen"] = k["want"]
		var due: int = frame + reaction
		var extra: int = 0
		if not bool(k["want"]):
			if turning.has(k["group"]):
				extra = _draw("overshoot")         # a turn: the old key is let go late by the overshoot
				_n["overshoots"] += 1
			else:
				extra = _draw("release_late")      # a stop: let go late
				_n["stops"] += 1
			if _rng.randf() < float(params["stick_chance"]):
				extra += _draw("stick")
				_n["sticks"] += 1
		(k["queue"] as Array).append([_after(k, due + extra), bool(k["want"]), extra])


## K4. One frame of a person's cursor for an aim (see set_aim).
func _aim_step(a: StringName, m: Dictionary, frame: int, away: bool) -> void:
	if not away:
		if not bool(m["wanted"]):
			if bool(m["shown"]):
				_ctx.input.clear_aim(a)
			m["shown"] = false
			m["seen_any"] = false
			return
		var want: Vector3 = m["want"]
		var seen: Vector3 = m["seen"]
		if not bool(m["seen_any"]) or Vector2(want.x - seen.x, want.z - seen.z).length() > float(params["aim_jump"]):
			var lag: int = _draw("aim_lag")              # a new target: seen, then followed a reaction later
			m["follow_at"] = frame + lag
			var ang: float = _rng.randf() * TAU
			var rad: float = _rng.randf() * float(params["aim_miss"])
			m["miss"] = Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)
			_n["aim_targets"] += 1
			_n["aim_lag_frames"] += lag
		m["seen"] = want
		m["seen_any"] = true
		if frame >= int(m["follow_at"]):
			var goal: Vector3 = want + (m["miss"] as Vector3)
			if not bool(m["shown"]):
				m["cursor"] = goal                       # the first time: the cursor comes in where he looks
				m["shown"] = true
			else:
				var cur: Vector3 = m["cursor"]
				var d: Vector3 = Vector3(goal.x - cur.x, 0.0, goal.z - cur.z)
				var dist: float = d.length()
				if dist > 0.000001:
					var speed: float = minf(float(params["aim_speed"]), float(params["aim_settle"]) * dist)
					m["cursor"] = cur + d / dist * minf(dist, speed / 60.0)
	if bool(m["shown"]):
		_ctx.input.set_aim(a, m["cursor"])           # held while the hand is away: the cursor stays where it was


func _apply(a: StringName, k: Dictionary, frame: int) -> void:
	var q: Array = k["queue"]
	while not q.is_empty() and int(q[0][0]) <= frame:
		var on: bool = bool(q[0][1])
		var opposite: StringName = k["opposite"]
		if on and not bool(k["down"]) and opposite != &"" and bool(_keys[opposite]["down"]):
			return                                       # a person lets go of the opposite key first
		if on and not bool(k["down"]):
			_ctx.input.press(a)
			k["down"] = true
			k["min_up"] = frame + _draw("tap")
			_n["presses"] += 1
		elif not on and bool(k["down"]) and not (int(q[0][2]) < 0 and bool(k["seen"])):
			if frame < int(k["min_up"]):
				q[0][0] = int(k["min_up"])           # a person's press is never shorter than a tap
				for i: int in range(1, q.size()):     # hunt2 B10: what follows moves too, so a next press has an up frame
					q[i][0] = maxi(int(q[i][0]), int(q[i - 1][0]) + 1)
				_n["lengthened"] += 1
				return
			_ctx.input.release(a)
			k["down"] = false
			_n["releases"] += 1
			_n["held_late_frames"] += maxi(0, int(q[0][2]))
		q.pop_front()
