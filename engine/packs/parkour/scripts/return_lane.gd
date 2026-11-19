extends RefCounted
## Return coordinates: +x runs west, +z is to the runner's right.
const HEIGHT := 1.6
const PIVOT_Y := 3.75
const ARM := 3.1
const PAD_X := 6.0
const PAD_LENGTH := 3.5
const PAD_WIDTH := 2.6
const CORNER_CENTER := Vector3(-0.65, HEIGHT, 0.3)
const CORNER_SIZE := Vector3(6.5, 0.48, 4.4)
const CONTACT_SKIN := 0.06
const PAD_YAW := 22.0
const BANK := 8.0
const WEIGHT_SIZE := Vector3(1.4, 1.05, 1.35)

const WALL_RUN := 3.6
const WALL_RISE := 3.2
const TIER_LENGTH := 3.4

const HEADWALL := 4.6
const RUNWAY_END := 10.2
const UPPER_WIDTH := 3.8
const FIRST_BAR := 11.5
const RED_RISE := 1.55
const LANDING_RUN := 3.9
const LANDING_RISE := 2.2

var summit_y: float
var rim_y: float
var ledge_rise: float
var first_bar_y: float
var second_bar: float
var landing_z: float
var landing_y: float

var root := Node3D.new()
var pads: Array[Node3D] = []
var pendulum := Node3D.new()
var weight_contact: TLTrigger
var pad_offsets: Array[float] = []
var second: float
var beam_start: float
var swing_x: float
var beam_end: float
var beam_width: float
var swing_angle: float
var swing_period_frames: int
var wall_base: float
var wall_lip: float
var crest: float
var crest_y: float
var tier_rise: float
var summit: float


