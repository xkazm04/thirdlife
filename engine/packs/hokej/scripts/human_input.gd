extends RefCounted
## The human's devices, as thirdjam's game mode turns them into FJamInput (K3 round 3). S = thirdjam HEAD 8dc713c6 Game/Source.
##
## Two halves:
##  1. raw(): the devices of this frame in the raw shape lane K1's core glue reads (engine/cores/rink/GAMEMODE.md,
##     RinkCore.set_raw_input: Down / Pressed as Unreal key names, Axis, CursorPx, CursorHitM, CursorOnIce, CameraYaw). This
##     half stays in the shell for good.
##  2. read(): MOVES TO CORE GLUE. The pack's own port of AHokejGameMode::ReadHumanInput (HokejGameMode.cpp:931-1000) with
##     JamControls::ApplyButtons (InputMapping.cpp:488-503) and FJamButtonResolver (InputMapping.cpp:318-424), until K1's
##     RinkCore v1.1 (human mode "raw", rink_gamemode.cpp) lands in this tree; then main.gd hands raw() to the core instead.
##     Team signals 1-4 need the core (the brain's world, HokejGameMode.cpp:1320-1331): not given by this half.

const Controls := preload("controls.gd")

## Unreal key name -> the pack's action (declared in main.gd with the Godot key or mouse button that is that key).
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

# FJamBindings::Defaults (InputMapping.cpp:98-119), the two-role verbs: key -> [with-the-puck verb, without-the-puck verb]
const WITH: Dictionary = {"LeftMouseButton": "Shoot", "RightMouseButton": "Pass", "Q": "Pass"}
const WITHOUT: Dictionary = {"LeftMouseButton": "CrossCheck", "MiddleMouseButton": "CrossCheck", "ThumbMouseButton": "CrossCheck", "RightMouseButton": "Check"}
const SLOT_KEYS: Array = ["LeftMouseButton", "MiddleMouseButton", "ThumbMouseButton", "RightMouseButton", "Q"]
# UJamSim::CrossHoldTapFrames (JamSim.h:755); jam.ctrl.BraceHoldFrames 13, SaucerHoldFrames 13 (InputMapping.cpp:456-460)
const CROSS_HOLD_TAP: int = 10
const BRACE_HOLD: int = 13
const SAUCER_HOLD: int = 13

var controls = Controls.new()     # the move's back-yaw hold, the stick aim, the aim anchor (rounds 1-2)
var held: Array = []              # FJamButtonResolver::Held: [{key, verb, down, new, dead, level_sent, level_dropped, steps}]
var last_down: Dictionary = {}
var cfg: Dictionary = {}          # {"carrier_reach", "saucer_half", "pass_power_full"}


func _init(config: Dictionary) -> void:
	cfg = config


static func declare(input) -> void:
	for k: String in KEYS:
		input.declare(KEYS[k][0], [KEYS[k][1]])
	for b: String in BUTTONS:
		input.declare(BUTTONS[b][0], [], [BUTTONS[b][1]])


## The devices of this frame, in K1's raw shape (no camera, no possession: those are the core's to read).
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
	var zoom: float = input.strength(TLInput.ZOOM)       # the wheel: + is out (down); IA_Deke is either way (InputMapping.cpp:113)
	if zoom < 0.0:
		pressed.append("MouseScrollUp")
	elif zoom > 0.0:
		pressed.append("MouseScrollDown")
	var ax: Vector2 = Controls.axis(_any(input, ["W", "Up"]), _any(input, ["S", "Down"]), _any(input, ["A", "Left"]), _any(input, ["D", "Right"]))
	var r: Dictionary = {"Down": down, "Pressed": pressed, "Axis": ax, "CameraYaw": cam_yaw, "CursorOnIce": cursor_ok}
	if cursor_ok:
		r["CursorPx"] = cursor_px
		r["CursorHitM"] = cursor_hit
	return r


static func _any(input, names: Array) -> float:
	for n: String in names:
		if input.pressed(KEYS[n][0]):
			return 1.0
	return 0.0


# ---- MOVES TO CORE GLUE -------------------------------------------------------------------------------------------

## JamControls::HasPuckForButtons (InputMapping.cpp:432-442; jam.ctrl.OurPuckShoots 1).
static func has_puck_for_buttons(snap: Dictionary, me: int) -> bool:
	var sk: Array = snap["Skaters"]
	var carrier: int = int(snap["Carrier"])
	if carrier == me:
		return true
	if carrier >= 0:
		return false
	var last: int = int(snap["Puck"]["LastTouch"])
	return last >= 0 and last < sk.size() and int(sk[last]["Team"]) == int(sk[me]["Team"])


## JamControls::ButtonContext (InputMapping.cpp:474-486).
func context(snap: Dictionary, me: int) -> Dictionary:
	var s: Dictionary = snap["Skaters"][me]
	var half: int = int(cfg["saucer_half"])
	var saucer_hold: int = half if half <= 0 else maxi(half, SAUCER_HOLD)
	return {"with": has_puck_for_buttons(snap, me), "carrying": int(snap["Carrier"]) == me,
		"in_reach": (s["Pos"] as Vector2).distance_to(snap["Puck"]["Pos"]) <= float(cfg["carrier_reach"]),
		"dead_across": true,
		"saucer_delay": maxi(0, saucer_hold - half) if half > 0 and int(cfg["pass_power_full"]) <= 0 else 0,
		"brace_delay": maxi(0, maxi(CROSS_HOLD_TAP, BRACE_HOLD) - CROSS_HOLD_TAP)}


