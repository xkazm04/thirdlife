extends Node
## L4 (night of 21 Nov): a dungeon. One pack alone, in this process, with its own camera, HUD and look; no world, no
## visitor. No class_name (boot.gd loads it by path).
##
## A dungeon is "the pack alone" (the gate law: a game in a world plays as it does alone), so this drives the same
## lifecycle core the lone worker drives (kernel/runner/pack_life.gd) in the same order, in mode "play" (a person):
##   load:  lint (a pack is played only inside the fence) -> context -> scene -> input and views (devices on) -> the
##          look -> laws on nodes as they arrive -> entry (generators, _pack_setup, laws) -> default ground (window)
##   frame f (physics, before every other node): first _pack_start -> ctx.frame = f -> input latches -> _pack_tick(f)
##          -> every 10th frame the census (laws on late bodies, counts) -> the physics step
##   end:   census, state hash (kernel/host/statehash.gd), _pack_teardown, every node of the pack freed, the default
##          look back, `left` emitted.
## So a counted run (`frames` > 0) hashes as `worker --mode=play --frames=N` of the same pack and seed (selftest 640).
##
## What the worker has and a dungeon does not: the watchdog thread (a tick that runs away hangs this process, as it
## would hang a person's `tl play`), the input record (--record), --devices. Script errors are counted by the runner's
## logger: more than 20 stop the dungeon with the reason on its card.
##
## The person's side: a load screen with the title while the pack loads (it stays LOAD_SCREEN_FRAMES drawn frames
## before the load blocks), Esc opens the pause card (Resume, and Leave or the caller's `back` label), which freezes the tree
## (SceneTree.paused also stops the physics server). Leaving keeps a small still of the last frame the person saw in
## user://dungeon_stills/<pack id>.png, for the menu.
##
##   var d = load("res://kernel/dungeon/dungeon.gd").new(); parent.add_child(d)
##   var ok: bool = await d.open(<pack dir>, {title?, look?, seed?, frames?, back?})
##   d.left -> (why: "leave" | "frames" | "error" | "refused");  d.result: {pack, seed, frames, state_hash?, ...}

signal left(why: String)

const PackLife = preload("res://kernel/runner/pack_life.gd")
const Manifest: GDScript = preload("res://kernel/runner/manifest.gd")
const Lint: GDScript = preload("res://kernel/runner/lint.gd")
const LoggerScript: GDScript = preload("res://kernel/runner/logger.gd")
const List: GDScript = preload("res://kernel/dungeon/dungeons.gd")
const UI: GDScript = preload("res://kernel/dungeon/look_ui.gd")

const CENSUS_EVERY: int = 10            # as the worker (kernel/runner/worker.gd)
const MAX_ERRORS: int = 20              # RUNNER.md: more than this stops a run
const LOAD_SCREEN_FRAMES: int = 30      # drawn frames the load screen stays before the load (half a second at 60 Hz)
const STILL_DIR: String = "user://dungeon_stills"
const STILL_SIZE: Vector2i = Vector2i(384, 216)

var pack_dir: String = ""
var title: String = ""
var look: String = ""                   # the look name asked for ("" = the default)
var look_used: String = ""              # the style file installed
var back_label: String = "Leave"
var seed_value: int = 1
var frames_target: int = 0              # 0: until the person leaves; N: a counted run that ends itself after N frames
var life: PackLife
var ctx: TLContext
var run: Node                           # the holder of the pack (PackLife's holder): pausable, under this node
var frame: int = 0
var started: bool = false
var loaded: bool = false
var finished: bool = false
var paused: bool = false
var problem: String = ""
var result: Dictionary = {}
var load_errors: Array = []
var warnings: Array = []
var _logger: Logger = null
var _headless: bool = true
var _layer: CanvasLayer = null
var _loading: Control = null
var _pause: Control = null
var _refused: Control = null
var _resume: Button = null
var _mouse_before: int = Input.MOUSE_MODE_VISIBLE
var _still: Image = null


func _init() -> void:
	name = "Dungeon"
	process_mode = Node.PROCESS_MODE_ALWAYS       # the cards and Esc work while the tree is paused; the pack is under `run`
	process_physics_priority = -100000            # before every other node of the frame, as the worker


