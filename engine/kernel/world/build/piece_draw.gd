extends RefCounted
## M3 (spark world-sandbox, 26 Nov 2026): draws and collides the Home's pieces, per 16 m section (the blocks' sections).
##   drawing    one MultiMeshInstance3D per prototype mesh per section (piece_catalog.gd `proto`: kind and params built
##              once): 500 fences of one length are one draw per section, not 500 nodes. A part with a light (house,
##              light_mast, street_lamp) or a breakable one (crate) is built as its own node instead, up to NODE_CAP in
##              the Home (lights cost per pixel); past the cap it is drawn instanced, without its light. A node's own
##              static bodies are freed: its shapes are in the visitor's space, below.
##   bodies     one static body per section in the visitor's WorldSpace (tag "home pieces", layer 1) holding every
##              collision shape of its pieces (the prototype's shapes, shared), made with the section's first piece
##              and dropped with its last. Never a pack's space, never a state hash.
## Kernel code: the meshes carry the kit's own TLStyle materials; nothing here makes a material.

const Catalog := preload("res://kernel/world/build/piece_catalog.gd")
const Collider := preload("res://kernel/world/land/chunk_collider.gd")
const TAG := "home pieces"
const STAT := "piece_shapes"
const NODE_CAP := 48

var holder: Node3D = null               # "HomePieces" (null: nothing drawn)
var ws: Object = null                   # the visitor's WorldSpace (null: no bodies)
var sections := {}                      # section -> Node3D holding its draws
var bodies := {}                        # section -> {"body": RID, "faces": 0, "stat": STAT, "shapes": int}
var nodes := 0                          # pieces drawn as nodes now (lights, breakables)
var counters := {"sections": 0, "multimeshes": 0, "instances": 0, "nodes": 0}


func _init(parent: Node3D, space: Object) -> void:
	ws = space
	if parent != null:
		holder = Node3D.new()
		holder.name = "HomePieces"
		parent.add_child(holder)


## Redraws section `s` from `recs` (its pieces, sorted) and refreshes its body.
func rebuild(s: Vector2i, recs: Array) -> void:
	counters.sections += 1
	if holder != null:
		_draw(s, recs)
	if ws != null:
		_body(s, recs)


func _draw(s: Vector2i, recs: Array) -> void:
	var old: Node3D = sections.get(s)
	if old != null:
		nodes -= int(old.get_meta(&"tl_nodes", 0))
		old.queue_free()
		holder.remove_child(old)
		sections.erase(s)
	if recs.is_empty():
		return
	var h := Node3D.new()
	h.name = "Pieces_%d_%d" % [s.x, s.y]
	var groups := {}                                       # proto key -> [proto, [xf, ...]]
	var keys := []
	var own := 0
	for r: Dictionary in recs:
		var pr: Dictionary = r.proto
		if (bool(pr.lights) or bool(pr.breakable)) and nodes < NODE_CAP:
			var n: Node3D = TLKit.build(str(r.part), r.bp)
			if n != null:
				_strip_bodies(n)
				n.transform = r.xf
				h.add_child(n)
				nodes += 1
				own += 1
				counters.nodes += 1
				continue
		if not groups.has(pr.key):
			groups[pr.key] = [pr, []]
			keys.append(pr.key)
		(groups[pr.key][1] as Array).append(r.xf)
	for k: String in keys:
		var pr: Dictionary = groups[k][0]
		var xfs: Array = groups[k][1]
		for i: int in (pr.meshes as Array).size():
			var m: Array = pr.meshes[i]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = m[0]
			mm.instance_count = xfs.size()
			for j: int in xfs.size():
				mm.set_instance_transform(j, (xfs[j] as Transform3D) * (m[1] as Transform3D))
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%d" % [str(pr.part), h.get_child_count()]
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(m[2]) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			h.add_child(mmi)
			counters.multimeshes += 1
			counters.instances += xfs.size()
	h.set_meta(&"tl_nodes", own)
	holder.add_child(h)
	sections[s] = h


static func _strip_bodies(n: Node) -> void:
	for c: Node in n.get_children():
		if c is StaticBody3D:
			n.remove_child(c)
			c.free()
		else:
			_strip_bodies(c)


func _body(s: Vector2i, recs: Array) -> void:
	var parts := []
	for r: Dictionary in recs:
		for sh: Array in (r.proto as Dictionary).shapes:
			parts.append([sh[0], (r.xf as Transform3D) * (sh[1] as Transform3D)])
	if parts.is_empty():
		if bodies.has(s):
			Collider.drop(bodies[s], ws)
			bodies.erase(s)
		return
	var stats: Dictionary = ws.get("stats")
	if not stats.has(STAT):
		stats[STAT] = 0
	if not bodies.has(s):
		var was: String = ws.get("tag")
		ws.set("tag", TAG)
		var rid: RID = ws.call("_static", parts[0][0], parts[0][1])
		ws.set("tag", was)
		bodies[s] = {"body": rid, "faces": 0, "stat": STAT}
	var b: Dictionary = bodies[s]
	PhysicsServer3D.body_clear_shapes(b.body)
	for p: Array in parts:
		PhysicsServer3D.body_add_shape(b.body, (p[0] as Shape3D).get_rid(), p[1])
	stats[STAT] = int(stats[STAT]) + parts.size() - int(b.faces)
	b.faces = parts.size()


## {"sections", "multimeshes", "instances", "nodes", "bodies", "shapes"} drawn and collided now.
func figures() -> Dictionary:
	var mms := 0
	var inst := 0
	for s: Vector2i in sections:
		for c: Node in (sections[s] as Node3D).get_children():
			if c is MultiMeshInstance3D:
				mms += 1
				inst += (c as MultiMeshInstance3D).multimesh.instance_count
	var shapes := 0
	for s: Vector2i in bodies:
		shapes += int(bodies[s].faces)
	return {"sections": sections.size(), "multimeshes": mms, "instances": inst, "nodes": nodes, "bodies": bodies.size(), "shapes": shapes}


func free_all() -> void:
	for s: Vector2i in sections:
		(sections[s] as Node).queue_free()
	sections.clear()
	nodes = 0
	if ws != null:
		for s: Vector2i in bodies:
			Collider.drop(bodies[s], ws)
	bodies.clear()
	if holder != null and is_instance_valid(holder):
		holder.queue_free()
	holder = null
