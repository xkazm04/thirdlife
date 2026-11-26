extends Node3D
## M4 (spark world-sandbox): what stands at the spot a command was asked for. While the model thinks: a small holo
## pillar with "thinking... 0:23" over it (the seconds counted in physics frames, 60 a second). While its answer is
## shown as a ghost: the note over the spot, no pillar. The holo material is the style's (TLStyle.material("holo")); the
## text is a Label3D drawn over everything. Moved only when told; left out of physics interpolation.

const HIGH := 2.2                       # metres the pillar stands

var cell := Vector3i.ZERO
var pillar: MeshInstance3D
var label: Label3D


func _init() -> void:
	name = "CommandMarker"
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	pillar = MeshInstance3D.new()
	pillar.name = "Pillar"
	var m := BoxMesh.new()
	m.size = Vector3(0.3, HIGH, 0.3)
	pillar.mesh = m
	pillar.position = Vector3(0.5, HIGH * 0.5, 0.5)
	pillar.material_override = TLStyle.material("holo")
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pillar)
	label = Label3D.new()
	label.name = "Text"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0011
	label.font_size = 26
	label.outline_size = 8
	label.modulate = Color(1, 1, 1, 0.96)
	label.outline_modulate = Color(0.05, 0.05, 0.08, 0.9)
	label.position = Vector3(0.5, HIGH + 0.5, 0.5)
	add_child(label)


func place_at(c: Vector3i) -> void:
	cell = c
	position = Vector3(c)


## "thinking... 0:23" after `frames` physics frames.
func thinking(frames: int) -> void:
	pillar.visible = true
	var s := frames / 60
	label.text = "thinking... %d:%02d" % [s / 60, s % 60]


func note(text: String, over: float) -> void:
	pillar.visible = false
	label.text = text
	label.position = Vector3(0.5, over + 1.0, 0.5)
