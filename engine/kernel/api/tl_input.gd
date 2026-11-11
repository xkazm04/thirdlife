class_name TLInput
extends Node
## Named actions: the one door for input. A pack declares actions; the player presses keys, a bot injects, and the
## game reads the same values either way. Everything is latched once per physics frame. Capability: `input`.
## The pack reaches it as `ctx.input`.
## P7: the latch is the record. Every device a game can feel comes through here: keys, and the pointer as the three
## kernel actions LOOK_X, LOOK_Y (pixels of a right-button drag in this frame) and ZOOM (wheel notches, + is out).
## Each frame's values that are not zero can be kept as `tl.input/1` frames and fed back instead of devices and bots.
## A sample is a multiple of 0.001 (STEP), whoever made it: what a game reads is exactly what a record can hold.

signal action_pressed(action: StringName)
signal action_released(action: StringName)

## The pointer's actions: declared by the kernel in every pack, any value (not 0..1), each lasts one frame.
const LOOK_X: StringName = &"tl.look_x"
const LOOK_Y: StringName = &"tl.look_y"
const ZOOM: StringName = &"tl.zoom"
## Every sample is rounded to this step when it is latched (the state hash's step too).
const STEP: float = 0.001

## Set by the kernel: real devices are read only in interactive play. Verify runs ignore keyboard and mouse entirely.
var accept_devices: bool = false

var _actions: Dictionary = {}     # name -> {keys: Array[int], injected: float, hold: int, now: float, prev: float, analog?}
var _warned: Dictionary = {}
var _ticks: int = 0               # samples taken so far: the frame the next sample belongs to
var _rec: Variant = null          # Array of [frame, action, value] while a record is kept
var _play: Variant = null         # the same list while a record is fed back (devices and injection are ignored)
var _play_at: int = 0
var _pointer: Vector3 = Vector3.ZERO   # what the mouse did since the last sample: drag x, drag y, wheel
var _order: Array[StringName] = []     # the declared actions in the order they were declared (the pointer's three are sampled apart)
var _pointer_live: bool = false        # a pointer action is not zero, was not a frame ago, or was injected: only then are the three sampled
const _POINTER: Array[StringName] = [LOOK_X, LOOK_Y, ZOOM]
const _NOTHING: Dictionary = {}


func _init() -> void:
	for a: StringName in [LOOK_X, LOOK_Y, ZOOM]:
		_actions[a] = {"keys": [], "injected": 0.0, "hold": -1, "now": 0.0, "prev": 0.0, "analog": true}


## Declares an action. `keys` are physical key codes (KEY_W, KEY_SPACE, ...); a bot needs none.
func declare(action: StringName, keys: Array = []) -> void:
	TLContext.require("input", "ctx.input")
	if _actions.has(action):
		(_actions[action] as Dictionary)["keys"] = keys.duplicate()
		return
	_actions[action] = {"keys": keys.duplicate(), "injected": 0.0, "hold": -1, "now": 0.0, "prev": 0.0}
	_order.append(action)


## The actions the pack declared (the kernel's pointer actions are not listed).
func declared() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for a: StringName in _actions.keys():
		if not (_actions[a] as Dictionary).has("analog"):
			out.append(String(a))
	return out


## 0..1 for this frame (a pointer action: pixels or notches of this frame, any sign).
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

## Holds an action down until `release()`. A pointer action (LOOK_X, LOOK_Y, ZOOM) takes any value for one frame.
func press(action: StringName, value: float = 1.0) -> void:
	var a: Variant = _action(action)
	if a != null:
		(a as Dictionary)["injected"] = value if (a as Dictionary).has("analog") else clampf(value, 0.0, 1.0)
		(a as Dictionary)["hold"] = -1
		if (a as Dictionary).has("analog"):
			_pointer_live = true


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


## True while a text field has the keyboard (the designer panel's fields): the game sees no key then.
func keys_taken() -> bool:
	var vp: Viewport = get_viewport() if is_inside_tree() else null
	var f: Control = vp.gui_get_focus_owner() if vp != null else null
	return f is LineEdit or f is TextEdit


