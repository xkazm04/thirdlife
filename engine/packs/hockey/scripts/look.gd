extends RefCounted
## L1: what a player reads from the play camera, kept out of main.gd (its 600-line limit). Created by main.gd, no
## class_name; g = main. The puck's drawn size, the rings under the skaters (his own; the carrier's), the HUD's lines
## for a newcomer (keys at the start, GOAL, play again), the arena's scoreboards showing the real score.
## Drawing and HUD text only: the rules read nothing here and _pack_state does not see it, so no result moves.

var cfg: Dictionary = {}               # data/tuning.json "look"
var ring_lib = null                    # gen/ring_hook.gd (meshes are made in a generator)
var touched: bool = false              # a person pressed a key or a button: the keys' lines go away
var goal_by: String = ""               # the side that scored last, shown during the pause after the goal
var seen: Dictionary = {}              # side -> the score the HUD last saw
var plated_hud = null                  # L2: the HUD whose labels were aligned (a new match makes a new HUD)
var plated: Dictionary = {}            # L2: widget id -> a plate is under it now (a plate only while there is a text)
const HAND: Array = [&"up", &"down", &"left", &"right", &"shoot", &"pass", &"poke", &"sprint", &"check", &"cross", &"dial"]


## The puck is drawn larger than its body (the body, and so the play, is unchanged) with a rim in a colour nothing
## else on the ice has: a dark dot of 0.24 m was 5 pixels from the play camera.
func dress_puck(g, part: Node3D, body: Node3D) -> void:
	var k: float = float(cfg["puck_scale"])
	part.scale = Vector3(k, float(cfg["puck_height_scale"]), k)
	var lib = _lib(g)
	if lib != null and float(cfg["puck_rim"]) > 0.0:
		var r: float = float(g.tune["puck"]["radius"]) * k
		lib.make_ring(body, r + float(cfg["puck_rim"]), float(cfg["puck_rim"]), str(cfg["puck_rim_key"]), "PuckRim", 0.015)


func _lib(g):
	if ring_lib == null and g.ctx.root.has_meta(&"hockey_ring"):
		ring_lib = g.ctx.load_script(str(g.ctx.root.get_meta(&"hockey_ring")))
	return ring_lib


## After every build: his reach ring (always there), a wider ring under whoever carries, the boards on this match.
func setup(g) -> void:
	var lib = _lib(g)
	if lib != null:
		for id: String in g.order:
			var sk: Node3D = g.skaters[id]
			var mine: bool = id == "b0"
			if mine and not sk.has_node("ReachRing"):
				lib.make_ring(sk, g.api.reach, float(g.tune["carry"]["ring_width"]), str(cfg["ring_key"]))
			if not sk.has_node("CarryRing") and (mine or bool(cfg["carrier_ring"])):
				var key: String = str(cfg["ring_key"]) if mine else str(cfg["team_keys"][str(g.teams[id])])
				var ring: Node3D = lib.make_ring(sk, g.api.reach, float(cfg["carry_width"]), key, "CarryRing", 0.025)
				ring.visible = false
			if not sk.has_node("DownRing") and float(cfg["down_ring"]) > 0.0:
				var dr: Node3D = lib.make_ring(sk, float(cfg["down_ring"]), 0.22, str(cfg["down_key"]), "DownRing", 0.035)    # L5: a man down reads as down
				dr.visible = false
	seen = {}
	goal_by = ""
	if g.dress_node != null:
		_bind(g.dress_node.find_child("scoreboard_w", true, false), g.rules)
		_bind(g.dress_node.find_child("scoreboard_e", true, false), g.rules)


## The kit's scoreboard draws fixed digits; bound to the rules it shows the score (KIT.md). A new match has new rules.
func _bind(board: Node, rules: TLRules) -> void:
	if board == null:
		return
	var old: Node = board.get_node_or_null("ScoreFace")
	if old != null:
		board.remove_child(old)
		old.queue_free()
	TLKitSite.bind_scoreboard(board as Node3D, rules)


func hud_lines(g) -> void:
	g.hud.add_bound(&"result", func() -> String: return center_text(g), &"center")
	g.hud.add_bound(&"keys", func() -> String: return keys_text(g), &"top")


## The keys, three lines in one label, until his first input (not while a bot-only match runs, not after the end).
func keys_text(g) -> String:
	if g.intro.active:
		return g.intro.text(g)               # L5: the first-minute drill's one line instead
	return "" if touched or g.autopilot or g.result != "" else "\n".join(PackedStringArray(cfg["keys"]))


## L2 (kernel API 1.5): a plate under every text that lies on the picture, only while it has a text (an empty
## plate is a dark pill on the ice); lines centred in the keys and the result, the dial's lines left. The dial and
## the rule line are main.gd's widgets: they exist by the first tick, so this runs from tick().
func plates(g) -> void:
	if plated_hud != g.hud:
		plated_hud = g.hud
		plated = {}
		g.hud.set_align(&"keys", &"center")
		g.hud.set_align(&"result", &"center")
	var want: Dictionary = {&"keys": keys_text(g) != "", &"result": center_text(g) != "", &"dial": g.dial_open, &"rule": g.rule_line != "", &"game": not g.menu_lib.open}
	for id: StringName in want:
		if bool(want[id]) != bool(plated.get(id, false)):
			plated[id] = want[id]
			g.hud.set_plate(id, bool(want[id]))


func center_text(g) -> String:
	if g.fun != null:
		return g.fun.card(g)                 # L5: the goal card and the match-end card (scripts/fun/fun.gd)
	if g.result != "":
		return "%s\n%s" % [g.result, str(cfg["again"])]
	if g.reset_in > 0 and goal_by != "":
		return str(cfg["goal"]) % goal_by.to_upper()
	return ""


func tick(g) -> void:
	plates(g)
	if not touched and not g.autopilot:
		for a: StringName in HAND:
			if g.ctx.input.pressed(a):
				touched = true
	for side: String in g.tune["rules"]["sides"]:
		var now: int = g.rules.score(side)
		if now > int(seen.get(side, 0)):
			goal_by = side
		seen[side] = now
	var c: String = g.api.carrier
	if g.ctx.headless:
		return                               # the rings are drawing only: no picture, no work (budget: frame p50)
	for id: String in g.order:
		var dring: Node3D = (g.skaters[id] as Node3D).get_node_or_null("DownRing") as Node3D
		if dring != null:
			dring.visible = (g.skaters[id] as TLBiped).is_down()
		var ring: Node3D = (g.skaters[id] as Node3D).get_node_or_null("CarryRing") as Node3D
		if ring != null:
			# H9a: the human's carry ring at once; another carrier's only after carrier_ring_after_frames of holding, so a
			# puck traded by pokes on one spot (8 times in 110 frames, lane L) does not make a ring jump between figures
			ring.visible = id == c and (id == "b0" or g.api._now - int(g.api.carry_since) >= int(cfg["carrier_ring_after_frames"]))
