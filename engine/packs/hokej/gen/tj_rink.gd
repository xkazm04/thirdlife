extends RefCounted
## thirdjam's regular rink as ARinkActor::Build makes it (S/JamGame/Private/RinkActor.cpp:434-886, measures RinkActor.h:59-70,
## thirdjam HEAD 8dc713c6), from the cartridge's game.rink (90 x 45 m, corners 3.75 m, goals 4 x 0.61 m), drawn kit-style
## (TLMesh, palette keys): the outline (ARinkActor::Outline, 12 segments a corner), the boards with their kick plate, the
## markings, and the goals as thirdjam's arena meshes are made (tools/blender/arena/arena.py goal_build, the 4 x 0.61 variant
## RinkActor picks). The ice sheet alone is the kit's `rink` part (no boards, glass, markings or goals of its own), lowered
## 0.05 m so its top is thirdjam's z = 0. Round 2 (the Director, 23 Nov): a plain dark hall round it in place of sky and
## grass (no art: walls, a ceiling). Visual only: the gym's skater is plain data. Every measure that differs is in
## docs/shifts/2026-11-24-night/lanes/K3-shell/RINK.md.

const Z_PAINT: float = 0.006      # RinkActor.cpp:604: markings 0.6 cm over the ice


static func generate(ctx) -> void:
	ctx.root.set_meta(&"hokej_rink", "gen/tj_rink.gd")


## Builds the rink under `parent` (a Node3D in Godot coordinates: rink x -> x, rink y -> z, up -> y).
## `arena_marks` (K3 round 9): empty without thirdjam's hall; with it (lane K6's arena, ctx.cores.part("rink", "arena")) the
## arena draws the ice, the boards and the kick plate as the clay tier dresses them, and its ice paints the centre line, the
## blue lines, the goal lines and the 9 m centre circle (style/shaders/hall_ice.gdshader: RinkActor's markings sections 0
## and 1). Then this draws only RinkActor's sections 2 and 3, "the marks B's painted ice does not carry" (RinkActor.cpp:
## 614-618), in thirdjam's own colours: {"red": section 2's colour, "pale": section 3's} (linear, arena.json's Markings
## materials, RinkActor.cpp:650-659), and the goals (the arena leaves them to the pack by default).
static func build(parent: Node3D, rink: Dictionary, hall: Dictionary, arena_marks: Dictionary = {}) -> Node3D:
	var L: float = float(rink["length_m"])
	var W: float = float(rink["width_m"])
	var R: float = float(rink["corner_radius_m"])
	var goal_w: float = float(rink.get("goal_width_m", 4.0))
	var goal_h: float = float(rink.get("goal_height_m", 0.61))   # FJamRinkConfig::GoalHeightM default (JamCartridge.h:37)
	var node := Node3D.new()
	node.name = "Rink"
	parent.add_child(node)
	var mk := TLMesh.new(41)
	if arena_marks.is_empty():
		var part: Node3D = TLKit.build("rink", {"length": L, "width": W, "corner_r": R, "boards": false, "glass": false,
			"markings": false, "goals": false, "apron": 0.0})
		part.position = Vector3(0, -0.05, 0)                     # the kit's ice top is y = 0.05 (KIT.md `rink`)
		node.add_child(part)
		_boards(mk, outline(L, W, R, 12))
	_markings(mk, L, W, R, goal_w, arena_marks)
	for s: float in [-1.0, 1.0]:
		_goal(mk, s, L * 0.5 - 4.0, goal_w, goal_h)
	node.add_child(mk.instance("TjRink"))
	if not hall.is_empty():
		_hall(node, L, W, hall)
	return node


## ARinkActor::Outline (RinkActor.cpp:416-432): counter-clockwise, corner arcs of `segs` segments.
static func outline(L: float, W: float, R: float, segs: int) -> Array:
	var out: Array = []
	var hx: float = L * 0.5
	var hz: float = W * 0.5
	var rc: float = clampf(R, 0.0, minf(hx, hz))
	var centres: Array = [Vector2(hx - rc, hz - rc), Vector2(-(hx - rc), hz - rc), Vector2(-(hx - rc), -(hz - rc)), Vector2(hx - rc, -(hz - rc))]
	for c: int in 4:
		var start: float = float(c) * PI * 0.5
		var n: int = segs if rc > 0.0 else 1
		for i: int in n + 1:
			var a: float = start + (PI * 0.5) * float(i) / float(n)
			out.append((centres[c] as Vector2) + Vector2(cos(a), sin(a)) * rc)
	return out


