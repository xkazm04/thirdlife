extends RefCounted
## Vernacular landmarks made out of the same palette geometry as the village joinery.
static func mill(places: RefCounted) -> void:
	var bank := Vector2(places.land.river_x(59)-places.land.river_width(59)-9,59)
	var deck := Vector3(bank.x,4.5,bank.y)
	var mk := TLMesh.new()
	mk.box(Vector3(14,10,19),"stone",Color.WHITE,0.25,deck-Vector3.UP*4.7)
	places.solids.append([Transform3D(Basis.IDENTITY,deck-Vector3.UP*4.7),Vector3(14,10,19)])     # D1: the visitor stands on it
	places.solids.append([Transform3D(Basis(Vector3.UP,PI*0.5),deck+Vector3.UP*4.0),Vector3(15,8,9)*Vector3(1.45,1,1.45)])
	var hall: Node3D=places.kit("house",{"width":15.0,"depth":9.0,"wall_h":5.5,"roof_rise":4.5,"lights":false},bank,90,1.45)
	hall.position=deck
	var tower: Node3D=places.kit("house",{"width":5.5,"depth":6.0,"wall_h":5.9,"roof_rise":4,"lights":false},bank,90,1.45)
	tower.position=deck+Vector3(-5,7,-6)
	mk.box(Vector3(1.8,12,1.8),"stone_dark",Color.WHITE,0.09,deck+Vector3(2,9,-5))
	mk.box(Vector3(2.35,0.65,2.35),"rock_warm",Color.WHITE,0.08,deck+Vector3(2,15.2,-5))
	var hub := Vector3(deck.x+9.5,places.land.level(bank.y)+7.3,deck.z)
	mk.cyl_between(hub-Vector3.RIGHT*7,hub+Vector3.RIGHT*2.8,0.65,8,"wood_dark")
	for i in 16:
		var a := TAU*i/16
		var b := TAU*(i+1)/16
		var p := hub+Vector3(0,cos(a),sin(a))*7.8
		var q := hub+Vector3(0,cos(b),sin(b))*7.8
		for side: float in [-1.45,1.45]:
			var ofs := Vector3.RIGHT*side
			mk.cyl_between(p+ofs,q+ofs,0.42,5,"wood_dark")
			if i%2==0: mk.cyl_between(hub+ofs,p+ofs,0.27,5,"plank")
		mk.push_at(p,Vector3(-rad_to_deg(a),0,0))
		mk.box(Vector3(3.4,1.1,0.48),"wood_light")
		mk.pop()
	# Loading platform on the side of the wheelhouse facing the road.
	var porch := deck+Vector3(-1,0.3,12)
	mk.box(Vector3(13,0.65,5),"plank",Color.WHITE,0.07,porch)
	places.solids.append([Transform3D(Basis.IDENTITY,porch),Vector3(13,0.65,5)])
	for x: float in [-5,5]:
		mk.box(Vector3(0.65,8,0.65),"wood_dark",Color.WHITE,0,porch+Vector3(x,-4,1.7))
	places.parent.add_child(mk.instance("WheelhouseAndLanding"))

static func portal(parent: Node3D,site: Dictionary,base: Vector3) -> void:
	var mk := TLMesh.new()
	mk.push_at(base,Vector3(0,float(site.yaw)-90,0))
	if site.id=="scar":
		for side: float in [-1,1]:
			for n in 5:
				var width := 5.0-n*0.34
				mk.box(Vector3(width,4.2,width+0.45),"stone_dark" if n%2==0 else "stone",Color.WHITE,0.32,Vector3(side*7.8,n*4.05+2.0,0))
		mk.box(Vector3(20.8,3.4,4.4),"rock_warm",Color.WHITE,0.48,Vector3(0,21.0,0))
		mk.box(Vector3(13.6,1.15,2.4),"wood_dark",Color.WHITE,0.12,Vector3(0,18.6,0))
		mk.cyl(1.0,2.8,10,"steel_dark",Color.WHITE,1.0,Vector3(0,17.4,0))
		mk.cyl(2.9,4.2,10,"yellow_dark",Color.WHITE,1.35,Vector3(0,14.2,0))
		mk.cyl(3.2,0.65,10,"yellow",Color.WHITE,3.0,Vector3(0,12.2,0))
		mk.cyl(0.57,1.1,8,"steel_dark",Color.WHITE,0.4,Vector3(0,11.5,0))
	else:
		for i in 15:
			var angle := PI*i/14
			var p := Vector3(8*cos(angle),3+13*sin(angle),0)
			mk.push_at(p,Vector3(0,0,rad_to_deg(angle)-90))
			mk.box(Vector3(3.0,3.85,4.1),"stone" if i%3 else "rock_warm",Color.WHITE,0.3)
			mk.pop()
		for side: float in [-1,1]:
			mk.box(Vector3(4.3,3.2,5),"stone_dark",Color.WHITE,0.25,Vector3(8*side,1.45,0))
	mk.pop()
	parent.add_child(mk.instance("BellGate" if site.id=="scar" else "ShepherdDoor"))

