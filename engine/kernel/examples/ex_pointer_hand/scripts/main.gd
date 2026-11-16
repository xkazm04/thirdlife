extends Node
## Primitive example (K4): a target on the ground jumps every JUMP_EVERY frames to a new place (the seeded generator)
## and slides on from there at SLIDE m/s, TARGETS times. The player aims (the aim "aim" on the ground) and shoots
## ("shoot": Space or the left button). A shot hits when the aim is within HIT metres of the target on the frame the
## game sees the press. Measured per run: hits, the aim's error at each shot, and the lag: frames from a jump until the
## aim first comes within HIT of the target (JUMP_EVERY when it never does).

const TARGETS: int = 20
const JUMP_EVERY: int = 90
const SLIDE: float = 3.0
const HIT: float = 0.6
var ctx
var ticks: int = 0
var target: Vector3 = Vector3.ZERO
var heading: Vector3 = Vector3.ZERO
var index: int = -1                  # the target's number (a jump makes the next one)
var since: int = 0                   # frames since the last jump
var reached: bool = false
var hits: int = 0
var shots: int = 0
var error_sum: float = 0.0
var lag_sum: int = 0
var lags: int = 0


func _pack_setup(c) -> void:
	ctx = c
	ctx.input.declare_aim(&"aim", 0.0, 200.0)
	ctx.input.declare(&"shoot", [KEY_SPACE], [MOUSE_BUTTON_LEFT])
	ctx.cameras.add_view(&"top", Vector3(0, 40, 10), Vector3(0, 0, 0), 55.0)


func _pack_start() -> void:
	pass


func _jump() -> void:
	if index >= 0:
		lag_sum += JUMP_EVERY if not reached else 0
		lags += 0 if reached else 1
	index += 1
	since = 0
	reached = false
	target = Vector3(ctx.rng.randf_range(-10.0, 10.0), 0.0, ctx.rng.randf_range(-8.0, 8.0))
	var a: float = ctx.rng.randf() * TAU
	heading = Vector3(cos(a), 0.0, sin(a)) * SLIDE


func _pack_tick(_frame: int) -> void:
	ticks += 1
	if index < 0 or (since >= JUMP_EVERY and index < TARGETS):
		_jump()
	if index >= TARGETS:
		return
	since += 1
	target += heading / 60.0
	var near: bool = ctx.input.aim_valid(&"aim") and _flat(ctx.input.aim(&"aim") - target) <= HIT
	if near and not reached:
		reached = true
		lag_sum += since
		lags += 1
	if ctx.input.just_pressed(&"shoot"):
		shots += 1
		var e: float = _flat(ctx.input.aim(&"aim") - target) if ctx.input.aim_valid(&"aim") else 99.0
		error_sum += e
		if e <= HIT:
			hits += 1
	if since == JUMP_EVERY and index == TARGETS - 1:
		index = TARGETS                     # the last target is over
		if not reached:
			lag_sum += JUMP_EVERY
			lags += 1


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _pack_state() -> Dictionary:
	return {"ticks": ticks, "index": index, "since": since, "target_x": target.x, "target_z": target.z, "hits": hits,
		"shots": shots, "over": index >= TARGETS, "mean_error": error_sum / maxf(1.0, float(shots)),
		"mean_lag": float(lag_sum) / maxf(1.0, float(lags)), "lags": lags}
