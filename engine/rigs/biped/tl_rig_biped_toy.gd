class_name TLRigBipedToy
extends RefCounted
## Diorama night (20 Nov 2026): the biped as a TOY of separate clay pieces, on the same skeleton as the classic figure
## (TLRigBipedMesh.BONES: every body joint where it was, so the gait, the grips, the sockets and the wings fit unchanged).
## Chosen by the style: `"_figure": {"variant": "toy"}` in the loaded style file; an absent key = the classic figure.
## What makes it a toy:
##   - chunky proportions inside the same 2.0 m: a large round head that sits in a rolled collar, a short flared jacket,
##     thick sleeves and trouser legs, mitten hands, bulbous boots, cream cuffs at the wrists and above the boots;
##   - every piece is its own closed, smooth lump (a ball, a loft through rounded sections, a rolled ring): pieces
##     overlap like pressed clay instead of meeting in seams, and bend at ball-like joints;
##   - hand-made unevenness: each piece is displaced by a low noise (a few millimetres), the hair is sculpted lobes with
##     combed tool marks, solid on the head, and a bun that rides the `Hair` bone (the 29 bones and their names are kept);
##   - a tone per vertex darkens where pieces press together, and the vertex alpha marks where paint chips (cuffs, hem,
##     boot edges): `style/shaders/body_clay.gdshader` reads both.
## Internal to the rig: not pack API. Everything is a function of the arguments (no random, no clock).

const HEAD_C: Vector3 = Vector3(0, 1.715, 0.0)
const HEAD_R: Vector3 = Vector3(0.315, 0.295, 0.3)
const HAIR_K: float = 1.06                              # the hair lumps are laid out on a head 0.295 x 0.285 and widened with it
const TUFT: Vector3 = Vector3(0.06, 2.0, 0.1)       # where the bun sits on the head: the `Hair` bone of the toy
const EYE_YAW: float = 19.5
const EYE_PITCH: float = -1.0
const BROW_PITCH: float = 14.0
const MOUTH_PITCH: float = -27.0

static var _cache: Dictionary = {}       # look key -> [ArrayMesh, triangles]
static var _cache_lock: Mutex = Mutex.new()
static var _mat: ShaderMaterial


## True when the loaded style asks for the toy figure.
static func on() -> bool:
	TLStyle.ensure()
	var f: Variant = TLStyle.data.get("_figure", null)
	return f is Dictionary and String((f as Dictionary).get("variant", "")) == "toy"


## A number of the style's `_figure` section.
static func num(key: String, default: float) -> float:
	var f: Variant = TLStyle.data.get("_figure", null)
	return float((f as Dictionary).get(key, default)) if f is Dictionary else default


## The clay material of the figure (one for every toy biped; null when headless). The palette lookup is the style's own:
## it is read from the palette material again at every build, and by `sync` while figures live (a style loaded at run time
## makes a new lookup).
static func material() -> ShaderMaterial:
	if TLStyle.headless():
		return null
	var pal: Material = TLStyle.material(&"white")
	if not (pal is ShaderMaterial):
		return null
	_cache_lock.lock()
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://style/shaders/body_clay.gdshader")
	_mat.set_shader_parameter(&"pal_lut", (pal as ShaderMaterial).get_shader_parameter(&"pal_lut"))
	_mat.set_shader_parameter(&"print_k", num("print", 1.0))
	_mat.set_shader_parameter(&"chip_k", num("chip", 1.0))
	_mat.set_shader_parameter(&"sheen_k", num("sheen", 1.0))
	_mat.set_shader_parameter(&"soft_k", num("soft", 1.0))
	_mat.set_shader_parameter(&"shade_k", num("shade", 0.6))
	_cache_lock.unlock()
	return _mat


## Main thread, cheap: the clay material follows a style that was loaded after the figures were built (its lookup and dials).
static func sync() -> void:
	if _mat != null and not TLStyle.headless():
		var pal: Material = TLStyle.material(&"white")
		if pal is ShaderMaterial and (pal as ShaderMaterial).get_shader_parameter(&"pal_lut") != _mat.get_shader_parameter(&"pal_lut"):
			material()


