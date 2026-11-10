class_name TLStyleFx
extends RefCounted
## Particle kit (CPUParticles3D, billboard quads, flat colours from the palette): sparks, dust burst, smoke, nitro trail.

static var _add: ShaderMaterial
static var _mix: ShaderMaterial


static func _quad(additive: bool) -> QuadMesh:
	if _add == null:
		_add = ShaderMaterial.new()
		_add.shader = load("res://style/shaders/fx_add.gdshader")
		_mix = ShaderMaterial.new()
		_mix.shader = load("res://style/shaders/fx_mix.gdshader")
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = _add if additive else _mix
	return q


static var _puffs: Dictionary = {}


## Inked cartoon puff: a low-poly toon blob (so the ink pass outlines it) that grows and shrinks. In-style dust/smoke.
static func _puff(key: String) -> Mesh:
	if not _puffs.has(key):
		var mk: TLMesh = TLMesh.new(5)
		mk.blob(Vector3(0.5, 0.42, 0.5), 1, 0.16, key, Color.WHITE, 0.04)
		_puffs[key] = mk.build("puff_" + key)
	return _puffs[key]


static func _hump(peak_at: float = 0.25, start: float = 0.25) -> Curve:
	var c: Curve = Curve.new()
	c.add_point(Vector2(0, start))
	c.add_point(Vector2(peak_at, 1.0))
	c.add_point(Vector2(1, 0.0))
	return c


static func _pal(key: String, a: float = 1.0) -> Color:
	var c: Color = Color(TLStyle.data["palette"][key])
	c.a = a
	return c


static func _ramp(cols: Array) -> Gradient:
	var g: Gradient = Gradient.new()
	var offs: PackedFloat32Array = PackedFloat32Array()
	var cs: PackedColorArray = PackedColorArray()
	for i: int in cols.size():
		offs.append(float(i) / float(cols.size() - 1))
		cs.append(cols[i])
	g.offsets = offs
	g.colors = cs
	return g


static func _curve(a: float, b: float) -> Curve:
	var c: Curve = Curve.new()
	c.max_value = maxf(maxf(a, b), 1.0) * 1.01
	c.add_point(Vector2(0, a))
	c.add_point(Vector2(1, b))
	return c


## A soft additive billboard (beacon, weld flash) that reads at distance. Scale the node to size it; pulse it in the sim.
static func glow(key: String, soft: float = 0.0) -> MeshInstance3D:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load("res://style/shaders/fx_add.gdshader")
	m.set_shader_parameter("tint", _pal(key))
	m.set_shader_parameter("soft", soft)
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = m
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	return mi


static func sparks() -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.name = "Sparks"
	p.mesh = _quad(true)
	p.amount = 40
	p.lifetime = 0.5
	p.randomness = 0.6
	p.local_coords = false
	p.direction = Vector3(0, 1, 0)
	p.spread = 75.0
	p.gravity = Vector3(0, -7.0, 0)
	p.initial_velocity_min = 1.8
	p.initial_velocity_max = 5.0
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.12
	p.scale_amount_curve = _curve(1.0, 0.2)
	p.color_ramp = _ramp([_pal("flame_core"), _pal("spark"), _pal("hot", 0.9), _pal("hot", 0.0)])
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var f: CPUParticles3D = CPUParticles3D.new()
	f.name = "Flash"
	f.mesh = _quad(true)
	f.amount = 3
	f.lifetime = 0.14
	f.randomness = 1.0
	f.gravity = Vector3.ZERO
	f.initial_velocity_max = 0.0
	f.scale_amount_min = 0.12
	f.scale_amount_max = 0.3
	f.color_ramp = _ramp([_pal("flame_core", 0.9), _pal("cyan", 0.5), _pal("cyan", 0.0)])
	f.emitting = false
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(f)
	return p


static func _soft_quad() -> QuadMesh:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load("res://style/shaders/fx_mix.gdshader")
	m.set_shader_parameter("soft", 0.0)
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = m
	return q