## FJamButtonResolver::Press / Release (InputMapping.cpp:320-333) from the frame's raw keys.
func _press(key: String) -> void:
	for h: Dictionary in held:
		if h["key"] == key:
			if not bool(h["down"]):
				h["down"] = true
				h["new"] = true
				h["verb"] = ""
			return
	held.append({"key": key, "verb": "", "down": true, "new": true, "dead": false, "level_sent": false, "level_dropped": false, "steps": 0})


func _release(key: String) -> void:
	for h: Dictionary in held:
		if h["key"] == key:
			h["down"] = false


## FJamButtonResolver::Step (InputMapping.cpp:347-424), statement for statement.
func step_buttons(c: Dictionary) -> Dictionary:
	var out: Dictionary = {"bShootHeld": false, "bPassHeld": false, "bCheck": false, "bLift": false, "bCrossHeld": false}
	for h: Dictionary in held:
		var is_new: bool = bool(h["new"])
		if is_new:
			h["new"] = false
			h["dead"] = false
			h["level_sent"] = false
			h["level_dropped"] = false
			h["steps"] = 0
			var w: String = WITH.get(h["key"], "")
			var wo: String = WITHOUT.get(h["key"], "")
			h["verb"] = (w if w != "" else wo) if bool(c["with"]) else (wo if wo != "" else w)
			match String(h["verb"]):
				"Check":
					out["bCheck"] = true
				"CrossCheck":
					out["bLift"] = true
		elif bool(c["dead_across"]) and not bool(h["dead"]):
			match String(h["verb"]):
				"Shoot", "Pass":
					h["dead"] = not bool(c["with"])
				"CrossCheck":
					h["dead"] = bool(c["carrying"])
				"Check":
					h["dead"] = bool(c["with"])
		h["steps"] = int(h["steps"]) + 1
		var with_verb: bool = h["verb"] == "Shoot" or h["verb"] == "Pass"
		var level: bool = false
		if bool(h["dead"]):
			if with_verb and bool(h["down"]) and bool(h["level_sent"]) and not bool(h["level_dropped"]) and bool(c["in_reach"]):
				level = true
			else:
				h["level_dropped"] = true
		else:
			match String(h["verb"]):
				"Shoot":
					level = bool(h["down"]) or is_new
				"Pass":
					level = (bool(h["down"]) and int(h["steps"]) > int(c["saucer_delay"])) or (not bool(h["down"]) and not bool(h["level_sent"]))
				"CrossCheck":
					level = (bool(h["down"]) or is_new) and int(h["steps"]) > int(c["brace_delay"])
		if level:
			h["level_sent"] = true
			match String(h["verb"]):
				"Shoot":
					out["bShootHeld"] = true
				"Pass":
					out["bPassHeld"] = true
				"CrossCheck":
					out["bCrossHeld"] = true
	var keep: Array = []
	for h: Dictionary in held:
		if bool(h["down"]) or bool(h["new"]):
			keep.append(h)
	held = keep
	return out


## AHokejGameMode::ReadHumanInput (HokejGameMode.cpp:931-1000) on this frame's raw devices and the last sim frame.
## aim_pixel: TLInput.aim_pixel of the cursor (the anchor's still hand, kernel 1.17).
func read(r: Dictionary, snap: Dictionary, aim_pixel: Vector2) -> Dictionary:
	var me: int = int(snap["HumanIndex"])
	var s: Dictionary = snap["Skaters"][me]
	var down: PackedStringArray = r["Down"]
	var pressed: PackedStringArray = r["Pressed"]
	# the slot keys' events since the last step (UJamPlayerInput::OnSlotStarted / OnSlotDone -> Buttons.Press / Release)
	for k: String in SLOT_KEYS:
		if pressed.has(k):
			_press(k)
		if not down.has(k):
			_release(k)
	var inp: Dictionary = {}
	inp["Move"] = controls.move(r["Axis"], float(r["CameraYaw"]))                         # cpp:940-958
	var c: Dictionary = context(snap, me)
	var b: Dictionary = step_buttons(c)                                                     # ApplyButtons (InputMapping.cpp:488-503)
	inp["bShootHeld"] = b["bShootHeld"]
	inp["bPassHeld"] = b["bPassHeld"]
	inp["bCheck"] = b["bCheck"]
	inp["bLift"] = b["bLift"]
	inp["bCrossHold"] = bool(b["bCrossHeld"]) and int(snap["Carrier"]) != me
	inp["bBrake"] = down.has("LeftControl")                                                # cpp:963
	inp["bSprint"] = down.has("LeftShift")                                                 # cpp:964
	var stick: Vector2 = Vector2.ZERO                                                       # cpp:966-990: the cursor (no pad, the cursor shown)
	if bool(r["CursorOnIce"]):
		var hit: Vector2 = controls.anchor_step(aim_pixel, r["CursorHitM"], s["Pos"])
		stick = controls.stick(hit, s["Pos"])
	else:
		controls.anchor_reset()
	inp["Stick"] = stick
	inp["bPoke"] = pressed.has("SpaceBar")                                                 # cpp:992 ConsumePokePressed
	inp["bDeke"] = pressed.has("MouseScrollUp") or pressed.has("MouseScrollDown")          # cpp:994
	inp["bSpin"] = pressed.has("E")                                                        # cpp:995
	inp["bAbility"] = pressed.has("F")                                                     # cpp:996
	return inp
