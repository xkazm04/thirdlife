## Created by boosts.gd in a rendered match. Cache kit geometry by appearance; these nodes never affect simulation.
extends RefCounted

var meshes := {}

## Lay out a segmented band with a fixed gap between adjacent bars.
static func ring(m: TLMesh, radius: float, y: float, width: float, key: String, segments: int, fraction: float) -> void:
	for i in segments:
		var a := TAU * i / segments
		var b := TAU * (i + fraction) / segments
		var p := Vector3(cos(a), 0, sin(a))
		var q := Vector3(cos(b), 0, sin(b))
		m.bar(p * radius + Vector3.UP * y, q * radius + Vector3.UP * y, width, width, key)

## Instance shared geometry without keeping retired arena nodes alive.
func part(parent: Node3D, mesh: ArrayMesh, label: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	parent.add_child(node)
	return node

## Keep the floor marker full size even when the beacon retracts.
func socket(key: String) -> ArrayMesh:
	var m := TLMesh.new(1)
	ring(m, 1.90, 0.065, 0.25, "bot_dark", 12, 0.88)
	ring(m, 1.90, 0.16, 0.18, key, 12, 0.84)
	return m.build("Socket")

## The illuminated column retracts independently of the floor marker.
func column(key: String) -> ArrayMesh:
	var m := TLMesh.new(1)
	m.cyl(0.65, 0.20, 8, "bot_dark")
	m.cyl(0.46, 0.34, 8, key)
	m.cyl(0.31, 2.30, 8, key)
	m.cyl(0.44, 0.18, 8, key, Color.WHITE, -1.0, Vector3.UP * 2.17)
	return m.build("Column")

## Build each collectible silhouette once in its catalogued colour.
func symbol(kind: String, key: String) -> ArrayMesh:
	var m := TLMesh.new(1)
	match kind:
		"speed": m.cyl(0.52, 0.95, 8, key, Color.WHITE, 0, Vector3.DOWN * 0.4)
		"precision":
			m.push_at(Vector3.ZERO, Vector3(35,0,45))
			m.box(Vector3.ONE * 0.77, key, Color.WHITE, 0.08)
			m.pop()
		"big_puck": m.blob(Vector3.ONE * 0.52, 2, 0, key)
		"heavy_puck": m.cyl(0.57, 0.28, 16, key)
		"shotgun":
			for x in [-0.29, 0.0, 0.29]:
				m.cyl(0.12, 0.85, 6, key, Color.WHITE, 0.05, Vector3(x,-0.32,0))
		"hip_check":
			for side in [-1,1]:
				m.bar(Vector3(side * 0.49,-0.28,0),Vector3(0,0.36,0),0.25,0.32,key)
		"shield":
			m.blob(Vector3(0.54,0.66,0.24),1,0,key)
		"slow_puck":
			m.cyl(0.4, 0.43, 8, key, Color.WHITE, 0.09, Vector3.DOWN * 0.43)
			m.cyl(0.09, 0.43, 8, key, Color.WHITE, 0.4)
	return m.build("Glyph")

## Put a rotating glyph over its fixed foot. First use bakes the meshes outside the arena build.
func beacon(parent: Node3D, pos: Vector3, kind: String, key: String) -> Node3D:
	var base := Node3D.new()
	base.position = pos
	parent.add_child(base)
	var socket_key := "socket_" + key
	var column_key := "column_" + key
	if not meshes.has(socket_key):
		meshes[socket_key] = socket(key)
		meshes[column_key] = column(key)
	if not meshes.has(kind):
		meshes[kind] = symbol(kind, key)
	part(base, meshes[socket_key], "Socket")
	var mast := part(base, meshes[column_key], "Column")
	mast.scale = Vector3.ONE * 0.7
	part(base, meshes[kind], "Glyph")
	pose(base, 3.0, 0)
	return base

## From two metres inward the glyph is one third height and the column is a faded stub.
func pose(base: Node3D, distance: float, frame: int) -> void:
	var raised := smoothstep(2.0, 3.0, distance)
	var profile := lerpf(1.0 / 3.0, 1.0, raised)
	var mast: MeshInstance3D = base.get_node("Column")
	mast.scale.y = lerpf(0.12, 0.7, raised)
	mast.transparency = 0.55 * (1.0 - raised)
	var glyph: Node3D = base.get_node("Glyph")
	glyph.rotation.y = frame * 0.036
	glyph.scale = Vector3.ONE * 1.89 * profile
	glyph.position.y = (2.17 + 0.10 * sin(frame * 0.065)) * profile

## Share each equipped ring across skaters, including the open shield shell.
func aura(parent: Node3D, key: String, shield: bool) -> Node3D:
	var id := "ring_" + key + ("_shield" if shield else "")
	if not meshes.has(id):
		meshes[id] = band(key, shield)
	return part(parent, meshes[id], "AbilityRing")

## Bake a waist band with optional meridians so the jersey remains visible.
func band(key: String, shield: bool) -> ArrayMesh:
	var m := TLMesh.new(1)
	ring(m, 1.34 if shield else 1.0, 0, 0.14, key, 10, 0.61)
	if shield:
		# Open meridians leave the jersey readable through the hologram on bright ice.
		for i in 6:
			var radial := Vector3(cos(i*TAU/6),0,sin(i*TAU/6)) * 1.55
			for j in 12:
				var a := lerpf(-1.32,1.32,j/12.0)
				var b := lerpf(-1.32,1.32,(j+1)/12.0)
				m.bar(radial*cos(a)+Vector3.UP*2.13*sin(a),radial*cos(b)+Vector3.UP*2.13*sin(b),0.075,0.075,"holo")
		ring(m,0.4,2.05,0.08,"holo",16,1.0)
		ring(m,0.4,-2.05,0.08,"holo",16,1.0)
	return m.build("AbilityRing")

## A hot puck and a tapered red core give the additive trail contrast on daylight ice.
func slug(puck: Node3D) -> Node3D:
	if not meshes.has("slug"):
		var m := TLMesh.new(1)
		m.cyl_between(Vector3.UP * 0.12, Vector3(-2.60, 0.12, 0), 0.48, 8, "tail_light", Color.WHITE, 0.025)
		m.cyl(0.52, 0.26, 12, "neon_pink")
		m.cyl(0.29, 0.28, 12, "head_light")
		meshes.slug = m.build("ShotgunPuck")
	var node := part(puck, meshes.slug, "ShotgunPuck")
	node.position.y = 0.22
	return node