## Dust that reads as dust: thin, warm, soft-edged billboards that puff out and are almost gone after a second, so the
## break itself (slabs, core faces, rebar) stays readable. Colour and opacity are style data (palette.dust, fx.dust_alpha).
static func dust_burst(amount: int = 70, radius: float = 2.5) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.name = "Dust"
	p.mesh = _soft_quad()
	p.amount = amount
	p.lifetime = 2.0
	p.one_shot = true
	p.explosiveness = 0.96
	p.randomness = 0.5
	p.lifetime_randomness = 0.45
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(radius, 0.3, 0.7)
	p.direction = Vector3(0, 1, 0)
	p.spread = 80.0
	p.gravity = Vector3(0, 0.35, 0)
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 3.4
	p.damping_min = 1.6
	p.damping_max = 3.0
	p.scale_amount_min = 2.4
	p.scale_amount_max = 4.4
	p.scale_amount_curve = _curve(0.3, 1.0)
	var a: float = float(TLStyle.data.get("fx", {}).get("dust_alpha", 0.2))
	p.color_ramp = _ramp([_pal("dust", 0.0), _pal("dust", a), _pal("dust", a * 0.45), _pal("dust", a * 0.16), _pal("dust", 0.0)])
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static func smoke() -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.name = "Smoke"
	p.mesh = _soft_quad()
	p.amount = 34
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.local_coords = false
	p.direction = Vector3(0.35, 1, 0.1)
	p.spread = 7.0
	p.gravity = Vector3(0.16, 0.04, 0.0)
	p.initial_velocity_min = 0.9
	p.initial_velocity_max = 1.2
	p.scale_amount_min = 1.4
	p.scale_amount_max = 2.4
	p.scale_amount_curve = _curve(0.3, 1.0)
	p.color_ramp = _ramp([_pal("smoke", 0.0), _pal("smoke", 0.4), _pal("smoke", 0.22), _pal("smoke", 0.0)])
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static func nitro_trail() -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.name = "NitroTrail"
	p.mesh = _quad(true)
	p.amount = 260
	p.lifetime = 0.5
	p.local_coords = false
	p.direction = Vector3(0, 0, 1)
	p.spread = 6.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.scale_amount_min = 0.55
	p.scale_amount_max = 0.85
	p.scale_amount_curve = _curve(1.0, 0.2)
	p.color_ramp = _ramp([_pal("flame_core"), _pal("hot"), Color(0.75, 0.3, 1.0, 0.8), Color(0.3, 0.4, 1.0, 0.0)])
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static func tyre_dust() -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.name = "TyreDust"
	p.mesh = _soft_quad()
	p.emitting = false
	p.amount = 22
	p.lifetime = 1.1
	p.local_coords = false
	p.direction = Vector3(0, 0.5, 1)
	p.spread = 25.0
	p.gravity = Vector3(0, 0.3, 0)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.6
	p.scale_amount_min = 0.9
	p.scale_amount_max = 1.8
	p.scale_amount_curve = _curve(0.4, 1.0)
	p.color_ramp = _ramp([_pal("dust", 0.0), _pal("dust", 0.35), _pal("dust", 0.0)])
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


# ------------------------------------------------------------------------------------------- WP5: kernel presets
static var _discs: Dictionary = {}


static func _disc(softness: float, additive: bool = false) -> QuadMesh:
	var key: String = "%s%.2f" % ["a" if additive else "m", softness]
	if not _discs.has(key):
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = load("res://style/shaders/fx_add.gdshader" if additive else "res://style/shaders/fx_mix.gdshader")
		m.set_shader_parameter("soft", softness)
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(1, 1)
		q.material = m
		_discs[key] = q
	return _discs[key]


static func _pk(key: String, a: float = 1.0) -> Color:
	var c: Color = TLStyle.color(key) if TLStyle.has_key(key) else Color.WHITE
	c.a = a
	return c


static func _fade(c: Color, alphas: Array) -> Gradient:
	var cols: Array = []
	for a: float in alphas:
		cols.append(Color(c.r, c.g, c.b, a))
	return _ramp(cols)


static func preset_names() -> PackedStringArray:
	return PackedStringArray(["dust", "sparks", "smoke", "ice_spray", "debris", "nitro_flame", "confetti", "splash", "goal_flash"])