## Interactive play only: a drag with the right mouse button and the wheel are kept until the next sample.
func _unhandled_input(event: InputEvent) -> void:
	if not accept_devices:
		return
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_RIGHT:
		_pointer.x += (event as InputEventMouseMotion).relative.x
		_pointer.y += (event as InputEventMouseMotion).relative.y
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_UP:
			_pointer.z -= 1.0
		elif (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_pointer.z += 1.0


## Kernel side. Keeps every later sample that is not zero as [frame, action, value]; returns the growing list.
func _record() -> Array:
	_rec = []
	return _rec


## Kernel side. From now on the samples come from `frames` (a `tl.input/1` list sorted by frame) and nothing else.
func _feed(frames: Array) -> void:
	_play = frames
	_play_at = 0


## Kernel side. What the game can read of the input, for the state hash: every action's value now and one frame ago.
func _hash_into(buf: StreamPeerBuffer) -> void:
	var names: Array = []
	for key: StringName in _actions.keys():
		names.append(String(key))      # as text: StringNames sort by where they sit in memory, which differs from run to run
	names.sort()
	for name: String in names:
		var a: Dictionary = _actions[StringName(name)]
		buf.put_data(name.to_utf8_buffer())
		buf.put_64(int(roundf(float(a["now"]) * 1000.0)))
		buf.put_64(int(roundf(float(a["prev"]) * 1000.0)))


## Called by the kernel once per physics frame, after the bot's tick and before the pack's tick.
func _sample() -> void:
	var devices: bool = accept_devices and _play == null
	var fed: Dictionary = _NOTHING
	if _play != null:
		fed = {}
		while _play_at < (_play as Array).size() and int(_play[_play_at][0]) <= _ticks:
			if int(_play[_play_at][0]) == _ticks:
				fed[StringName(str(_play[_play_at][1]))] = float(_play[_play_at][2])
			_play_at += 1
		for name: StringName in fed.keys():
			if not _actions.has(name) and not _warned.has(name):
				_warned[name] = true
				push_error("the input record presses '%s' at frame %d, an action this pack did not declare" % [name, _ticks])
	# the pointer: sampled only while it is alive, so a pack nobody points at pays one test per frame
	if _pointer_live or _play != null or (devices and _pointer != Vector3.ZERO):
		_pointer_live = false
		for name: StringName in _POINTER:
			var p: Dictionary = _actions[name]
			var pv: float = float(p["injected"])
			p["injected"] = 0.0           # a pointer value lasts one frame
			p["hold"] = -1
			if devices:
				pv += _pointer.x if name == LOOK_X else (_pointer.y if name == LOOK_Y else _pointer.z)
			if _play != null:
				pv = float(fed.get(name, 0.0))
			pv = roundf(pv * 1000.0) / 1000.0
			p["prev"] = p["now"]
			p["now"] = pv
			if _rec != null and pv != 0.0:
				(_rec as Array).append([_ticks, String(name), pv])
			if pv != 0.0 or float(p["prev"]) != 0.0:
				_pointer_live = true      # the next frame has to bring it back to zero
		_pointer = Vector3.ZERO
	var keys: bool = devices and not _order.is_empty() and not keys_taken()
	for name: StringName in _order:
		var a: Dictionary = _actions[name]
		var v: float = float(a["injected"])
		if keys:
			for k: Variant in (a["keys"] as Array):
				if Input.is_physical_key_pressed(int(k)):
					v = 1.0
		if _play != null:
			v = float(fed.get(name, 0.0))
		v = roundf(v * 1000.0) / 1000.0      # STEP: k / 1000 is the same number in every reader of a record
		a["prev"] = a["now"]
		a["now"] = v
		if _rec != null and v != 0.0:
			(_rec as Array).append([_ticks, String(name), v])
		if int(a["hold"]) > 0:
			a["hold"] = int(a["hold"]) - 1
			if int(a["hold"]) == 0:
				a["injected"] = 0.0
				a["hold"] = -1
		if v >= 0.5 and float(a["prev"]) < 0.5:
			action_pressed.emit(name)
		elif v < 0.5 and float(a["prev"]) >= 0.5:
			action_released.emit(name)
	_ticks += 1