func build(ctx: TLContext, origin: Vector3) -> void:
	var d: Dictionary = ctx.read_json("return.json")
	for key: String in d:
		if key not in ["pad_spacing_m", "pad_offsets_m", "beam_width_m", "beam_entry_offset_m", "swing_degrees", "swing_period_frames",
			"wall_crest_rise_m", "tower_step_rise_m"]:
			push_error("Unknown return course key '%s'" % key)
	pad_offsets.assign(d.pad_offsets_m)
	if pad_offsets.size() != 2:
		push_error("The return lane needs two pad offsets")
		return
	second = PAD_X + float(d.pad_spacing_m)
	beam_start = second + float(d.beam_entry_offset_m)
	swing_x = beam_start + 5.0
	beam_end = swing_x + 3.1
	beam_width = float(d.beam_width_m)
	swing_angle = deg_to_rad(float(d.swing_degrees))
	swing_period_frames = int(d.swing_period_frames)
	assert(swing_period_frames > 0, "Swing period must be positive")
	root.name = "ReturnLane"
	root.position = origin
	root.basis = Basis(Vector3.UP, PI)
	ctx.root.add_child(root)
	# The chute feeds a rising quarter-turn. The corner deck is long enough to take it at a run.
	var ramp := Vector2(5.3, HEIGHT)
	var bank := _slab(Vector3(-0.7, HEIGHT / 2, 4.65), Vector3(5.6, 0.35, ramp.length()), "concrete")
	bank.rotation.x = ramp.angle()
	_slab(CORNER_CENTER, CORNER_SIZE, "wood")
	for t: float in [-2.9, 1.5]:
		_pier(t, -0.85, HEIGHT - 0.48)
		_pier(t, 1.4, HEIGHT - 0.48)
	for i: int in 2:
		var side := 1.0 if i == 0 else -1.0
		var t := PAD_X if i == 0 else second
		var pad := _slab(Vector3(t, HEIGHT, pad_offsets[i]), Vector3(PAD_LENGTH, 0.42, PAD_WIDTH), "wood")
		pad.basis = Basis(Vector3.UP, deg_to_rad(side * PAD_YAW)) * Basis(Vector3.RIGHT, deg_to_rad(side * BANK))
		pads.append(pad)
		_part(pad, "kerb", {"length": PAD_WIDTH - 0.14, "width": 0.30, "height": 0.03},
			Vector3(PAD_LENGTH / 2 - 0.28, 0, -(PAD_WIDTH - 0.14) / 2)).rotation.y = -PI / 2
		_pier(t, pad_offsets[i], HEIGHT - 0.35)
	# Kerb starts at its near end; the red/white beam and its collision share the same part.
	_part(root, "kerb", {"length": beam_end - beam_start, "width": beam_width, "height": 0.40},
		Vector3(beam_start, HEIGHT - 0.4, 0))
	for t: float in [beam_start + 0.6, beam_end - 0.6]:
		_pier(t, 0, HEIGHT - 0.4)
	_slab(Vector3(beam_end + 2.3, HEIGHT, 0), Vector3(4.6, 0.42, 3.4), "wood")
	_pier(beam_end + 2.2, 0, HEIGHT - 0.42)
	# Hang the arm from one of the gable ties. Its four corner posts leave the swept volume open.
	_part(root, "timber_frame", {"width": 3.0, "depth": 6.8, "height": 5.82, "roof_rise": 0.95},
		Vector3(swing_x + 0.5, -1.25, 0))
	pendulum.position = Vector3(swing_x, HEIGHT + PIVOT_Y, 0)
	root.add_child(pendulum)
	_part(pendulum, "kerb", {"length": ARM, "width": 0.30, "height": 0.18}, Vector3.ZERO).rotation.z = -PI / 2
	for i: int in 3:
		var y := -ARM - WEIGHT_SIZE.y / 2 + i * WEIGHT_SIZE.y / 3
		if i == 1:
			_part(pendulum, "ground_patch", {"size_x": WEIGHT_SIZE.x, "size_z": WEIGHT_SIZE.z,
				"thickness": WEIGHT_SIZE.y / 3, "surface": "asphalt"}, Vector3(0, y + WEIGHT_SIZE.y / 3, 0))
		else:
			_part(pendulum, "kerb", {"length": WEIGHT_SIZE.x, "width": WEIGHT_SIZE.z, "height": WEIGHT_SIZE.y / 3},
				Vector3(-WEIGHT_SIZE.x / 2, y, 0))
	# A narrow contact skin registers brushing the weight even when the walker stops against its solid face.
	weight_contact = TLBodies.trigger(&"box", WEIGHT_SIZE + Vector3.ONE * (2.0 * CONTACT_SKIN), {
		"position": Vector3.DOWN * ARM, "name": "WeightContact", "group_filter": &"timber_runner"})
	pendulum.add_child(weight_contact)
	_cross_stripe(swing_x - 3.3, HEIGHT, beam_width)
	advance(0)
	_build_summit(float(d.wall_crest_rise_m), float(d.tower_step_rise_m))


func phase(frame: int) -> int:
	# The weight starts at its turning point.
	return (frame + roundi(swing_period_frames / 4.0)) % swing_period_frames


func advance(frame: int) -> void:
	pendulum.rotation.x = swing_angle * sin(TAU * float(phase(frame)) / swing_period_frames)


func local_feet(pack_feet: Vector3) -> Vector3:
	return root.transform.affine_inverse() * pack_feet


func pad_landing(i: int, feet: Vector3) -> bool:
	var p := pads[i].transform.affine_inverse() * feet
	return absf(p.x) <= PAD_LENGTH / 2 and absf(p.z) <= PAD_WIDTH / 2 and absf(p.y) < 0.22


func _part(parent: Node3D, kind: String, params: Dictionary, pos: Vector3) -> Node3D:
	var part := TLKit.build(kind, params)
	part.position = pos
	parent.add_child(part)
	return part


func _slab(pos: Vector3, dims: Vector3, surface: String) -> Node3D:
	return _part(root, "ground_patch", {"size_x": dims.x, "size_z": dims.z, "thickness": dims.y, "surface": surface}, pos)


