extends RefCounted
const Landmarks = preload("res://kernel/world/home/landmarks.gd")
const Parts = preload("res://kernel/world/terrain/village_parts.gd")
var parent: Node3D
var land: RefCounted
var ground: RefCounted
var rng := RandomNumberGenerator.new()
var splines := []
var road_cells := {}
var phase_ms := {}
var approach_sample := {}
var lane_faces := PackedVector3Array()   # D1: the lanes and the bridge deck as the visitor's ground (hook.gd)
var rail_faces := PackedVector3Array()   # D1: the bridge's two rails, walls of 1.6 m (hook.gd)
var trunks := []                         # D1: [foot, radius] of every valley tree: its trunk stops the visitor (hook.gd)
var solids := []                         # D1: [transform, size] boxes of the mill that stop the visitor (hook.gd)

func grow(root: Node3D,valley: RefCounted) -> Dictionary:
	parent=root
	land=valley
	rng.seed=land.world_seed*457+19
	var start := Time.get_ticks_usec()
	for child in parent.get_children():
		if child.name in [&"WorldFarGround",&"WorldMesas",&"WorldMesaPines"]: child.hide()
		if str(child.name).begins_with("WorldBelt") and child is MultiMeshInstance3D:
			var mm: MultiMesh = child.multimesh
			var kept := []
			for xf: Transform3D in child.get_meta(&"tl_xs"):
				if land.village.inside(xf.origin.x,xf.origin.z): kept.append(xf)
			mm.instance_count=kept.size()
			for i in kept.size():
				mm.set_instance_transform(i,kept[i])
				mm.set_instance_color(i,Color.WHITE)
	ground=preload("res://kernel/world/home/ground.gd").new()
	ground.build(parent,land)
	var last := lap("terrain_and_belt",start)
	river()
	roads()
	last=lap("water_and_lanes",last)
	plots()
	farms()
	last=lap("places_and_crops",last)
	scatter()
	lap("trees",last)
	return phase_ms

func lap(key: String,t: int) -> int:
	var now := Time.get_ticks_usec()
	phase_ms[key]=(now-t)/1000.0
	return now

func river() -> void:
	var cps := []
	for z in range(-land.LIMIT,land.LIMIT+1,48):
		cps.append(Vector2(land.river_x(z),z))
	var channel := TLKitPath.new(cps,false,4)
	for i in channel.count(): channel.ys[i]=land.level(channel.pts[i].y)
	# The native river ribbon provides metres-along-flow UVs for the crisp water shader.
	# Land depth clips the wide ribbon precisely to the carved banks.
	parent.add_child(TLKitRoad.river_ribbon(channel,136,0).instance("WrenWater"))

func p3(p: Vector2,lift:=0.0) -> Vector3:
	return ground.point(p,lift)

