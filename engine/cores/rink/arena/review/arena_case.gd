extends SceneTree
## Headless checks of thirdjam's hall as the core carries it (selftest block 840, lane K6):
##   godot --headless --path engine --script res://cores/rink/arena/review/arena_case.gd
## Prints one line a case, `ARENA <case> ok=true|false <detail>`:
##   pieces     arena.scn holds every group of arena.json with its instance count; the triangles add up to the table's
##   places     the pieces stand where thirdjam's SOURCE puts them (numbers from RinkActor.h / .cpp and ASSETS.md, not
##              from the export): benches, boxes, table, goal lights, caps, stands, fans, lamps, the four key spots
##   materials  every thirdjam material a piece wears has a master this port knows; the rink's own surfaces are listed
##   rink       with game.rink given, the ice, the boards, the kick plate and the cap are built round thirdjam's outline
##   light      the rig handed to the style: 18 spots of which 4 cast shadows, the exposure of EV100 4.2, a roof light
## TL_ARENA_EXPECT_FANS overrides the expected number of fans (to show the case red).

const Arena := preload("res://cores/rink/arena/rink_arena.gd")
const MASTERS: PackedStringArray = ["M_ClayBarn", "M_ArenaWood", "M_ClayCrowd", "M_ClayBulb", "M_Toon", "M_Trim", "M_Ice"]
# thirdjam's regular rink (Game/Content/Cartridges/hockey.regular.cartridge.json game.rink)
const L: float = 90.0
const W: float = 45.0
const R: float = 3.75


func _init() -> void:
	var t: Dictionary = Arena.table()
	var host := Node3D.new()
	get_root().add_child(host)
	var root: Node3D = Arena.build(host, {"rink": {"length_m": L, "width_m": W, "corner_radius_m": R}})
	if root == null or t.is_empty():
		print("ARENA pieces ok=false the hall does not build")
		quit(1)
		return
	_pieces(t, root)
	_places(t, root)
	_materials(t)
	_rink(root)
	_light(t)
	host.free()
	quit(0)


func _group(t: Dictionary, gname: String) -> Dictionary:
	for g: Dictionary in t["groups"]:
		if str(g["name"]) == gname:
			return g
	return {}


func _origins(root: Node3D, gname: String) -> Array:
	var n: Node = root.get_node_or_null(NodePath(gname))
	var out: Array = []
	if n is MeshInstance3D:
		out.append((n as MeshInstance3D).transform.origin)
	elif n is MultiMeshInstance3D:
		var buf: PackedFloat32Array = n.get_meta(&"tl_buffer", PackedFloat32Array())
		var count: int = int(n.get_meta(&"tl_count", 0))
		var stride: int = buf.size() / maxi(count, 1)
		for i: int in count:
			out.append(Vector3(buf[i * stride + 3], buf[i * stride + 7], buf[i * stride + 11]))
	return out


func _pieces(t: Dictionary, root: Node3D) -> void:
	var bad: PackedStringArray = []
	var tris: int = 0
	var inst: int = 0
	for g: Dictionary in t["groups"]:
		var n: Node = root.get_node_or_null(NodePath(str(g["name"])))
		if n == null:
			bad.append("%s missing" % g["name"])
			continue
		var mesh: Mesh = (n as MeshInstance3D).mesh if n is MeshInstance3D else (n as MultiMeshInstance3D).multimesh.mesh
		var count: int = 1 if n is MeshInstance3D else int(n.get_meta(&"tl_count", 0))
		if count != int(g["count"]):
			bad.append("%s has %d of %d" % [g["name"], count, int(g["count"])])
		var mt: int = 0
		for s: int in mesh.get_surface_count():
			mt += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		if mesh.get_surface_count() != (g["materials"] as Array).size():
			bad.append("%s has %d surfaces for %d materials" % [g["name"], mesh.get_surface_count(), (g["materials"] as Array).size()])
		tris += mt * count
		inst += count
	var tot: Dictionary = t["totals"]
	if tris != int(tot["triangles"]) or inst != int(tot["instances"]):
		bad.append("%d triangles in %d instances, the table says %d in %d" % [tris, inst, int(tot["triangles"]), int(tot["instances"])])
	print("ARENA pieces ok=%s groups=%d instances=%d triangles=%d%s" % [str(bad.is_empty()), (t["groups"] as Array).size(), inst, tris,
		"" if bad.is_empty() else " " + "; ".join(bad)])


