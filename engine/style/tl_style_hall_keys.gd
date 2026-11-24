class_name TLStyleHallKeys
extends RefCounted
## The shadows of a hall's key lights (K7, hockey port, round 3): the lights of a rig that cast shadows (thirdjam's
## LR_P3_Clay: four spots 13 m over the rink's long axis, 22.5 m apart) as real spot lights with shadow maps, so that a
## figure throws one shadow a light, away from that light's foot, long near the boards, as it does in the reference.
## A new entry beside TLStyleHall; it changes no light of the picture: the hall's surfaces are lit by the rig's own
## numbers in their shaders (TLStyleArena, hall_rig.gdshaderinc), and these lights are only READ there for their
## shadow. They light nothing: their colour is black. (A cull mask of one layer was tried: the engine then no longer
## counts a figure on another layer as the light's, and a moving figure's shadow stayed where it first fell.)
##
##   TLStyleHallKeys.install(anchor, lights)       # lights: TLStyleArena.set_rig's shape; those with "shadows": true are made
##   TLStyleHallKeys.receive(ice_mesh_instance)    # a surface drawn by hall_ice.gdshader: it takes the shadows
##   TLStyleHallKeys.clear(anchor)
##
## Each light is made so that what a shader's light() reads as ATTENUATION is the shadow alone: no fall-off with
## distance (decay 0, a range four times the light's radius: the window is 0.992 at the radius), a cone 6 degrees wider
## than the light's outer cone with no fall-off inside it. The shader weighs each key's shadow by that key's own share of the
## rig's light at the point (hall_ice.gdshader, the lines marked K7).
## The softness: a filtered edge of one width (`blur`), looked at against the running game's stills. thirdjam's is its
## light's source radius (60 cm: a penumbra that widens with the caster's height); the engine's own soft shadows for a
## spot light (`soft`: true) came out hard-edged and stepped at this map size, so they are off by default.
## Options: `atlas` (the viewport's positional shadow atlas, px; default 8192: four lights at 4096 px each),
## `blur` (default 1.0), `soft` (false; true: the light's source radius through the engine's soft shadows),
## `bias` (0.03), `filter` (the renderer's soft shadow filter for spot lights, RenderingServer.ShadowQuality 0..5;
## default 4, high).
## Headless it does nothing. It acts on the anchor's viewport (a game alone).

const NODE: StringName = &"HallKeys"
const DEFAULTS: Dictionary = {"atlas": 8192, "blur": 1.0, "soft": false, "bias": 0.03, "filter": 4}
const WIDER_DEG: float = 6.0
const RANGE_K: float = 4.0