## The in-style effect for a kernel `TLVfx` preset name (contracts/KIT-RIG-STYLE.md, second-round amendment): round
## soft discs in palette colours for dust, smoke, spray and splash, additive discs for sparks and flames, inked toon
## chips for debris. Returns null headless and for a name it does not know (the kernel then uses its stand-in).
## Options: `life_frames` (particle lifetime in physics frames), `one_shot` (bool), `direction` (Vector3),
## `scale` (float), `color` (Color: replaces the palette colour).
static func preset(pname: String, opts: Dictionary = {}) -> CPUParticles3D:
	TLStyle.ensure()
	if TLStyle.headless() or TLStyle.data.is_empty() or not preset_names().has(pname):
		return null
	var s: float = float(opts.get("scale", 1.0))
	var one_shot: bool = bool(opts.get("one_shot", true))
	var has_tint: bool = opts.has("color")
	var tint: Color = opts.get("color", Color.WHITE)
	var p: CPUParticles3D = CPUParticles3D.new()
	p.name = "Fx_" + pname
	p.local_coords = false
	p.one_shot = one_shot
	p.explosiveness = 0.92 if one_shot else 0.0
	p.lifetime = maxf(float(opts.get("life_frames", 60)) / 60.0, 0.05)
	p.direction = opts.get("direction", Vector3.UP)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match pname:
		"dust":
			var a: float = clampf(float((TLStyle.data.get("fx", {}) as Dictionary).get("dust_alpha", 0.2)) * 2.2, 0.3, 0.6)
			_shape(p, _disc(0.0), 12, 70.0, Vector3(0, 0.35, 0), 0.3 * s, 1.4 * s, 0.7 * s, 1.3 * s, _curve(0.3, 1.0))
			p.damping_min = 1.6
			p.damping_max = 3.0
			p.lifetime_randomness = 0.3
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 0.25 * s
			p.color_ramp = _fade(tint if has_tint else _pk("dust"), [0.0, a, a * 0.45, 0.0])
		"smoke":
			_shape(p, _disc(0.0), 16, 12.0, Vector3(0.16, 0.3, 0), 0.6 * s, 1.1 * s, 0.6 * s, 1.1 * s, _curve(0.3, 1.0))
			p.color_ramp = _fade(tint if has_tint else _pk("smoke"), [0.0, 0.4, 0.22, 0.0])
		"sparks":
			_shape(p, _disc(0.55, true), 30, 60.0, Vector3(0, -7.0, 0), 1.8 * s, 5.0 * s, 0.05 * s, 0.12 * s, _curve(1.0, 0.2))
			p.color_ramp = _ramp([_pk("flame_core"), _pk("spark"), _pk("hot", 0.9), _pk("hot", 0.0)])
			if has_tint:
				p.color = tint
		"ice_spray":
			_shape(p, _disc(0.5), 30, 45.0, Vector3(0, -6.0, 0), 1.5 * s, 4.0 * s, 0.06 * s, 0.16 * s, _curve(1.0, 0.3))
			p.color_ramp = _fade(tint if has_tint else _pk("ice"), [0.95, 0.8, 0.0])
		"debris":
			# opaque toon chips: the ink pass outlines them and the sun lights them; they shrink away instead of fading
			_shape(p, _puff("white"), 10, 55.0, Vector3(0, -9.8, 0), 1.5 * s, 4.0 * s, 0.10 * s, 0.24 * s, _curve(1.0, 0.3))
			var dc: Color = tint if has_tint else _pk("concrete")
			dc.a = 1.0
			p.color = dc
		"nitro_flame":
			_shape(p, _disc(0.55, true), 48, 6.0, Vector3.ZERO, 1.0 * s, 3.0 * s, 0.22 * s, 0.4 * s, _curve(1.0, 0.2))
			p.color_ramp = _ramp([_pk("flame_core"), _pk("hot"), Color(0.75, 0.3, 1.0, 0.8), Color(0.3, 0.4, 1.0, 0.0)])
			if has_tint:
				p.color = tint
		"confetti":
			_shape(p, _disc(0.85), 60, 60.0, Vector3(0, -4.0, 0), 3.0 * s, 6.0 * s, 0.07 * s, 0.12 * s, _curve(1.0, 0.8))
			p.damping_min = 1.0
			p.damping_max = 2.0
			if has_tint:
				p.color = tint
			else:
				p.color_initial_ramp = _ramp([_pk("curb_red"), _pk("spark"), _pk("cyan"), _pk("white"), _pk("hot")])
			p.color_ramp = _fade(Color.WHITE, [1.0, 1.0, 0.0])
		"splash":
			_shape(p, _disc(0.4), 30, 70.0, Vector3(0, -9.8, 0), 2.0 * s, 4.5 * s, 0.08 * s, 0.18 * s, _curve(1.0, 0.4))
			p.color_ramp = _fade(tint if has_tint else _pk("water").lerp(Color.WHITE, 0.5), [0.9, 0.7, 0.0])
		"goal_flash":
			_shape(p, _disc(0.3, true), 40, 180.0, Vector3.ZERO, 3.0 * s, 8.0 * s, 0.15 * s, 0.4 * s, _curve(1.0, 0.1))
			p.damping_min = 4.0
			p.damping_max = 6.0
			p.color_ramp = _ramp([_pk("flame_core"), _pk("spark"), _pk("hot", 0.6), _pk("hot", 0.0)])
			if has_tint:
				p.color = tint
	p.emitting = true
	return p


static func _shape(p: CPUParticles3D, mesh: Mesh, amount: int, spread: float, gravity: Vector3, v_min: float, v_max: float,
		size_min: float, size_max: float, size_curve: Curve) -> void:
	p.mesh = mesh
	p.amount = amount
	p.spread = spread
	p.gravity = gravity
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	p.scale_amount_curve = size_curve
