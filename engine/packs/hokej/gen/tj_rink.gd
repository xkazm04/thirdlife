extends RefCounted
## thirdjam's regular rink as ARinkActor::Build makes it (S/JamGame/Private/RinkActor.cpp:434-886, measures RinkActor.h:59-70,
## thirdjam HEAD 8dc713c6), from the cartridge's game.rink (90 x 45 m, corners 3.75 m, goals 4 x 0.61 m). The ice, boards and
## glass are the kit's `rink` part placed so its geometry lands on thirdjam's (the part centres its boards on its outline:
## built 0.2 m longer and wider with the corner 0.1 m larger, its boards' inner face stands on thirdjam's outline; lowered
## 0.05 m, its ice top is thirdjam's z = 0). The markings and the nets are not the kit's (its blue lines, goal lines, dots and
## goal differ): they are drawn here, kit-style (TLMesh, palette keys), from RinkActor's own numbers. Visual only: the
## gym's skater is plain data (the simulation knows the rink, not these meshes). Every measure that differs is in
## docs/shifts/2026-11-24-night/lanes/K3-shell/RINK.md.

const Z_PAINT: float = 0.006      # RinkActor.cpp:604: markings 0.6 cm over the ice
const UU: float = 1.0             # thirdjam builds in cm (UU = 100); here metres


static func generate(ctx) -> void:
	ctx.root.set_meta(&"hokej_rink", "gen/tj_rink.gd")


## Builds the rink under `parent` (a Node3D in Godot coordinates: rink x -> x, rink y -> z, up -> y).
static func build(parent: Node3D, rink: Dictionary) -> Node3D:
	var L: float = float(rink["length_m"])
	var W: float = float(rink["width_m"])
	var R: float = float(rink["corner_radius_m"])
	var goal_w: float = float(rink.get("goal_width_m", 4.0))
	var goal_h: float = float(rink.get("goal_height_m", 0.61))   # FJamRinkConfig::GoalHeightM default (JamCartridge.h, R-0033)
	var node := Node3D.new()
	node.name = "Rink"
	parent.add_child(node)
	var board_t: float = 0.2                                     # RinkActor.h:62 BoardThicknessM
	# DEVIATION: no glass. RinkActor stands 0.9 m of glass on the boards (RinkActor.h:61); the kit's glass draws white sheen
	# stripes, and with the boards view's camera 0.4 m inside the end boards a stripe crossed the skater (K3 round 1, frame
	# 1380 of bot_gym_hand). thirdjam's glass is near invisible in its film. Back when the kit or the style has a quiet glass.
	var part: Node3D = TLKit.build("rink", {"length": L + board_t, "width": W + board_t, "corner_r": R + board_t * 0.5,
		"glass": false, "glass_h": 0.9, "markings": false, "goals": false})   # RinkActor.h:60 BoardHeightM 1.2
	part.position = Vector3(0, -0.05, 0)                         # the kit's ice top is y = 0.05 (KIT.md `rink`)
	node.add_child(part)
	var mk := TLMesh.new(41)
	_markings(mk, L, W, R, goal_w)
	_nets(mk, L, goal_w, goal_h)
	node.add_child(mk.instance("TjMarkings"))
	return node


# A strip of half width hw between two points on the ice (FMeshBuf::Strip: the width argument is the half width).
static func _strip(mk: TLMesh, a: Vector2, b: Vector2, hw: float, key: String, z: float = Z_PAINT) -> void:
	var d: Vector2 = (b - a).normalized()
	var n: Vector2 = Vector2(-d.y, d.x) * hw
	mk.quad_up(Vector3(a.x + n.x, z, a.y + n.y), Vector3(b.x + n.x, z, b.y + n.y), Vector3(b.x - n.x, z, b.y - n.y), Vector3(a.x - n.x, z, a.y - n.y), key)


# A ring (r0 = 0: a disc) or an arc from angle a0 to a1 (radians, rink frame), seg segments (FMeshBuf::Ring / Arc).
static func _arc(mk: TLMesh, c: Vector2, r0: float, r1: float, a0: float, a1: float, seg: int, key: String, z: float = Z_PAINT) -> void:
	for i: int in seg:
		var t0: float = a0 + (a1 - a0) * float(i) / float(seg)
		var t1: float = a0 + (a1 - a0) * float(i + 1) / float(seg)
		var o0: Vector2 = c + Vector2(cos(t0), sin(t0)) * r1
		var o1: Vector2 = c + Vector2(cos(t1), sin(t1)) * r1
		var i0: Vector2 = c + Vector2(cos(t0), sin(t0)) * r0
		var i1: Vector2 = c + Vector2(cos(t1), sin(t1)) * r0
		mk.quad_up(Vector3(i0.x, z, i0.y), Vector3(o0.x, z, o0.y), Vector3(o1.x, z, o1.y), Vector3(i1.x, z, i1.y), key)


