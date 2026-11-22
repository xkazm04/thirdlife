extends Node
const View = preload("res://kernel/world/draw/view.gd")
const Land = preload("res://kernel/world/home/valley.gd")
const Places = preload("res://kernel/world/home/places.gd")
const LABELS := ["overview_sw","village_edge_out","far_look_back","venue_approach","region_seam","map"]
const START := 1970
const LENGTH := 1080
var view: Node
var land: RefCounted
var artist: RefCounted
var output: String
var baseline: bool
var stats := {"stills":{}}
var camera: Camera3D
var poses := []
var times := []
var last := 0
var pass_name: String
var calls := PackedInt32Array()
var pose_hash := HashingContext.new()
var fog: Environment
var original_fog: bool
var first := 0
var clock_tick := 0

func _ready() -> void:
	output=OS.get_environment("TL_HOME_RAW")
	pass_name=OS.get_environment("TL_HOME_PASS")
	baseline=pass_name=="baseline"
	pose_hash.start(HashingContext.HASH_SHA256)
	var walkfile := output.path_join("walk.json")
	var walk: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://boot/village.json"))
	var games: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://boot/games.json"))
	var root := ProjectSettings.globalize_path("res://").get_base_dir().trim_suffix("/engine")
	for p: Dictionary in walk.plots:
		for g: Dictionary in games.games:
			if p.pack==g.name: p.pack=root.path_join(g.from)
	write(walkfile,walk)
	first=Time.get_ticks_usec()
	view=View.new()
	add_child(view)
	var end_tick := 4000 if pass_name=="growth" else START+LENGTH+8
	stats["run_id"]=OS.get_environment("TL_HOME_CAPTURE_ID")
	view.start({"walk":walkfile,"ticks":str(end_tick),
		"load":"block","out-dir":output,"log":output.path_join("tiers-"+pass_name+".json")})
	if view.landscape==null:
		get_tree().quit(2)
		return
	fog=get_viewport().world_3d.environment
	original_fog=fog.fog_enabled
	var data_start := Time.get_ticks_usec()
	land=Land.new(walk.landscape.seed,view.landscape.get_meta(&"tl_terrain"))
	stats["data_ms"]=(Time.get_ticks_usec()-data_start)/1000.0
	if not baseline:
		artist=Places.new()
		stats["build_ms"]=artist.grow(view.landscape,land)
		write(output.path_join("regions.json"),land.summary())
	print("[home] extent ",land.summary().extent," village ",land.border)
	stats["setup_ms"]=(Time.get_ticks_usec()-first)/1000.0
	camera=Camera3D.new()
	camera.far=11000
	camera.near=0.4
	camera.fov=50
	add_child(camera)
	camera.make_current()
	poses=[
		[Vector3(-1500,650,1300),Vector3(30,0,-25)],
		[Vector3(-386,7.708004,14),Vector3(-586,14.352797,115)],
		[Vector3(-1400,146.76834,-499),Vector3(-20,9,0)],
		[Vector3(-808,maxf(1.3,land.height(-808,81)+0.22)+6.4,81),Vector3(-884,8.0,95)],
		[Vector3(-1430,151.24783,95),Vector3(-1010,47.95913,-96)],
		[Vector3(30,3200,-25),Vector3(30,0,-25)]]
	var coords := []
	for pose: Array in poses:
		coords.append([Array(PackedFloat32Array([pose[0].x,pose[0].y,pose[0].z])),Array(PackedFloat32Array([pose[1].x,pose[1].y,pose[1].z]))])
	stats["cameras"]=coords
	if not baseline:
		stats["approach"]=artist.approach_sample.duplicate()
		stats.approach["clearance_m"]=poses[3][0].y-stats.approach.deck_y
	set_pose(poses[0],false)
	process_physics_priority=100100
	RenderingServer.frame_post_draw.connect(after_draw)

func write(path: String,value: Variant) -> void:
	var f := FileAccess.open(path,FileAccess.WRITE)
	if f==null:
		push_error("Cannot write "+path)
		get_tree().quit(2)
		return
	f.store_string(JSON.stringify(value,"\t"))

func set_pose(pose: Array,top: bool) -> void:
	camera.look_at_from_position(pose[0],pose[1],Vector3.FORWARD if top else Vector3.UP)
	camera.reset_physics_interpolation()

