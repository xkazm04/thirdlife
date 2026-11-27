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

const Check := preload("res://kernel/world/build/rules_check.gd")
const ROLE_KEYS := {"": "neon_violet", "start": "neon_lime", "checkpoint": "cyan", "finish": "beacon", "launch": "neon_pink"}
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
	match str(zone.get("look", "none")):
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
		n.set_meta(&"tl_look", str(zone.get("look", "none")))
	return n


## Zone id -> role ("start" | "checkpoint" | "finish") from the rules (saved forms). Finish wins over start, start
## over checkpoint, when one zone has two.
static func roles(rules: Dictionary) -> Dictionary:
	var out := {}
	var rank := {"launch": 1, "checkpoint": 2, "start": 3, "finish": 4}
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
		var n := look_of(zones[z], str(role.get(z, "")))
		if n == null:
			continue
		holder.add_child(n)
		nodes[z] = n
		looks[z] = str(zones[z].look)
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
