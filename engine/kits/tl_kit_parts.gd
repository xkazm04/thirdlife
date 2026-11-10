class_name TLKitParts
extends RefCounted
## Builders behind TLKit.build: one branch per part kind. `n` is the part root (already tagged tl_kind / tl_params),
## `p` the params with defaults filled in. Geometry comes from the lane-B generators (TLKitArena, TLKitSite, ...).
## Node convention (kits/KIT.md): MeshInstance3D children; StaticBody3D children tagged tl_material; Intact / Pieces
## for fracturable parts; dynamic props carry tl_shape / tl_material / tl_mass_hint on the root and have no body.

const SURFACE_KEY: Dictionary = {"grass": "grass", "dirt": "dirt", "concrete": "concrete", "asphalt": "tarmac", "ice": "ice", "snow": "white", "stone": "stone", "wood": "plank"}
const DENSITY: Dictionary = {"concrete": 2400.0, "wood": 600.0, "rubber": 1100.0, "plastic": 950.0, "steel": 7800.0, "stone": 2600.0}


static func mesh(n: Node3D, mk: TLMesh, mname: String = "Mesh", shadows: bool = true) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = mname
	mi.mesh = mk.build(mname.to_snake_case())
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	return mi


static func body(n: Node3D, material: String, bname: String = "Body") -> StaticBody3D:
	var b: StaticBody3D = StaticBody3D.new()
	b.name = bname
	b.set_meta("tl_material", material)
	n.add_child(b)
	return b


static func shape(b: Node3D, s: Shape3D, t: Transform3D = Transform3D.IDENTITY) -> CollisionShape3D:
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = s
	cs.transform = t
	cs.name = "Shape%d" % b.get_child_count()
	b.add_child(cs)
	return cs


static func box(b: Node3D, size: Vector3, centre: Vector3, yaw: float = 0.0) -> void:
	var s: BoxShape3D = BoxShape3D.new()
	s.size = size.max(Vector3(0.02, 0.02, 0.02))
	shape(b, s, Transform3D(Basis(Vector3.UP, yaw), centre))


static func cyl(b: Node3D, r: float, h: float, centre: Vector3) -> void:
	var s: CylinderShape3D = CylinderShape3D.new()
	s.radius = r
	s.height = h
	shape(b, s, Transform3D(Basis.IDENTITY, centre))


static func hull(b: Node3D, pts: PackedVector3Array) -> void:
	var s: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	s.points = pts
	shape(b, s)


static func trimesh(b: Node3D, faces: PackedVector3Array) -> void:
	var s: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	s.set_faces(faces)
	shape(b, s)


## One box around everything the generator emitted.
static func auto_box(n: Node3D, mk: TLMesh, material: String) -> StaticBody3D:
	var bb: AABB = mk.aabb()
	var b: StaticBody3D = body(n, material)
	box(b, bb.size, bb.get_center())
	return b


static func dynamic(n: Node3D, s: Shape3D, material: String, volume: float) -> void:
	n.set_meta("tl_dynamic", true)
	n.set_meta("tl_shape", s)
	n.set_meta("tl_material", material)
	n.set_meta("tl_mass_hint", snappedf(volume * float(DENSITY.get(material, 1000.0)), 0.001))


