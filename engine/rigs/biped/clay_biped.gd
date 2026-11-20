extends "res://rigs/biped/clay_form.gd"
## The diorama biped. All positions are in the existing skeleton's bind space.
## Its large pieces have distinct profiles; small pressings are spaced to read in a chase view.
const Contact = preload("res://rigs/biped/clay_motion.gd")

const COAT := [Vector2(-1,.87), Vector2(-.96,.98), Vector2(-.83,1), Vector2(-.47,.94),
	Vector2(.02,.86), Vector2(.42,.94), Vector2(.68,.99), Vector2(.86,.87), Vector2(1,.59)]
const COLLAR := [Vector2(-1,.66), Vector2(-.85,.88), Vector2(-.29,1),
	Vector2(.37,1.02), Vector2(.78,.94), Vector2(1,.76)]
const SLEEVE := [Vector2(-1,.72), Vector2(-.89,.94), Vector2(-.52,1), Vector2(-.22,.96), Vector2(.05,1), Vector2(.24,.96),
	Vector2(.68,.92), Vector2(.92,.68), Vector2(1,.27)]
const DENIM := [Vector2(-1,.78), Vector2(-.88,.96), Vector2(-.57,.88), Vector2(-.19,.90),
	Vector2(-.07,.96), Vector2(.14,.91), Vector2(.47,1), Vector2(.78,1.01), Vector2(1,.86)]
const BOOT := [Vector2(-1,.89), Vector2(-.64,1.035), Vector2(-.53,1.06), Vector2(-.45,.978),
	Vector2(.02,.96), Vector2(.56,.84), Vector2(1,.57)]
const BAG := [Vector2(-1,.60), Vector2(-.80,.91), Vector2(-.35,1.03), Vector2(.21,.96),
	Vector2(.71,.88), Vector2(1,.72)]
const DEEP := Color(.76,.70,.68)
const SHADE := Color(.88,.84,.82)
const COPPER := Color(.95,.73,.49)
const CREAM := Color(1,.93,.80)
# Cross sections from thumb tip, through the heel of the palm, to the curled
# fingertips. The open centre sits on the same grip point used by the arm IK.
# Each row gives the position in the palm plane and the two section radii.
const HAND := [
	Vector4(-.032,-.035,0,0), Vector4(-.048,-.028,.021,.035),
	Vector4(-.060,-.005,.031,.045), Vector4(-.061,.024,.037,.051),
	Vector4(-.041,.052,.043,.057), Vector4(-.005,.059,.053,.069),
	Vector4(.032,.044,.053,.077), Vector4(.049,.014,.047,.079),
	Vector4(.050,-.020,.048,.080), Vector4(.038,-.045,.047,.077),
	Vector4(.013,-.061,.043,.071), Vector4(-.010,-.061,.035,.061),
	Vector4(-.025,-.053,.024,.043), Vector4(-.026,-.041,0,0)]


func sculpt(sk: Skeleton3D, colors: Dictionary, pack: bool, helmet: bool, skate: bool) -> void:
	skeleton = sk
	look = colors
	_jacket(skate)
	for sign_x: float in [-1.0, 1.0]:
		var side := "Left" if sign_x < 0.0 else "Right"
		_leg(side, sign_x)
		_arm(side, sign_x, skate)
	_sculpt_face(helmet)
	if helmet:
		_helmet()
	else:
		_hair()
	if pack:
		_satchel()


