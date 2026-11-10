class_name TLStandin
extends RefCounted
## Plain stand-ins so the kernel runs without WP2 (kits, rigs, style). Nothing here depends on TLKit, TLRigs or
## TLStyle; `ext()` finds them at run time when they are present.

static var _ext_cache: Dictionary = {}
static var _ext_said: Dictionary = {}
static var _has_cache: Dictionary = {}    # script path + "#" + method -> bool (script_has)


## The script of an optional global class ("TLKit", "TLRigs", "TLStyle"), or null with one log line when absent.
## Call its static functions with `script.call("build", ...)`.
static func ext(cls: String) -> GDScript:
	if _ext_cache.has(cls):
		return _ext_cache[cls]
	var found: GDScript = null
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if str(entry["class"]) == cls:
			found = load(str(entry["path"])) as GDScript
			break
	if found == null and not _ext_said.has(cls):
		_ext_said[cls] = true
		print("[tl] %s is not installed; using the kernel stand-in" % cls)
	_ext_cache[cls] = found
	return found


## A rig for `family` (&"biped", &"vehicle", &"bot"): from TLRigs when installed, else the stand-in.
static func rig(family: StringName, params: Dictionary = {}) -> Node3D:
	var rigs: GDScript = ext("TLRigs")
	if rigs != null:
		var built: Variant = rigs.call("build", String(family), params)
		if built is Node3D and check_rig(built as Node3D).is_empty():
			return built
		push_error("TLRigs.build('%s') did not return a usable rig; using the stand-in" % family)
	return standin_rig(family, params)


## The kernel's own plain rig (a capsule, or a box on four wheels), whether or not TLRigs is installed.
static func standin_rig(family: StringName, params: Dictionary = {}) -> Node3D:
	var r: TLStandinRig = TLStandinRig.new()
	r.build(family, params)
	return r


## Readable problems with a rig node (empty when it answers the whole rig table of KIT-RIG-STYLE.md).
static func check_rig(node: Node3D) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	if node == null:
		problems.append("the rig is null")
		return problems
	for m: String in ["metrics", "clips", "play", "set_locomotion", "set_param", "socket", "tick"]:
		if not node.has_method(m):
			problems.append("the rig has no %s()" % m)
	if not ("family" in node):
		problems.append("the rig has no `family`")
	return problems


## Tells TLStyle (when installed) whether this run is headless, and loads the style file. Called once per run.
static func prepare_style(headless: bool) -> void:
	var style: GDScript = ext("TLStyle")
	if style == null:
		return
	style.call("set_headless", headless)
	var problems: Variant = style.call("load_style")
	if problems is PackedStringArray:
		for p: String in problems:
			print("[tl] style: " + p)


## Sun, sky and environment for windowed runs when TLStyle is absent. Idempotent.
static func install_look(host: Node) -> void:
	if host.has_node("TLLook"):
		return
	var style: GDScript = ext("TLStyle")
	if style != null:
		var holder: Node3D = Node3D.new()
		holder.name = "TLLook"
		host.add_child(holder)
		style.call("install", holder)
		return
	var look: Node3D = Node3D.new()
	look.name = "TLLook"
	host.add_child(look)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.shadow_enabled = true
	sun.light_energy = 1.2
	look.add_child(sun)
	var env: Environment = Environment.new()
	var sky: Sky = Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	look.add_child(we)


## A flat-colour material for visuals the kernel makes (TLBodies.make, TLBall, the stand-ins). With the style
## installed it is the style's toon material in that colour (TLStyle.flat_material; WP5), so kernel-made geometry is
## lit like kit geometry; without the style it is a plain StandardMaterial3D.
static func material(color: Color, material_id: String = "") -> Material:
	var style: GDScript = ext("TLStyle")
	if style != null and script_has(style, "flat_material"):
		var made: Variant = style.call("flat_material", color, 0.6 if material_id == "steel" else 0.0)
		if made is Material:
			return made
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m


const MATERIAL_COLORS: Dictionary = {
	"ice": Color(0.78, 0.9, 0.97), "concrete": Color(0.62, 0.62, 0.6), "steel": Color(0.55, 0.6, 0.66),
	"wood": Color(0.6, 0.44, 0.27), "rubber": Color(0.14, 0.14, 0.15), "asphalt": Color(0.24, 0.24, 0.26),
	"grass": Color(0.36, 0.58, 0.3), "dirt": Color(0.45, 0.34, 0.24), "glass": Color(0.7, 0.86, 0.9),
	"plastic": Color(0.9, 0.42, 0.2), "snow": Color(0.95, 0.96, 0.98), "water": Color(0.25, 0.5, 0.75),
	"stone": Color(0.5, 0.5, 0.52), "fabric": Color(0.72, 0.3, 0.36),
}


static func material_for(material_id: String) -> Material:
	return material(MATERIAL_COLORS.get(material_id, Color(0.8, 0.8, 0.8)), material_id)


## True when a script (an optional class from `ext`) declares a method: the duck-typed seam checks before it calls.
static func script_has(s: GDScript, method: String) -> bool:
	var key: String = s.resource_path + "#" + method
	if not _has_cache.has(key):
		var found: bool = false
		for mi: Dictionary in s.get_script_method_list():
			if mi["name"] == method:
				found = true
				break
		_has_cache[key] = found
	return _has_cache[key]


