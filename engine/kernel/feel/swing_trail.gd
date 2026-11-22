extends Node3D
## Owns one fighter's ribbon. Count unfrozen physics ticks and sample after socket transforms update.

const HOLDER := &"_tl_swing_trail"

var ribbon: Node3D
var left: int
var last_pose: int
var ticked := false


static func start(who: TLBiped, weight: float, frames: int, opts: Dictionary) -> Node3D:
	if not is_instance_valid(who):
		return null
	var old: Variant = who.get_meta(HOLDER) if who.has_meta(HOLDER) else null
	if is_instance_valid(old):
		who.remove_meta(HOLDER)
		who.remove_child(old)
		old.queue_free()
	if frames <= 0:
		return null
	var target: Node3D
	if opts.has("node"):
		if is_instance_valid(opts.node):
			target = opts.node as Node3D
	elif is_instance_valid(who.rig) and who.rig.has_method("socket"):
		if opts.has("socket"):
			target = who.rig.call("socket", opts.socket)
		else:
			target = who.rig.call("socket", &"stick_blade")
			if target == null:
				target = who.rig.call("socket", &"hand_r")
	if target == null or target.get_parent() == null or TLStandin.ext("TLStyleFx") == null:
		return null
	var w := clampf(weight, 0.0, 1.0)
	var trail := TLVfx.trail(target, {"width": opts.get("width", lerpf(0.12, 0.36, w)),
		"frames": opts.get("keep", roundi(lerpf(5.0, 12.0, w))), "color": opts.get("color", "white"),
		"offset": opts.get("offset", Vector3.ZERO)})
	if trail == null:
		return null
	var holder = new()
	holder.name = "TLSwingTrail"
	holder.process_physics_priority = who.process_physics_priority + 1
	holder.left = frames
	holder.last_pose = who._frame
	holder.ribbon = trail
	who.add_child(holder)
	who.set_meta(HOLDER, holder)
	trail.reparent(holder, false)
	trail.set_physics_process(false)
	# A holder created during a physics callback joins the process list next tick.
	# Observe the creation tick too, including a one-frame ribbon or same-tick impact.
	holder._creation_tick.call_deferred(Engine.is_in_physics_frame())
	return trail


func _creation_tick(in_physics: bool) -> void:
	if not ticked:
		_after_pose(in_physics)


func _physics_process(_delta: float) -> void:
	ticked = true
	# Skeleton3D publishes the socket transforms after physics processing.
	_after_pose.call_deferred(true)


func _after_pose(in_physics: bool) -> void:
	if not is_inside_tree():
		return
	if not is_instance_valid(ribbon):
		queue_free()
		return
	var who := get_parent() as TLBiped
	if who.is_physics_processing():
		# On the last frozen tick stop_left reaches zero while the pose counter still holds.
		if who._frame == last_pose:
			return
	elif not in_physics or TLHit.stop_left(who) > 0:
		return
	last_pose = who._frame
	ribbon.call("_physics_process", 1.0 / 60.0)
	left -= 1
	if left <= 0:
		queue_free()