func _jacket(team: bool) -> void:
	part("Hips", Finish.ENAMEL if team else Finish.JACKET, .78)
	bend_into("Chest", .94, 1.30)
	var coat_y := 1.119 if team else 1.151
	var coat_half := .311 if team else .269
	piece(Vector3(0,coat_y,.009), Vector3(.28,coat_half,.189), "top", COAT, 32, Vector3.ZERO, Form.COAT)
	part("Chest", Finish.CLAY)
	piece(Vector3(0,1.445,-.004), Vector3(.121,.105,.126), "skin", EGG, 14)
	# A rolled stand collar with a lower front and a shadow at the neck.
	part("Backpack", Finish.ENAMEL, .31)
	if team:
		piece(Vector3(0,1.418,0), Vector3(.202,.044,.155), "trim", ROLL, 20, Vector3(6,0,0), Form.KNIT)
	else:
		piece(Vector3(0,1.408,.003), Vector3(.285,.068,.211), "top", COLLAR, 32, Vector3(0,-6,-3), Form.COLLAR)
		part("Spine", Finish.ENAMEL)
		bend_into("Chest", 1.06, 1.30)
		# Slight overlap of the two fronts, small brass press studs and two welt pockets.
		cord([Vector3(.013,.895,-.169), Vector3(.018,.973,-.175), Vector3(.014,1.14,-.158),
			Vector3(.021,1.29,-.180), Vector3(.017,1.38,-.150)], .012, "top", DEEP)
		for yz: Vector2 in [Vector2(.962,-.177), Vector2(1.098,-.165), Vector2(1.24,-.173), Vector2(1.350,-.166)]:
			piece(Vector3(.022,yz.x,yz.y-.006), Vector3(.013,.013,.007), "wood_light", BEAD, 6, Vector3.ZERO, Form.PLAIN, COPPER)
		for side: float in [-1.0,1.0]:
			cord([Vector3(side*.133,.952,-.158),Vector3(side*.162,.992,-.147),Vector3(side*.194,1.034,-.127)], .014, "top", SHADE)
	if team:
		part("Spine")
		piece(Vector3(0,.928,0), Vector3(.278,.030,.182), "white", ROLL, 20, Vector3.ZERO, Form.COAT, CREAM)
		part("Chest")
		# A moulded seven on the jersey, seen over the shoulder in chase view.
		cord([Vector3(-.058,1.30,.175),Vector3(-.006,1.303,.181),Vector3(.058,1.30,.175)], .017,"white")
		cord([Vector3(.051,1.296,.176),Vector3(.018,1.25,.18),Vector3(-.028,1.17,.165)], .016,"white")


func _arm(side: String, s: float, skate: bool) -> void:
	var x := s * .29
	part(side + "LowerArm", Finish.ENAMEL if skate else Finish.SLEEVE, .68)
	bend_into(side + "UpperArm", 1.13, 1.22)
	# One sleeve per arm. The bend stays covered as the hand rises.
	piece(Vector3(x,1.206,-.002), Vector3(.116,.261,.124), "top", SLEEVE, 16, Vector3(0,0,-s*1.5), Form.SLEEVE)
	part(side + "LowerArm", Finish.ENAMEL, .66)
	piece(Vector3(x+s*.005,.954,-.001), Vector3(.111,.030,.117), "trim", ROLL, 16, Vector3(-3,0,-s*4), Form.KNIT)
	if not skate:
		part(side + "LowerArm", Finish.SLEEVE, .70)
		piece(Vector3(x+s*.005,.984,-.001), Vector3(.119,.034,.125), "top", ROLL, 16, Vector3(-3,0,-s*4), Form.KNIT)
	part(side + "Hand", Finish.CLAY)
	if skate:
		piece(Vector3(x,.856,-.019), Vector3(.100,.120,.094), "boots", EGG, 14, Vector3(-8,0,-s*7))
		piece(Vector3(x-s*.071,.871,-.069), Vector3(.044,.072,.047), "boots", BEAD, 12, Vector3(22,0,s*18), Form.PLAIN, SHADE)
		part(side + "Hand", Finish.ENAMEL)
		piece(Vector3(x+s*.045,.862,.03), Vector3(.067,.084,.054), "top", ROLL, 12, Vector3(-9,0,-s*8))
	else:
		_hand(s)


