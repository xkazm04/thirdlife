extends RefCounted
## D1 (day of 22 Nov 2026): the Home of arm A (Wren Valley, valley.gd) in the normal World. landscape.gd `build` asks
## `wanted(cfg)`; when it is on, the far plain and its mesas are not made, the forest belt keeps only the trees on the
## village's own ground, and `grow` draws the valley round the village (places.gd) after the village is built and
## before the first draw. The visitor walks on it: the valley's own rendered triangles (ground.gd) and its lanes and
## the bridge deck (places.gd) become collider chunks of 96 m in the visitor's space, made and dropped through N5's
## land/chunk_collider.gd as he moves (`ensure`, chained onto the space's `ensure_land`), so what he stands on is what
## is drawn. Only the visitor's space: no pack's physics space is touched (world = alone holds).
##
## The switch: the walk's `landscape.home` ("wren": boot/village.json) turns it on; the environment variable
## TL_HOME=plain gives the old landscape (the far plain and the mesas) back, TL_HOME=wren turns it on for any walk.
const Valley := preload("res://kernel/world/home/valley.gd")
const Places := preload("res://kernel/world/home/places.gd")
const Collider := preload("res://kernel/world/land/chunk_collider.gd")
const Land := preload("res://kernel/world/land/land.gd")
const SWITCH := "TL_HOME"
const CHUNK := 96.0
const KEEP := 2        # chunks kept round the visitor's chunk (5 x 5 = 480 m square: 2 s of flight at cruise)
const DROP := 3        # chunks beyond this (Chebyshev) are dropped

var ground: RefCounted
var border: Rect2
var space: WeakRef
var lanes := {}         # chunk -> triangles of the lanes and the bridge deck whose centre lies in it
var bodies := {}        # chunk -> collider (chunk_collider.gd `build`)
var centre := Vector2i(1 << 30, 1 << 30)
var stats := {"made": 0, "dropped": 0, "faces": 0, "build_usec": 0}


static func wanted(cfg: Dictionary) -> bool:
	var env := OS.get_environment(SWITCH)
	if env == "plain":
		return false
	return env == "wren" or str(cfg.get("home", "")) == "wren"


## The landscape's own config without the far things the Home replaces (the mesas and the clumps on the plain).
static func trim(cfg: Dictionary, on: bool) -> Dictionary:
	if not on:
		return cfg
	var c := cfg.duplicate()
	c["mesas"] = 0
	c["plain_clumps"] = 0
	return c


## The forest belt: only the trees standing on the village's own ground (the hills beyond are the valley's now).
static func keep(xs: Array, terr: RefCounted, on: bool) -> Array:
	if not on:
		return xs
	return xs.filter(func(x: Transform3D) -> bool: return terr.inside(x.origin.x, x.origin.z))


## Draws the valley under `parent` and hangs its collider chunks on `ws`. Returns the build figures (ms by phase).
static func grow(parent: Node3D, cfg: Dictionary, terr: RefCounted, ws: Object) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var valley: RefCounted = Valley.new(int(cfg.get("seed", 7)), terr)
	var artist: RefCounted = Places.new()
	var out: Dictionary = artist.grow(parent, valley)
	var home: RefCounted = (load("res://kernel/world/home/hook.gd") as GDScript).new()
	home.ground = artist.ground
	home.border = valley.border
	home.space = weakref(ws)
	home.bucket(artist.lane_faces)
	if not artist.rail_faces.is_empty():
		var was: String = ws.get("tag")
		ws.set("tag", "home rail")
		ws.call("add_faces", facing_up(artist.rail_faces), "home_rail_faces")
		ws.set("tag", was)
	var prior: Callable = ws.get("ensure_land")
	ws.set("ensure_land", func(p: Vector2) -> void:
		if prior.is_valid():
			prior.call(p)
		home.ensure(p))
	home.ensure(Land.focus(parent, true))     # the ground under the spawn is there before the visitor asks for it
	parent.set_meta(&"tl_home", home)
	out["valley"] = valley.summary().extent
	out["total_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	return out


static func chunk_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))


