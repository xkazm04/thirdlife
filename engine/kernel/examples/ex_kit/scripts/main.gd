extends Node
## Integration example: the kit (TLKit), the rigs (TLRigs) and the kernel in one pack. Four lanes:
##   ice     a kit ball on a kit ice patch slides by the law table (rubber on ice 0.10)
##   wall    a kit barrier_wall and a kit crate break, sleep and are baked through TLFracture
##   biped   TLBiped with the real biped rig walks on kit concrete; a second one skates on kit ice
##   car     TLVehicle with the real vehicle rig drives on kit asphalt; steering right turns the wheels right
## Nothing here is driven by input: the script gives intents on fixed frames and the bot only measures.

var ctx
var cfg: Dictionary
var ball: TLBall
var ball_x0: float = 0.0
var wall_f: TLFracture
var crate_f: TLFracture
var shot_wall: TLBall
var shot_crate: TLBall
var walker: TLBiped
var skater: TLBiped
var car: TLVehicle
var plain_walker: TLBiped             # the fallback: the same controllers on the kernel's stand-in rigs
var plain_car: TLVehicle
var plain_walk_top: float = 0.0
var plain_car_top: float = 0.0
var kit_bodies: int = 0
var leg_min: float = 9.0
var leg_max: float = -9.0
var walk_top: float = 0.0
var skate_top: float = 0.0
var skate_coast: float = 0.0
var car_top: float = 0.0
var spin_seen: float = 0.0
var steer_wheel_yaw: float = 0.0
var steer_turn: float = 0.0
var _heading0: Vector3 = Vector3.ZERO


func _patch(surface: String, size: Vector2, at: Vector3) -> void:
	var p: Node3D = TLKit.build("ground_patch", {"size_x": size.x, "size_z": size.y, "surface": surface})
	p.position = at
	ctx.root.add_child(p)


func _pack_setup(c) -> void:
	ctx = c
	cfg = ctx.read_json("kit.json")
	# --- ice lane (z = 0): the kit ball becomes a TLBall body; `planar` keeps it from rolling, so it slides
	_patch("ice", Vector2(30, 6), Vector3(12, 0, 0))
	ball = TLBall.create({"part": TLKit.build("ball", {}), "planar": true, "position": Vector3(0, 0.11, 0), "name": "KitBall"})
	ctx.root.add_child(ball)
	# --- wall lane (z = -14)
	_patch("concrete", Vector2(24, 12), Vector3(2, 0, -14))
	var wall: Node3D = TLKit.build("barrier_wall", {"blocks": int(cfg["wall"]["blocks"]), "cells": int(cfg["wall"]["cells"])})
	wall.position = Vector3(0, 0, -17)
	ctx.root.add_child(wall)
	wall_f = TLFracture.attach(wall, {"hp": 100.0})
	var crate: Node3D = TLKit.build("crate", {"size": float(cfg["crate"]["size"]), "cells": int(cfg["crate"]["cells"])})
	crate.position = Vector3(7, 0, -17)
	ctx.root.add_child(crate)
	crate_f = TLFracture.attach(crate, {"hp": 100.0})
	shot_wall = TLBall.create({"radius": 0.4, "material": "steel", "position": Vector3(0, 0.4, -10), "drag": 0.6, "name": "ShotWall"})
	shot_crate = TLBall.create({"radius": 0.2, "material": "steel", "position": Vector3(7, 0.2, -10), "drag": 0.6, "name": "ShotCrate"})
	# a plain kernel body behind the lane, so the shots stay on the patch after they went through
	ctx.root.add_child(TLBodies.make(&"box", Vector3(24, 2.4, 0.5), "concrete", {"position": Vector3(2, 1.2, -19.7), "name": "Backstop"}))
	ctx.root.add_child(shot_wall)
	ctx.root.add_child(shot_crate)
	# --- biped lane (z = -28 concrete, z = -34 ice): no `rig` option, so the controller asks TLRigs
	_patch("concrete", Vector2(30, 5), Vector3(0, 0, -28))
	_patch("ice", Vector2(90, 5), Vector3(30, 0, -34))
	walker = TLBiped.create({"position": Vector3(-10, 0.05, -28), "facing": -PI * 0.5, "name": "Walker"})
	skater = TLBiped.create({"mode": "skate", "position": Vector3(-10, 0.05, -34), "facing": -PI * 0.5, "name": "Skater"})
	ctx.root.add_child(walker)
	ctx.root.add_child(skater)
	# --- car lane (z = -46)
	_patch("asphalt", Vector2(160, 40), Vector3(50, 0, -58))
	car = TLVehicle.create({"position": Vector3(-20, 0.1, -50), "facing": -PI * 0.5, "name": "Car"})
	ctx.root.add_child(car)
	# --- the fallback still works: a stand-in rig given by hand (what the kernel builds when TLRigs is absent)
	plain_walker = TLBiped.create({"rig": TLStandin.standin_rig(&"biped"), "position": Vector3(-10, 0.05, -29.5), "facing": -PI * 0.5, "name": "PlainWalker"})
	plain_car = TLVehicle.create({"rig": TLStandin.standin_rig(&"vehicle"), "position": Vector3(-20, 0.1, -66), "facing": -PI * 0.5, "name": "PlainCar"})
	ctx.root.add_child(plain_walker)
	ctx.root.add_child(plain_car)
	for b: Node in ctx.root.find_children("*", "StaticBody3D", true, false):
		if b.has_meta(&"tl_material"):
			kit_bodies += 1
	ctx.cameras.add_view(&"ice", Vector3(2.5, 1.6, 4.5), Vector3(2.5, 0.1, 0), 45.0)
	ctx.cameras.add_view(&"wall", Vector3(8, 3.5, -9), Vector3(2.5, 0.6, -17), 50.0)
	ctx.cameras.add_view(&"walker", Vector3(-4.5, 1.6, -23.5), Vector3(-5.5, 1.0, -28), 45.0)
	ctx.cameras.chase(skater, {"distance": 5.0, "height": 2.0, "look_height": 1.1}, &"skater")
	ctx.cameras.chase(car, {"distance": 7.5, "height": 2.6, "look_height": 0.8}, &"car")


