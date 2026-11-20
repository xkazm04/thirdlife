extends "res://rigs/biped/clay_biped.gd"
## The walking coat has a box pleat across the shoulders and one inked hem.
## The skater keeps the team sweater, padded gloves and helmet on this skin.
const JACKET := [Vector2(-1,.94),Vector2(-.94,1),Vector2(-.70,.99),
	Vector2(.12,.93),Vector2(.59,1),Vector2(.82,.95),Vector2(1,.66)]
const TUFT := [Vector2(-1,.57),Vector2(-.74,.88),Vector2(-.28,1.0),
	Vector2(.43,.97),Vector2(.82,.73),Vector2(1,.45)]


func _init() -> void:
	paint_shader = preload("res://style/shaders/body_cel.gdshader")
	contour = preload("res://style/cel/body_outline.tres")


func _hair() -> void:
	part("Head", Finish.HAIR)
	# One continuous nape and two swept blocks. The crown steps down to
	# the near ear. Both locks follow the existing secondary-motion bone.
	piece(Vector3(0,1.781,.031),Vector3(.341,.190,.295),"hair",DOME,28,
		Vector3(0,-4,-2),Form.HAIRLINE,Color.WHITE,.77)
	part("Hair", Finish.HAIR)
	piece(Vector3(.073,1.970,.033),Vector3(.171,.110,.158),"hair",TUFT,16,
		Vector3(6,-19,-21),Form.PLAIN,Color.WHITE,.66)
	piece(Vector3(-.103,1.938,.163),Vector3(.139,.087,.118),"hair",TUFT,16,
		Vector3(19,15,16),Form.PLAIN,Color(1,.92,.85),.64)
	# A swept fringe crosses the hairline only on one side of the face.
	piece(Vector3(-.081,1.893,-.160),Vector3(.202,.080,.113),"hair",TIP,20,
		Vector3(-16,-17,-18),Form.LOCK,Color.WHITE,.83)
	part("Head", Finish.HAIR)
	piece(Vector3(-.249,1.795,-.112),Vector3(.069,.112,.074),"hair",TIP,14,
		Vector3(8,-20,-12),Form.LOCK)


func _nose() -> void:
	# A tapered bridge enters the forehead and cheek. Only its turned side
	# catches a line. A closed ball here inks a complete ring on the face.
	const ROWS := [Vector3(1.645,.032,0),Vector3(1.658,.048,.020),Vector3(1.674,.056,.052),
		Vector3(1.691,.051,.060),Vector3(1.711,.043,.041),Vector3(1.735,.040,.021),Vector3(1.760,.033,0)]
	const SPANS := 9
	var start := vertices.size()
	var skin := TLStyle.index(look["skin"])
	for row: Vector3 in ROWS:
		for i in SPANS:
			var u := float(i)/(SPANS-1)*2.0-1.0
			var depth := -.263 + .011*u*u - row.z*pow(1.0-u*u,1.5)
			_vertex(Vector3(row.y*u,row.x,depth),Color(1,.96,.93),0,skin)
	for j in ROWS.size():
		for i in SPANS:
			var v := start+j*SPANS+i
			var across := vertices[v+mini(1,SPANS-1-i)]-vertices[v-mini(1,i)]
			var along := vertices[v+mini(1,ROWS.size()-1-j)*SPANS]-vertices[v-mini(1,j)*SPANS]
			normals[v] = along.cross(across).normalized()
			if i+1 < SPANS and j+1 < ROWS.size():
				indices.append_array(PackedInt32Array([v,v+1,v+SPANS,v+1,v+SPANS+1,v+SPANS]))
	tri_count = indices.size()/3


