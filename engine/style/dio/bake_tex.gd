extends SceneTree
## Diorama day (20 Nov 2026), surfaces: bakes the PNGs of make_tex.py into the resources the style loads.
##   "$G" --headless --path engine -s res://style/dio/bake_tex.gd -- <dir with felt.png clay.png wood.png cast.png soil.png wool.png>
## Each becomes res://style/dio/tex/<name>.res: a PortableCompressedTexture2D (lossless, mipmaps inside). No import
## step: a fresh checkout and an exported game load it as it is.


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "."
	var failed: int = 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://style/dio/tex"))
	for n: String in ["felt", "clay", "wood", "cast", "soil", "wool"]:
		var img: Image = Image.load_from_file(dir.path_join(n + ".png"))
		if img == null:
			printerr("bake_tex: cannot read " + dir.path_join(n + ".png"))
			failed += 1
			continue
		img.convert(Image.FORMAT_RGBA8)
		img.generate_mipmaps()
		var tex: PortableCompressedTexture2D = PortableCompressedTexture2D.new()
		tex.keep_compressed_buffer = true
		tex.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
		var err: Error = ResourceSaver.save(tex, "res://style/dio/tex/%s.res" % n)
		print("bake_tex: %s %dx%d mipmaps %s -> %s" % [n, img.get_width(), img.get_height(), str(img.has_mipmaps()), error_string(err)])
		if err != OK:
			failed += 1
	quit(1 if failed > 0 else 0)
