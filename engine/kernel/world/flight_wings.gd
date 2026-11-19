extends RefCounted
## Lane flight (19 Nov 2026): the walker's mechanical wings, a kernel part worn on the biped rig's `back` socket.
## The mesh is `assets/engine/wings.glb` (engine/tools/assets/wings_blender.py), drawn in the house look by TLKitAsset
## (its materials are palette keys); this file only moves its named parts. Visual only: no body, nothing a pack or a
## state hash can see. Every part turns about the socket's Z axis (out of his back), so the wings fold in planes
## parallel to his back.
##
##   var wings := FlightWings.attach(rig)        # null when the rig has no `back` socket or the file is missing
##   wings.tick(flying, speed_k, turn, frame)    # once per world tick: speed_k 0..1 of cruise, turn rad/s (+ = left)
##
## Folded (on the ground): the arm spar hangs down his back, the forearm lies back up along it, and every panel lies
## along its spar slid into its sleeve (25 % long): two narrow bundles behind the backpack.
## Take-off unfolds them in UNFOLD_TICKS (0.5 s): the spars swing out first, the forearms open, the panels slide out.
## Landing folds them in FOLD_TICKS. In the air: a slow flap while hovering, a still glide pose at cruise, the wings
## bank with the turn. All of it is a function of ticks: the same calls give the same pose.

const UNFOLD_TICKS: int = 30
const FOLD_TICKS: int = 36
const FLAP_TICKS: float = 96.0          # one flap cycle while hovering (1.6 s)
const PANEL_FOLDED_LEN: float = 0.25
# Folded angles (degrees about the socket's Z, for the RIGHT wing; the left wing mirrors them)
const ARM_FOLD: float = -112.0
const FORE_FOLD: float = 199.0         # the forearm lies back up along the arm
const ARM_DIR: float = 13.5            # the spars' own directions at rest (wings_blender.py SHOULDER, ELBOW, TIP)
const FORE_DIR: float = -5.7
# the panels' rest angles (wings_blender.py PANELS) and which spar carries them
const PANEL_REST: Array = [-122.0, -106.0, -93.0, -80.0, -64.0, -44.0]
const PANEL_ON_FORE: Array = [false, false, false, true, true, true]

var root: Node3D = null
var k: float = 0.0                      # 0 folded .. 1 spread
var flap_t: float = 0.0
var bank: float = 0.0                   # eased bank (degrees, + = left wing up... see tick)
var _parts: Dictionary = {}             # "l" / "r" -> {"arm", "fore", "panels": [Node3D x6]}
var trails: Array = []                  # the wind trails at the wing tips (style ribbons), while near cruise
const TRAIL_ON: float = 0.9             # share of cruise from which the tips draw a wind trail ...
const TRAIL_OFF: float = 0.8            # ... and below which it stops (a band: no flicker at the threshold)


static func asset_path() -> String:
	var rel: String = "assets/engine/wings.glb"
	var repo: String = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/").get_base_dir()
	var p: String = repo + "/" + rel
	if not FileAccess.file_exists(p):        # the exported game: the asset beside the exe (as the landmarks)
		p = OS.get_executable_path().get_base_dir().replace("\\", "/") + "/" + rel
	return p if FileAccess.file_exists(p) else ""


static func attach(rig: Node3D) -> RefCounted:
	if rig == null or not rig.has_method("socket"):
		return null
	var sock: Node3D = rig.call("socket", &"back")
	var path: String = asset_path()
	if sock == null or path.is_empty():
		if path.is_empty():
			push_warning("flight wings: assets/engine/wings.glb not found, flying without wings")
		return null
	var node: Node3D = TLKitAsset.build(path)
	if node == null:
		return null
	var w: RefCounted = load("res://kernel/world/flight_wings.gd").new()
	w.set("root", node)
	node.name = "FlightWings"
	sock.add_child(node)
	w.call("_find")
	w.call("_pose")
	return w


func _find() -> void:
	for s: String in ["l", "r"]:
		var arm: Node3D = root.find_child("wing_%s" % s, true, false)
		var fore: Node3D = root.find_child("wing_%s_fore" % s, true, false)
		var panels: Array = []
		for i: int in 6:
			panels.append(root.find_child("wing_%s_f%d" % [s, i + 1], true, false))
		_parts[s] = {"arm": arm, "fore": fore, "panels": panels}


static func _ss(a: float, b: float, x: float) -> float:
	return smoothstep(a, b, x)


## One world tick. `flying`: the body is in flight; `speed_k`: horizontal speed / cruise (0..1); `turn`: the heading's
## turn rate (rad/s, + = turning left).
func tick(flying: bool, speed_k: float, turn: float, _frame: int) -> void:
	if flying:
		k = minf(1.0, k + 1.0 / float(UNFOLD_TICKS) + 0.000001)
	else:
		k = maxf(0.0, k - 1.0 / float(FOLD_TICKS) - 0.000001)
	var hover: float = 1.0 - clampf(speed_k * 1.6, 0.0, 1.0)
	flap_t += 1.0 + 0.6 * hover
	var want_bank: float = clampf(rad_to_deg(turn) * 0.18, -18.0, 18.0) if flying else 0.0
	bank = lerpf(bank, want_bank, 0.12)
	_pose(hover, speed_k)
	_trails(flying and k >= 1.0 and speed_k >= (TRAIL_OFF if not trails.is_empty() else TRAIL_ON))