static func make(kind: String, n: Node3D, p: Dictionary) -> void:
	var mk: TLMesh = TLMesh.new(int(p.get("seed", 1)))
	match kind:
		"ground_patch":
			var sx: float = p["size_x"]
			var sz: float = p["size_z"]
			var th: float = p["thickness"]
			mk.uv_fixed = true   # an `ice` patch is plain ice: no rink markings (uv = 0)
			mk.box(Vector3(sx, th, sz), SURFACE_KEY[p["surface"]], Color.WHITE, 0.0, Vector3(0, -th * 0.5, 0))
			mesh(n, mk)
			box(body(n, p["surface"]), Vector3(sx, th, sz), Vector3(0, -th * 0.5, 0))
		"road_spline":
			var cps: Array = []
			var ys: Array = []
			for q: Array in p["points"]:
				cps.append(Vector2(q[0], q[q.size() - 1]))
				ys.append(float(q[1]) if q.size() == 3 else float(p["y"]))
			var path: TLKitPath = TLKitPath.new(cps, bool(p["closed"]), 2.0)
			var total: float = maxf(path.length, 0.001)
			var cn: int = cps.size()
			path.set_heights(func(s: float, _q: Vector2) -> float:
				var f: float = clampf(s / total, 0.0, 1.0) * float(cn if bool(p["closed"]) else cn - 1)
				var i0: int = int(floorf(f)) % cn
				var i1: int = (i0 + 1) % cn if bool(p["closed"]) else mini(i0 + 1, cn - 1)
				return lerpf(float(ys[i0]), float(ys[i1]), f - floorf(f)))
			var rm: TLMesh = TLKitRoad.build(path, float(p["half_width"]), float(p["kerb_width"]), 0.14, 2, 0.07)
			mesh(n, rm, "Road")
			trimesh(body(n, "asphalt"), rm.faces())
			n.set_meta("tl_length", path.length)
		"kerb":
			var kl: float = p["length"]
			var kn: int = maxi(1, roundi(kl / 2.0))
			for i: int in kn:
				mk.boxm(Vector3(kl * float(i) / float(kn), 0, -float(p["width"]) * 0.5), Vector3(kl * float(i + 1) / float(kn), float(p["height"]), float(p["width"]) * 0.5), "curb_red" if i % 2 == 0 else "curb_white", Color.WHITE, 0.02)
			mesh(n, mk)
			auto_box(n, mk, "concrete")
		"barrier_wall":
			var bw: float = p["block_w"]
			var nb: int = int(p["blocks"])
			var offs: Array = []
			for i: int in nb:
				offs.append(Vector3((float(i) - float(nb - 1) * 0.5) * (bw + 0.06), 0, 0))
			fracture(n, Vector3(bw, float(p["height"]), float(p["depth"])), offs, int(p["cells"]), int(p["seed"]), "barrier", "barrier_dark", true, "concrete")
		"crate":
			var cs: float = p["size"]
			fracture(n, Vector3(cs, cs, cs), [Vector3.ZERO], int(p["cells"]), int(p["seed"]), "plank", "wood_dark", false, "wood")
		"rink":
			_rink(n, p)
		"stands":
			var sm: TLMesh = TLKitArena.stands(float(p["length"]) + 8.0, -6.4, int(p["rows"]), float(p["row_depth"]), float(p["rise"]), int(p["seed"]) - 32)
			mesh(n, sm)
			var sb: StaticBody3D = body(n, "concrete")
			for i: int in int(p["rows"]):
				var top: float = float(i + 1) * float(p["rise"])
				box(sb, Vector3(float(p["length"]), top + 0.5, float(p["row_depth"])), Vector3(0, (top - 0.5) * 0.5, -(float(i) + 0.5) * float(p["row_depth"])))
			var zb: float = -float(p["rows"]) * float(p["row_depth"])
			var topb: float = float(p["rows"]) * float(p["rise"])
			box(sb, Vector3(float(p["length"]) + 1.0, topb + 5.3, 0.6), Vector3(0, (topb + 4.3) * 0.5, zb - 0.3))
		"arch_rib":
			var holo: bool = p["hologram"]
			var rmk: TLMesh = TLKitArena.rib_mesh(float(p["span"]), float(p["apex"]), float(p["exponent"]), float(p["purlin_dx"]), "holo" if holo else "rib_built", "holo" if holo else "rib_steel")
			var rmi: MeshInstance3D = mesh(n, rmk, "Rib", not holo)
			if not TLStyle.headless():
				rmi.set_instance_shader_parameter(&"build", 0.0 if holo else 1.0)
			if bool(p["footings"]) and not holo:
				var fm: TLMesh = TLMesh.new(35)
				var fb: StaticBody3D = body(n, "concrete", "Footings")
				for sz: float in [-float(p["span"]), float(p["span"])]:
					fm.box(Vector3(2.0, 1.1, 2.0), "concrete", Color.WHITE, 0.08, Vector3(0, 0.45, sz))
					fm.box(Vector3(1.5, 0.3, 1.5), "concrete_dark", Color.WHITE, 0.04, Vector3(0, 1.1, sz))
					box(fb, Vector3(2.0, 1.25, 2.0), Vector3(0, 0.625, sz))
				mesh(n, fm, "FootingMesh")
		"scaffold":
			var decks: Array = []
			for dl: Variant in p["decks"]:
				if int(dl) <= int(p["levels"]):
					decks.append(int(dl))
			var scm: TLMesh = TLKitSite.scaffold(int(p["bays"]), int(p["levels"]), float(p["bay_w"]), float(p["bay_d"]), float(p["level_h"]), decks)
			mesh(n, scm)
			var W: float = float(p["bays"]) * float(p["bay_w"])
			var db: StaticBody3D = body(n, "wood", "Decks")
			for dl: int in decks:
				box(db, Vector3(W, 0.12, float(p["bay_d"]) + 0.12), Vector3(W * 0.5, float(dl) * float(p["level_h"]) + 0.06, float(p["bay_d"]) * 0.5))
			var pb: StaticBody3D = body(n, "steel", "Frame")
			var H: float = float(p["levels"]) * float(p["level_h"]) + 1.0
			for i: int in int(p["bays"]) + 1:
				for z: float in [0.0, float(p["bay_d"])]:
					box(pb, Vector3(0.16, H, 0.16), Vector3(float(i) * float(p["bay_w"]), H * 0.5, z))
		"crane":
			var cr: Node3D = TLKitSite.crane(float(p["height"]), float(p["mast"]), float(p["jib"]), float(p["counter"]))
			for c: Node in cr.get_children():
				cr.remove_child(c)
				n.add_child(c)
			cr.free()
			(n.get_node("Slew") as Node3D).rotation_degrees.y = float(p["slew"])
			(n.get_node("Slew/Hoist") as Node3D).position.x = float(p["jib"]) * float(p["trolley"])
			var cb: StaticBody3D = body(n, "steel")
			box(cb, Vector3(float(p["mast"]), float(p["height"]), float(p["mast"])), Vector3(0, float(p["height"]) * 0.5, 0))
			box(body(n, "concrete", "Base"), Vector3(float(p["mast"]) + 3.2, 1.65, float(p["mast"]) + 3.2), Vector3(0, 0.825, 0))
		"house":
			var hm: TLMesh = TLKitHouse.house(float(p["width"]), float(p["depth"]), float(p["wall_h"]), float(p["roof_rise"]))
			mesh(n, hm)
			var hb: StaticBody3D = body(n, "wood")
			box(hb, Vector3(float(p["width"]), float(p["wall_h"]) + float(p["roof_rise"]) * 0.5, float(p["depth"])), Vector3(0, (float(p["wall_h"]) + float(p["roof_rise"]) * 0.5) * 0.5, 0))
			if bool(p["lights"]) and not TLStyle.headless():
				var kx: float = float(p["width"]) / 8.0
				var kz: float = float(p["depth"]) / 5.6
				for lp: Vector3 in [Vector3(-2.4 * kx, 2.0, 4.2 * kz), Vector3(2.4 * kx, 2.0, 4.2 * kz), Vector3(0.8 * kx, 2.6, 3.6 * kz)]:
					var ol: OmniLight3D = OmniLight3D.new()
					ol.light_color = TLStyle.color("window")
					ol.light_energy = TLStyle.num("lights", "window", 5.0)
					ol.omni_range = TLStyle.num("lights", "window_range", 7.5)
					ol.omni_attenuation = 1.4
					ol.position = lp
					ol.name = "Light%d" % n.get_child_count()
					n.add_child(ol)
		"timber_frame":
			var tfm: TLMesh = TLKitHouse.frame(float(p["width"]), float(p["depth"]), float(p["height"]), float(p["roof_rise"]))
			mesh(n, tfm)
			var tb: StaticBody3D = body(n, "wood")
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					box(tb, Vector3(0.3, float(p["height"]), 0.3), Vector3(sx * float(p["width"]) * 0.5, float(p["height"]) * 0.5, sz * float(p["depth"]) * 0.5))
		"tree":
			var th2: float = p["height"]
			var tm: TLMesh
			match String(p["species"]):
				"pine": tm = TLKitNature.pine(int(p["seed"]), th2, 5, th2 * 0.24)
				"broadleaf": tm = TLKitNature.broadleaf(int(p["seed"]), th2)
				_:
					tm = TLKitNature.hero_tree()
					th2 = tm.aabb().size.y
			mesh(n, tm)
			cyl(body(n, "wood"), maxf(0.12, th2 * 0.03), th2 * 0.5, Vector3(0, th2 * 0.25, 0))
		"rock":
			var rk: TLMesh = TLKitNature.rock(int(p["seed"]), float(p["size"]), float(p["squash"]))
			mesh(n, rk)
			hull(body(n, "stone"), rk.all_points())
		"bush":
			mesh(n, TLKitNature.bush(int(p["seed"]), float(p["size"])))
		"fence":
			var fa: Vector3 = Vector3.ZERO
			var fb2: Vector3 = Vector3(float(p["length"]), 0, 0)
			if String(p["style"]) == "mesh":
				TLKitSite.add_site_fence(mk, fa, fb2)
			else:
				TLKitSite.add_fence(mk, fa, fb2)
			mesh(n, mk)
			var fbb: AABB = mk.aabb()
			box(body(n, "steel" if String(p["style"]) == "mesh" else "wood"), Vector3(fbb.size.x, fbb.size.y, 0.14), fbb.get_center())
		"light_mast":
			var mh: float = p["height"]
			TLKitSite.add_light_mast(mk, Vector3.ZERO, mh, 0.0)
			mesh(n, mk)
			cyl(body(n, "steel"), 0.3, mh, Vector3(0, mh * 0.5, 0))
			var e: float = TLStyle.num("lights", "mast", 0.0)
			if bool(p["light"]) and e > 0.0 and not TLStyle.headless():
				var sl: SpotLight3D = SpotLight3D.new()
				sl.name = "Light"
				sl.light_color = TLStyle.color("window")
				sl.light_energy = e
				sl.spot_range = mh * 2.6
				sl.spot_angle = 36.0
				sl.spot_angle_attenuation = 0.5
				sl.spot_attenuation = 0.35
				sl.shadow_enabled = false
				sl.position = Vector3(0, mh + 0.4, 0)
				# aimed at the ground in front of the lamp head (+Z): -Z of the light looks down and forward
				sl.basis = Basis.looking_at(Vector3(0, -mh, mh * 0.75).normalized(), Vector3.UP)
				n.add_child(sl)
		"sign":
			TLKitSite.add_sign(mk, Vector3.ZERO, 0.0, String(p["color"]))
			mesh(n, mk)
			auto_box(n, mk, "wood")
		"flag":
			TLKitSite.add_flag(mk, Vector3.ZERO, float(p["height"]), String(p["color"]))
			mesh(n, mk)
			cyl(body(n, "steel"), 0.08, float(p["height"]), Vector3(0, float(p["height"]) * 0.5, 0))
		"scoreboard":
			TLKitSite.add_scoreboard(mk, Vector3.ZERO, 0.0)
			mesh(n, mk)
			auto_box(n, mk, "steel")
		"tyre_stack":
			TLKitSite.add_tyres(mk, Vector3.ZERO, 0.0, int(p["columns"]))
			mesh(n, mk)
			auto_box(n, mk, "rubber")
		"watch_tower":
			TLKitSite.add_watch_tower(mk, Vector3.ZERO, 0.0, float(p["height"]))
			mesh(n, mk)
			auto_box(n, mk, "wood")
		"pond":
			var water: bool = String(p["surface"]) == "water"
			mk.uv_fixed = true   # plain ice: no rink markings
			TLKitSite.add_pond(mk, Vector3.ZERO, float(p["radius_x"]), float(p["radius_z"]), "water" if water else "pond_ice")
			mesh(n, mk, "Mesh", false)
			if water:
				n.set_meta("tl_material", "water")
			else:
				box(body(n, "ice"), Vector3(float(p["radius_x"]) * 1.7, 0.3, float(p["radius_z"]) * 1.7), Vector3(0, -0.09, 0))
		"bridge":
			TLKitSite.add_bridge(mk, Vector3.ZERO, 0.0, float(p["length"]), float(p["width"]), int(p["spans"]), float(p["rise"]))
			mesh(n, mk)
			trimesh(body(n, "stone"), mk.faces())
		"lumber":
			TLKitSite.add_lumber(mk, Vector3.ZERO, float(p["length"]), float(p["width"]), int(p["layers"]), 0.0)
			mesh(n, mk)
			auto_box(n, mk, "wood")
		"pallet":
			TLKitSite.add_pallet(mk, Vector3.ZERO, int(p["rows"]), 0.0)
			mesh(n, mk)
			auto_box(n, mk, "wood")
		"cone":
			TLKitSite.add_cone(mk, Vector3.ZERO)
			mesh(n, mk)
			auto_box(n, mk, "plastic")
		"barricade":
			TLKitSite.add_barricade(mk, Vector3.ZERO, float(p["width"]), 0.0)
			mesh(n, mk)
			auto_box(n, mk, "wood")
		"cabin":
			TLKitSite.add_cabin(mk, Vector3.ZERO, 0.0)
			mesh(n, mk)
			auto_box(n, mk, "steel")
		"marshal_post":
			TLKitSite.add_marshal_post(mk, Vector3.ZERO, 0.0)
			mesh(n, mk)
			auto_box(n, mk, "wood")
		"entrance":
			TLKitSite.add_entrance(mk, Vector3.ZERO, 0.0)
			mesh(n, mk)
			var eb: AABB = mk.aabb()
			var ebody: StaticBody3D = body(n, "concrete")
			for sx: float in [-1.0, 1.0]:   # two piers: the opening stays walkable
				box(ebody, Vector3(eb.size.x * 0.18, eb.size.y, eb.size.z), eb.get_center() + Vector3(sx * eb.size.x * 0.41, 0, 0))
		"stones":
			for i: int in int(p["count"]):
				mk.box(Vector3(0.5, 0.5, 0.5), "stone", Color(0.9 + 0.05 * (i % 2), 0.9, 0.9), 0.05, Vector3(i * 0.62, 0.25, -0.1 * (i % 2)))
			mesh(n, mk)
			auto_box(n, mk, "stone")
		"goal":
			_goal(n, p)
		"puck":
			mk.cyl(float(p["radius"]), float(p["height"]), 14, "black")
			mesh(n, mk)
			var ps: CylinderShape3D = CylinderShape3D.new()
			ps.radius = float(p["radius"])
			ps.height = float(p["height"])
			n.set_meta("tl_shape_offset", Vector3(0, float(p["height"]) * 0.5, 0))
			dynamic(n, ps, "rubber", PI * float(p["radius"]) * float(p["radius"]) * float(p["height"]))
		"ball":
			var br: float = p["radius"]
			mk.blob(Vector3(br, br, br), 2, 0.0, String(p["color"]), Color.WHITE, 0.0, Vector3(0, br, 0))
			mesh(n, mk)
			var bs: SphereShape3D = SphereShape3D.new()
			bs.radius = br
			n.set_meta("tl_shape_offset", Vector3(0, br, 0))
			dynamic(n, bs, "rubber", 4.0 / 3.0 * PI * br * br * br * 0.12)   # hollow
		"paddle":
			var sz2: Vector3 = Vector3(float(p["length"]), float(p["height"]), float(p["depth"]))
			mk.rbox(sz2, String(p["color"]), Color.WHITE, minf(sz2.y, sz2.z) * 0.3, Vector3(0, sz2.y * 0.5, 0))
			mk.box(Vector3(sz2.x * 0.9, sz2.y * 0.25, sz2.z * 1.04), "white", Color.WHITE, 0.0, Vector3(0, sz2.y * 0.5, 0))
			mesh(n, mk)
			var pbx: BoxShape3D = BoxShape3D.new()
			pbx.size = sz2
			n.set_meta("tl_shape_offset", Vector3(0, sz2.y * 0.5, 0))
			dynamic(n, pbx, "plastic", sz2.x * sz2.y * sz2.z * 0.3)
		_:
			push_error("TLKitParts: no builder for '%s'" % kind)


