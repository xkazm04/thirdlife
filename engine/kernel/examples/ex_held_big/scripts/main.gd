extends Node
## Primitive example (K3): a ball is never a moving floor, held or loose, whatever the body's size. A skater with the
## hockey pack's body (rig and body scaled 2.2: a capsule of 0.66 m) stands still; a carrier node moves a held puck in a
## small circle under the rim of his body (0.14 m from his centre: the round bottom of a 0.66 m capsule rests on a 0.025 m
## puck up to 0.18 m out), then at tick 90 the puck is released at 25 m/s from under him, as a shot or a poke does.
## Measured: his top speed. A puck that acted as a floor hands him its own (contact) velocity when it leaves.

const SCALE: float = 2.2
const OFF: float = 0.14
var ctx
var carrier: Node3D
var puck: TLBall
var skater: TLBiped
var ticks: int = 0
var top_speed: float = 0.0
var top_speed_after: float = 0.0
var released_at: int = -1
var puck_peak: float = 0.0


func _pack_setup(c) -> void:
	ctx = c
	ctx.root.add_child(TLBodies.ground(Vector2(120, 40), "ice", 0.0, Vector3.ZERO))
	skater = TLBiped.create({"position": Vector3(0, 0.05, 0), "mode": "skate", "name": "Skater", "body_scale": SCALE})
	skater.rig.scale = Vector3(SCALE, SCALE, SCALE)
	ctx.root.add_child(skater)
	carrier = Node3D.new()
	carrier.name = "Carrier"
	carrier.position = Vector3(OFF, 0.0125, 0)
	ctx.root.add_child(carrier)
	puck = TLBall.create({"kind": &"puck", "material": "rubber", "position": Vector3(OFF, 0.0125, 0), "name": "Puck"})
	ctx.root.add_child(puck)
	puck.hold(carrier)
	ctx.cameras.add_view(&"side", Vector3(0, 5, 14), Vector3(0, 1, 0), 55.0)


func _pack_start() -> void:
	pass


func _pack_tick(_frame: int) -> void:
	ticks += 1
	skater.move(Vector3.ZERO)
	if ticks < 90:
		var a: float = float(ticks) * 0.35
		carrier.position = Vector3(OFF * cos(a), 0.0125, OFF * sin(a))     # a carried puck moved every frame (3 m/s)
	elif ticks == 90:
		puck.release(Vector3(25, 0, 6))
		released_at = ticks
	top_speed = maxf(top_speed, skater.speed())
	if released_at >= 0:
		top_speed_after = maxf(top_speed_after, skater.speed())
		puck_peak = maxf(puck_peak, puck.speed())


func _pack_state() -> Dictionary:
	return {"ticks": ticks, "top_speed": top_speed, "top_speed_after": top_speed_after, "released_at": released_at,
		"puck_peak": puck_peak, "skater_x": skater.global_position.x, "skater_z": skater.global_position.z,
		"skater_y": skater.global_position.y, "body_radius": skater.body_radius(), "skate_speed": skater.skate_speed}
