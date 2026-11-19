extends SceneTree
## Headless clearance regression. Each isolated patch carries one of the village kit trees.
## The production space gets the recipe and transform, the scratch space gets the kit's output mesh.
const Space := preload("res://kernel/world/terrain/world_space.gd")
const Visitor := preload("res://kernel/world/visitor.gd")
const Oracle := preload("res://kernel/world/walks/crown_oracle.gd")
const SETTLE := 12
var space := Space.new()
var oracle := Oracle.new()
var batches := []
var trees: Array[Vector3] = []


func _initialize() -> void:
	physics_frame.connect(_run, CONNECT_ONE_SHOT)


func _plant(recipe: TLMesh, scales: Vector2, stretch: Vector2, trunk: float, sink: float, part_count := 5) -> bool:
	var parts := oracle.parts_of(recipe.build("test_tree"))
	if parts.size() != part_count:
		return false
	var xs := []
	batches.append([recipe, xs])
	for i in 3:
		var sc := lerpf(scales.x, scales.y, 0.5 * i)
		var sy := sc * lerpf(stretch.y, stretch.x, 0.5 * i)
		var centre := Vector3(40.0 * trees.size(), 0, 0)
		var slope := tan(deg_to_rad([-15.0, 0.0, 18.0][i]))
		var a := centre + Vector3(-18, -18 * slope, -18)
		var b := centre + Vector3(18, -18 * slope, -18)
		var c := centre + Vector3(18, 18 * slope, 18)
		var d := centre + Vector3(-18, 18 * slope, 18)
		space.add_faces(PackedVector3Array([a, b, c, a, c, d]))
		var yaw := TAU * fmod(0.381966 * trees.size(), 1.0)
		var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(sc, sy, sc)), centre + Vector3.UP * sink)
		xs.append(xf)
		if trunk > 0.0:
			space.add_trunk(xf.origin, sc * trunk)
		oracle.place(parts, xf)
		trees.append(xf.origin)
	return true


func _build() -> bool:
	space.set("crown_batches", batches)
	space.tag = "tree"
	for v in 3:
		if not _plant(TLKitNature.pine(100 + v, 8.5 + 2 * v, 5, 2.1 + 0.3 * v), Vector2(0.8, 1.35), Vector2(0.9, 1.15), 0.42, -0.2):
			return false
	if not _plant(TLKitNature.broadleaf(120, 7.5), Vector2(0.8, 1.3), Vector2(0.9, 1.15), 0.5, 0.0):
		return false
	if not _plant(TLKitNature.broadleaf(121, 6.5), Vector2(0.75, 1.2), Vector2(0.9, 1.15), 0.5, 0.0):
		return false
	for v in 2:
		if not _plant(TLKitNature.pine(110 + v, 10.0 + 2.5 * v, 5, 2.4 + 0.3 * v), Vector2(0.9, 1.7), Vector2(0.95, 1.2), 0.5, -0.2):
			return false
	# Clumps, mesa foot and cap all use the four-cone recipe. They have no solid trunk.
	# Other village seeds may place one of them within camera reach of the terrain.
	var mesa := TLKitNature.pine(130, 10.0, 4, 2.6)
	if not _plant(mesa, Vector2(1.3, 2.2), Vector2(0.95, 1.2), 0.0, -0.3, 4):
		return false
	if not _plant(mesa, Vector2(1.6, 2.6), Vector2(0.95, 1.2), 0.0, -0.4, 4):
		return false
	if not _plant(mesa, Vector2(1.5, 2.3), Vector2.ONE, 0.0, 0.0, 4):
		return false
	space.finish()
	return true


func _run() -> void:
	if OS.get_cmdline_user_args() != PackedStringArray(["regression"]):
		quit(2)
		return
	if not _build():
		push_error("Missing kit foliage in headless crown fixture")
		quit(2)
		return
	var land := Node3D.new()
	root.add_child(land)
	land.set_meta(&"tl_space", space)
	var visitor := Visitor.new()
	land.add_child(visitor)
	visitor.setup(Vector3.ZERO)
	visitor.steer_on()
	var counts := [[0, 0, 0], [0, 0, 0]]
	var poses := 0
	for tree in trees:
		for radius: float in [0.6, 3.0, 7.0]:
			for bearing in 4:
				var angle := TAU * bearing / 4.0
				visitor.put(tree + radius * Vector3(sin(angle), 0, cos(angle)), angle)
				for facing in 8:
					visitor.rotation.y = angle + TAU * facing / 8.0
					for tick in SETTLE:
						visitor.cam._physics_process(1.0 / 60.0)
						var row: Array = counts[int(oracle.inside(visitor.cam._look))]
						row[0] += 1
						row[1] += int(oracle.inside(visitor.cam.position))
						row[2] += int(oracle.near_crown(visitor.cam.position))
					poses += 1
	var frames: int = counts[0][0] + counts[1][0]
	var ok: bool = frames == 34560 and poses == 2880 and counts[1][0] > 0 and counts[0][0] > 0 and counts[0][1] == 0 and counts[0][2] == 0
	print("CROWNCASE regression %s frames=%d poses=%d head_out=%s head_in=%s" % ["ok" if ok else "FAIL", frames, poses, counts[0], counts[1]])
	land.free()
	oracle.close()
	space.free_all()
	quit(0 if ok else 1)
