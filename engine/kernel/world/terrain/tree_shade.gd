extends RefCounted
## Day of 20 Nov 2026 (lane cel-fable; the Director's word of 14:35: "darker grass under the trees"): a map of where the
## scattered trees and bushes of the landscape stand, handed to the terrain's own material, so a style's land shader can
## paint the ground under each one (toon_cel.gdshader: a field of the dark grass paint with a cut, wobbly edge).
## One function, called once at the end of landscape.gd `build`, and only for a style that names `detail.tree_shade`
## (the blob's radius as a share of the crown's; absent or 0 = no map: today's landscape and today's material).
##
## Presentation only: no node, no collider, no geometry; one small texture (one byte per 1.5 m of land) and two
## uniforms on the terrain's material, which a shader that does not declare them never reads.

## The landscape's scattered kinds (node name starts with ...) and the crown's radius at scale 1 (m).
const KINDS: Dictionary = {"WorldPines": 2.3, "WorldBroadleaf": 2.7, "WorldRoadTrees": 2.4, "WorldBelt": 2.3, "WorldMesaPines": 2.6,
	"WorldBushes": 1.2, "WorldRoadBushes": 1.1}
const TEXEL_M: float = 1.5


## Returns the number of trees and bushes stamped into the map.
static func build(parent: Node3D, k: float) -> int:
	var ground: MeshInstance3D = parent.get_node_or_null("WorldTerrain") as MeshInstance3D
	if ground == null or k <= 0.0 or not (ground.material_override is ShaderMaterial):
		return 0
	var box: AABB = ground.get_aabb()
	var w: int = clampi(ceili(box.size.x / TEXEL_M), 8, 2048)
	var h: int = clampi(ceili(box.size.z / TEXEL_M), 8, 2048)
	var data: PackedByteArray = PackedByteArray()
	data.resize(w * h)
	var count: int = 0
	for child: Node in parent.get_children():
		var mmi: MultiMeshInstance3D = child as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null:
			continue
		var crown: float = 0.0
		for kind: String in KINDS:
			if String(mmi.name).begins_with(kind):
				crown = float(KINDS[kind])
		if crown <= 0.0:
			continue
		for i: int in mmi.multimesh.instance_count:
			var xf: Transform3D = mmi.multimesh.get_instance_transform(i)
			var r: float = crown * xf.basis.get_scale().x * k
			var cx: float = (xf.origin.x - box.position.x) / TEXEL_M
			var cz: float = (xf.origin.z - box.position.z) / TEXEL_M
			var rt: float = r * 1.3 / TEXEL_M
			for pz: int in range(maxi(int(cz - rt), 0), mini(int(cz + rt) + 2, h)):
				for px: int in range(maxi(int(cx - rt), 0), mini(int(cx + rt) + 2, w)):
					var d: float = Vector2(float(px) + 0.5 - cx, float(pz) + 0.5 - cz).length() * TEXEL_M
					var v: int = int(255.0 * (1.0 - smoothstep(r * 0.55, r * 1.3, d)))
					if v > data[pz * w + px]:
						data[pz * w + px] = v
			count += 1
	var tex: ImageTexture = ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_R8, data))
	var mat: ShaderMaterial = ground.material_override as ShaderMaterial
	mat.set_shader_parameter(&"cel_shade", tex)
	mat.set_shader_parameter(&"cel_shade_uv", Vector4(1.0 / (float(w) * TEXEL_M), 1.0 / (float(h) * TEXEL_M),
		-box.position.x / (float(w) * TEXEL_M), -box.position.z / (float(h) * TEXEL_M)))
	return count
