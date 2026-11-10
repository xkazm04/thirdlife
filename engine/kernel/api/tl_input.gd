class_name TLInput
extends Node
## Named actions: the one door for input. A pack declares actions; the player presses keys, a bot injects, and the
## game reads the same values either way. Everything is latched once per physics frame. Capability: `input`.
## The pack reaches it as `ctx.input`.

signal action_pressed(action: StringName)
signal action_released(action: StringName)

## Set by the kernel: real devices are read only in interactive play. Verify runs ignore keyboard and mouse entirely.
var accept_devices: bool = false

var _actions: Dictionary = {}     # name -> {keys: Array[int], injected: float, hold: int, now: float, prev: float}
var _warned: Dictionary = {}


## Declares an action. `keys` are physical key codes (KEY_W, KEY_SPACE, ...); a bot needs none.
func declare(action: StringName, keys: Array = []) -> void:
	TLContext.require("input", "ctx.input")
	if _actions.has(action):
		(_actions[action] as Dictionary)["keys"] = keys.duplicate()
		return
	_actions[action] = {"keys": keys.duplicate(), "injected": 0.0, "hold": -1, "now": 0.0, "prev": 0.0}


func declared() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for a: StringName in _actions.keys():
		out.append(String(a))
	return out


## 0..1 for this frame.
func strength(action: StringName) -> float:
	var a: Variant = _action(action)
	return 0.0 if a == null else float((a as Dictionary)["now"])


func pressed(action: StringName) -> bool:
	return strength(action) >= 0.5


## True only on the first frame the action is down.
func just_pressed(action: StringName) -> bool:
	var a: Variant = _action(action)
	return a != null and float((a as Dictionary)["now"]) >= 0.5 and float((a as Dictionary)["prev"]) < 0.5


func just_released(action: StringName) -> bool:
	var a: Variant = _action(action)
	return a != null and float((a as Dictionary)["now"]) < 0.5 and float((a as Dictionary)["prev"]) >= 0.5


## -1..1 from two actions.
func axis(negative: StringName, positive: StringName) -> float:
	return strength(positive) - strength(negative)


## x = right - left, y = down - up, length at most 1 (the same convention as Input.get_vector).
func vector(left: StringName, right: StringName, up: StringName, down: StringName) -> Vector2:
	var v: Vector2 = Vector2(axis(left, right), axis(up, down))
	return v.limit_length(1.0)


# ---- injection: the door bots, AI and replays use ---------------------------------------------------------------

## Holds an action down until `release()`.
func press(action: StringName, value: float = 1.0) -> void:
	var a: Variant = _action(action)
	if a != null:
		(a as Dictionary)["injected"] = clampf(value, 0.0, 1.0)
		(a as Dictionary)["hold"] = -1


func release(action: StringName) -> void:
	var a: Variant = _action(action)
	if a != null:
		(a as Dictionary)["injected"] = 0.0
		(a as Dictionary)["hold"] = -1


## Presses for a number of frames, then releases by itself.
func tap(action: StringName, frames: int = 1) -> void:
	var a: Variant = _action(action)
	if a != null:
		(a as Dictionary)["injected"] = 1.0
		(a as Dictionary)["hold"] = maxi(1, frames)


## Sets a two-action axis in one call: `set_axis(&"left", &"right", -0.4)`.
func set_axis(negative: StringName, positive: StringName, value: float) -> void:
	press(negative, maxf(0.0, -value))
	press(positive, maxf(0.0, value))


func release_all() -> void:
	for a: Dictionary in _actions.values():
		a["injected"] = 0.0
		a["hold"] = -1


# ---- kernel side ------------------------------------------------------------------------------------------------

func _action(action: StringName) -> Variant:
	if _actions.has(action):
		return _actions[action]
	if not _warned.has(action):
		_warned[action] = true
		push_error("input action '%s' was not declared (ctx.input.declare)" % action)
	return null


## Called by the kernel once per physics frame, after the bot's tick and before the pack's tick.
func _sample() -> void:
	for name: StringName in _actions.keys():
		var a: Dictionary = _actions[name]
		var v: float = float(a["injected"])
		if accept_devices:
			for k: Variant in (a["keys"] as Array):
				if Input.is_physical_key_pressed(int(k)):
					v = 1.0
		a["prev"] = a["now"]
		a["now"] = v
		if int(a["hold"]) > 0:
			a["hold"] = int(a["hold"]) - 1
			if int(a["hold"]) == 0:
				a["injected"] = 0.0
				a["hold"] = -1
		if float(a["now"]) >= 0.5 and float(a["prev"]) < 0.5:
			action_pressed.emit(name)
		elif float(a["now"]) < 0.5 and float(a["prev"]) >= 0.5:
			action_released.emit(name)
