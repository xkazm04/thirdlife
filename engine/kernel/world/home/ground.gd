extends RefCounted
## Fixed grid split at the exact village border. Heights used by paths and scatter
## interpolate these same triangles. The native village has zero-height outer vertices.
var land: RefCounted
var xs := PackedFloat32Array()
var zs := PackedFloat32Array()
var vertices := PackedVector3Array()
var indices := PackedInt32Array()

func axis(a: float,b: float) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for span: Array in [[-land.LIMIT,-1536,48],[-1536,a,12],[a,b,12],[b,1536,12],[1536,land.LIMIT,48]]:
		var count := ceili((float(span[1])-span[0])/span[2])
		for k in count: result.append(lerpf(span[0],span[1],float(k)/count))
	result.append(land.LIMIT)
	return result

func build(parent: Node3D, valley: RefCounted) -> void:
	land = valley
	xs = axis(land.border.position.x, land.border.end.x)
	zs = axis(land.border.position.y, land.border.end.y)
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var custom := PackedFloat32Array()
	var pigment := {}
	for key in land.KEYS+["terrain"]:
		pigment[key] = TLStyle.color("grass" if key=="terrain" else key).srgb_to_linear()
	var code := 1+16*TLStyle.index("terrain")
	var limestone := TLStyle.color("curb_white").srgb_to_linear()
	var sandstone := TLStyle.color("sand").srgb_to_linear()
	var rush_color := TLStyle.color("leaf").srgb_to_linear()
	var plain_code := 1+16*TLStyle.index("white")
	var bands := mini(8,OS.get_processor_count())
	var rows_per := ceili(float(zs.size())/bands)
	var slices := []
	slices.resize(bands)
	var fill := func(b: int) -> void:
		var positions := PackedVector3Array()
		var paint := PackedColorArray()
		var attributes := PackedFloat32Array()
		for j in range(b*rows_per,mini(zs.size(),(b+1)*rows_per)):
			var z := zs[j]
			for x in xs:
				var y: float=land.height(x,z)
				positions.append(Vector3(x,y,z))
				var field: Dictionary=land.parcel_at(x,z)
				var bedrock: float=land.exposure(x,z,y)
				var wet: float=land.wetness(x,z,y)
				var green: bool=land.green_at(x,z)
				var key: String=land.surface_key(x,z,field,bedrock,wet,green)
				var color: Color=pigment[key]
				if bedrock>0.0:
					var bed := 0.5+0.5*cos((y+0.11*x+0.035*z)/9.5)
					var joint := smoothstep(0.42,0.68,bed)
					var chalk: Color=sandstone.lerp(limestone,0.16+0.78*joint)
					color = pigment["grass_dry"].lerp(chalk,bedrock)
				if wet>0 and field.is_empty() and not green and key!="terrain":
					color=color.lerp(rush_color,wet*0.85)
				var bare := bedrock>0.22 or not field.is_empty() or green or (wet>0.22 and key!="terrain")
				attributes.append_array([x,y,z,plain_code if bare else code])
				if not field.is_empty():
					var a: Array=field.corners[0]
					var b1: Array=field.corners[1]
					var u := Vector2(b1[0]-a[0],b1[1]-a[1])
					var across := Vector2(x-a[0],z-a[1]).dot(u)/u.length_squared()
					color *= 0.91+0.09*cos(TAU*across*3.0)
				color *= 0.94+0.06*land.noise.get_noise_2d(x+130,z)
				color.a=1
				paint.append(color)
		slices[b]=[positions,paint,attributes]
	var task := WorkerThreadPool.add_group_task(fill,bands)
	WorkerThreadPool.wait_for_group_task_completion(task)
	for slice: Array in slices:
		vertices.append_array(slice[0])
		colors.append_array(slice[1])
		custom.append_array(slice[2])
	uvs.resize(vertices.size())
	var n := xs.size()
	for j in zs.size():
		for i in n:
			var k := j*n+i
			var dx := vertices[j*n+mini(i+1,n-1)]-vertices[j*n+maxi(0,i-1)]
			var dz := vertices[mini(j+1,zs.size()-1)*n+i]-vertices[maxi(0,j-1)*n+i]
			normals.append(dz.cross(dx).normalized())
			if i+1==n or j+1==zs.size(): continue
			if land.border.has_point(Vector2((xs[i]+xs[i+1])*0.5,(zs[j]+zs[j+1])*0.5)): continue
			indices.append_array([k,k+1,k+n+1,k,k+n+1,k+n])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX]=vertices
	arr[Mesh.ARRAY_INDEX]=indices
	arr[Mesh.ARRAY_COLOR]=colors
	arr[Mesh.ARRAY_CUSTOM0]=custom
	arr[Mesh.ARRAY_NORMAL]=normals
	arr[Mesh.ARRAY_TEX_UV]=uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr,[],{},Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	mesh.surface_set_material(0, TLStyle.material("terrain"))
	var instance := MeshInstance3D.new()
	instance.mesh=mesh
	instance.name="WrenValley"
	parent.add_child(instance)

func y(x: float,z: float) -> float:
	if land.border.has_point(Vector2(x,z)): return land.village.gy(x,z)
	var i := clampi(xs.bsearch(x)-1,0,xs.size()-2)
	var j := clampi(zs.bsearch(z)-1,0,zs.size()-2)
	var u := (x-xs[i])/(xs[i+1]-xs[i])
	var v := (z-zs[j])/(zs[j+1]-zs[j])
	var k := j*xs.size()+i
	var a := vertices[k].y
	var b := vertices[k+1].y
	var d := vertices[k+xs.size()].y
	var c := vertices[k+xs.size()+1].y
	return a+(b-a)*u+(c-b)*v if u>=v else a+(c-d)*u+(d-a)*v

func point(p: Vector2,lift := 0.0) -> Vector3:
	return Vector3(p.x,y(p.x,p.y)+lift,p.y)
