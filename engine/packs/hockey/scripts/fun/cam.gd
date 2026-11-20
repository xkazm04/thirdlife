extends RefCounted
## L5 (21 Nov): the play camera. A broadcast camera that follows the play: it looks down at `pitch_deg` from the side of
## the rink nearest the viewer, so up on the screen is still up the ice (W) and right is still right (D), as on the old
## top view. It frames the puck (or its carrier), leads in the attack direction and along the puck's velocity, keeps
## b0 in the picture (it widens when he is far from the puck) and eases with a critically damped follow. During a
## goal's replay it follows the puck closer. V switches to the old fixed top view ("arena") and back.
## Visual only: it reads the game and moves the view "follow"; nothing in the simulation reads it (the aim is read
## through whatever camera is on screen, as the kernel says). Numbers: data/tuning.json "follow".
## Created by fun.gd, no class_name; g = main.

var cfg: Dictionary = {}
var view: Camera3D = null
var on: bool = true                    ## the follow view is the one on screen (false: the old top view)
var focus: Vector3 = Vector3.ZERO
var speed: Vector3 = Vector3.ZERO      ## the focus's velocity (the damped follow)
var dist: float = 0.0
var _placed: bool = false
var _punch: float = 0.0                ## share of the distance taken off by a big hit, fading
var _punch_frames: int = 0
var _punch_left: int = 0


## A big hit pulls the camera in by `amount` of its distance, easing back over `frames` (visual only).
func punch(amount: float, frames: int) -> void:
	_punch = maxf(amount, _punch * float(_punch_left) / float(maxi(_punch_frames, 1)))
	_punch_frames = frames
	_punch_left = frames


func snap() -> void:
	_placed = false


func setup(g) -> void:
	cfg = g.tune["follow"]
	var c: Dictionary = cfg
	if view == null:
		if g.ctx.cameras.has_view(&"follow"):
			view = g.ctx.cameras.view(&"follow")
		else:
			view = g.ctx.cameras.add_view(&"follow", Vector3(0, 30, 20), Vector3.ZERO, float(c["fov"]))
	view.fov = float(c["fov"])
	g.ctx.cameras.set_subject(&"follow", g.skaters["b0"])
	_placed = false
	g.ctx.cameras.activate(&"follow" if on else &"arena")
	tick(g, false, false)                  # placed before the first picture (it showed the whole rink from 30 m up)


## Where the camera wants to look this frame (on the ice).
func want(g, replay: bool) -> Vector3:
	var api = g.api
	var pp: Vector3 = api.puck_pos()
	if replay:
		return pp
	var me: Vector3 = api.pos_of("b0")
	var lead: Vector3 = Vector3.ZERO
	if api.carrier != "":
		lead.x = float(cfg["attack_lead"]) * (1.0 if str(g.teams[api.carrier]) == "blue" else -1.0)
		pp = pp.lerp(api.pos_of(api.carrier), 0.5)
	var pv: Vector3 = g.puck.linear_velocity
	pv.y = 0.0
	if api.carrier != "":
		pv = (g.skaters[api.carrier] as TLBiped).velocity
		pv.y = 0.0
	lead += (pv * float(cfg["speed_lead_s"])).limit_length(float(cfg["speed_lead_max"]))
	var o: Vector3 = g.ctx.root.global_position            # the rink's centre (a world may put the pack anywhere)
	var w: Vector3 = (pp + lead).lerp(me, float(cfg["player_pull"])) - o
	var hx: float = float(g.tune["rink"]["half_length"]) - float(cfg["edge_x"])
	var hz: float = float(g.tune["rink"]["half_width"]) - float(cfg["edge_z"])
	return Vector3(clampf(w.x, -hx, hx) + o.x, o.y, clampf(w.z, -hz, hz) + o.z)


## How far the camera stands from its focus: wider when b0 and the puck are far apart, closer in a replay.
func want_dist(g, replay: bool) -> float:
	if replay:
		return float(cfg["replay_distance"])
	var gap: float = g.api.pos_of("b0").distance_to(g.api.puck_pos())
	return clampf(float(cfg["distance"]) + maxf(gap - float(cfg["gap_free"]), 0.0) * float(cfg["gap_zoom"]), float(cfg["distance"]), float(cfg["distance_max"]))


## Every tick (after the game's own work; not while a hit holds the picture still: `hold`).
func tick(g, replay: bool, hold: bool) -> void:
	if g.ctx.input.just_pressed(&"view"):
		on = not on
		g.ctx.cameras.activate(&"follow" if on else &"arena")
	if view == null or g.ctx.headless:
		return                             # visual only: no picture, no work (budget: frame p50)
	var w: Vector3 = want(g, replay)
	var d: float = want_dist(g, replay)
	if not _placed:
		focus = w
		speed = Vector3.ZERO
		dist = d
		_placed = true
	elif not hold:
		# a critically damped spring: no overshoot, no lag that grows with speed (omega in 1/s)
		var om: float = float(cfg["replay_omega"] if replay else cfg["omega"])
		var dt: float = 1.0 / 60.0
		var acc: Vector3 = (w - focus) * om * om - speed * 2.0 * om
		speed += acc * dt
		focus += speed * dt
		dist = lerpf(dist, d, float(cfg["zoom_ease"]))
	var dd: float = dist
	if _punch_left > 0:
		var u: float = float(_punch_left) / float(maxi(_punch_frames, 1))
		dd *= 1.0 - _punch * u * u
		if not hold:
			_punch_left -= 1
	var pitch: float = deg_to_rad(float(cfg["pitch_deg"]))
	var at: Vector3 = focus + Vector3(0.0, float(cfg["look_height"]), 0.0)
	view.global_position = at + Vector3(0.0, sin(pitch), cos(pitch)) * dd
	view.look_at(at, Vector3.UP)
