extends TLMesh
## Indexed, closed rings in bind space. Each piece has its own outline and paint.
## UV holds edge wear and finish. CUSTOM0 retains bind-space position through skinning.
enum Form { PLAIN, COAT, COLLAR, HAIRLINE, LOCK, LEATHER, KNIT, DENIM, CURL, SLEEVE, FLAP }
enum Finish { CLAY, ENAMEL, HAIR, SATIN, GLOSS, HELMET, JACKET, SOLE, DENIM, SLEEVE, BOOT }

const EGG := [Vector2(-1, .06), Vector2(-.91, .40), Vector2(-.68, .73), Vector2(-.36, .94),
	Vector2(0, 1), Vector2(.36, .94), Vector2(.68, .73), Vector2(.91, .40), Vector2(1, .06)]
const BEAD := [Vector2(-1,0), Vector2(-.70,.71), Vector2(-.12,.99), Vector2(.58,.81), Vector2(1,0)]
const ROLL := [Vector2(-1, .76), Vector2(-.82, .93), Vector2(-.42, 1), Vector2(.24, 1),
	Vector2(.76, .95), Vector2(1, .81)]
const DOME := [Vector2(-1, .86), Vector2(-.88, .97), Vector2(-.42, 1), Vector2(.05, .98),
	Vector2(.47, .85), Vector2(.78, .62), Vector2(.95, .34), Vector2(1, .07)]
const TIP := [Vector2(-1, .09), Vector2(-.84, .55), Vector2(-.5, .9), Vector2(-.08, 1),
	Vector2(.33, .87), Vector2(.65, .62), Vector2(.87, .32), Vector2(1, .05)]
const CURL := [Vector2(-1,0), Vector2(-.82,.68), Vector2(-.38,.93), Vector2(.02,1),
	Vector2(.42,.94), Vector2(.63,.84), Vector2(.77,.70), Vector2(.87,.56),
	Vector2(.94,.41), Vector2(.98,.25), Vector2(1,0)]

var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var indices := PackedInt32Array()
var pigment := PackedColorArray()
var finish_uv := PackedVector2Array()
var bind_data := PackedFloat32Array()
var joints := PackedInt32Array()
var weights := PackedFloat32Array()
var skeleton: Skeleton3D
var look: Dictionary
var finish := Finish.ENAMEL
var wear := 0.0
var next_joint := -1
var joint_blend := Vector2.ZERO
var blend_axis := Vector3.UP
var hip_joint := -1
var grip_points: Dictionary[int,Vector3] = {}
var grip_normals: Dictionary[int,Vector3] = {}
var paint_shader: Shader = preload("res://style/shaders/body_clay.gdshader")
var contour: Material


func part(joint: String, surface: Finish = Finish.ENAMEL, worn_edge: float = 0.0) -> void:
	bone = skeleton.find_bone(joint)
	next_joint = -1
	hip_joint = -1
	finish = surface
	wear = worn_edge


## Blend only the cross-sections between these two bind-space heights.
func bend_into(joint: String, low: float, high: float, axis := Vector3.UP) -> void:
	next_joint = skeleton.find_bone(joint)
	joint_blend = Vector2(low, high)
	blend_axis = axis


