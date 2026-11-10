extends SceneTree
## Regenerates the generated tables of kits/KIT.md and rigs/RIGS.md from TLKit.spec / TLRigs.spec (tools/k.sh docs).
## Everything below the marker line `<!-- generated below: do not edit by hand -->` is replaced.

const MARK: String = "<!-- generated below: do not edit by hand -->"


func _initialize() -> void:
	var kit: String = "\n## Parts (%d)\n\n| Kind | Material tag | Fracturable | Triangles (defaults) | Bodies | What it is |\n|---|---|---|---|---|---|\n" % TLKit.list().size()
	var details: String = "\n## Params per part\n"
	for kind: String in TLKit.list():
		var s: Dictionary = TLKit.spec(kind)
		var n: Node3D = TLKit.build(kind, {})
		var bodies: PackedStringArray = PackedStringArray()
		for b: Node in n.find_children("*", "StaticBody3D", true, false):
			bodies.append("%s (%s)" % [b.name, b.get_meta("tl_material", "?")])
		if bool(n.get_meta("tl_dynamic", false)):
			bodies.append("none: dynamic, `tl_shape` on the part")
		kit += "| `%s` | %s | %s | %d | %s | %s |\n" % [kind, s.get("material", ""), "yes" if bool(s["fracturable"]) else "", TLKit.triangles(n), ", ".join(bodies) if bodies.size() > 0 else "none", s["doc"]]
		n.free()
		details += "\n### `%s`\n" % kind
		details += _params(s["params"])
	_splice("res://kits/KIT.md", kit + details)
	var rigs: String = ""
	for family: String in TLRigs.list():
		var s2: Dictionary = TLRigs.spec(family)
		var r: Node3D = TLRigs.build(family, {})
		var m: Dictionary = r.call("metrics")
		rigs += "\n## `%s`\n%s\n\nMetrics at scale 1: `%s`\n\nClips: %s\n\nBuild params (also the initial values of the runtime params of the same name):\n" % [family, s2["doc"], JSON.stringify(m), ", ".join(r.call("clips"))]
		rigs += _params(s2["params"])
		for rk: String in (s2["runtime"] as Dictionary):
			rigs += "\nRuntime only: `%s`: %s\n" % [rk, s2["runtime"][rk]]
		r.free()
	_splice("res://rigs/RIGS.md", rigs)
	quit()


func _params(params: Dictionary) -> String:
	if params.is_empty():
		return "No params.\n"
	var t: String = "| Param | Type | Default | Range / values | Meaning |\n|---|---|---|---|---|\n"
	for pn: String in params:
		var d: Dictionary = params[pn]
		var rng: String = ""
		if d.has("enum"):
			rng = ", ".join(d["enum"])
		elif d.has("keys"):
			rng = "keys: " + ", ".join(d["keys"])
		elif d.has("count"):
			rng = "%d numbers" % int(d["count"])
		elif d.has("max"):
			rng = "%s..%s" % [str(d["min"]), str(d["max"])]
		elif d.has("min"):
			rng = "at least %s" % str(d["min"])
		elif d["type"] == "key":
			rng = "a palette key"
		t += "| `%s` | %s | `%s` | %s | %s |\n" % [pn, d["type"], JSON.stringify(d["default"]), rng, d.get("doc", "")]
	return t


func _splice(path: String, generated: String) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	var i: int = text.find(MARK)
	if i < 0:
		print("[docs] no marker in ", path)
		return
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text.substr(0, i + MARK.length()) + "\n" + generated)
	f.close()
	print("[docs] wrote ", path)
