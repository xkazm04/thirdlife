extends Control
## L3 (night of 21 Nov 2026): a stand-alone host for the Create page, driven from the fixture job logs
## (ui/fixtures/create/). Nothing is started: the page runs with a dry door; Try it and Play only record their command
## line. Arguments after `--`:
##   --mode=stills --shots=<abs dir>    one JPG per state at the window's size (1280 x 720), and the words of each
##                                      screen ("[create] words <state> <n>"); then quit
##   --mode=clip                        click through idea -> designing -> pitch -> tap tap -> Build it -> building ->
##                                      phase done -> Try it -> Pass -> done with input events (record it with
##                                      --write-movie); then quit
##   --mode=open                        the page on its own (idea), to look at
##   --mode=live --jobs=<abs dir> --flags=<abs json> [--sentence=<text>] [--timeout=<s>]
##                                      the page with a real Foreman (no dry door, the real clock): Go, wait for the
##                                      pitch, Build it, wait for done (or failed), one line per screen it meets
##                                      ("[create] live <screen> ..."); Play is recorded, not started; exit 0 at done
##   --mode=phases --job=<abs job dir> --flags=<abs json> [--shots=<abs dir>]
##                                      a job that stops after each phase (`foreman init-fixture <dir> --phases` of the
##                                      designer v2 Foreman; TL_FOREMAN_CLI names its cli.js): the page's own buttons
##                                      Try it (recorded), Pass, Hold + note, Pass ... until done; one line per screen
##   --mode=menu --menu [--shots=<abs dir>]   the exe's own main menu (res://boot/boot.tscn, L4's boot/hub.gd): click
##                                      Create, the page opens; click its Menu button, `closed` brings the menu back
##   --mode=iterate --menu --job=<abs job dir> --flags=<abs json> [--shots=<abs dir>] [--grow=<text>] [--change=<text>]
##                                      E4 (24-25 Nov): the person's path through iterations on a real Foreman (the
##                                      phases fixture made by foreman/dist/testing/grow-steps.js: fake adapter, fake
##                                      runner): Continue, Pass x3, done; a change that grows the game, done version 2;
##                                      a change to a package, done version 3; Play (recorded); Add to menu; My games
##                                      and reopen; the main menu's Dungeons with the game in it. TL_USER_DUNGEONS
##                                      names the person's list (the caller gives a scratch file); exit 0 when all held
##   --fixtures=<abs dir>               default res://ui/fixtures/create
##   --try-stub=<abs pack dir>          the pack Try it / Play would open (default: the seed seed_wall)

const Create = preload("res://ui/create/create.tscn")
const Model = preload("res://ui/create/create_model.gd")
const JobModel = preload("res://ui/job_model.gd")

const NOW: float = 1763751000.0          # 2026-11-21T19:30:00Z: a fixed clock for every still

var args: Dictionary = {}
var page: Control = null
var fixtures: String = ""
var shots: String = ""


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var eq: int = a.find("=")
			args[a.substr(2) if eq < 0 else a.substr(2, eq - 2)] = "1" if eq < 0 else a.substr(eq + 1)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_window().title = "Third Life: Create"
	fixtures = str(args.get("fixtures", ProjectSettings.globalize_path("res://ui/fixtures/create"))).trim_suffix("/")
	shots = str(args.get("shots", "")).trim_suffix("/")
	if str(args.get("mode", "")) != "menu":
		_new_page()
	match str(args.get("mode", "open")):
		"stills": _stills()
		"clip": _clip()
		"live": _live()
		"phases": _phases()
		"menu": _menu()
		"iterate": _iterate()
		"pauses": await (load("res://ui/create/stage_pauses.gd") as GDScript).new().drive(self)   # E4b


