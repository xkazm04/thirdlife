class_name Wall
extends Node3D
## Barrier wall: 12 intact concrete blocks (one voxel mesh each, static). `crumble()` swaps each for its pre-baked
## voxel clusters (Voronoi split of the SAME voxel grid, convex-hull colliders) + shards + dust. Jolt does the rest.

var style: Style
var blocks: Array = []
var intact: Array = []
var debris: Array = []
var shards: Array = []
var dust: Array = []
var variants: Array = []
var shard_meshes: Array = []
var block_mesh: ArrayMesh
var crumbled: bool = false
var crumble_clock: float = -1.0
var pending: Array = []
var hull_cache: Dictionary = {}
var settled_at: float = -1.0
var sim_since: float = 0.0
var stat_bodies: int = 0


func setup(st: Style, layout: Array) -> void:
	style = st
	blocks = layout
	block_mesh = Vxm.load_mesh("res://assets/wall_block.vxm", st)
	for v in 3:
		variants.append(Vxm.load_chunks("res://assets/wall_debris%d.vxm" % v, st))
	for s in 4:
		shard_meshes.append(Vxm.load_mesh("res://assets/shard%d.vxm" % s, st))
	for i in blocks.size():
		var b: Dictionary = blocks[i]
		var n := Node3D.new()
		n.position = Vector3(b["x"], b["y"], b["z"])
		n.rotation.y = float(b["yaw"]) + PI / 2.0
		add_child(n)
		var mi := MeshInstance3D.new()
		mi.mesh = block_mesh
		n.add_child(mi)
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(2.4, 1.0, 0.8)
		cs.shape = bs
		cs.position = Vector3(0, 0.5, 0)
		sb.add_child(cs)
		n.add_child(sb)
		intact.append(n)
		var d := Fx.dust(self)
		d.one_shot = true
		d.explosiveness = 0.85
		d.position = n.position + Vector3(0, 0.6, 0)
		dust.append(d)


func crumble(impact_idx: int = 5) -> void:
	if crumbled:
		return
	crumbled = true
	crumble_clock = 0.0
	sim_since = 0.0
	pending.clear()
	for i in blocks.size():
		pending.append({"i": i, "delay": absf(i - impact_idx) * 0.07})


func _spawn_block(i: int) -> void:
	var b: Dictionary = blocks[i]
	var node: Node3D = intact[i]
	var xf := node.global_transform
	node.visible = false
	for ch in node.get_children():
		if ch is StaticBody3D:
			(ch as StaticBody3D).process_mode = Node.PROCESS_MODE_DISABLED
			for c2 in ch.get_children():
				if c2 is CollisionShape3D:
					(c2 as CollisionShape3D).disabled = true
	var tn := Vector2(b["tn"][0], b["tn"][1])
	var perp := Vector3(tn.y, 0, -tn.x)
	if perp.dot(Vector3(b["x"] - 40.0, 0, b["z"] + 75.0)) < 0:
		perp = -perp
	var chunks: Array = variants[i % 3]
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + i
	for k in chunks.size():
		var ch: Dictionary = chunks[k]
		var rb := RigidBody3D.new()
		var piv: Vector3 = ch["pivot"]
		rb.global_transform = xf * Transform3D(Basis.IDENTITY, piv)
		add_child(rb)
		var mi := MeshInstance3D.new()
		mi.mesh = ch["mesh"]
		rb.add_child(mi)
		var cs := CollisionShape3D.new()
		var key := "%d_%d" % [i % 3, k]
		if not hull_cache.has(key):
			hull_cache[key] = (ch["mesh"] as ArrayMesh).create_convex_shape(true, true)
		cs.shape = hull_cache[key]
		rb.add_child(cs)
		rb.mass = 55.0
		rb.linear_damp = 0.25
		rb.angular_damp = 0.5
		rb.continuous_cd = false
		var pm := PhysicsMaterial.new()
		pm.friction = 0.9
		pm.bounce = 0.12
		rb.physics_material_override = pm
		var local_c := (piv)
		var out := perp * rng.randf_range(2.0, 6.5) + Vector3(0, rng.randf_range(2.0, 5.5), 0) + (xf.basis * Vector3(local_c.x, 0, 0)).normalized() * rng.randf_range(0.5, 2.0)
		rb.linear_velocity = out
		rb.angular_velocity = Vector3(rng.randf_range(-4, 4), rng.randf_range(-4, 4), rng.randf_range(-4, 4))
		debris.append(rb)
	for s in 6:
		var rb := RigidBody3D.new()
		rb.global_transform = xf * Transform3D(Basis.IDENTITY, Vector3(rng.randf_range(-1.1, 1.1), rng.randf_range(0.2, 0.9), rng.randf_range(-0.3, 0.3)))
		add_child(rb)
		var mi := MeshInstance3D.new()
		mi.mesh = shard_meshes[s % 4]
		rb.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.2, 0.2, 0.2)
		cs.shape = bs
		rb.add_child(cs)
		rb.mass = 6.0
		rb.linear_damp = 0.2
		rb.linear_velocity = perp * rng.randf_range(3.0, 9.0) + Vector3(rng.randf_range(-2, 2), rng.randf_range(3.0, 7.0), rng.randf_range(-2, 2))
		rb.angular_velocity = Vector3(rng.randf_range(-9, 9), rng.randf_range(-9, 9), rng.randf_range(-9, 9))
		shards.append(rb)
	dust[i].global_position = xf.origin + Vector3(0, 0.6, 0) + perp * 0.5
	dust[i].emitting = true
	stat_bodies = debris.size() + shards.size()


func _physics_process(delta: float) -> void:
	if not crumbled:
		return
	crumble_clock += delta
	sim_since += delta
	var rest: Array = []
	for p: Dictionary in pending:
		if crumble_clock >= p["delay"]:
			_spawn_block(p["i"])
		else:
			rest.append(p)
	pending = rest


func sleeping_count() -> Vector2i:
	var s := 0
	for rb: RigidBody3D in debris:
		if rb.sleeping:
			s += 1
	for rb2: RigidBody3D in shards:
		if rb2.sleeping:
			s += 1
	return Vector2i(s, debris.size() + shards.size())


func reset() -> void:
	crumbled = false
	crumble_clock = -1.0
	pending.clear()
	for rb: RigidBody3D in debris:
		rb.queue_free()
	for rb2: RigidBody3D in shards:
		rb2.queue_free()
	debris.clear()
	shards.clear()
	for n: Node3D in intact:
		n.visible = true
		for ch in n.get_children():
			if ch is StaticBody3D:
				(ch as StaticBody3D).process_mode = Node.PROCESS_MODE_INHERIT
				for c2 in ch.get_children():
					if c2 is CollisionShape3D:
						(c2 as CollisionShape3D).disabled = false
	for d: GPUParticles3D in dust:
		d.emitting = false
