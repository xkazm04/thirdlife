extends RefCounted
## Glow Ice scenery. All dimensions are in local rink space; none of the geometry has collision.
const HOME := "cyan"
const AWAY := "tail_light"
const PAINT := 0.083
const HALL_TINT := Color(0.07, 0.10, 0.16)

static func finish(parent: Node3D, mk: TLMesh, label: String) -> MeshInstance3D:
	var surface := MeshInstance3D.new()
	surface.name = label
	surface.mesh = mk.build(label)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(surface)
	return surface

static func point(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)

static func stroke(mk: TLMesh, a: Vector2, b: Vector2, width: float, key: String, y: float = PAINT, tint: Color = Color.WHITE) -> void:
	var n := (b - a).normalized().orthogonal() * width * 0.5
	mk.quad_up(point(a - n, y), point(b - n, y), point(b + n, y), point(a + n, y), key, tint)

static func arc(mk: TLMesh, c: Vector2, r: float, width: float, start: float, end: float, key: String, dashed: bool = false) -> void:
	var steps := ceili(48 * absf(end - start) / TAU)
	for i in steps:
		if dashed and i % 8 >= 6:
			continue
		var d0 := Vector2.from_angle(lerpf(start, end, float(i) / steps))
		var d1 := Vector2.from_angle(lerpf(start, end, float(i + 1) / steps))
		mk.quad_up(point(c + d0 * (r - width), PAINT), point(c + d1 * (r - width), PAINT),
			point(c + d1 * r, PAINT), point(c + d0 * r, PAINT), key)

static func ice(mk: TLMesh, path: Array, half: Vector2, radius: float) -> void:
	# Bake the reflected board light into a narrow strip of the sheet. Each corner follows the boards.
	var inset := 2.4
	var inside := TLKitArena.rrect((half.x - inset) * 2, (half.y - inset) * 2, maxf(0.1, radius - inset), 7)
	var sheet_tint := Color(0.10, 0.21, 0.30)
	var midnight := TLStyle.color("black").srgb_to_linear() * sheet_tint
	var home := Color("#276884").srgb_to_linear()
	var away := Color("#75425e").srgb_to_linear()
	mk.prism(PackedVector2Array(inside), -0.10, 0.060, "black", sheet_tint, 1.0, true, false)
	for i in path.size():
		var j := (i + 1) % path.size()
		var a := point(path[i], 0.060)
		var b := point(path[j], 0.060)
		var c := point(inside[j], 0.060)
		var d := point(inside[i], 0.060)
		var ca := home.lerp(away, smoothstep(-4.0, 4.0, a.x))
		var cb := home.lerp(away, smoothstep(-4.0, 4.0, b.x))
		mk.tri_n(a, d, c, Vector3.UP, Vector3.UP, Vector3.UP, "white", ca, midnight, midnight)
		mk.tri_n(a, c, b, Vector3.UP, Vector3.UP, Vector3.UP, "white", ca, midnight, cb)

static func arena(parent: Node3D, half: Vector2, radius: float, goals: Dictionary, accent: String, lines: bool) -> void:
	var mk := TLMesh.new(1)
	var path := TLKitArena.rrect(half.x * 2, half.y * 2, radius, 7)
	ice(mk, path, half, radius)
	# The kit batches the apron and net cages together. Cap the apron and leave the netting visible.
	var deck := TLKitArena.rrect(half.x * 2 + 7.1, half.y * 2 + 7.1, radius + 3.55, 7)
	mk.prism(PackedVector2Array(deck), -0.09, -0.016, "black", Color(0.23, 0.29, 0.40), 1.0, true, false)
	# The building beyond the lit boards falls away into black, even in the opening wide shot.
	mk.box(Vector3(half.x * 2 + 42, 0.20, half.y * 2 + 42), "black", HALL_TINT, 0, Vector3(0, -0.22, 0))
	mk.box(Vector3(half.x * 2 + 40, 7.0, 0.4), "black", HALL_TINT, 0, Vector3(0, 3.4, -half.y - 19))
	for i in path.size():
		var a: Vector2 = path[i]
		var b: Vector2 = path[(i + 1) % path.size()]
		TLKitArena.slab(mk, a, b, 0.34, 0.05, 1.24, "bot_dark")
		var mid := a.lerp(b, 0.5)
		for endpoints: Array in [[a, mid], [mid, b]]:
			var start: Vector2 = endpoints[0]
			var end: Vector2 = endpoints[1]
			var side := HOME if start.x + end.x < 0 else AWAY
			TLKitArena.slab(mk, start, end, 0.38, 0.17, 0.27, side, Color.WHITE, 0)
	# Inset grid stops before the curved boards. Its width and tint keep the face-off marks foremost.
	for x in range(-floori(half.x / 3), ceili(half.x / 3) + 1):
		var px := 3.0 * x
		if absf(px) >= half.x - 0.3: continue
		var dz := maxf(0, absf(px) - half.x + radius)
		var z := half.y - radius + sqrt(maxf(0, radius * radius - dz * dz)) - 0.18
		stroke(mk, Vector2(px, -z), Vector2(px, z), 0.042, "tarmac", 0.069, Color(0.26, 0.32, 0.44))
	for j in range(-floori(half.y / 3), ceili(half.y / 3) + 1):
		var pz := 3.0 * j
		if absf(pz) >= half.y - 0.3: continue
		var dx := maxf(0, absf(pz) - half.y + radius)
		var x := half.x - radius + sqrt(maxf(0, radius * radius - dx * dx)) - 0.18
		stroke(mk, Vector2(-x, pz), Vector2(x, pz), 0.042, "tarmac", 0.070, Color(0.26, 0.32, 0.44))
	if lines:
		markings(mk, half, goals, accent)
	finish(parent, mk, "NightRink")

