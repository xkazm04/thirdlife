extends RefCounted
## The editor changes the same pack-local layout the game reads at setup.
const Layout = preload("res://style/hud/layout.gd")
var game_dir: String
var catalog: Array = []
var profile: Dictionary = {}
var saved: Dictionary = {}
var _original: String

func open_game(dir: String) -> String:
	var specs := JSON.new()
	var error := _read(dir.path_join(Layout.CATALOG), specs)
	if error != "":
		return error
	error = Layout.check_catalog(specs.data)
	if error != "":
		return error
	var data := JSON.new()
	error = _read(dir.path_join(Layout.PROFILE), data)
	if error != "":
		return error
	error = Layout.check_profile(data.data, specs.data)
	if error != "":
		return error
	game_dir = dir
	catalog = specs.data
	profile = data.data
	saved = profile.duplicate(true)
	_original = data.get_parsed_text()
	return ""

func _read(path: String, parser: JSON) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "Could not open %s (%s)." % [path.get_file(), error_string(FileAccess.get_open_error())]
	if parser.parse(f.get_as_text(), true) != OK:
		return "%s, line %d: %s" % [path.get_file(), parser.get_error_line() + 1, parser.get_error_message()]
	return ""

func set_option(id: String, key: String, value: Variant) -> void:
	var edits: Array = profile.get("widgets", [])
	for item: Dictionary in edits:
		if item.id == id:
			item[key] = value
			return
	edits.append({"id": id, key: value})
	profile["widgets"] = edits

func dirty() -> bool:
	return profile != saved

func save() -> String:
	var error := Layout.check_profile(profile, catalog)
	if error != "":
		return error
	var path := game_dir.path_join(Layout.PROFILE)
	if FileAccess.get_file_as_string(path) != _original:
		return "The layout changed on disk. Reopen it to use the latest version."
	var tmp := path.get_base_dir().path_join(".hud-%d.tmp" % OS.get_process_id())
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return "Could not write the layout (%s)." % error_string(FileAccess.get_open_error())
	var next := JSON.stringify(profile, "  ", false) + "\n"
	file.store_string(next)
	file.flush()
	var err := file.get_error()
	file.close()
	if err == OK:
		err = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		DirAccess.remove_absolute(tmp)
		return "Could not save the layout (%s)." % error_string(err)
	_original = next
	saved = profile.duplicate(true)
	return ""
