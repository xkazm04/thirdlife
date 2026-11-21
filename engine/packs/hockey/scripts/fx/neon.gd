extends RefCounted
## All persistent actors and the cached venue keep their normal look between visits.
## Only the root of the scenery belongs to the transient arena; socket pieces and ribbons live elsewhere.
var art
var scenery: Node3D
var attachments: Array[Node3D] = []
var hidden: Array[Node3D] = []
var flashes: Dictionary = {}
var ribbons: Array[Node3D] = []
var trails_on := false
var flash_until := -1
var goals_seen := 0
var last_puck := Vector3.ZERO

func clear() -> void:
	for node: Node3D in attachments + ribbons:
		if is_instance_valid(node):
			node.free()
	for node: Node3D in hidden:
		if is_instance_valid(node):
			node.show()
	if is_instance_valid(scenery):
		scenery.free()
	attachments.clear()
	ribbons.clear()
	hidden.clear()
	flashes.clear()

func hide_for_match(node: Node3D) -> void:
	if is_instance_valid(node) and node.visible:
		node.hide()
		hidden.append(node)

func setup(g, cfg: Dictionary) -> void:
	art = g.ctx.load_script("gen/neon_hook.gd")
	scenery = Node3D.new()
	scenery.name = "GlowIce"
	g.arena.add_child(scenery)
	hide_for_match(g.dress_node)
	hide_for_match(g.puck.get_node_or_null("PuckRim"))
	var rink: Dictionary = g.tune["rink"]
	var half := Vector2(rink["half_length"], rink["half_width"])
	var gl: Dictionary = g.tune["goals"]
	art.arena(scenery, half, float(rink["corner_r"]), gl, str(cfg.get("accent", "window")), bool(cfg.get("lines", true)))
	for side: String in ["blue", "red"]:
		var key: String = art.HOME if side == "blue" else art.AWAY
		var frame_light: Node3D = art.net(scenery, float(gl["half_width"]), key, false)
		frame_light.position.x = float(gl[side][0])
		var flash: Node3D = art.net(scenery, float(gl["half_width"]), "nitro_core", true)
		flash.position = frame_light.position
		flash.hide()
		flashes[side] = flash
	attachments.append(art.puck(g.puck, float(g.tune["puck"]["radius"]) * float(g.tune["look"]["puck_scale"])))
	if bool(cfg.get("trim", true)):
		for id: String in g.order:
			var sk: TLBiped = g.skaters[id]
			if sk.rig != null:
				var key: String = art.HOME if g.teams[id] == "blue" else art.AWAY
				attachments.append(art.helmet(sk.rig.socket(&"head"), key))
				attachments.append(art.jacket(sk.rig.socket(&"back"), key))
	trails_on = bool(cfg.get("trails", true))
	if trails_on:
		start_trails(g)
		last_puck = g.puck.position

func start_trails(g) -> void:
	for id: String in g.order:
		var light := Color(0.0, 0.90, 1.0) if g.teams[id] == "blue" else Color(1.0, 0.025, 0.0)
		ribbons.append(TLVfx.trail(g.skaters[id], {"width": 0.41, "frames": 29, "color": light, "offset": Vector3(0, 0.19, 0.50)}))
	ribbons.append(TLVfx.trail(g.puck, {"width": 0.52, "frames": 37, "color": "white", "offset": Vector3(0, 0.12, 0)}))

func tick(g, scorer: String) -> void:
	var goals: int = g.rules.score("blue") + g.rules.score("red")
	var now: int = g.ctx.frame
	if goals > goals_seen:
		goals_seen = goals
		flash_until = now + 30
		flashes["red" if scorer == "blue" else "blue"].show()
	if flash_until >= 0 and now >= flash_until:
		flash_until = -1
		for flash: Node3D in flashes.values():
			flash.hide()
	# Discard history across a face-off so no ribbon spans the trip back to centre.
	if trails_on and last_puck.distance_squared_to(g.puck.position) > 16.0:
		for ribbon in ribbons:
			ribbon.free()
		ribbons.clear()
		start_trails(g)
	last_puck = g.puck.position