static func install(anchor: Node, lights: Array, opt: Dictionary = {}) -> int:
	if TLStyle.headless() or anchor == null or not anchor.is_inside_tree():
		return 0
	for k: String in opt:
		if not DEFAULTS.has(k):
			push_error("TLStyleHallKeys.install: unknown option '%s' (known: %s)" % [k, ", ".join(PackedStringArray(DEFAULTS.keys()))])
			return 0
	var o: Dictionary = DEFAULTS.duplicate()
	o.merge(opt, true)
	var rig: Node = anchor.get_tree().root.find_child(TLStyle.RIG_NODE, true, false)
	if rig == null:
		push_error("TLStyleHallKeys.install: no installed style rig (TLStyle.install)")
		return 0
	clear(anchor)
	var host: Node3D = Node3D.new()
	host.name = NODE
	rig.add_child(host)
	var made: int = 0
	for l: Dictionary in lights:
		if not bool(l.get("shadows", false)):
			continue
		for k: String in ["pos", "dir", "radius_m", "outer_deg"]:
			if not l.has(k):
				push_error("TLStyleHallKeys.install: a light without '%s'" % k)
				return made
		var s: SpotLight3D = SpotLight3D.new()
		s.name = "Key%d" % made
		host.add_child(s)
		var dir: Vector3 = (l["dir"] as Vector3).normalized()
		var up: Vector3 = Vector3.RIGHT if absf(dir.y) > 0.99 else Vector3.UP
		s.look_at_from_position(l["pos"] as Vector3, (l["pos"] as Vector3) + dir, up)
		s.light_color = Color(0, 0, 0)      # it lights nothing: a surface that takes its shadow reads ATTENUATION alone
		s.light_energy = 1.0
		s.light_specular = 0.0
		s.spot_range = float(l["radius_m"]) * RANGE_K
		s.spot_attenuation = 0.0
		s.spot_angle = minf(float(l["outer_deg"]) + WIDER_DEG, 86.0)
		s.spot_angle_attenuation = 0.001       # the engine: (1 - rim) ^ this; near 0 = no fall-off inside the cone (looked at: 64 left 3 % of the light)
		s.shadow_enabled = true
		s.shadow_bias = float(o["bias"])
		s.shadow_normal_bias = 1.0
		s.shadow_blur = float(o["blur"])
		s.light_size = float(l.get("source_radius_m", 0.0)) if bool(o["soft"]) else 0.0
		made += 1
	var vp: Viewport = anchor.get_viewport()
	if vp != null and made > 0:
		host.set_meta(&"tl_atlas_was", [vp.positional_shadow_atlas_size, vp.positional_shadow_atlas_16_bits, vp.positional_shadow_atlas_quad_0,
			vp.positional_shadow_atlas_quad_1, vp.positional_shadow_atlas_quad_2, vp.positional_shadow_atlas_quad_3])
		# every quadrant cut alike, so that each key has a map of one size wherever the engine puts it (with the engine's
		# own cut, 1 / 4 / 16 / 64, a key's map changed size with the camera: seen as a shadow that came and went)
		var cut: Viewport.PositionalShadowAtlasQuadrantSubdiv = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1 if made <= 4 else Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4
		vp.positional_shadow_atlas_size = int(o["atlas"])
		vp.positional_shadow_atlas_16_bits = false
		vp.positional_shadow_atlas_quad_0 = cut
		vp.positional_shadow_atlas_quad_1 = cut
		vp.positional_shadow_atlas_quad_2 = cut
		vp.positional_shadow_atlas_quad_3 = cut
		RenderingServer.positional_soft_shadow_filter_set_quality(int(o["filter"]) as RenderingServer.ShadowQuality)
	return made


## A surface that takes the keys' shadows: its material (hall_ice.gdshader) is told to read them in place of the style
## sun's one shadow.
static func receive(mi: GeometryInstance3D) -> void:
	if TLStyle.headless() or mi == null:
		return
	var m: ShaderMaterial = mi.material_override as ShaderMaterial
	if m == null and mi is MeshInstance3D:
		m = (mi as MeshInstance3D).get_active_material(0) as ShaderMaterial
	if m != null:
		m.set_shader_parameter(&"key_shadows", 1.0)


## How many key lights stand (0 = none: surfaces take the style sun's shadow, as before).
static func count(anchor: Node) -> int:
	var host: Node = _host(anchor)
	return 0 if host == null else host.get_child_count()


static func clear(anchor: Node) -> void:
	var host: Node = _host(anchor)
	if host == null:
		return
	var vp: Viewport = anchor.get_viewport()
	if vp != null and host.has_meta(&"tl_atlas_was"):
		var was: Array = host.get_meta(&"tl_atlas_was")
		vp.positional_shadow_atlas_size = int(was[0])
		vp.positional_shadow_atlas_16_bits = bool(was[1])
		vp.positional_shadow_atlas_quad_0 = was[2]
		vp.positional_shadow_atlas_quad_1 = was[3]
		vp.positional_shadow_atlas_quad_2 = was[4]
		vp.positional_shadow_atlas_quad_3 = was[5]
		RenderingServer.positional_soft_shadow_filter_set_quality(
			int(ProjectSettings.get_setting("rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality", 2)) as RenderingServer.ShadowQuality)
	host.get_parent().remove_child(host)
	host.queue_free()


static func _host(anchor: Node) -> Node:
	if TLStyle.headless() or anchor == null or not anchor.is_inside_tree():
		return null
	var rig: Node = anchor.get_tree().root.find_child(TLStyle.RIG_NODE, true, false)
	return rig.get_node_or_null(NodePath(String(NODE))) if rig != null else null