## Gives every toon surface of a mesh the clay material (the figure's own mesh and what it holds).
static func dress(mesh: Mesh) -> void:
	var m: ShaderMaterial = material()
	if m == null or mesh == null:
		return
	var pal: Material = TLStyle.material(&"white")
	for i: int in mesh.get_surface_count():
		if mesh.surface_get_material(i) == pal:
			mesh.surface_set_material(i, m)


## A prop mesh of the figure, in clay when `toy` (the classic figure keeps the mesh as it is built).
static func dressed(mesh: ArrayMesh, toy: bool) -> ArrayMesh:
	if toy:
		dress(mesh)
	return mesh


## Builds the figure's mesh on the rig and returns its triangle count: the toy (one shared mesh per look) or the classic one.
static func attach(rig: TLRigNode, model: Node3D, sk: Skeleton3D, look: Dictionary, pack: bool, helmet: bool, toy: bool) -> int:
	if toy:
		var made: Array = mesh_for(sk, look, pack, helmet)
		rig._attach_mesh(model, sk, made[0])
		return int(made[1])
	var mk: TLMesh = TLRigBipedMesh.build_mesh(sk, look, pack, helmet)
	rig.attach_skinned(model, sk, mk, "biped")
	return mk.tri_count


# ------------------------------------------------------------------ the head's surface (face parts are laid on it)
static func _head_fn(d: Vector3) -> Vector3:
	var cheek: float = 1.0 + 0.075 * exp(-pow((d.y + 0.32) / 0.36, 2.0))
	return HEAD_C + Vector3(HEAD_R.x * d.x * cheek, HEAD_R.y * d.y, HEAD_R.z * d.z * (1.0 + 0.4 * (cheek - 1.0)))


static func _dir(yaw_deg: float, pitch_deg: float) -> Vector3:
	var y: float = deg_to_rad(yaw_deg)
	var p: float = deg_to_rad(pitch_deg)
	return Vector3(sin(y) * cos(p), sin(p), -cos(y) * cos(p))


## A point on the head: yaw + = towards +X (the figure's right), pitch + = up, from straight ahead (-Z); `lift` metres off the surface.
static func head_at(yaw_deg: float, pitch_deg: float, lift: float = 0.0) -> Vector3:
	return _head_fn(_dir(yaw_deg, pitch_deg)) + head_n(yaw_deg, pitch_deg) * lift


static func head_n(yaw_deg: float, pitch_deg: float) -> Vector3:
	var a: Vector3 = _head_fn(_dir(yaw_deg - 2.0, pitch_deg))
	var b: Vector3 = _head_fn(_dir(yaw_deg + 2.0, pitch_deg))
	var c: Vector3 = _head_fn(_dir(yaw_deg, pitch_deg - 2.0))
	var d: Vector3 = _head_fn(_dir(yaw_deg, pitch_deg + 2.0))
	var n: Vector3 = (d - c).cross(b - a).normalized()
	return n if n.dot(_dir(yaw_deg, pitch_deg)) > 0.0 else -n


## A frame on the head: Y = the surface normal, X = level, towards +X.
static func _head_frame(yaw_deg: float, pitch_deg: float, lift: float = 0.0) -> Transform3D:
	var n: Vector3 = head_n(yaw_deg, pitch_deg)
	var x: Vector3 = Vector3.UP.cross(n).normalized() * -1.0
	if x.x < 0.0:
		x = -x
	var z: Vector3 = x.cross(n).normalized()
	return Transform3D(Basis(x, n, z), head_at(yaw_deg, pitch_deg, lift))


## The skeleton: the classic bones, the head's children where the toy head puts them (`Hair` carries the bun).
static func bones() -> Array:
	var at: Dictionary = {
		"Hair": TUFT,
		"LeftEye": head_at(-EYE_YAW, EYE_PITCH), "RightEye": head_at(EYE_YAW, EYE_PITCH),
		"Brows": head_at(0.0, BROW_PITCH), "MouthCorners": head_at(0.0, MOUTH_PITCH), "Glints": head_at(0.0, EYE_PITCH),
	}
	var out: Array = []
	for b: Array in TLRigBipedMesh.BONES:
		out.append([b[0], b[1], at[b[0]]] if at.has(String(b[0])) else b)
	return out


