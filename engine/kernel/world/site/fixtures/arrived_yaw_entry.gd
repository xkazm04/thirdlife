extends SceneTree

const Tiers := preload("res://kernel/world/tiers.gd")
const Site := preload("res://kernel/world/site.gd")


func _initialize() -> void:
	var cfg: Dictionary = Tiers.load_config("res://kernel/world/tiers.json").cfg
	cfg.adjacent_gap_m = 1.5
	cfg.sideline_m = 0.1
	var origin := Vector3(38, 2, -17)
	for degrees: float in [30.0, -30.0, 0.0]:
		var plot := {"id": "rink", "origin": origin, "size": Vector2(40, 12), "yaw": degrees}
		# Markers in the actual 3D plot frame, independent of the scheduler's inverse 2D projection.
		var frame := Transform3D(Basis(Vector3.UP, deg_to_rad(degrees)), origin)
		var inside: Vector3 = frame * Vector3(18, 0, 5.9)
		var outside: Vector3 = frame * Vector3(20.5, 0, 1)
		var neighbour := {"id": "near", "origin": frame * Vector3(23, 0, 0), "size": Vector2(4, 2), "yaw": degrees}
		var sched := Tiers.new()
		sched.setup(cfg, [plot, neighbour])
		assert(is_zero_approx(sched.distance(plot, inside)))
		assert(is_equal_approx(sched.distance(plot, outside), 0.5))
		assert(is_equal_approx(sched._gap(plot, neighbour), 1.0))
		var corner := neighbour.duplicate()
		corner.origin = frame * Vector3(25, 0, 11)
		assert(is_equal_approx(sched._gap(corner, plot), 5.0)) # 3-by-4 corner separation
		corner.origin = origin
		assert(is_zero_approx(sched._gap(plot, corner))) # containment
		corner.size = Vector2(50, 2)
		corner.yaw = degrees + 90.0
		assert(is_zero_approx(sched._gap(plot, corner))) # crossing edges, no enclosed corners
		if degrees != 0.0:
			var tip := frame * Vector3(20, 0, 6 * signf(degrees))
			var upright := {"origin": tip + Vector3(2, 0, 0), "size": Vector2(2, 4), "yaw": 0.0}
			assert(is_equal_approx(sched._gap(plot, upright), 1.0))
			assert(is_equal_approx(sched._gap(upright, plot), 1.0))
			# At these centres an axis-aligned pair would miss the adjacency threshold.
			var flat := neighbour.duplicate()
			flat.yaw = 0.0
			var flat_plot := plot.duplicate()
			flat_plot.yaw = 0.0
			assert(sched._gap(flat_plot, flat) > cfg.adjacent_gap_m)
		sched.visitor = true
		sched.plots[0].size = Site.HELD_SIZE
		sched.request("enter")
		sched.decide(0, inside)
		assert(sched.stage == -1)
		sched.plots[0].size = plot.size
		sched.request("enter")
		var events := sched.decide(1, inside)
		assert(sched.stage == 0 and sched.plots[1].tier == "sideline")
		assert(events.has({"t": 1, "e": "tier", "plot": "rink", "from": "backdrop", "to": "stage", "why": "enter"}))
	print("SITE ARRIVED YAW ENTRY OK")
	quit()
