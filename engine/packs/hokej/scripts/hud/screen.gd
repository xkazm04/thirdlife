extends RefCounted
## The seam between the shell (main.gd, lane K3) and the screen (lane K5): ONE call a drawn frame,
##   screen = Screen.frame_of(screen, ctx, snap, human, last_in, last_raw)
## made in main.gd's _draw() in match mode. It makes the pack's TLHud and its painter layer on the first call, reads what the
## HUD's rules need from the buttons (UpdateControlsPanel's gathering, HUDControlsPanel.cpp:339-411) and hands the frame to
## hud.gd. Presentation only.

const Hud := preload("hud.gd")
const R := preload("rules.gd")

var tl_hud                 # TLHud
var view                   # hud.gd


static func frame_of(screen, ctx, snap: Dictionary, human, last_in: Dictionary, last_raw: Dictionary):
	if ctx.headless:
		return screen                  # nothing is drawn headless: the HUD (presentation only) costs a headless run nothing (tests/bot_hud_rules.gd drives its own)
	if screen == null:
		screen = new()
		screen.tl_hud = TLHud.create()
		ctx.root.add_child(screen.tl_hud)
		var cart: Dictionary = ctx.read_json("hockey.regular.cartridge.json")
		var level: String = String((ctx.read_json("match.json") as Dictionary).get("difficulty", "pro"))   # the level in force (match.json)
		screen.view = Hud.new(screen.tl_hud.add_layer(&"hokej"), cart["game"], level)
	screen.view.frame(snap, ui_of(snap, human, last_in, last_raw))
	return screen


## What the buttons say this frame: possession as the buttons read it, the verbs whose button is down, the holds' words.
static func ui_of(snap: Dictionary, human, last_in: Dictionary, last_raw: Dictionary) -> Dictionary:
	var me: int = int(snap["HumanIndex"])
	var with: bool = human.has_puck_for_buttons(snap, me) if human != null else false
	var down: PackedStringArray = last_raw.get("Down", PackedStringArray())
	var held: Dictionary = {}
	# the two-role buttons as the last step resolved them (JamControls::LastHumanButtons, cpp:361-365)
	if bool(last_in.get("bShootHeld", false)):
		held["Shoot"] = true
	if bool(last_in.get("bPassHeld", false)):
		held["Pass"] = true
	if bool(last_in.get("bCrossHold", false)) or bool(last_in.get("bLift", false)):
		held["CrossCheck"] = true
	if bool(last_in.get("bCheck", false)):
		held["Check"] = true
	# a two-role key down lights the verb it does now (cpp:380-385)
	for k: String in ["LeftMouseButton", "RightMouseButton", "Q", "MiddleMouseButton", "ThumbMouseButton"]:
		if down.has(k):
			var v: String = ({"LeftMouseButton": "Shoot", "RightMouseButton": "Pass", "Q": "Pass"} if with else
				{"LeftMouseButton": "CrossCheck", "MiddleMouseButton": "CrossCheck", "ThumbMouseButton": "CrossCheck", "RightMouseButton": "Check"}).get(k, "")
			if v != "":
				held[v] = true
	var press: bool = not held.is_empty()                                  # bPress (cpp:378-379)
	for pair: Array in [["SpaceBar", "Poke"], ["E", "Spin"], ["F", "Ability"], ["LeftShift", "Sprint"], ["LeftControl", "Brake"]]:
		if down.has(pair[0]):
			held[pair[1]] = true
	if bool(last_in.get("bDeke", false)):
		held["Deke"] = true
	for k: String in ["W", "A", "S", "D", "Up", "Down", "Left", "Right"]:
		if down.has(k):
			held["Skate"] = true
	# the brace's word: the cross-check key held BraceHoldFrames (cpp:368); no SAUCER word (jam.hud.Words 1 with the pass's power on, cpp:366)
	var braced: bool = false
	if human != null:
		for h: Dictionary in human.held:
			if String(h.get("verb", "")) == "CrossCheck" and bool(h.get("down", false)) and int(h.get("steps", 0)) >= R.BRACE_HOLD_FRAMES:
				braced = true
	var s: Dictionary = snap["Skaters"][me]
	# HumanStamina01 (HokejGameMode.cpp:1588): Stamina / StaminaFull, full = drain_frames x refill_frames (180 x 360, JamCartridge.h:81-82)
	var st: int = int(s.get("Stamina", -1))
	return {"with_puck": with, "held": held, "press": press, "saucer": false, "braced": braced, "paused": false,
		"stamina01": 1.0 if st < 0 else clampf(float(st) / float(180 * 360), 0.0, 1.0)}