## Fracturable part: Intact (one mesh + one static body) and Pieces (hidden; one MeshInstance3D per piece with
## tl_shape = ConvexPolygonShape3D, tl_material, tl_mass_hint). The kit never creates rigid bodies.
static func fracture(n: Node3D, size: Vector3, offsets: Array, cells: int, seed_: int, key_out: String, key_in: String, rebar: bool, material: String) -> void:
	var intact: Node3D = Node3D.new()
	intact.name = "Intact"
	n.add_child(intact)
	var pieces: Node3D = Node3D.new()
	pieces.name = "Pieces"
	pieces.visible = false
	n.add_child(pieces)
	var im: TLMesh = TLMesh.new(seed_)
	var ib: StaticBody3D = body(intact, material)
	var dens: float = float(DENSITY.get(material, 1000.0)) * (0.25 if material == "wood" else 1.0)
	for bi: int in offsets.size():
		var o: Vector3 = offsets[bi]
		var tint: float = 0.94 + 0.06 * float((seed_ + bi) % 2) if rebar else 1.0   # neighbouring blocks differ a little (lane B)
		im.box(size, key_out, Color(tint, tint, tint), 0.04, o + Vector3(0, size.y * 0.5, 0))
		if rebar:
			im.box(Vector3(size.x * 0.96, 0.05, size.z * 0.5), "curb_red" if (seed_ + bi) % 2 == 0 else "curb_white", Color.WHITE, 0.0, o + Vector3(0, size.y + 0.005, 0))
		else:
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					im.box(Vector3(size.x * 0.1, size.y * 1.01, size.z * 0.1), key_in, Color.WHITE, 0.01, o + Vector3(sx * size.x * 0.46, size.y * 0.5, sz * size.z * 0.46))
		box(ib, size, o + Vector3(0, size.y * 0.5, 0))
		var blk: Dictionary = TLKitWall.block(size.x, size.y, size.z, cells, seed_ * 131 + bi, tint, key_out, key_in, rebar)
		var k: int = 0
		for ch: Dictionary in blk["chunks"]:
			var pm: MeshInstance3D = MeshInstance3D.new()
			pm.name = "Piece%d_%d" % [bi, k]
			pm.mesh = ch["mesh"]
			pm.position = o + (ch["centre"] as Vector3)
			var cs: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
			cs.points = ch["pts"]
			pm.set_meta("tl_shape", cs)
			pm.set_meta("tl_material", material)
			var bb: AABB = AABB(Vector3.ZERO, Vector3.ZERO)
			for q: Vector3 in (ch["pts"] as PackedVector3Array):
				bb = bb.expand(q)
			pm.set_meta("tl_mass_hint", snappedf(maxf(0.05, bb.size.x * bb.size.y * bb.size.z * 0.5 * dens), 0.01))
			pieces.add_child(pm)
			k += 1
	mesh(intact, im)


