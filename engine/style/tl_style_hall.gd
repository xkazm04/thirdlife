class_name TLStyleHall
extends RefCounted
## A light rig a pack may ask for (K3, hockey port, 23-24 Nov 2026): an indoor hall lit from above, in place of the style's
## low sun. Modelled on thirdjam's rig levels (`/JamAssets/Rigs/LR_P3_Clay`, the regular cut's `p3_clay` tier): the light
## comes from the roof, so the ice is one even tone with no sun on it and the figures stand on their own shadows.
## A new entry, not a new look: no shader changes, no style file changes. It moves the installed style's sun (the
## "TLStyleRig/Sun" node TLStyle.install made) straight down and sets the cel shader's sun colour (the global `g_sun`)
## and its direction (`g_sun_dir`); the fog and the sky are switched off (a closed hall). `clear()` gives the style back.
## Headless it does nothing (no picture). It acts on the whole process: meant for a game alone (a dungeon, `tl play`).
##
##   TLStyleHall.apply(ctx.root, {"color": "#b8a8b4", "energy": 1.0})   # from a pack's _pack_setup
##
## Options: `color` (the light's colour, "#rrggbb"; default "#ffffff"), `energy` (its strength, the style sun's unit;
## default 1.0), `shadows` (true: the figures cast their shadow straight down; default true).

const DEFAULTS: Dictionary = {"color": "#ffffff", "energy": 1.0, "shadows": true}


static func apply(anchor: Node, opt: Dictionary = {}) -> bool:
	if TLStyle.headless() or anchor == null or not anchor.is_inside_tree():
		return false
	for k: String in opt:
		if not DEFAULTS.has(k):
			push_error("TLStyleHall.apply: unknown option '%s' (known: %s)" % [k, ", ".join(PackedStringArray(DEFAULTS.keys()))])
			return false
	var o: Dictionary = DEFAULTS.duplicate()
	o.merge(opt, true)
	var rig: Node = anchor.get_tree().root.find_child(TLStyle.RIG_NODE, true, false)
	var sun: DirectionalLight3D = rig.get_node_or_null("Sun") as DirectionalLight3D if rig != null else null
	if sun == null:
		push_error("TLStyleHall.apply: no installed style rig (TLStyle.install) to light")
		return false
	var key: Node = sun.get_node_or_null("OverheadKey")
	if key != null:
		key.set_process(false)                   # the cel style's key turns the sun by the camera; a roof light does not turn
	sun.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	sun.shadow_enabled = bool(o["shadows"])
	var c: Color = Color(String(o["color"])).srgb_to_linear()
	TLStyle._g("g_sun", Vector4(c.r, c.g, c.b, float(o["energy"])))
	TLStyle._g("g_sun_dir", Vector4(0.0, 1.0, 0.0, 0.0))
	var we: WorldEnvironment = rig.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null:
		we.environment.fog_enabled = false
	return true


## Gives the installed style its own sun, fog and globals back (TLStyle.install again on the same host).
static func clear(anchor: Node) -> void:
	if TLStyle.headless() or anchor == null or not anchor.is_inside_tree():
		return
	var rig: Node = anchor.get_tree().root.find_child(TLStyle.RIG_NODE, true, false)
	if rig != null and rig.get_parent() != null:
		var sun: Node = rig.get_node_or_null("Sun")
		var key: Node = sun.get_node_or_null("OverheadKey") if sun != null else null
		if key != null:
			key.set_process(true)
		TLStyle.install(rig.get_parent())
