extends RefCounted
## Stations are metres north along the decks. Each later station follows the preceding span.
const WIDTH := 5.0
const DECK_Y := 7.0
const Z_START := 22.0
const FIRST_LIP := 8.0
const BAR_DEPTH := 1.45
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
	bar = chain_land + 2.1
	lip = bar + BAR_DEPTH + 5.6
	clearance = float(data["bar_clearance_m"])
	angle = deg_to_rad(float(data["chute_degrees"]))
	foot = lip + DROP / tan(angle)
	finish = foot + 5.0
	checkpoints = [first_land + 2.5, bar + BAR_DEPTH + 1.0, finish]

	_place(TLKit.build("ground_patch", {"size_x": 16.0, "size_z": finish + 6.0, "thickness": 0.25, "surface": "dirt"}),
		point(finish / 2, YARD_Y))
	_place(TLKit.build("lumber", {"length": 4.0, "layers": 4}), point(first_land + 3, YARD_Y, -5.1))
	_place(TLKit.build("pallet", {"rows": 2}), point(3.0, YARD_Y, 5.2))
	_place(TLKit.build("barricade", {"width": 2.5}), point(finish + 1, YARD_Y, 3.8))
	_deck(-2, FIRST_LIP, DECK_Y)
	_deck(first_land, chain_lip, DECK_Y)
	_deck(chain_land, lip, DECK_Y)
	_deck(foot, finish + 2, 0)
	# The top face of the tilted kit slab meets both deck tops exactly.
	var slope := _place(TLKit.build("ground_patch", {"size_x": WIDTH, "size_z": DROP / sin(angle),
		"thickness": 0.32, "surface": "concrete"}), point((lip + foot) / 2, DECK_Y - DROP / 2))
	slope.rotation.x = -angle

	# Landing lines, take-off boards and finish stripe use the same painted kit kerb.
	for station: float in [0.0, FIRST_LIP - 0.45, first_land + 0.55, chain_lip - 0.45, chain_land + 0.55, lip - 0.45]:
		_stripe(station, DECK_Y)
	_stripe(finish, 0)
	for station: float in [0.0, first_land + 2.5, finish]:
		var height := 0.0 if station == finish else DECK_Y
		_place(TLKit.build("flag", {"height": 3.0, "color": "flag_a" if station == finish else "flag_b"}), point(station, height, -2.35))

	# A deep striped lintel overhangs each unsupported side by more than half a running jump.
	# Its side piers rise past jump height, right at the two edges of the landing.
	for x: float in [-WIDTH / 2, WIDTH / 2]:
		_place(TLKit.build("ground_patch", {"size_x": 1.0, "size_z": BAR_DEPTH, "thickness": clearance, "surface": "concrete"}),
			point(bar + BAR_DEPTH / 2, DECK_Y + clearance, x))
	_place(TLKit.build("ground_patch", {"size_x": WIDTH + 7.0, "size_z": BAR_DEPTH, "thickness": 0.50, "surface": "wood"}),
		point(bar + BAR_DEPTH / 2, DECK_Y + clearance + 0.50))
	_place(TLKit.build("kerb", {"length": WIDTH + 7.0, "width": BAR_DEPTH, "height": 0.14}),
		point(bar + BAR_DEPTH / 2, DECK_Y + clearance + 0.50, -(WIDTH + 7.0) / 2))
	# Left and right cheeks of the chute make its angle visible from the road.
	for x: float in [-2.45, 2.45]:
		var cheek := _place(TLKit.build("kerb", {"length": DROP / sin(angle), "width": 0.3, "height": 0.18}),
			point(lip, DECK_Y, x))
		cheek.basis = Basis(Vector3.RIGHT, -angle) * Basis(Vector3.UP, PI / 2)


func point(station: float, y: float, x: float = 0.0) -> Vector3:
	return Vector3(x, y, Z_START - station)


func _place(part: Node3D, at: Vector3) -> Node3D:
	part.position = at
	root.add_child(part)
	return part


func _deck(a: float, b: float, y: float) -> void:
	_place(TLKit.build("ground_patch", {"size_x": WIDTH, "size_z": b - a, "thickness": 0.34, "surface": "wood"}), point((a + b) / 2, y))
	if y < 1.0:
		_place(TLKit.build("ground_patch", {"size_x": WIDTH - 0.25, "size_z": b - a - 0.25, "thickness": y - YARD_Y - 0.3,
			"surface": "concrete"}), point((a + b) / 2, y - 0.3))
		return
	# Trestles cross the width of each deck. No trestle or apron bridges a gap.
	for station: float in [a + 1.35, b - 1.35]:
		_place(TLKit.build("scaffold", {"bays": 2, "bay_w": 2.2, "bay_d": 1.1, "levels": 3,
			"level_h": (y - YARD_Y - 1.34) / 3, "decks": [3]}), point(station - 0.55, YARD_Y, -2.2))


func _stripe(station: float, y: float) -> void:
	_place(TLKit.build("kerb", {"length": WIDTH - 0.15, "width": 0.30, "height": 0.03}), point(station, y, -(WIDTH - 0.15) / 2))
