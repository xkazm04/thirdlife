extends Node
## seed.drive: one car on a small road loop. Three laps before the clock runs out (data/rules.json). Four
## checkpoints per lap must be passed in order; a pad on the near straight fills the nitro tank; loose cones stand
## on the road and come back after a while.
##
## Where things come from:
##   data/track.json   the venue (tl.layout/1): terrain, the road loop `loop`, the pad strip `pad`, scenery, a camera
##   data/rules.json   TLRules config: laps, checkpoints per lap, the time limit
##   data/tuning.json  where the car starts, where checkpoints and cones are, car tuning
## The road gives the script its centre line (metadata tl_centre_line: a point every 2 m). Everything on the road is
## placed from it with _road(s, off), so moving the control points in track.json moves the whole game with it.

var ctx
var tune: Dictionary
var rules: TLRules
var hud: TLHud
var car: TLVehicle
var cones: TLSpawner
var line: PackedVector3Array           # the centre line of the loop, in driving order
var length: float = 0.0                # metres round the loop
var ahead: Vector3 = Vector3.ZERO      # a point on the centre line a little ahead of the car: where to steer
var far: Vector3 = Vector3.ZERO        # the point the car reaches in `far_seconds` at its speed: when to slow down
var off_line: float = 0.0              # how far the car is from the centre line
var pad_visits: int = 0
var nitro_starts: int = 0
var cone_hits: int = 0
var top_speed: float = 0.0
var _on_pad: bool = false              # flag from the pad trigger


func _pack_setup(c) -> void:
	ctx = c
	tune = ctx.read_json("tuning.json")
	var built: Dictionary = TLKit.build_layout(ctx.read_json("track.json"), ctx.root)
	if not built["ok"]:
		push_error("track.json does not build: %s" % "; ".join(built["errors"]))
		return
	var road: Node3D = built["nodes"]["loop"]
	line = road.get_meta(&"tl_centre_line")
	length = float(road.get_meta(&"tl_length"))
	var half_width: float = float(road.get_meta(&"tl_half_width"))

	# the car: TLVehicle builds the real coupe rig; tuning members come straight from data
	var start: Transform3D = _road(float(tune["start_s"]))
	var opts: Dictionary = (tune["car"] as Dictionary).duplicate()
	opts.erase("_note")
	opts.merge({"position": start.origin + Vector3(0, 0.1, 0), "facing": start.basis.get_euler().y, "name": "Car",
		"rig_params": {"colors": tune["car_colors"]}})
	car = TLVehicle.create(opts)
	ctx.root.add_child(car)
	car.nitro_charge = 0.0                                   # empty until the pad
	car.nitro_started.connect(func() -> void: nitro_starts += 1)
	car.nitro_started.connect(func() -> void: ctx.cameras.shake(0.06, 18))        # the kick of the nitro (visual only)
	car.contact.hit.connect(_on_car_hit)

	# rules, and one round trigger per checkpoint. TLRules counts a checkpoint only in order.
	rules = TLRules.create(ctx.read_json("rules.json"))
	ctx.root.add_child(rules)
	var shares: Array = tune["checkpoints"]["at"]
	for i: int in shares.size():
		var gate: TLTrigger = TLBodies.trigger(&"sphere", half_width + float(tune["checkpoints"]["margin"]),
			{"position": _road(float(shares[i]) * length).origin + Vector3(0, 1, 0), "name": "Checkpoint%d" % i})
		ctx.root.add_child(gate)
		gate.entered.connect(_on_checkpoint.bind(i))

	# the nitro pad: a trigger where the layout put the strip called `pad`
	var pad: TLTrigger = TLBodies.trigger(&"sphere", float(tune["pad_radius"]),
		{"position": (built["nodes"]["pad"] as Node3D).global_position + Vector3(0, 1, 0), "name": "NitroPad"})
	ctx.root.add_child(pad)
	pad.entered.connect(_on_pad_entered)

	# cones: a spawner keeps one at each point and replaces each after `respawn_seconds` (a knocked-over cone returns)
	var points: Array = []
	for cone: Dictionary in tune["cones"]["at"]:
		points.append(_road(float(cone["s"]), float(cone["off"])).origin + Vector3(0, 0.05, 0))
	var jitter: float = float(tune["cones"]["jitter"])
	cones = TLSpawner.create(_loose_cone, {"points": points, "every_frames": 1, "max_alive": points.size(), "jitter": Vector3(jitter, 0, jitter),
		"lifetime_frames": ctx.frames(float(tune["cones"]["respawn_seconds"])), "name": "Cones"})
	ctx.root.add_child(cones)

	hud = TLHud.create()
	ctx.root.add_child(hud)
	hud.add_clock(rules, &"top")
	hud.add_bound(&"laps", func() -> String: return "LAP %d / %d" % [mini(int(rules.laps["car"]) + 1, rules.laps_to_win), rules.laps_to_win], &"top_left")
	hud.add_bound(&"nitro", func() -> String: return "NITRO %d%%" % int(car.nitro_charge * 100.0), &"bottom_left")
	hud.add_speed(car.speed_kmh, "km/h", &"bottom_right")
	hud.add_label(&"hint", "A / D steer, W gas, S reverse, Space brake, Shift nitro (fill it at the striped pad)", &"bottom")
	rules.finished.connect(func(winner: String, reason: String) -> void:
		hud.set_text(&"hint", "THREE LAPS DONE" if winner == "car" else "OUT OF TIME (%s)" % reason))

	for action: Array in [[&"left", KEY_A], [&"right", KEY_D], [&"gas", KEY_W], [&"reverse", KEY_S], [&"brake", KEY_SPACE], [&"nitro", KEY_SHIFT]]:
		ctx.input.declare(action[0], [action[1]])
	ctx.cameras.chase(car, {"distance": 8.5, "height": 3.0, "look_height": 1.1, "fov": 58.0})        # the view "chase"
	ctx.cameras.frame(car, 0.2)                                                          # the car covers a fifth of the frame height
	for cam: String in built["cams"]:
		var v: Dictionary = built["cams"][cam]
		ctx.cameras.add_view(StringName(cam), v["pos"], v["look"], float(v["fov"]))