func _new_page() -> void:
	if page != null:
		page.free()
	page = Create.instantiate()
	var stub: String = str(args.get("try-stub", ProjectSettings.globalize_path("res://seeds/seed_wall")))
	if str(args.get("mode", "")) in ["live", "phases", "iterate", "pauses"]:
		var f: Variant = JobModel.read_json(str(args.get("flags", "")))
		var o: Dictionary = {"jobs": str(args.get("jobs", "")), "flags": (f as Dictionary).get("flags", {}) if f is Dictionary else {}}
		if args.has("repo"):
			# E4: the door as an exported build meets it (res:// is no folder; the exe in <repo>/dist/ThirdLife), as selftest 780
			o["door"] = {"res_dir": "", "exe": str(args["repo"]).path_join("dist/ThirdLife/ThirdLife.exe")}
		page.call("setup", o)
	else:
		page.call("setup", {"jobs": fixtures, "dry": true, "now": NOW, "try_stub": stub, "flags": {"new": ["--adapter", "fake"]}})
	add_child(page)
	page.call("open")


## Frames pass; in the clip the page's fixed clock moves with them (60 per second), so its timers run.
func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame
		if str(args.get("mode", "")) == "clip":
			(page.get("opts") as Dictionary)["now"] = float((page.get("opts") as Dictionary)["now"]) + 1.0 / 60.0


func _shot(name_: String) -> void:
	await _frames(4)
	if not shots.is_empty():
		await RenderingServer.frame_post_draw          # E4: no picture asked (a headless run): no wait for a drawn frame
	if page != null:
		var words: Dictionary = Model.screen_words(page)
		print("[create] words %s %d  %s" % [name_, int(words["total"]), JSON.stringify(words["items"])])
	if shots.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(shots)
	var img: Image = get_viewport().get_texture().get_image()
	img.save_jpg(shots.path_join(name_ + ".jpg"), 0.9)
	print("[create] still %s" % shots.path_join(name_ + ".jpg"))


## A fixture's directory; the page's clock is set 42 s after the fixture's last event (a live-looking elapsed time).
func _fx(name_: String) -> String:
	var dir: String = fixtures.path_join(name_)
	var j: Dictionary = JobModel.reduce(JobModel.read_events(dir)["events"], 0.0)
	(page.get("opts") as Dictionary)["now"] = float(j["last_ts"]) + 42.0
	return dir


func _stills() -> void:
	await _frames(3)
	await _shot("1-idea")
	page.set("sentence", "penguins pushing each other off an iceberg")
	page.call("set_creativity", "crazy")
	await _shot("1b-idea-crazy")
	page.set("drawer_open", true)
	page.call("_rebuild")
	await _shot("1c-idea-drawer")
	page.call("go")
	await _shot("2a-designing-before-the-job")
	page.call("show_job", _fx("c1-designing"))
	await _shot("2-designing")
	page.call("show_job", _fx("c2-pitch"))
	await _shot("3-pitch")
	page.call("tap", "player")
	page.call("tap", "player")
	page.call("tap", "cannon")
	page.call("tap", "cannon")
	page.call("tap", "cannon")
	await _shot("3b-pitch-tapped")
	page.call("expand", "orca")
	await _shot("3c-pitch-tell-me-more")
	page.call("show_job", _fx("c4-redesigned"))
	await _shot("3d-pitch-redesigned")
	page.call("show_job", _fx("c5-building"))
	await _shot("4-building")
	page.call("show_job", _fx("c6-phase-done"))
	await _shot("5-phase-done")
	page.set("holding", true)
	page.call("_rebuild")
	await _shot("5b-phase-hold-note")
	page.call("show_job", _fx("c7-held"))
	await _shot("4b-building-held")
	page.call("show_job", _fx("c8-phase2"))
	await _shot("4c-building-phase2")
	page.call("show_job", _fx("c9-done"))
	await _shot("6-done")
	page.call("show_job", _fx("c10-failed"))
	await _shot("7-failed")
	page.call("show_job", _fx("c11-design-failed"))
	await _shot("7b-design-failed")
	get_tree().quit(0)


# ---- the clip: real mouse events on the page's own buttons

## A drawn pointer (a recorded movie has no system cursor): it glides to each click and rings when it presses.
class Pointer extends Control:
	var ring: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(40, 40)
		z_index = 100

	func _draw() -> void:
		if ring > 0.0:
			draw_arc(Vector2.ZERO, 14.0 + (1.0 - ring) * 26.0, 0, TAU, 40, Color(1, 0.85, 0.3, ring), 5.0, true)
		var tip: PackedVector2Array = [Vector2(0, 0), Vector2(0, 30), Vector2(8, 23), Vector2(14, 36), Vector2(20, 33), Vector2(14, 21), Vector2(24, 21)]
		draw_colored_polygon(tip, Color.WHITE)
		var outline: PackedVector2Array = tip.duplicate()
		outline.append(tip[0])
		draw_polyline(outline, Color("#1b1d32"), 2.5, true)