func roads() -> void:
	var mk := TLMesh.new()
	for road: Dictionary in land.paths:
		if road.get("existing",false): continue
		var cp := []
		for p: Array in road.points: cp.append(Vector2(p[0],p[1]))
		var path := TLKitPath.new(cp,false,3)
		splines.append(path)
		path.pts.append(cp.back())
		path.tang.append(path.tang[-1])
		var prev := []
		var was_bridge := false
		var previous_verge := []
		var previous_point := Vector2.ZERO
		for i in path.pts.size():
			var p := path.pts[i]
			var normal := path.tang[i].orthogonal()
			var left := p3(p+normal*float(road.width)*0.5,0.22)
			var right := p3(p-normal*float(road.width)*0.5,0.22)
			var bridge: bool = road.to=="mill" and minf(left.y,right.y)<1.3
			if bridge:
				left.y=maxf(1.3,left.y)
				right.y=maxf(1.3,right.y)
			var minor: bool=road.to not in ["ford","mill","down"]
			var boundary: Vector2=p.clamp(land.border.position,land.border.end)
			var margin := (1.35 if minor else 1.75)*smoothstep(0,62,p.distance_to(boundary))
			var verge := [p3(p+normal*(float(road.width)*0.5+margin),0.20),p3(p-normal*(float(road.width)*0.5+margin),0.20)]
			if not prev.is_empty():
				var chalk: bool = not bridge and not was_bridge and not land.village.inside(p.x,p.y)
				mk.quad_up(prev[0],prev[1],right,left,"plank" if bridge else ("sand" if chalk else "dirt"))
				lane_faces.append_array(PackedVector3Array([prev[0],prev[1],right,prev[0],right,left]))
				lane_sides(i,path.pts.size(),bridge or was_bridge,chalk and margin>0.02,prev,[left,right],previous_verge,verge,previous_point,p)
				if chalk and minor:
					var lift := Vector3.UP*0.045
					mk.quad_up(prev[0].lerp(prev[1],0.43)+lift,prev[0].lerp(prev[1],0.57)+lift,left.lerp(right,0.57)+lift,left.lerp(right,0.43)+lift,"grass_dry")
				if chalk and margin>0.02:
					for k in 2:
						mk.quad_up(previous_verge[k],prev[k],left if k==0 else right,verge[k],"stone" if minor else "concrete")
				if road.to=="mill":
					var eye := Vector2(-808,81)
					var nearest := Geometry2D.get_closest_point_to_segment(eye,previous_point,p)
					var offset := eye.distance_to(nearest)
					if offset<float(approach_sample.get("lateral_m",INF)):
						var weight := previous_point.distance_to(nearest)/maxf(0.001,previous_point.distance_to(p))
						approach_sample={"lateral_m":offset,"width_m":road.width,"deck_y":lerpf((prev[0].y+prev[1].y)*0.5,(left.y+right.y)*0.5,weight)}

				if bridge and was_bridge:
					for edge in [[prev[0],left],[prev[1],right]]:
						var a: Vector3=edge[0]
						var b: Vector3=edge[1]
						rail_faces.append_array(PackedVector3Array([a,b,b+Vector3.UP*1.6,a,b+Vector3.UP*1.6,a+Vector3.UP*1.6]))
						mk.cyl_between(a+Vector3.UP*1.6,b+Vector3.UP*1.6,0.13,5,"wood_dark")
						if i%2==0:
							mk.box(Vector3(0.30,2.05,0.30),"wood",Color.WHITE,0,b+Vector3.UP*0.76)
						if i%4==0:
							var floor_y: float=ground.y(b.x,b.z)
							var depth := maxf(b.y-floor_y+0.3,0.5)
							mk.box(Vector3(1.45,depth,1.45),"stone",Color.WHITE,0.16,b-Vector3.UP*depth*0.5)
							mk.cyl_between(b-Vector3.UP*1.9,b+(a-b)*1.4,0.22,6,"wood_dark")
							mk.cyl_between(b-Vector3.UP*1.9,b-(a-b)*1.4,0.22,6,"wood_dark")
			road_cells[Vector2i(floori(p.x/12),floori(p.y/12))]=true
			previous_verge=verge
			previous_point=p
			prev=[left,right]
			was_bridge=bridge
	parent.add_child(mk.instance("ValleyLanes"))

## D1: the lane floats 0.22 m on the land. For the visitor (hook.gd) its sides, over the chalk verge where one is drawn,
## and both of its ends run down to the ground in a ramp of 0.7 m: no step to catch on and no gap under the lane.
## The deck has rails instead of side ramps.
func lane_sides(i: int,count: int,deck: bool,verged: bool,prev: Array,now: Array,prev_verge: Array,verge: Array,from: Vector2,to: Vector2) -> void:
	var along := (to-from).normalized()
	var across := along.orthogonal()
	if not deck:
		for k in 2:
			var sign_k := 1.0 if k==0 else -1.0
			var a: Vector3=prev[k]
			var b: Vector3=now[k]
			if verged:
				lane_faces.append_array(PackedVector3Array([a,b,verge[k],a,verge[k],prev_verge[k]]))
				a=prev_verge[k]
				b=verge[k]
			lane_faces.append_array(ramp(a,b,Vector2(a.x,a.z)+across*sign_k*0.7,Vector2(b.x,b.z)+across*sign_k*0.7))
	if i==1:
		lane_faces.append_array(ramp(prev[0],prev[1],Vector2(prev[0].x,prev[0].z)-along*0.7,Vector2(prev[1].x,prev[1].z)-along*0.7))
	if i==count-1:
		lane_faces.append_array(ramp(now[0],now[1],Vector2(now[0].x,now[0].z)+along*0.7,Vector2(now[1].x,now[1].z)+along*0.7))

