extends MeshInstance3D
## F2 (27 Nov 2026 day, playtest #3 and #7): the refused ground round the cursor, drawn while a ground tool or a stamp
## is in the hand (buildable.gd `cells`): each refused 3 m cell a see-through red film on the ground, and a denser red
## band along its sides that face buildable ground, so the edge of where you may build shows before you reach it. The
## style's own material for its palette's `hazard_red` (TLStyle.material_instance: the glass look, alpha blended), two
## private copies with their opacity raised; no hand-made material. (The holo look is added light: red added to sunlit
## grass reads as a warmer grass, not as "no", seen in the window on 27 Nov.) Redrawn only when the cells change; left
## out of physics interpolation; never casts a shadow.

const LATTICE := 3.0
const LIFT := 0.12                      # metres over the ground
const BAND := 0.45                      # metres: the edge band's width, inside the refused cell
const FILL_A := 0.34                    # the film's opacity (glass `base_a`)
const EDGE_A := 0.85                    # the edge band's
const SIDES := [[Vector2i(0, -1), Vector2(0, 0), Vector2(1, 0)], [Vector2i(1, 0), Vector2(1, 0), Vector2(1, 1)],
	[Vector2i(0, 1), Vector2(1, 1), Vector2(0, 1)], [Vector2i(-1, 0), Vector2(0, 1), Vector2(0, 0)]]

var drawn := ""                         # buildable.gd `tint_key` drawn now ("" nothing)
var count := 0                          # cells drawn
var edges := 0                          # edge bands drawn
var _fill: Material
var _edge: Material


func _init() -> void:
	name = "RefusalTint"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_fill = _red(FILL_A)
	_edge = _red(EDGE_A)
	visible = false


static func _red(a: float) -> Material:
	var m := TLStyle.material_instance("hazard_red")
	if m is ShaderMaterial and not TLStyle.headless():
		(m as ShaderMaterial).set_shader_parameter(&"base_a", a)
		(m as ShaderMaterial).set_shader_parameter(&"fres_a", 0.15)
	return m


## Draws `cells` ([[Vector2i, reason], ...]) under the key `key`, the edge bands only toward the cells of `free`
## (Vector2i -> true: asked and buildable; a band at the tint's own rim would only mark how far it was asked);
## `height` (x, z) -> the ground's height, or invalid (then `y` everywhere).
func show_cells(cells: Array, key: String, height: Callable, y := 0.0, free := {}) -> void:
	if cells.is_empty():
		hide_tint()
		return
	if key == drawn and visible:
		return
	drawn = key
	count = cells.size()
	edges = 0
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _fill)
	for e: Array in cells:
		var o := Vector2(e[0] as Vector2i) * LATTICE
		_quad(im, _at(o, height, y), _at(o + Vector2(LATTICE, 0), height, y), _at(o + Vector2(LATTICE, LATTICE), height, y),
			_at(o + Vector2(0, LATTICE), height, y))
	im.surface_end()
	var bands := []
	for e: Array in cells:
		var c: Vector2i = e[0]
		var o := Vector2(c) * LATTICE
		for s: Array in SIDES:
			if not free.has(c + (s[0] as Vector2i)):
				continue
			var a: Vector2 = o + (s[1] as Vector2) * LATTICE
			var b: Vector2 = o + (s[2] as Vector2) * LATTICE
			var inward := (o + Vector2.ONE * LATTICE * 0.5 - (a + b) * 0.5).normalized() * BAND
			bands.append([_at(a, height, y, 0.02), _at(b, height, y, 0.02), _at(b + inward, height, y, 0.02), _at(a + inward, height, y, 0.02)])
	if not bands.is_empty():
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _edge)
		for q: Array in bands:
			_quad(im, q[0], q[1], q[2], q[3])
		im.surface_end()
	edges = bands.size()
	mesh = im
	visible = true


func hide_tint() -> void:
	visible = false
	drawn = ""
	count = 0
	edges = 0


static func _at(v: Vector2, height: Callable, y: float, up := 0.0) -> Vector3:
	return Vector3(v.x, (float(height.call(v.x, v.y)) if height.is_valid() else y) + LIFT + up, v.y)


## A quad a b c d, both windings (the glass look culls back faces; the ground is seen from above and, from a slope's
## foot, from below its lip).
static func _quad(im: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for p: Vector3 in [a, b, c, a, c, d, a, c, b, a, d, c]:
		im.surface_set_normal(Vector3.UP)
		im.surface_add_vertex(p)