# ------------------------------------------------------------------ the figure
## The cached mesh of a look (equal looks share one ArrayMesh: ten skaters are two meshes). Returns [ArrayMesh, triangles].
static func mesh_for(sk: Skeleton3D, L: Dictionary, pack: bool, helmet: bool) -> Array:
	var key: String = "%s|%s|%s|%s" % [TLStyle.style_path, var_to_str(L), pack, helmet]
	_cache_lock.lock()
	var hit: Variant = _cache.get(key, null)
	if hit is Array:
		_cache_lock.unlock()
		return hit
	# the contact tone depends on the pieces only: the first build of a variant runs once dry to note its lumps
	if TLRigBipedClay.bake_begin("%s|%s" % [pack, helmet], num("contact", 1.0)):
		build_mesh(sk, L, pack, helmet)
	TLRigBipedClay.bake_real()
	var mk: TLMesh = build_mesh(sk, L, pack, helmet)
	TLRigBipedClay.bake_end()
	# Two surfaces. Surface 0 is a small lump of the top colour inside the chest, on the style's palette material: the
	# world's far marks take a figure's colour from surface 0 of its largest mesh and know the palette material only
	# (kernel/world/draw/draw_life.gd), so a far toy is a mark in its jacket's or its team's colour, as the classic figure
	# is. Surface 1 is the figure, every key in one surface, in clay.
	var vote: TLMesh = TLMesh.new(71)
	vote.skinned = true
	vote.bone = sk.find_bone("Chest")
	vote.box(Vector3(0.05, 0.05, 0.05), String(L["top"]), Color.WHITE, 0.0, Vector3(0, 1.3, 0))
	var mesh: ArrayMesh = vote.build("biped")
	var all: TLMesh.Surf = TLMesh.Surf.new()
	var keys: Array = mk.surfs.keys()
	keys.sort()
	for part_key: String in keys:
		var part: TLMesh.Surf = mk.surfs[part_key]
		all.v.append_array(part.v)
		all.n.append_array(part.n)
		all.c.append_array(part.c)
		all.uv.append_array(part.uv)
		all.cu.append_array(part.cu)
		all.b.append_array(part.b)
		all.w.append_array(part.w)
	# the clay shader lays fingerprints in the surface: it needs the rest-pose normal, which goes in UV (octahedral; a
	# TLMesh part leaves UV at 0,0, which the shader reads as "no rest normal")
	all.uv.resize(all.n.size())
	for i: int in all.n.size():
		var nn: Vector3 = all.n[i]
		var l1: float = maxf(absf(nn.x) + absf(nn.y) + absf(nn.z), 0.000001)
		var ox: float = nn.x / l1
		var oy: float = nn.y / l1
		if nn.z < 0.0:
			var fx: float = (1.0 - absf(oy)) * (1.0 if ox >= 0.0 else -1.0)
			oy = (1.0 - absf(ox)) * (1.0 if oy >= 0.0 else -1.0)
			ox = fx
		all.uv[i] = Vector2(ox * 0.5 + 0.5, oy * 0.5 + 0.5)
	var clay: ShaderMaterial = material()
	TLMesh._add_surface(mesh, all, clay if clay != null else TLStyle.material(&"white"))
	mesh.set_meta("tl_hash", mk.content_hash())
	mesh.set_meta("tl_tris", mk.tri_count + vote.tri_count)
	var made: Array = [mesh, mk.tri_count + vote.tri_count]
	_cache[key] = made
	_cache_lock.unlock()
	return made


