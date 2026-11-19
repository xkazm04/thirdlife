extends RefCounted
## Validation shared by the game and the workbench. The author owns the catalogue, the player owns the overrides.
const Stock = preload("res://style/hud/stock.gd")
const ANCHORS := ["top_left", "top", "top_right", "left", "center", "right", "bottom_left", "bottom", "bottom_right"]
const SIZES := {"small": 0.82, "regular": 1.0, "large": 1.22}
const CATALOG := "data/hud-widgets.json"
const PROFILE := "data/hud.json"
const FIELDS := {
	"bib": ["value", "name"], "cue": ["value"], "split": ["name", "value", "best", "delta"],
	"timer": ["value", "best"], "progress": ["done", "total"],
	"results": ["value", "name", "best", "rows"], "keys": ["pairs"],
}

static func _keys(data: Variant, allowed: Array, where: String) -> String:
	if not data is Dictionary:
		return "%s must be an object" % where
	for key: Variant in data:
		if key not in allowed:
			return "%s has unknown key '%s'" % [where, key]
	return ""

static func check_reading(form: String, reading: Variant) -> String:
	if not FIELDS.has(form):
		return "unknown widget form '%s'" % form
	var err := _keys(reading, FIELDS[form], form)
	if err != "":
		return err
	for key: String in FIELDS[form]:
		var val: Variant = reading.get(key)
		match key:
			"done", "total":
				if typeof(val) not in [TYPE_INT, TYPE_FLOAT] or val != floorf(float(val)):
					return "%s.%s must be a whole number" % [form, key]
			"rows", "pairs":
				if not val is Array:
					return "%s.%s must be a list" % [form, key]
				for row: Variant in val:
					if not row is Array or row.size() != (3 if key == "rows" else 2):
						return "%s.%s has an invalid row" % [form, key]
					for item: Variant in row:
						if not item is String:
							return "%s.%s cells must be text" % [form, key]
			_:
				if not val is String:
					return "%s.%s must be text" % [form, key]
	if form == "progress" and (reading.total < 1 or reading.done < 0 or reading.done > reading.total):
		return "progress must be between zero and total"
	return ""

static func check_catalog(catalog: Variant) -> String:
	if not catalog is Array or catalog.is_empty():
		return "HUD catalogue must be a nonempty list"
	var seen := {}
	for item: Variant in catalog:
		var err := _keys(item, ["id", "title", "form", "anchor", "phase", "sample", "finish_sample"], "widget")
		if err != "":
			return err
		var id: Variant = item.get("id")
		if not id is String or not id.is_valid_ascii_identifier() or seen.has(id):
			return "missing, duplicate or invalid widget id '%s'" % str(id)
		seen[id] = true
		if not item.get("title") is String or item.title.is_empty():
			return "%s needs a title" % id
		if item.get("anchor") not in ANCHORS or item.get("phase", "run") not in ["run", "finish", "both"]:
			return "%s has an unknown anchor or phase" % id
		err = check_reading(str(item.get("form", "")), item.get("sample"))
		if err == "" and item.has("finish_sample"):
			err = check_reading(item.form, item.finish_sample)
		if err != "":
			return "%s: %s" % [id, err]
	return ""

static func check_profile(profile: Variant, catalog: Array) -> String:
	var err := _keys(profile, ["theme", "widgets"], "HUD layout")
	if err != "":
		return err
	if profile.get("theme", "signal") not in Stock.THEMES:
		return "unknown HUD theme '%s'" % str(profile.theme)
	var edits: Variant = profile.get("widgets", [])
	if not edits is Array:
		return "widgets must be a list"
	var known := {}
	for item: Dictionary in catalog:
		known[item.id] = true
	for override_: Variant in edits:
		err = _keys(override_, ["id", "visible", "anchor", "size"], "widget override")
		if err != "":
			return err
		var id: Variant = override_.get("id")
		if not known.erase(id):
			return "unknown or duplicate widget id '%s'" % str(id)
		if override_.get("anchor", "top") not in ANCHORS:
			return "%s has an unknown anchor" % id
		if override_.get("size", "regular") not in SIZES:
			return "%s has an unknown size" % id
		if not override_.get("visible", true) is bool:
			return "%s.visible must be true or false" % id
	return ""

static func resolved(catalog: Array, profile: Dictionary) -> Dictionary:
	var widgets := {}
	for item: Dictionary in catalog:
		widgets[item.id] = {"anchor": item.anchor, "visible": true, "size": "regular"}
	for item: Dictionary in profile.get("widgets", []):
		widgets[item.id].merge(item, true)
	return widgets
