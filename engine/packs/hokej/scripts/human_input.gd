extends RefCounted
## The human's devices, read for the core (K3 round 5). The rules that turn them into FJamInput (thirdjam's ReadHumanInput,
## ApplyButtons, FJamButtonResolver, the aim anchor, the S lock, signals 1-4, R) live in the core's glue
## (engine/cores/rink/GAMEMODE.md, RinkCore human mode "raw"); this script only reads the keys, the mouse buttons, the wheel
## and the cursor into the raw shape RinkCore.set_raw_input takes: Down / Pressed as Unreal key names (FJamBindings::Defaults,
## InputMapping.cpp:98-120; the signal keys One..Four, SignalSystem.cpp:46), Axis, CursorOnIce, CursorPx, CursorHitM,
## CameraYaw. MouseDeltaPx and StickAxis stay absent (the cursor is always shown; no gamepad).

## Unreal key name -> the pack's action and the Godot key or mouse button that is that key.
const KEYS: Dictionary = {
	"W": [&"k_w", KEY_W], "Up": [&"k_up", KEY_UP], "S": [&"k_s", KEY_S], "Down": [&"k_down", KEY_DOWN],
	"A": [&"k_a", KEY_A], "Left": [&"k_left", KEY_LEFT], "D": [&"k_d", KEY_D], "Right": [&"k_right", KEY_RIGHT],
	"LeftShift": [&"k_shift", KEY_SHIFT], "LeftControl": [&"k_ctrl", KEY_CTRL],
	"Q": [&"k_q", KEY_Q], "SpaceBar": [&"k_space", KEY_SPACE], "E": [&"k_e", KEY_E], "F": [&"k_f", KEY_F], "R": [&"k_r", KEY_R],
	"One": [&"k_1", KEY_1], "Two": [&"k_2", KEY_2], "Three": [&"k_3", KEY_3], "Four": [&"k_4", KEY_4],
}
const BUTTONS: Dictionary = {
	"LeftMouseButton": [&"m_left", MOUSE_BUTTON_LEFT], "RightMouseButton": [&"m_right", MOUSE_BUTTON_RIGHT],
	"MiddleMouseButton": [&"m_middle", MOUSE_BUTTON_MIDDLE], "ThumbMouseButton": [&"m_thumb", MOUSE_BUTTON_XBUTTON1],
}


static func declare(input) -> void:
	for k: String in KEYS:
		input.declare(KEYS[k][0], [KEYS[k][1]])
	for b: String in BUTTONS:
		input.declare(BUTTONS[b][0], [], [BUTTONS[b][1]])


## IA_Move's value (InputMapping.cpp:950-953): the skate keys' axis, x right, y forward, each clamped to [-1, 1].
static func axis(input) -> Vector2:
	var f: float = _any(input, ["W", "Up"])
	var b: float = _any(input, ["S", "Down"])
	var l: float = _any(input, ["A", "Left"])
	var r: float = _any(input, ["D", "Right"])
	return Vector2(clampf(r - l, -1.0, 1.0), clampf(f - b, -1.0, 1.0))


## This frame's devices in RinkCore's raw shape. cam_yaw: the camera's yaw of the last sim frame, radians in rink
## coordinates (ReadHumanInput reads the camera, HokejGameMode.cpp:943-946).
static func raw(input, cam_yaw: float, cursor_ok: bool, cursor_px: Vector2, cursor_hit: Vector2) -> Dictionary:
	var down: PackedStringArray = PackedStringArray()
	var pressed: PackedStringArray = PackedStringArray()
	for k: String in KEYS:
		if input.pressed(KEYS[k][0]):
			down.append(k)
		if input.just_pressed(KEYS[k][0]):
			pressed.append(k)
	for b: String in BUTTONS:
		if input.pressed(BUTTONS[b][0]):
			down.append(b)
		if input.just_pressed(BUTTONS[b][0]):
			pressed.append(b)
	var zoom: float = input.strength(TLInput.ZOOM)       # the wheel: + is out (down); IA_Deke takes either (InputMapping.cpp:113)
	if zoom < 0.0:
		pressed.append("MouseScrollUp")
	elif zoom > 0.0:
		pressed.append("MouseScrollDown")
	var r: Dictionary = {"Down": down, "Pressed": pressed, "Axis": axis(input), "CameraYaw": cam_yaw, "CursorOnIce": cursor_ok}
	if cursor_ok:
		r["CursorPx"] = cursor_px
		r["CursorHitM"] = cursor_hit
	return r


static func _any(input, names: Array) -> float:
	for n: String in names:
		if input.pressed(KEYS[n][0]):
			return 1.0
	return 0.0