## L = palette keys per part (TLRigBipedMesh.LOOK overlaid with the rig's `colors`).
static func build_mesh(sk: Skeleton3D, L: Dictionary, pack: bool, helmet: bool = false) -> TLMesh:
	var mk: TLMesh = TLMesh.new(71)
	mk.skinned = true
	var B: Callable = func(n: String) -> void: mk.bone = sk.find_bone(n)
	var top: String = L["top"]
	var trim: String = L["trim"]
	var legs: String = L["legs"]
	var boots: String = L["boots"]
	var skin: String = L["skin"]
	var hair: String = L["hair"]
	var hands: String = boots if helmet else skin        # a skater wears gloves; the walker's hands are bare
	var collar: String = "white" if helmet else top
	# ---- trunk: the seat of the trousers, the flared jacket in two lumps, buttons, the rolled collar
	B.call("Hips")
	TLRigBipedClay.ball(mk, Vector3(0, 0.92, 0.0), Vector3(0.262, 0.14, 0.172), {"key": legs, "col": Color(0.93, 0.93, 0.93), "seed": 2.0}, 14, 7)
	B.call("Spine")
	var hem: Callable = Callable()
	if helmet:
		hem = func(p: Vector3) -> String: return "white" if p.y < 0.94 else top
	TLRigBipedClay.loft(mk, [[Vector3(0, 0.83, 0), 0.235, 0.165], [Vector3(0, 0.865, 0), 0.305, 0.206], [Vector3(0, 0.99, 0), 0.286, 0.19], [Vector3(0, 1.12, 0), 0.264, 0.174],
		[Vector3(0, 1.235, 0), 0.256, 0.168], [Vector3(0, 1.275, 0), 0.21, 0.14]], 20, 9,
		{"key": top, "pw": 2.5, "seed": 3.0, "lump": 0.005, "chip": 0.26, "chip0": 0.36, "chipw": 0.3, "ao0": 0.14, "aow": 0.16, "keyfn": hem, "dome": 0.2})
	B.call("Chest")
	TLRigBipedClay.loft(mk, [[Vector3(0, 1.165, 0), 0.2, 0.132], [Vector3(0, 1.205, 0), 0.258, 0.164], [Vector3(0, 1.30, 0), 0.268, 0.166], [Vector3(0, 1.40, 0.002), 0.278, 0.167],
		[Vector3(0, 1.475, 0.004), 0.25, 0.16], [Vector3(0, 1.52, 0.004), 0.17, 0.126]], 20, 9,
		{"key": top, "pw": 2.6, "seed": 4.0, "lump": 0.005, "chip": 0.26, "ao1": 0.16, "aow": 0.2, "dome": 0.25})
	if helmet:   # hockey kit: the number patch on the back (the hem band is in the jacket itself, the collar is white)
		mk.rbox(Vector3(0.23, 0.19, 0.02), "white", Color.WHITE, 0.01, Vector3(0, 1.35, 0.168), 1)
	else:
		for by: float in [1.39, 1.275]:
			TLRigBipedClay.ball(mk, Vector3(0, by, -0.168 - 0.004 * (1.4 - by) * 10.0), Vector3(0.028, 0.028, 0.014), {"key": trim, "col": Color(0.96, 0.9, 0.78), "lump": 0.001}, 8, 5)
	B.call("UpperChest")
	TLRigBipedClay.ring(mk, Vector3(0, 1.53, 0.028), 0.19, 0.192, 0.07, 0.074, {"key": collar, "col": Color(0.9, 0.88, 0.88) if not helmet else Color.WHITE, "seed": 5.0, "lump": 0.007, "chip": 0.15}, 20, 8, Vector3(-11, 0, 0))
	if pack:
		_backpack(mk, sk, L)
	# ---- head: a large round head that sits in the collar; the neck is a peg
	B.call("Neck")
	TLRigBipedClay.loft(mk, [[Vector3(0, 1.45, 0), 0.06, 0.06], [Vector3(0, 1.50, 0), 0.075, 0.075], [Vector3(0, 1.56, 0), 0.07, 0.07]], 8, 3, {"key": skin, "col": Color(0.86, 0.84, 0.84), "lump": 0.0})
	B.call("Head")
	TLRigBipedClay.ball_fn(mk, _head_fn, 26, 14, {"key": skin, "seed": 6.0, "lump": 0.0035, "lumpf": 7.0})
	for sx: float in [-1.0, 1.0]:
		TLRigBipedClay.ball(mk, head_at(sx * 90.0, -9.0, -0.006), Vector3(0.04, 0.072, 0.058), {"key": skin, "col": Color(0.93, 0.9, 0.9), "lump": 0.001}, 8, 5)   # ears
	TLRigBipedClay.ball(mk, head_at(0.0, -11.0, 0.004), Vector3(0.036, 0.031, 0.031), {"key": skin, "col": Color(0.94, 0.9, 0.9), "lump": 0.0}, 8, 5)             # nose
	_face(mk, sk, L)
	if helmet:
		_helmet(mk, sk, L)
	else:
		_hair(mk, sk, hair)
	# ---- arms and legs (mirrored). The lumps of a limb sit a little outside its joints (arm 0.29, leg 0.11): the toy is
	# broad and stands with his legs apart, on the classic skeleton
	for side: Array in [["Left", -1.0], ["Right", 1.0]]:
		var sx: float = side[1]
		var x: float = sx * 0.312
		var nm: String = side[0]
		var sd: float = 10.0 + sx
		B.call(nm + "Shoulder")
		TLRigBipedClay.ball(mk, Vector3(sx * 0.276, 1.452, 0.0), Vector3(0.118, 0.108, 0.112), {"key": top, "col": Color(0.96, 0.96, 0.96), "seed": sd}, 12, 7)
		B.call(nm + "UpperArm")
		TLRigBipedClay.loft(mk, [[Vector3(sx * 0.3, 1.478, 0), 0.07, 0.07], [Vector3(x, 1.43, 0), 0.108, 0.108], [Vector3(x, 1.30, 0), 0.106, 0.106], [Vector3(x, 1.19, 0), 0.1, 0.1],
			[Vector3(x, 1.13, 0), 0.068, 0.068]], 12, 7, {"key": top, "seed": sd + 1.0, "chip": 0.2, "ao1": 0.12, "aow": 0.2})
		B.call(nm + "LowerArm")
		TLRigBipedClay.loft(mk, [[Vector3(x, 1.22, 0), 0.068, 0.068], [Vector3(x, 1.17, 0), 0.1, 0.1], [Vector3(x, 1.06, 0), 0.104, 0.104], [Vector3(x, 0.985, 0), 0.114, 0.114],
			[Vector3(x, 0.955, 0), 0.096, 0.096]], 12, 7, {"key": top, "seed": sd + 2.0, "ao0": 0.12, "aow": 0.2, "chip": 0.2, "chip1": 0.4, "chipw": 0.35, "dome": 0.2})
		TLRigBipedClay.ring(mk, Vector3(x, 0.957, 0), 0.089, 0.089, 0.04, 0.037, {"key": trim, "seed": sd + 3.0, "lump": 0.005, "chip": 0.2}, 16, 7)
		B.call(nm + "Hand")
		TLRigBipedClay.ball(mk, Vector3(x, 0.846, -0.01), Vector3(0.098, 0.112, 0.104), {"key": hands, "col": Color(0.97, 0.95, 0.95) if not helmet else Color(0.8, 0.8, 0.8), "seed": sd + 4.0, "lump": 0.003}, 14, 9)
		TLRigBipedClay.ball(mk, Vector3(x - sx * 0.074, 0.872, -0.064), Vector3(0.04, 0.056, 0.042), {"key": hands, "col": Color(0.93, 0.9, 0.9) if not helmet else Color(0.88, 0.88, 0.88), "seed": sd + 5.0, "lump": 0.001}, 8, 5, Vector3(0, 0, sx * 24.0))
		var lx: float = sx * 0.152
		B.call(nm + "UpperLeg")
		TLRigBipedClay.loft(mk, [[Vector3(sx * 0.13, 0.995, 0), 0.08, 0.09], [Vector3(sx * 0.144, 0.93, 0), 0.124, 0.134], [Vector3(lx, 0.76, 0), 0.124, 0.134], [Vector3(lx, 0.575, 0), 0.118, 0.126],
			[Vector3(lx, 0.495, 0), 0.084, 0.09]], 14, 7, {"key": legs, "seed": sd + 6.0, "pw": 2.2, "chip": 0.16, "ao0": 0.1, "aow": 0.2})
		B.call(nm + "LowerLeg")
		TLRigBipedClay.loft(mk, [[Vector3(lx, 0.58, 0), 0.084, 0.09], [Vector3(lx, 0.535, 0), 0.118, 0.125], [Vector3(lx + sx * 0.003, 0.40, 0), 0.122, 0.13], [Vector3(lx + sx * 0.006, 0.27, 0), 0.132, 0.14],
			[Vector3(lx + sx * 0.006, 0.235, 0), 0.11, 0.118]], 14, 7, {"key": legs, "col": Color(0.95, 0.95, 0.95), "seed": sd + 7.0, "pw": 2.2, "chip": 0.16, "chip1": 0.4, "chipw": 0.3, "dome": 0.2})
		TLRigBipedClay.ring(mk, Vector3(lx + sx * 0.006, 0.25, 0), 0.122, 0.13, 0.048, 0.048, {"key": trim, "seed": sd + 8.0, "lump": 0.006, "chip": 0.2}, 16, 7)
		TLRigBipedClay.loft(mk, [[Vector3(lx + sx * 0.006, 0.245, 0), 0.1, 0.108], [Vector3(lx + sx * 0.006, 0.21, 0), 0.128, 0.138], [Vector3(lx + sx * 0.006, 0.14, 0.004), 0.134, 0.146], [Vector3(lx + sx * 0.006, 0.085, 0.006), 0.128, 0.14]],
			14, 5, {"key": boots, "seed": sd + 9.0, "pw": 2.3, "chip0": 0.2, "chipw": 0.3})
		B.call(nm + "Foot")
		TLRigBipedClay.ball(mk, Vector3(lx + sx * 0.006, 0.1, 0.02), Vector3(0.14, 0.118, 0.165), {"key": boots, "seed": sd + 10.0, "floor": 0.0, "dark": 0.03, "chip": 0.06}, 16, 9)
		B.call(nm + "Toes")
		TLRigBipedClay.ball(mk, Vector3(lx + sx * 0.006, 0.088, -0.16), Vector3(0.14, 0.108, 0.142), {"key": boots, "col": Color(0.96, 0.95, 0.94), "seed": sd + 11.0, "floor": 0.0, "dark": 0.03, "chip": 0.14}, 16, 9)
	return mk


