extends RefCounted
## A furlong is a group of strips farmed together. Shared ends follow the slope;
## a grass headland and an occasional hedge separate neighbours.
const Parts = preload("res://kernel/world/terrain/village_parts.gd")
const SOILS := ["grass_dry","dirt","grass_dark","sand","grass_dry","dirt","grass"]

static func fields(rng: RandomNumberGenerator) -> Array:
	var parcels := []
	for district: Array in [
		[[-470,370],[525,424],[475,810],[-294,701],9],
		[[-1430,-130],[-966,-63],[-949,64],[-1425,121],6],
		[[-1260,496],[-922,479],[-984,688],[-1300,623],5],
		[[485,-285],[1070,-348],[1035,-82],[535,-56],7],
		[[623,380],[1235,237],[1300,490],[552,606],8],
		[[-470,-685],[332,-802],[363,-563],[-435,-500],8]]:
		var corners := []
		for i in 4: corners.append(Vector2(district[i][0],district[i][1]))
		var t := 0.0
		for i in int(district[4]):
			var end := minf(1,t+rng.randf_range(0.75,1.25)/float(district[4]))
			if i+1==int(district[4]): end=1
			if end-t < 0.04: break
			var pts := []
			for uv: Vector2 in [Vector2(t+0.005,0.02),Vector2(end-0.005,0.02),Vector2(end-0.005,0.98),Vector2(t+0.005,0.98)]:
				var p: Vector2=corners[0].lerp(corners[1],uv.x).lerp(corners[3].lerp(corners[2],uv.x),uv.y)
				pts.append([p.x,p.y])
			parcels.append({"corners":pts,"soil":SOILS[(i+rng.randi_range(0,2))%SOILS.size()],"hedge":i%3!=1,
				"rows":rng.randi_range(6,13),"end_tree":rng.randf()>0.58})
			t=end
	return parcels

static func place(places: RefCounted) -> void:
	var hay := []
	var furrows := TLMesh.new()
	var hedges := []
	var oaks := []
	for field: Dictionary in places.land.fields:
		var corners := PackedVector2Array()
		for q: Array in field.corners: corners.append(Vector2(q[0],q[1]))
		var steps := ceili(maxf(corners[0].distance_to(corners[3]),corners[1].distance_to(corners[2]))/9)
		if field.soil in ["dirt","grass_dry","sand"]:
			for i in range(1,int(field.rows),2):
				var u := float(i)/float(field.rows)
				var p := corners[0].lerp(corners[1],u)
				var q := corners[3].lerp(corners[2],u)
				var side := (q-p).normalized().orthogonal()*0.72
				for j in steps:
					var start := p.lerp(q,float(j)/steps)
					if places.near_lane(start): continue
					var end := p.lerp(q,float(j+1)/steps)
					furrows.quad_up_any(places.p3(start+side,0.14),places.p3(start-side,0.14),places.p3(end-side,0.14),places.p3(end+side,0.14),"grass_dry" if field.soil=="dirt" else "dirt")
		for j in steps:
			var along := (corners[3]-corners[0])/steps
			var a := corners[0]+along*j
			if j%5==2 and field.soil=="grass_dry":
				var p := a+(corners[1]-corners[0])*0.34
				if places.clear(p): hay.append(Transform3D(Basis(Vector3.UP,-along.angle()),places.p3(p)))
			if field.hedge and places.clear(a):
				hedges.append(hedge(places,a,along))
				if j%9==5 and field.end_tree: oaks.append(places.tree_at(a,places.rng.randf_range(0.8,1.3)))
	places.parent.add_child(furrows.instance("Furrows"))
	var sheaf := TLMesh.new()
	sheaf.cyl(1.35,1.9,8,"grass_dry",Color.WHITE,0.53)
	sheaf.cyl(0.93,0.17,8,"wood_light",Color.WHITE,0.85,Vector3(0,1.05,0))
	Parts.multi(places.parent,sheaf,hay,"HarvestStooks")
	Parts.multi(places.parent,TLKitNature.bush(880,1.6),hedges,"HawthornHedges")
	Parts.multi(places.parent,TLKitNature.broadleaf(883,12.0),oaks,"FieldOaks")
	for q: Array in [[-1340,-146,9],[-1307,-162,-8],[-414,747,-17],[488,-374,22],[1062,275,63]]:
		places.kit("house",{"width":13,"depth":7,"wall_h":4.5,"roof_rise":3.8,"lights":false},Vector2(q[0],q[1]),q[2],1.3)

static func hedge(places: RefCounted,p: Vector2,along: Vector2) -> Transform3D:
	var basis := Basis(Vector3.UP,-along.angle()).scaled_local(Vector3(3.7,1.4,1.0))
	return Transform3D(basis,places.p3(p,-0.1))
