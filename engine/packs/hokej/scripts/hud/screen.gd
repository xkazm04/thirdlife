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
		screen.view = Hud.new(screen.tl_hud.add_layer(&"hokej"), cart["game"], level, ctx.seed)
	var ui: Dictionary = ui_of(snap, human, last_in, last_raw)
	var head = screen.head_world(ctx, snap)
	if head != null:
		ui["head"] = head
	screen.view.frame(snap, ui)
	return screen


var figure                    # the human's figure: a node with thirdjam's sockets (K2's TLRigSkater body), found by its place
var figure_look: int = 0


## HumanHeadWorld (HUDWidget.cpp:1089-1131, jam.hud.MarkerAnchor 1): the figure's head_socket, lifted YouMarkerHeadLiftCm (-18 cm)
## along the head's own axis (the "head" bone to the socket); null without a figure that has sockets (the stand-in: its bounds).
## The figure is looked for every 60 frames (a mesh may arrive later), as thirdjam looks again at a bounds answer.
func head_world(ctx, snap: Dictionary):
	var me: Dictionary = snap["Skaters"][int(snap["HumanIndex"])]
	var p: Vector2 = me["Pos"]
	if (figure == null or not is_instance_valid(figure)) and figure_look % 60 == 0:
		figure = _find_figure(ctx.root, p)
	figure_look += 1
	if figure == null or not is_instance_valid(figure) or not figure.is_inside_tree():
		return null
	if Vector2(figure.global_position.x, figure.global_position.z).distance_to(p) > 1.5:
		figure = null                                            # not his (the figures were rebuilt): look again
		return null
	var sock: Transform3D = figure.socket_transform(&"head_socket")
	if sock == Transform3D.IDENTITY:
		return null
	var at: Vector3 = figure.global_transform * sock.origin
	var axis := Vector3.UP
	if figure.has_method("bone_transform"):
		var hb: Transform3D = figure.bone_transform(&"head")
		if hb != Transform3D.IDENTITY:
			var d: Vector3 = at - figure.global_transform * hb.origin
			if d.length() > 0.01:
				axis = d.normalized()
	return at + axis * (-0.18)                                     # YouMarkerHeadLiftCm (h:322)


static func _find_figure(root: Node, p: Vector2) -> Node3D:
	var best: Node3D = null
	var best_d: float = 1.5
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Node3D and n.has_method("socket_transform"):
			var g: Vector3 = (n as Node3D).global_position
			var d: float = Vector2(g.x, g.z).distance_to(p)
			if d < best_d:
				best_d = d
				best = n
		stack.append_array(n.get_children())
	return best


## What the buttons say this frame (UpdateControlsPanel's gathering, HUDControlsPanel.cpp:339-411), read from the core's glue:
## possession as the buttons read it (JamControls::HasPuckForButtons, computed in the glue: the snapshot's
## Controls.HasPuckForButtons, asked of lane K1; absent = false), the verbs the last step resolved (the FJamInput the human
## got, `last_in` = rink.last_human_input()), the keys down (`last_raw.Down`, Unreal key names) and the cross-check's hold
## (Controls.CrossHoldSteps). `_human` is unused (the shell has no button resolver of its own since the raw glue).
static func ui_of(snap: Dictionary, _human, last_in: Dictionary, last_raw: Dictionary) -> Dictionary:
	var me: int = int(snap["HumanIndex"])
	var ctl: Dictionary = snap.get("Controls", {})
	var with: bool = bool(ctl.get("HasPuckForButtons", false))
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
	var press: bool = not held.is_empty() or bool(last_in.get("bShoot", false)) or bool(last_in.get("bPass", false))   # bPress (cpp:378)
	# a two-role key down lights the verb it does now (cpp:379-385)
	for k: String in ["LeftMouseButton", "RightMouseButton", "Q", "MiddleMouseButton", "ThumbMouseButton"]:
		if down.has(k):
			press = true
			var v: String = ({"LeftMouseButton": "Shoot", "RightMouseButton": "Pass", "Q": "Pass"} if with else
				{"LeftMouseButton": "CrossCheck", "MiddleMouseButton": "CrossCheck", "ThumbMouseButton": "CrossCheck", "RightMouseButton": "Check"}).get(k, "")
			if v != "":
				held[v] = true
	for pair: Array in [["SpaceBar", "Poke"], ["E", "Spin"], ["F", "Ability"], ["LeftShift", "Sprint"], ["LeftControl", "Brake"]]:
		if down.has(pair[0]):
			held[pair[1]] = true
	if bool(last_in.get("bDeke", false)):
		held["Deke"] = true
	for k: String in ["W", "A", "S", "D", "Up", "Down", "Left", "Right"]:
		if down.has(k):
			held["Skate"] = true
	# the brace's word: the cross-check held BraceHoldFrames (13) steps (cpp:368); no SAUCER word (jam.hud.Words 1 with the pass's power on, cpp:366)
	var braced: bool = held.has("CrossCheck") and int(ctl.get("CrossHoldSteps", 0)) >= R.BRACE_HOLD_FRAMES
	var s: Dictionary = snap["Skaters"][me]
	# HumanStamina01 (HokejGameMode.cpp:1588): Stamina / StaminaFull, full = drain_frames x refill_frames (180 x 360, JamCartridge.h:81-82)
	var st: int = int(s.get("Stamina", -1))
	return {"with_puck": with, "held": held, "press": press, "saucer": false, "braced": braced, "paused": false,
		"stamina01": 1.0 if st < 0 else clampf(float(st) / float(180 * 360), 0.0, 1.0)}
