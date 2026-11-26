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
## L4b, the watchdog (kernel/dungeon/watch.gd): the worker's rule, reused. Every call into pack code is watched from a
## thread through kernel/host/cpuclock.gd `verdict` with the worker's limits (a tick 250 ms, a setup call 10 s, of
## processor time). A runaway cannot be interrupted, so the process records why, starts the same executable on that
## record (`--tripped=<record>`: a card "<title> was stopped" with Leave, `open_tripped`) and ends. More than 20 script
## errors stop the dungeon to the same kind of card in this process. Nothing of the watch reaches a hash or a result.
## What the worker has and a dungeon does not: the input record (--record), --devices.
##
## The person's side: a load screen with the title; the load runs in steps (each asset generator, then the entry and its
## _pack_setup: PackLife.load_steps) with a drawn frame between them, so its bar moves; the pack's nodes do not run and
## the physics server is off until the load is done (a step-wise load is still the worker's one-frame load). Esc opens the pause card (Resume, and Leave or the caller's `back` label), which freezes the tree
## (SceneTree.paused also stops the physics server). Leaving keeps a small still of the last frame the person saw in
## user://dungeon_stills/<pack id>.png, for the menu.
##
##   var d = load("res://kernel/dungeon/dungeon.gd").new(); parent.add_child(d)
##   var ok: bool = await d.open(<pack dir>, {title?, look?, seed?, frames?, back?})
##   d.left -> (why: "leave" | "frames" | "error" | "refused" | "tripped");  d.result: {pack, seed, frames, state_hash?, ...}
##   d.open_tripped(<record file>, {back?})   the card of a dungeon the watchdog stopped (in the process started for it)

signal left(why: String)

const PackLife = preload("res://kernel/runner/pack_life.gd")
const Manifest: GDScript = preload("res://kernel/runner/manifest.gd")
const Lint: GDScript = preload("res://kernel/runner/lint.gd")
const LoggerScript: GDScript = preload("res://kernel/runner/logger.gd")
const List: GDScript = preload("res://kernel/dungeon/dungeons.gd")
const UI: GDScript = preload("res://kernel/dungeon/look_ui.gd")
const Watch: GDScript = preload("res://kernel/dungeon/watch.gd")
const Trophies: GDScript = preload("res://kernel/world/build/trophies.gd")   # spark world-sandbox M3: the Home's trophies

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
var _watch: RefCounted = null           # L4b: kernel/dungeon/watch.gd
var _load_bar: ColorRect = null         # the load screen's moving bar
var _load_step: Label = null
var _load_frames: int = 0
var _pause_asked: bool = false           # K5 (1.25): the pack paused itself during its load: the pause starts with frame 0


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
	if bool(o.get("watch", true)):
		_watch = Watch.new()
		var trip: String = str(o.get("trip", "user://dungeon_trip_%d.json" % OS.get_process_id()))
		_watch.call("start", ProjectSettings.globalize_path(trip) if trip.begins_with("user://") else trip,
			PackedStringArray(o.get("relaunch", PackedStringArray())), {"pack": str(m["id"]), "pack_dir": pack_dir, "title": title})
	run = Node.new()
	run.name = "Run"
	run.process_mode = Node.PROCESS_MODE_DISABLED    # nothing of the pack runs before its frame 0 (the load is in steps)
	add_child(run)
	life = PackLife.new()
	life.load_errors = load_errors
	life.warnings = warnings
	life.on_begin = func(phase: String) -> void:
		if _watch != null:
			_watch.call("begin", phase, frame if started else -1)
	life.on_end = func(_phase: String) -> bool:
		return bool(_watch.call("finish")) if _watch != null else true
	ctx = life.make_context(run, m, pack_dir, seed_value, frames_target if frames_target > 0 else (1 << 40), "play")
	TLContext.current = ctx                       # one pack in this process while the dungeon runs (as the worker)
	# K5 (1.25): the frame's pause and Leave, reachable from the pack (ctx.pause / resume / leave_game)
	ctx._pause_hook = func(on: bool) -> void:
		if on:
			if loaded:
				pause()
			else:
				_pause_asked = true
		else:
			_pause_asked = false
			resume()
	ctx._leave_hook = func() -> void:
		close.call_deferred("leave")              # never inside the pack's own call: close frees the pack
	life.make_scene()
	life.make_io(true)                            # a person's devices reach ctx.input
	_install_look()
	if not _headless:
		TLStandin.install_look(run)
	get_tree().node_added.connect(_on_node_added)
	var steps: Array = life.load_steps()
	PhysicsServer3D.set_active(false)                # no physics step between the load's steps: the worker loads in one frame
	for i: int in steps.size():
		_load_note(i, steps.size(), str(m["assets"][i]) if i < (m["assets"] as Array).size() else str(m["entry"]))
		await (get_tree().process_frame if _headless else RenderingServer.frame_post_draw)
		if finished:
			PhysicsServer3D.set_active(true)
			return false                               # the window was closed meanwhile
		if not bool((steps[i] as Callable).call()):
			PhysicsServer3D.set_active(true)
			var first: Dictionary = load_errors[0] if not load_errors.is_empty() else {}
			_free_pack()
			return _refuse("it did not load: %s %s" % [str(first.get("file", "")), str(first.get("message", "see the log"))])
	PhysicsServer3D.set_active(true)
	run.process_mode = Node.PROCESS_MODE_PAUSABLE
	if not _headless:
		TLStandin.install_default_ground(run, ctx.root)
	life.find_idle_scripts()
	loaded = true
	print("[dungeon] %s (%s) runs: look %s, seed %d, %s" % [title, str(m["id"]), look_used, seed_value,
		("%d frames" % frames_target) if frames_target > 0 else "until the person leaves"])
	_hide_loading()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_physics_process(true)
	if _pause_asked:
		_pause_asked = false
		pause()                                    # K5: the pack asked for it during its load (a menu before its frame 0)
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
		_halt("more than %d script errors by frame %d" % [MAX_ERRORS, frame])
		return
	if frame % CENSUS_EVERY == 0:
		life.census(frame)
	frame += 1


