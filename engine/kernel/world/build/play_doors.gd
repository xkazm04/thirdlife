extends RefCounted
## Lane P (M6 rules and runs, 27 Nov 2026): an open zone's blocks, hidden and passable (contracts/BUILD.md "open":
## "the blocks inside the zone stop being drawn and stop colliding while it is open"), with a short slide in frames
## instead of a pop. The saved blocks never change: the blocks layer's mask (blocks_layer.gd `set_mask`) leaves the
## zone's cells out of the section mesh and the chunk body (block_mesh.gd `mask`), and a slide shows the door moving.
##
##   open    the mask goes on at once (passable from the next rebuild, two frames on: the body moves before build mode
##           rebuilds); a copy of the zone's blocks sinks by the zone's height over OPEN_FRAMES and is freed.
##   close   a copy rises from below over CLOSE_FRAMES while the zone is still open (so nobody is shut inside a block
##           that has not arrived), then the mask comes off and the copy goes once the sections are rebuilt.
##   instant (build mode comes on, the visit ends) the mask comes off now and every slide goes.
## The copy is meshed by block_mesh.gd itself from a scratch store holding only the zone's blocks (no collider).

const Blocks := preload("res://kernel/world/build/blocks.gd")
const BlockMesh := preload("res://kernel/world/build/block_mesh.gd")
const OPEN_FRAMES := 14
const CLOSE_FRAMES := 18

var build: RefCounted = null             # home_build.gd
var slides := {}                         # zone id -> {node, y0, y1, f0, frames, unmask, lo, hi, done}
var frame := 0


func _init(b: RefCounted = null) -> void:
	build = b


func _layer() -> RefCounted:
	return build.call("layer", "blocks") if build != null else null


static func corners(box: Array) -> Array:
	return [Vector3i(int(box[0][0]), int(box[0][1]), int(box[0][2])), Vector3i(int(box[1][0]), int(box[1][1]), int(box[1][2]))]


## Zone `zid` opens (`open` true) or closes. `instant`: no slide (build mode, the end of a visit).
func set_open(zid: int, box: Array, open: bool, at_frame: int, instant := false) -> void:
	var bl := _layer()
	if bl == null:
		return
	var c := corners(box)
	var h := float(c[1].y - c[0].y + 1)
	var s: Dictionary = slides.get(zid, {})
	var y_now := _y_of(s, at_frame) if not s.is_empty() else (-h if not open else 0.0)
	if instant:
		_drop(zid)
		bl.set_mask(zid, c[0], c[1], open)
		return
	if open:
		bl.set_mask(zid, c[0], c[1], true)
		_slide(zid, c, y_now, -h, at_frame, OPEN_FRAMES, false)
	else:
		_slide(zid, c, y_now, 0.0, at_frame, CLOSE_FRAMES, true)


func _slide(zid: int, c: Array, y0: float, y1: float, at_frame: int, frames: int, unmask: bool) -> void:
	var s: Dictionary = slides.get(zid, {})
	if s.is_empty() or not is_instance_valid(s.get("node")):
		var node := _copy(zid, c[0], c[1])
		s = {"node": node}
		slides[zid] = s
	s.merge({"y0": y0, "y1": y1, "f0": at_frame, "frames": frames, "unmask": unmask, "lo": c[0], "hi": c[1], "done": false}, true)
	if s.node != null:
		(s.node as Node3D).position.y = y0
		(s.node as Node3D).visible = true


func _y_of(s: Dictionary, at_frame: int) -> float:
	var t := clampf(float(at_frame - int(s.f0)) / float(maxi(1, int(s.frames))), 0.0, 1.0)
	return lerpf(float(s.y0), float(s.y1), t * t * (3.0 - 2.0 * t))


## The zone's blocks alone, meshed in the Home's look under the Home's root (null: no blocks there, or no root).
func _copy(zid: int, lo: Vector3i, hi: Vector3i) -> Node3D:
	var root: Node3D = build.get("root")
	if root == null:
		return null
	var src: RefCounted = build.get("blocks")
	var scratch: RefCounted = Blocks.new(int(src.get("sec")))
	var n := 0
	for y: int in range(lo.y, hi.y + 1):
		for z: int in range(lo.z, hi.z + 1):
			for x: int in range(lo.x, hi.x + 1):
				var code: int = src.call("get_code", Vector3i(x, y, z))
				if code != 0 and scratch.call("put", Vector3i(x, y, z), code):
					n += 1
	if n == 0:
		return null
	var node := Node3D.new()
	node.name = "Door_%d" % zid
	root.add_child(node)
	var m: RefCounted = BlockMesh.new(scratch, node, null)
	for s: Vector2i in Blocks.sorted_ids(scratch.get("sections")):
		m.call("rebuild", s)
	node.set_meta(&"tl_cells", n)
	return node


## One physics frame: the slides move; a finished close takes its mask off and its copy goes once the sections under
## it are rebuilt (so the real blocks are drawn before the copy leaves: no frame without the door).
func tick(at_frame: int) -> void:
	frame = at_frame
	var bl := _layer()
	for zid: int in slides.keys():
		var s: Dictionary = slides[zid]
		var y := _y_of(s, at_frame)
		if s.node != null and is_instance_valid(s.node):
			(s.node as Node3D).position.y = y
		var t_end := at_frame - int(s.f0) >= int(s.frames)
		if not t_end:
			continue
		if not bool(s.unmask):
			_drop(zid)                                   # opened: the copy has sunk away
			continue
		if not bool(s.done):
			s.done = true
			if bl != null:
				bl.set_mask(zid, s.lo, s.hi, false)
			continue
		if not _pending(s.lo, s.hi):
			_drop(zid)


func _pending(lo: Vector3i, hi: Vector3i) -> bool:
	var store: RefCounted = build.get("blocks")
	var dirty: Dictionary = store.get("dirty")
	var a: Vector2i = store.call("section_of", lo - Vector3i(2, 0, 2))
	var b: Vector2i = store.call("section_of", hi + Vector3i(2, 0, 2))
	for sz in range(a.y, b.y + 1):
		for sx in range(a.x, b.x + 1):
			if dirty.has(Vector2i(sx, sz)):
				return true
	return false


func _drop(zid: int) -> void:
	var s: Dictionary = slides.get(zid, {})
	if s.has("node") and s.node != null and is_instance_valid(s.node):
		(s.node as Node).queue_free()
	slides.erase(zid)


## Build mode comes on or the visit ends: every mask off, every slide gone (the blocks as saved, at once).
func clear() -> void:
	for zid: int in slides.keys():
		_drop(zid)
	var bl := _layer()
	if bl != null:
		bl.clear_masks()


func moving() -> int:
	return slides.size()