func _hand(side: float) -> void:
	const SIDES := 12
	var wrist := skeleton.get_bone_global_rest(bone).origin
	var grip := wrist + Contact.PALM
	var across := Contact.palm_width(side)
	var depth := Contact.palm_axis(side)
	var first := vertices.size()
	var skin := TLStyle.index(look["skin"])
	for j in HAND.size():
		var row: Vector4 = HAND[j]
		var step: Vector4 = HAND[mini(j+1,HAND.size()-1)] - HAND[maxi(j-1,0)]
		var tangent := (across*step.x + Vector3.UP*step.y).normalized()
		var radial := tangent.cross(depth)
		var center := across*row.x + Vector3.UP*row.y
		var outward := center.normalized()
		var rim_sign := signf(radial.dot(outward))
		for i in SIDES:
			var angle := TAU*i/SIDES
			var rim := radial*cos(angle)
			var span := depth*sin(angle)
			var point := center + rim*row.z + span*row.w
			var normal := (row.w*rim + row.z*span).normalized()
			if j == 0 or j == HAND.size()-1:
				normal = -tangent if j == 0 else tangent
			# A little pigment gathers in the channel between thumb and fingers.
			var shade := lerpf(.72,1.0,smoothstep(.013,.060,point.length()))
			_vertex(grip+point,Color(shade,shade,shade),0.0,skin)
			normals[normals.size()-1] = normal
			# Let the soft inside of the hand yield to the 5 cm bar.
			# Preserve the knuckles and the connection to the sleeve.
			var layer := .65*row.z*(1.0+cos(angle)*rim_sign)
			grip_points[vertices.size()-1] = grip + outward*(.055+layer) + span*row.w
			if j > 0:
				var lo := first + (j-1)*SIDES
				var k := (i+1)%SIDES
				if j > 1:
					indices.append_array(PackedInt32Array([lo+i,lo+k,lo+i+SIDES]))
				if j < HAND.size()-1:
					indices.append_array(PackedInt32Array([lo+k,lo+k+SIDES,lo+i+SIDES]))
	for j in HAND.size():
		for i in SIDES:
			var n := first+j*SIDES+i
			if j == 0 or j == HAND.size()-1:
				grip_normals[n] = normals[n]
			else:
				var along := grip_points[n+SIDES]-grip_points[n-SIDES]
				var around := grip_points[first+j*SIDES+(i+1)%SIDES]-grip_points[first+j*SIDES+posmod(i-1,SIDES)]
				grip_normals[n] = along.cross(around).normalized()
	tri_count = indices.size()/3


func _leg(side: String, s: float) -> void:
	var x := s * .132
	part(side + "LowerLeg", Finish.DENIM, .50)
	bend_into(side + "UpperLeg", .43, .60)
	hip_joint = skeleton.find_bone("Hips")
	piece(Vector3(x,.582,.009), Vector3(.131,.349,.147), "legs", DENIM, 24, Vector3.ZERO, Form.DENIM, Color.WHITE, .9)
	# Unbleached turn-up below the pressed knee fold.
	x += .032*s
	part(side + "LowerLeg", Finish.SATIN, .62)
	piece(Vector3(x,.27,.005), Vector3(.137,.043,.143), "trim", ROLL, 16, Vector3(2,0,s*6), Form.KNIT, CREAM, .90)
	# One rounded shoe, including the welt. Its front rolls from the toe pivot.
	part(side + "Foot", Finish.BOOT, .82)
	bend_into(side + "Toes", .076, .16, Vector3.FORWARD)
	piece(Vector3(x,.143,-.052), Vector3(.147,.120,.187), "boots", BOOT, 22, Vector3.ZERO, Form.LEATHER, Color.WHITE, .86)
	part(side + "Foot", Finish.SOLE, .54)
	bend_into(side + "Toes", .076, .16, Vector3.FORWARD)
	piece(Vector3(x,.034,-.049), Vector3(.156,.033,.196), "boots", ROLL, 22, Vector3.ZERO, Form.PLAIN, DEEP, .84)
	# Small pull loop and two rolled laces, set into the instep.
	piece(Vector3(x+.014*s,.218,.096), Vector3(.027,.055,.017), "boots", ROLL, 8, Vector3(12,0,s*9), Form.PLAIN, SHADE)
	cord([Vector3(x-.059,.192,-.177),Vector3(x-.018,.201,-.179),Vector3(x+.020,.204,-.177),Vector3(x+.056,.197,-.163)], .010,"wood", SHADE)
	cord([Vector3(x-.053,.217,-.146),Vector3(x-.012,.222,-.145),Vector3(x+.027,.220,-.148),Vector3(x+.050,.217,-.141)], .009,"wood", SHADE)

