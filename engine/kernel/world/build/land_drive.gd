extends RefCounted
## M5 lane L (spark world-sandbox): what the land-look (764) and plants (763) cases share: the landscape of
## res://boot/village.json with build mode mounted, a camera over a spot, and a person's hands (keys, the pointer on the
## ground, LMB held for frames), as land_case.gd (755) drives them. Frames, not wall clock.

const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const CAM_H := 40.0

var tree: SceneTree
var node: Node3D
var home: RefCounted                     # home/hook.gd
var bm: Node                             # build_mode.gd
var b: RefCounted                        # home_build.gd
var land: RefCounted
var cam: Camera3D
var far := Vector3(2000.0, 0.0, 2000.0)  # where the visitor stands (nothing he does refuses an edit there)


## Builds it under `t.root`; "" or what went wrong.
func setup(t: SceneTree, dir: String) -> String:
	tree = t
	TLStyle.set_headless(false)
	CaseUtil.remove_dir(ProjectSettings.globalize_path(dir))
	node = CaseUtil.landscape(t.root, CaseUtil.walk())
	if not node.has_meta(&"tl_build_mode"):
		return "no build mode: home/hook.gd did not mount it"
	home = node.get_meta(&"tl_home")
	bm = node.get_meta(&"tl_build_mode")
	b = node.get_meta(&"tl_build")
	land = b.layer("land")
	bm.call("open", dir)
	bm.set("feet_at", func() -> Vector3: return far)
	b.protect.visitor_at = func() -> Vector3: return far
	cam = Camera3D.new()
	cam.fov = 60.0
	t.root.add_child(cam)
	cam.current = true
	bm.set("cam", cam)
	t.root.size = Vector2i(1280, 720)
	return ""


## Before quitting: the visitor callables hold this object (a cycle through the builder); drop them.
func release() -> void:
	if b != null:
		b.protect.visitor_at = Callable()
	if bm != null and is_instance_valid(bm):
		bm.set("feet_at", Callable())
	b = null
	land = null
	home = null


func wait(n: int) -> void:
	for i in n:
		await tree.physics_frame


func vtx(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x / 3.0), roundi(p.y / 3.0))


## A spot near `want` whose vertices within `r` m nothing protects (for land, paint and plant), with at least `slope`
## of ground gradient; the chunks round it loaded.
func free_site(want: Vector2, r: float, slope := 0.0) -> Vector2:
	for ring: int in 40:
		for k: int in maxi(1, ring * 6):
			var p := want + Vector2.from_angle(TAU * k / maxi(1, ring * 6)) * ring * 12.0
			var g := Vector2(land.height_at(p.x + 3, p.y) - land.height_at(p.x - 3, p.y), land.height_at(p.x, p.y + 3) - land.height_at(p.x, p.y - 3)) / 6.0
			if g.length() < slope:
				continue
			var ok := true
			for j: int in range(-ceili(r / 3), ceili(r / 3) + 1):
				for i: int in range(-ceili(r / 3), ceili(r / 3) + 1):
					for what: String in ["land", "paint", "plant"]:
						ok = ok and land.refusal(vtx(p) + Vector2i(i, j), what) == ""
			if ok:
				home.ensure(p)
				return p
	home.ensure(want)
	return want


func tap(k: Key, shift := false) -> void:
	if shift:
		CaseUtil.key(KEY_SHIFT, true)
	CaseUtil.key(k, true, shift)
	await wait(2)
	CaseUtil.key(k, false, shift)
	if shift:
		CaseUtil.key(KEY_SHIFT, false)
	await wait(2)


func to_tool(id: String) -> bool:
	for i in (bm.get("tools") as Array).size():
		if str(bm.call("tool").get("id")) == id:
			return true
		await tap(KEY_T)
	return str(bm.call("tool").get("id")) == id


func set_radius(r: int) -> void:
	for i in 10:
		await tap(KEY_BRACKETLEFT)
	for i in r - 1:
		await tap(KEY_BRACKETRIGHT)


func button(down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = bm.get("pointer")
	Input.parse_input_event(e)
	Input.flush_buffered_events()


## The camera over `p` and the pointer on the ground there (off the lattice: a ray exactly through an edge two
## triangles share can miss both).
func point(p: Vector2) -> void:
	var y: float = land.height_at(p.x, p.y)
	cam.look_at_from_position(Vector3(p.x, y + CAM_H, p.y + 0.01), Vector3(p.x, y, p.y), Vector3.FORWARD)
	cam.reset_physics_interpolation()
	var q := p + Vector2(0.23, 0.31)
	bm.set("pointer", cam.unproject_position(Vector3(q.x, land.height_at(q.x, q.y), q.y)))


## LMB held `frames` physics frames at `at` (along `path` when given).
func stroke(at: Vector2, frames: int, path := Vector2.ZERO) -> void:
	point(at)
	await wait(2)
	button(true)
	for f: int in frames:
		if path != Vector2.ZERO:
			point(at + path * (float(f) / frames))
		await wait(1)
	button(false)
	await wait(3)
	b.flush()


func last_ops() -> Array:
	return (b.edits.history[b.edits.history.size() - 1] as Dictionary).ops if not b.edits.history.is_empty() else []


## The drawn chunk mesh's [colour, code, uv] at lattice point (i, j), or [] when no open chunk has it.
func mesh_at(v: Vector2i) -> Array:
	for id: Vector2i in land.mesh.chunks:
		var s: Dictionary = land.mesh.chunks[id]
		var px := (s.X as PackedFloat32Array).find(v.x * 3.0)
		var qz := (s.Z as PackedFloat32Array).find(v.y * 3.0)
		if px >= 0 and qz >= 0:
			var k: int = qz * (s.X as PackedFloat32Array).size() + px
			return [(s.col as PackedColorArray)[k], (s.code as PackedInt32Array)[k], (s.uv as PackedVector2Array)[k]]
	return []