## The face of pass 4 (eyes with highlights, brows, a smile with teeth, blush) laid on the round head.
static func _face(mk: TLMesh, sk: Skeleton3D, L: Dictionary) -> void:
	var B: Callable = func(n: String) -> void: mk.bone = sk.find_bone(n)
	B.call("Head")
	for sx: float in [-1.0, 1.0]:
		mk.push(_head_frame(sx * 40.0, -19.0, -0.004))            # blush
		mk.cyl(0.04, 0.006, 14, L["skin"], Color(1.14, 0.78, 0.78))
		mk.pop()
	for side: Array in [["Left", -1.0], ["Right", 1.0]]:
		B.call(String(side[0]) + "Eye")
		mk.push(_head_frame(float(side[1]) * EYE_YAW, EYE_PITCH, -0.004))
		mk.push(Transform3D(Basis.from_scale(Vector3(0.92, 1.0, 1.12)), Vector3.ZERO))
		mk.cyl(0.054, 0.014, 16, "black")
		mk.pop()
		mk.pop()
	B.call("Glints")
	for sx: float in [-1.0, 1.0]:
		mk.push(_head_frame(sx * EYE_YAW + 3.2, EYE_PITCH + 4.2, 0.0075))
		mk.cyl(0.0165, 0.004, 10, "white")
		mk.pop()
	B.call("Brows")
	for sx: float in [-1.0, 1.0]:
		mk.capsule(head_at(sx * 11.0, BROW_PITCH + 0.6, 0.004), head_at(sx * 29.0, BROW_PITCH - 1.4, 0.004), 0.018, L["hair"], Color.WHITE, 8, 2)
	B.call("MouthCorners")
	var f: Transform3D = _head_frame(0.0, MOUTH_PITCH, 0.004)
	# the mouth is drawn in a plane whose -Z looks out of the face
	mk.push(Transform3D(Basis(f.basis.x, f.basis.z * -1.0 if f.basis.z.y < 0.0 else f.basis.z, -f.basis.y), f.origin))
	var mp: Array = []
	for k: int in 11:
		var a: float = PI * float(k) / 10.0
		for z: float in [-0.006, 0.006]:
			mp.append(Vector3(cos(a) * 0.058, 0.018 - sin(a) * 0.04, z))
	mk.hull(mp, "roof", Color(0.62, 0.55, 0.55))
	mk.box(Vector3(0.084, 0.011, 0.004), "white", Color.WHITE, 0.0, Vector3(0, 0.0105, -0.0065))
	mk.pop()