static func _g(p: Vector2, h: float) -> Vector3:   # rink (x, y) at height h -> Godot
	return Vector3(p.x, h, p.y)


## The boards (RinkActor.cpp:470-500, RinkActor.h:60-67): 1.2 m high, 0.2 m thick outward from the outline; the kick plate
## 0.25 m high standing 2 cm proud of the inner face, yellow (RinkActor.cpp:550, LoadConstructionMat(0.85, 0.72, 0.12)).
static func _boards(mk: TLMesh, line: Array) -> void:
	var bh: float = 1.2
	var t: float = 0.2
	for i: int in line.size():
		var p0: Vector2 = line[i]
		var p1: Vector2 = line[(i + 1) % line.size()]
		if p0.distance_to(p1) < 0.01:
			continue
		var d: Vector2 = (p1 - p0).normalized()
		var o: Vector2 = Vector2(d.y, -d.x)                      # outward for a counter-clockwise outline (cpp:484)
		var e: Vector2 = d * 0.01                                 # a hair of overlap at the joints
		mk.bar(_g(p0 - e + o * (t * 0.5), 0.0), _g(p1 + e + o * (t * 0.5), 0.0), t, bh * 2.0, "cabin")
		mk.bar(_g(p0 - e - o * 0.01, 0.0), _g(p1 + e - o * 0.01, 0.0), 0.02, 0.5, "yellow")


# A strip of half width hw between two points on the ice (FMeshBuf::Strip: the width argument is the half width).
## A paint `key` is a palette key, or a Color: thirdjam's own colour on the palette's white (the toon shader multiplies the
## palette colour by the vertex colour).
static func _paint(key: Variant) -> Array:
	return ["white", key as Color] if key is Color else [String(key), Color.WHITE]


static func _strip(mk: TLMesh, a: Vector2, b: Vector2, hw: float, key: Variant, z: float = Z_PAINT) -> void:
	var d: Vector2 = (b - a).normalized()
	var n: Vector2 = Vector2(-d.y, d.x) * hw
	var pk: Array = _paint(key)
	mk.quad_up(Vector3(a.x + n.x, z, a.y + n.y), Vector3(b.x + n.x, z, b.y + n.y), Vector3(b.x - n.x, z, b.y - n.y), Vector3(a.x - n.x, z, a.y - n.y), pk[0], pk[1])


# A ring (r0 = 0: a disc) or an arc from angle a0 to a1 (radians, rink frame), seg segments (FMeshBuf::Ring / Arc).
static func _arc(mk: TLMesh, c: Vector2, r0: float, r1: float, a0: float, a1: float, seg: int, key: Variant, z: float = Z_PAINT) -> void:
	var pk: Array = _paint(key)
	for i: int in seg:
		var t0: float = a0 + (a1 - a0) * float(i) / float(seg)
		var t1: float = a0 + (a1 - a0) * float(i + 1) / float(seg)
		var o0: Vector2 = c + Vector2(cos(t0), sin(t0)) * r1
		var o1: Vector2 = c + Vector2(cos(t1), sin(t1)) * r1
		var i0: Vector2 = c + Vector2(cos(t0), sin(t0)) * r0
		var i1: Vector2 = c + Vector2(cos(t1), sin(t1)) * r0
		mk.quad_up(Vector3(i0.x, z, i0.y), Vector3(o0.x, z, o0.y), Vector3(o1.x, z, o1.y), Vector3(i1.x, z, i1.y), pk[0], pk[1])


