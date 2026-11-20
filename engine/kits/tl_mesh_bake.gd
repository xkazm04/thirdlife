extends RefCounted
## TLMesh's baking helpers, kept beside tl_mesh.gd (whose size is ratcheted): the merge of whole meshes, and the
## record of box faces.
##
## Box faces (diorama night, 20 Nov 2026). A solid made of flat faces reads as cut, not as made by hand. So every
## rectangular face of a `box` says, per vertex, where that vertex is on its face and how large the face is: UV2 =
## (size in whole centimetres) + (place across the face, 0.002 .. 0.998), for each of the face's two sides. The whole part
## is the same at all three corners of a triangle, so it survives the interpolation and the shader takes it off with
## floor(). A style may then soften the edge (toon.gdshader, TL_DIORAMA: `detail.bevel`) and wear the paint there;
## today's style never reads the channel. UV2 is filled lazily (empty for a surface without box faces) and is not part
## of TLMesh.content_hash: the look of an edge is presentation, and kit hashes stay as they were.
##
## Round lumps (the same night). A `blob` (rock, bush, crown) and the side of a `cyl` (post, trunk, the tiers of a
## pine) are facets of a round thing. Their vertices carry the round thing's own normal in the same channel: UV2 =
## 0.5 + 0.45 * (n.x, n.z) of the unit normal in mesh space, so both fractions lie in 0.05 .. 0.95, plus a whole part of
## 0 for a turned side and 1 for a lump (never the zero of "nothing", never the 2 or more centimetres of a box face). The shader takes the missing n.y from the
## sign of the facet's own normal and may light the lump as round (`detail.round`). The facets, the collision, the
## prepass normal and the hash are unchanged. A skinned part is left alone (its normals move with the bones).


## The record of a rectangular face from its four corners in order (local space, `tf` = the mesh's current
## transform): [origin, unit x, unit y, size (m), size in whole cm]; [] when the face is too small or too large to mark.
static func face(tf: Transform3D, pts: Array) -> Array:
	var o: Vector3 = tf * (pts[0] as Vector3)
	var ex: Vector3 = tf * (pts[1] as Vector3) - o
	var ey: Vector3 = tf * (pts[3] as Vector3) - o
	var sz: Vector2 = Vector2(ex.length(), ey.length())
	if sz.x < 0.02 or sz.y < 0.02 or sz.x > 40.9 or sz.y > 40.9:
		return []
	return [o, ex / sz.x, ey / sz.y, sz, Vector2(roundf(sz.x * 100.0), roundf(sz.y * 100.0))]


static func code(f: Array, p: Vector3) -> Vector2:
	var d: Vector3 = p - (f[0] as Vector3)
	var sz: Vector2 = f[3]
	var q: Vector2 = f[4]
	return Vector2(q.x + 0.002 + 0.996 * clampf(d.dot(f[1]) / sz.x, 0.0, 1.0), q.y + 0.002 + 0.996 * clampf(d.dot(f[2]) / sz.y, 0.0, 1.0))


## The three vertices just appended to `s` (in this order) lie on the face `f`.
static func mark(s: TLMesh.Surf, f: Array, p0: Vector3, p1: Vector3, p2: Vector3) -> void:
	if s.uv2.size() < s.v.size() - 3:
		s.uv2.resize(s.v.size() - 3)          # the triangles before this one: zero = no face
	s.uv2.append(code(f, p0)); s.uv2.append(code(f, p1)); s.uv2.append(code(f, p2))


## A lump round about the point `centre` with radii `r` (a blob), in the local space of the transform `tf`.
static func lump(tf: Transform3D, centre: Vector3, r: Vector3) -> Array:
	return [0, centre, Vector3(1.0 / maxf(r.x * r.x, 1e-6), 1.0 / maxf(r.y * r.y, 1e-6), 1.0 / maxf(r.z * r.z, 1e-6)), tf.basis.inverse().transposed()]


## A side round about the local Y axis that leans in by `slope` (0 a cylinder, r / h a cone).
static func turned(tf: Transform3D, slope: float) -> Array:
	return [1, slope, Vector3.ZERO, tf.basis.inverse().transposed()]


