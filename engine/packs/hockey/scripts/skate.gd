extends RefCounted
## Shared skate step. The kernel turns and integrates the body after the pack's tick.

var game
var reverse_decel: float
var reverse_dot: float
var intent_min: float
var stop_speed: float
var pivot_speed: float
var burst_frames: int
var accel_mult: float
var own_stop: bool
var rest_frames: int
var rest_kept: float
var rest_speed: float
var slow_speed: float
var cut_frames: int
var cut_dot: float
var free_speed_mult: float
var sprint_bonus: float
var sprint_carry_bonus: float
var carrier_sprint_cap: float
var carry_scale: float
var carry_sprint_scale: float
var free_sprint_scale: float
var sprint_drain_frames: int
var sprint_refill_frames: int
var stamina_full: int
var stamina := PackedInt32Array()
var sprinting := PackedByteArray()
var human_slot: int
var base_speed: float
var bodies: Array[TLBiped] = []
var ids: Array[String] = []
var slots: Dictionary = {}
var field_slots := PackedInt32Array()
var intent := PackedVector3Array()
var braking := PackedByteArray()
var history := PackedVector3Array()
var cursor := PackedInt32Array()
var resting := PackedInt32Array()
var earned := PackedByteArray()
var reversing := PackedByteArray()
var burst_left := PackedInt32Array()
var stops: Dictionary = {}
var base_turn: float
var base_accel: float

func setup(g) -> void:
	game = g
	base_turn = float(g.tune["skater"]["skate_turn_rate"])
	base_accel = float(g.tune["skater"]["skate_accel"])
	var cfg: Dictionary = g.tune["skate"]
	var burst: Dictionary = cfg["burst"]
	for key: String in cfg:
		if key not in ["free_speed_mult", "sprint_bonus", "sprint_carry_bonus", "carrier_sprint_cap", "sprint_drain_frames", "sprint_refill_frames",
				"reverse_decel", "reverse_dot", "intent_min", "stop_speed", "pivot_speed", "burst"]:
			push_error("tuning.json: unknown skate.%s" % key)
	for key: String in burst:
		if key not in ["frames", "accel_mult", "own_stop", "rest_frames", "rest_kept", "rest_speed", "slow_speed", "cut_frames", "cut_dot"]:
			push_error("tuning.json: unknown skate.burst.%s" % key)
	# JamCartridge.h:67,70,80-85; JamSim.h:505. Share of the dial-adjusted base speed and thrust.
	free_speed_mult = cfg["free_speed_mult"]
	sprint_bonus = cfg["sprint_bonus"]
	sprint_carry_bonus = cfg["sprint_carry_bonus"]
	carrier_sprint_cap = cfg["carrier_sprint_cap"]
	carry_scale = g.tune["carry"]["carry_speed_scale"]
	carry_sprint_scale = minf(carry_scale * (1.0 + sprint_carry_bonus), carrier_sprint_cap * (1.0 + sprint_bonus))
	free_sprint_scale = free_speed_mult * (1.0 + sprint_bonus)
	sprint_drain_frames = cfg["sprint_drain_frames"]
	sprint_refill_frames = cfg["sprint_refill_frames"]
	stamina_full = sprint_drain_frames * sprint_refill_frames
	reverse_decel = cfg["reverse_decel"]
	reverse_dot = cfg["reverse_dot"]
	intent_min = cfg["intent_min"]
	stop_speed = cfg["stop_speed"]
	pivot_speed = cfg["pivot_speed"]
	burst_frames = burst["frames"]
	accel_mult = burst["accel_mult"]
	own_stop = burst["own_stop"]
	rest_frames = burst["rest_frames"]
	rest_kept = burst["rest_kept"]
	rest_speed = burst["rest_speed"]
	slow_speed = burst["slow_speed"]
	cut_frames = maxi(0, burst["cut_frames"])
	cut_dot = burst["cut_dot"]
	for id: String in g.order:
		var i := ids.size()
		slots[id] = i
		ids.append(id)
		bodies.append(g.skaters[id])
		if not g.keeper.is_goalie(id):
			field_slots.append(i)
	human_slot = slots["b0"]
	stamina.resize(ids.size())
	stamina.fill(stamina_full)
	sprinting.resize(ids.size())
	intent.resize(ids.size())
	braking.resize(ids.size())
	cursor.resize(ids.size())
	resting.resize(ids.size())
	earned.resize(ids.size())
	reversing.resize(ids.size())
	burst_left.resize(ids.size())
	history.resize(ids.size() * cut_frames)