func piece(at: Vector3, size: Vector3, key: String, rings: Array = EGG, sides: int = 16,
		turn: Vector3 = Vector3.ZERO, form: Form = Form.PLAIN, tint: Color = Color.WHITE,
		squareness: float = 1.0) -> void:
	var palette_id := TLStyle.index(look.get(key, key))
	var basis := Basis.from_euler(turn * PI / 180.0)
	var offset := vertices.size()
	var pointed := rings == EGG or rings == BEAD or rings == TIP or rings == CURL
	for row: Vector2 in rings:
		var h := row.x
		for i in sides:
			var angle := TAU * float(i) / sides
			var c := cos(angle)
			var s := sin(angle)
			var x := signf(c) * pow(absf(c), squareness)
			var z := signf(s) * pow(absf(s), squareness)
			var radius := 0.0 if pointed and absf(h) == 1.0 else row.y
			# A gentle tool flat on the side of the clay. Varies continuously around the seam.
			radius *= 1.0 + .012 * sin(3.0 * angle + h + at.x * 11.0) + .008 * cos(5.0 * angle - h * 1.4)
			var y := h
			var recess := 0.0
			match form:
				Form.COAT:
					y += (.035 * sin(2.0 * angle + .6) + .03 * c) * (1.0 - h) * .5
					radius *= 1.0 + .043 * cos(5.0 * angle - 1.8*h) * (1.0 - h) * .5
					if finish == Finish.JACKET:
						# Two folds turn out of the hem at different angles. The
						# high side of each fold catches the light on a moving back.
						var left := (c + .52 - .29*h) / .22
						var right := (c - .51 + .18*h) / .29
						var hem := smoothstep(.12,.79,s) * (1.0-smoothstep(-.76,.19,h))
						var pinch := exp(-left*left) + .79*exp(-right*right)
						recess = .65 * pinch * hem
						radius += hem * (.065 + .045*cos(5.0*c+.4) - .085*pinch)
						y += hem * (.055*pinch - .025)
				Form.SLEEVE:
					y += .065 * sin(angle + signf(at.x)*.7)
					y -= .17 * smoothstep(.12,1.0,h) * (.7 + .5*signf(at.x)*c)
					var elbow := h + .15 - signf(at.x)*.14*c - .10*s
					recess = exp(-50.0*elbow*elbow) * (.44 + .39*s)
					radius *= 1.0 - .14*recess
				Form.COLLAR:
					var split := smoothstep(.81,.995,-s)
					y += .26*s - .82*split + .10*c
					radius *= 1.0 - .29*split
					y += .11 * cos(2.0*angle - .45)
				Form.HAIRLINE:
					# Low nape; high brow with pointed sides and a slant above one eye.
					y += (1.0 - h) * .5 * (-.45 * s - .30 * maxf(s,0.0) + .09 * sin(3.0 * angle + .8) - .10 * c)
					y += .35*pow(absf(c),5.0)*(1.0-h)*.5
					var lock := cos(6.0 * angle + 2.7 * h + .5 * sin(3.0 * angle))
					radius *= 1.0 + .04 * lock - .031 * pow(maxf(-lock,0.0), 8.0)
					# A flattened sweep from the near temple to the middle
					# of the nape. Give its upper edge a lip and its base a cut.
					var sweep := (h + .48 + .66*c - .50*c*c) / .30
					var fade := smoothstep(.18,.78,s) * (1.0-smoothstep(-.12,.67,c))
					recess = .52*fade*exp(-sweep*sweep)
					radius += fade*.075*exp(-pow(sweep-1.0,2)) - .15*recess
				Form.LOCK:
					x += .44 * pow((h + 1.0) * .5, 2.0) / maxf(.04, radius)
					radius *= 1.0 + .035 * cos(4.0 * angle + 2.2 * h)
				Form.CURL:
					# A groove follows the thumb around the near face, then dies
					# out at the centre. Its shadow is part of the same piece.
					recess = pow(maxf(0.0,cos(angle - 6.8*radius + .6)), 3.0)
					recess *= smoothstep(.08,.76,h) * smoothstep(.0,.32,radius)
					y -= .25 * recess
					radius *= 1.0 - .08*recess + .06*cos(3.0*angle+h)
				Form.LEATHER:
					z += .32 * (h + 1.0) * .5
				Form.KNIT:
					radius *= 1.0 + .012 * cos(12.0 * angle)
				Form.FLAP:
					y += .52 * x*x * (1.0-h)*.5
				Form.DENIM:
					x += signf(at.x) * .24 * (1.0 - h) * .5
					y += .07 * sin(angle + .6) * exp(-9.0 * h*h)
					radius *= 1.0 + .047 * cos(3.0*angle + 1.2*h)
					var knee := h - .15 - signf(at.x)*.15*c + .09*s
					recess = exp(-50.0*knee*knee) * (.52 + .45*s)
					radius *= 1.0 - .15*recess
			var sculpt := Vector3(x * radius, y, z * radius)
			if form == Form.LOCK and pointed and h == 1.0:
				sculpt.x = .44
			var point := at + basis * (sculpt * size)
			if form == Form.SLEEVE:
				point.x -= signf(at.x)*.033*smoothstep(.18,1.0,h)
			if form == Form.DENIM:
				# Each tube opens into half of the same oval waist. Both lips
				# meet at the centre front/back and are weighted to the pelvis.
				var side := signf(at.x)
				var seat := smoothstep(.635,.775,point.y)
				var waist_x := side * .252 * maxf(side*c,0.0)
				point.x = lerpf(point.x,waist_x,seat)
				point.z = lerpf(point.z,.010 + .157*s,seat)
			var edge := wear * (1.0 - smoothstep(-.94, -.42, h))
			# Pigment collects where the rim of one clay piece turns under another.
			var lip := lerpf(.72, 1.0, smoothstep(-1.0, -.63, h)) if not pointed else 1.0
			var shade := lip * (1.0 - .24*recess)
			_vertex(point, Color(tint.r * shade, tint.g * shade, tint.b * shade), edge, palette_id)
	for j in rings.size():
		for i in sides:
			var n := offset + j * sides + i
			var left := offset + j * sides + posmod(i - 1, sides)
			var right := offset + j * sides + (i + 1) % sides
			var above := n + sides if j + 1 < rings.size() else n
			var below := n - sides if j > 0 else n
			var normal := (vertices[above] - vertices[below]).cross(vertices[right] - vertices[left]).normalized()
			if form == Form.DENIM and absf(cos(TAU * i / sides)) < .0001:
				var waist := smoothstep(.635,.775,vertices[n].y)
				normal = normal.lerp(Vector3.BACK * signf(vertices[n].z),waist).normalized()
			normals[n] = basis.y * signf(rings[j].x) if pointed and (j == 0 or j == rings.size()-1) else normal
			if j + 1 < rings.size():
				if form == Form.DENIM and minf(vertices[n].y,vertices[right].y) >= .775 and signf(at.x)*cos(TAU*(i+.5)/sides) < 0.0:
					continue # the two inside walls end where the trouser legs join
				if not pointed or j != 0:
					indices.append_array(PackedInt32Array([n, right, above]))
				if not pointed or j + 2 != rings.size():
					indices.append_array(PackedInt32Array([right, right + sides, above]))
	if pointed:
		tri_count = indices.size() / 3
		return
	# A triangle fan closes each end. A separate ring keeps a flat sole flat.
	for end in [0, rings.size() - 1]:
		var top: bool = end != 0
		var first: int = offset + end * sides
		var cap := vertices.size()
		var middle := Vector3.ZERO
		for i in sides:
			middle += vertices[first + i] / sides
		_vertex(middle, tint, 0.0, palette_id)
		var axis := basis.y if top else -basis.y
		normals[cap] = axis
		for i in sides:
			_vertex(vertices[first + i], tint, finish_uv[first + i].x, palette_id)
			normals[cap + i + 1] = axis
		for i in sides:
			var a := cap + 1 + i
			var b := cap + 1 + (i + 1) % sides
			indices.append_array(PackedInt32Array([cap, a, b] if top else [cap, b, a]))
	tri_count = indices.size() / 3


