class_name TLRigSkaterFx
extends RefCounted
## The effects that hang off thirdjam's skater's moves. Its Blueprint BP_SkaterVisual_TB1_P3 has two Niagara
## components: SlideFx (active from a knockdown until he is released: the ice he throws up while he slides) and
## BrakeFx (restarted by a stop take, with User.Strength = the speed he stopped from / 14). The MOMENTS are thirdjam's
## and are kept by the figure's takes (`bSlideFx`: [KnockDown] L590, L605 of the listing; `brake_fx_n`,
## `brake_fx_strength`: [StopTick] L1753, L1768). Internal to engine/rigs/skater: TLRigSkater ticks one.
## DEVIATION: the two Niagara systems themselves are not exported. They are drawn with the style's own "ice_spray"
## preset (TLStyleFx): the slide's while he moves faster than 1 m/s (thirdjam's own rule is inside its Niagara
## system), the brake's as one burst of 8 to 60 flakes by the strength. Nothing is made in a headless run.

var _slide: CPUParticles3D = null
var _brake: CPUParticles3D = null
var _brake_seen: int = 0


func tick(fig: TLRigSkater) -> void:
	if not fig.is_inside_tree() or TLStyle.headless():
		return
	var takes: TLRigSkaterToys = fig.takes
	if takes.bSlideFx and _slide == null:
		_slide = TLStyleFx.preset("ice_spray", {"one_shot": false, "life_frames": 24, "scale": 0.7})
		if _slide != null:
			_slide.amount = 16
			fig.add_child(_slide)
	if _slide != null:
		_slide.emitting = takes.bSlideFx and fig.SpeedNow > 1.0
		var pel: Vector3 = fig.bone_xf(TLRigSkaterPose.PELVIS).origin
		_slide.position = Vector3(pel.x, 0.03, pel.z)
	if takes.brake_fx_n != _brake_seen:
		_brake_seen = takes.brake_fx_n
		if _brake == null:
			_brake = TLStyleFx.preset("ice_spray", {"one_shot": true, "life_frames": 30})
			if _brake != null:
				fig.add_child(_brake)
		if _brake != null:
			_brake.amount = int(clampf(30.0 * takes.brake_fx_strength, 8.0, 60.0))
			_brake.position = Vector3(0.0, 0.03, -0.3)
			_brake.restart()