## WP5. A pack that built no venue still gets a floor to stand its scene on: when nothing under `world` came from a
## kit layout or a `ground_patch`, the style's default ground (visual only, no body) is put just under the lowest
## visual of the pack. Windowed runs only; called by the worker after `_pack_setup`. Idempotent.
static func install_default_ground(host: Node, world: Node3D) -> void:
	var look: Node = host.get_node_or_null("TLLook")
	var style: GDScript = ext("TLStyle")
	if look == null or style == null or look.has_node("TLStyleGround") or not script_has(style, "ground"):
		return
	var box: Array = [false, AABB()]
	if _scan_world(world, box):
		return
	var y: float = (box[1] as AABB).position.y - 0.02 if bool(box[0]) else 0.0
	var g: Variant = style.call("ground", y)
	if g is Node3D:
		look.add_child(g as Node3D)
		print("[tl] the pack built no kit ground: the style's default ground is at y = %.2f (visual only)" % (g as Node3D).position.y)


## True when the tree holds a kit ground (a layout or a ground_patch); otherwise grows box[1] by every visible mesh.
static func _scan_world(n: Node, box: Array) -> bool:
	if String(n.name).begins_with("Layout_") or str(n.get_meta(&"tl_kind", "")) == "ground_patch":
		return true
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).is_visible_in_tree():
		var b: AABB = (n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()
		box[1] = b if not bool(box[0]) else (box[1] as AABB).merge(b)
		box[0] = true
	for c: Node in n.get_children():
		if _scan_world(c, box):
			return true
	return false


## A part the game moves, in the kit's dynamic-prop convention (no body; metadata tl_dynamic, tl_shape,
## tl_shape_offset, tl_material, tl_mass_hint). `kind`: &"puck" (radius, height), &"ball" (radius) or &"box"
## (a block radius*2 wide and deep, `height` high). For kernel examples and tests; real parts come from TLKit.
static func dynamic_part(kind: StringName, radius: float, height: float, material_id: String, mass_hint: float) -> Node3D:
	var part: Node3D = Node3D.new()
	part.name = "Standin_" + String(kind)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var shape: Shape3D
	if kind == &"puck":
		var cyl: CylinderShape3D = CylinderShape3D.new()
		cyl.radius = radius
		cyl.height = height
		shape = cyl
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = radius
		cm.bottom_radius = radius
		cm.height = height
		mi.mesh = cm
	elif kind == &"ball":
		var sp: SphereShape3D = SphereShape3D.new()
		sp.radius = radius
		shape = sp
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = radius
		sm.height = radius * 2.0
		mi.mesh = sm
	else:
		var bx: BoxShape3D = BoxShape3D.new()
		bx.size = Vector3(radius * 2.0, height, radius * 2.0)
		shape = bx
		var bm: BoxMesh = BoxMesh.new()
		bm.size = bx.size
		mi.mesh = bm
	mi.material_override = material_for(material_id)
	part.add_child(mi)
	part.set_meta(&"tl_kind", "standin_" + String(kind))
	part.set_meta(&"tl_params", {"radius": radius, "height": height})
	part.set_meta(&"tl_dynamic", true)
	part.set_meta(&"tl_shape", shape)
	part.set_meta(&"tl_shape_offset", Vector3.ZERO)
	part.set_meta(&"tl_material", material_id)
	part.set_meta(&"tl_mass_hint", mass_hint)
	return part


## A fracturable part in the kit's `Intact` / `Pieces` convention, made of boxes: a wall `size` (x wide, y high,
## z thick) cut into nx * ny pieces. For kernel examples and tests; real parts come from TLKit.
static func fracturable_wall(size: Vector3, nx: int, ny: int, material_id: String = "concrete") -> Node3D:
	var part: Node3D = Node3D.new()
	part.name = "StandinWall"
	part.set_meta(&"tl_kind", "standin_wall")
	part.set_meta(&"tl_params", {"size": size, "nx": nx, "ny": ny})
	var intact: Node3D = Node3D.new()
	intact.name = "Intact"
	part.add_child(intact)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material_for(material_id)
	mi.position.y = size.y * 0.5
	intact.add_child(mi)
	var sb: StaticBody3D = StaticBody3D.new()
	sb.set_meta(&"tl_material", material_id)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position.y = size.y * 0.5
	intact.add_child(sb)
	var pieces: Node3D = Node3D.new()
	pieces.name = "Pieces"
	pieces.visible = false
	part.add_child(pieces)
	var ps: Vector3 = Vector3(size.x / float(nx), size.y / float(ny), size.z)
	var density: float = float(TLLaws.material(material_id)["density"])
	for iy: int in ny:
		for ix: int in nx:
			var p: MeshInstance3D = MeshInstance3D.new()
			var pm: BoxMesh = BoxMesh.new()
			pm.size = ps * 0.98
			p.mesh = pm
			p.material_override = material_for(material_id)
			p.position = Vector3(-size.x * 0.5 + ps.x * (float(ix) + 0.5), ps.y * (float(iy) + 0.5), 0.0)
			var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
			var h: Vector3 = ps * 0.49
			shape.points = PackedVector3Array([Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z),
				Vector3(h.x, h.y, -h.z), Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z)])
			p.set_meta(&"tl_shape", shape)
			p.set_meta(&"tl_material", material_id)
			p.set_meta(&"tl_mass_hint", density * ps.x * ps.y * ps.z)
			pieces.add_child(p)
	return part