## The triangle p0 p1 p2 (local points, outside seen counter-clockwise) was just appended to `s` as p0, p2, p1 and
## belongs to the round thing `r`: its vertices take that thing's normal. The flat end of a turned part stays flat.
static func mark_round(s: TLMesh.Surf, r: Array, p0: Vector3, p1: Vector3, p2: Vector3) -> void:
	var flat: Vector3 = (p1 - p0).cross(p2 - p0).normalized()
	if int(r[0]) == 1 and absf(flat.y) > 0.98:
		return
	if s.uv2.size() < s.v.size() - 3:
		s.uv2.resize(s.v.size() - 3)
	for p: Vector3 in [p0, p2, p1]:
		var n: Vector3 = flat
		if int(r[0]) == 0:
			var d: Vector3 = p - (r[1] as Vector3)
			n = d * (r[2] as Vector3)
		elif p.x * p.x + p.z * p.z > 1e-8:
			var rad: Vector2 = Vector2(p.x, p.z).normalized()
			n = Vector3(rad.x, float(r[1]), rad.y)
		n = ((r[3] as Basis) * n).normalized()
		var whole: float = 1.0 if int(r[0]) == 0 else 0.0       # whole part 1 = a lump, 0 = a turned side
		s.uv2.append(Vector2(whole + 0.5 + 0.45 * n.x, whole + 0.5 + 0.45 * n.z))


## `part`'s vertices were just appended to `whole`: its face records follow them (zero for everything before).
static func join(whole: TLMesh.Surf, part: TLMesh.Surf) -> void:
	if part.uv2.size() > 0:
		whole.uv2.resize(whole.v.size() - part.v.size())
		whole.uv2.append_array(part.uv2)


## The face records of a surface as its UV2 array (none: the mesh has no such channel).
static func put(arr: Array, s: TLMesh.Surf) -> void:
	if s.uv2.size() > 0:
		s.uv2.resize(s.v.size())
		arr[Mesh.ARRAY_TEX_UV2] = s.uv2


## TLMesh.merge: whole meshes (each with a transform) into one ArrayMesh, one surface per material, keeping CUSTOM0
## and the face records.
static func merge(items: Array, mesh_name: String) -> ArrayMesh:
	var acc: Dictionary = {}
	for it: Array in items:
		var m: Mesh = it[0]
		var t: Transform3D = it[1]
		var nb: Basis = t.basis.inverse().transposed()
		for si: int in m.get_surface_count():
			var mat: Material = m.surface_get_material(si)
			var arr: Array = (m.get_meta(&"tl_arrays") as Array)[si] if m.has_meta(&"tl_arrays") else m.surface_get_arrays(si)   # P12
			if not acc.has(mat):
				acc[mat] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedVector2Array(), PackedFloat32Array(), PackedVector2Array()]
			var d: Array = acc[mat]
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			# packed arrays are values: take them out, append, put them back
			var av: PackedVector3Array = d[0]
			var an: PackedVector3Array = d[1]
			var ac: PackedColorArray = d[2]
			var au: PackedVector2Array = d[3]
			var af: PackedFloat32Array = d[4]
			for i: int in vs.size():
				av.append(t * vs[i])
				an.append((nb * ns[i]).normalized())
			ac.append_array(arr[Mesh.ARRAY_COLOR])
			au.append_array(arr[Mesh.ARRAY_TEX_UV])
			af.append_array(arr[Mesh.ARRAY_CUSTOM0])
			if arr[Mesh.ARRAY_TEX_UV2] != null:        # box faces: zero for every vertex before them
				var a2: PackedVector2Array = d[5]
				a2.resize(av.size() - vs.size())
				a2.append_array(arr[Mesh.ARRAY_TEX_UV2])
				d[5] = a2
			d[0] = av; d[1] = an; d[2] = ac; d[3] = au; d[4] = af
	var out: ArrayMesh = ArrayMesh.new()
	out.resource_name = mesh_name
	for mat: Material in acc:
		var d: Array = acc[mat]
		var arr2: Array = []
		arr2.resize(Mesh.ARRAY_MAX)
		arr2[Mesh.ARRAY_VERTEX] = d[0]
		arr2[Mesh.ARRAY_NORMAL] = d[1]
		arr2[Mesh.ARRAY_COLOR] = d[2]
		arr2[Mesh.ARRAY_TEX_UV] = d[3]
		if (d[5] as PackedVector2Array).size() > 0:
			var u2: PackedVector2Array = d[5]
			u2.resize((d[0] as PackedVector3Array).size())
			arr2[Mesh.ARRAY_TEX_UV2] = u2
		arr2[Mesh.ARRAY_CUSTOM0] = d[4]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr2, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		out.surface_set_material(out.get_surface_count() - 1, mat)
	return out
