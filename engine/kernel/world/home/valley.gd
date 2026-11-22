extends RefCounted
## The Wren valley. Metres, x east and z south. The village owns its entire sampled rectangle.
const LIMIT := 3264
const KEYS := ["grass", "grass_dark", "grass_dry", "sand", "rock_warm", "cliff", "dirt", "stone"]
var village: RefCounted
var border: Rect2
var world_seed: int
var noise := FastNoiseLite.new()
var phase: float
var regions := []
var sites := []
var paths := []
var waters := []
var fields := []
var field_cells := {}
var pad_cells := {}

func _init(seed_value: int, terrain: RefCounted) -> void:
	world_seed = seed_value
	village = terrain
	border = Rect2(terrain.x0, terrain.z0, terrain.x1()-terrain.x0, terrain.z1()-terrain.z0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 271 + 31
	phase = rng.randf_range(-0.45, 0.45)
	noise.seed = seed_value + 113
	noise.frequency = 0.003
	regions = [
		["Wren Water", "floodplain", [-1050,-1650,-420,1500], "A shallow winding channel broadens below the mill."],
		["Saffron Leas", "strip farms", [-590,280,640,1000], "Long tilled strips run down low south-facing folds."],
		["Perry Coomb","chalk escarpment",[-2860,-880,-1490,1350],"Two outward-facing spurs divided by a deep grass saddle above the fair."],
		["Perry Bank", "orchard", [-1350,140,-830,700], "Fruit trees in rows on the rising terrace."],
		["Hemlock Fold", "wood", [-1650,-760,-900,-190], "Tall close-set conifers surround a clearing."],
		["Bell Scar", "escarpment", [-1710,-1400,900,-660], "Broken limestone spurs frame a high saddle."],
		["Downland", "pasture", [455,-650,1900,890], "Open grass ridges beyond the east gates."],
		["The Sisters","limestone peaks",[1000,-3200,3230,-1240],"A wide sloping back, a needle and a lower shoulder above the distant watershed."]]
	_site("mill", "Mill Green", [-881,95], [46,36], 12)
	_site("orchard", "Perry Fair", [-1140,390], [52,34], -18)
	_site("wood", "Charcoal Green", [-1300,-420], [44,34], 30)
	_site("leas", "Harvest Common", [-270,555], [58,40], -12)
	_site("down", "Kite Down", [957,198], [44,38], 26)
	_site("scar", "Bell Gate", [-1070,-760], [18,14], 0, true)
	_site("steps", "Shepherd's Door", [335,905], [17,12], -35, true)
	_path("village", "ford", [[-270,6],[-391,14],[-477,49],[-575,116]], 8)
	_path("ford","mill",[[-575,116],[-653,106],[-747,92],[-805,81],[-847,77],[-881,95]], 9)
	_path("mill","orchard",[[-881,95],[-962,124],[-1040,209],[-1050,289],[-1140,390]], 7)
	_path("mill","wood",[[-881,95],[-987,32],[-1030,-89],[-1150,-181],[-1255,-265],[-1300,-420]], 7)
	_path("wood","scar",[[-1300,-420],[-1390,-510],[-1355,-580],[-1180,-575],[-1080,-632],[-1070,-760]], 5)
	_path("ford","leas",[[-575,116],[-562,249],[-497,329],[-485,426],[-375,486],[-270,555]], 7)
	_path("leas","steps",[[-270,555],[-125,615],[20,604],[147,690],[225,845],[335,905]], 5)
	paths.append({"from":"village","to":"east_end","spline":"catmull_rom","points":[[-270,6],[-190,3],[-100,0],[0,0],[100,0],[190,2],[290,5]],"width":6,"existing":true})
	_path("east_end","down",[[290,5],[405,9],[504,23],[586,67],[691,117],[800,114],[883,148],[957,198]],7)
	fields=preload("res://kernel/world/home/husbandry.gd").fields(rng)
	for parcel: Dictionary in fields:
		var polygon := PackedVector2Array()
		for pt: Array in parcel.corners: polygon.append(Vector2(pt[0],pt[1]))
		index_bounds(field_cells,Rect2(polygon[0],Vector2.ZERO).expand(polygon[1]).expand(polygon[2]).expand(polygon[3]),[parcel,polygon])
	for s: Dictionary in sites:
		var c := Vector2(s.centre[0],s.centre[1])
		index_bounds(pad_cells,Rect2(c-Vector2(82,82),Vector2(164,164)),s)
	var named := []
	for reg: Array in regions:
		named.append({"name":reg[0],"kind":reg[1],"bounds":reg[2],"character":reg[3]})
	regions=named
	waters = [{"name":"Wren Water", "kind":"river", "axis":"z", "range_m":[-LIMIT,LIMIT],
		"sample_spacing_m":12,"centre_and_half_width":[]}]
	for z in range(-LIMIT,LIMIT+1,12):
		waters[0].centre_and_half_width.append([river_x(z),z,river_width(z),level(z)])

func _site(id: String, title: String, at: Array, size: Array, yaw: float, portal := false) -> void:
	sites.append({"id":id,"name":title,"centre":at,"footprint":size,"yaw":yaw,"portal":portal,"pad_h":raw_height(at[0],at[1])})

func _path(a: String,b: String,points: Array,width: float) -> void:
	paths.append({"from":a,"to":b,"spline":"catmull_rom","points":points,"width":width})

func river_x(z: float) -> float:
	return -738 + 98*sin(z*0.004+phase) + 58*sin(z*0.009-0.9)

func river_width(z: float) -> float:
	return 18 + 22*exp(-pow((z-135)/175.0,2)) + 9*(1+sin(z*0.005))

func level(z: float) -> float:
	return -5 + 0.0013*z

func peak(x: float,z: float,cx: float,cz: float,wx: float,wz: float) -> float:
	return maxf(0,1-sqrt(pow((x-cx)/wx,2)+pow((z-cz)/wz,2)))

func raw_height(x: float,z: float) -> float:
	var d := absf(x-river_x(z))
	var w := river_width(z)
	var rolls := 25 + 13*sin(x*0.004+phase)*cos(z*0.007) + 15*noise.get_noise_2d(x,z)
	# Bell Scar is a dipping limestone bed. Its long back and broken short face have
	# different slopes. A gap where the river cuts the ridge separates the two massifs.
	var crest := -1070 + 94*sin(x*0.003+phase) + 37*cos(x*0.008)
	var foot := z-crest
	var slab := smoothstep(-820,0,foot)*(1-smoothstep(0,240,foot))
	var notch := smoothstep(82,285,d)
	var ridge := slab*notch*(160+56*cos(x*0.005)+83*peak(x,z,430,-1040,330,450))
	ridge += 124*peak(x,z,-1170,-1080,390,290) + 92*peak(x,z,340,-1130,180,260)
	ridge += 185*peak(x,z,1820,80,970,630) + 70*peak(x,z,1540,240,305,390)
	ridge += 162*peak(x,z,-1750,-310,780,660) + 152*peak(x,z,1630,400,600,940)
	if x>1120 and x<2250 and z > -220 and z<820:
		# Two short bedding-plane spurs with a water-worn nick between them.
		var u := x-1590
		var v := z-160+u*0.24
		var west_face := maxf(0,1-maxf(absf(v)/187,absf(u)/(300 if u<0 else 460)))
		var calf := maxf(0,1-maxf(absf(z-498+0.31*u)/134,absf(u-3)/(230 if u<0 else 345)))
		var cleft := peak(x,z,1585,329,620,135)
		ridge = ridge*(1-0.48*cleft)+137*smoothstep(0,0.72,west_face)+99*smoothstep(0,0.68,calf)
	if x < -1460:
		var rim := -1990+195*sin(z*0.0036)+67*cos(z*0.008+phase)
		var dip := x-rim
		var profile := smoothstep(-860,0,dip)*(1-smoothstep(0,295,dip))
		var southern := 300.0*peak(x,z,-1850,535,960,730)
		var northern := 198.0*peak(x,z,-2060,-515,790,470)
		var slot := smoothstep(32,255,absf(z-16+0.15*dip))
		ridge += profile*slot*(64.0+southern+northern)
	if x>450 and z < -720:
		# Two intersecting planes make the limestone dip slope and its near-vertical scarp.
		# A detached needle and a lower knuckle give the watershed its three bearings.
		var u := x-1900
		var v := z+2060+0.31*u
		var back := maxf(0,1-maxf(absf(u)/1160,absf(v)/(830 if v<0 else 420)))
		var needle := peak(x,z,2060,-2020,238,290)
		var knuckle := peak(x,z,1280,-1915,470,430)
		ridge += 285*back+181*needle+107*knuckle
	if ridge>55:
		ridge += smoothstep(55,170,ridge)*12*noise.get_noise_2d(x*3,z*3)
	rolls += ridge + 61*peak(x,z,352,980,680,510)
	# Flatten the floor through which the old west road leaves the village ring.
	var exit_z := 11+0.40*(-393-x)
	var cut := (1-smoothstep(45,145,absf(z-exit_z)))*smoothstep(-770,-600,x)*(1-smoothstep(-375,-285,x))
	rolls = lerpf(rolls,2.5+2.3*sin(x*0.006),cut)
	# The loading green sits on a low alluvial bench above the mill wheel.
	var mill_bench := 1.0-smoothstep(0.50,1.0,Vector2((x+858)/137.0,(z-85)/102.0).length())
	rolls = lerpf(rolls,6.4+0.013*(-850-x),mill_bench)
	return lerpf(level(z)-4.0, rolls, smoothstep(w-10, w+120, d)) + 5.0*smoothstep(w-9,w+7,d)*(1-smoothstep(w+7,w+120,d))

func height(x: float,z: float) -> float:
	var edge := Vector2(clampf(x,border.position.x,border.end.x),clampf(z,border.position.y,border.end.y))
	var distance := edge.distance_to(Vector2(x,z))
	if distance <= 0.0001:
		return village.gy(x,z)
	var y := raw_height(x,z)
	for s: Dictionary in pad_cells.get(cell(x,z),[]):
		var v := Vector2(x-s.centre[0], z-s.centre[1])
		if v.length_squared() > 5500: continue
		v = v.rotated(deg_to_rad(s.yaw)).abs()-Vector2(s.footprint[0],s.footprint[1])*0.5
		y = lerpf(s.pad_h,y,smoothstep(7,34,maxf(v.x,v.y)))
	if distance < 72:
		y = lerpf(village.gy(edge.x,edge.y),y,smoothstep(0,72,distance))
	return y

func cell(x: float,z: float) -> Vector2i:
	return Vector2i(floori(x/96),floori(z/96))

func index_bounds(index: Dictionary,box: Rect2,item: Variant) -> void:
	var lo := cell(box.position.x,box.position.y)
	var hi := cell(box.end.x,box.end.y)
	for iz in range(lo.y,hi.y+1):
		for ix in range(lo.x,hi.x+1):
			var k := Vector2i(ix,iz)
			if not index.has(k): index[k]=[]
			index[k].append(item)

func parcel_at(x: float,z: float) -> Dictionary:
	for entry: Array in field_cells.get(cell(x,z),[]):
		if Geometry2D.is_point_in_polygon(Vector2(x,z),entry[1]):
			return entry[0]
	return {}

func exposure(x: float,z: float,y: float) -> float:
	if (z > -660 and x > -1490 and x<1150) or y<68: return 0
	var dx := (raw_height(x+8,z)-raw_height(x-8,z))/16.0
	var dz := (raw_height(x,z+8)-raw_height(x,z-8))/16.0
	return smoothstep(68,160,y)*smoothstep(0.22,0.77,Vector2(dx,dz).length()+0.08*noise.get_noise_2d(x*3,z*3))

func material(x: float,z: float) -> String:
	var y:=height(x,z)
	return surface_key(x,z,parcel_at(x,z),exposure(x,z,y),wetness(x,z,y),green_at(x,z))

func green_at(x: float,z: float) -> bool:
	for site: Dictionary in pad_cells.get(cell(x,z),[]):
		var p:=Vector2(x-site.centre[0],z-site.centre[1]).rotated(deg_to_rad(site.yaw)).abs()
		if not site.portal and p.x<=site.footprint[0]*0.5 and p.y<=site.footprint[1]*0.5: return true
	return false

func wetness(x: float,z: float,y: float) -> float:
	if x < -1160 or x > -380: return 0
	var above := y-level(z)
	var bank := absf(x-river_x(z))-river_width(z)
	var swale := 133+37*sin(z*0.009+phase)+24*noise.get_noise_2d(x*2,z*2)
	return smoothstep(4,24,bank)*(1-smoothstep(swale,swale+74,bank))*(1-smoothstep(14,33,above))

func surface_key(x: float,z: float,parcel: Dictionary,bedrock: float,wet: float,green: bool) -> String:
	if border.has_point(Vector2(x,z)): return "terrain"
	if green: return "grass_dry"
	if not parcel.is_empty(): return parcel.soil
	if wet>0.43: return "grass_dark"
	var d := absf(x-river_x(z))
	if d < river_width(z)+11: return "sand"
	if bedrock>0.52: return "stone"
	if x < -940 and z < -135 and z > -740: return "grass_dark"
	if z > 320 and z < 920 and x > -525 and x < 630: return "grass_dry"
	return "grass"

func water(x: float,z: float) -> Variant:
	if border.has_point(Vector2(x,z)):
		for p: Dictionary in village.ponds:
			if Vector2(x,z).distance_to(p.c)<p.r and height(x,z)<p.y: return p.y
		if not village.river.is_empty() and village.river_dist(x,z)<float(village.river.half):
			var pts: PackedVector2Array = village.river.pts
			var best := 0
			for i in pts.size():
				if pts[i].distance_squared_to(Vector2(x,z)) < pts[best].distance_squared_to(Vector2(x,z)): best=i
			return village.river.ys[best]
		return null
	return level(z) if absf(x-river_x(z)) < river_width(z)+35 and height(x,z)<level(z) else null

func summary() -> Dictionary:
	return {"seed":world_seed,"extent":[-LIMIT,-LIMIT,LIMIT,LIMIT],"regions":regions,"paths":paths,"water":waters,"sites":sites,"fields":fields}

func chunk(cx: int,cz: int) -> Dictionary:
	var heights := []
	var mats := []
	var levels := []
	var palette := KEYS + ["terrain"]
	for j in 33:
		for i in 33:
			var x := cx*96+i*3
			var z := cz*96+j*3
			heights.append(clampi(roundi((height(x,z)+128)*100),0,65535))
			if i==32 or j==32: continue
			mats.append(palette.find(material(x+1.5,z+1.5)))
			var w = water(x+1.5,z+1.5)
			if w != null: levels.append([j*32+i,w])
	return {"proposal_version":1,"chunk":[cx,cz],"cell_m":3,"cells":[32,32],"offset_m":-128,"scale_m":0.01,
		"heights_u16":heights,"palette":palette,"materials":mats,"water_levels_m":levels}
