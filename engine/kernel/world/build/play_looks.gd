extends RefCounted
## Lane P (M6 rules and runs, 27 Nov 2026): the zones' looks in play (contracts/BUILD.md "Milestone 6": `pad` a flat
## glowing disc on the zone's floor, `coin` a turning token at the zone's centre, `flag` a pole and flag at the zone's
## floor centre; `none` nothing). Cel style through TLStyle palette keys (TLMesh, one toon material) and the kit's
## `flag` part; no hand-made material. One mesh per look and role is built once and shared, so a Home of 100 coins is
## 100 MeshInstance3D nodes and one mesh. Everything moves by physics frames (`tick(frame)`), never by a clock.
##
##   PlayLooks.look_of(zone) -> Node3D        a look's node at the zone's place (null for `none`): lane T may call it
##   var l = PlayLooks.new(holder); l.sync(rules_layer); l.taken(id, true, frame); l.tick(frame); l.clear()
##
## A pad is tinted by its role in the rules: the zone whose trigger starts a run (`start`, lime), the zone a checkpoint
## names (`checkpoint`, cyan), the zone whose trigger finishes a run (`finish`, amber); any other pad is violet.
## Lane F3 (27 Nov, the playtest's "a hazard is an invisible box that sends you back, a door is two planks among
## fourteen"): a zone of look `none` shows its role in play too: a `hazard` (entering it respawns) lies as red and white
## cel stripes on its floor with a red rim and a slow warning shimmer; a `door` (a rule opens, closes or toggles it)
## gets a thin amber frame round its opening on both faces of the wall (posts and a lintel, outside the blocks).

const Check := preload("res://kernel/world/build/rules_check.gd")
const ROLE_KEYS := {"": "neon_violet", "start": "neon_lime", "checkpoint": "cyan", "finish": "beacon", "launch": "neon_pink",
	"hazard": "hazard_red", "door": "neon_violet"}
const STRIPE := 0.5                      # metres: a hazard's stripes (red, white, red ...) across its longer side
const FRAME_W := 0.07                    # metres: a door frame's bar
const SHIMMER := 0.05                    # radians per frame of a hazard's shimmer
const KICK_FRAMES := 14                  # round 2: a jump pad's kick (the disc swells, its glow flares) when it launches
const SPIN := 0.055                      # radians per frame a coin turns
const TAKE_FRAMES := 14                  # a taken coin flies up and shrinks away over these frames
const BACK_FRAMES := 10                  # a coin that comes back grows in over these
const FLAG_H := 3.2

static var _meshes := {}                 # "pad:<role>:<r>" | "coin" -> ArrayMesh

var holder: Node3D = null                # the looks hang here (home_build.gd `root`: cell coordinates are its own)
var nodes := {}                          # zone id -> Node3D
var looks := {}                          # zone id -> look
var base_y := {}                         # zone id -> the coin's resting height
var gone := {}                           # zone id -> [frame taken, hidden at the end] / back: [frame back, false]
var fx := []                             # [node, frame to free]
var kicks := {}                          # zone id -> the frame its pad kicked (a launch from it)
var revision := -1                       # the rules layer's revision the looks were made for
var solid: Callable                      # cell -> bool: the Home's blocks (a door's frame goes round its blocks)
var frame := 0


func _init(h: Node3D = null) -> void:
	holder = h