func ramp(a: Vector3,b: Vector3,a_out: Vector2,b_out: Vector2) -> PackedVector3Array:
	var a2 := Vector3(a_out.x,ground.y(a_out.x,a_out.y)-0.02,a_out.y)
	var b2 := Vector3(b_out.x,ground.y(b_out.x,b_out.y)-0.02,b_out.y)
	return PackedVector3Array([a,b,b2,a,b2,a2])

func near_lane(p: Vector2) -> bool:
	var cell := Vector2i(floori(p.x/12),floori(p.y/12))
	for dx in range(-1,2):
		for dz in range(-1,2):
			if road_cells.has(cell+Vector2i(dx,dz)): return true
	return false

func kit(kind: String,params: Dictionary,p: Vector2,yaw:=0.0,scale_factor:=1.0) -> Node3D:
	var part := TLKit.build(kind,params)
	part.position=p3(p)
	part.rotation.y=deg_to_rad(yaw)
	part.scale=Vector3.ONE*scale_factor
	parent.add_child(part)
	return part

func plots() -> void:
	var pads := TLMesh.new()
	for site: Dictionary in land.sites:
		var c := Vector2(site.centre[0],site.centre[1])
		var size := Vector2(site.footprint[0],site.footprint[1])
		var yaw := deg_to_rad(site.yaw)
		var corners := []
		for sign_v: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			corners.append(p3(c+(sign_v*size*0.5).rotated(-yaw),0.13))
		# Low corner stones show the buildable area; the green itself is land.
		for j in 4:
			var p: Vector3=corners[j]
			pads.box(Vector3(0.9,1.35,0.9),"stone",Color.WHITE,0.12,p+Vector3.UP*0.43)
			if not site.portal:
				var end: Vector3=p.lerp(corners[(j+1)%4],0.20)
				pads.box(Vector3(0.3,1.25,0.3),"wood_dark",Color.WHITE,0,end+Vector3.UP*0.49)
				pads.cyl_between(p+Vector3.UP*0.84,end+Vector3.UP*0.84,0.12,4,"wood_light")
		if site.portal:
			Landmarks.portal(parent,site,p3(c))
		else:
			kit("flag",{"height":10.0,"color":"flag_a"},c+(size*0.46).rotated(-yaw))
	parent.add_child(pads.instance("ValleyGreens"))
	# A split-rail gate and an ash mark the turn onto the mill road.
	var gate := TLMesh.new()
	for side in [-1,1]:
		var prev := Vector3.ZERO
		for i in 12:
			var q := Vector2(-404-i*4.4,18+i*1.65+side*7)
			var foot := p3(q)
			gate.box(Vector3(0.29,1.85,0.3),"wood_dark",Color.WHITE,0,foot+Vector3.UP*0.87)
			if i>0 and i!=4:
				for height: float in [0.58,1.28]:
					gate.cyl_between(prev+Vector3.UP*height,foot+Vector3.UP*height,0.105,4,"wood")
			prev=foot
	parent.add_child(gate.instance("PerryLaneGate"))
	kit("tree",{"height":13.0,"species":"broadleaf","seed":290},Vector2(-427,12))
	kit("sign",{},Vector2(-409,33),85)
	Landmarks.mill(self)
	Landmarks.hoist(self)
	Landmarks.perry_market(self)
	Landmarks.fair_bunting(self)
	# Pollards mark the loading green from the far end of the mill bridge.
	var pollards := []
	for loc: Vector2 in [Vector2(-850,67),Vector2(-864,62),Vector2(-880,60),Vector2(-898,65),Vector2(-910,85)]:
		pollards.append(tree_at(loc,rng.randf_range(0.85,1.16)))
	Parts.multi(parent,TLKitNature.broadleaf(521,9.5),pollards,"MillGreenPollards")
	add_trunks(pollards,0.38)

func farms() -> void:
	preload("res://kernel/world/home/husbandry.gd").place(self)
	var vane := Vector2(986,180)
	kit("watch_tower",{"height":13},vane,26,1.3)
	kit("flag",{"height":17,"color":"flag_b"},vane+Vector2(7,-4))
	