func _input(event: InputEvent) -> void:
	# K5 (1.25): a pack that owns its pause card reads the menu keys while paused; Esc opens the pause, then is the card's
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and paused and _pack_owns_pause() and _refused == null:
		ctx.input._menu_key("click")
		return
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if paused and _pack_owns_pause() and _refused == null:
		var menu: String = {KEY_UP: "up", KEY_DOWN: "down", KEY_LEFT: "left", KEY_RIGHT: "right", KEY_ENTER: "enter", KEY_KP_ENTER: "enter", KEY_ESCAPE: "esc"}.get(k.keycode, "")
		if menu != "":
			get_viewport().set_input_as_handled()
			ctx.input._menu_key(menu)
		return
	if k.keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	if _refused != null or not loaded:
		if _refused != null:
			_card_leave()
		return
	if paused:
		resume()
	else:
		pause()


## K5 (1.25): the pack draws its own pause card (ctx.own_pause) and has a HUD to draw it on.
func _pack_owns_pause() -> bool:
	return ctx != null and ctx.owns_pause and not ctx.huds.is_empty()


func pause() -> void:
	if paused or finished or not loaded:
		return
	if not _headless:
		_still = get_viewport().get_texture().get_image()     # the frame he saw, before the card covers it
	paused = true
	ctx.paused = true
	get_tree().paused = true
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _pack_owns_pause():
		ctx.input.menu_keys()                      # K5: a fresh list for the pack's card (the Esc that opened it is not on it)
		print("[dungeon] paused at frame %d (the pack's own card)" % frame)
		return
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
	ctx.paused = false
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
		Trophies.record(run, result, frames_target)   # M3: a person's play -> trophies.json (TLRules winner, scores)
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


## K1 round 4: the engine quits while the dungeon is still open (`--quit-after`, a quit from elsewhere): the tree is torn
## down without close(). Leaving the watchdog thread running and the script logger registered crashed the process on exit
## (exit 139, every dungeon, 4 of 4 runs). Stop and free them here, the pack's teardown included; nothing is printed or emitted.
func _exit_tree() -> void:
	if finished:
		return
	finished = true
	if loaded and life != null:
		life.teardown()
	_free_pack()


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
	if _watch != null:
		_watch.call("stop")
		_watch = null
	loaded = false
	# the default look again (TL_STYLE, else crisp): what the menu and the world are drawn with
	TLStyle.load_style(TLStyle._chosen_path())


## The dungeon stops itself (more than 20 script errors): headless it ends; in a window the game stands still under a
## card that says why, with Leave.
func _halt(why: String) -> void:
	problem = "%s stopped: %s" % [title, why]
	print("[dungeon] " + problem)
	if _headless:
		close("error")
		return
	set_physics_process(false)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refused = _make_card(problem, "error")
	_layer.add_child(_refused)