var pointer: Pointer = null


func _glide(to: Vector2, frames: int) -> void:
	if pointer == null:
		pointer = Pointer.new()
		pointer.position = Vector2(640, 600)
		add_child(pointer)
	var from: Vector2 = pointer.position
	for i: int in frames:
		var t: float = float(i + 1) / float(frames)
		pointer.position = from.lerp(to, t * t * (3.0 - 2.0 * t))
		move_child(pointer, get_child_count() - 1)
		var move: InputEventMouseMotion = InputEventMouseMotion.new()
		move.position = pointer.position
		move.global_position = pointer.position
		Input.parse_input_event(move)
		await get_tree().process_frame


func _click(path: String) -> void:
	var n: Node = page.find_child(path, true, false)
	if n == null or not (n is Control):
		print("[create] clip: no %s" % path)
		return
	var c: Control = n
	var at: Vector2 = c.get_global_transform_with_canvas() * (c.size * 0.5)
	await _glide(at, 18)
	await _frames(4)
	pointer.ring = 1.0
	for pressed: bool in [true, false]:
		var e: InputEventMouseButton = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = at
		e.global_position = at
		Input.parse_input_event(e)
		await _frames(2)
	for i: int in 12:
		pointer.ring = maxf(0.0, pointer.ring - 1.0 / 12.0)
		pointer.queue_redraw()
		await get_tree().process_frame
	print("[create] clip: clicked %s" % path)


func _type(text: String) -> void:
	for ch: String in text:
		var e: InputEventKey = InputEventKey.new()
		e.pressed = true
		e.unicode = ch.unicode_at(0)
		e.keycode = KEY_SPACE if ch == " " else KEY_A
		Input.parse_input_event(e)
		var up: InputEventKey = e.duplicate()
		up.pressed = false
		Input.parse_input_event(up)
		await _frames(2)


func _clip() -> void:
	await _frames(30)
	await _click("Sentence")
	await _type("penguins pushing each other off an iceberg")
	await _frames(20)
	await _click("Crazy")
	await _frames(30)
	await _click("Go")
	await _frames(60)
	page.call("show_job", _fx("c1-designing"))
	await _frames(90)
	page.call("show_job", _fx("c2-pitch"))
	await _frames(60)
	await _click("Card_player")
	await _frames(20)
	await _click("Card_player")
	await _frames(30)
	await _click("Card_cannon")
	await _frames(15)
	await _click("Card_cannon")
	await _frames(15)
	await _click("Card_cannon")
	await _frames(30)
	await _click("More_orca")
	await _frames(70)
	await _click("SheetDone")
	await _frames(30)
	await _click("BuildIt")
	await _frames(45)
	page.call("show_job", _fx("c5-building"))
	await _frames(100)
	page.call("show_job", _fx("c6-phase-done"))
	await _frames(60)
	await _click("TryIt")
	await _frames(40)
	await _click("Pass")
	await _frames(40)
	page.call("show_job", _fx("c8-phase2"))
	await _frames(90)
	page.call("show_job", _fx("c9-done"))
	await _frames(90)
	await _click("Play")
	await _frames(40)
	print("[create] clip: launch %s" % " ".join(page.get("last_launch")))
	var door: RefCounted = page.get("door")
	for s: Variant in door.get("dry_steps"):
		print("[create] clip: door %s" % JSON.stringify(s))
	get_tree().quit(0)


# ---- live: a real Foreman behind the page