## The look of `zone` (a saved zone: {"id", "box", "look", "name"?}) as a node placed in cell coordinates, or null
## for `none`. `role`: "", "start", "checkpoint" or "finish" (a pad's tint).
static func look_of(zone: Dictionary, role := "") -> Node3D:
	var box: Array = zone.get("box", [])
	if box.size() != 2:
		return null
	var n: Node3D = null
	var look := str(zone.get("look", "none"))
	if look == "none" and (role == "hazard" or role == "door"):
		look = role
	match look:
		"pad":
			var w := float(box[1][0]) - float(box[0][0]) + 1.0
			var d := float(box[1][2]) - float(box[0][2]) + 1.0
			var r := snappedf(clampf(minf(w, d) * 0.5 * 0.86, 0.36, 4.0), 0.02)
			n = Node3D.new()
			n.name = "Pad_%d" % int(zone.get("id", 0))
			n.add_child(_mi(_pad_mesh(r, role), "Disc"))
			var glow: MeshInstance3D = TLStyleFx.glow(str(ROLE_KEYS.get(role, "neon_violet")), 0.0)   # round 2: the pad glows
			glow.name = "Glow"
			glow.position = Vector3(0, 0.3, 0)
			glow.scale = Vector3.ONE * r * 2.4
			n.add_child(glow)
			n.set_meta(&"tl_r", r)
			n.position = Check.floor_centre(box)
		"coin":
			n = Node3D.new()
			n.name = "Coin_%d" % int(zone.get("id", 0))
			n.add_child(_mi(_coin_mesh(), "Token"))
			n.position = _centre(box)
		"hazard":
			var hw := float(box[1][0]) - float(box[0][0]) + 1.0
			var hd := float(box[1][2]) - float(box[0][2]) + 1.0
			n = Node3D.new()
			n.name = "Hazard_%d" % int(zone.get("id", 0))
			n.add_child(_mi(_hazard_mesh(hw, hd), "Stripes"))
			var hg: MeshInstance3D = TLStyleFx.glow("hazard_red", 0.6)
			hg.name = "Shimmer"
			hg.position = Vector3(0, 0.35, 0)
			hg.scale = Vector3.ONE * minf(maxf(hw, hd), 6.0)
			n.add_child(hg)
			n.set_meta(&"tl_r", minf(maxf(hw, hd), 6.0))
			n.position = Check.floor_centre(box)
		"door":
			n = Node3D.new()
			n.name = "Door_%d" % int(zone.get("id", 0))
			var at := Check.floor_centre(box)
			var op: Dictionary = zone.get("opening", {}) if zone.get("opening", {}) is Dictionary else {}
			n.add_child(_mi(_frame_mesh(op if not op.is_empty() else door_opening(box), at), "Frame"))
			n.position = at
		"flag":
			n = Node3D.new()
			n.name = "Flag_%d" % int(zone.get("id", 0))
			var f: Node3D = TLKit.build("flag", {"height": FLAG_H, "color": "flag_a"})
			if f != null:
				for c: Node in f.get_children():
					if c is CollisionObject3D:          # a finish flag is run through, never stood against
						f.remove_child(c)
						c.free()
				n.add_child(f)
			n.add_child(_mi(_pad_mesh(0.55, "finish"), "Foot"))
			n.position = Check.floor_centre(box)
	if n != null:
		n.set_meta(&"tl_zone", int(zone.get("id", 0)))
		n.set_meta(&"tl_look", look)
	return n


## Zone id -> role ("start" | "checkpoint" | "finish") from the rules (saved forms). Finish wins over start, start
## over checkpoint, when one zone has two.
static func roles(rules: Dictionary) -> Dictionary:
	var out := {}
	var rank := {"door": 1, "hazard": 1, "launch": 2, "checkpoint": 3, "start": 4, "finish": 5}
	var put := func(z: int, role: String) -> void:
		if z > 0 and int(rank.get(str(out.get(z, "")), 0)) < int(rank[role]):
			out[z] = role
	for id: int in rules:
		var r: Dictionary = rules[id]
		var tz := int((r.when as Dictionary).get("zone", 0))
		for e: Dictionary in r.do:
			match str(e.do):
				"start":
					put.call(tz, "start")
				"finish":
					put.call(tz, "finish")
				"checkpoint":
					put.call(int(e.get("zone", 0)), "checkpoint")
				"launch":
					put.call(tz, "launch")
				"respawn":
					if str((r.when as Dictionary).get("on", "")) == "enter":
						put.call(tz, "hazard")
				"open", "close", "toggle":
					put.call(int(e.get("zone", 0)), "door")
	return out


static func _centre(box: Array) -> Vector3:
	return Vector3((float(box[0][0]) + float(box[1][0]) + 1.0) * 0.5, (float(box[0][1]) + float(box[1][1]) + 1.0) * 0.5,
		(float(box[0][2]) + float(box[1][2]) + 1.0) * 0.5)


