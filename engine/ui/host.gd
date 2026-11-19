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
##   --editor  [--sentence=<text>] [--recipe=<name>] [--place=<x>,<z>] [--turn=<steps>] [--take] [--closeup]
##                                     open the workbench (ui/editor/) over the panel; the rest fill it for a capture

const Panel_ = preload("res://ui/panel.gd")
const Door = preload("res://ui/foreman_door.gd")
const JobModel = preload("res://ui/job_model.gd")
const Workbench = preload("res://ui/editor/workbench.gd")
const GameSheet = preload("res://ui/editor/game_sheet.gd")

var args: Dictionary = {}
var panel: Panel_
var door: Door
var workbench: Workbench = null
var game_sheet: GameSheet = null


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
	panel.action_started.connect(func(what: String, _err: String) -> void:
		if what == "workbench":
			open_workbench())
	panel.job_selected.connect(open_game_sheet)
	if args.has("editor"):
		open_workbench()
		_fill_workbench()
	elif not panel.selected.is_empty():
		open_game_sheet(panel.selected)
	if capture:
		_capture_and_quit(str(args["out"]))
	elif args.has("drive"):
		var drive: Node = (load("res://ui/drive.gd") as GDScript).new()
		drive.name = "Drive"
		add_child(drive)
		drive.call("start", self, str(args["drive"]), str(args.get("shots", "")))


## E1: the workbench over the panel. Build it -> the builders start through the same door; the panel shows the job.
func open_workbench() -> void:
	if workbench != null:
		return
	workbench = Workbench.new()
	workbench.name = "Workbench"
	workbench.setup(door, door.jobs_root)
	add_child(workbench)
	panel.visible = false
	workbench.closed.connect(close_workbench)
	workbench.committed.connect(func(request: String, err: String) -> void:
		if err.is_empty():
			panel.set("_want_select_sentence", Door.clean_text(request))
			panel.say("The Designer is writing a brief…")
			close_workbench.call_deferred()
		panel.refresh(true))


## E2: a game made in the workbench (its draft is under <jobs>/_editor) opens in the game sheet when it is selected.
func open_game_sheet(id: String) -> void:
	if workbench != null or game_sheet != null or not panel.jobs.has(id):
		return
	var d: Dictionary = GameSheet.find_draft(door.jobs_root, str((panel.jobs[id] as Dictionary).get("sentence", "")))
	if d.is_empty():
		return
	game_sheet = GameSheet.new()
	game_sheet.name = "GameSheet"
	game_sheet.setup(door, door.jobs_root.path_join(id), d)
	add_child(game_sheet)
	panel.visible = false
	game_sheet.closed.connect(func() -> void:
		game_sheet.queue_free()
		game_sheet = null
		panel.visible = true)


func close_workbench() -> void:
	if workbench != null:
		workbench.queue_free()
		workbench = null
	panel.visible = true


## For captures: --sentence, --recipe, --take, --place, --turn fill the workbench as a player would have.
func _fill_workbench() -> void:
	var m: RefCounted = workbench.model
	if args.has("sentence"):
		var idea: LineEdit = workbench.find_child("IdeaField", true, false) as LineEdit
		idea.text = str(args["sentence"])
		m.call("set_sentence", idea.text)
	if args.has("recipe"):
		m.call("choose_recipe", str(args["recipe"]))
	if args.has("take"):
		m.call("take_proposals")
	if args.has("place"):
		var xz: PackedStringArray = str(args["place"]).split(",")
		m.call("place", Vector2(float(xz[0]), float(xz[1])))
	if args.has("turn"):
		m.call("turn", int(args["turn"]))
	if args.has("closeup"):
		(workbench.find_child("CloseUpButton", true, false) as Button).pressed.emit()
	workbench.refresh()


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
