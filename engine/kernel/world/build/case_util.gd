extends RefCounted
## SEAM: what the headless build cases share (build_case.gd is at the 600-line cap and keeps its own copies). The
## lanes' cases (M2, M3, M4) use these instead of copying them again.

const Landscape := preload("res://kernel/world/landscape.gd")


## The landscape of res://boot/village.json under `root` (the Home grown by home/hook.gd, build mode mounted), as
## walk_case.gd and build_case.gd build it. Returns the node (its metas: tl_space, tl_home, tl_build, tl_build_mode).
static func landscape(root: Node, walk: Dictionary) -> Node3D:
	var cfg: Dictionary = walk.landscape.duplicate(true)
	cfg.road = walk.road
	cfg.footprints = []
	var xf := []
	var radii := []
	var own := []
	for p: Dictionary in walk.plots:
		xf.append(Transform3D(Basis.IDENTITY, Vector3(p.origin[0], p.origin[1], p.origin[2])))
		radii.append(p.radius)
		own.append(false)
		cfg.footprints.append(Vector2(p.footprint.size_m[0], p.footprint.size_m[1]))
	var node := Node3D.new()
	node.set_meta(&"tl_walk", walk)
	root.add_child(node)
	Landscape.build(node, xf, radii, own, cfg)
	Landscape.arrive(node)
	return node


static func walk() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://boot/village.json"))


## Removes a directory and everything in it (an absolute path; globalize a user:// one first).
static func remove_dir(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f: String in d.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	for sub: String in d.get_directories():
		remove_dir(path.path_join(sub))
	DirAccess.remove_absolute(path)


## A key pressed or let go through the engine's input state (build mode polls it).
static func key(k: Key, down: bool, shift := false) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = down
	e.shift_pressed = shift
	Input.parse_input_event(e)
	Input.flush_buffered_events()