## The physics reads a triangle's winding (a ground face wound downward reports a downward contact normal, and the
## body is "in the air" on it): every face is wound to face up, and a steep one (a lane's side, a rail) both ways.
static func facing_up(faces: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for f: int in range(0, faces.size() - 2, 3):
		var a := faces[f]
		var b := faces[f + 1]
		var c := faces[f + 2]
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-12:
			continue
		n = n.normalized()
		if n.y >= 0.2:
			out.append_array(PackedVector3Array([a, b, c]))
		elif n.y <= -0.2:
			out.append_array(PackedVector3Array([a, c, b]))
		else:
			out.append_array(PackedVector3Array([a, b, c, a, c, b]))
	return out


func bucket(faces: PackedVector3Array) -> void:
	var up := facing_up(faces)
	for f: int in range(0, up.size() - 2, 3):
		var c := (up[f] + up[f + 1] + up[f + 2]) / 3.0
		var id := chunk_of(Vector2(c.x, c.z))
		if not lanes.has(id):
			lanes[id] = PackedVector3Array()
		var row: PackedVector3Array = lanes[id]
		row.append_array(PackedVector3Array([up[f], up[f + 1], up[f + 2]]))
		lanes[id] = row


## The rendered triangles of the valley ground whose cell centre lies in chunk `id` (the village's own rectangle is the
## village terrain's: left out), and the lanes and the deck over them.
func faces(id: Vector2i) -> PackedVector3Array:
	var out := PackedVector3Array()
	var xs: PackedFloat32Array = ground.xs
	var zs: PackedFloat32Array = ground.zs
	var v: PackedVector3Array = ground.vertices
	var n := xs.size()
	var lo := Vector2(id) * CHUNK
	var hi := lo + Vector2.ONE * CHUNK
	var i0 := maxi(0, xs.bsearch(lo.x) - 1)
	var j0 := maxi(0, zs.bsearch(lo.y) - 1)
	for j in range(j0, zs.size() - 1):
		var cz := (zs[j] + zs[j + 1]) * 0.5
		if cz >= hi.y:
			break
		if cz < lo.y:
			continue
		for i in range(i0, n - 1):
			var cx := (xs[i] + xs[i + 1]) * 0.5
			if cx >= hi.x:
				break
			if cx < lo.x or border.has_point(Vector2(cx, cz)):
				continue
			var k := j * n + i
			out.append_array(PackedVector3Array([v[k], v[k + n + 1], v[k + 1], v[k], v[k + n], v[k + n + 1]]))     # the drawn split, wound up
	if lanes.has(id):
		out.append_array(lanes[id])
	return out


## Called before every move of the visitor (world_space.gd `ensure_land`): the chunks round him exist, far ones go.
func ensure(p: Vector2) -> void:
	var c := chunk_of(p)
	if c == centre:
		return
	var ws: Object = space.get_ref()
	if ws == null:
		return
	var t0 := Time.get_ticks_usec()
	centre = c
	for id: Vector2i in bodies.keys():
		if maxi(absi(id.x - c.x), absi(id.y - c.y)) > DROP:
			Collider.drop(bodies[id], ws)
			bodies.erase(id)
			stats.dropped += 1
	var limit := int(Valley.LIMIT / CHUNK)
	for z in range(c.y - KEEP, c.y + KEEP + 1):
		for x in range(c.x - KEEP, c.x + KEEP + 1):
			var id := Vector2i(x, z)
			if bodies.has(id) or x < -limit or z < -limit or x >= limit or z >= limit:
				continue
			var tri := faces(id)
			if tri.is_empty():
				continue
			bodies[id] = Collider.build(null, Rect2i(), tri, "faces", ws, "home ground", "home_faces")
			stats.made += 1
			stats.faces += tri.size() / 3
	stats.build_usec += Time.get_ticks_usec() - t0


## The height of what the visitor stands on at (x, z) outside the village: the rendered ground (lanes and deck aside).
func ground_y(x: float, z: float) -> float:
	return ground.y(x, z)