static func _markings(mk: TLMesh, L: float, W: float, R: float, goal_w: float, arena_marks: Dictionary = {}) -> void:
	var gl: float = L * 0.5 - 4.0                    # FJamRinkConfig::GoalLineX (JamCartridge.h:43)
	var hz: float = W * 0.5
	var red: Variant = arena_marks.get("red", "rink_red")
	var pale: Variant = arena_marks.get("pale", "rink_blue")
	if arena_marks.is_empty():
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
			_arc(mk, c, 0.0, dot_r, 0.0, TAU, 16, red)
			_arc(mk, c, circle_r - lw, circle_r + lw, 0.0, TAU, 64, red)
			for hx: float in [-1.0, 1.0]:
				for hy: float in [-1.0, 1.0]:
					_strip(mk, Vector2(c.x + hx * hash_x, c.y + hy * circle_r), Vector2(c.x + hx * hash_x, c.y + hy * (circle_r + hash_l)), lw, red)
			_arc(mk, Vector2(nx, zs * dot_y), 0.0, dot_r, 0.0, TAU, 16, red)
		var gc := Vector2(s * gl, 0)
		var a0: float = PI * 0.5 if s > 0.0 else -PI * 0.5   # the half disc faces the centre
		_arc(mk, gc, 0.0, crease_r - lw, a0, a0 + PI, 24, pale, Z_PAINT - 0.001)
		_arc(mk, gc, crease_r - lw, crease_r + lw, a0, a0 + PI, 24, red)
		var trap_near: float = goal_w * 0.5 + 1.35
		var trap_far: float = minf(goal_w * 0.5 + 2.25, maxf(trap_near, hz - R))
		for zs: float in [-1.0, 1.0]:
			_strip(mk, Vector2(s * gl, zs * trap_near), Vector2(s * L * 0.5, zs * trap_far), lw, red)
	# section 3, pale blue (cpp:640, 647, 659): the crease fills (above) and the centre dot r 15 cm
	_arc(mk, Vector2.ZERO, 0.0, 0.15, 0.0, TAU, 16, pale)


## A goal as thirdjam's arena mesh makes it (tools/blender/arena/arena.py goal_build, lines 559-633, G at 521-530): the
## posts' inner faces at +-w/2 and the crossbar's underside at h (the sim's goal volume), posts and crossbar 16 cm, the
## bottom bars, back posts, back bar and braces 11 cm, depth 1.5 m (UJamSim::NetDepth), the back frame min(0.9, 0.6 h);
## the net of 3 cm cords in 25 cm cells. Its frame: x along the goal line -> rink y, `out` (into the net) -> rink x * side.
static func _at(side: float, gl: float, x: float, o: float, z: float) -> Vector3:
	return Vector3(side * (gl + o), z, x)