func _pack_start() -> void:
	pass


func _pack_tick(frame: int) -> void:
	if frame == int(cfg["ice"]["push_frame"]):
		ball_x0 = ball.global_position.x
		ball.shoot(Vector3(ball.mass * float(cfg["ice"]["start_speed"]), 0, 0))
	if frame == int(cfg["wall"]["shot_frame"]):
		shot_wall.shoot_at(Vector3(0, 0.5, -17), float(cfg["wall"]["shot_speed"]))
		shot_crate.shoot_at(Vector3(7, 0.5, -17), float(cfg["crate"]["shot_speed"]))
	# bipeds: go along +x; the skater thrusts for two seconds and then coasts
	var go: bool = frame >= int(cfg["biped"]["go_frame"])
	walker.move(Vector3.RIGHT if go and walker.global_position.x < 8.0 else Vector3.ZERO)
	skater.move(Vector3.RIGHT if go and frame < int(cfg["biped"]["coast_frame"]) else Vector3.ZERO)
	plain_walker.move(Vector3.RIGHT if go and plain_walker.global_position.x < 8.0 else Vector3.ZERO)
	plain_walk_top = maxf(plain_walk_top, plain_walker.speed())
	walk_top = maxf(walk_top, walker.speed())
	skate_top = maxf(skate_top, skater.speed())
	if frame == int(cfg["biped"]["coast_frame"]) + 120:
		skate_coast = skater.speed()
		skater.brake(true)                  # measured: now stop before the ice ends
	var sk: Skeleton3D = _skeleton(walker.rig)
	if sk != null:
		var q: Quaternion = sk.get_bone_pose_rotation(sk.find_bone("LeftUpperLeg"))
		leg_min = minf(leg_min, q.x)
		leg_max = maxf(leg_max, q.x)
	# car: full throttle, then a right turn at part throttle, then the brake
	var steer_at: int = int(cfg["car"]["steer_frame"])
	var brake_at: int = int(cfg["car"]["brake_frame"])
	if frame < int(cfg["car"]["go_frame"]):
		car.set_controls(0.0, 0.0)
	elif frame < steer_at:
		car.set_controls(0.0, 1.0)
	elif frame < brake_at:
		if frame == steer_at:
			_heading0 = car.forward()
		car.set_controls(0.4, 0.2)
		var pivot: Node3D = car.rig.get_node_or_null("WheelFL") as Node3D
		if pivot != null:
			steer_wheel_yaw = pivot.rotation.y
		steer_turn = _heading0.cross(car.forward()).y      # negative = turned right (clockwise seen from above)
	else:
		car.set_controls(0.0, 0.0, 1.0)
	plain_car.set_controls(0.0, 1.0 if frame >= int(cfg["car"]["go_frame"]) and frame < steer_at else 0.0, 0.0 if frame < steer_at else 1.0)
	plain_car_top = maxf(plain_car_top, plain_car.speed())
	car_top = maxf(car_top, car.speed())
	var spin: Node3D = car.rig.get_node_or_null("WheelRL/Spin") as Node3D
	if spin != null:
		spin_seen = maxf(spin_seen, absf(spin.rotation.x))


func _skeleton(rig: Node) -> Skeleton3D:
	var found: Array = rig.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null


func _pack_state() -> Dictionary:
	var wm: Dictionary = walker.rig.metrics()
	var cm: Dictionary = car.rig.metrics()
	return {
		"ice": {"distance": ball.global_position.x - ball_x0, "speed": ball.speed(), "surface": ball.surface(), "mass": ball.mass,
			"material": ball.material_id, "law_friction": float(TLLaws.pair(ball.material_id, "ice")["friction"])},
		"kit_bodies_tagged": kit_bodies,
		"wall": {"state": String(wall_f.state), "pieces": wall_f.pieces.size(), "awake": wall_f.awake_count(), "impulse": wall_f.damage.last_impulse},
		"crate": {"state": String(crate_f.state), "pieces": crate_f.pieces.size(), "awake": crate_f.awake_count(), "impulse": crate_f.damage.last_impulse},
		"walker": {"x": walker.global_position.x, "top": walk_top, "surface": walker.surface, "rig_family": String(walker.rig.family),
			"standin": walker.rig is TLStandinRig, "bones": int(wm.get("bones", 0)), "height": float(wm["height"]),
			"leg_swing": leg_max - leg_min if leg_max >= leg_min else 0.0},
		"skater": {"x": skater.global_position.x, "top": skate_top, "coast": skate_coast, "surface": skater.surface, "mode": String(skater.mode)},
		"standin": {"walker_is_standin": plain_walker.rig is TLStandinRig, "walk_top": plain_walk_top,
			"car_is_standin": plain_car.rig is TLStandinRig, "car_top": plain_car_top, "car_speed": plain_car.speed()},
		"car": {"x": car.global_position.x, "top": car_top, "speed": car.speed(), "standin": car.rig is TLStandinRig, "mass": car.mass,
			"wheelbase": float(cm["wheelbase"]), "wheel_spin_seen": spin_seen, "steer_wheel_yaw": steer_wheel_yaw, "steer_turn": steer_turn,
			"surface": car.wheel_surface[0], "grounded_wheels": car.grounded_wheels()},
	}
