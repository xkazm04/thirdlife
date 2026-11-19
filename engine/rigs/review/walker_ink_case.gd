extends SceneTree
## Headless CPU check of the ink shader's inner and wide depth profiles. Evaluate its actual
## scalar assignments with Godot Expression so reverting the shader also reverts the test result.
## Inputs stand in for texture samples. Rendering and AA need the windowed probe.

const CORE := ["fp", "fm", "background_gap", "core"]
const CREST := ["crest_jump", "crest_slope", "crest"]
const OUTER := ["outer", "wide_jump", "wide_slope", "wide_crest"]
var assignments: Array[Array] = []

func _initialize() -> void:
	var shader := load("res://style/shaders/ink_post.gdshader") as Shader
	if shader == null:
		quit(1)
		return
	for raw: String in shader.code.split("\n"):
		var line := raw.strip_edges().trim_prefix("float ")
		var sides := line.split(" = ", true, 1)
		if sides.size() == 2 and (sides[0] in CORE or sides[0] in CREST or sides[0] in OUTER):
			assignments.append([sides[0], sides[1].get_slice(";", 0)])
	# depth in metres, centre at 8.5 m, grazing factor 0.1. Roughness 0.5 marks a rig.
	var cases := [
		["wall to the right", 1.0, 8.5, 0.5, 9.0, 1.0, 1.0],
		["wall to the left", 1.0, 9.0, 1.0, 8.5, 0.5, 1.0],
		["grazing ground", 0.0, 8.0, 1.0, 9.0, 1.0, 0.0],
		["two body samples", 1.0, 8.5, 0.5, 9.0, 0.5, 0.0],
		["wall in front", 1.0, 8.0, 1.0, 8.5, 0.5, 0.0],
		["touching ground", 1.0, 8.51, 1.0, 8.5, 0.5, 0.0],
		["distant backdrop", 0.0, 8.5, 1.0, 18.0, 1.0, 1.0],
	]
	var errors := 0
	for c: Array in cases:
		var state := {"body": c[1], "dbp": c[2], "np": Color(0, 0, 0, c[3]),
			"dbm": c[4], "nm": Color(0, 0, 0, c[5]), "d0": 8.5, "inv_d": 0.1 / 8.5}
		if not _evaluate(state, CORE):
			quit(1)
			return
		if not is_equal_approx(float(state.get("core", -1.0)), float(c[6])):
			print("ink case ", c[0], " expected ", c[6], " got ", state.get("core"))
			errors += 1
	# One vertical pair of terrain taps. Inverse depth advances linearly along the
	# projected grazing plane (centre 20 m). The cliff sample has a 10% gap above.
	# Opacity after the 0.96 line multiplier. A small gap on the ramp still covers
	# its pixel, and a large gap saturates at the lighter crest tone.
	var land_cases := [["close terrain crest", 22.0, 19.98, 0.5, 0.55],
		["shallow crest on the ramp", 20.37, 19.98, 0.5, 0.55],
		["perspective plane", 20.0 / 0.95, 20.0 / 1.05, 0.0, 0.0],
		["rising foreground", 19.0, 20.02, 0.0, 0.0]]
	for c: Array in land_cases:
		var state := {"d0": 20.0, "dbm": c[1], "dbp": c[2], "centre_depth": 20.0,
			"vertical_taps": Vector4(c[2], c[1], 0.9, 0.9), "crest": 0.0}
		if not _evaluate(state, CREST):
			quit(1)
			return
		var opacity := float(state.crest) * 0.96
		if opacity < c[3] or opacity > c[4]:
			print("ink case ", c[0], " expected opacity in [", c[3], ", ", c[4], "] got ", opacity)
			errors += 1
	# No inner crest. One wide tap gives a faint brush flank. Keep it at a ridge,
	# clear it on a plane with equal and opposite reciprocal-depth changes.
	var brush_cases := [
		["strong terrain silhouette", 1.0, 3.0, Vector2(20.0, 20.0), 1.0],
		["wide terrain crest flank", 0.0, 1.0, Vector2(19.98, 30.0), smoothstep(0.0, 2.6, 1.0)],
		["wide grazing plane flank", 0.0, 1.0, Vector2(20.0 / 1.3, 20.0 / 0.7), 0.0],
	]
	for c: Array in brush_cases:
		var state := {"core": c[1], "cnt": c[2], "d0": 20.0, "wide_depth": c[3],
			"hair": 0.0, "hair_alpha": 0.8, "thin_b": 0.0, "thin_tone": 0.55,
			"flat_k": 0.0, "tk": 0.0, "crest": 0.0}
		if not _evaluate(state, OUTER):
			quit(1)
			return
		if not is_equal_approx(float(state.get("outer", -1.0)), float(c[4])):
			print("ink case ", c[0], " expected ", c[4], " got ", state.get("outer"))
			errors += 1
	print("INK_CORE completed=%d failed=%d" % [cases.size() + land_cases.size() + brush_cases.size(), errors])
	quit(1 if errors else 0)


func _evaluate(state: Dictionary, targets: Array) -> bool:
	for assignment: Array in assignments:
		if assignment[0] not in targets:
			continue
		var expression := Expression.new()
		if expression.parse(assignment[1], PackedStringArray(state.keys())) != OK:
			print("cannot evaluate ink assignment ", assignment, ": ", expression.get_error_text())
			return false
		var value: Variant = expression.execute(state.values(), self)
		if expression.has_execute_failed() or typeof(value) not in [TYPE_FLOAT, TYPE_INT]:
			print("ink expression failed: ", assignment)
			return false
		state[assignment[0]] = value
	return true


## GLSL step(edge, x) for Expression.
func step(edge: float, x: float) -> float:
	return 1.0 if x >= edge else 0.0


func mix(a: float, b: float, weight: float) -> float:
	return lerpf(a, b, weight)
