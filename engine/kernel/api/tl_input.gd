class_name TLInput
extends Node
## Named actions: the one door for input. A pack declares actions; the player presses keys, a bot injects, and the
## game reads the same values either way. Everything is latched once per physics frame. Capability: `input`.
## The pack reaches it as `ctx.input`.
## P7: the latch is the record. Every device a game can feel comes through here: keys, and the pointer as the three
## kernel actions LOOK_X, LOOK_Y (pixels of a right-button drag in this frame) and ZOOM (wheel notches, + is out).
## Each frame's values that are not zero can be kept as `tl.input/1` frames and fed back instead of devices and bots.
## A sample is a multiple of 0.001 (STEP), whoever made it: what a game reads is exactly what a record can hold.
## K1: an aim is a declared action whose value is a point: where the cursor meets a ground plane (y = a height the
## pack gives) through the camera on screen, resolved once per physics frame from the camera's pose at that frame
## (lens shake left out), or the point a bot set with `set_aim`. Without a bot or a cursor over the window it is
## invalid, never a stale point.

signal action_pressed(action: StringName)
signal action_released(action: StringName)

## The pointer's actions: declared by the kernel in every pack, any value (not 0..1), each lasts one frame.
const LOOK_X: StringName = &"tl.look_x"
const LOOK_Y: StringName = &"tl.look_y"
const ZOOM: StringName = &"tl.zoom"
## Every sample is rounded to this step when it is latched (the state hash's step too).
const STEP: float = 0.001
## An aim closer than this to the `from` of `aim_direction` (metres on the plane) has no direction: the fallback is returned.
const AIM_DEAD: float = 0.05

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
# K1: name -> {height, reach, set: bool, at: Vector3 (what a bot set), valid: bool, now: Vector3 (the latched point)}
var _aims: Dictionary = {}


func _init() -> void:
	for a: StringName in [LOOK_X, LOOK_Y, ZOOM]:
		_actions[a] = {"keys": [], "injected": 0.0, "hold": -1, "now": 0.0, "prev": 0.0, "analog": true}


## Declares an action. `keys` are physical key codes (KEY_W, KEY_SPACE, ...); K2: `buttons` are mouse buttons
## (MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE) that press it too, in interactive play. A bot needs neither.
func declare(action: StringName, keys: Array = [], buttons: Array = []) -> void:
	TLContext.require("input", "ctx.input")
	if _aims.has(action):
		push_error("ctx.input.declare('%s'): the name is already an aim (declare_aim)" % action)
		return
	if String(action).contains("@"):   # hunt2 C2: "<aim>@x" / "@z" name an aim's record entries; a plain action never does
		push_error("ctx.input.declare('%s'): '@' is reserved for an aim's record entries" % action)
		return
	if _actions.has(action):
		(_actions[action] as Dictionary)["keys"] = keys.duplicate()
		(_actions[action] as Dictionary)["buttons"] = buttons.duplicate()
		return
	_actions[action] = {"keys": keys.duplicate(), "buttons": buttons.duplicate(), "injected": 0.0, "hold": -1, "now": 0.0, "prev": 0.0}
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


# ---- K1: the aim, a point on the ground under the cursor --------------------------------------------------------

## Declares an aim: each frame, the point on the plane y = `height` under the cursor through the camera on screen,
## valid while the cursor is over the window and the ray meets the plane in front of the camera within `reach`
## metres. A bot sets it with `set_aim`. Declare it again to change height or reach.
func declare_aim(action: StringName, height: float = 0.0, reach: float = 200.0) -> void:
	TLContext.require("input", "ctx.input")
	if _actions.has(action):
		push_error("ctx.input.declare_aim('%s'): the name is already a plain action" % action)
		return
	if String(action).contains("@"):   # hunt2 C2: reserved for the record entries "<aim>@x" / "@z"
		push_error("ctx.input.declare_aim('%s'): '@' is reserved for an aim's record entries" % action)
		return
	if _aims.has(action):
		(_aims[action] as Dictionary)["height"] = height
		(_aims[action] as Dictionary)["reach"] = maxf(reach, 0.0)
		return
	_aims[action] = {"height": height, "reach": maxf(reach, 0.0), "set": false, "at": Vector3.ZERO, "valid": false, "now": Vector3.ZERO}