## A set start forgets the previous approach. Match stop counts survive a face-off.
func reset() -> void:
	sprinting.fill(0)
	intent.fill(Vector3.ZERO)
	history.fill(Vector3.ZERO)
	cursor.fill(0)
	resting.fill(0)
	earned.fill(0)
	reversing.fill(0)
	braking.fill(0)
	burst_left.fill(0)

func want(id: String, v: Vector3) -> void:
	var i: int = slots[id]
	intent[i] = v
	bodies[i].move(v)

func brake(id: String, on: bool) -> void:
	var i: int = slots[id]
	braking[i] = int(on)
	bodies[i].brake(on)

## JamSim.cpp:1266-1300. A frame pays in refill ticks or recovers in drain ticks.
func pace(i: int, held: bool, move: Vector3) -> void:
	var active := held and stamina[i] > 0 and move.length_squared() > intent_min * intent_min
	if active:
		active = not bodies[i].is_down() and not bodies[i].is_stumbling() and not game.hits.is_braced(ids[i])
	sprinting[i] = int(active)
	if active:
		stamina[i] = maxi(0, stamina[i] - sprint_refill_frames)
	elif stamina[i] < stamina_full:
		stamina[i] = mini(stamina_full, stamina[i] + sprint_drain_frames)

func stamina_bar() -> String:
	if game.autopilot or (stamina[human_slot] == stamina_full and not sprinting[human_slot]):
		return ""
	var bars := ceili(10.0 * stamina[human_slot] / stamina_full)
	return "SPRINT [" + "|".repeat(bars) + " ".repeat(10 - bars) + "]"

func is_sprinting(id: String) -> bool:
	return sprinting[slots[id]] != 0

## JamSim.cpp:1281-1300,1338-1342. Both top speed and thrust use the same pace.
func _scale(carrying: bool, sprint: bool) -> float:
	if carrying:
		return carry_sprint_scale if sprint else carry_scale
	return free_sprint_scale if sprint else free_speed_mult

func top_speed(id: String) -> float:
	var scale := _scale(id == game.api.carrier, is_sprinting(id))
	return base_speed * scale * (game.hits.hold_speed if game.hits.is_braced(id) else 1.0)

func tick() -> void:
	var hits = game.hits
	var carrier: String = game.api.carrier
	var braced: String = hits.human if hits.hold_age > 0 and hits.is_braced(hits.human) else ""
	for i in field_slots:
		var sk := bodies[i]
		var id := ids[i]
		if sk.is_down():
			# Down frames cannot earn a cut. Keep the rest and burst clocks advancing.
			_cut(i, Vector3.ZERO)
			resting[i] = mini(resting[i] + 1, rest_frames)
			burst_left[i] = maxi(burst_left[i] - 1, 0)
			reversing[i] = 0
			sk.skate_speed = base_speed * _scale(false, false)   # L4b: reset while down too, so a boost (L5, x on top each frame) cannot compound
			sk.skate_accel = base_accel * _scale(false, false)
			continue
		var scale := _scale(id == carrier, sprinting[i] != 0)
		sk.skate_turn_rate = base_turn
		sk.skate_speed = base_speed * scale
		if id == braced:
			sk.skate_speed *= hits.hold_speed
			sk.skate_turn_rate *= hits.hold_turn
		sk.skate_accel = base_accel * scale
		_step(i, sk)