static func _markings(mk: TLMesh, L: float, W: float, R: float, goal_w: float) -> void:
	var gl: float = L * 0.5 - 4.0                    # FJamRinkConfig::GoalLineX (JamCartridge.h:43)
	var hz: float = W * 0.5
	# section 0, red (RinkActor.cpp:600-610): the centre line 30 cm, the goal lines 6 cm
	_strip(mk, Vector2(0, -hz), Vector2(0, hz), 0.15, "rink_red")
	for s: float in [-1.0, 1.0]:
		var ext: float = maxf(hz - maxf(0.0, R - (L * 0.5 - gl)), hz * 0.6)
		_strip(mk, Vector2(s * gl, -ext), Vector2(s * gl, ext), 0.03, "rink_red")
	# section 1, blue (cpp:611-614): the blue lines at +-L/6, 30 cm; the centre circle r 4.5 to 4.6 m
	for s: float in [-1.0, 1.0]:
		_strip(mk, Vector2(s * L / 6.0, -hz), Vector2(s * L / 6.0, hz), 0.15, "rink_blue")
	_arc(mk, Vector2.ZERO, 4.5, 4.6, 0.0, TAU, 64, "rink_blue")
	# section 2, red (cpp:620-645): faceoff circles r 4.5 m (12 cm line) with four hash marks, dots r 0.3 m, creases, trapezoids
	var lw: float = 0.06
	var circle_r: float = 4.5
	var dot_r: float = 0.3
	var hash_l: float = 0.6
	var hash_x: float = 0.85
	var crease_r: float = 1.8
	var dot_y: float = minf(7.0, W * 0.3)
	for s: float in [-1.0, 1.0]:
		var cx: float = s * (gl - 6.0)
		var nx: float = s * (L / 6.0 - 1.5)
		for zs: float in [-1.0, 1.0]:
			var c := Vector2(cx, zs * dot_y)
			_arc(mk, c, 0.0, dot_r, 0.0, TAU, 16, "rink_red")
			_arc(mk, c, circle_r - lw, circle_r + lw, 0.0, TAU, 64, "rink_red")
			for hx: float in [-1.0, 1.0]:
				for hy: float in [-1.0, 1.0]:
					_strip(mk, Vector2(c.x + hx * hash_x, c.y + hy * circle_r), Vector2(c.x + hx * hash_x, c.y + hy * (circle_r + hash_l)), lw, "rink_red")
			_arc(mk, Vector2(nx, zs * dot_y), 0.0, dot_r, 0.0, TAU, 16, "rink_red")
		var gc := Vector2(s * gl, 0)
		var a0: float = PI * 0.5 if s > 0.0 else -PI * 0.5   # the half disc faces the centre
		_arc(mk, gc, 0.0, crease_r - lw, a0, a0 + PI, 24, "rink_blue", Z_PAINT - 0.001)
		_arc(mk, gc, crease_r - lw, crease_r + lw, a0, a0 + PI, 24, "rink_red")
		var trap_near: float = goal_w * 0.5 + 1.35
		var trap_far: float = minf(goal_w * 0.5 + 2.25, maxf(trap_near, hz - R))
		for zs: float in [-1.0, 1.0]:
			_strip(mk, Vector2(s * gl, zs * trap_near), Vector2(s * L * 0.5, zs * trap_far), lw, "rink_red")
	# section 3 (cpp:647): the centre dot r 15 cm
	_arc(mk, Vector2.ZERO, 0.0, 0.15, 0.0, TAU, 16, "rink_blue")