func _pier(t: float, z: float, top: float) -> void:
	_slab(Vector3(t, top, z), Vector3(1, top + 1.25, 1), "concrete")


func _build_summit(crest_rise: float, step_rise: float) -> void:
	wall_base = beam_end + 3.0
	wall_lip = wall_base + WALL_RUN + 1.6
	crest = wall_lip + 2.90
	crest_y = HEIGHT + WALL_RISE + crest_rise
	tier_rise = step_rise
	summit = crest + TIER_LENGTH * 2 + 1.4
	var ramp := Vector2(WALL_RUN, WALL_RISE)
	var face := _slab(Vector3(wall_base + WALL_RUN / 2, HEIGHT + WALL_RISE / 2, 0),
		Vector3(ramp.length(), 0.42, 3.4), "concrete")
	face.rotation.z = ramp.angle()
	for side: float in [-1, 1]:
		_part(root, "kerb", {"length": ramp.length(), "width": 0.3, "height": 0.14},
			Vector3(wall_base, HEIGHT, side * 1.68)).rotation.z = ramp.angle()
	_slab(Vector3(wall_lip - 0.8, HEIGHT + WALL_RISE, 0), Vector3(1.6, 0.44, 3.4), "wood")
	_part(root, "scaffold", {"bays": 1, "bay_w": 1.3, "bay_d": 2.3, "levels": 2,
		"level_h": (HEIGHT + WALL_RISE + 1.25 - 1.05) / 2, "decks": [1, 2]},
		Vector3(wall_lip - 1.47, -1.25, -1.15))
	_cross_stripe(wall_lip - 0.3, HEIGHT + WALL_RISE, 3.2)
	# The tower has three playable terraces. Its steel bracing sits under the walking surface.
	for i: int in 3:
		var near := crest + i * TIER_LENGTH
		var top := crest_y + i * tier_rise
		var width := 4.4 - i * 0.40
		var frame_height := top + 1.25 - 1.1
		var levels := ceili(frame_height / 3)
		_part(root, "scaffold", {"bays": 1, "bay_w": TIER_LENGTH - 0.28, "bay_d": 2.7,
			"levels": levels, "level_h": frame_height / levels, "decks": range(1, levels + 1)}, Vector3(near + 0.14, -1.25, -1.35))
		_slab(Vector3(near + TIER_LENGTH / 2, top, 0), Vector3(TIER_LENGTH, 0.38, width), "wood")
		if i == 0:
			# Recess the concrete pier 0.82 m. The run-up lands on a thin timber nose without a handhold.
			_slab(Vector3(near + 1.36, top - 0.36, 0), Vector3(1.08, 3.9, width - 0.12), "concrete")
		_cross_stripe(summit if i == 2 else near + TIER_LENGTH - 0.55, top, width - 0.12)
		if i == 2:
			_part(root, "flag", {"height": 3.4, "color": "flag_a"}, Vector3(summit, top, -width / 2))


func _cross_stripe(t: float, top: float, width: float) -> void:
	_part(root, "kerb", {"length": width, "width": 0.3, "height": 0.03},
		Vector3(t, top, -width / 2)).rotation.y = -PI / 2