## A place on the road: `s` metres along the centre line, `off` metres to the right of it. The basis faces along
## the road (its -z is the driving direction), so `basis.get_euler().y` is a `facing` for a controller.
func _road(s: float, off: float = 0.0) -> Transform3D:
	var n: int = line.size()
	var i: int = int(round(fposmod(s, length) / length * n)) % n
	var forward: Vector3 = (line[(i + 1) % n] - line[i]).normalized()
	return Transform3D(Basis.looking_at(forward, Vector3.UP), line[i] + forward.cross(Vector3.UP) * off)


## A kit cone is scenery with a static body. To let the car knock it over, tag it as a dynamic prop (the convention
## the kit's ball and paddle use: no body, a shape in metadata) and let the kernel make the body.
func _loose_cone() -> Node3D:
	var part: Node3D = TLKit.build("cone", {})
	var fixed: Node = part.find_children("*", "StaticBody3D", true, false)[0]
	var shape: CollisionShape3D = fixed.find_children("*", "CollisionShape3D", true, false)[0]
	part.set_meta(&"tl_dynamic", true)
	part.set_meta(&"tl_shape", shape.shape)
	part.set_meta(&"tl_shape_offset", shape.position)
	part.remove_child(fixed)
	fixed.free()
	return TLBodies.from_part(part, {"mass": float(tune["cones"]["mass"]), "group": "cones"})


func _on_checkpoint(body: Node3D, index: int) -> void:
	if body == car:
		rules.pass_checkpoint("car", index)


func _on_pad_entered(body: Node3D) -> void:
	if body == car:
		_on_pad = true


func _on_car_hit(other: Node, _impulse: float, _speed: float) -> void:
	if other.is_in_group("cones"):
		cone_hits += 1


func _pack_start() -> void:
	rules.start()


func _pack_tick(_frame: int) -> void:
	if rules.is_over():
		car.set_controls(0.0, 0.0, 1.0)                      # the run is over: brake to a stop
	else:
		car.drive_from_input(ctx.input, {"left": &"left", "right": &"right", "gas": &"gas", "brake": &"brake", "reverse": &"reverse", "nitro": &"nitro"})
	if _on_pad:
		_on_pad = false
		pad_visits += 1
		car.nitro_charge = 1.0
	top_speed = maxf(top_speed, car.speed())
	var lane: Dictionary = TLSteer.keep_lane(car.global_position, car.forward(), line, float(tune["look_ahead"]), true)
	ahead = lane["target"]
	off_line = float(lane["offset"])
	var reach: float = maxf(float(tune["look_ahead"]), car.speed() * float(tune["far_seconds"]))
	far = TLSteer.keep_lane(car.global_position, car.forward(), line, reach, true)["target"]


## What a bot (and the state hash) sees.
func _pack_state() -> Dictionary:
	var s: Dictionary = rules.snapshot()
	var f: Vector3 = car.forward()
	s["car"] = {"x": car.global_position.x, "y": car.global_position.y, "z": car.global_position.z, "fx": f.x, "fz": f.z,
		"forward_speed": car.forward_speed(), "nitro_charge": car.nitro_charge, "nitro_active": car.nitro_active,
		"grounded_wheels": car.grounded_wheels(), "surface": car.wheel_surface[0]}
	s["ahead"] = [ahead.x, ahead.z]
	s["far"] = [far.x, far.z]
	s["off_line"] = off_line
	s["next_checkpoint"] = int(rules.next_checkpoint["car"])
	s["pad_visits"] = pad_visits
	s["nitro_starts"] = nitro_starts
	s["cone_hits"] = cone_hits
	s["cones"] = {"alive": cones.alive().size(), "spawned": cones.total}
	s["top_speed"] = top_speed
	s["hud"] = {"laps": hud.text_of(&"laps"), "clock": hud.text_of(&"clock"), "hint": hud.text_of(&"hint")}
	return s
