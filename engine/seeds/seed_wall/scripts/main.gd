extends Node
## seed.wall: a walker throws heavy balls at a row of barrier blocks. Every piece of wall knocked out of its place
## is a point; reach score_to_win before the 60 second clock runs out (data/rules.json).
##
## Where things come from:
##   data/yard.json    the venue (tl.layout/1): terrain, the six blocks block_0..block_5, scenery, spawn, a camera
##   data/rules.json   TLRules config: score to win and the time limit
##   data/tuning.json  walker, balls, throw, how tough a block is
## The kernel does the work: TLBiped walks, TLBall.hold / release carries and throws, TLContact reports each impact
## to TLDamage, TLFracture breaks a block into the pieces the kit prepared, TLRules keeps score and clock.
## This script only wires them, and counts pieces. Signal handlers queue events; _pack_tick acts on them.

var ctx
var tune: Dictionary
var rules: TLRules
var hud: TLHud
var player: TLBiped
var cam: TLOrbitCam
var balls: Array = []                 # the pool of TLBall; the next one handed out is balls[next_ball]
var next_ball: int = 0
var in_hand: TLBall = null            # the ball the player carries, or null while reloading
var reload_frame: int = 0             # frame at which the next ball appears in the hands
var blocks: Array = []                # one {part: Node3D, fracture: TLFracture} per barrier block
var origin_of: Dictionary = {}        # piece (RigidBody3D) -> where it sat in the wall when its block broke
var down: Dictionary = {}             # pieces already counted as knocked down
var throws: int = 0
var hits: int = 0
var dust: Color = Color(0.78, 0.7, 0.62)
var _events: Array = []               # [kind, value] from signal handlers, handled in _pack_tick


func _pack_setup(c) -> void:
	ctx = c
	tune = ctx.read_json("tuning.json")
	var built: Dictionary = TLKit.build_layout(ctx.read_json("yard.json"), ctx.root)
	if not built["ok"]:
		push_error("yard.json does not build: %s" % "; ".join(built["errors"]))
		return
	var nodes: Dictionary = built["nodes"]

	# every layout prop called block_<n> is a fracturable kit part: give each its own TLFracture
	var wall: Dictionary = tune["wall"]
	var ids: Array = nodes.keys().filter(func(id: String) -> bool: return id.begins_with("block_") and not id.contains("."))
	ids.sort()
	for id: String in ids:
		# some blocks are tougher than others; which ones is decided by the run's seed (ctx.rng, never randf())
		var hp: float = float(wall["hp"]) * (1.0 + ctx.rng.randf_range(-1.0, 1.0) * float(wall["hp_spread"]))
		var fracture: TLFracture = TLFracture.attach(nodes[id], {"hp": hp, "threshold": float(wall["threshold"]),
			"kick": float(wall["kick"]), "scatter": float(wall["scatter"])})
		var index: int = blocks.size()
		fracture.broke.connect(func(_by: Node) -> void: _events.append(["broke", index]))
		blocks.append({"part": nodes[id], "fracture": fracture})

	# the walker: TLBiped builds the real biped rig; it starts at the layout's spawn point, facing the wall (-z)
	var opts: Dictionary = (tune["player"] as Dictionary).duplicate()
	opts.erase("_note")
	opts.merge({"position": (built["spawn"] as Transform3D).origin, "name": "Player"})
	player = TLBiped.create(opts)
	ctx.root.add_child(player)

	# the balls: kit balls made heavy. They wait in a row behind the player until they are handed out.
	var spec: Dictionary = tune["balls"]
	for i: int in int(spec["count"]):
		var ball: TLBall = TLBall.create({"part": TLKit.build("ball", {"radius": float(spec["radius"]), "color": str(spec["color"])}),
			"mass": float(spec["mass"]), "position": player.position + Vector3(-1.0 + 0.5 * i, 0.0, 3.0), "group": "balls", "name": "Ball%d" % i})
		ctx.root.add_child(ball)
		ball.bounced.connect(func(other: Node, speed: float) -> void:
			if ball != in_hand:           # a ball just taken back into the hands may still report its last touch
				_events.append(["hit", [ball.global_position, speed, other]]))
		balls.append(ball)

	rules = TLRules.create(ctx.read_json("rules.json"))
	ctx.root.add_child(rules)
	rules.finished.connect(func(_winner: String, reason: String) -> void: _events.append(["finished", reason]))
	hud = TLHud.create()
	ctx.root.add_child(hud)
	hud.add_score(rules, "player", &"top_left", "PIECES DOWN")
	hud.add_clock(rules, &"top")
	hud.add_label(&"hint", "WASD walk (Shift runs), Space throws where you face. %d pieces before the clock runs out." % rules.score_to_win, &"bottom")

	for action: Array in [[&"left", KEY_A], [&"right", KEY_D], [&"forward", KEY_W], [&"back", KEY_S], [&"run", KEY_SHIFT], [&"throw", KEY_SPACE]]:
		ctx.input.declare(action[0], [action[1]])
	cam = ctx.cameras.orbit(player, tune["camera"], &"player")       # behind and above the walker
	for view: String in built["cams"]:
		var v: Dictionary = built["cams"][view]
		ctx.cameras.add_view(StringName(view), v["pos"], v["look"], float(v["fov"]))