func _jacket(team: bool) -> void:
	if team:
		super._jacket(true)
		return
	part("Hips", Finish.JACKET)
	bend_into("Chest",.94,1.31)
	piece(Vector3(0,1.133,.006),Vector3(.277,.261,.186),"top",JACKET,28,
		Vector3.ZERO,Form.PLAIN,Color.WHITE,.74)
	part("Chest", Finish.CLAY)
	piece(Vector3(0,1.427,-.004),Vector3(.127,.089,.126),"skin",EGG,18)
	part("Backpack", Finish.ENAMEL)
	# Flare the top edge. The two ends of the collar dip towards the zip.
	piece(Vector3(0,1.388,.005),Vector3(.298,.048,.205),"top",
		[Vector2(-1,.66),Vector2(-.44,.87),Vector2(.47,1.02),Vector2(1,1.0)],
		28,Vector3(0,-4,-2),Form.COLLAR,Color.WHITE,.80)
	part("Spine", Finish.ENAMEL)
	bend_into("Chest",1.04,1.28)
	cord([Vector3(.006,.889,-.171),Vector3(.006,.950,-.186),Vector3(.009,1.143,-.173),
		Vector3(.008,1.284,-.181),Vector3(.004,1.358,-.150)],.007,"top",DEEP)
	piece(Vector3(.006,1.295,-.185),Vector3(.012,.024,.006),"wood_light",ROLL,8)


func _arm(side: String, s: float, skate: bool) -> void:
	if skate:
		super._arm(side,s,true)
		return
	var x := s*.288
	part(side+"LowerArm",Finish.SLEEVE)
	bend_into(side+"UpperArm",1.11,1.24)
	piece(Vector3(x,1.187,-.002),Vector3(.110,.255,.124),"top",SLEEVE,18,
		Vector3(0,0,-s*2.0),Form.SLEEVE,Color.WHITE,.86)
	part(side+"LowerArm",Finish.ENAMEL)
	piece(Vector3(x+s*.004,.947,-.001),Vector3(.114,.033,.122),"trim",ROLL,18,
		Vector3(-3,0,-s*4),Form.PLAIN,Color(.92,.86,.91),.86)
	part(side+"Hand",Finish.CLAY)
	_hand(s)


func _hand(s: float) -> void:
	var start := vertices.size()
	super(s)
	# Open the relaxed thumb towards the viewer behind the shoulder. The
	# fitted vertices still come from the common five-centimetre bar grip.
	var sides := (vertices.size()-start)/HAND.size()
	for ring in 5:
		var shift := Vector3(-s*.023,-.011,.032)*(1.0-smoothstep(0,4,ring))
		for i in sides:
			var v := start+ring*sides+i
			vertices[v] += shift
			bind_data[v*4] = vertices[v].x
			bind_data[v*4+1] = vertices[v].y
			bind_data[v*4+2] = vertices[v].z
	for ring in range(1,5):
		for i in sides:
			var first := start+ring*sides
			var v := first+i
			var along := vertices[v+sides]-vertices[v-sides]
			var around := vertices[first+(i+1)%sides]-vertices[first+posmod(i-1,sides)]
			normals[v] = along.cross(around).normalized()


func _leg(side: String, s: float) -> void:
	var x := s*.132
	part(side+"LowerLeg",Finish.DENIM)
	bend_into(side+"UpperLeg",.43,.60)
	hip_joint = skeleton.find_bone("Hips")
	piece(Vector3(x,.584,.010),Vector3(.126,.342,.151),"legs",DENIM,20,
		Vector3.ZERO,Form.DENIM,Color(.82,.90,1),.77)
	x += .041*s
	part(side+"LowerLeg",Finish.SATIN)
	piece(Vector3(x,.259,.006),Vector3(.138,.032,.154),"trim",ROLL,16,
		Vector3(1,0,s*4),Form.PLAIN,Color(.74,.72,.94),.73)
	part(side+"Foot",Finish.BOOT)
	bend_into(side+"Toes",.076,.16,Vector3.FORWARD)
	piece(Vector3(x,.134,-.054),Vector3(.146,.112,.199),"boots",BOOT,20,
		Vector3.ZERO,Form.LEATHER,Color(1,.90,.85),.68)
	part(side+"Foot",Finish.SOLE)
	bend_into(side+"Toes",.076,.16,Vector3.FORWARD)
	piece(Vector3(x,.033,-.053),Vector3(.149,.030,.202),"boots",ROLL,18,
		Vector3.ZERO,Form.PLAIN,Color(.57,.49,.52),.67)
