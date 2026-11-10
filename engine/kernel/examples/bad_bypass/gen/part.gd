extends RefCounted
## Builds geometry by hand instead of asking TLKit: lint counts this generator in composability.kit_parts_added.


static func generate(ctx) -> void:
	var mesh: ArrayMesh = ArrayMesh.new()
	var holder: MeshInstance3D = MeshInstance3D.new()
	holder.mesh = mesh
	holder.material_override = ShaderMaterial.new()     # BYPASS: style (a hand-made material counts in a generator too)
	holder.name = "HandMadePart"
	ctx.root.add_child(holder)