## True when the aim has a point this frame (a cursor over the window whose ray meets the plane, or a bot's point).
func aim_valid(action: StringName) -> bool:
	var a: Variant = _aim_of(action)
	return a != null and bool((a as Dictionary)["valid"])


## The aim's point this frame, on its plane (y = its height; x and z multiples of STEP). Vector3.ZERO when invalid:
## read `aim_valid` first.
func aim(action: StringName) -> Vector3:
	var a: Variant = _aim_of(action)
	return (a as Dictionary)["now"] if a != null and bool((a as Dictionary)["valid"]) else Vector3.ZERO


## The unit vector on the plane (y = 0) from `from` to the aim's point. When the aim is invalid, or the point is
## within AIM_DEAD metres of `from` on the plane (the cursor sits on the figure), it returns `fallback` flattened
## and normalised (Vector3.ZERO when that has no length): pass the figure's facing and it keeps it.
func aim_direction(action: StringName, from: Vector3, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if aim_valid(action):
		var d: Vector3 = aim(action) - from
		d.y = 0.0
		if d.length() > AIM_DEAD:
			return d.normalized()
	var f: Vector3 = Vector3(fallback.x, 0.0, fallback.z)
	return f.normalized() if f.length() > 0.000001 else Vector3.ZERO


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
	for a: Dictionary in _aims.values():
		a["set"] = false


## K1. Points an aim at `point` (its y is ignored: the point is put on the aim's plane) until `clear_aim`; the game
## reads it from the next sample on, as it reads a `press`. It wins over the cursor.
func set_aim(action: StringName, point: Vector3) -> void:
	var a: Variant = _aim_of(action)
	if a != null:
		(a as Dictionary)["set"] = true
		(a as Dictionary)["at"] = point


## K1. Takes a bot's point away: the aim is the cursor's again (invalid in a verify run).
func clear_aim(action: StringName) -> void:
	var a: Variant = _aim_of(action)
	if a != null:
		(a as Dictionary)["set"] = false


# ---- kernel side ------------------------------------------------------------------------------------------------

func _action(action: StringName) -> Variant:
	if _actions.has(action):
		return _actions[action]
	if not _warned.has(action):
		_warned[action] = true
		push_error("input action '%s' was not declared (ctx.input.declare)" % action)
	return null


func _aim_of(action: StringName) -> Variant:
	if _aims.has(action):
		return _aims[action]
	if not _warned.has(action):
		_warned[action] = true
		push_error("aim '%s' was not declared (ctx.input.declare_aim)" % action)
	return null


## K1. A record's entry that belongs to an aim: its own name, or the name with "@x" / "@z".
func _is_aim_entry(name: StringName) -> bool:
	var s: String = String(name)
	if s.ends_with("@x") or s.ends_with("@z"):
		s = s.substr(0, s.length() - 2)
	return _aims.has(StringName(s))


## K1. Interactive play only: where the ray under the cursor meets the plane y = `height`, or null. The ray is made
## from the pose the camera has now (a physics frame: chase and orbit cameras move in _physics_process) and its lens,
## leaving out the shake's lens offsets (`h_offset`, `v_offset`: visual only, the aim does not shake).
func _cursor_on_plane(height: float, reach: float) -> Variant:
	if not is_inside_tree():
		return null
	var win: Window = get_window()
	var vp: Viewport = get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp != null else null
	if win == null or cam == null:
		return null
	var screen: Vector2i = DisplayServer.mouse_get_position()
	if not Rect2i(win.position, win.size).has_point(screen):
		return null                       # the cursor is not over the window
	return _ray_on_plane(cam, vp.get_mouse_position(), vp.get_visible_rect().size, height, reach)


## K1. Kernel side: where the ray through screen point `mp` (pixels in a viewport of `size`) of `cam` meets the plane
## y = `height` within `reach` metres in front of the camera, or null. Lens offsets (shake) are left out.
static func _ray_on_plane(cam: Camera3D, mp: Vector2, size: Vector2, height: float, reach: float) -> Variant:
	if size.x < 1.0 or size.y < 1.0 or not Rect2(Vector2.ZERO, size).has_point(mp):
		return null
	var ndc: Vector2 = Vector2(mp.x / size.x * 2.0 - 1.0, 1.0 - mp.y / size.y * 2.0)
	var aspect: float = size.x / size.y
	var basis: Basis = cam.global_transform.basis.orthonormalized()
	var origin: Vector3 = cam.global_position
	var dir: Vector3
	if cam.projection == Camera3D.PROJECTION_PERSPECTIVE:
		var t: float = tan(deg_to_rad(cam.fov) * 0.5)
		var local: Vector3 = Vector3(ndc.x * t * aspect, ndc.y * t, -1.0) if cam.keep_aspect == Camera3D.KEEP_HEIGHT \
			else Vector3(ndc.x * t, ndc.y * t / aspect, -1.0)
		dir = (basis * local).normalized()
	elif cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		var half: float = cam.size * 0.5
		var off: Vector2 = Vector2(ndc.x * half * aspect, ndc.y * half) if cam.keep_aspect == Camera3D.KEEP_HEIGHT \
			else Vector2(ndc.x * half, ndc.y * half / aspect)
		origin += basis.x * off.x + basis.y * off.y
		dir = -basis.z
	else:
		origin = cam.project_ray_origin(mp)
		dir = cam.project_ray_normal(mp)
	if absf(dir.y) < 0.000001:
		return null                       # the ray runs along the plane
	var along: float = (height - origin.y) / dir.y
	if along <= 0.0 or along > reach:
		return null                       # the plane is behind the camera, or farther than the aim reaches
	return origin + dir * along


## K8. Kernel side: true when an action the pack declared has the physical key `keycode` (the host asks it of the game
## on stage: a key the game declared belongs to the game, so the host does not take it for itself). Reads declarations
## only, never a device.
func _declares_key(keycode: int) -> bool:
	for name: StringName in _order:
		if ((_actions[name] as Dictionary)["keys"] as Array).has(keycode):
			return true
	return false


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
	var aim_names: Array = []
	for key: StringName in _aims.keys():
		if bool((_aims[key] as Dictionary).get("ever", false)):
			aim_names.append(String(key))
	if aim_names.is_empty():
		return                            # K1, K2: an aim that was never valid adds nothing: a pack that declares one and never
		                                  # points it (every keyboard run) hashes exactly as before aims existed
	aim_names.sort()
	buf.put_data("|aim".to_utf8_buffer())
	for name: String in aim_names:
		var m: Dictionary = _aims[StringName(name)]
		buf.put_data(name.to_utf8_buffer())
		buf.put_8(1 if bool(m["valid"]) else 0)
		buf.put_64(int(roundf((m["now"] as Vector3).x * 1000.0)))
		buf.put_64(int(roundf((m["now"] as Vector3).z * 1000.0)))


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
			if not _actions.has(name) and not _is_aim_entry(name) and not _warned.has(name):
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
			for b: Variant in (a.get("buttons", []) as Array):     # K2: a mouse button declared with the action
				if Input.is_mouse_button_pressed(int(b)):
					v = 1.0
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
	# K1: the aims. A fed record decides alone; else a bot's point; else the cursor in interactive play; else invalid.
	# In a record a valid aim is three entries of its frame: [f, "<aim>", 1], [f, "<aim>@x", x], [f, "<aim>@z", z]
	# (x or z left out when it is 0, as every zero is); a frame without "<aim>" is an invalid aim.
	for name: StringName in _aims.keys():
		var m: Dictionary = _aims[name]
		var p: Variant = null
		if _play != null:
			if float(fed.get(name, 0.0)) >= 0.5:
				p = Vector3(float(fed.get(StringName(String(name) + "@x"), 0.0)), 0.0, float(fed.get(StringName(String(name) + "@z"), 0.0)))
		elif bool(m["set"]):
			p = m["at"]
		elif devices:
			p = _cursor_on_plane(float(m["height"]), float(m["reach"]))
		m["valid"] = p != null
		if p != null:
			m["ever"] = true                # K2: from now on the aim is part of the state hash
		m["now"] = Vector3(roundf((p as Vector3).x * 1000.0) / 1000.0, float(m["height"]), roundf((p as Vector3).z * 1000.0) / 1000.0) \
			if p != null else Vector3.ZERO
		if _rec != null and p != null:
			(_rec as Array).append([_ticks, String(name), 1.0])
			if (m["now"] as Vector3).x != 0.0:
				(_rec as Array).append([_ticks, String(name) + "@x", (m["now"] as Vector3).x])
			if (m["now"] as Vector3).z != 0.0:
				(_rec as Array).append([_ticks, String(name) + "@z", (m["now"] as Vector3).z])
	_ticks += 1
