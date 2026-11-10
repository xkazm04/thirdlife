extends SceneTree
## Asset scan (devx `tl assets scan`): one line per kit part, built from its default params.
##   TLASSET {"id":"kit.rink","hash":"<TLKit.hash>","tris":N,"material":"ice","fracturable":false,"doc":"..."}
## Parts are visited in sorted order; nothing here depends on wall time or randomness.
## Run: godot --headless --path engine -s tools/assets/scan_kit.gd


func _initialize() -> void:
	var kinds: Array = Array(TLKit.list())
	kinds.sort()
	var bad: int = 0
	for kind: String in kinds:
		var spec: Dictionary = TLKit.spec(kind)
		var defaults: Dictionary = {}
		for pn: String in spec["params"]:
			defaults[pn] = (spec["params"] as Dictionary)[pn]["default"]
		var a: Node3D = TLKit.build(kind, {})
		var b: Node3D = TLKit.build(kind, {})
		if a == null or b == null:
			print("TLASSET_ERROR build failed: " + kind)
			bad += 1
			continue
		var h: String = TLKit.hash(a)
		if h != TLKit.hash(b):
			print("TLASSET_ERROR nondeterministic hash: " + kind)
			bad += 1
		var row: Dictionary = {"id": "kit." + kind, "part": kind, "hash": h, "tris": TLKit.triangles(a),
			"material": String(spec.get("material", "")), "fracturable": bool(spec["fracturable"]), "doc": String(spec["doc"])}
		print("TLASSET " + JSON.stringify(row, "", true))
		a.free()
		b.free()
	print("TLASSET_DONE %d parts, %d errors" % [kinds.size(), bad])
	quit(1 if bad > 0 else 0)