func _vertex(point: Vector3, tint: Color, edge: float, palette_id: int) -> void:
	vertices.append(point)
	normals.append(Vector3.UP)
	pigment.append(tint)
	finish_uv.append(Vector2(edge, finish))
	bind_data.append_array(PackedFloat32Array([point.x, point.y, point.z, float(palette_id)]))
	var w := smoothstep(joint_blend.x, joint_blend.y, point.dot(blend_axis)) if next_joint >= 0 else 0.0
	var pelvis_w := smoothstep(.635,.775,point.y) if hip_joint >= 0 else 0.0
	joints.append_array(PackedInt32Array([bone, maxi(0, next_joint), maxi(0,hip_joint), 0]))
	weights.append_array(PackedFloat32Array([(1.0 - w)*(1.0 - pelvis_w), w*(1.0 - pelvis_w), pelvis_w, 0.0]))


func build(mesh_name: String = "biped") -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.resource_name = mesh_name
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = pigment
	arrays[Mesh.ARRAY_TEX_UV] = finish_uv
	arrays[Mesh.ARRAY_CUSTOM0] = bind_data
	arrays[Mesh.ARRAY_BONES] = joints
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = indices
	var shapes := []
	if not grip_points.is_empty():
		var fitted := vertices.duplicate()
		var fitted_normals := normals.duplicate()
		for index: int in grip_points:
			fitted[index] = grip_points[index]
			fitted_normals[index] = grip_normals[index]
		var shape := []
		shape.resize(Mesh.ARRAY_MAX)
		shape[Mesh.ARRAY_VERTEX] = fitted
		shape[Mesh.ARRAY_NORMAL] = fitted_normals
		shapes.append(shape)
		mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
		mesh.add_blend_shape(&"Grip")
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, shapes, {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	var material := TLStyle.material("white") as ShaderMaterial
	if not TLStyle.headless():
		var paint := ShaderMaterial.new()
		paint.shader = paint_shader
		paint.next_pass = contour
		paint.set_shader_parameter(&"pal_lut", material.get_shader_parameter(&"pal_lut"))
		material = paint
	mesh.surface_set_material(0, material)
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA1)
	for data: Variant in arrays:
		if data != null:
			digest.update(data.to_byte_array())
	for shape: Array in shapes:
		digest.update(shape[Mesh.ARRAY_VERTEX].to_byte_array())
		digest.update(shape[Mesh.ARRAY_NORMAL].to_byte_array())
	mesh.set_meta(&"tl_hash", digest.finish().hex_encode())
	mesh.set_meta(&"tl_tris", tri_count)
	return mesh