static func _goal(mk: TLMesh, sd: float, gl: float, w: float, h: float) -> void:
	var pt: float = 0.16
	var lt: float = 0.11
	var dd: float = 1.5
	var hw: float = w * 0.5
	var xp: float = hw + pt * 0.5
	var top: float = h + pt * 0.5
	var bh: float = minf(0.9, h * 0.6)
	var ct: float = 0.03
	var cell: float = 0.25
	for sx: float in [-1.0, 1.0]:
		mk.bar(_at(sd, gl, sx * xp, 0.0, 0.0), _at(sd, gl, sx * xp, 0.0, h + pt), pt, pt, "goal_red")                 # post
		mk.bar(_at(sd, gl, sx * xp, -lt * 0.5, lt * 0.5), _at(sd, gl, sx * xp, dd + lt * 0.5, lt * 0.5), lt, lt, "goal_red")   # bottom bar
		mk.bar(_at(sd, gl, sx * xp, dd, 0.0), _at(sd, gl, sx * xp, dd, bh), lt, lt, "goal_red")                       # back post
		mk.bar(_at(sd, gl, sx * xp, 0.0, top), _at(sd, gl, sx * xp, dd, bh), lt, lt, "goal_red")                      # brace
	mk.bar(_at(sd, gl, -(hw + pt), 0.0, top), _at(sd, gl, hw + pt, 0.0, top), pt, pt, "goal_red")                     # crossbar
	mk.bar(_at(sd, gl, -(hw + pt), dd, lt * 0.5), _at(sd, gl, hw + pt, dd, lt * 0.5), lt, lt, "goal_red")             # back bottom bar
	mk.bar(_at(sd, gl, -(hw + pt), dd, bh), _at(sd, gl, hw + pt, dd, bh), lt, lt, "goal_red")                         # back bar
	# the net (arena.py:604-632)
	var nx: int = maxi(4, roundi(w / cell))
	var f0 := Vector2(pt * 0.2, top)
	var b0 := Vector2(dd, bh)
	var nt: int = maxi(3, roundi((b0 - f0).length() / cell))
	for i: int in range(1, nx):
		var x: float = -hw + w * float(i) / float(nx)
		mk.bar(_at(sd, gl, x, f0.x, f0.y), _at(sd, gl, x, b0.x, b0.y), ct, ct, "goal_net")
		mk.bar(_at(sd, gl, x, dd, bh), _at(sd, gl, x, dd, lt * 0.5), ct, ct, "goal_net")
	for j: int in range(1, nt):
		var q: Vector2 = f0.lerp(b0, float(j) / float(nt))
		mk.bar(_at(sd, gl, -xp, q.x, q.y), _at(sd, gl, xp, q.x, q.y), ct, ct, "goal_net")
	var nb: int = maxi(2, roundi(bh / cell))
	for j: int in range(1, nb):
		mk.bar(_at(sd, gl, -xp, dd, bh * float(j) / float(nb)), _at(sd, gl, xp, dd, bh * float(j) / float(nb)), ct, ct, "goal_net")
	var no: int = maxi(3, roundi(dd / cell))
	for sx: float in [-1.0, 1.0]:
		for k: int in range(1, no):
			var o: float = dd * float(k) / float(no)
			mk.bar(_at(sd, gl, sx * xp, o, top + (bh - top) * float(k) / float(no)), _at(sd, gl, sx * xp, o, lt * 0.5), ct, ct, "goal_net")
		var z: float = cell
		while z < top - 0.12:
			var o_end: float = dd if z <= bh else dd * (top - z) / (top - bh)
			mk.bar(_at(sd, gl, sx * xp, pt * 0.2, z), _at(sd, gl, sx * xp, o_end, z), ct, ct, "goal_net")
			z += cell


## The hall (round 2, the Director's word: no art): a dark box round the rink, its floor, four walls and a ceiling, from
## data/gym.json "hall". It is not thirdjam's arena (stair step 5); it takes the sky and the grass out of the picture.
static func _hall(node: Node3D, L: float, W: float, hall: Dictionary) -> void:
	var m: float = float(hall["margin_m"])
	var hh: float = float(hall["height_m"])
	var hx: float = L * 0.5 + m
	var hz: float = W * 0.5 + m
	var mk := TLMesh.new(44)
	var key: String = String(hall["wall_key"])
	mk.boxm(Vector3(-hx, -0.3, -hz), Vector3(hx, -0.02, hz), String(hall["floor_key"]))
	mk.boxm(Vector3(-hx - 1.0, -0.3, -hz - 1.0), Vector3(hx + 1.0, hh, -hz), key)
	mk.boxm(Vector3(-hx - 1.0, -0.3, hz), Vector3(hx + 1.0, hh, hz + 1.0), key)
	mk.boxm(Vector3(-hx - 1.0, -0.3, -hz), Vector3(-hx, hh, hz), key)
	mk.boxm(Vector3(hx, -0.3, -hz), Vector3(hx + 1.0, hh, hz), key)
	if bool(hall.get("ceiling", true)):
		mk.boxm(Vector3(-hx - 1.0, hh, -hz - 1.0), Vector3(hx + 1.0, hh + 1.0, hz + 1.0), String(hall["ceiling_key"]))
	var mi: MeshInstance3D = mk.instance("Hall")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # the roof light comes through the hall's own roof (TLStyleHall)
	node.add_child(mi)