## Sculpted hair: a cap, lobes pressed on round the back and the sides and a swept fringe, solid on the head; the bun on `Hair`.
static func _hair(mk: TLMesh, sk: Skeleton3D, hair: String) -> void:
	mk.bone = sk.find_bone("Head")
	var g: Dictionary = {"key": hair, "lump": 0.007, "lumpf": 8.0}
	var o: Callable = func(seed_: float, col: Color, extra: Dictionary = {}) -> Dictionary:
		var d: Dictionary = g.duplicate()
		d["seed"] = seed_
		d["col"] = col
		d.merge(extra, true)
		return d
	mk.grain = 3   # the clay shader reads this as "hair": combed tool marks instead of fingerprints
	var hb: Callable = func(c: Vector3, r: Vector3, od: Dictionary, m: int, n: int, e: Vector3 = Vector3.ZERO) -> void:
		TLRigBipedClay.ball(mk, Vector3(c.x * HAIR_K, c.y, c.z * HAIR_K), Vector3(r.x * HAIR_K, r.y, r.z * HAIR_K), od, m, n, e)
	hb.call(Vector3(0, 1.815, 0.05), Vector3(0.318, 0.25, 0.315), o.call(20.0, Color(0.88, 0.88, 0.88)), 22, 11)                             # cap
	hb.call(Vector3(-0.13, 1.745, 0.238), Vector3(0.17, 0.165, 0.128), o.call(21.0, Color(0.96, 0.96, 0.96), {"ao0": 0.25, "aow": 0.4}), 12, 7, Vector3(0, 0, 9))    # back lobes
	hb.call(Vector3(0.135, 1.735, 0.234), Vector3(0.165, 0.17, 0.126), o.call(22.0, Color(1, 1, 1), {"ao0": 0.25, "aow": 0.4}), 12, 7, Vector3(0, 0, -7))
	hb.call(Vector3(0.0, 1.66, 0.19), Vector3(0.24, 0.092, 0.118), o.call(23.0, Color(0.9, 0.9, 0.9), {"ao0": 0.25, "aow": 0.5}), 12, 6)   # nape
	for sx: float in [-1.0, 1.0]:
		hb.call(Vector3(sx * 0.262, 1.785, 0.1), Vector3(0.075, 0.115, 0.15), o.call(24.0 + sx, Color(0.95, 0.95, 0.95), {"ao0": 0.25, "aow": 0.4}), 10, 7, Vector3(0, 0, sx * 6.0))   # sides, above the ears
	hb.call(Vector3(-0.09, 1.9, -0.228), Vector3(0.182, 0.08, 0.09), o.call(26.0, Color(1, 1, 1)), 12, 7, Vector3(0, 12, 13))               # the fringe, swept to his right
	hb.call(Vector3(0.148, 1.91, -0.202), Vector3(0.138, 0.072, 0.084), o.call(27.0, Color(0.97, 0.97, 0.97)), 10, 6, Vector3(0, -22, -16))
	hb.call(Vector3(-0.125, 2.04, 0.03), Vector3(0.118, 0.082, 0.115), o.call(28.0, Color(1, 1, 1), {"ao0": 0.3, "aow": 0.4}), 12, 7, Vector3(0, 0, 12))   # the smaller bun, solid on the head
	mk.bone = sk.find_bone("Hair")
	TLRigBipedClay.ball(mk, Vector3(0.07, 2.055, 0.105), Vector3(0.155, 0.11, 0.145), o.call(29.0, Color(1, 1, 1), {"ao0": 0.3, "aow": 0.4}), 14, 8, Vector3(-8, 0, -6))   # the bun
	mk.grain = 1