static func perry_market(places: RefCounted) -> void:
	var mk := TLMesh.new()
	for stall in 3:
		var foot: Vector3=places.p3(Vector2(-1179+stall*13,411+stall*3))
		for x: float in [-5.0,5.0]:
			for z: float in [-3.0,3.0]:
				mk.box(Vector3(0.45,5,0.45),"wood_dark",Color.WHITE,0.06,foot+Vector3(x,2.5,z))
		mk.box(Vector3(11,0.35,2),"plank",Color.WHITE,0.08,foot+Vector3(0,1.55,-2))
		for band in 6:
			var x := -6.0+band*2
			for side: float in [-1,1]:
				var p := foot+Vector3(x,5.9,0)
				var q := foot+Vector3(x,4.6,side*4)
				mk.quad_up_any(p,p+Vector3.RIGHT*2,q+Vector3.RIGHT*2,q,"curb_white" if band%2==0 else "flag_a")
		for barrel in 3:
			mk.cyl(0.86,1.7,10,"wood",Color.WHITE,0.72,foot+Vector3(-4+barrel*2,0.85,-4))
	places.parent.add_child(mk.instance("PerryFairStalls"))

static func hoist(places: RefCounted) -> void:
	# At the perimeter of the green the miller can swing a sack onto a cart.
	var mk := TLMesh.new()
	var foot: Vector3=places.p3(Vector2(-902,121))
	mk.push_at(foot,Vector3(0,-18,0))
	mk.box(Vector3(6,0.9,6),"stone",Color.WHITE,0.25,Vector3.UP*0.45)
	mk.box(Vector3(1.1,12,1.1),"wood_dark",Color.WHITE,0.12,Vector3.UP*6)
	mk.cyl_between(Vector3(-2.5,11.8,0),Vector3(7,11.8,0),0.52,6,"wood")
	mk.cyl_between(Vector3(0,5.4,0),Vector3(6.2,11.7,0),0.36,6,"wood")
	mk.cyl_between(Vector3(6.3,11.7,0),Vector3(6.3,2.8,0),0.11,6,"wood_dark")
	mk.box(Vector3(2.4,2.1,1.8),"plank",Color.WHITE,0.18,Vector3(6.3,2.1,0))
	for i in 5:
		mk.cyl(1.15,2.6,10,"wood",Color.WHITE,0.94,Vector3(-3+i%3*2.5,1.3,4+i/3*2.5))
	mk.pop()
	places.parent.add_child(mk.instance("MillGreenSackHoist"))

static func fair_bunting(places: RefCounted) -> void:
	var mk:=TLMesh.new()
	for loc: Vector2 in [Vector2(-1105,350),Vector2(-1114,361)]:
		var root: Vector3=places.p3(loc)
		mk.push_at(root,Vector3(0,-41,0))
		for side: float in [-1,1]:
			mk.box(Vector3(0.47,8.3,0.47),"wood_dark",Color.WHITE,0.05,Vector3(side*8,4.0,0))
		for i in 12:
			var x: float=-8.0+i*16.0/12
			var next:=x+16.0/12
			var a:=Vector3(x,6.65+1.4*pow(x/8,2),0)
			var b:=Vector3(next,6.65+1.4*pow(next/8,2),0)
			mk.cyl_between(a,b,0.08,4,"wood_dark")
			var tip:=a.lerp(b,0.55)+Vector3(0,-1.4,0.26)
			var dye: String=["flag_a","curb_white","yellow"][i%3]
			mk.tri(a,b,tip,dye)
			mk.tri(tip,b,a,dye)
		mk.pop()
	places.parent.add_child(mk.instance("FairDayBunting"))