## The 1.64 m stand-in skater (until lane K2's figure): a capsule with a facing mark (a chest plate on its +x side) built
## facing +x, and a separate unit stick bar along +x (the caller scales and turns it). Not the engine's walking figure.
static func standin_figure(parent: Node3D, key: String = "car_blue", nm: String = "Skater") -> Array:
	var body := Node3D.new()
	body.name = nm
	parent.add_child(body)
	var mk := TLMesh.new(42)
	mk.capsule(Vector3(0, 0.25, 0), Vector3(0, 1.64 - 0.25, 0), 0.25, key, Color.WHITE, 12, 3)
	mk.boxm(Vector3(0.18, 1.05, -0.12), Vector3(0.34, 1.35, 0.12), "yellow")       # the facing mark: chest, his +x
	mk.boxm(Vector3(0.12, 0.0, -0.1), Vector3(0.42, 0.06, 0.1), "black")           # and a toe on the ice, ahead
	body.add_child(mk.instance("SkaterStandin"))
	var stick := Node3D.new()
	stick.name = nm + "Stick"
	parent.add_child(stick)
	var sk := TLMesh.new(43)
	sk.boxm(Vector3(0.0, 0.0, -0.025), Vector3(1.0, 0.05, 0.025), "wood_dark")
	stick.add_child(sk.instance("StickStandin"))
	return [body, stick]


## thirdjam's puck (K3 round 10), as AJamPuck::InitPuck makes it (S/JamCore/Private/JamPawns.cpp:865-916): the engine's
## unit cylinder scaled to 2r x 2r x 0.08 m (game.puck.radius_m 0.12; colour_hex #111111: the palette's black), its node at
## the puck's bottom (the cylinder from y = 0 to 8 cm; thirdjam centres it 4 cm up). And its kit, R-0016's SM_PuckDisc
## (/JamAssets/Props, exported by lane K6: hk-arena .tl/arena-export/meshes/SM_PuckDisc.glb), which AJamPuck::PlaceDiscOnIce
## keeps 0.4 cm over the ice under the puck whatever its height (:1019-1025): section 0 a low dome 42 cm across and 2.7 cm
## high (its profile read from the export: radius 0.21 m at 0.2 cm, 0.18 at 1.1, 0.15 at 1.8, 0.12 at 2.3, 0.06 at 2.6, the
## top 2.7 cm) in MI_Trim_PuckHalo (M_Trim, Emissive 18, TeamColour linear (0.75, 1.0, 0.15): a glowing lime that the
## camera's tone curve shows near white); drawn here in the palette's `neon_lime` (an emissive key, emit 2.2).
## DEVIATIONS: section 1, the beacon skirt (MI_Fx_PuckBeacon: additive, unlit, fading out from 15 m), is not drawn (no
## additive surface in the palette); the halo's strength is the palette's emit 2.2, not Emissive 18 under thirdjam's
## exposure; the trail (NS_puck_trail) is not drawn.
## Returns the puck node; its disc is a sibling node, `puck.get_meta(&"disc")`, which the caller places on the ice.
const PUCK_H: float = 0.08                 # AJamPuck::InitPuck: 0.08 m tall (HalfHeightM 0.04)
const PUCK_DISC_Y: float = 0.004           # AJamPuck::PlaceDiscOnIce: 0.4 cm over the ice
const PUCK_HALO: Array = [[0.21, 0.002], [0.18, 0.011], [0.15, 0.018], [0.12, 0.023], [0.06, 0.026], [0.0, 0.027]]
static func standin_puck(parent: Node3D, radius: float) -> Node3D:
	var n := Node3D.new()
	n.name = "Puck"
	parent.add_child(n)
	var mk := TLMesh.new(45)
	mk.cyl(radius, PUCK_H, 24, "black")
	n.add_child(mk.instance("PuckMesh"))
	var disc := Node3D.new()
	disc.name = "PuckDisc"
	parent.add_child(disc)
	var dm := TLMesh.new(46)
	for i: int in PUCK_HALO.size() - 1:
		var r0: float = float(PUCK_HALO[i][0])
		var y0: float = float(PUCK_HALO[i][1])
		var r1: float = float(PUCK_HALO[i + 1][0])
		var y1: float = float(PUCK_HALO[i + 1][1])
		dm.cyl(r0, y1 - y0, 32, "neon_lime", Color.WHITE, r1, Vector3(0, y0, 0), r1 > 0.0, false)
	disc.add_child(dm.instance("PuckHalo"))
	n.set_meta(&"disc", disc)
	return n
