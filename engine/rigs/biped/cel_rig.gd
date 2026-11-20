extends "res://rigs/biped/clay_rig.gd"


func _init() -> void:
	# Leave daylight between the broad boots. The gait places both soles
	# on the ground and brings them back onto the running track at speed.
	_gait.standing_half_width = .168


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