## L4b: the process started by the watchdog for a dungeon it stopped (boot.gd --tripped=<record>): the card that says
## so, with Leave (or the caller's `back`). Leave emits `left("tripped")`.
func open_tripped(record_file: String, o: Dictionary = {}) -> void:
	_headless = DisplayServer.get_name() == "headless"
	back_label = str(o.get("back", "Leave"))
	_layer = CanvasLayer.new()
	_layer.name = "DungeonCards"
	_layer.layer = 110
	add_child(_layer)
	var rec: Variant = JSON.parse_string(FileAccess.get_file_as_string(record_file)) if FileAccess.file_exists(record_file) else null
	var r: Dictionary = rec if rec is Dictionary else {}
	if FileAccess.file_exists(record_file):
		DirAccess.remove_absolute(record_file)       # read once: the card holds it now (--out keeps it)
	title = str(r.get("title", "The game"))
	result = {"schema": "thirdlife.dungeon/1", "kind": "dungeon", "trip": r}
	if r.has("pack"):
		result["pack"] = str(r["pack"])
	var what: String = "its setup" if not str(r.get("phase", "")).ends_with("_tick") else "one step of the game (frame %d)" % int(r.get("frame", -1))
	problem = "%s was stopped by the watchdog: %s did not return within %s of processor time." % [title, what,
		"250 ms" if str(r.get("phase", "")).ends_with("_tick") else "10 s"] if not r.is_empty() else "the game was stopped by the watchdog (no record at %s)" % record_file
	print("[dungeon] card: %s | button: %s" % [problem, back_label])
	_refused = _make_card(problem, "tripped")
	_layer.add_child(_refused)


func _refuse(why: String) -> bool:
	problem = "%s cannot be opened as a dungeon: %s" % [title if not title.is_empty() else pack_dir, why]
	print("[dungeon] " + problem)
	_hide_loading()
	if _headless:
		close.call_deferred("refused")
		return false
	_refused = _make_card(problem, "refused")
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
	var track: ColorRect = ColorRect.new()                  # the bar moves every drawn frame, also between the load's steps
	track.color = Color(UI.colors()["ink"], 0.15)
	track.custom_minimum_size = Vector2(560, 14)
	track.clip_contents = true
	_load_bar = ColorRect.new()
	_load_bar.color = UI.colors()["accent"]
	_load_bar.size = Vector2(120, 14)
	track.add_child(_load_bar)
	v.add_child(track)
	_load_step = UI.label("checking the game", 20)
	v.add_child(_load_step)
	card.add_child(v)
	_loading.add_child(_centered(card))
	_layer.add_child(_loading)


func _load_note(i: int, n: int, file: String) -> void:
	if _load_step != null:
		_load_step.text = "%s  (%d of %d: %s)" % ["building its parts" if i < n - 1 else "setting up the game", i + 1, n, file]


## The load screen's bar: a block that sweeps the track, one step per drawn frame (a picture, not a clock).
func _process(_delta: float) -> void:
	if paused and not finished and _pack_owns_pause():
		for h: Variant in ctx.huds:                # K5 (1.25): the pack draws its own pause card, once a drawn frame
			if is_instance_valid(h):
				(h as TLHud)._paused_tick(frame)
	if _loading == null or _load_bar == null:
		return
	_load_frames += 1
	var w: float = (_load_bar.get_parent() as Control).size.x
	_load_bar.position.x = fmod(float(_load_frames) * 16.0, w + 120.0) - 120.0


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


## A card with the title, why, and one button (Leave or the caller's `back`). `kind`: refused, error (the game stands
## still behind it) or tripped. Leave ends the dungeon with `left(kind)`.
func _make_card(text: String, kind: String) -> Control:
	var root: Control = _full()
	root.name = "Card_" + kind
	if kind == "error":
		var dim: ColorRect = ColorRect.new()
		dim.color = Color(UI.colors()["ink"], 0.55)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(dim)
	else:
		root.add_child(UI.sky_backdrop())
	var card: PanelContainer = UI.card()
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(760, 0)
	v.add_child(UI.label(title if not title.is_empty() else "This game", 40))
	var why: Label = UI.label(text, 22)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(why)
	var back: Button = UI.button(back_label)
	back.name = "Leave"
	_card_kind = kind
	back.pressed.connect(_card_leave)
	v.add_child(back)
	card.add_child(v)
	root.add_child(_centered(card))
	back.grab_focus.call_deferred()
	return root


var _card_kind: String = "refused"


func _card_leave() -> void:
	print("[dungeon] card: %s pressed" % back_label)
	result["card"] = {"kind": _card_kind, "text": problem, "button": back_label, "pressed": true}
	close(_card_kind)