func build_skyline(ctx: TLContext) -> void:
	var data: Dictionary = ctx.read_json("upper.json")
	for key: String in data:
		if key not in ["ledge_rise_m", "first_bar_rise_m", "bar_spacing_m", "landing_gap_m"]:
			push_error("Unknown upper course key '%s'" % key)
	ledge_rise = float(data.ledge_rise_m)
	summit_y = crest_y + 2 * tier_rise
	rim_y = summit_y + ledge_rise
	first_bar_y = rim_y + float(data.first_bar_rise_m)
	second_bar = FIRST_BAR + float(data.bar_spacing_m)
	landing_z = second_bar + float(data.landing_gap_m)
	landing_y = rim_y + 1.48
	# A quarter turn at the summit sends the runner across the outgoing high line.
	_upper_deck(1.8, HEADWALL + 0.2, summit_y, 0.34, "wood")
	_upper_deck(HEADWALL, HEADWALL + 1.0, rim_y, ledge_rise + 0.35, "concrete")
	_upper_deck(HEADWALL + 1.0, RUNWAY_END, rim_y, 0.36, "wood")
	for side: float in [-1, 1]:
		_part(root, "kerb", {"length": 1.0, "width": 0.3, "height": 0.03},
			Vector3(summit + (-UPPER_WIDTH / 2 if side < 0 else UPPER_WIDTH / 2 - 1.0), rim_y, RUNWAY_END - 0.85))
		var x := summit + side * (UPPER_WIDTH / 2 - 0.13)
		var height := summit_y - 0.35 + 1.25
		var sections := ceili(height / 5.0)
		for j: int in sections:
			var depth := height / sections
			_slab(Vector3(x, -1.25 + (j + 1) * depth, HEADWALL + 0.48), Vector3(1, depth, 1), "concrete")
		_part(root, "kerb", {"length": ledge_rise, "width": 0.30, "height": 0.08},
			Vector3(x, summit_y, HEADWALL - 0.02)).rotation.z = PI / 2

	# These longitudinal steel ribs rise from plinths at either end of the gap.
	# Their crowns carry the rods. The lower high-line deck remains clear beneath them.
	for side: float in [-1, 1]:
		var x := summit + side * 1.76
		_part(root, "arch_rib", {"span": 7.7, "apex": 15.95, "exponent": 2.65, "footings": false},
			Vector3(x, -1.25, 14.7)).scale.x = 0.45
		for station: float in [7.0, 22.4]:
			_slab(Vector3(x, -0.66, station), Vector3(1.0, 0.65, 1.0), "concrete")
	_build_grip(FIRST_BAR, first_bar_y, "flag_b")
	_build_grip(second_bar, first_bar_y + RED_RISE, "flag_a")
	_part(root, "scaffold", {"bays": 1, "bay_w": 2.8, "bay_d": 2.8, "levels": 5,
		"level_h": (landing_y + 1.25 - 1.1) / 5, "decks": [1, 3, 5]}, Vector3(summit - 1.4, -1.25, landing_z + 0.5))
	# Two crossheads bear the inclined decking on the scaffold's level top platform.
	for d: float in [0.8, 3.0]:
		var cap := landing_height(d - 0.40) - 0.45
		_slab(Vector3(summit, cap, landing_z + d), Vector3(2.9, cap - (landing_y - 1.0), 1.0), "concrete")
	var ramp := Vector2(LANDING_RUN, LANDING_RISE)
	_slab(Vector3(summit, landing_y + LANDING_RISE / 2, landing_z + LANDING_RUN / 2),
		Vector3(UPPER_WIDTH, 0.42, ramp.length()), "wood").rotation.x = -ramp.angle()
	_part(root, "kerb", {"length": UPPER_WIDTH - 0.1, "width": 0.30, "height": 0.03},
		Vector3(summit - UPPER_WIDTH / 2 + 0.05, landing_height(1.0), landing_z + 1.0)).rotation.x = -ramp.angle()
	for side: float in [-1, 1]:
		_part(root, "flag", {"height": 2.6, "color": "flag_a"}, Vector3(summit + side * 1.8, landing_height(1.6), landing_z + 1.6))


func landing_height(distance: float) -> float:
	return landing_y + LANDING_RISE * distance / LANDING_RUN


func _build_grip(station: float, height: float, color: String) -> void:
	var span := 3.8
	var rod := _part(root, "flag", {"height": span, "color": color}, Vector3(summit + span / 2, height, station))
	rod.rotation.z = PI / 2
	TLBiped.mark_bar(rod.get_node("Body") as StaticBody3D)


func _upper_deck(start: float, end: float, top: float, depth: float, surface: String) -> void:
	_slab(Vector3(summit, top, (start + end) / 2), Vector3(UPPER_WIDTH, depth, end - start), surface)
