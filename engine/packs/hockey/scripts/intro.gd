extends RefCounted
## L5 (21 Nov): the first minute. A person's session (the panel's rule: ctx.mode "play", on stage) starts with a drill
## that is playable at once: skate to the ring, take your mate's pass, pass it back (Q), take it again and shoot into
## the empty net (click or Space). Then the match starts at the default level and mode (R after a match opens the panel).
## Enter skips it. One line on the screen per step: a key and a few words. A test starts it with the keyless action
## `intro`. Numbers in data/tuning.json "intro"; the set start is the drill "intro" of data/drills.json (goalies on the
## bench: the net is empty). Created by main.gd, no class_name; g = main.

var active: bool = false
var ran: bool = false
var step: String = ""                  ## skate, take, pass, back, shoot, done
var t: int = 0                         ## frames in this step
var netted: bool = false               ## the drill ended with a goal (not a skip)
var skipped: bool = false
var steps: int = 0                     ## steps completed
var _ring: Node3D = null
var _loose: int = 0

func wanted(g) -> bool:
	return not ran and g.menu_lib.enabled and g.ctx.on_stage

func cfg(g) -> Dictionary:
	return g.tune["intro"]

func begin(g, frame: int) -> void:
	active = true
	ran = true
	netted = false
	skipped = false
	steps = 0
	for d: Dictionary in g.drills["drills"]:
		if str(d["id"]) == "intro":
			g.drill_lib.start(g, d, frame)
	g.drill_id = "intro"
	if g.rules.is_running():
		g.rules.pause()                      # started by a test in a running match: the clock waits (a person's starts before it)
	var c: Dictionary = cfg(g)
	var lib = g.look._lib(g)
	if lib != null and (_ring == null or not is_instance_valid(_ring)):
		_ring = Node3D.new()
		_ring.name = "IntroRing"
		g.ctx.root.add_child(_ring)
		lib.make_ring(_ring, float(c["ring_r"]), 0.3, str(g.look.cfg["puck_rim_key"]), "Ring", 0.03)
	if _ring != null:
		_ring.position = Vector3(float(c["ring"][0]), 0.06, float(c["ring"][1]))      # above the ice top (0.05)
		_ring.visible = true
	_go("skate")

func _go(s: String) -> void:
	if step != "" and step != s:
		steps += 1
	step = s
	t = 0

func text(g) -> String:
	var lines: Dictionary = cfg(g)["lines"]
	return "%s\n%s" % [str(lines.get(step, "")), str(lines["skip"])]

## Every tick before the match's own work: true while the drill runs (main then does nothing else this tick).
func tick(g, frame: int) -> bool:
	if not active:
		if g.ctx.input.just_pressed(&"intro"):
			begin(g, frame)
			return true
		return false
	if g.ctx.input.just_pressed(&"skip"):
		skipped = true
		finish(g)
		return true
	var api = g.api
	var c: Dictionary = cfg(g)
	api.tick(frame)
	g.hits.tick(frame)
	g.player.aim(g)
	api.update_possession()
	g.player.live_input(g)
	api._follow_blade()
	g.drill_lib.tick(g, frame)
	g.player.input(g)
	api.step_sticks()
	g.hits.step_actions()
	api.pose_sticks()
	api.apply_speeds()
	t += 1
	var me: Vector3 = api.pos_of("b0")
	var ring: Vector3 = Vector3(float(c["ring"][0]), 0.0, float(c["ring"][1])) + g.ctx.root.global_position
	match step:
		"skate":
			if me.distance_to(ring) <= float(c["ring_r"]):
				if _ring != null:
					_ring.visible = false
				_feed(g, "b1")
				_go("take")
		"take":
			if api.carrier == "b1":
				_feed(g, "b1")
			if api.carrier == "b0":
				_go("pass")
		"pass":
			if api.carrier == "b1":
				_go("back")
		"back":
			if api.carrier == "b1" and t >= int(c["return_frames"]):
				_feed(g, "b1")
			if api.carrier == "b0":
				_go("shoot")
		"shoot":
			if api.goal_by_position(g.tune["goals"]) == "blue":
				netted = true
				g._event("goal", g.puck.global_position, "blue")
				_go("done")
		"done":
			if t >= int(c["done_frames"]):
				finish(g)
				return true
	# a puck nobody can reach any more (shot wide, passed astray): back on his blade after lost_frames
	if step != "done" and step != "skate" and api.carrier == "" and g.puck.linear_velocity.length() < 2.0:
		_loose += 1
		if _loose >= int(c["lost_frames"]):
			_loose = 0
			api.give("b0" if step == "shoot" or step == "pass" else "b1")
			if step == "take":
				_feed(g, "b1")
	else:
		_loose = 0
	for e: Array in api.events:
		if str(e[0]) == "shot":
			g._event("shot", api.pos_of(str(e[1])), "blue")
	api.events.clear()
	g.hits.events.clear()
	g._flush_events(frame)
	return true

## The mate's pass to b0 (led to where he will be).
func _feed(g, from: String) -> void:
	var api = g.api
	if api.carrier != from:
		return
	var to: Vector3 = api.lead_point("b0") - api.puck_pos()
	if to.length() <= 0.2:
		return
	var dir := to.normalized()
	api.stick_dir[from] = dir
	# Let the blade swing to the passing side before the return feed crosses his skates.
	var body_offset: Vector3 = api.pos_of(from) - api.puck_pos()
	if body_offset.dot(dir) > 0.0 and body_offset.cross(dir).length() < g.skaters[from].body_radius() + api.puck_radius:
		return
	api.try_pass(from, "b0")
	api.stick_dir.erase(from)

func finish(g) -> void:
	active = false
	if _ring != null and is_instance_valid(_ring):
		_ring.visible = false
	g.drill_id = ""
	g._build(g.mode_id)
	g._begin()
