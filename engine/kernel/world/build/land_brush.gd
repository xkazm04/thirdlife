extends RefCounted
## M2 (spark world-sandbox): what the sculpt and paint tools share: the round brush (radius 1..8 lattice cells of 3 m,
## the wheel or [ and ] to resize), its ring on the ground (a holo ribbon that follows the land, red while the spot is
## refused), the vertices or cells under it with their falloff, and the refusal of each, asked once per stroke.
## The ring is the tools' ghost: build mode's block ghost stays hidden for them (`ghost_state` {}).

const LATTICE := 3.0
const R_MIN := 1
const R_MAX := 8
const SEGMENTS := 72
const BAND := 0.14                       # metres: the ring's half width
const LIFT := 0.12                       # metres over the ground
const FLAT_TOP := 0.25                   # of the radius at full strength (a round dome; (1 - t^2)^2 made a cone on the 3 m lattice)

var host: Node = null                   # build_mode.gd
var radius := 3                         # lattice cells
var ring: MeshInstance3D = null
var _ok: Material
var _bad: Material
var _refused := {}                      # Vector2i -> reason, for the stroke now ("" allowed)


func setup(h: Node) -> void:
	host = h
	ring = MeshInstance3D.new()
	ring.name = "LandBrush"
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	ring.visible = false
	_ok = TLStyle.material("holo")
	_bad = TLStyle.material_instance("holo")
	if _bad is ShaderMaterial and not TLStyle.headless():
		var red := TLStyle.color("hazard_red")
		(_bad as ShaderMaterial).set_shader_parameter(&"holo", red)
		(_bad as ShaderMaterial).set_shader_parameter(&"edge", red.lightened(0.4))
	h.add_child(ring)


func metres() -> float:
	return radius * LATTICE


## The wheel and [ ] resize the brush. Returns true when `e` was one of them.
func resize(e: InputEvent) -> bool:
	var step := 0
	if e is InputEventMouseButton:
		var bi: int = (e as InputEventMouseButton).button_index
		step = 1 if bi == MOUSE_BUTTON_WHEEL_UP else (-1 if bi == MOUSE_BUTTON_WHEEL_DOWN else 0)
	elif e is InputEventKey:
		var k: int = (e as InputEventKey).physical_keycode
		step = 1 if k == KEY_BRACKETRIGHT else (-1 if k == KEY_BRACKETLEFT else 0)
	if step == 0:
		return false
	radius = clampi(radius + step, R_MIN, R_MAX)
	return true


## Where the cursor's ray meets the level plane at height `y` within reach (null: it does not). A held stroke keeps its
## brush on the plane of its first press: the ground it raises would otherwise meet the ray nearer the camera every
## frame, and a still cursor would walk the brush toward the visitor (seen in the exe: a hill grew onto his feet).
func on_plane(y: float) -> Variant:
	var r: Array = host.ray()
	if r.is_empty():
		return null
	var from: Vector3 = r[0]
	var d: Vector3 = r[1]
	if absf(d.y) < 0.0001:
		return null
	var t := (y - from.y) / d.y
	if t <= 0.0 or t > float(host.reach(from)):
		return null
	return from + d * t


func layer() -> RefCounted:
	return host.build.layer("land") if host != null and host.build != null else null


## Vertices (`cells` false) or cells under the brush at `at`, with their falloff: [[Vector2i, weight 0..1], ...].
func under(at: Vector3, cells := false) -> Array:
	var out := []
	var r := metres()
	var off := 0.5 if cells else 0.0
	for j: int in range(floori((at.z - r) / LATTICE) - 1, ceili((at.z + r) / LATTICE) + 1):
		for i: int in range(floori((at.x - r) / LATTICE) - 1, ceili((at.x + r) / LATTICE) + 1):
			var d := Vector2((i + off) * LATTICE - at.x, (j + off) * LATTICE - at.z).length()
			if d <= r:
				var t := d / r
				out.append([Vector2i(i, j), 1.0 - smoothstep(FLAT_TOP, 1.0, t) if not cells else 1.0])
	return out


## Why `v` may not be edited now (asked once per stroke and remembered).
func refusal(v: Vector2i, what: String) -> String:
	if not _refused.has(v):
		_refused[v] = layer().refusal(v, what)
	return _refused[v]


func forget() -> void:
	_refused.clear()


## The first refusal under the brush at `at`, asked at its centre and at 8 points of its rim (every drawn frame, so a
## sample; the stroke asks every vertex it touches): the ring is red then.
func first_refusal(at: Vector3, what: String) -> String:
	var l := layer()
	var off := 0.5 if what == "paint" else 0.0
	var r := metres() * 0.85
	l.begin_asking(Rect2(at.x - metres() - 2 * LATTICE, at.z - metres() - 2 * LATTICE, 2 * metres() + 4 * LATTICE, 2 * metres() + 4 * LATTICE))
	var why := ""
	for s: int in 9:
		var p := Vector2(at.x, at.z) + (Vector2.ZERO if s == 0 else Vector2.from_angle(TAU * s / 8.0) * r)
		why = l.refusal(Vector2i(roundi(p.x / LATTICE - off), roundi(p.y / LATTICE - off)), what)
		if why != "":
			break
	l.end_asking()
	return why


## The ring at `at` (null: hidden), following the ground, red when `bad`.
func show_ring(at: Variant, bad := false) -> void:
	if ring == null:
		return
	if at == null:
		ring.visible = false
		return
	var c: Vector3 = at
	var l := layer()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _bad if bad else _ok)
	var r := metres()
	var prev := []
	for s: int in SEGMENTS + 1:
		var a := TAU * s / SEGMENTS
		var dir := Vector2(cos(a), sin(a))
		var pts := []
		for rr: float in [r - BAND, r + BAND]:
			var p := Vector2(c.x, c.z) + dir * rr
			pts.append(Vector3(p.x, float(l.height_at(p.x, p.y)) + LIFT, p.y))
		pts.append(float(s) / SEGMENTS)
		if not prev.is_empty():
			# uv: x along the ring, y 0 inner / 1 outer (the holo shader draws its edge lines there)
			for q: Array in [[prev, 0], [pts, 0], [pts, 1], [prev, 0], [pts, 1], [prev, 1]]:
				im.surface_set_normal(Vector3.UP)
				im.surface_set_uv(Vector2(float(q[0][2]), float(q[1])))
				im.surface_add_vertex(q[0][q[1]])
		prev = pts
	im.surface_end()
	ring.mesh = im
	ring.visible = true


func hide() -> void:
	if ring != null:
		ring.visible = false