func _live() -> void:
	var t0: int = Time.get_ticks_msec()
	var limit: int = int(args.get("timeout", "900")) * 1000
	var seen: String = ""
	await _frames(10)
	page.set("sentence", str(args.get("sentence", "a marble run with three marbles")))
	page.call("go")
	var built: bool = false
	while Time.get_ticks_msec() - t0 < limit:
		await get_tree().create_timer(0.5).timeout
		var shown: String = page.call("shown_screen")
		var job: Dictionary = page.get("job")
		if shown != seen:
			seen = shown
			print("[create] live %s at %.1f s: job %s, %d events, words %d, message '%s'" % [shown, float(Time.get_ticks_msec() - t0) / 1000.0,
				str(job.get("id", "-")), int(job.get("n_events", 0)), int(Model.screen_words(page)["total"]), str(page.get("message"))])
			if not shots.is_empty():
				await _shot("live-" + shown)
		if shown == "pitch" and not built:
			built = true
			await _frames(30)
			page.call("build_it")
		elif shown == "done":
			(page.get("door") as RefCounted).set("dry", true)
			page.call("launch", Model.play_dir(job))
			print("[create] live play: %s" % " ".join(page.get("last_launch")))
			get_tree().quit(0)
			return
		elif shown in ["failed", "error"]:
			print("[create] live stopped: %s" % str(job.get("fail_line", job.get("error", ""))))
			get_tree().quit(1)
			return
	print("[create] live: no end in %d s (screen %s)" % [limit / 1000, seen])
	get_tree().quit(2)


# ---- phases: a real phased job, the page's own buttons

func _press(name_: String) -> bool:
	var b: Node = page.find_child(name_, true, false)
	if b == null or not (b is BaseButton) or not (b as CanvasItem).is_visible_in_tree():
		print("[create] phases: no %s button on %s" % [name_, str(page.call("shown_screen"))])
		return false
	(b as BaseButton).pressed.emit()
	return true


func _phases() -> void:
	var t0: int = Time.get_ticks_msec()
	await _frames(10)
	page.call("show_job", str(args.get("job", "")))
	var verdicts: Array = ["pass", "hold", "pass", "pass"]      # phase 1 pass, phase 2 held once then passed, phase 3 pass
	var seen: String = ""
	var last_seq: int = -1
	while Time.get_ticks_msec() - t0 < 600000:
		await get_tree().create_timer(0.5).timeout
		var shown: String = page.call("shown_screen")
		var job: Dictionary = page.get("job")
		var key: String = "%s/%s" % [shown, str(job.get("phase_wait", ""))]
		if key != seen:
			seen = key
			print("[create] phases %s at %.1f s: %d events, %s, phase_wait '%s', words %d, message '%s'" % [shown, float(Time.get_ticks_msec() - t0) / 1000.0,
				int(job.get("n_events", 0)), Model.phase_line(job), str(job.get("phase_wait", "")), int(Model.screen_words(page)["total"]), str(page.get("message"))])
			if not shots.is_empty():
				await _shot("phases-%02d-%s" % [int(job.get("n_events", 0)) % 100, shown])
		if shown == "phase_done" and int(job.get("last_seq", 0)) != last_seq and str(page.get("busy")).is_empty():
			last_seq = int(job.get("last_seq", 0))
			(page.get("door") as RefCounted).set("dry", true)
			_press("TryIt")
			(page.get("door") as RefCounted).set("dry", false)
			print("[create] phases try: %s" % " ".join(page.get("last_launch")))
			var v: String = str(verdicts.pop_front()) if not verdicts.is_empty() else "pass"
			if v == "hold":
				_press("Hold")
				await _frames(2)
				var nb: LineEdit = page.find_child("HoldNote", true, false)
				nb.text = "the rival is too slow, make it chase harder"
				_press("SendHold")
			else:
				_press("Pass")
			var steps: Array = (page.get("door") as RefCounted).get("started")
			print("[create] phases %s pressed (door: %s)" % [v, str(steps.back().get("label", "")) if not steps.is_empty() else "nothing"])
		elif shown == "done":
			print("[create] phases done: Play -> %s" % Model.play_dir(job))
			get_tree().quit(0)
			return
		elif shown in ["failed", "error"] or not str(page.get("message")).is_empty():
			print("[create] phases stopped: %s / %s" % [str(job.get("fail_line", "")), str(page.get("message"))])
			get_tree().quit(1)
			return
	get_tree().quit(2)


# ---- menu: the main menu mounts the page and gets it back

