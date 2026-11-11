extends Control
## N6: contact sheet of the panel's captures (tools/ui.sh sheet --dir=<captures> --out=<png>). Every png in the
## directory except the sheet itself, in name order, four to a row, each with its file name.

const COLS: int = 4
const CELL_W: int = 472
const CELL_H: int = 266
const CAP_H: int = 22
const GAP: int = 6


func _ready() -> void:
	var dir: String = ""
	var out: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--dir="):
			dir = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
	var names: PackedStringArray = []
	var d: DirAccess = DirAccess.open(dir)
	if d != null:
		for f: String in d.get_files():
			if f.ends_with(".png") and f != out.get_file() and not f.begins_with("_"):
				names.append(f)
	names.sort()
	var rows: int = int(ceil(float(names.size()) / float(COLS)))
	var w: int = COLS * CELL_W + (COLS + 1) * GAP
	var h: int = rows * (CELL_H + CAP_H) + (rows + 1) * GAP
	var sv: SubViewport = SubViewport.new()
	sv.size = Vector2i(w, maxi(h, 64))
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.transparent_bg = false
	add_child(sv)
	var back: ColorRect = ColorRect.new()
	back.color = Color("#1a1024")
	back.size = Vector2(sv.size)
	sv.add_child(back)
	for i: int in names.size():
		var img: Image = Image.new()
		if img.load(dir.path_join(names[i])) != OK:
			continue
		img.resize(CELL_W, int(float(CELL_W) * float(img.get_height()) / float(img.get_width())), Image.INTERPOLATE_LANCZOS)
		var x: int = GAP + (i % COLS) * (CELL_W + GAP)
		var y: int = GAP + (i / COLS) * (CELL_H + CAP_H + GAP)
		var tr: TextureRect = TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		tr.position = Vector2(x, y)
		sv.add_child(tr)
		var l: Label = Label.new()
		l.text = names[i]
		l.position = Vector2(x + 2, y + CELL_H + 1)
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color("#f3e8dc"))
		sv.add_child(l)
	for i: int in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var err: int = sv.get_texture().get_image().save_png(out)
	print("[ui] sheet of %d captures %s -> %s" % [names.size(), "written" if err == OK else "FAILED", out])
	get_tree().quit(0 if err == OK else 1)
