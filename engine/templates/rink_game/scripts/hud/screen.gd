extends RefCounted
## The seam between the shell (main.gd, lane K3) and the screen (lane K5): ONE call a drawn frame, ... [base README: scripts/hud/screen.gd §1]

const Hud := preload("hud.gd")
const R := preload("rules.gd")
const Kit := preload("kit.gd")
const PauseCard := preload("pausecard.gd")
const Front := preload("front.gd")
const GameSkin := preload("skin.gd")
## The level chosen on HOME is an input (a key-less action tapped for frame 0), so a run replays from its record alone.
const LEVEL_ACTIONS: Array = [&"level_rookie", &"level_pro", &"level_all_star"]
const LEVEL_IDS: Array = ["rookie", "pro", "all_star"]


## Called by the shell on frame 0 before the core's first step (main.gd _pack_tick): the level HOME ... [base README: scripts/hud/screen.gd §2]
static func start_level(ctx, core) -> String:
	for i: int in LEVEL_ACTIONS.size():
		if ctx.input.declared().has(String(LEVEL_ACTIONS[i])) and ctx.input.pressed(LEVEL_ACTIONS[i]):
			core.set_difficulty(LEVEL_IDS[i])
			core.reset(ctx.seed)
			ctx.root.set_meta(&"hokej_level", LEVEL_IDS[i])
			return LEVEL_IDS[i]
	return ""

## The level the shell applied this run (start_level's meta), else `fallback` (data/match.json's): the ... [base README: scripts/hud/screen.gd §3]
static func applied_level(ctx, fallback: String) -> String:
	if ctx.root != null and ctx.root.has_meta(&"hokej_level"):
		return String(ctx.root.get_meta(&"hokej_level"))
	return fallback

var tl_hud                 # TLHud
var view                   # hud.gd
var ctx_                   # the pack's context (the paused painter has no other door to it)
var kit                    # kit.gd
var card                   # pausecard.gd: thirdjam's pause card
var front                  # front.gd: thirdjam's title and HOME, before the match's frame 0
var last_snap: Dictionary = {}
var last_ui: Dictionary = {}
var was_paused: bool = false


## `head`: the human figure's head socket in the world this frame (K3's ... [base README: scripts/hud/screen.gd §4]
static func frame_of(screen, ctx, snap: Dictionary, human, last_in: Dictionary, last_raw: Dictionary, head = null):
	if ctx.frame == 0 and not ctx.input.declared().has(String(LEVEL_ACTIONS[0])):
		for a: StringName in LEVEL_ACTIONS:
			ctx.input.declare(a, [])                          # key-less: only HOME's PLAY NOW (or a bot) presses them
	if ctx.headless:
		return screen                  # nothing is drawn headless: the HUD (presentation only) costs a headless run nothing (tests/bot_hud_rules.gd drives its own)
	if screen == null:
		screen = new()
		screen.tl_hud = TLHud.create()
		ctx.root.add_child(screen.tl_hud)
		var mcfg: Dictionary = ctx.read_json("match.json")
		var cart: Dictionary = ctx.read_json(String(mcfg.get("cartridge", "hockey.regular.cartridge.json")))   # the cut in force (lane E1)
		var level: String = applied_level(ctx, String(mcfg.get("difficulty", "pro")))   # the level the shell applied, else match.json's
		var skin: Dictionary = GameSkin.of(ctx)                # the game's words and banks (data/skin.json, lane E1)
		screen.view = Hud.new(screen.tl_hud.add_layer(&"hokej"), cart["game"], level, ctx.seed, GameSkin.bark_rows(ctx, skin), skin, GameSkin.commentary_rows(ctx, skin))
		screen.ctx_ = ctx
		screen.kit = Kit.new(screen.view.lay)
		screen.card = PauseCard.new(screen.kit)
		screen.front = Front.new(screen.kit, level, skin)
		ctx.own_pause()                                   # thirdjam's pause card replaces the frame's (kernel 1.24)
		screen.tl_hud.on_paused(screen.paused_tick)
		if ctx.can_pause():                                # in the exe's dungeon: the title and HOME come before frame 0
			screen.front.up = true
			ctx.pause()
	var applied: String = applied_level(ctx, screen.view.cards.level_id)   # the card shows what the shell applied (a record's level action, frame 0)
	if applied != screen.view.cards.level_id:
		screen.view.cards.set_level(applied)
	var ui: Dictionary = ui_of(snap, human, last_in, last_raw)
	ui["pack_hint"] = str(ctx.root.get_meta(&"rink_hint", ""))   # lane H2b: a game's own hint line, drawn in the base's slot (hud/hint.gd)
	ui["top_view"] = ctx.cameras.active != null and ctx.cameras.active == ctx.cameras.view(&"top")   # lane H2b: the overview draws no rings
	var hw = screen.head_world(ctx, snap, head)
	if hw != null:
		ui["head"] = hw
		ui["bones"] = screen.bone_points()
	screen.view.frame(snap, ui)
	screen.last_snap = snap
	screen.last_ui = ui
	return screen