## The nets (RinkActor.cpp:840-871): a 14 cm frame (posts, crossbar, side and back bottom bars), the back frame at
## min(0.9, h * 0.9 / 1.5) and the netting from the crossbar to the back bar; the opening faces the centre, depth 1.5 m
## (UJamSim::NetDepth, JamSim.h:506), the goal line at x = +-(L/2 - 4).
static func _nets(mk: TLMesh, L: float, goal_w: float, goal_h: float) -> void:
	var gl: float = L * 0.5 - 4.0
	var depth: float = 1.5
	var pr: float = 0.07
	var hw: float = goal_w * 0.5
	var bh: float = minf(0.9, goal_h * (0.9 / 1.5))
	for s: float in [-1.0, 1.0]:
		var x0: float = s * gl
		var x1: float = s * (gl + depth)
		# rink (x, y, up) -> Godot (x, up, y)
		mk.boxm(Vector3(x0 - pr, 0, -hw - pr), Vector3(x0 + pr, goal_h, -hw + pr), "goal_red")
		mk.boxm(Vector3(x0 - pr, 0, hw - pr), Vector3(x0 + pr, goal_h, hw + pr), "goal_red")
		mk.boxm(Vector3(x0 - pr, goal_h - pr * 2.0, -hw - pr), Vector3(x0 + pr, goal_h, hw + pr), "goal_red")
		mk.boxm(Vector3(minf(x0, x1) - pr, 0, -hw - pr), Vector3(maxf(x0, x1) + pr, pr * 2.0, -hw + pr), "goal_red")
		mk.boxm(Vector3(minf(x0, x1) - pr, 0, hw - pr), Vector3(maxf(x0, x1) + pr, pr * 2.0, hw + pr), "goal_red")
		mk.boxm(Vector3(x1 - pr, 0, -hw - pr), Vector3(x1 + pr, pr * 2.0, hw + pr), "goal_red")
		mk.boxm(Vector3(x1 - pr, 0, -hw - pr), Vector3(x1 + pr, bh, -hw + pr), "goal_red")
		mk.boxm(Vector3(x1 - pr, 0, hw - pr), Vector3(x1 + pr, bh, hw + pr), "goal_red")
		mk.boxm(Vector3(x1 - pr, bh - pr * 2.0, -hw - pr), Vector3(x1 + pr, bh, hw + pr), "goal_red")
		# the netting (RinkActor.cpp:864-867: the back, two sides, the sloped top from the crossbar to the back bar) as cords
		# 0.25 m apart: thirdjam's net mesh is see-through, a solid sheet read as a crate (K3 round 1, frames 920 and 1380)
		var cord: float = 0.018
		var nh: int = int(ceil(goal_w / 0.25))
		for i: int in nh + 1:
			var y: float = -hw + goal_w * float(i) / float(nh)
			mk.bar(Vector3(x1, 0, y), Vector3(x1, bh, y), cord, cord, "goal_net")                 # back, upright
			mk.bar(Vector3(x0, goal_h, y), Vector3(x1, bh, y), cord, cord, "goal_net")            # top, along the slope
		for k: int in 4:
			var t: float = float(k) / 3.0
			mk.bar(Vector3(x1, bh * t, -hw), Vector3(x1, bh * t, hw), cord, cord, "goal_net")     # back, across
		var nd: int = int(ceil(depth / 0.25))
		for j: int in nd + 1:
			var x: float = x0 + (x1 - x0) * float(j) / float(nd)
			var top: float = goal_h + (bh - goal_h) * float(j) / float(nd)
			for y2: float in [-hw, hw]:
				mk.bar(Vector3(x, 0, y2), Vector3(x, top, y2), cord, cord, "goal_net")            # sides, upright
			mk.bar(Vector3(x, top, -hw), Vector3(x, top, hw), cord, cord, "goal_net")             # top, across


## The 1.64 m stand-in skater (until lane K2's figure): a capsule with a facing mark (a chest plate on its +x side) built
## facing +x, and a separate unit stick bar along +x (the caller scales and turns it). Not the engine's walking figure.
static func standin_figure(parent: Node3D) -> Array:
	var body := Node3D.new()
	body.name = "Skater"
	parent.add_child(body)
	var mk := TLMesh.new(42)
	mk.capsule(Vector3(0, 0.25, 0), Vector3(0, 1.64 - 0.25, 0), 0.25, "car_blue", Color.WHITE, 12, 3)
	mk.boxm(Vector3(0.18, 1.05, -0.12), Vector3(0.34, 1.35, 0.12), "yellow")       # the facing mark: chest, his +x
	mk.boxm(Vector3(0.12, 0.0, -0.1), Vector3(0.42, 0.06, 0.1), "black")           # and a toe on the ice, ahead
	body.add_child(mk.instance("SkaterStandin"))
	var stick := Node3D.new()
	stick.name = "Stick"
	parent.add_child(stick)
	var sk := TLMesh.new(43)
	sk.boxm(Vector3(0.0, 0.0, -0.025), Vector3(1.0, 0.05, 0.025), "wood_dark")
	stick.add_child(sk.instance("StickStandin"))
	return [body, stick]