func _places(t: Dictionary, root: Node3D) -> void:
	var bad: PackedStringArray = []
	# RinkActor.h:60-78: boards 0.2 m thick, a piece stands ArenaGapM 0.05 outside them; the benches' centres at
	# +-ArenaBenchCentreFactor 0.0833 x the length on the +y side, scaled 0.1 x length / 12 along the boards; the boxes at
	# x = -+PenaltyBoxCentreXM 3 on the -y side with the scorer's table between; a goal light behind each end.
	var side: float = W * 0.5 + 0.2 + 0.05
	var end: float = L * 0.5 + 0.2 + 0.05
	var want: Dictionary = {
		"ArenaBenchNeg": Vector3(-0.0833 * L, 0, side), "ArenaBenchPos": Vector3(0.0833 * L, 0, side),
		"ArenaBoxNeg": Vector3(-3, 0, -side), "ArenaBoxPos": Vector3(3, 0, -side), "ArenaTable": Vector3(0, 0, -side),
		"ArenaGoalLightNeg": Vector3(-end, 0, 0), "ArenaGoalLightPos": Vector3(end, 0, 0),
	}
	for k: String in want:
		var o: Array = _origins(root, k)
		if o.size() != 1 or (o[0] as Vector3).distance_to(want[k]) > 0.002:
			bad.append("%s at %s, thirdjam's source says %s" % [k, str(o), str(want[k])])
	var bench: MeshInstance3D = root.get_node_or_null("ArenaBenchNeg") as MeshInstance3D
	if bench == null or absf(bench.transform.basis.x.length() - 0.1 * L / 12.0) > 1e-4:
		bad.append("the bench's scale along the boards is not 0.1 x length / 12")
	# RinkActor.cpp:526-547: a cap at every stanchion place, round(perimeter / 3.6), on the board's middle line and top
	var perimeter: float = 2.0 * (L - 2.0 * R) + 2.0 * (W - 2.0 * R) + TAU * R
	var caps: Array = _origins(root, "ArenaCaps") + _origins(root, "ArenaCapsPos")
	if caps.size() != roundi(perimeter / 3.6):
		bad.append("%d board caps, round(%.2f / 3.6) = %d" % [caps.size(), perimeter, roundi(perimeter / 3.6)])
	for c: Vector3 in caps:
		if absf(c.y - 1.2) > 0.002 or absf(_outside(c) - 0.1) > 0.02:
			bad.append("a cap at %s is not on the board top's middle line" % str(c))
			break
	# ASSETS.md, row LR_P3_Clay.umap: on the regular rink 56 stand pieces and 664 fans; 18 lamp shades; 10 roof bays,
	# 32 wall bays, 12 lengths of bunting, 18 lamp arms
	var fans: int = 0
	for g: Dictionary in t["groups"]:
		if str(g["mesh"]).begins_with("SM_Fan_"):
			fans += int(g["count"])
	var want_fans: int = int(OS.get_environment("TL_ARENA_EXPECT_FANS")) if OS.get_environment("TL_ARENA_EXPECT_FANS") != "" else 664
	if fans != want_fans:
		bad.append("%d fans, expected %d" % [fans, want_fans])
	var stands: int = int(_group(t, "Stand_Mod").get("count", 0)) + int(_group(t, "Stand_End").get("count", 0)) + int(_group(t, "Stand_Corner").get("count", 0))
	for row: Array in [["stand pieces", stands, 56], ["lamp shades", int(_group(t, "Con_ClayLampShade").get("count", 0)), 18],
			["roof bays", int(_group(t, "Barn_TrussBay").get("count", 0)), 10], ["wall bays", int(_group(t, "Barn_WallBay").get("count", 0)), 32],
			["bunting", int(_group(t, "Barn_Bunting").get("count", 0)), 12],
			["lamp arms", int(_group(t, "Barn_LampArm_075").get("count", 0)) + int(_group(t, "Barn_LampArm_225").get("count", 0)), 18]]:
		if int(row[1]) != int(row[2]):
			bad.append("%d %s, thirdjam's asset table says %d" % [row[1], row[0], row[2]])
	# every fan sits outside the boards and inside the barn's walls (the walls stand at +-60 and +-37 m)
	for g: Dictionary in t["groups"]:
		if str(g["mesh"]).begins_with("SM_Fan_"):
			for o: Vector3 in _origins(root, str(g["name"])):
				if _outside(o) < 0.5 or absf(o.x) > 60.0 or absf(o.z) > 37.0:
					bad.append("a fan of %s sits at %s" % [g["name"], str(o)])
					break
	# M_Ice's own lamp table (MI_Ice_Night LampA 1125, 3375, 1300; LampB y 1350, z 1150 cm) against the rig's spots
	var keys: int = 0
	var lamps: int = 0
	for l: Dictionary in t["lights"]:
		var p := Vector3(l["pos"][0], l["pos"][1], l["pos"][2])
		if bool(l["shadows"]) and (is_equal_approx(absf(p.x), 11.25) or is_equal_approx(absf(p.x), 33.75)) and is_equal_approx(p.y, 13.0) and is_zero_approx(p.z) and is_equal_approx(float(l["candela"]), 5200.0):
			keys += 1
		elif str(l["name"]).begins_with("Lamp_") and is_equal_approx(absf(p.z), 13.5) and is_equal_approx(p.y, 11.5) and is_equal_approx(float(l["candela"]), 2100.0):
			lamps += 1
	if keys != 4 or lamps != 8 or (t["lights"] as Array).size() != 18:
		bad.append("%d key spots, %d side lamps, %d lights (4, 8, 18)" % [keys, lamps, (t["lights"] as Array).size()])
	print("ARENA places ok=%s caps=%d fans=%d stands=%d keys=%d lamps=%d%s" % [str(bad.is_empty()), caps.size(), fans, stands, keys, lamps,
		"" if bad.is_empty() else " " + "; ".join(bad)])


