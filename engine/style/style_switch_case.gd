extends SceneTree
## Diorama night seam: TL_STYLE picks the style file. Prints one line STYLE_SWITCH path=<p> name=<n> errors=<k>.


func _initialize() -> void:
	var problems: PackedStringArray = TLStyle.load_style()
	var hard := 0
	for p: String in problems:
		if not p.begins_with("clamped: "):
			hard += 1
	print("STYLE_SWITCH path=%s name=%s errors=%d" % [TLStyle.DEFAULT_PATH, str(TLStyle.data.get("name", "")), hard])
	quit(0)
