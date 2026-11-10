class_name Fx
extends RefCounted
## Particle kit (CPUParticles3D, billboard quads, flat colours from the palette): sparks, dust burst, smoke, nitro trail.

static var _add: ShaderMaterial
static var _mix: ShaderMaterial


static func _quad(additive: bool) -> QuadMesh:
	if _add == null:
		_add = ShaderMaterial.new()
		_add.shader = load("res://shaders/fx_add.gdshader")
		_mix = ShaderMaterial.new()
		_mix.shader = load("res://shaders/fx_mix.gdshader")
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = _add if additive else _mix
	return q


static var _puffs: Dictionary = {}


## Inked cartoon puff: a low-poly toon blob (so the ink pass outlines it) that grows and shrinks. In-style dust/smoke.
static func _puff(key: String) -> Mesh:
	if not _puffs.has(key):
		var mk: MK = MK.new(5)
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
	var c: Color = Color(Style.data["palette"][key])
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
	m.shader = load("res://shaders/fx_add.gdshader")
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
	m.shader = load("res://shaders/fx_mix.gdshader")
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
	var a: float = float(Style.data.get("fx", {}).get("dust_alpha", 0.2))
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