static func _mi(mesh: Mesh, n: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A pad: a dark rim ring on the floor, the glowing disc in the role's colour inside it, a brighter centre.
static func _pad_mesh(r: float, role: String) -> ArrayMesh:
	var key := "pad:%s:%.2f" % [role, r]
	if not _meshes.has(key):
		var mk := TLMesh.new(1)
		mk.cyl(r, 0.05, 24, "steel_dark", Color.WHITE, -1.0, Vector3(0, 0.01, 0))
		mk.cyl(r * 0.82, 0.075, 24, str(ROLE_KEYS.get(role, "neon_violet")), Color.WHITE, -1.0, Vector3(0, 0.01, 0))
		mk.cyl(r * 0.34, 0.085, 16, "white", Color.WHITE, -1.0, Vector3(0, 0.01, 0))
		_meshes[key] = mk.build("pad")
	return _meshes[key]


## A hazard's floor: red and white stripes STRIPE wide across its longer side, a red rim; `w` x `d` metres, centred.
static func _hazard_mesh(w: float, d: float) -> ArrayMesh:
	var key := "hazard:%.1f:%.1f" % [w, d]
	if not _meshes.has(key):
		var mk := TLMesh.new(1)
		var y := 0.03
		var along_x := w >= d
		var length := w if along_x else d
		var n := maxi(1, int(round(length / STRIPE)))
		var step := length / n
		for i in n:
			var a := -length * 0.5 + i * step
			var b := a + step
			var k := "hazard_red" if i % 2 == 0 else "hazard_white"
			if along_x:
				mk.quad_up(Vector3(a, y, -d * 0.5), Vector3(b, y, -d * 0.5), Vector3(b, y, d * 0.5), Vector3(a, y, d * 0.5), k)
			else:
				mk.quad_up(Vector3(-w * 0.5, y, a), Vector3(w * 0.5, y, a), Vector3(w * 0.5, y, b), Vector3(-w * 0.5, y, b), k)
		var r := 0.08
		mk.boxm(Vector3(-w * 0.5, 0.0, -d * 0.5), Vector3(w * 0.5, 0.06, -d * 0.5 + r), "hazard_red")
		mk.boxm(Vector3(-w * 0.5, 0.0, d * 0.5 - r), Vector3(w * 0.5, 0.06, d * 0.5), "hazard_red")
		mk.boxm(Vector3(-w * 0.5, 0.0, -d * 0.5), Vector3(-w * 0.5 + r, 0.06, d * 0.5), "hazard_red")
		mk.boxm(Vector3(w * 0.5 - r, 0.0, -d * 0.5), Vector3(w * 0.5, 0.06, d * 0.5), "hazard_red")
		_meshes[key] = mk.build("hazard")
	return _meshes[key]


## The opening a door frames: the solid cells of its zone (`solid`: cell -> bool, the Home's blocks) as [lo, hi] and
## whether the wall's faces look along z (`faces_z`: the wall runs along x, judged by the solid cells beside the
## opening, else by its wider side). With no solid cell (or no `solid`): the zone's middle slice on its thinner side.
static func door_opening(box: Array, solid: Callable = Callable()) -> Dictionary:
	var lo := Vector3i(int(box[0][0]), int(box[0][1]), int(box[0][2]))
	var hi := Vector3i(int(box[1][0]), int(box[1][1]), int(box[1][2]))
	var a := Vector3i(hi)
	var b := Vector3i(lo)
	var any := false
	if solid.is_valid():
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				for x in range(lo.x, hi.x + 1):
					if bool(solid.call(Vector3i(x, y, z))):
						any = true
						a = Vector3i(mini(a.x, x), mini(a.y, y), mini(a.z, z))
						b = Vector3i(maxi(b.x, x), maxi(b.y, y), maxi(b.z, z))
	if not any:
		a = lo
		b = hi
		if hi.x - lo.x <= hi.z - lo.z:
			a.x = (lo.x + hi.x) / 2
			b.x = a.x
		else:
			a.z = (lo.z + hi.z) / 2
			b.z = a.z
	var beside_x := 0
	var beside_z := 0
	if solid.is_valid():
		for y in range(a.y, b.y + 1):
			for z in range(a.z, b.z + 1):
				beside_x += int(bool(solid.call(Vector3i(a.x - 1, y, z)))) + int(bool(solid.call(Vector3i(b.x + 1, y, z))))
			for x in range(a.x, b.x + 1):
				beside_z += int(bool(solid.call(Vector3i(x, y, a.z - 1)))) + int(bool(solid.call(Vector3i(x, y, b.z + 1))))
	var faces_z := beside_x > beside_z if beside_x != beside_z else (b.x - a.x) >= (b.z - a.z)
	return {"lo": a, "hi": b, "faces_z": faces_z}


## A door's frame round `op` (door_opening), in the frame of the zone's floor centre `at`: two posts and a lintel on
## both faces of the wall, FRAME_W outside the blocks so it never hides in them.
static func _frame_mesh(op: Dictionary, at: Vector3) -> ArrayMesh:
	var a: Vector3 = Vector3(op.lo) - at
	var b: Vector3 = Vector3(op.hi) + Vector3.ONE - at
	var fz := bool(op.faces_z)
	var key := "door:%s:%s:%s" % [str(a), str(b), str(fz)]
	if not _meshes.has(key):
		var mk := TLMesh.new(1)
		var f := FRAME_W
		var g := 0.012
		var s0 := a.x if fz else a.z                     # the opening along the wall
		var s1 := b.x if fz else b.z
		var y0 := a.y
		var y1 := b.y
		for plane: Array in ([[a.z - g - f, a.z - g], [b.z + g, b.z + g + f]] if fz else [[a.x - g - f, a.x - g], [b.x + g, b.x + g + f]]):
			for q: Array in [[s0 - f, y0, s0, y1], [s1, y0, s1 + f, y1], [s0 - f, y1, s1 + f, y1 + f]]:
				if fz:
					mk.boxm(Vector3(q[0], q[1], plane[0]), Vector3(q[2], q[3], plane[1]), "yellow")
				else:
					mk.boxm(Vector3(plane[0], q[1], q[0]), Vector3(plane[1], q[3], q[2]), "yellow")
		_meshes[key] = mk.build("door")
	return _meshes[key]


## A coin: a gold disc standing up (its faces along z), a glowing amber inlay on both faces.
static func _coin_mesh() -> ArrayMesh:
	if not _meshes.has("coin"):
		var mk := TLMesh.new(1)
		mk.push(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.045)))
		mk.cyl(0.34, 0.09, 20, "yellow")
		mk.cyl(0.2, 0.11, 16, "beacon", Color.WHITE, -1.0, Vector3(0, -0.01, 0))
		mk.pop()
		_meshes["coin"] = mk.build("coin")
	return _meshes["coin"]


