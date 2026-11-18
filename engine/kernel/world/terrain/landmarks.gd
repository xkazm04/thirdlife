extends RefCounted
## D2 (Astra trial): `landscape.landmarks` = [{"asset": "<repo-relative .glb>", "at": [x, z], "yaw": deg,
## "clear_m": m, "posts": [[x, z, r], ...]}]. Each is a mesh asset of assets/ (contracts/ASSETS.md) drawn in the
## house look by `TLKitAsset` (its materials are palette keys), standing on the land at `at`, turned by `yaw` (0: the
## model's front looks along +Z). `posts` are cylinders in the model's own metres that the visitor stops at (his
## collider; none = he walks through). Visual and the visitor's body only:
## no pack sees it, so no state hash can move. A file that is not found (the exported game has no assets/) is left
## out with a warning. With `clear_m` the landmark is appended to `centres` / `rad` (the landscape's plot list, after the
## terrain is built and only read by the scatter from there on) so trees, rocks, bushes and tufts keep that far away.
## Leave it out where the spot is already clear: the scatter shares one generator, so one rejected candidate moves
## every later tree, tuft, belt tree and mesa of the village (measured on village.json: the mesas moved).
static func place(parent: Node3D, ws: RefCounted, terr: RefCounted, cfg: Dictionary, stats: Dictionary, centres: Array, rad: Array) -> void:
	var list: Variant = cfg.get("landmarks", [])
	if typeof(list) != TYPE_ARRAY:
		return
	var repo: String = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/").get_base_dir()
	var tag: String = str(ws.get("tag"))
	for lm: Variant in list:
		var d: Dictionary = lm
		var path: String = repo + "/" + str(d.get("asset", ""))
		if not FileAccess.file_exists(path):     # the exported game: export.sh puts the asset beside the exe
			path = OS.get_executable_path().get_base_dir().replace("\\", "/") + "/" + str(d.get("asset", ""))
		if not FileAccess.file_exists(path):
			push_warning("landscape: landmark %s not found, left out" % str(d.get("asset", "")))
			continue
		var node: Node3D = TLKitAsset.build(path)
		if node == null:
			continue
		var at: Vector2 = Vector2(float((d["at"] as Array)[0]), float((d["at"] as Array)[1]))
		var yaw: float = deg_to_rad(float(d.get("yaw", 0.0)))
		var foot: Vector3 = Vector3(at.x, float(terr.call("gy", at.x, at.y)), at.y)
		node.transform = Transform3D(Basis(Vector3.UP, yaw), foot)
		node.name = "Landmark_%s" % node.name
		parent.add_child(node)
		ws.set("tag", "landmark")
		for pv: Variant in d.get("posts", []):
			var p: Array = pv
			var lp: Vector3 = Basis(Vector3.UP, yaw) * Vector3(float(p[0]), 0.0, float(p[1]))
			ws.call("add_trunk", foot + lp, float(p[2]), 4.0)
		if d.has("clear_m"):
			centres.append(at)
			rad.append(float(d["clear_m"]))
		stats["landmarks"] = int(stats.get("landmarks", 0)) + 1
	ws.set("tag", tag)
