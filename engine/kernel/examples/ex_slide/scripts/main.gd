extends Node
## Law example: four flat blocks are pushed to the same speed along four lanes. How far each slides depends only on
## the law tables: friction of the pair (materials.json), with the pairwise overrides of surfaces.json for rubber.
## "track": true bodies carry a TLContact (they follow pairwise overrides); "track": false bodies are plain tagged
## bodies and get the default pair law (the lower friction) from the physics engine.

var ctx
var lanes: Array = []
var start_speed: float = 3.0


func _pack_setup(c) -> void:
	ctx = c
	var data: Dictionary = ctx.read_json("slide.json")
	start_speed = float(data["start_speed"])
	var z: float = 0.0
	for lane: Dictionary in data["lanes"]:
		ctx.root.add_child(TLBodies.make(&"box", Vector3(60, 1, 3), str(lane["surface"]), {"position": Vector3(25, -0.5, z)}))
		var block: PhysicsBody3D = TLBodies.make(&"box", Vector3(1.0, 0.3, 1.0), str(lane["slider"]),
			{"dynamic": true, "position": Vector3(0, 0.16, z), "track": bool(lane["track"]), "name": str(lane["name"])})
		ctx.root.add_child(block)
		lanes.append({"name": str(lane["name"]), "slider": str(lane["slider"]), "surface": str(lane["surface"]), "body": block, "x0": 0.0})
		z += 4.0
	ctx.cameras.add_view(&"lanes", Vector3(8, 9, 24), Vector3(8, 0, 6), 50.0)


func _pack_start() -> void:
	pass


func _pack_tick(frame: int) -> void:
	if frame == 30:      # the blocks have settled on their lanes: push them all to the same speed
		for lane: Dictionary in lanes:
			var body: RigidBody3D = lane["body"]
			lane["x0"] = body.global_position.x
			TLBodies.push(body, Vector3(body.mass * start_speed, 0, 0))


func _pack_state() -> Dictionary:
	var out: Dictionary = {"start_speed": start_speed}
	for lane: Dictionary in lanes:
		var body: RigidBody3D = lane["body"]
		out[lane["name"]] = {"distance": body.global_position.x - float(lane["x0"]), "speed": body.linear_velocity.length(),
			"law_friction": float(TLLaws.pair(lane["slider"], lane["surface"])["friction"])}
	return out