func _sculpt_face(helmet: bool) -> void:
	part("Head", Finish.CLAY)
	piece(Vector3(0,1.70,-.014), Vector3(.302,.278,.265), "skin", EGG, 28)
	for s: float in [-1.0,1.0]:
		part("Head", Finish.CLAY)
		# The bare lobe peeks out from the nape. A helmet cups it against the head.
		var ear := Vector3(s*.289,1.665,.002) if helmet else Vector3(s*.309,1.657,.044)
		var size := Vector3(.056,.081,.064) if helmet else Vector3(.064,.091,.075)
		piece(ear, size, "skin", EGG, 14, Vector3(16,-s*12,-s*15))
		var bowl := Vector3(s*.036,.002,-.025) if helmet else Vector3(s*.043,.009,.013)
		piece(ear+bowl, Vector3(.020,.045,.031), "skin", BEAD, 8, Vector3(13,-s*15,-s*16), Form.PLAIN, Color(.92,.70,.63))
		part("LeftEye" if s < 0.0 else "RightEye", Finish.GLOSS)
		piece(Vector3(s*.106,1.737,-.264), Vector3(.031,.042,.015), "black", EGG, 14, Vector3(0,-s*18,-s*4), Form.PLAIN, DEEP)
		part("Glints", Finish.SATIN)
		piece(Vector3(s*.105-.006,1.75,-.276), Vector3(.008,.010,.005), "white", BEAD, 8)
		part("Brows", Finish.HAIR)
		cord([Vector3(s*.069,1.799,-.251),Vector3(s*.097,1.81,-.244),Vector3(s*.133,1.81,-.230),Vector3(s*.149,1.802,-.223)], .012,"hair", DEEP)
	part("Head", Finish.CLAY)
	_nose()
	part("MouthCorners", Finish.CLAY)
	cord([Vector3(-.058,1.634,-.261),Vector3(-.034,1.618,-.270),Vector3(-.004,1.612,-.270),
		Vector3(.028,1.620,-.272),Vector3(.057,1.639,-.266)], .009, "hair", DEEP)


func _nose() -> void:
	piece(Vector3(0,1.688,-.274), Vector3(.041,.035,.036), "skin", EGG, 14, Vector3.ZERO, Form.PLAIN, Color(1,.91,.82))


func _hair() -> void:
	# The scalp sits on the head. Only the crown and forelock have secondary motion.
	part("Head", Finish.HAIR)
	piece(Vector3(0,1.798,.020), Vector3(.347,.184,.291), "hair", DOME, 40, Vector3(0,-4,0), Form.HAIRLINE, Color(1,.98,.94))
	for s: float in [-1.0,1.0]:
		piece(Vector3(s*.27,1.769,-.081), Vector3(.048,.089,.081), "hair", TIP, 14, Vector3(19,-s*17,s*13), Form.LOCK, SHADE)
	# A low sweep from one temple melts into the nape.
	piece(Vector3(-.222,1.792,.178), Vector3(.078,.153,.062), "hair", TIP, 16, Vector3(-24,21,-28), Form.LOCK)
	part("Hair", Finish.HAIR)
	piece(Vector3(.097,1.998,.072), Vector3(.147,.089,.120), "hair", EGG, 18, Vector3(18,-27,-31), Form.LOCK, Color(1,.95,.90))
	piece(Vector3(-.103,1.936,.185), Vector3(.132,.128,.098), "hair", CURL, 24, Vector3(64,-18,22), Form.CURL)
	piece(Vector3(.034,1.914,-.153), Vector3(.156,.079,.122), "hair", TIP, 16, Vector3(-26,-13,-62), Form.LOCK, Color(1,.97,.93))
	# A flat thumb-swept fringe flows down one temple.
	piece(Vector3(-.142,1.853,-.201), Vector3(.076,.113,.064), "hair", TIP, 16, Vector3(-14,17,-47), Form.LOCK)


func _helmet() -> void:
	part("Head", Finish.HAIR)
	piece(Vector3(0,1.717,.173), Vector3(.245,.101,.098), "hair", EGG, 16, Vector3(0,0,-2), Form.PLAIN, SHADE)
	part("Head", Finish.HELMET, .35)
	piece(Vector3(0,1.858,.013), Vector3(.324,.166,.283), "top", DOME, 32)
	part("Head", Finish.ENAMEL)
	piece(Vector3(0,1.801,-.157), Vector3(.300,.031,.181), "top", ROLL, 20, Vector3(-5,0,0), Form.PLAIN, SHADE)
	for s: float in [-1.0,1.0]:
		piece(Vector3(s*.295,1.721,.009), Vector3(.049,.095,.095), "top", ROLL, 16, Vector3(6,0,-s*10))
		piece(Vector3(s*.337,1.731,.010), Vector3(.009,.029,.031), "trim", BEAD, 8, Vector3.ZERO, Form.PLAIN, SHADE)