func _pack_start() -> void:
	rules.start()
	TLAudio.play(&"whistle")


func _pack_tick(frame: int) -> void:
	if rules.is_over():
		player.move(Vector3.ZERO)
	else:
		# walk relative to the camera: "forward" is away from it, toward the wall
		player.drive_from_input(ctx.input, {"left": &"left", "right": &"right", "forward": &"forward", "back": &"back", "run": &"run"}, cam.yaw_basis())
		if in_hand == null and frame >= reload_frame:
			_take_ball()
		elif in_hand != null and ctx.input.just_pressed(&"throw"):
			_throw(frame)
		_count_pieces_down()
	_handle_events()          # last, so what a signal queued this frame (a break, the end) is acted on this frame


## The next ball of the pool appears in front of the walker's chest (wherever it was lying) and is carried there.
func _take_ball() -> void:
	in_hand = balls[next_ball]
	next_ball = (next_ball + 1) % balls.size()
	var at: Array = tune["throw"]["carry_at"]
	in_hand.hold(player, Vector3(float(at[0]), float(at[1]), float(at[2])))
	player.rig.play(&"carry")


## Lets go of the ball along the way the walker faces, with a little lift so it arrives at chest height.
func _throw(frame: int) -> void:
	in_hand.release(player.forward() * float(tune["throw"]["speed"]) + Vector3.UP * float(tune["throw"]["lift"]))
	in_hand = null
	throws += 1
	reload_frame = frame + ctx.frames(float(tune["throw"]["reload_seconds"]))
	player.rig.play(&"")                                              # back to walking and standing


func _handle_events() -> void:
	for event: Array in _events:
		match event[0]:
			"broke":      # remember where every piece sat, then dust, debris and the crack
				var block: Dictionary = blocks[int(event[1])]
				var at: Vector3 = (block["part"] as Node3D).global_position + Vector3.UP
				for piece: RigidBody3D in (block["fracture"] as TLFracture).pieces:
					origin_of[piece] = piece.global_position
				TLVfx.burst(&"debris", at, ctx.root, {"color": dust.darkened(0.25)})
				TLVfx.burst(&"dust", at, ctx.root, {"scale": 1.6, "color": dust})
				TLAudio.play(&"break", at)
			"hit":        # a hard hit on the wall or its rubble: a puff of dust (the contact sound is the kernel's own)
				var other: Variant = event[1][2]
				if float(event[1][1]) > 6.0 and is_instance_valid(other) and blocks.any(func(b: Dictionary) -> bool: return (b["part"] as Node).is_ancestor_of(other)):
					hits += 1
					TLVfx.burst(&"dust", event[1][0], ctx.root, {"scale": 0.6, "color": dust})
			"finished":
				TLAudio.play(&"horn")
				hud.set_text(&"hint", "THE WALL IS DOWN" if event[1] == "score" else "TIME IS UP")
				player.rig.play(&"cheer" if event[1] == "score" else &"idle")
	_events.clear()


## A piece counts once, when it is more than `down_distance` from where it sat in the wall.
func _count_pieces_down() -> void:
	var fresh: int = 0
	for piece: RigidBody3D in origin_of:
		if not down.has(piece) and piece.global_position.distance_to(origin_of[piece]) > float(tune["wall"]["down_distance"]):
			down[piece] = true
			fresh += 1
	if fresh > 0:
		rules.add_score("player", fresh)


## What a bot (and the state hash) sees.
func _pack_state() -> Dictionary:
	var s: Dictionary = rules.snapshot()
	var f: Vector3 = player.forward()
	s["player"] = {"x": player.global_position.x, "z": player.global_position.z, "fx": f.x, "fz": f.z, "holding": in_hand != null}
	s["blocks"] = blocks.map(func(b: Dictionary) -> Dictionary:
		var p: Vector3 = (b["part"] as Node3D).global_position
		return {"x": p.x, "z": p.z, "state": String((b["fracture"] as TLFracture).state), "hp": (b["fracture"] as TLFracture).damage.hp})
	s["throws"] = throws
	s["hits"] = hits
	s["pieces_loose"] = origin_of.size()
	s["pieces_down"] = down.size()
	s["sounds"] = {"break": TLAudio.count(&"break"), "whistle": TLAudio.count(&"whistle"), "horn": TLAudio.count(&"horn")}
	s["hud"] = {"pieces": hud.text_of(&"score_player"), "clock": hud.text_of(&"clock"), "hint": hud.text_of(&"hint")}
	return s
