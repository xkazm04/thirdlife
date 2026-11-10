class_name Fx
extends RefCounted
## Voxel-style particles: every particle is a small cube (GPUParticles3D + BoxMesh).


static func _unshaded_mat(c: Color, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	if emit > 0.0:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(c.r * emit, c.g * emit, c.b * emit, 1.0)
	else:
		m.albedo_color = c
		m.roughness = 1.0
	return m


static func _ramp(cols: Array, offs: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	g.colors = PackedColorArray(cols)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _make(parent: Node3D, amount: int, life: float, size: float, mat: StandardMaterial3D, pm: ParticleProcessMaterial, local: bool = false) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size, size, size)
	bm.material = mat
	p.draw_pass_1 = bm
	p.amount = amount
	p.lifetime = life
	p.local_coords = local
	p.process_material = pm
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	p.fixed_fps = 0
	parent.add_child(p)
	return p


static func sparks(parent: Node3D) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.6, 1)
	pm.spread = 55.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, -7.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pm.color_ramp = _ramp([Color(1, 0.95, 0.6, 1), Color(1, 0.55, 0.15, 1), Color(0.4, 0.1, 0.0, 0)], [0.0, 0.4, 1.0])
	return _make(parent, 24, 0.5, 0.03, _unshaded_mat(Color(1, 0.8, 0.4), 5.0), pm)


static func dust(parent: Node3D) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.4, 0)
	pm.spread = 80.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 3.2
	pm.gravity = Vector3(0, 0.15, 0)
	pm.damping_min = 0.8
	pm.damping_max = 1.6
	pm.scale_min = 0.5
	pm.scale_max = 2.4
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1.0, 0.4, 0.5)
	pm.color_ramp = _ramp([Color(0.78, 0.7, 0.6, 0.75), Color(0.7, 0.62, 0.52, 0.45), Color(0.65, 0.58, 0.5, 0.0)], [0.0, 0.5, 1.0])
	var m := _unshaded_mat(Color(1, 1, 1))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.82, 0.74, 0.62, 1)
	return _make(parent, 160, 2.6, 0.22, m, pm)


static func flame(parent: Node3D) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 9.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.color_ramp = _ramp([Color(0.7, 0.9, 1.0, 1), Color(1.0, 0.75, 0.25, 1), Color(1.0, 0.25, 0.05, 1), Color(0.2, 0.05, 0.02, 0)], [0.0, 0.2, 0.6, 1.0])
	return _make(parent, 90, 0.55, 0.11, _unshaded_mat(Color(1, 0.85, 0.5), 4.5), pm)


static func trail(parent: Node3D) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.2, 1)
	pm.spread = 14.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 2.0
	pm.gravity = Vector3(0, 0.1, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.8
	pm.color_ramp = _ramp([Color(1.0, 0.55, 0.25, 0.9), Color(0.8, 0.3, 0.15, 0.5), Color(0.3, 0.2, 0.2, 0.0)], [0.0, 0.4, 1.0])
	var m := _unshaded_mat(Color(1, 0.7, 0.4), 2.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return _make(parent, 140, 1.4, 0.16, m, pm)


static func smoke(parent: Node3D) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.3, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0.25, 0.1, 0)
	pm.scale_min = 0.8
	pm.scale_max = 2.0
	pm.color_ramp = _ramp([Color(0.85, 0.83, 0.8, 0.9), Color(0.8, 0.78, 0.76, 0.5), Color(0.8, 0.8, 0.8, 0.0)], [0.0, 0.5, 1.0])
	var m := _unshaded_mat(Color(1, 1, 1))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.88, 0.84, 0.8, 1)
	return _make(parent, 28, 5.0, 0.3, m, pm)
