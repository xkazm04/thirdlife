class_name TLVfxNode
extends Node3D
## One running effect made by TLVfx. Frees itself after `frames_left` physics frames (one-shot effects).

var preset: StringName = &""
var one_shot: bool = true
var frames_left: int = -1          ## -1 = until stopped
var particles: CPUParticles3D


## Stops emitting and frees the effect once the particles alive have faded.
func stop() -> void:
	if particles != null:
		particles.emitting = false
		frames_left = int(particles.lifetime * 60.0) + 2
	else:
		frames_left = 1


func _physics_process(_delta: float) -> void:
	if frames_left < 0:
		return
	frames_left -= 1
	if frames_left <= 0:
		queue_free()
