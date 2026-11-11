extends RefCounted
## P9. What an exported build can and cannot do, measured (the table of docs/EXE.md is this file's output from the
## editor binary and from the exe, side by side). Started by boot.gd: `-- probe --out=<abs file>`.
## Every answer is a fact of THIS process: no assumption is written down as a result.

const CpuClock: GDScript = preload("res://kernel/host/cpuclock.gd")
const Manifest: GDScript = preload("res://kernel/runner/manifest.gd")

var rows: Array = []


func _row(id: String, value: Variant, note: String = "") -> void:
	var r: Dictionary = {"id": id, "value": value}
	if not note.is_empty():
		r["note"] = note
	rows.append(r)


func run(boot: Node, out: String) -> void:
	var exe_dir: String = OS.get_executable_path().get_base_dir().replace("\\", "/")
	var games: String = str(boot.get("games_dir"))
	_row("exported", bool(boot.call("exported")))
	_row("features", {"editor": OS.has_feature("editor"), "template": OS.has_feature("template"), "release": OS.has_feature("release"),
		"debug": OS.has_feature("debug"), "thirdlife_exe": OS.has_feature("thirdlife_exe")})
	_row("godot", str(Engine.get_version_info().get("string", "")))
	_row("main_scene_setting", str(ProjectSettings.get_setting("application/run/main_scene")))
	_row("globalize res://", ProjectSettings.globalize_path("res://"), "the project folder under the editor binary; EMPTY in the exe, so every globalize_path(res://...) of the kernel finds nothing there")
	_row("user dir", OS.get_user_data_dir())
	_row("display", DisplayServer.get_name())
	_row("physics_engine", str(ProjectSettings.get_setting("physics/3d/physics_engine")))

	# 1. files inside the pack file
	_row("res json: file_exists kernel/world/tiers.json", FileAccess.file_exists("res://kernel/world/tiers.json"))
	_row("res json: bytes kernel/data/materials.json", FileAccess.get_file_as_string("res://kernel/data/materials.json").length())
	_row("res json: bytes style/style.json", FileAccess.get_file_as_string("res://style/style.json").length())
	_row("res json: bytes boot/village.json", FileAccess.get_file_as_string("res://boot/village.json").length())
	_row("res gd as a file: file_exists kernel/host/host.gd", FileAccess.file_exists("res://kernel/host/host.gd"))
	_row("res gd as text: bytes kernel/host/host.gd", FileAccess.get_file_as_string("res://kernel/host/host.gd").length(), "0 = the source text is not in the build (binary tokens)")
	_row("res gd as a resource: exists kernel/host/host.gd", ResourceLoader.exists("res://kernel/host/host.gd"))
	_row("class cache as a disk file beside res://", FileAccess.file_exists(ProjectSettings.globalize_path("res://").trim_suffix("/") + "/.godot/global_script_class_cache.cfg"),
		"host.gd _ensure_import asks exactly this; false = it would start the executable again with --import")
	_row("class cache inside the build", FileAccess.file_exists("res://.godot/global_script_class_cache.cfg"))
	_row("global classes known", ProjectSettings.get_global_class_list().size())
	_row("shader loads: style/shaders/toon.gdshader", load("res://style/shaders/toon.gdshader") != null)

	# 2. the engine's own packs (seeds/ and kernel/examples/ carry .gdignore)
	_row("res://seeds/seed_drive/pack.json file_exists", FileAccess.file_exists("res://seeds/seed_drive/pack.json"))
	_row("res://seeds/seed_drive/scripts/main.gd resource exists", ResourceLoader.exists("res://seeds/seed_drive/scripts/main.gd"))
	_row("res://kernel/examples/ex_car/pack.json file_exists", FileAccess.file_exists("res://kernel/examples/ex_car/pack.json"))
	_row("Manifest.resolve_dir(res://seeds/seed_drive)", str(Manifest.call("resolve_dir", "res://seeds/seed_drive")), "empty = the kernel does not find the pack")

	# 3. a pack that IS inside the project (res://boot/probe/inner): by res:// path
	_row("inner pack: file_exists res://boot/probe/inner/pack.json", FileAccess.file_exists("res://boot/probe/inner/pack.json"))
	_row("inner pack: file_exists res://boot/probe/inner/scripts/main.gd", FileAccess.file_exists("res://boot/probe/inner/scripts/main.gd"),
		"pack.gd and tl_context.gd ask FileAccess.file_exists before load()")
	var inner: GDScript = load("res://boot/probe/inner/scripts/main.gd") as GDScript
	_row("inner pack: load(res://.../main.gd)", inner != null and inner.can_instantiate())
	if inner != null and inner.can_instantiate():
		var io: Object = inner.new()
		_row("inner pack: script runs", str(io.call("answer")))
		if io is Node:
			(io as Node).free()
	_row("inner pack: DirAccess lists res://boot/probe/inner/scripts", _list("res://boot/probe/inner/scripts"))
	_row("inner pack: Manifest.resolve_dir(res://boot/probe/inner)", str(Manifest.call("resolve_dir", "res://boot/probe/inner")),
		"empty = the kernel cannot load a pack from inside the pack file as it is written today")
	_row("inner pack: dir_exists_absolute(res://boot/probe/inner)", DirAccess.dir_exists_absolute("res://boot/probe/inner"))

	# 4. a .gd file from a folder outside the pack file, written now, never seen by the export
	var ext_dir: String = OS.get_user_data_dir().replace("\\", "/") + "/boot/probe_ext_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(ext_dir + "/scripts")
	_write(ext_dir + "/scripts/helper.gd", "extends RefCounted\nstatic func twice(x: int) -> int:\n\treturn x * 2\n")
	_write(ext_dir + "/scripts/main.gd", "extends Node\n## written at run time by the probe\nvar Helper: GDScript = load(get_script().resource_path.get_base_dir() + \"/helper.gd\")\n"
		+ "func answer() -> String:\n\tvar ctx: TLContext = TLContext.new()\n\tvar v: Vector3 = Vector3(1, 2, 3) * float(Helper.call(\"twice\", 21))\n"
		+ "\treturn \"ext ok %d %s %s\" % [int(v.x), str(ctx != null), str(TLKit != null)]\n")
	_write(ext_dir + "/scripts/broken.gd", "extends Node\nfunc answer() -> String:\n\treturn 1 +\n")
	var t0: int = Time.get_ticks_usec()
	var ext: GDScript = load(ext_dir + "/scripts/main.gd") as GDScript
	_row("outside .gd: load(<abs path>/main.gd) compiles", ext != null and ext.can_instantiate(), "%.1f ms" % (float(Time.get_ticks_usec() - t0) / 1000.0))
	if ext != null and ext.can_instantiate():
		var eo: Node = ext.new()
		_row("outside .gd: runs, loads its sibling, uses kernel classes by name", str(eo.call("answer")))
		eo.free()
	var broken: GDScript = load(ext_dir + "/scripts/broken.gd") as GDScript
	_row("outside .gd: a file with a parse error", "refused, the process lives" if broken == null or not broken.can_instantiate() else "LOADED")
	var src: GDScript = GDScript.new()
	src.source_code = "extends RefCounted\nfunc answer() -> int:\n\treturn 6 * 7\n"
	var rc: Error = src.reload()
	_row("GDScript compiled from a string", (str((src.new() as RefCounted).call("answer")) if rc == OK else "error %d" % rc))
	for f: String in ["scripts/main.gd", "scripts/helper.gd", "scripts/broken.gd", "scripts", ""]:
		DirAccess.remove_absolute(ext_dir + ("/" + f if not f.is_empty() else ""))

	# 5. the games folder beside the exe
	_row("games dir", games)
	_row("games dir: folders", _dirs(games) if not games.is_empty() else [])
	_row("exe dir writable", _writable(exe_dir))

	# 6. helper processes: the processor clock of the watchdogs (kernel/host/cpuclock.gd starts PowerShell)
	var cpu: RefCounted = CpuClock.new()
	var c0: int = Time.get_ticks_msec()
	cpu.call("start", OS.get_process_id())
	cpu.call("wait_settled", 8000)
	var settle_ms: int = Time.get_ticks_msec() - c0
	_row("cpuclock: helper available", bool(cpu.get("available")), "settled in %d ms" % settle_ms)
	if bool(cpu.get("available")):
		var hp: int = int(cpu.get("_helper_pid"))
		var burn: int = Time.get_ticks_usec()
		var x: float = 0.0
		while Time.get_ticks_usec() - burn < 120000:
			x += sin(x)
		_row("cpuclock: used_ms after a 120 ms busy loop", snappedf(float(cpu.call("used_ms", burn, Time.get_ticks_usec())), 0.1))
		var o: Array = []
		OS.execute("powershell", PackedStringArray(["-NoProfile", "-NonInteractive", "-Command", "(Get-Process -Id %d).MainWindowHandle" % hp]), o, true)
		_row("cpuclock: helper's window handle", ("".join(PackedStringArray(o))).strip_edges(), "0 = the helper shows no console window")
	cpu.call("stop")

	# 7. drawing
	if DisplayServer.get_name() != "headless":
		_row("rendering driver", RenderingServer.get_current_rendering_driver_name())
		_row("rendering method", RenderingServer.get_current_rendering_method())
		_row("video adapter", RenderingServer.get_video_adapter_name())

	var text: String = JSON.stringify({"schema": "thirdlife.exe/1", "kind": "probe", "rows": rows}, "  ", false)
	print(text)
	if out.is_absolute_path():
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		_write(out, text + "\n")
	boot.get_tree().quit(0)


func _write(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()


func _writable(dir: String) -> bool:
	var p: String = "%s/.tl_probe_%d" % [dir, OS.get_process_id()]
	var f: FileAccess = FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(p)
	return true


func _list(dir: String) -> Array:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return ["<cannot open>"]
	var out: Array = Array(d.get_files())
	out.sort()
	return out


func _dirs(dir: String) -> Array:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return ["<cannot open>"]
	var out: Array = Array(d.get_directories())
	out.sort()
	return out
