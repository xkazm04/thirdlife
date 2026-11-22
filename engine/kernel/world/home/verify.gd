extends SceneTree
const Landscape = preload("res://kernel/world/landscape.gd")
const Land = preload("res://kernel/world/home/valley.gd")
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(label: String,okay: bool,detail: String) -> void:
	print(("PASS " if okay else "FAIL ")+"home.a."+label+" "+detail)
	failed = failed or not okay

func digest(land: RefCounted) -> String:
	var samples := []
	for x in range(-1664,1664,41):
		for z in range(-1248,1248,47):
			samples.append([land.height(x,z),land.material(x,z),land.water(x,z)])
	return (JSON.stringify(land.summary())+JSON.stringify(samples)).sha256_text()

func run() -> void:
	var walk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://boot/village.json"))
	var cfg: Dictionary = walk.landscape.duplicate(true)
	cfg.road=walk.road
	cfg.footprints=[]
	var xf := []
	var radii := []
	var own := []
	for p: Dictionary in walk.plots:
		xf.append(Transform3D(Basis.IDENTITY,Vector3(p.origin[0],p.origin[1],p.origin[2])))
		radii.append(p.radius)
		own.append(false)
		cfg.footprints.append(Vector2(p.footprint.size_m[0],p.footprint.size_m[1]))
	var node := Node3D.new()
	root.add_child(node)
	TLStyle.set_headless(false)
	Landscape.build(node,xf,radii,own,cfg)
	Landscape.arrive(node)
	var terrain: RefCounted=node.get_meta("tl_terrain")
	var before: PackedByteArray = terrain.heights.to_byte_array()
	var land := Land.new(cfg.seed,terrain)
	var h := digest(land)
	var second := digest(Land.new(cfg.seed,terrain))
	check("determinism", h==second and h!=digest(Land.new(cfg.seed+1,terrain)),h+" repeat "+second)
	check("extent",land.LIMIT>=1300,str(land.summary().extent))
	var reached := {"village":Vector2(-270,6)}
	for k in land.paths.size():
		for path: Dictionary in land.paths:
			if reached.has(path.from) and reached[path.from]==Vector2(path.points[0][0],path.points[0][1]) and path.width>0:
				reached[path.to]=Vector2(path.points[-1][0],path.points[-1][1])
	var good := true
	var venues := 0
	for s: Dictionary in land.sites:
		var centre := Vector2(s.centre[0],s.centre[1])
		good = good and reached.get(s.id)==centre
		for vx in [-1,1]:
			for vz in [-1,1]:
				var corner := centre+Vector2(vx*s.footprint[0],vz*s.footprint[1]).rotated(-deg_to_rad(s.yaw))*0.5
				good = good and absf(land.height(corner.x,corner.y)-s.pad_h)<0.01
		if not s.portal: venues+=1
	check("reach",good and venues==5 and land.sites.size()-venues==2,"5 graded venues, 2 portals")
	var raw := OS.get_environment("TL_HOME_TEST")
	DirAccess.make_dir_recursive_absolute(raw)
	var chunks := []
	for c in [Vector2i(-8,1),Vector2i(-7,1),Vector2i(-8,2)]:
		var chunk := land.chunk(c.x,c.y)
		FileAccess.open(raw.path_join("chunk_%d_%d.json"%[c.x,c.y]),FileAccess.WRITE).store_string(JSON.stringify(chunk))
		chunks.append(chunk)
	good=true
	for chunk: Dictionary in chunks:
		good=good and chunk.heights_u16.size()==1089 and chunk.materials.size()==1024
		for j in 33:
			for i in 33:
				var q: int=chunk.heights_u16[j*33+i]
				var original := land.height(chunk.chunk[0]*96+i*3,chunk.chunk[1]*96+j*3)
				good=good and q>=0 and q<=65535 and absf(q*chunk.scale_m+chunk.offset_m-original)<=chunk.scale_m*0.51
		for id: int in chunk.materials: good=good and id>=0 and id<chunk.palette.size()
		for w: Array in chunk.water_levels_m:
			var x: float=chunk.chunk[0]*96+(int(w[0])%32)*3+1.5
			var z: float=chunk.chunk[1]*96+floori(float(w[0])/32)*3+1.5
			good=good and land.height(x,z)<=float(w[1])
	for i in 33:
		good=good and chunks[0].heights_u16[i*33+32]==chunks[1].heights_u16[i*33]
		good=good and chunks[0].heights_u16[32*33+i]==chunks[2].heights_u16[i]
	check("chunk",good and chunks[0].water_levels_m.size()>0,"3 chunks, 66 shared samples")
	var seam := 0.0
	for j in terrain.nz+1:
		for i in terrain.nx+1:
			var x: float=terrain.x0+i*terrain.cell
			var z: float=terrain.z0+j*terrain.cell
			seam=maxf(seam,absf(land.height(x,z)-terrain.gy(x,z)))
			if i==0 or i==terrain.nx or j==0 or j==terrain.nz:
				var outward := Vector2(-1 if i==0 else int(i==terrain.nx),-1 if j==0 else int(j==terrain.nz))
				seam=maxf(seam,absf(land.height(x+outward.x*0.001,z+outward.y*0.001)-terrain.gy(x,z)))
	check("village",seam<0.001 and before==terrain.heights.to_byte_array(),"max interior/edge delta "+str(seam))
	FileAccess.open(raw.path_join("regions.json"),FileAccess.WRITE).store_string(JSON.stringify(land.summary(),"\t"))
	quit(1 if failed else 0)