func _click_node(n: Node) -> void:
	var c: Control = n
	var at: Vector2 = c.get_global_transform_with_canvas() * (c.size * 0.5)
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	Input.parse_input_event(move)
	await _frames(6)
	for pressed: bool in [true, false]:
		var e: InputEventMouseButton = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = at
		e.global_position = at
		Input.parse_input_event(e)
		await _frames(2)


func _find_visible(root: Node, name_: String) -> Node:
	for n: Node in root.find_children(name_, "", true, false):
		if n is CanvasItem and (n as CanvasItem).is_visible_in_tree():
			return n
	return null


func _menu() -> void:
	var boot: Node = (load("res://boot/boot.tscn") as PackedScene).instantiate()
	add_child(boot)
	await _frames(60)
	var create_b: Node = _find_visible(boot, "Create")
	print("[create] menu: Create button %s" % ("found" if create_b != null else "MISSING"))
	if not shots.is_empty():
		await _shot("menu-1-menu")
	if create_b == null:
		get_tree().quit(1)
		return
	await _click_node(create_b)
	await _frames(30)
	var pg: Node = _find_visible(boot, "Create")       # the page's root is named Create (create.tscn)
	var opened: bool = pg != null and pg.has_method("open") and pg.has_signal("closed")
	print("[create] menu: after Create the page is %s" % ("open" if opened else "NOT open"))
	if not shots.is_empty():
		await _shot("menu-2-create")
	if not opened:
		get_tree().quit(1)
		return
	var back: Node = _find_visible(pg, "Back")
	await _click_node(back)
	await _frames(30)
	var gone: bool = not is_instance_valid(pg) or not (pg as CanvasItem).is_visible_in_tree()
	var again: Node = _find_visible(boot, "Create")
	var menu_back: bool = gone and again != null and not again.has_method("open")
	print("[create] menu: after the page's Menu button the page is %s and the menu is %s" % ["gone" if gone else "STILL THERE", "back" if menu_back else "NOT back"])
	if not shots.is_empty():
		await _shot("menu-3-back")
	get_tree().quit(0 if menu_back else 1)


# ---- iterate (E4): done -> change -> a new version -> Play; My games -> reopen; Add to menu -> the menu

var _it_ok: bool = true
var _it_t0: int = 0


func _it_say(what: String, ok: bool) -> void:
	_it_ok = _it_ok and ok
	print("[create] iterate %s %s (frame %d)" % ["PASS" if ok else "FAIL", what, Engine.get_process_frames() - _it_t0])


## Waits until `want` holds, counted in frames (each frame also sleeps 10 ms, as selftest 780: `limit_s` * 100 frames
## is about `limit_s` seconds for the Foreman's processes to answer).
func _it_wait(want: Callable, limit_s: float) -> bool:
	for i: int in int(limit_s * 100.0):
		if want.call():
			return true
		await get_tree().process_frame
		OS.delay_msec(10)
	if not str(page.get("message")).is_empty():
		print("[create] iterate toast: %s" % str(page.get("message")))
	return want.call()


