extends Node
## Primitive example: ball, contact damage and fracture. A light rubber ball bounces off a concrete wall and leaves
## it standing (its impulse is under the wall's threshold, which comes from the hardness of concrete). A heavy steel
## ball then breaks it: the wall's pieces wake as rigid bodies, settle, and are baked to static bodies.

var ctx
var wall: Node3D
var fracture: TLFracture
var light: TLBall
var heavy: TLBall
var light_bounces: int = 0
var broke_frame: int = -1
var settled_after: int = -1


func _pack_setup(c) -> void:
	ctx = c
	ctx.root.add_child(TLBodies.ground(Vector2(40, 40), "concrete"))
	wall = TLStandin.fracturable_wall(Vector3(4.0, 2.0, 0.4), 6, 3, "concrete")
	wall.position = Vector3(0, 0, -6)
	ctx.root.add_child(wall)
	fracture = TLFracture.attach(wall, {"hp": 100.0})
	fracture.broke.connect(func(_by: Node) -> void: broke_frame = ctx.frame)
	fracture.settled.connect(func(frames: int) -> void: settled_after = frames)
	light = TLBall.create({"radius": 0.11, "material": "rubber", "position": Vector3(-1, 1.0, 2), "name": "Light"})
	heavy = TLBall.create({"radius": 0.4, "material": "steel", "position": Vector3(1, 0.4, 6), "name": "Heavy"})
	ctx.root.add_child(light)
	ctx.root.add_child(heavy)
	light.bounced.connect(func(_other: Node, _speed: float) -> void: light_bounces += 1)
	ctx.cameras.add_view(&"side", Vector3(9, 4, 2), Vector3(0, 1, -5), 55.0)


func _pack_start() -> void:
	pass


func _pack_tick(frame: int) -> void:
	if frame == 30:
		light.shoot_at(Vector3(-1, 1.0, -6), 9.0)
	if frame == 180:
		heavy.shoot_at(Vector3(1, 0.8, -6), 12.0)


func _pack_state() -> Dictionary:
	return {"wall": String(fracture.state), "hp": fracture.damage.hp, "strongest_impulse": fracture.damage.last_impulse,
		"threshold": TLLaws.impact_threshold("concrete"), "light_bounces": light_bounces, "broke_frame": broke_frame,
		"settled_after": settled_after, "pieces": fracture.pieces.size(), "awake": fracture.awake_count(),
		"light_mass": light.mass, "heavy_mass": heavy.mass}