func clear(p: Vector2) -> bool:
	if near_lane(p) or absf(p.x-land.river_x(p.y))<land.river_width(p.y)+12: return false
	for site: Dictionary in land.sites:
		if p.distance_squared_to(Vector2(site.centre[0],site.centre[1]))<2100: return false
	return true

func tree_at(p: Vector2,s: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*s),p3(p,-0.12))

func scatter() -> void:
	var fir := []
	var pear := []
	var willow := []
	for i in 1250:
		var p := Vector2(rng.randf_range(-1590,-950),rng.randf_range(-715,-95))
		if ((p-Vector2(-1270,-405))/Vector2(342,312)).length()>1+0.12*sin(p.x*0.024) or not clear(p): continue
		fir.append(tree_at(p,rng.randf_range(0.65,1.45)))
	for i in 22:
		for j in 13:
			var p := Vector2(-1280+i*16+j*2,220+j*18-i*2)
			if clear(p): pear.append(tree_at(p,rng.randf_range(0.82,1.12)))
	for i in 500:
		var z := rng.randf_range(-1600,1550)
		var p := Vector2(land.river_x(z)+(land.river_width(z)+rng.randf_range(14,76))*(1 if i%2==0 else -1),z)
		if clear(p) and sin(z*0.017+float(i%2))>0: willow.append(tree_at(p,rng.randf_range(0.7,1.5)))
	# Coppices follow two shallow drainage lines across the open downs. Leave gaps
	# at the col and under the high bedrock, so the far tree line has a shape.
	river_reeds()
	var larches := []
	for i in 1000:
		var x := rng.randf_range(-1730,1850)
		var z := -655+96*sin(x*0.003+land.phase)+rng.randfn(0,38)
		if i%3==0:
			x=rng.randf_range(500,1750)
			z=830-0.24*x+130*sin(x*0.003)+rng.randfn(0,46)
		var p := Vector2(x,z)
		if sin(x*0.009)+0.65*cos(z*0.019)>-0.2 and clear(p) and land.parcel_at(x,z).is_empty():
			larches.append(tree_at(p,rng.randf_range(0.7,1.45)))
	# Trunk radii are the kit's own (TLKitNature: a pine 0.22 h / 9, a broadleaf 0.28 h / 7) times each tree's scale.
	for group: Array in [[larches,0.42],[fir,0.42],[pear,0.30],[willow,0.46]]: add_trunks(group[0],group[1])
	Parts.multi(parent,TLKitNature.pine(402,17,3,4.8),larches,"DownsCoppices")
	Parts.multi(parent,TLKitNature.pine(201,17,5,4.6),fir,"HemlockFold")
	Parts.multi(parent,TLKitNature.broadleaf(217,7.5),pear,"PerryBank")
	Parts.multi(parent,TLKitNature.broadleaf(232,11.5),willow,"WrenAlders")

func add_trunks(xs: Array,radius: float) -> void:
	for xf: Transform3D in xs: trunks.append([xf.origin,radius*xf.basis.get_scale().x])

func river_reeds() -> void:
	var seed_rng := RandomNumberGenerator.new()
	seed_rng.seed=land.world_seed*523+71
	var bunch := TLMesh.new()
	for i in 9:
		var root:=Vector3(seed_rng.randf_range(-1.5,1.5),0,seed_rng.randf_range(-0.9,0.9))
		var tip:=root+Vector3(0.32,seed_rng.randf_range(1.7,3.1),0.18)
		bunch.cyl_between(root,tip,0.085,4,"leaf")
		bunch.cyl_between(tip,tip+Vector3(0.06,0.45,0.04),0.14,5,"wood_dark")
	var tufts := []
	for i in 740:
		var z:=seed_rng.randf_range(-1590,1620)
		var flank:=1 if i%2 else -1
		if sin(z*0.021+flank)<0.28: continue
		var x: float=land.river_x(z)+flank*(land.river_width(z)+seed_rng.randf_range(0.4,7.5))
		var p:=Vector2(x,z)
		var foot:=p3(p)
		if near_lane(p) or foot.y<land.level(z)-0.5: continue
		tufts.append(Transform3D(Basis(Vector3.UP,seed_rng.randf()*TAU),foot))
	Parts.multi(parent,bunch,tufts,"WrenRushBeds")
