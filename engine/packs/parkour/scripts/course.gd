extends RefCounted
## Stations increase eastward so the whole silhouette faces the village road.
const WIDTH := 5.0
const DECK_Y := 7.0
const START_X := -22.0
const FIRST_LIP := 8.0
const BAR_DEPTH := 0.68
const DROP := 7.0
const YARD_Y := -1.25

var root: Node3D
var first_land: float
var chain_lip: float
var chain_land: float
var bar: float
var lip: float
var foot: float
var finish: float
var clearance: float
var angle: float
var checkpoints: Array[float] = []


func build(parent: Node3D, data: Dictionary) -> void:
	root = parent
	for key: String in data:
		if key not in ["first_gap_m", "chain_gap_m", "bar_clearance_m", "chute_degrees"]:
			push_error("Unknown course key '%s'" % key)
	first_land = FIRST_LIP + float(data["first_gap_m"])
	chain_lip = first_land + 10.0
	chain_land = chain_lip + float(data["chain_gap_m"])
	bar = chain_land + 5.5 - BAR_DEPTH / 2
	lip = chain_land + 9.15
	clearance = float(data["bar_clearance_m"])
	angle = deg_to_rad(float(data["chute_degrees"]))
	foot = lip + DROP / tan(angle)
	finish = foot + 5.0
	checkpoints = [first_land + 2.5, chain_land + 0.65, bar + BAR_DEPTH / 2, finish]

	_deck(-2, FIRST_LIP, DECK_Y)
	_deck(first_land, chain_lip, DECK_Y)
	_deck(chain_land, lip, DECK_Y)
	_deck(foot, finish + 2, 0)
	var slope_length := DROP / sin(angle)
	var slope := _part("ground_patch", {"size_x": slope_length, "size_z": WIDTH,
		"thickness": 0.32, "surface": "concrete"}, (lip + foot) / 2, DECK_Y - DROP / 2)
	slope.rotation.z = -angle
	for side: float in [-1.0, 1.0]:
		var cheek := _part("kerb", {"length": slope_length, "width": 0.3, "height": 0.18},
			lip, DECK_Y, side * (WIDTH / 2 - 0.05))
		cheek.rotation.z = -angle
		for station: float in [0.0, checkpoints[0], finish]:
			if station == finish and side > 0:
				continue
			_part("flag", {"height": 3.0, "color": "flag_a" if station == finish else "flag_b"},
				station, 0.0 if station == finish else DECK_Y, side * (WIDTH / 2 + 0.12))
		# One short red kerb stood on end forms each jamb.
		var jamb := _part("kerb", {"length": maxf(clearance, 1.0), "width": BAR_DEPTH, "height": 0.27},
			bar + BAR_DEPTH / 2, DECK_Y + minf(clearance - 1.0, 0.0), side * (WIDTH / 2 - 0.2))
		jamb.basis = Basis(Vector3.UP, PI / 2) * Basis(Vector3.BACK, PI / 2)
	var beam := _part("kerb", {"length": WIDTH + 0.4, "width": BAR_DEPTH, "height": 0.48},
		bar + BAR_DEPTH / 2, DECK_Y + clearance, -(WIDTH + 0.4) / 2)
	beam.rotation.y = -PI / 2
	for station: float in [0.0, FIRST_LIP - 0.45, first_land + 0.55, chain_lip - 0.45, checkpoints[1], lip - 0.45]:
		_stripe(station, DECK_Y)
	_stripe(finish, 0)


func point(station: float, y: float, lateral: float = 0.0) -> Vector3:
	return Vector3(START_X + station, y, lateral)


func _part(kind: String, params: Dictionary, station: float, y: float, lateral: float = 0.0) -> Node3D:
	var part := TLKit.build(kind, params)
	part.position = point(station, y, lateral)
	root.add_child(part)
	return part


func _deck(a: float, b: float, y: float) -> void:
	_part("ground_patch", {"size_x": b - a, "size_z": WIDTH, "thickness": 0.34, "surface": "wood"}, (a + b) / 2, y)
	if y < 1.0:
		_part("ground_patch", {"size_x": b - a - 0.25, "size_z": WIDTH - 0.25, "thickness": y - YARD_Y - 0.3,
			"surface": "concrete"}, (a + b) / 2, y - 0.3)
		return
	# Scaffold galleries run along the deck edges. Their top rails stop at each jump.
	var bays := ceili((b - a) / 3.2)
	for lateral: float in [-WIDTH / 2 - 0.65, WIDTH / 2 - 0.15]:
		_part("scaffold", {"bays": bays, "bay_w": (b - a - 0.36) / bays, "bay_d": 0.8,
			"levels": 3, "level_h": (y - YARD_Y - 0.12) / 3, "decks": [2, 3]}, a + 0.18, YARD_Y, lateral)


func _stripe(station: float, y: float) -> void:
	var line := _part("kerb", {"length": WIDTH - 0.15, "width": 0.30, "height": 0.03},
		station, y, -(WIDTH - 0.15) / 2)
	line.rotation.y = -PI / 2