func _satchel() -> void:
	part("Chest", Finish.SATIN)
	bend_into("Backpack",.14,.23,Vector3.BACK)
	for s: float in [-1.0,1.0]:
		cord([Vector3(.012+s*.153,1.048,.249),Vector3(s*.229,1.040,.150),
			Vector3(s*.260,1.043,.034),Vector3(s*.202,1.055,-.120),
			Vector3(s*.167,1.20,-.151),Vector3(s*.161,1.35,-.157),Vector3(s*.17,1.420,-.079),
			Vector3(s*.166,1.424,.043),Vector3(s*.154,1.365,.146),Vector3(s*.132,1.248,.206)], .034, "strap", Color.WHITE, true)
	part("Backpack", Finish.SATIN, .57)
	piece(Vector3(.012,1.117,.222), Vector3(.180,.145,.100), "pack", BAG, 18, Vector3(0,0,-6), Form.PLAIN, Color.WHITE, .80)
	piece(Vector3(.017,1.177,.247), Vector3(.184,.086,.093), "pack", ROLL, 18, Vector3(-9,0,-6), Form.FLAP, SHADE, .80)
	piece(Vector3(.035,1.117,.344), Vector3(.023,.073,.010), "strap", ROLL, 8, Vector3(13,0,-6))
	cord([Vector3(.010,1.117,.356), Vector3(.011,1.135,.359), Vector3(.056,1.132,.360),
		Vector3(.057,1.109,.356),Vector3(.012,1.112,.355),Vector3(.010,1.121,.357)], .0065, "wood_light", COPPER)
	piece(Vector3(.035,1.124,.363), Vector3(.005,.017,.005), "wood_light", BEAD, 8, Vector3.ZERO, Form.PLAIN, COPPER)


## A tapered roll of clay pressed along a path (mouth, piping, stripes).
func cord(path: Array, radius: float, key: String, tint: Color = Color.WHITE, strap := false) -> void:
	const STRAP_EDGE := [Vector2(1,0),Vector2(.82,1),Vector2(-.82,1),Vector2(-1,0),Vector2(-.82,-1),Vector2(.82,-1)]
	var sides := STRAP_EDGE.size() if strap else 8
	var first := vertices.size()
	var palette_id := TLStyle.index(look.get(key,key))
	for j in path.size():
		var tangent: Vector3 = (path[mini(j+1,path.size()-1)] - path[maxi(j-1,0)]).normalized()
		var ref := Vector3.UP if absf(tangent.y) < .88 else Vector3.RIGHT
		# Parallel transport the section so a curve does not twist at a steep bend.
		if strap:
			ref = Vector3.RIGHT # the broad face crosses the shoulder
		elif j > 0:
			ref = normals[first + (j-1) * sides]
		var a := (ref - tangent * tangent.dot(ref)).normalized()
		var b := a.cross(tangent)
		var r := radius * (.26 if j == 0 or j == path.size()-1 else 1.0)
		for i in sides:
			var angle := TAU * i / sides
			var normal := a * cos(angle) + b * sin(angle)
			var offset := r*normal
			var color := tint
			if strap:
				var section: Vector2 = STRAP_EDGE[i]
				offset = r*(a*section.x + b*.34*section.y)
				normal = (a*section.x + b*2.5*section.y).normalized()
				if section.y == 0:
					color = Color(1.0,.88,.72) # burnished cut edge of the leather
			_vertex(path[j] + offset, color, 0.0, palette_id)
			normals[normals.size()-1] = normal
			if j > 0:
				var lo := first + (j-1) * sides
				var k := (i+1) % sides
				indices.append_array(PackedInt32Array([lo+i,lo+k,lo+i+sides,lo+k,lo+k+sides,lo+i+sides]))
	tri_count = indices.size()/3