## Loads the pack. True when it runs; false (and `problem`, and a card that says it, and `left("refused")` on the
## next frame) when it cannot.
func open(dir: String, o: Dictionary = {}) -> bool:
	set_physics_process(false)
	_headless = DisplayServer.get_name() == "headless"
	pack_dir = Manifest.resolve_dir(dir)
	title = str(o.get("title", ""))
	look = str(o.get("look", ""))
	back_label = str(o.get("back", "Leave"))
	seed_value = int(o.get("seed", 1))
	frames_target = maxi(0, int(o.get("frames", 0)))
	result = {"schema": "thirdlife.dungeon/1", "kind": "dungeon", "pack_dir": pack_dir if not pack_dir.is_empty() else dir, "seed": seed_value}
	_layer = CanvasLayer.new()
	_layer.name = "DungeonCards"
	_layer.layer = 110
	add_child(_layer)
	if pack_dir.is_empty():
		return _refuse("there is no pack folder at %s" % dir)
	var mres: Dictionary = Manifest.read(pack_dir)
	if not bool(mres["ok"]):
		return _refuse("its pack.json is not valid: %s" % str(((mres["errors"] as Array)[0] as Dictionary).get("message", "")) if not (mres["errors"] as Array).is_empty() else "its pack.json is not valid")
	var m: Dictionary = mres["manifest"]
	if title.is_empty():
		title = str(m.get("title", m.get("id", pack_dir.get_file())))
	result["pack"] = str(m["id"])
	_show_loading()
	if not _headless:
		for i: int in LOAD_SCREEN_FRAMES:
			await RenderingServer.frame_post_draw          # the load screen is on the screen (and seen) before the load blocks
			if finished:
				return false                               # the window was closed meanwhile
	var fence: Array = Lint.run(pack_dir)["errors"]
	if not fence.is_empty():
		return _refuse("it does not pass lint (%d finding(s)); first: %s" % [fence.size(), str((fence[0] as Dictionary).get("message", fence[0]))])
	for e: String in TLLaws.load_tables():
		load_errors.append({"kind": "engine", "file": "res://kernel/data", "message": e})
	_logger = LoggerScript.new()
	_logger.set("pack_dir", pack_dir)
	OS.add_logger(_logger)
	run = Node.new()
	run.name = "Run"
	run.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(run)
	life = PackLife.new()
	life.load_errors = load_errors
	life.warnings = warnings
	ctx = life.make_context(run, m, pack_dir, seed_value, frames_target if frames_target > 0 else (1 << 40), "play")
	TLContext.current = ctx                       # one pack in this process while the dungeon runs (as the worker)
	life.make_scene()
	life.make_io(true)                            # a person's devices reach ctx.input
	_install_look()
	if not _headless:
		TLStandin.install_look(run)
	get_tree().node_added.connect(_on_node_added)
	if not life.load_entry():
		var first: Dictionary = load_errors[0] if not load_errors.is_empty() else {}
		_free_pack()
		return _refuse("it did not load: %s %s" % [str(first.get("file", "")), str(first.get("message", "see the log"))])
	if not _headless:
		TLStandin.install_default_ground(run, ctx.root)
	life.find_idle_scripts()
	loaded = true
	print("[dungeon] %s (%s) runs: look %s, seed %d, %s" % [title, str(m["id"]), look_used, seed_value,
		("%d frames" % frames_target) if frames_target > 0 else "until the person leaves"])
	_hide_loading()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_physics_process(true)
	return true


## The dungeon's look: its `look` name, else the default (TL_STYLE, else crisp). A style file that is refused leaves
## the default and says so on the log.
func _install_look() -> void:
	TLStyle.set_headless(_headless)
	var path: String = List.look_path(look)
	if path.is_empty():
		path = TLStyle._chosen_path()
	var probs: PackedStringArray = TLStyle.load_style(path)
	for p: String in probs:
		print("[dungeon] look %s: %s" % [path, p])
	look_used = TLStyle.style_path if not TLStyle.style_path.is_empty() else path


func _on_node_added(n: Node) -> void:
	if life == null or life.pack_node == null:
		return
	life.mute_if_pack(n)
	if n is CollisionObject3D and n.has_meta(&"tl_material") and not n.has_meta(&"tl_law_applied") and life.pack_node.is_ancestor_of(n):
		TLLaws.apply(n as CollisionObject3D)


func _physics_process(_delta: float) -> void:
	if finished or not loaded or get_tree().paused:
		return
	if not started:
		started = true
		life.start()
	if frames_target > 0 and frame >= frames_target:
		close("frames")
		return
	_logger.set("frame", frame)
	life.tick(frame, true)
	if int(_logger.call("total_errors")) > MAX_ERRORS:
		_stop("more than %d script errors by frame %d" % [MAX_ERRORS, frame])
		return
	if frame % CENSUS_EVERY == 0:
		life.census(frame)
	frame += 1


func _input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo or k.keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	if _refused != null or not loaded:
		if _refused != null:
			close("refused")
		return
	if paused:
		resume()
	else:
		pause()


func pause() -> void:
	if paused or finished or not loaded:
		return
	if not _headless:
		_still = get_viewport().get_texture().get_image()     # the frame he saw, before the card covers it
	paused = true
	get_tree().paused = true
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _pause == null:
		_pause = _make_pause()
		_layer.add_child(_pause)
	_pause.visible = true
	_resume.grab_focus()
	print("[dungeon] paused at frame %d" % frame)


