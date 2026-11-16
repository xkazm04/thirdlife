## H1: the reach ring under the human skater, built with the kit's own toolbox (TLMesh, palette key, style material).
## A flat annulus on the ice whose outer edge is the carry reach: a loose puck inside it is his. Geometry made in a
## generator is counted by lint as `kit_parts_added`; it is no physics body, so the state hash does not see it.
## L1: the same annulus under a name (the carrier's ring), and the puck's rim (an annulus round the puck's drawn edge).
static func generate(ctx) -> void:
	ctx.root.set_meta('hockey_ring', 'gen/ring_hook.gd')


static func make_ring(holder: Node3D, radius: float, width: float, key: String, node_name: String = "ReachRing", y: float = 0.02) -> MeshInstance3D:
	var mk: TLMesh = TLMesh.new(1)
	var seg: int = 48
	var r0: float = maxf(radius - width, 0.01)
	for i: int in seg:
		var a0: float = TAU * float(i) / float(seg)
		var a1: float = TAU * float(i + 1) / float(seg)
		mk.quad_up(Vector3(cos(a0) * r0, y, sin(a0) * r0), Vector3(cos(a1) * r0, y, sin(a1) * r0),
			Vector3(cos(a1) * radius, y, sin(a1) * radius), Vector3(cos(a0) * radius, y, sin(a0) * radius), key)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mk.build("reach_ring")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mi)
	return mi