# ------------------------------------------------------------------ the looks of a Home in play
## Makes the looks again when the rules layer changed (its `revision`); none while nothing changed.
func sync(layer: RefCounted) -> void:
	if layer == null or holder == null or int(layer.get("revision")) == revision:
		return
	clear()
	revision = int(layer.get("revision"))
	var zones: Dictionary = layer.get("zones")
	var role := roles(layer.get("rules"))
	var ids: Array = zones.keys()
	ids.sort()
	for z: int in ids:
		var zd: Dictionary = zones[z]
		if str(role.get(z, "")) == "door" and str(zd.get("look", "none")) == "none":
			zd = zd.duplicate()
			zd["opening"] = door_opening(zd.box, solid)
		var n := look_of(zd, str(role.get(z, "")))
		if n == null:
			continue
		holder.add_child(n)
		nodes[z] = n
		looks[z] = str(n.get_meta(&"tl_look", str(zones[z].look)))
		base_y[z] = n.position.y


## A coin is taken (hidden after a short fly-up) or back (grown in). Sparks where it was taken.
func taken(zid: int, is_taken: bool, at_frame: int) -> void:
	if not nodes.has(zid):
		return
	var n: Node3D = nodes[zid]
	if is_taken:
		gone[zid] = [at_frame, true]
		var p: CPUParticles3D = TLStyleFx.preset("sparks", {"scale": 0.55, "life_frames": 30})
		if p != null:
			p.position = n.position
			holder.add_child(p)
			fx.append([p, at_frame + 90])
	else:
		gone[zid] = [at_frame, false]
		n.visible = true