func _physics_process(_delta: float) -> void:
	if not camera: return
	clock_tick=int(view.world.tick)
	if clock_tick==50: fog.fog_enabled=false
	if clock_tick==60: fog.fog_enabled=original_fog
	if clock_tick<60:
		var i := clampi(floori(clock_tick/10.0),0,5)
		set_pose(poses[i],i==5)
	elif clock_tick>=START and clock_tick<START+LENGTH:
		var u := float(clock_tick-START)/float(LENGTH-1)
		var pose := flight(u)
		set_pose(pose,false)
		pose_hash.update(PackedVector3Array(pose).to_byte_array())
	else:
		if camera.current and view.stage<0: view.visitor.cam.make_current()
		return
	camera.make_current()

# x and z are world metres; y is clearance above the actual road or field.
func spline(points: PackedVector3Array,u: float) -> Vector3:
	var t := u*(points.size()-1)
	var i := mini(floori(t),points.size()-2)
	var p := points[i].cubic_interpolate(points[i+1],points[maxi(0,i-1)],points[mini(i+2,points.size()-1)],t-i)
	p.y+=land.height(p.x,p.z)
	return p

func flight(u: float) -> Array:
	var eye := spline(PackedVector3Array([
		Vector3(233,15,34),Vector3(123,16,27),Vector3(-37,19,9),Vector3(-202,27,8),
		Vector3(-384,29,20),Vector3(-536,43,85),Vector3(-676,40,119),Vector3(-797,27,106),
		Vector3(-881,17,95),Vector3(-963,25,137),Vector3(-1045,32,231),Vector3(-1078,27,315),
		Vector3(-1140,18,390),Vector3(-1191,34,389)]),u)
	var target := spline(PackedVector3Array([
		Vector3(181,2,67),Vector3(69,4,43),Vector3(-165,5,10),Vector3(-367,5,18),
		Vector3(-520,5,82),Vector3(-709,5,100),Vector3(-802,10,65),Vector3(-877,5,100),
		Vector3(-980,5,150),Vector3(-1060,8,229),Vector3(-1100,5,332),Vector3(-1154,6,389),
		Vector3(-1160,5,417),Vector3(-1151,4,415)]),u)
	return [eye,target]

func after_draw() -> void:
	if not camera or view._done: return
	var t := clock_tick
	if not stats.has("first_draw_ms"): stats["first_draw_ms"]=(Time.get_ticks_usec()-first)/1000.0
	if t<60 and t%10==8:
		var label: String=LABELS[floori(t/10.0)]
		var vp := get_viewport()
		stats.stills[label]={"tick":t,"draw_calls":vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			"primitives":vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)}
		if pass_name=="growth": save_image(output.path_join(label+".jpg"),false)
	if t>=START and t<START+LENGTH:
		var now := Time.get_ticks_usec()
		if last>0: times.append((now-last)/1000.0)
		last=now
		calls.append(get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
		if pass_name=="growth" and (t-START)%2==0:
			save_image(output.path_join("frame_%04d.jpg"%floori((t-START)/2.0)),true)
	if t==START+LENGTH:
		times.sort()
		var ordered := calls.duplicate()
		ordered.sort()
		stats["flyover"]={"samples":times.size(),"start_tick":START,"physics_frames":LENGTH,"capture_stride":2 if pass_name=="growth" else 0,"fps":30 if pass_name=="growth" else 60,
			"p50_ms":times[ceili(times.size()*0.5)-1],"p99_ms":times[ceili(times.size()*0.99)-1],"max_ms":times[-1],
			"pose_sha256":pose_hash.finish().hex_encode(),"draw_calls_p50":ordered[ceili(ordered.size()*0.5)-1],
			"draw_calls_p99":ordered[ceili(ordered.size()*0.99)-1],"draw_calls_max":ordered[-1]}
		stats["map_fog_off"]=original_fog
		write(output.path_join(pass_name+"-calls.json"),Array(calls))
		write(output.path_join(pass_name+".json"),stats)

func save_image(path: String,small: bool) -> void:
	var img := get_viewport().get_texture().get_image()
	if small: img.resize(1280,720,Image.INTERPOLATE_BILINEAR)
	if img.save_jpg(path,0.92)!=OK: get_tree().quit(2)