## A small wind trail at each wing tip at top speed: the style's own ribbon (TLStyleFx.trail, additive, house palette),
## none when the style is absent (headless draws nothing either).
func _trails(on: bool) -> void:
	if on == not trails.is_empty():
		return
	if not on:
		for t: Variant in trails:
			if is_instance_valid(t):
				(t as Node).queue_free()
		trails.clear()
		return
	var fx: GDScript = TLStandin.ext("TLStyleFx")
	if fx == null:
		return
	for s: String in ["l", "r"]:
		var fore: Node3D = (_parts.get(s, {}) as Dictionary).get("fore")
		if fore == null:
			continue
		var m: float = 1.0 if s == "r" else -1.0
		var t: Variant = fx.call("trail", fore, {"width": 0.07, "frames": 9, "color": "fall_b", "offset": Vector3(0.80 * m, -0.08, 0.02)})
		if t != null:
			trails.append(t)


func _pose(hover: float = 1.0, speed_k: float = 0.0) -> void:
	var ka: float = _ss(0.0, 0.6, k)          # the spars swing out first
	var kf: float = _ss(0.2, 0.8, k)          # the forearms open
	var kp: float = _ss(0.4, 1.0, k)          # the panels slide out
	var ph: float = TAU * flap_t / FLAP_TICKS
	var spread: float = _ss(0.85, 1.0, k)     # flap and glide only once spread
	var flap: float = spread * (sin(ph) * (13.0 * hover + 2.5 * (1.0 - hover)))
	var flap_f: float = spread * (sin(ph - 0.7) * (9.0 * hover + 1.5 * (1.0 - hover)))
	var sweep: float = spread * (6.0 * speed_k)    # at cruise the spars rise a little and the forearms sweep back
	for s: String in ["l", "r"]:
		var p: Dictionary = _parts.get(s, {})
		if p.is_empty() or p["arm"] == null:
			continue
		var m: float = 1.0 if s == "r" else -1.0
		# bank: turning left (+) lifts the right wing and lowers the left one
		var b: float = bank * (1.0 if s == "r" else -1.0)
		var arm_a: float = lerpf(ARM_FOLD, 0.0, ka) + flap + sweep + b
		var fore_a: float = lerpf(FORE_FOLD, 0.0, kf) + flap_f - sweep * 1.5
		(p["arm"] as Node3D).rotation = Vector3(0.0, 0.0, deg_to_rad(arm_a * m))
		if p["fore"] != null:
			(p["fore"] as Node3D).rotation = Vector3(0.0, 0.0, deg_to_rad(fore_a * m))
		for i: int in 6:
			var pn: Node3D = (p["panels"] as Array)[i]
			if pn == null:
				continue
			# folded: it lies along its own spar (slid into its sleeve); spread: its rest angle with a little trail
			var rel: float = lerpf((FORE_DIR if bool(PANEL_ON_FORE[i]) else ARM_DIR) - float(PANEL_REST[i]), -flap * 0.3, kp)
			var ln: float = lerpf(PANEL_FOLDED_LEN, 1.0, kp)
			pn.transform.basis = _len_basis(deg_to_rad(rel * m), deg_to_rad(float(PANEL_REST[i]) if m > 0.0 else 180.0 - float(PANEL_REST[i])), ln)


## A rotation about Z by `a` after a scale of `ln` along the panel's own in-plane direction `dir` (its length axis).
static func _len_basis(a: float, dir: float, ln: float) -> Basis:
	var r: Basis = Basis(Vector3(0, 0, 1), dir)
	var s: Basis = Basis.from_scale(Vector3(ln, 1.0, 1.0))
	return Basis(Vector3(0, 0, 1), a) * (r * s * r.inverse())


## Round 2: a puff of dust at `at` under `parent` (take-off and landing): the style's own `dust` preset (TLStyleFx, palette
## discs), freed after its life in physics frames; nothing headless or without the style. `scale` 1 = a landing.
const DUST_FRAMES: int = 40


static func dust(parent: Node, at: Vector3, scale: float = 1.0) -> Node:
	var fx: GDScript = TLStandin.ext("TLStyleFx")
	if fx == null or parent == null or not parent.is_inside_tree():
		return null
	var p: Variant = fx.call("preset", "dust", {"life_frames": DUST_FRAMES, "one_shot": true, "scale": scale})
	if p == null:
		return null
	var n: CPUParticles3D = p
	n.add_child(_FreeAfter.new(DUST_FRAMES + 10))
	parent.add_child(n)
	n.global_position = at + Vector3(0.0, 0.05, 0.0)
	n.emitting = true
	return n


class _FreeAfter extends Node:
	var left: int = 0

	func _init(frames: int) -> void:
		left = frames

	func _physics_process(_d: float) -> void:
		left -= 1
		if left <= 0:
			get_parent().queue_free()
