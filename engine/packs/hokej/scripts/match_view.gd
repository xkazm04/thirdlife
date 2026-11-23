extends RefCounted
## The match drawn from the core's snapshot with STAND-INS (K3 round 3): one 1.64 m capsule a skater in its team's colour
## with a facing mark, a stick bar from the body to the sim's blade (BladePos), the puck at its true position and height.
## The seam for lane K2's figure: draw_skater(i, skater_snapshot) gets one skater's snapshot dictionary per frame; K2's
## pawn (engine/cores/rink/view/skater_pawn.gd, AJamSkater::ApplySimFrame) replaces the body of that function.
## Interpolation between the 60 Hz frames: AJamSkater::ApplyRender lerps PrevPos -> Pos with the render alpha
## (JamPawns.cpp:824-846); the engine's physics interpolation does the same for a node moved once a physics frame. A jump
## the sim does not move through (a faceoff's reset puts the skaters on their dots, PrevPos = Pos there) is not drawn as a
## slide: the node's interpolation is reset when the sim's own PrevPos is the new position and the node stood elsewhere.

var bodies: Array = []
var sticks: Array = []
var puck: Node3D


func _init(root: Node3D, rink_gen, snap: Dictionary, puck_radius: float) -> void:
	var sk: Array = snap["Skaters"]
	for i: int in sk.size():
		var team: int = int(sk[i]["Team"])
		var parts: Array = rink_gen.standin_figure(root, "car_blue" if team == 0 else "orange", "Skater%d" % i)   # cartridge colours #1D4ED8, #E8651A
		bodies.append(parts[0])
		sticks.append(parts[1])
	puck = rink_gen.standin_puck(root, puck_radius)


## One frame. `hold`: indices whose figures hold their last pose (a hit-stop's victim and checker).
func draw(snap: Dictionary, hold: Dictionary = {}) -> void:
	var sk: Array = snap["Skaters"]
	for i: int in sk.size():
		if not hold.has(i):
			draw_skater(i, sk[i])
	var p: Dictionary = snap["Puck"]
	if not hold.has(-1):
		var pp: Vector2 = p["Pos"]
		_place(puck, Vector3(pp.x, float(p["Z"]), pp.y), (p["PrevPos"] as Vector2) == pp if p.has("PrevPos") else false)


func draw_skater(i: int, s: Dictionary) -> void:
	var pos: Vector2 = s["Pos"]
	var body: Node3D = bodies[i]
	var teleport: bool = (s["PrevPos"] as Vector2) == pos and Vector2(body.position.x, body.position.z).distance_to(pos) > 0.5
	body.rotation = Vector3(0.0, -float(s["Yaw"]), 0.0)       # rink yaw (towards +y) -> Godot: about -Y
	_place(body, Vector3(pos.x, 0.0, pos.y), teleport)
	# the stick: from the body's edge (0.25 m) to the blade on the ice (FJamSkaterState::BladePos)
	var blade: Vector2 = s["BladePos"]
	if blade.distance_to(pos) > 3.0:              # a blade the sim has not placed yet (BladePos (0, 0) before the first step):
		blade = pos + Vector2(cos(float(s["Yaw"])), sin(float(s["Yaw"]))) * 1.0   # held ahead (stand-in rule; no reach is 3 m)
	var d: Vector2 = blade - pos
	var st: Node3D = sticks[i]
	var yaw: float = atan2(d.y, d.x) if d.length() > 0.01 else float(s["Yaw"])
	var from: Vector2 = pos + Vector2(cos(yaw), sin(yaw)) * 0.25
	st.rotation = Vector3(0.0, -yaw, 0.0)
	st.scale = Vector3(maxf(0.05, blade.distance_to(from)), 1.0, 1.0)
	_place(st, Vector3(from.x, 0.0, from.y), teleport)


static func _place(n: Node3D, at: Vector3, teleport: bool) -> void:
	n.position = at
	if teleport:
		n.reset_physics_interpolation()


## After the first placement: nothing slides in from where the nodes were made.
func reset_interpolation() -> void:
	for n: Node3D in bodies + sticks + [puck]:
		n.reset_physics_interpolation()
