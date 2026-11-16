extends Node
## Primitive example: the aim (K1). A skater stands on ice holding a stick; the stick turns, at most
## `turn_degrees_per_frame`, toward the aim: the point on the ice under the cursor (a bot sets it with
## ctx.input.set_aim). When the aim is invalid or sits on the figure, the stick keeps its heading.
## WASD moves the figure in interactive play.

var ctx
var skater: TLBiped
var pivot: Node3D
var data: Dictionary = {}
var heading: float = 0.0            # radians about +y; 0 faces -z
var target: float = 0.0             # where the aim asks the stick to point
var valid_frames: int = 0
var invalid_frames: int = 0
var dead_frames: int = 0            # the aim was valid but on the figure: no direction, heading held
var ticks: int = 0


func _pack_setup(c) -> void:
	ctx = c
	data = ctx.read_json("pointer.json")
	ctx.root.add_child(TLBodies.ground(Vector2(30, 30), "ice", 0.0, Vector3.ZERO))
	skater = TLBiped.create({"position": Vector3(0, 0.05, 0), "mode": "skate", "name": "Skater"})
	ctx.root.add_child(skater)
	pivot = Node3D.new()
	pivot.name = "StickPivot"
	ctx.root.add_child(pivot)
	var reach: float = float(data["stick_reach"])
	# the stick: a thin blade from the skater's side to `stick_reach` ahead, lying just above the ice
	pivot.add_child(TLBodies.make(&"box", Vector3(0.07, 0.05, reach - 0.45), "wood",
		{"position": Vector3(0, 0.06, -(0.45 + reach) * 0.5), "name": "Stick"}))
	ctx.input.declare_aim(&"aim", float(data["aim_height"]), float(data["aim_reach"]))
	for action: Array in [[&"forward", KEY_W], [&"back", KEY_S], [&"left", KEY_A], [&"right", KEY_D]]:
		ctx.input.declare(action[0], [action[1]])
	ctx.cameras.add_view(&"rink", Vector3(0, 12, 9), Vector3(0, 0, 0), 55.0)
	ctx.cameras.add_view(&"top", Vector3(0, 24, 0.01), Vector3(0, 0, 0), 60.0)


func _pack_start() -> void:
	pass


func _pack_tick(_frame: int) -> void:
	ticks += 1
	skater.drive_from_input(ctx.input, {"left": &"left", "right": &"right", "forward": &"forward", "back": &"back"})
	var at: Vector3 = skater.global_position
	pivot.position = Vector3(at.x, 0.0, at.z)
	var facing: Vector3 = Vector3(-sin(heading), 0.0, -cos(heading))
	var dir: Vector3 = ctx.input.aim_direction(&"aim", at, facing)
	if ctx.input.aim_valid(&"aim"):
		valid_frames += 1
		var off: Vector3 = ctx.input.aim(&"aim") - at
		off.y = 0.0
		if off.length() <= TLInput.AIM_DEAD:
			dead_frames += 1
	else:
		invalid_frames += 1
	if ctx.mode == "smoke" and ctx.input.aim_valid(&"aim"):
		# the proof of "no bot, no cursor: invalid on every frame": a smoke run fails on this error
		push_error("the aim is valid in a run without a bot or a cursor (frame %d)" % _frame)
	target = atan2(-dir.x, -dir.z)
	var step: float = deg_to_rad(float(data["turn_degrees_per_frame"]))
	heading = wrapf(heading + clampf(wrapf(target - heading, -PI, PI), -step, step), -PI, PI)
	pivot.rotation = Vector3(0.0, heading, 0.0)


func _pack_state() -> Dictionary:
	var p: Vector3 = ctx.input.aim(&"aim")
	return {"heading_deg": rad_to_deg(heading), "target_deg": rad_to_deg(target), "aim_valid": ctx.input.aim_valid(&"aim"),
		"aim_x": p.x, "aim_z": p.z, "skater_x": skater.global_position.x, "skater_z": skater.global_position.z,
		"valid_frames": valid_frames, "invalid_frames": invalid_frames, "dead_frames": dead_frames, "ticks": ticks}
