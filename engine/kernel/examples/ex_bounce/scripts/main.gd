extends Node
## Primitive example: ball restitution by the law tables, a spawner, a trigger and a score.
## Left: four balls are dropped from the same height onto four pads; how high each comes back depends only on the
## pair law (restitution of the two materials added up, or the override in surfaces.json). The first bounce counts:
## the ball's contact tracker looks ahead, so the pair law is already in force when the ball first touches.
## Right: a spawner drops plastic balls (positions from ctx.rng) down a chute into a bin; a trigger scores each one
## and the rules end the game at five.

var ctx
var data: Dictionary = {}
var drops: Array = []            # {name, ball, pad_top, min_seen, bounced, peak}
var rules: TLRules
var spawner: TLSpawner
var bin_trigger: TLTrigger


func _pack_setup(c) -> void:
	ctx = c
	data = ctx.read_json("bounce.json")
	ctx.root.add_child(TLBodies.ground(Vector2(40, 30), "concrete"))
	var x: float = -9.0
	for pad: Dictionary in data["pads"]:
		ctx.root.add_child(TLBodies.make(&"box", Vector3(1.5, 0.4, 1.5), str(pad["pad"]), {"position": Vector3(x, 0.2, 0)}))
		var ball: TLBall = TLBall.create({"radius": float(data["ball_radius"]), "material": str(pad["ball"]),
			"position": Vector3(x, 0.4 + float(data["ball_radius"]) + float(data["drop_height"]), 0), "name": str(pad["name"])})
		ctx.root.add_child(ball)
		ball.bounced.connect(_on_bounced.bind(drops.size()))
		drops.append({"name": str(pad["name"]), "ball": ball, "floor": 0.4 + float(data["ball_radius"]), "bounced": false, "peak": 0.0,
			"law": float(TLLaws.pair(str(pad["ball"]), str(pad["pad"]))["restitution"])})
		x += 2.5
	# the bin: three low walls and a trigger inside
	for wall: Array in [[Vector3(3, 1, 0.2), Vector3(8, 0.5, 1.5)], [Vector3(3, 1, 0.2), Vector3(8, 0.5, -1.5)], [Vector3(0.2, 1, 3), Vector3(9.5, 0.5, 0)],
			[Vector3(0.2, 1, 3), Vector3(6.5, 0.5, 0)]]:
		ctx.root.add_child(TLBodies.make(&"box", wall[0], "wood", {"position": wall[1]}))
	bin_trigger = TLBodies.trigger(&"box", Vector3(2.8, 0.6, 2.8), {"position": Vector3(8, 0.3, 0), "group_filter": "pellets", "name": "Bin"})
	ctx.root.add_child(bin_trigger)
	bin_trigger.entered.connect(_on_binned)
	rules = TLRules.create(data["rules"])
	ctx.root.add_child(rules)
	var so: Dictionary = (data["spawner"] as Dictionary).duplicate()
	so["points"] = [Vector3(0, 0, 0)]
	so["jitter"] = Vector3(1.0, 0.0, 1.0)
	spawner = TLSpawner.create(_make_pellet, so)
	spawner.position = Vector3(8, 4, 0)
	ctx.root.add_child(spawner)
	ctx.cameras.add_view(&"front", Vector3(0, 4, 16), Vector3(0, 1, 0), 55.0)


func _make_pellet() -> Node3D:
	return TLBall.create({"radius": 0.15, "material": "plastic", "group": "pellets"})


func _on_bounced(_other: Node, _speed: float, index: int) -> void:
	drops[index]["bounced"] = true


func _on_binned(_body: Node3D) -> void:
	rules.add_score("bin")


func _pack_start() -> void:
	rules.start()


func _pack_tick(_frame: int) -> void:
	for d: Dictionary in drops:
		if d["bounced"]:
			d["peak"] = maxf(float(d["peak"]), (d["ball"] as TLBall).global_position.y - float(d["floor"]))


func _pack_state() -> Dictionary:
	var s: Dictionary = rules.snapshot()
	s["spawned"] = spawner.total
	s["alive"] = spawner.alive().size()
	s["drop_height"] = float(data["drop_height"])
	for d: Dictionary in drops:
		s[d["name"]] = {"rebound": float(d["peak"]), "law": float(d["law"]), "moving": (d["ball"] as TLBall).is_moving()}
	return s