## One drawn frame while the kernel's frame holds the pack paused (TLHud.on_paused): the front end ... [base README: scripts/hud/screen.gd §5]
func paused_tick(_frame: int) -> void:
	var ks: PackedStringArray = ctx_.input.menu_keys()
	var lay = view.lay
	var ext: Vector2 = lay.extent()
	if front.up:
		var act: String = front.keys(ks)
		if act == "play":
			# PLAY NOW: the match at the lit level (ChooseCut -> OpenLevel with ?level=, MenuWidget.cpp:2138-2150)
			ctx_.input.tap(LEVEL_ACTIONS[LEVEL_IDS.find(front.level_id())])   # latched (and recorded) on frame 0; main.gd applies it
			view.cards.set_level(front.level_id())
			front.up = false
			was_paused = false
			ctx_.resume()
			return
		if act == "leave":
			ctx_.leave_game()
			return
		ctx_.cameras.screen_fade(0.0)                   # the menu is its own screen: the match's light hold starts with its frame 0
		lay.clear()
		front.paint(lay, ext.x, ext.y)
		return
	if not was_paused:
		card.open()
		was_paused = true
	var act2: String = card.keys(ks)
	if act2 == "resume" or act2 == "restart":
		if act2 == "restart":
			ctx_.input.tap(&"k_r")                       # RESTART: Resume, then RestartMatch (DirectorsCallController.cpp:257-261): the R key the glue restarts on
		was_paused = false
		ctx_.resume()
		return
	if act2 == "leave":
		ctx_.leave_game()
		return
	if last_snap.is_empty():
		return
	var ui: Dictionary = last_ui.duplicate()
	ui["paused"] = true
	view.frame(last_snap, ui)
	card.paint(lay, ext.x, ext.y, view.cards.take, view.cards.level)


var figure                    # the human's figure: a node with thirdjam's sockets (K2's TLRigSkater body), found by its place
var figure_look: int = 0


## HumanHeadWorld (HUDWidget.cpp:1089-1131, jam.hud.MarkerAnchor 1): the figure's head_socket, lifted ... [base README: scripts/hud/screen.gd §6]
func head_world(ctx, snap: Dictionary, given = null):
	var me: Dictionary = snap["Skaters"][int(snap["HumanIndex"])]
	var p: Vector2 = me["Pos"]
	if (figure == null or not is_instance_valid(figure)) and figure_look % 60 == 0:
		figure = _find_figure(ctx.root, p)
	figure_look += 1
	if figure == null or not is_instance_valid(figure) or not figure.is_inside_tree():
		return (given as Vector3) + Vector3.UP * (-0.18) if given is Vector3 else null   # the world's up where no head bone is known (h:316-321)
	if Vector2(figure.global_position.x, figure.global_position.z).distance_to(p) > 1.5:
		figure = null                                            # not his (the figures were rebuilt): look again
		return null
	var at: Vector3
	if given is Vector3:
		at = given                                                 # the shell's own socket point (match_view.head_world)
	else:
		var sock: Transform3D = figure.socket_transform(&"head_socket")
		if sock == Transform3D.IDENTITY:
			return null
		at = figure.global_transform * sock.origin
	var axis := Vector3.UP
	if figure.has_method("bone_transform"):
		var hb: Transform3D = figure.bone_transform(&"head")
		if hb != Transform3D.IDENTITY:
			var d: Vector3 = at - figure.global_transform * hb.origin
			if d.length() > 0.01:
				axis = d.normalized()
	return at + axis * (-0.18)                                     # YouMarkerHeadLiftCm (h:322)


## FigureBoxOnScreen's source 2 (HUDWidget.h:277-278, HUDClearDown.cpp): the figure's bones in the world (the skeleton's posed joints).
func bone_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	if figure == null or not is_instance_valid(figure) or not figure.has_method("skeleton"):
		return out
	var sk: Skeleton3D = figure.skeleton()
	if sk == null or not sk.is_inside_tree():
		return out
	for i: int in sk.get_bone_count():
		out.append(sk.global_transform * sk.get_bone_global_pose(i).origin)
	return out


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


## What the buttons say this frame (UpdateControlsPanel's gathering, HUDControlsPanel.cpp:339-411), ... [base README: scripts/hud/screen.gd §7]
static func ui_of(snap: Dictionary, _human, last_in: Dictionary, last_raw: Dictionary) -> Dictionary:
	var me: int = int(snap["HumanIndex"])
	var ctl: Dictionary = snap.get("Controls", {})
	var with: bool = bool(ctl.get("ButtonsWithPuck", false))
	var down: PackedStringArray = last_raw.get("Down", PackedStringArray())
	var held: Dictionary = {}
	if bool(last_in.get("bShootHeld", false)):   # the two-role buttons as the last step resolved them (JamControls::LastHumanButtons, cpp:361-365)
		held["Shoot"] = true
	if bool(last_in.get("bPassHeld", false)):
		held["Pass"] = true
	if bool(last_in.get("bCrossHold", false)) or bool(last_in.get("bLift", false)):
		held["CrossCheck"] = true
	if bool(last_in.get("bCheck", false)):
		held["Check"] = true
	var press: bool = not held.is_empty() or bool(last_in.get("bShoot", false)) or bool(last_in.get("bPass", false))   # bPress (cpp:378)
	for k: String in ["LeftMouseButton", "RightMouseButton", "Q", "MiddleMouseButton", "ThumbMouseButton"]:   # a two-role key down lights the verb it does now (cpp:379-385)
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
	return {"with_puck": with, "hit_pressed": bool(last_in.get("bCheck", false)) or bool(last_in.get("bLift", false)), "held": held, "press": press, "saucer": false, "braced": braced, "paused": false,
		"stamina01": 1.0 if st < 0 else clampf(float(st) / float(180 * 360), 0.0, 1.0)}