func resume() -> void:
	if not paused:
		return
	paused = false
	if _pause != null:
		_pause.visible = false
	Input.mouse_mode = _mouse_before as Input.MouseMode
	get_tree().paused = false
	print("[dungeon] resumed at frame %d" % frame)


## Ends the dungeon: the hash of a loaded run, the pack's teardown, every node of the pack freed, the default look back.
func close(why: String) -> void:
	if finished:
		return
	finished = true
	set_physics_process(false)
	if get_tree().paused:
		get_tree().paused = false
	if loaded:
		life.census(frame)
		result["frames"] = frame
		result["state_hash"] = life.state_hash()
		var snap: Dictionary = _logger.call("snapshot")
		result["script_errors"] = int(snap.get("script_errors", 0))
		result["engine_errors"] = int(snap.get("engine_errors", 0))
		life.teardown()
	if not problem.is_empty():
		result["problem"] = problem
	result["why"] = why
	_keep_still()
	_free_pack()
	if not look_used.is_empty():
		result["look"] = look_used
	result["look_after"] = TLStyle.style_path            # the default again (TL_STYLE, else crisp)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print(JSON.stringify(result, "", false))
	left.emit(why)


func _free_pack() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	if ctx != null:
		for h: Variant in ctx.huds:
			if is_instance_valid(h) and not (h as Node).is_queued_for_deletion() and (run == null or not run.is_ancestor_of(h)):
				(h as Node).free()                    # a HUD the pack hung outside its own tree
		if TLContext.current == ctx:
			TLContext.current = null
	if run != null:
		run.free()
		run = null
	if _logger != null:
		OS.remove_logger(_logger)
		_logger = null
	loaded = false
	# the default look again (TL_STYLE, else crisp): what the menu and the world are drawn with
	TLStyle.load_style(TLStyle._chosen_path())


func _stop(why: String) -> void:
	problem = "the game stopped: " + why
	print("[dungeon] " + problem)
	close("error")


func _refuse(why: String) -> bool:
	problem = "%s cannot be opened as a dungeon: %s" % [title if not title.is_empty() else pack_dir, why]
	print("[dungeon] " + problem)
	_hide_loading()
	if _headless:
		close.call_deferred("refused")
		return false
	_refused = _make_refused()
	_layer.add_child(_refused)
	return false


## user://dungeon_stills/<pack id>.png: the last frame the person saw (taken when he paused), small. The menu shows it.
func _keep_still() -> void:
	if _still == null or not result.has("pack"):
		return
	var img: Image = _still
	_still = null
	if img.get_width() <= 0:
		return
	img.resize(STILL_SIZE.x, STILL_SIZE.y, Image.INTERPOLATE_BILINEAR)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STILL_DIR))
	img.save_png(still_path(str(result["pack"])))


static func still_path(pack_id: String) -> String:
	return "%s/%s.png" % [STILL_DIR, pack_id.validate_filename()]


# ------------------------------------------------------------------------------------------------ the cards
func _full() -> Control:
	var c: Control = Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	return c


func _centered(card: Control) -> CenterContainer:
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.add_child(card)
	return cc


func _show_loading() -> void:
	_loading = _full()
	_loading.name = "Loading"
	_loading.add_child(UI.sky_backdrop())
	var card: PanelContainer = UI.card()
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(UI.label("Entering", 26))
	v.add_child(UI.label(title, 56))
	v.add_child(UI.label("look: %s" % (look if not look.is_empty() else "default"), 22))
	card.add_child(v)
	_loading.add_child(_centered(card))
	_layer.add_child(_loading)


func _hide_loading() -> void:
	if _loading != null:
		_loading.free()
		_loading = null


func _make_pause() -> Control:
	var root: Control = _full()
	root.name = "Pause"
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(UI.colors()["ink"], 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var card: PanelContainer = UI.card()
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(520, 0)
	v.add_child(UI.label(title, 40))
	v.add_child(UI.label("paused", 22))
	_resume = UI.button("Resume")
	_resume.name = "Resume"
	_resume.pressed.connect(resume)
	v.add_child(_resume)
	var leave: Button = UI.button(back_label)
	leave.name = "Leave"
	leave.pressed.connect(func() -> void: close("leave"))
	v.add_child(leave)
	v.add_child(UI.label("Esc  resume", 20))
	card.add_child(v)
	root.add_child(_centered(card))
	return root


func _make_refused() -> Control:
	var root: Control = _full()
	root.name = "Refused"
	root.add_child(UI.sky_backdrop())
	var card: PanelContainer = UI.card()
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(760, 0)
	v.add_child(UI.label(title if not title.is_empty() else "This game", 40))
	var why: Label = UI.label(problem, 22)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(why)
	var back: Button = UI.button(back_label)
	back.pressed.connect(func() -> void: close("refused"))
	v.add_child(back)
	card.add_child(v)
	root.add_child(_centered(card))
	back.grab_focus.call_deferred()
	return root