func _iterate() -> void:
	_it_t0 = Engine.get_process_frames()
	var grow_text: String = str(args.get("grow", "add rocket skates: hold the boost key to fly forward"))
	var change_text: String = str(args.get("change", "the rallies are too slow: make the court smaller"))
	await _frames(10)
	var dir: String = str(args.get("job", ""))
	var screen_is: Callable = func(s: String) -> bool: return page.call("shown_screen") == s
	page.call("show_job", dir)
	await _frames(4)
	_it_say("reopened job shows the build with Continue (no Foreman)", page.call("shown_screen") == "building" and page.find_child("Continue", true, false) != null)
	await _shot("it-01-continue")
	_press("Continue")
	for i: int in 3:
		var at: bool = await _it_wait(func() -> bool: return screen_is.call("phase_done") and not bool(page.get("settling")), 240.0)
		_it_say("phase %d waits for the person" % (i + 1), at)
		if i == 0:
			await _shot("it-02-phase-done")
		_press("Pass")
		await _frames(10)
	var done1: bool = await _it_wait(func() -> bool: return screen_is.call("done"), 300.0)
	_it_say("version 1 is ready", done1 and Model.version_n(page.get("job")) == 1)
	await _shot("it-03-done-v1")
	for round_: Array in [[grow_text, 2, "grow"], [change_text, 3, "change"]]:
		var box: LineEdit = page.find_child("ChangeBox", true, false)
		if box == null:
			_it_say("change box on done", false)
			break
		box.text = str(round_[0])
		box.text_changed.emit(box.text)
		await _shot("it-%02d-typed-%s" % [int(round_[1]) * 2, str(round_[2])])
		_press("SendChange")
		var building: bool = await _it_wait(func() -> bool: return screen_is.call("building") and page.find_child("Changing", true, false) != null, 60.0)
		_it_say("%s round shows Changing: <words>" % str(round_[2]), building)
		await _frames(30)
		await _shot("it-%02d-changing-%s" % [int(round_[1]) * 2 + 1, str(round_[2])])
		var back: bool = await _it_wait(func() -> bool: return screen_is.call("done") and str(page.get("busy")).is_empty() and Model.version_n(page.get("job")) == int(round_[1]), 300.0)
		_it_say("%s round ends with version %d" % [str(round_[2]), int(round_[1])], back)
		await _shot("it-%02d-done-v%d" % [int(round_[1]) * 2 + 2, int(round_[1])])
	var job: Dictionary = page.get("job")
	var pk: Dictionary = job.get("packages", {})
	_it_say("the grow round added the package rocket; the change round re-opened court", pk.has("rocket") and str((pk["rocket"] as Dictionary).get("state", "")) == "promoted")
	(page.get("door") as RefCounted).set("dry", true)
	_press("Play")
	(page.get("door") as RefCounted).set("dry", false)
	var launch: String = " ".join(page.get("last_launch"))
	_it_say("Play opens the newest version (%s)" % launch, launch.contains("@0.1.2"))
	_press("AddMenu")
	await _frames(4)
	_it_say("Add to menu: the game is in the person's list", page.find_child("RemoveMenu", true, false) != null)
	await _shot("it-08-in-menu")
	page.call("new_idea")
	await _frames(4)
	_press("MyGames")
	await _frames(4)
	_it_say("My games lists the job", page.call("shown_screen") == "games" and page.find_child("Game0", true, false) != null)
	await _shot("it-09-my-games")
	_press("Game0")
	await _frames(4)
	_it_say("a row reopens the game where it stands (done, version 3)", page.call("shown_screen") == "done" and str(page.get("job_dir")) == dir)
	await _shot("it-10-reopened")
	# the main menu: Dungeons lists the game (the person's list beside engine/boot/dungeons.json)
	page.queue_free()
	page = null
	if DisplayServer.get_name() == "headless":
		# the menu needs a window: headless (selftest 781) reads the rows boot/hub.gd's load_rows() reads
		var List: GDScript = load("res://kernel/dungeon/dungeons.gd")
		var listed: bool = false
		for r: Dictionary in List.call("read_menu")["dungeons"]:
			if r.get("mine", false) == true and str(r["title"]) == str(job.get("title", "?")) and not str(List.call("resolve", str(r["pack"]), "")).is_empty():
				listed = true
		_it_say("the main menu's rows (read_menu, headless) list the game, playable", listed)
		print("[create] iterate %s" % ("all held" if _it_ok else "NOT all held"))
		get_tree().quit(0 if _it_ok else 1)
		return
	var boot: Node = (load("res://boot/boot.tscn") as PackedScene).instantiate()
	add_child(boot)
	await _frames(60)
	var menu: Node = null
	for n: Node in boot.find_children("*", "", true, false):
		if n.has_method("_show_list"):
			menu = n
			break
	if menu != null:
		menu.call("_show_list")
	await _frames(20)
	var seen: bool = false
	for b: Node in boot.find_children("Dungeon*", "Button", true, false):
		if (b as Button).text.contains("made by you in Create") and (b as Button).text.contains(str(job.get("title", "?"))) and not (b as Button).disabled:
			seen = true
	_it_say("the main menu's Dungeons lists the game, playable", seen)
	await _shot("it-11-menu-dungeons")
	print("[create] iterate %s" % ("all held" if _it_ok else "NOT all held"))
	get_tree().quit(0 if _it_ok else 1)
