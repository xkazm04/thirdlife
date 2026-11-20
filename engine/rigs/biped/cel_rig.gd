extends "res://rigs/biped/clay_rig.gd"


func _init() -> void:
	# The gait's own stance (0.115 m): a wider one (0.168, round 3) changed the leg pose that
	# example.kit's bot measures, so that game's state hash moved under crisp (operator, 20 Nov 18:50).
	_gait.standing_half_width = .115


func _sculptor() -> _Sculpt:
	return preload("res://rigs/biped/cel_biped.gd").new()


func _pocket_beat(beat: float) -> float:
	# Brush the side pocket once during the glance. The return exposes the
	# pale cuff and the curled thumb as two separate shapes against the road.
	return smoothstep(.97,1.58,beat)*(1.0-smoothstep(1.86,2.52,beat))


func _idle(t: float) -> Dictionary:
	var pose := super(t)
	if not _skate_built and not _stick_on:
		pose["LeftUpperArm"] += Vector3(-12,-5,-4)
		pose["RightUpperArm"] += Vector3(-12,5,4)
		pose["LeftHand"] += Vector3(0,-13,0)
		pose["RightHand"] += Vector3(0,13,0)
	return pose