func is_hidden(zid: int) -> bool:
	return nodes.has(zid) and not (nodes[zid] as Node3D).visible


## One physics frame: coins turn and bob, a taken coin flies away, a pad breathes.
func tick(at_frame: int) -> void:
	frame = at_frame
	for z: int in nodes:
		var n: Node3D = nodes[z]
		match str(looks[z]):
			"coin":
				var y := float(base_y[z]) + 0.08 * sin(at_frame * 0.06)
				var s := 1.0
				var spin := at_frame * SPIN
				if gone.has(z):
					var g: Array = gone[z]
					var k := float(at_frame - int(g[0]))
					if bool(g[1]):
						var t := clampf(k / TAKE_FRAMES, 0.0, 1.0)
						y += 0.9 * t
						s = (1.0 - t) * (1.0 + 0.5 * sin(t * PI))
						spin += 14.0 * t
						n.visible = t < 1.0
					else:
						s = clampf(k / BACK_FRAMES, 0.0, 1.0)
						if s >= 1.0:
							gone.erase(z)
				if n.visible:
					n.position.y = y
					n.rotation.y = spin
					n.scale = Vector3.ONE * maxf(s, 0.001)
			"pad":
				var disc: Node3D = n.get_child(0)
				var kick := 0.0
				if kicks.has(z):
					var kt := float(at_frame - int(kicks[z])) / KICK_FRAMES
					kick = 1.0 - kt if kt < 1.0 else 0.0
					if kt >= 1.0:
						kicks.erase(z)
				var breathe := 0.035 * sin(at_frame * 0.08)
				disc.scale = Vector3(1.0 + breathe + 0.35 * kick, 1.0 + 2.5 * kick, 1.0 + breathe + 0.35 * kick)
				if n.get_child_count() > 1:
					var glow: Node3D = n.get_child(1)
					glow.scale = Vector3.ONE * float(n.get_meta(&"tl_r", 1.0)) * 2.4 * (1.0 + 0.12 * sin(at_frame * 0.08 + 1.0) + 1.2 * kick)
			"hazard":
				if n.get_child_count() > 1:
					var sh: Node3D = n.get_child(1)
					var k := 0.5 + 0.5 * sin(at_frame * SHIMMER)
					sh.scale = Vector3.ONE * float(n.get_meta(&"tl_r", 1.0)) * (0.75 + 0.3 * k)
					sh.position.y = 0.2 + 0.25 * k
	var keep := []
	for e: Array in fx:
		if at_frame >= int(e[1]):
			if is_instance_valid(e[0]):
				(e[0] as Node).queue_free()
		else:
			keep.append(e)
	fx = keep


## The pads of zones `ids` kick (a launch went off from them).
func kick(ids: Array, at_frame: int) -> void:
	for z: int in ids:
		if nodes.has(z) and str(looks.get(z, "")) == "pad":
			kicks[z] = at_frame


func set_visible(on: bool) -> void:
	for z: int in nodes:
		var n: Node3D = nodes[z]
		n.visible = on and not (gone.has(z) and bool(gone[z][1]) and frame - int(gone[z][0]) >= TAKE_FRAMES)


func clear() -> void:
	for z: int in nodes:
		if is_instance_valid(nodes[z]):
			(nodes[z] as Node).queue_free()
	for e: Array in fx:
		if is_instance_valid(e[0]):
			(e[0] as Node).queue_free()
	nodes.clear()
	looks.clear()
	base_y.clear()
	gone.clear()
	kicks.clear()
	fx.clear()
	revision = -1


func count() -> int:
	return nodes.size()