## How far a point of the floor plan lies outside thirdjam's outline (negative inside).
func _outside(p: Vector3) -> float:
	var q := Vector2(absf(p.x) - (L * 0.5 - R), absf(p.z) - (W * 0.5 - R))
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - R


func _materials(t: Dictionary) -> void:
	var bad: PackedStringArray = []
	var mats: Dictionary = t["materials"]
	var used: Dictionary = {}
	for g: Dictionary in t["groups"]:
		for m: Variant in g["materials"]:
			used[str(m)] = true
	var rs: Dictionary = t.get("rink_surfaces", {})
	for k: String in ["Ice", "Boards", "KickPlate", "Trim"]:
		if not rs.has(k) or (rs[k]["materials"] as Array).is_empty():
			bad.append("no rink surface '%s'" % k)
		else:
			used[str(rs[k]["materials"][0])] = true
	for m: String in used:
		var master: String = str((mats.get(m, {}) as Dictionary).get("master", ""))
		if not MASTERS.has(master):
			bad.append("%s has the master '%s'" % [m, master])
		elif Arena.material(m) == null:
			bad.append("%s gives no material" % m)
	if bool(rs.get("Glass", {}).get("shown", true)):
		bad.append("the glass is shown (thirdjam hides it on the clay tier)")
	print("ARENA materials ok=%s used=%d%s" % [str(bad.is_empty()), used.size(), "" if bad.is_empty() else " " + "; ".join(bad)])


func _rink(root: Node3D) -> void:
	var bad: PackedStringArray = []
	var segs: int = Arena.outline(L, W, R, 12).size()
	for row: Array in [["RinkIce", segs], ["RinkBoards", segs * 6], ["RinkKickPlate", segs * 4], ["RinkTrim", segs * 6]]:
		var mi: MeshInstance3D = root.get_node_or_null(NodePath(str(row[0]))) as MeshInstance3D
		var n: int = (mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3 if mi != null else -1
		if n != int(row[1]):
			bad.append("%s has %d triangles of %d" % [row[0], n, row[1]])
	var ice: MeshInstance3D = root.get_node_or_null("RinkIce") as MeshInstance3D
	if ice != null:
		var bb: AABB = ice.mesh.get_aabb()
		if absf(bb.size.x - L) > 1e-3 or absf(bb.size.z - W) > 1e-3 or bb.position.y < 0.0 or bb.position.y > 0.006:
			bad.append("the ice sheet measures %s" % str(bb))
	print("ARENA rink ok=%s outline=%d%s" % [str(bad.is_empty()), segs, "" if bad.is_empty() else " " + "; ".join(bad)])


func _light(t: Dictionary) -> void:
	var bad: PackedStringArray = []
	var rig: Array = Arena.rig_lights()
	var shadows: int = rig.filter(func(l: Dictionary) -> bool: return bool(l["shadows"])).size()
	if rig.size() != 18 or shadows != 4:
		bad.append("%d lights, %d with shadows" % [rig.size(), shadows])
	if absf(Arena.exposure() - 1.0 / (1.2 * pow(2.0, 4.2))) > 1e-6:
		bad.append("exposure %f is not 1 / (1.2 * 2^4.2)" % Arena.exposure())
	var roof: Dictionary = Arena.roof_light()
	if not (str(roof.get("color", "")).begins_with("#") and float(roof.get("energy", 0.0)) > 0.1 and float(roof.get("energy", 0.0)) < 4.0):
		bad.append("roof light %s" % str(roof))
	var post: Dictionary = Arena.hall_post()
	if float(post["grade"]["plum_density"]) != 0.0 or not post.has("ink"):
		bad.append("hall post %s" % str(post))
	print("ARENA light ok=%s lights=%d shadows=%d exposure=%.6f roof=%s x %.3f%s" % [str(bad.is_empty()), rig.size(), shadows, Arena.exposure(),
		roof.get("color", ""), float(roof.get("energy", 0.0)), "" if bad.is_empty() else " " + "; ".join(bad)])
