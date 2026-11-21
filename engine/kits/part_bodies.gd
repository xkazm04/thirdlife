extends RefCounted
## Day of 21 Nov 2026 (lane L6, crisp-harden; internal to TLKitParts, not API): bodies of kit parts that follow their
## solid pieces, for parts whose one box round everything (`TLKitParts.auto_box`, or a box to mid-roof) was not the
## part: a walker met a wall in the air, stood on a floor above the roof, or walked into a stone footing; a thing
## stacked on the part floated or sank.
## The selftest `harden.kit_tops` (kernel/world/terrain/kit_tops_case.gd) holds every part's collider top to its mesh
## top, straight and turned. The numbers are those of the TLKitSite / TLKitHouse generators that draw the part.
## Static functions; `b` is the part's StaticBody3D.



## `barricade` of width `w` (TLKitSite.add_barricade): the two rows of boards (0.55-0.95 m up, 0.1 m thick) and the
## A-frame legs at each end, each a hull (feet 0.7 m apart). The box round it all stood 0.3 m before and behind the
## boards: an invisible wall to a walker, a ledge to a ball; a ball now rolls under the boards between the legs.
static func barricade(b: StaticBody3D, w: float) -> void:
	TLKitParts.box(b, Vector3(w, 0.4, 0.1), Vector3(0, 0.75, 0))
	for sx: float in [-1.0, 1.0]:
		var x: float = sx * w * 0.5
		var pts: PackedVector3Array = PackedVector3Array()
		for dx: float in [-0.035, 0.035]:
			pts.append_array([Vector3(x + dx, 0, -0.385), Vector3(x + dx, 0, 0.385), Vector3(x + dx, 0.97, -0.035), Vector3(x + dx, 0.97, 0.035)])
		TLKitParts.hull(b, pts)


## `cabin` (TLKitSite.add_cabin): the two skids, the box with its trims (to the roof at 2.89 m), the unit on the roof
## and the door's step. The box round it all stood over the step up to the roof unit's top (3.37 m): an invisible
## wall in front of the door and a floor 0.48 m above the roof.
static func cabin(b: StaticBody3D) -> void:
	for sx: float in [-2.6, 2.6]:
		TLKitParts.box(b, Vector3(0.5, 0.3, 2.3), Vector3(sx, 0.15, 0))
	TLKitParts.box(b, Vector3(6.1, 2.63, 2.5), Vector3(0, 1.575, 0))
	TLKitParts.box(b, Vector3(0.9, 0.5, 0.7), Vector3(2.0, 3.12, -0.5))
	TLKitParts.box(b, Vector3(1.2, 0.16, 0.7), Vector3(-1.9, 0.16, 1.6))


## `house` (TLKitHouse.house; w, d, wall_h, rise): the stone footing (0.75 m), the walls with their corner posts, the
## gable roof as one hull from its ridge to its eaves (0.75 m over the walls, 0.55 m over the gables) with the ridge
## board, the chimney and its cap, the porch's slab, step, posts and roof. The box before stood to mid-roof over the
## walls only: 2.1 m under the ridge, the eaves and the porch open.
static func house(b: StaticBody3D, w: float, d: float, wall_h: float, rise: float) -> void:
	var f: float = 0.75
	var y1: float = f + wall_h
	var yr: float = y1 + rise
	TLKitParts.box(b, Vector3(w + 0.4, f, d + 0.42), Vector3(0, f * 0.5, 0.01))
	TLKitParts.box(b, Vector3(w + 0.28, wall_h + 0.05, d + 0.28), Vector3(0, f + (wall_h + 0.05) * 0.5, 0))
	var xe: float = w * 0.5 + 0.55
	var ze: float = d * 0.5 + 0.75
	var roof: PackedVector3Array = PackedVector3Array()
	for sx: float in [-1.0, 1.0]:
		roof.append_array([Vector3(sx * xe, yr, 0), Vector3(sx * xe, y1 - 0.15, -ze), Vector3(sx * xe, y1 - 0.15, ze),
			Vector3(sx * xe, y1 - 0.35, -ze), Vector3(sx * xe, y1 - 0.35, ze)])
	TLKitParts.hull(b, roof)
	TLKitParts.box(b, Vector3(w + 1.2, 0.2, 0.3), Vector3(0, yr + 0.02, 0))
	var cx: float = w * 0.26
	var cz: float = -d * 0.14
	TLKitParts.box(b, Vector3(1.0, yr + 1.1 - (y1 - 0.5), 1.0), Vector3(cx, (yr + 1.1 + y1 - 0.5) * 0.5, cz))
	TLKitParts.box(b, Vector3(1.24, 0.22, 1.24), Vector3(cx, yr + 1.11, cz))
	TLKitParts.box(b, Vector3(3.2, 0.18, 1.6), Vector3(0, 0.09, d * 0.5 + 0.9))
	TLKitParts.box(b, Vector3(2.4, 0.12, 0.5), Vector3(0, 0.06, d * 0.5 + 1.95))
	for sx: float in [-1.0, 1.0]:
		TLKitParts.box(b, Vector3(0.16, f + 2.4 - 0.18, 0.16), Vector3(sx * 1.45, (0.18 + f + 2.4) * 0.5, d * 0.5 + 1.55))
	var y0: float = f
	TLKitParts.hull(b, PackedVector3Array([Vector3(-1.9, y0 + 2.4, d * 0.5 - 0.1), Vector3(1.9, y0 + 2.4, d * 0.5 - 0.1), Vector3(-1.9, y0 + 2.4, d * 0.5 + 1.9),
		Vector3(1.9, y0 + 2.4, d * 0.5 + 1.9), Vector3(-1.9, y0 + 3.0, d * 0.5 - 0.1), Vector3(1.9, y0 + 3.0, d * 0.5 - 0.1),
		Vector3(-1.9, y0 + 2.45, d * 0.5 + 1.9), Vector3(1.9, y0 + 2.45, d * 0.5 + 1.9)]))


## `timber_frame` (TLKitHouse.frame; w, d, h): the stone footing (0.7 m) and the plank floor of its first bay, the eight
## posts (0.24 m, from the floor at 0.78 m) and the two long top beams. Four posts from the ground stood before: the
## visitor walked into the footing. The rafters (0.16 m) and the ridge are not solid: nothing can stand on them.
static func frame(b: StaticBody3D, w: float, d: float, h: float) -> void:
	TLKitParts.box(b, Vector3(w + 0.3, 0.7, d + 0.3), Vector3(0, 0.35, 0))
	TLKitParts.box(b, Vector3(w * 0.4 + 0.15, 0.08, d + 0.3), Vector3((-w * 0.5 - 0.15 - w * 0.1) * 0.5, 0.74, 0))
	var y0: float = 0.78
	for i: int in 4:
		var x: float = -w * 0.5 + w * float(i) / 3.0
		for z: float in [-d * 0.5, d * 0.5]:
			TLKitParts.box(b, Vector3(0.24, h, 0.24), Vector3(x, y0 + h * 0.5, z))
	for z: float in [-d * 0.5, d * 0.5]:
		TLKitParts.box(b, Vector3(w + 0.24, 0.22, 0.24), Vector3(0, y0 + h, z))