## JamSim.cpp:1302-1317, JamSim.h:501-502. An old direction can earn exactly one cut.
func _cut(i: int, dir: Vector3) -> bool:
	if cut_frames == 0:
		return false
	var start := i * cut_frames
	var head := cursor[i]
	var cut := false
	if dir != Vector3.ZERO and dir != history[start + (head + cut_frames - 1) % cut_frames]:
		for j in range(start, start + cut_frames):
			if history[j] != Vector3.ZERO and dir.dot(history[j]) < cut_dot:
				cut = true
				break
	if cut:
		for j in range(start, start + cut_frames):
			history[j] = Vector3.ZERO
	history[start + head] = dir
	cursor[i] = (head + 1) % cut_frames
	return cut

func _step(i: int, sk: TLBiped) -> void:
	var vel := Vector3(sk.velocity.x, 0, sk.velocity.z)
	var speed := vel.length()
	var move: Vector3 = intent[i]
	var mag := move.length()
	var can_act: bool = not sk.is_stumbling()
	# JamSim.cpp:1369-1406, JamSim.h:503, JamCartridge.h:90. Shove is impulse in N s.
	var dir := move.normalized() if can_act and mag > intent_min else Vector3.ZERO
	var brk: bool = can_act and braking[i]
	var reverse := not brk and dir != Vector3.ZERO and dir.dot(vel) < reverse_dot * speed
	var stop := reverse and speed > stop_speed
	if stop and not reversing[i]:
		var rig = sk.rig
		if rig != null and not game.ctx.headless and rig.has_method("clips") and (rig.clips() as PackedStringArray).has("skate_stop"):   # drawing only
			rig.play(&"skate_stop")
		game._event("skate_stop", sk.global_position, game.teams[ids[i]], ids[i])
	reversing[i] = int(stop)
	if reverse:
		var cut := minf(speed, reverse_decel * minf(mag, 1.0) / 60.0)
		sk.shove(-vel.normalized() * cut * sk.body_mass)
	# JamSim.cpp:1410-1412, JamSim.h:504. A pivot keeps turning under kernel steering.
	var pivot := speed < pivot_speed and dir.dot(sk.forward()) < reverse_dot
	var push := dir != Vector3.ZERO and not (brk or reverse or pivot)
	var left := maxi(burst_left[i] - 1, 0)
	if _cut(i, dir):
		left = burst_frames
	# JamSim.cpp:1318-1335,1430-1452; JamCartridge.h:93-125; JamSim.h:499-500.
	# A brake earns the next slow push. A bump below rest_kept preserves an armed start.
	if (stop or brk) and speed > stop_speed:
		earned[i] = 1
	elif not reverse and speed >= slow_speed:
		earned[i] = 0
	var rest := resting[i]
	var rested := rest >= rest_frames and speed < rest_kept
	var own := speed < slow_speed and (earned[i] != 0 or not own_stop)
	if push and (own or rested):
		left = burst_frames
		earned[i] = 0
	if push or speed >= rest_kept:
		rest = 0
	elif speed < rest_speed:
		rest = mini(rest + 1, rest_frames)
	elif not rested:
		rest = 0
	resting[i] = rest
	burst_left[i] = left
	if left > 0:
		sk.skate_accel *= accel_mult
	if reverse or pivot:
		sk.skate_accel = 0.0

func state() -> Dictionary:
	var s := {"stamina": {"b0": stamina[human_slot]}, "stamina_full": stamina_full}
	for i in field_slots:
		if i != human_slot and stamina[i] < stamina_full:
			s.stamina[ids[i]] = stamina[i]
		if sprinting[i]:
			if not s.has("sprinting"):
				s["sprinting"] = {}
			s.sprinting[ids[i]] = true
		if burst_left[i] > 0:
			if not s.has("burst_left"):
				s["burst_left"] = {}
			s["burst_left"][ids[i]] = burst_left[i]
	if not stops.is_empty():
		s["stops"] = stops.duplicate()
	return s

