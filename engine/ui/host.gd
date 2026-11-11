extends Control
## N6: the stand-alone host of the designer panel (tools/ui.sh). A seed frame stands in for the game picture, the
## panel sits over it. Modes, by the arguments after `--`:
##   --jobs=<dir>                      the jobs root (job directories with a job.jsonl)
##   --out=<abs png>                   capture: draw, save the picture, quit. Nothing is started, nothing is written.
##   --select=<job id> --section=brief|build|change|tune|notes|all|none   what the capture shows
##   --new-open  --picture=<n>         capture with the "New game" field open / with the n-th picture enlarged
##   --flags=<json>                    the Foreman settings per command (adapter, limits); without it nothing starts
##   --readonly                        look only: no Foreman command, no write to a pack
##   --drive=<name> --shots=<dir>      run a scripted session through real input events (ui/drive.gd)
##   --bg=<png>|none                   the picture behind the panel

const Panel_ = preload("res://ui/panel.gd")
const Door = preload("res://ui/foreman_door.gd")
const JobModel = preload("res://ui/job_model.gd")

var args: Dictionary = {}
var panel: Panel_
var door: Door


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var eq: int = a.find("=")
			if eq == -1:
				args[a.substr(2)] = "1"
			else:
				args[a.substr(2, eq - 2)] = a.substr(eq + 1)
	Engine.max_fps = 60
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_window().title = "Third Life: designer panel"
	_background(str(args.get("bg", ProjectSettings.globalize_path("res://look/after/wall_player_f700.png"))))
	var jobs_root: String = str(args.get("jobs", "")).replace("\\", "/").trim_suffix("/")
	var capture: bool = args.has("out")
	var read_only: bool = args.has("readonly")
	var flags: Dictionary = {}
	var flags_name: String = ""
	if args.has("flags"):
		var f: Variant = JobModel.read_json(str(args["flags"]))
		if f is Dictionary:
			flags = (f as Dictionary).get("flags", {})
			flags_name = str((f as Dictionary).get("name", ""))
		else:
			push_warning("the flags file is not JSON: " + str(args["flags"]))
	door = Door.new()
	var opts: Dictionary = {"dry": read_only or capture, "flags": flags, "flags_name": flags_name}
	if args.has("foreman"):
		opts["cli"] = str(args["foreman"])
	if args.has("node"):
		opts["node"] = str(args["node"])
	door.setup(jobs_root, opts)
	panel = Panel_.new()
	panel.name = "Panel"
	var popts: Dictionary = {"read_only": read_only}
	if args.has("section"):
		popts["section"] = str(args["section"])
	panel.setup(jobs_root, door, popts)
	add_child(panel)
	if args.has("new-open"):
		panel.new_open = true
	if args.has("select"):
		var want: String = str(args["select"])
		panel.selected = want if panel.jobs.has(want) else ""
		if panel.selected.is_empty():
			print("[ui] no job named %s under %s" % [want, jobs_root])
	panel.refresh(true)
	if capture:
		_capture_and_quit(str(args["out"]))
	elif args.has("drive"):
		var drive: Node = (load("res://ui/drive.gd") as GDScript).new()
		drive.name = "Drive"
		add_child(drive)
		drive.call("start", self, str(args["drive"]), str(args.get("shots", "")))


func _background(path: String) -> void:
	var back: ColorRect = ColorRect.new()
	back.color = Color("#3f48a8")
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	if path == "none" or not FileAccess.file_exists(path):
		return
	var img: Image = Image.new()
	if img.load(path) != OK:
		return
	var tr: TextureRect = TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)


func _capture_and_quit(out: String) -> void:
	for i: int in 6:
		await get_tree().process_frame
	if args.has("picture"):
		var thumbs: Array = panel.find_children("Thumb_*", "Button", true, false)
		var n: int = int(args["picture"])
		print("[ui] %d pictures in the sheet; enlarging number %d" % [thumbs.size(), n])
		if n >= 0 and n < thumbs.size():
			(thumbs[n] as Button).pressed.emit()
	for i: int in 10:
		await get_tree().process_frame
	var err: int = await shot(out)
	print("[ui] capture %s -> %s" % ["written" if err == OK else "FAILED (%d)" % err, out])
	get_tree().quit(0 if err == OK else 1)


func shot(out: String) -> int:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	return img.save_png(out)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not args.has("drive"):
		get_tree().quit(0)
