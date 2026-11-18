extends SceneTree
## Walker-feel T selftest case `ground.no_sky_pit` (tools/selftest.sh): the world's ground is cut open only for a pack
## whose own ground covers its plot, and a hole can be shut while its plot draws nothing. Headless; prints one line
## `GROUNDCASE ok|fail <detail>`.
##   B1 (the most common blink of 18 Nov: ex_car's plot and the hockey plot showed the sky through the ground): a pack
##   whose only wide meshes are ex_car's two boxes (asphalt 60 x 1 x 40, ice 60 x 1 x 400 with its origin 200 m out,
##   which the plot cut drops whole) has no rim (NAN), while a 416 m terrain sheet has one.
##   B2: draw/view_seam.gd `close_holes` sets a shut plot's hole radius to 0 and gives it back when opened.

const DrawScript: GDScript = preload("res://kernel/world/draw/draw.gd")
const Seam: GDScript = preload("res://kernel/world/draw/view_seam.gd")


func _box(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = b
	mi.position = at
	parent.add_child(mi)


var _ran: bool = false


func _process(_delta: float) -> bool:
	if not _ran:
		_ran = true
		_check()
	return false


func _initialize() -> void:
	pass


func _check() -> void:
	var why: Array = []
	var car: Node3D = Node3D.new()
	root.add_child(car)                                   # the nodes are in the tree: their global transforms are read
	_box(car, Vector3(60, 1, 40), Vector3(0, -0.5, 10))         # asphalt: x -30..30, z -10..30
	_box(car, Vector3(60, 1, 400), Vector3(0, -0.5, -210))      # ice: its origin 210 m out of a 40 m plot
	var r_car: float = float(DrawScript.call("edge_height", car, 40.0))
	if not is_nan(r_car):
		why.append("ex_car's boxes give a rim (%.2f): the world's ground would be cut open over a plot with no ground" % r_car)
	var cover: float = float(DrawScript.call("ground_cover", car, 40.0, [car.get_child(0), car.get_child(1)]))
	var sheet: Node3D = Node3D.new()
	root.add_child(sheet)
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(416, 416)
	pm.subdivide_width = 103
	pm.subdivide_depth = 103
	var smi: MeshInstance3D = MeshInstance3D.new()
	smi.mesh = pm
	smi.position = Vector3(0, 1.5, 0)
	sheet.add_child(smi)
	var r_sheet: float = float(DrawScript.call("edge_height", sheet, 40.0))
	if is_nan(r_sheet) or absf(r_sheet - 1.5) > 0.01:
		why.append("a 416 m terrain sheet at 1.5 m gives rim %s, not 1.5" % str(r_sheet))
	# B2: shut and open a hole
	var land: Node3D = Node3D.new()
	root.add_child(land)
	var gm: ShaderMaterial = ShaderMaterial.new()        # headless: the style gives no shader; the hole list is what counts
	var all: Array = [Vector4(0, 0, 42.5, 0), Vector4(100, 0, 32.5, 0)]
	while all.size() < 32:
		all.append(Vector4.ZERO)
	gm.set_meta(&"tl_holes_all", all)
	land.set_meta(&"tl_ground_mat", gm)
	Seam.call("close_holes", land, [true, true], [40.0, 30.0], [false, true])
	var h: Array = gm.get_shader_parameter(&"tl_holes")
	if not ((h[0] as Vector4).z > 42.0 and (h[1] as Vector4).z == 0.0):
		why.append("shut plot 1: holes are %s and %s" % [str(h[0]), str(h[1])])
	Seam.call("close_holes", land, [true, true], [40.0, 30.0], [false, false])
	h = gm.get_shader_parameter(&"tl_holes")
	if not ((h[1] as Vector4).z > 32.0):
		why.append("opened again: plot 1's hole is %s" % str(h[1]))
	print("GROUNDCASE %s %s" % ["ok" if why.is_empty() else "fail",
		("ex_car's boxes cover %d %% of the rim: no hole; a terrain sheet: rim 1.5; a hole shut and opened again" % int(round(cover * 100.0))) if why.is_empty() else "; ".join(why)])
	car.free()
	sheet.free()
	land.free()
	quit(0 if why.is_empty() else 1)