## The hockey helmet: a dome in the top colour with a white stripe, ear guards and a short brim; hair shows at the back.
static func _helmet(mk: TLMesh, sk: Skeleton3D, L: Dictionary) -> void:
	var top: String = L["top"]
	mk.bone = sk.find_bone("Head")
	var stripe: Callable = func(p: Vector3) -> String: return "white" if absf(p.x) < 0.064 else top
	# the dome's poles lie on the ears, so its rings run front to back and the stripe is one clean ring
	TLRigBipedClay.ball(mk, Vector3(0, 1.815, 0.012), Vector3(0.262, 0.355, 0.346), {"key": top, "seed": 30.0, "lump": 0.002, "floor": 1.782, "keyfn": stripe, "chip": 0.06}, 16, 16, Vector3(0, 0, 90))
	TLRigBipedClay.ball(mk, Vector3(0, 1.755, 0.185), Vector3(0.278, 0.1, 0.168), {"key": top, "col": Color(0.93, 0.93, 0.93), "seed": 33.0, "lump": 0.002}, 12, 6)   # the shell comes lower at the back
	TLRigBipedClay.ball(mk, Vector3(0, 1.797, -0.3), Vector3(0.21, 0.026, 0.072), {"key": top, "col": Color(0.85, 0.85, 0.85), "seed": 31.0, "lump": 0.002}, 12, 5)
	for sx: float in [-1.0, 1.0]:
		TLRigBipedClay.ball(mk, Vector3(sx * 0.33, 1.70, 0.02), Vector3(0.042, 0.095, 0.095), {"key": top, "col": Color(0.9, 0.9, 0.9), "seed": 32.0 + sx, "lump": 0.002}, 10, 6)
	var g: Dictionary = {"key": L["hair"], "lump": 0.006, "lumpf": 8.0, "col": Color(0.92, 0.92, 0.92)}
	mk.grain = 3
	TLRigBipedClay.ball(mk, Vector3(0.0, 1.66, 0.228), Vector3(0.24, 0.09, 0.108), g, 12, 6)
	mk.grain = 1