static func _goal(n: Node3D, p: Dictionary) -> void:
	var mk: TLMesh = TLMesh.new(36)
	var w: float = float(p["width"]) * 0.5
	var hgt: float = p["height"]
	var depth: float = p["depth"]
	mk.bar(Vector3(0, 0, -w), Vector3(0, hgt, -w), 0.1, 0.1, "goal_red", Color.WHITE, 0.02)
	mk.bar(Vector3(0, 0, w), Vector3(0, hgt, w), 0.1, 0.1, "goal_red", Color.WHITE, 0.02)
	mk.bar(Vector3(0, hgt, -w), Vector3(0, hgt, w), 0.1, 0.1, "goal_red", Color.WHITE, 0.02)
	# the net is a cage of thin bars (an open mouth reads from a chase camera; a solid hull read as a white box)
	var bw: float = w * 0.85
	var bh: float = hgt * 0.62
	for sz: float in [-1.0, 1.0]:
		mk.bar(Vector3(0, 0.03, sz * w), Vector3(depth, 0.03, sz * bw), 0.05, 0.05, "goal_red")
		mk.bar(Vector3(0, hgt, sz * w), Vector3(depth, bh, sz * bw), 0.04, 0.04, "goal_red")
		mk.bar(Vector3(depth, 0.03, sz * bw), Vector3(depth, bh, sz * bw), 0.04, 0.04, "goal_red")
		for k: int in range(1, 4):
			var f: float = float(k) / 4.0
			mk.bar(Vector3(depth * f, 0.03, sz * lerpf(w, bw, f)), Vector3(depth * f, lerpf(hgt, bh, f), sz * lerpf(w, bw, f)), 0.018, 0.018, "goal_net")
		mk.bar(Vector3(0, hgt * 0.5, sz * w), Vector3(depth, bh * 0.5, sz * bw), 0.018, 0.018, "goal_net")
	mk.bar(Vector3(depth, 0.03, -bw), Vector3(depth, 0.03, bw), 0.05, 0.05, "goal_red")
	mk.bar(Vector3(depth, bh, -bw), Vector3(depth, bh, bw), 0.04, 0.04, "goal_red")
	var nv: int = maxi(4, roundi(w * 2.0 / 0.26))
	for k: int in range(1, nv):
		var z: float = lerpf(-1.0, 1.0, float(k) / float(nv))
		mk.bar(Vector3(depth, 0.03, z * bw), Vector3(depth, bh, z * bw), 0.018, 0.018, "goal_net")
		mk.bar(Vector3(0, hgt, z * w), Vector3(depth, bh, z * bw), 0.018, 0.018, "goal_net")
	for k: int in range(1, 3):
		mk.bar(Vector3(depth, bh * float(k) / 3.0, -bw), Vector3(depth, bh * float(k) / 3.0, bw), 0.018, 0.018, "goal_net")
	mesh(n, mk)
	var fb: StaticBody3D = body(n, "steel", "Frame")
	box(fb, Vector3(0.1, hgt, 0.1), Vector3(0, hgt * 0.5, -w))
	box(fb, Vector3(0.1, hgt, 0.1), Vector3(0, hgt * 0.5, w))
	box(fb, Vector3(0.1, 0.1, w * 2.0), Vector3(0, hgt, 0))
	var nb: StaticBody3D = body(n, "fabric", "Net")   # back, two sides and the top: open towards -X so a puck can enter
	box(nb, Vector3(0.06, hgt * 0.7, w * 1.8), Vector3(depth, hgt * 0.35, 0))
	box(nb, Vector3(depth, hgt * 0.8, 0.06), Vector3(depth * 0.5, hgt * 0.4, -w * 0.93))
	box(nb, Vector3(depth, hgt * 0.8, 0.06), Vector3(depth * 0.5, hgt * 0.4, w * 0.93))
	box(nb, Vector3(depth, 0.06, w * 1.8), Vector3(depth * 0.5, hgt * 0.85, 0))
	n.set_meta("tl_mouth", {"width": w * 2.0, "height": hgt, "depth": depth})   # for a goal sensor: the kernel owns Area3D