static func markings(mk: TLMesh, half: Vector2, goals: Dictionary, accent: String) -> void:
	var z := half.y - 0.14
	var r := half.y * 0.23
	for sign_z: float in [-1.0, 1.0]:
		stroke(mk, Vector2(0, sign_z * (r + 0.15)), Vector2(0, sign_z * z), 0.12, accent)
	arc(mk, Vector2.ZERO, r, 0.13, 0, TAU, accent)
	# Three cuts in the ice form the home-ice crest. The points run in the direction of attack.
	for blade in range(-1, 2):
		var mid := Vector2(0.58 * blade, 0)
		var arm := Vector2(0.73, -1.50) * (1.0 if blade == 0 else 0.74)
		mk.quad_up(point(mid - arm, PAINT), point(mid + Vector2(0.23, -0.14), PAINT),
			point(mid + arm, PAINT), point(mid - Vector2(0.23, -0.14), PAINT), "pants", Color(0.64, 0.66, 0.83))
	mk.cyl(0.18, 0.008, 24, accent, Color.WHITE, -1, Vector3(0, PAINT, 0))
	for s: float in [-1.0, 1.0]:
		var team := HOME if s < 0 else AWAY
		var zone_x := s * half.x / 3.0
		if s < 0:
			stroke(mk, Vector2(zone_x, -z), Vector2(zone_x, z), 0.16, team)
		else:
			for i in 16:
				var at_z := lerpf(-z, z, float(i) / 16.0)
				stroke(mk, Vector2(zone_x, at_z), Vector2(zone_x, at_z + z * 0.089), 0.16, team)
		var gx: float = goals["blue" if s < 0 else "red"][0]
		var angle := 0.0 if s < 0 else PI
		var crease := PackedVector2Array()
		for step in 25:
			crease.append(Vector2(gx, 0) + Vector2.from_angle(angle - PI / 2 + PI * step / 24) * 2.8)
		mk.prism(crease, 0.068, 0.076, "white", Color("#274766" if s < 0 else "#50344b").srgb_to_linear(), 1.0, true, false)
		stroke(mk, Vector2(gx, -2.8), Vector2(gx, 2.8), 0.09, team)
		arc(mk, Vector2(gx, 0), 2.8, 0.12, angle - PI / 2, angle + PI / 2, team)
		for flank: float in [-1.0, 1.0]:
			var spot := Vector2(half.x * s * 0.62, half.y * flank * 0.53)
			arc(mk, spot, 2.85, 0.095, 0, TAU, team, s > 0)
			for end: float in [-1.0, 1.0]:
				for split: float in [-0.40, 0.40]:
					var tick := spot + Vector2(split, 2.86 * end)
					stroke(mk, tick, tick + Vector2(0, end * 0.32), 0.10, team)
			mk.cyl(0.14, 0.008, 16, team, Color.WHITE, -1, point(spot, PAINT))

static func net(parent: Node3D, half_mouth: float, key: String, flashed: bool) -> MeshInstance3D:
	var mk := TLMesh.new(1)
	var w := 0.20 if flashed else 0.15
	for z: float in [-half_mouth, half_mouth]:
		mk.bar(Vector3(0, 0.05, z), Vector3(0, 1.55, z), w, w, key)
	mk.bar(Vector3(0, 1.55, -half_mouth), Vector3(0, 1.55, half_mouth), w, w, key)
	return finish(parent, mk, "GoalFlash" if flashed else "GoalLight")

static func puck(parent: Node3D, r: float) -> MeshInstance3D:
	var mk := TLMesh.new(1)
	mk.cyl(r * 1.32, 0.085, 32, "head_light", Color.WHITE, -1, Vector3(0, 0.025, 0))
	mk.cyl(r * 1.11, 0.017, 32, "black", Color.WHITE, -1, Vector3(0, 0.11, 0))
	mk.cyl(r * 0.71, 0.016, 32, "nitro_core", Color.WHITE, -1, Vector3(0, 0.127, 0))
	return finish(parent, mk, "LuminousPuck")

static func helmet(socket: Node3D, team: String) -> MeshInstance3D:
	# A ribbon across the curved crown, fixed to the head bone through turns and falls.
	var mk := TLMesh.new(1)
	var left := Vector3(-0.045, -0.155, -0.267)
	var right := Vector3(0.045, -0.155, -0.267)
	for i in range(1, 17):
		var a := PI * float(i) / 16
		var l := Vector3(left.x, -0.15 + sin(a) * 0.184, -cos(a) * 0.289 + 0.013)
		var r := Vector3(right.x, l.y, l.z)
		mk.quad_up_any(left, right, r, l, team)
		left = l
		right = r
	return finish(socket, mk, "HelmetTape")

static func jacket(socket: Node3D, key: String) -> MeshInstance3D:
	var mk := TLMesh.new(1)
	for s: float in [-1.0, 1.0]:
		mk.bar(Vector3(0, 0.005, 0.019), Vector3(s * 0.21, 0.11, -0.005), 0.045, 0.045, key)
	return finish(socket, mk, "ShoulderTape")