## The lane-B backpack in clay: body, lid, pocket, bedroll and the small light (own bone: it lags a little).
static func _backpack(mk: TLMesh, sk: Skeleton3D, L: Dictionary) -> void:
	mk.bone = sk.find_bone("Backpack")
	var z: float = 0.27
	TLRigBipedClay.loft(mk, [[Vector3(0, 1.13, z), 0.14, 0.085], [Vector3(0, 1.19, z), 0.185, 0.115], [Vector3(0, 1.36, z), 0.19, 0.118], [Vector3(0, 1.50, z), 0.18, 0.11], [Vector3(0, 1.545, z), 0.13, 0.08]],
		14, 8, {"key": L["pack"], "pw": 2.8, "seed": 40.0, "lump": 0.006, "ao0": 0.1, "aow": 0.2})
	TLRigBipedClay.ball(mk, Vector3(0, 1.515, z), Vector3(0.196, 0.062, 0.122), {"key": L["pack"], "col": Color(0.82, 0.82, 0.82), "seed": 41.0, "lump": 0.004}, 12, 6)
	TLRigBipedClay.ball(mk, Vector3(0, 1.235, z + 0.105), Vector3(0.115, 0.075, 0.045), {"key": L["pack"], "col": Color(0.87, 0.87, 0.87), "seed": 42.0, "lump": 0.003}, 10, 6)
	mk.capsule(Vector3(-0.2, 1.635, z - 0.01), Vector3(0.2, 1.635, z - 0.01), 0.085, L["trim"], Color(0.92, 0.9, 0.86), 10, 2)
	TLRigBipedClay.ball(mk, Vector3(0, 1.41, z + 0.112), Vector3(0.06, 0.06, 0.03), {"key": "cyan", "lump": 0.0}, 10, 5)
	TLRigBipedClay.ring(mk, Vector3(0, 1.41, z + 0.106), 0.062, 0.062, 0.018, 0.02, {"key": L["strap"], "lump": 0.001}, 12, 5, Vector3(90, 0, 0))
	mk.bone = sk.find_bone("Chest")
	for sx: float in [-1.0, 1.0]:      # the straps over the shoulders, pressed into the jacket
		TLRigBipedClay.ring(mk, Vector3(sx * 0.15, 1.35, 0.0), 0.03, 0.172, 0.022, 0.2, {"key": L["strap"], "seed": 43.0 + sx, "lump": 0.002}, 8, 12)