static func _rink(n: Node3D, p: Dictionary) -> void:
	var L: float = p["length"]
	var W: float = p["width"]
	var r: float = clampf(float(p["corner_r"]), 0.0, minf(W, L) * 0.5 - 0.5)
	var gh: float = p["glass_h"]
	var mk: TLMesh = TLMesh.new(31)
	var path: Array = TLKitArena.rrect(L, W, maxf(r, 0.05), 7)
	var cnt: int = path.size()
	var poly: PackedVector2Array = PackedVector2Array()
	for q: Vector2 in path:
		poly.append(q)
	# the sheet carries its own half sizes in UV: the toon shader draws the markings in part space from them
	mk.uv_fixed = true
	mk.uv_value = Vector2(L * 0.5, W * 0.5) if bool(p["markings"]) else Vector2.ZERO
	mk.prism(poly, -0.5, 0.05, "ice", Color.WHITE, 1.0, true, false)
	mk.uv_fixed = false
	box(body(n, "ice", "Ice"), Vector3(L, 0.55, W), Vector3(0, -0.225, 0))
	var ap: float = p["apron"]
	if ap > 0.0:
		var apoly: PackedVector2Array = PackedVector2Array()
		for q: Vector2 in TLKitArena.rrect(L + ap * 2.0, W + ap * 2.0, r + ap, 7):
			apoly.append(q)
		mk.prism(apoly, -0.9, -0.05, "concrete", Color(0.95, 0.95, 0.95), 1.0, true, false)
		box(body(n, "concrete", "Apron"), Vector3(L + ap * 2.0, 0.85, W + ap * 2.0), Vector3(0, -0.475, 0))
	if bool(p["boards"]):
		var bb: StaticBody3D = body(n, "plastic", "Boards")
		var gb: StaticBody3D = body(n, "glass", "Glass") if bool(p["glass"]) else null
		for i: int in cnt:
			var p0: Vector2 = path[i]
			var p1: Vector2 = path[(i + 1) % cnt]
			TLKitArena.slab(mk, p0, p1, 0.2, 0.05, 0.34, "boards_kick")
			TLKitArena.slab(mk, p0, p1, 0.2, 0.34, 1.12, "boards")
			TLKitArena.slab(mk, p0, p1, 0.28, 1.12, 1.2, "steel_light")
			var d: Vector2 = p1 - p0
			if d.length() < 1e-4:
				continue
			var mid: Vector2 = (p0 + p1) * 0.5
			var yaw: float = atan2(-d.y, d.x)
			box(bb, Vector3(d.length() + 0.08, 1.15, 0.24), Vector3(mid.x, 0.625, mid.y), yaw)
			if gb != null:
				TLKitArena.slab(mk, p0, p1, 0.05, 1.2, 1.2 + gh, "glass", Color.WHITE, 0.0)
				box(gb, Vector3(d.length() + 0.04, gh, 0.08), Vector3(mid.x, 1.2 + gh * 0.5, mid.y), yaw)
				if i % 3 == 0:
					mk.bar(Vector3(p0.x, 1.1, p0.y), Vector3(p0.x, 1.2 + gh + 0.15, p0.y), 0.12, 0.12, "steel_light", Color.WHITE, 0.02)
	mesh(n, mk, "Rink")
	if bool(p["goals"]):
		for side: Array in [["GoalA", -1.0], ["GoalB", 1.0]]:
			var g: Node3D = TLKit.build("goal", {})
			g.name = side[0]
			g.position = Vector3(float(side[1]) * (L * 0.5 - 3.4), 0.05, 0)
			g.rotation.y = 0.0 if float(side[1]) > 0.0 else PI
			n.add_child(g)
