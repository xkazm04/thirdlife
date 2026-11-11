extends RefCounted
## V0 + V1 lint. Works on text only: no pack code is loaded or run. Comments and string contents are blanked before
## matching (positions are preserved, so every finding has a file and a line).
## No global class names are used here (see manifest.gd).

const Manifest: GDScript = preload("res://kernel/runner/manifest.gd")

const MAX_SCRIPT_LINES: int = 600
const MAX_PACK_LINES: int = 6000
const MAX_DATA_BYTES: int = 2 * 1024 * 1024
const TOP_LEVEL: Array = ["pack.json", "scripts", "data", "gen", "assets", "tests", "examples", "preview"]
## Files allowed at the pack root. item.json is the sharing card (docs/SHARING.md); preview/ holds its pictures.
const ROOT_FILES: Array = ["pack.json", "README.md", "item.json"]
const SCRIPT_DIRS: Array = ["scripts", "gen", "tests", "examples"]
const LOAD_PREFIXES: Array = ["res://kits/", "res://rigs/", "res://style/", "res://kernel/api/"]

## N4: every file of a pack is classed, wherever it sits. The same table gives a shared item its tier
## (kernel/share/item.gd): only inert files make a `data` item.
##   script  .gd: read by the fence, in any directory
##   inert   cannot carry code the engine would run: JSON, text, raster pictures
##   ignored written by the engine or the version tool beside real files; never part of a pack's content
##   other   everything else (scenes, resources, shaders, libraries, archives, unknown types): the fence cannot read
##           it and the engine may execute it, so a pack may not hold it
const INERT_EXT: Array = ["json", "md", "txt", "png", "jpg", "jpeg", "webp"]
const IGNORED_NAMES: Array = [".gitkeep", ".gdignore"]
const IGNORED_EXT: Array = ["uid", "import"]
const NODE_PATH_CALLS: String = "(?<![\\w])(get_node|get_node_or_null|has_node|get_node_and_resource|NodePath)\\s*\\(\\s*|\\$\\s*"

## [regex, label, hint]. The first block is the contract's list (PACK.md); the block marked "kernel extension" closes
## obvious holes in the same spirit (other doors to the global random generator) and is listed in API.md.
const FENCE: Array = [
	["(?m)^[ \\t]*class_name\\b", "class_name", "pack scripts never declare a global class"],
	["@tool\\b", "@tool", ""],
	["(?<![\\w.])OS\\b", "OS.", ""],                       # N4: the bare name too (`var o = OS`)
	["\\bFileAccess\\b", "FileAccess", "read data/ with ctx.read_json()"],
	["\\bDirAccess\\b", "DirAccess", ""],
	["\\bResourceSaver\\b", "ResourceSaver", ""],
	["\\bProjectSettings\\b", "ProjectSettings.", ""],    # N4: the bare name too
	["\\bEngine\\s*\\.\\s*get_singleton\\b", "Engine.get_singleton", ""],
	["\\bClassDB\\b", "ClassDB.", ""],                    # N4: the bare name too
	["\\bHTTPRequest\\b", "HTTPRequest", ""],
	["\\bHTTPClient\\b", "HTTPClient", ""],
	["\\bStreamPeer\\w*", "StreamPeer", ""],
	["\\bTCPServer\\b", "TCPServer", ""],
	["\\bUDPServer\\b", "UDPServer", ""],
	["\\bPacketPeer\\w*", "PacketPeer", ""],
	["\\bWebSocketPeer\\b", "WebSocketPeer", ""],
	["\\bENetConnection\\b", "ENetConnection", ""],
	["\\bThread\\b", "Thread", ""],
	["\\bMutex\\b", "Mutex", ""],
	["\\bSemaphore\\b", "Semaphore", ""],
	["\\bJavaScriptBridge\\b", "JavaScriptBridge", ""],
	["\\bExpression\\b", "Expression", ""],
	["\\bGDScript\\s*\\.\\s*new\\b", "GDScript.new", ""],
	["\\bstr_to_var\\b", "str_to_var", ""],
	["\\bbytes_to_var\\w*", "bytes_to_var", ""],
	["get_tree\\s*\\(\\s*\\)\\s*\\.\\s*root\\b", "get_tree().root", "build under ctx.root"],
	["\\bchange_scene\\w*", "change_scene", ""],
	["get_tree\\s*\\(\\s*\\)\\s*\\.\\s*quit\\b", "get_tree().quit", ""],
	["\\bTime\\s*\\.\\s*get_ticks\\w*", "Time.get_ticks", "time is ctx.frame (60 per second)"],
	["\\bTime\\s*\\.\\s*get_unix\\w*", "Time.get_unix", "time is ctx.frame (60 per second)"],
	["(?<![\\w.])randf\\s*\\(", "randf(", "use ctx.rng"],
	["(?<![\\w.])randi\\s*\\(", "randi(", "use ctx.rng"],
	["(?<![\\w.])randomize\\s*\\(", "randomize(", "use ctx.rng"],
	# kernel extension
	["(?<![\\w.])randf_range\\s*\\(", "randf_range(", "use ctx.rng (kernel extension of the fence)"],
	["(?<![\\w.])randi_range\\s*\\(", "randi_range(", "use ctx.rng (kernel extension of the fence)"],
	["(?<![\\w.])randfn\\s*\\(", "randfn(", "use ctx.rng (kernel extension of the fence)"],
	["\\.\\s*shuffle\\s*\\(", ".shuffle(", "uses the global generator; use ctx.shuffle() (kernel extension of the fence)"],
	["\\.\\s*pick_random\\s*\\(", ".pick_random(", "uses the global generator; use ctx.pick() (kernel extension of the fence)"],
	["\\bWorkerThreadPool\\b", "WorkerThreadPool", "kernel extension of the fence"],
	# ---- N4 (2026-11-11): the holes a scout found. No seed, kernel example or promoted pack needs any of these.
	# reflection: a name in a string is invisible to a text check
	["(?<![\\w])call\\b", "call(", "reflection: call the method by its name (N4)"],
	["(?<![\\w])callv\\b", "callv(", "reflection: call the method by its name (N4)"],
	["(?<![\\w])call_deferred\\b", "call_deferred(", "reflection: call the method by its name (N4)"],
	["(?<![\\w])(call_group|call_group_flags|propagate_call|propagate_notification)\\b", "call_group(", "reflection (N4)"],
	["(?<![\\w])Callable\\s*(\\(|\\.\\s*create\\b)", "Callable(", "reflection: write the method itself, obj.method (N4)"],
	["\\.\\s*set\\b", ".set(", "reflection: assign the property, obj.name = value; d[key] = value for a Dictionary (N4)"],
	["(?<![\\w])(set_deferred|set_indexed)\\b", "set_deferred(", "reflection: assign the property (N4)"],
	["\\bset_script\\b", "set_script", "make the node from its script: ctx.load_script(path).new() (N4)"],
	["\\.\\s*script\\s*=(?!=)", ".script =", "make the node from its script: ctx.load_script(path).new() (N4)"],
	["\\.\\s*source_code\\b", ".source_code", "a script is a file of the pack, never text built at run time (N4)"],
	["\\.\\s*reload\\b", ".reload(", "a script is a file of the pack, never text built at run time (N4)"],
	["\\b(instance_from_id|dict_to_inst)\\b", "instance_from_id", "N4"],
	# engine classes that read or write files, open the network, or reach past the kernel
	["\\bResourceLoader\\b", "ResourceLoader", "use ctx.load_script() and ctx.read_json() (N4)"],
	["\\bConfigFile\\b", "ConfigFile", "N4"],
	["\\bZIP(Reader|Packer)\\b", "ZIPReader/ZIPPacker", "N4"],
	["\\bPCKPacker\\b", "PCKPacker", "N4"],
	["\\bXMLParser\\b", "XMLParser", "N4"],
	["\\bload_from_file\\b", "load_from_file", "pictures are built in memory (Image.create) or come from the kit (N4)"],
	["\\.\\s*(save_(png|jpg|exr|webp)\\w*|save_to_wav)\\b", "Image.save_*", "a pack writes no files (N4)"],
	["\\bPackedScene\\b", "PackedScene", "a scene file can carry scripts lint cannot read (N4)"],
	["\\bMarshalls\\b", "Marshalls", "N4"],
	["\\bMultiplayer\\w+", "Multiplayer*", "N4"],
	["\\bENetMultiplayerPeer\\b", "ENetMultiplayerPeer", "N4"],
	["\\bWebRTC\\w*", "WebRTC*", "N4"],
	["\\bget_multiplayer\\b|(?<![\\w])multiplayer\\s*\\.|(?<![\\w])rpc(_id)?\\s*\\(|@rpc\\b", "multiplayer", "N4"],
	["\\b(Crypto\\w*|HashingContext|AESContext|HMACContext|X509Certificate|TLSOptions)\\b", "Crypto", "N4"],
	["\\bDisplayServer\\b", "DisplayServer", "N4"],
	["\\bRenderingServer\\b", "RenderingServer", "N4"],
	["\\bRenderingDevice\\b", "RenderingDevice", "N4"],
	["\\bPhysicsServer[23]D\\w*", "PhysicsServer", "bodies come from TLBodies (N4)"],
	["\\bAudioServer\\b", "AudioServer", "sound goes through TLAudio (N4)"],
	["\\bPerformance\\b", "Performance", "N4"],
	["(?<![\\w.])Input\\b", "Input.", "input goes through ctx.input, the door a bot uses too (N4)"],
	["(?<![\\w.])InputMap\\b", "InputMap", "input goes through ctx.input (N4)"],
	["\\bEngine\\b(?!\\s*\\.\\s*get_singleton\\b)", "Engine.", "N4"],
	["\\bTime\\s*\\.\\s*get_(datetime|date|time)\\w*", "Time.get_datetime", "time is ctx.frame (60 per second) (N4)"],
	# the scene tree above the pack
	["\\bget_tree\\b(?!\\s*\\(\\s*\\)\\s*\\.\\s*(root\\b|quit\\b|change_scene))", "get_tree()", "the pack lives under ctx.root (N4)"],
	["\\bget_root\\b", "get_root(", "build under ctx.root (N4)"],
	["\\b(get_parent|find_parent)\\b", "get_parent(", "a parent chain leaves ctx.root (N4)"],
	["\\bget_(window|viewport)\\b", "get_window()/get_viewport()", "the window is the tree's root (N4)"],
	# the same doors by another name: a singleton or a class kept in a variable, a method taken without calling it
	["(?<![\\w.])Time\\b(?!\\s*\\.)", "Time (as a value)", "time is ctx.frame (N4)"],
	["(=|\\(|,|\\[|\\breturn)\\s*GDScript\\b(?!\\s*\\.\\s*new\\b)", "GDScript (as a value)", "N4"],
	# more engine classes that read files, record, or resolve names on the network
	["(?<![\\w.])IP\\b", "IP", "N4"],
	["\\bCamera(Server|Feed)\\b", "CameraServer", "N4"],
	["\\bAudioStreamMicrophone\\b|\\bAudioEffect(Capture|Record)\\b", "microphone", "N4"],
	["\\bGDExtension\\w*", "GDExtension", "N4"],
	["\\b(GLTF|FBX)\\w+", "GLTF/FBX", "N4"],
	["\\bload_(dynamic|bitmap)_font\\b", "load_dynamic_font", "N4"],
	["(?<![\\w.])(load|preload)\\b(?!\\s*\\()", "load (as a value)", "N4"],
	["\\bWebSocket(?!Peer\\b)\\w+", "WebSocket*", "N4"],
	["\\bENet(?!Connection\\b|MultiplayerPeer\\b)\\w+", "ENet*", "N4"],
	["\\b(UPNP\\w*|DTLSServer|SceneMultiplayer)\\b", "UPNP/DTLSServer/SceneMultiplayer", "N4"],
	["\\b(Java(?!ScriptBridge\\b)\\w+|JNISingleton|EngineDebugger)\\b", "JavaClassWrapper/EngineDebugger", "N4"],
	["\\b(FileDialog|LinkButton)\\b", "FileDialog/LinkButton", "a pack opens no file chooser and no web address (N4)"],
	# ---- P7 (2026-11-11): the fence follows the seam: no device read past ctx.input, no clock but the tick count, no other pack's nodes
	["\\bInputEvent\\w+", "InputEvent*", "a device event read past ctx.input is not in the input record (P7)"],
	["(?m)^[ \\t]*func\\s+_(unhandled_key_input|shortcut_input|gui_input)\\s*\\(", "_gui_input handler", "input goes through ctx.input (P7)"],
	["\\bset_process_(unhandled_key_|unhandled_|shortcut_)?input\\b", "set_process_input", "the kernel switches a pack's event handlers off; input goes through ctx.input (P7)"],
	["\\b(get_(global|local)_mouse_position|warp_mouse|get_mouse_position)\\b", "mouse position", "the pointer is ctx.input (TLInput.LOOK_X, LOOK_Y, ZOOM) (P7)"],
	["\\b(Button|CheckBox|CheckButton|OptionButton|MenuButton|TextureButton|LineEdit|TextEdit|CodeEdit|SpinBox|HSlider|VSlider|ItemList|TabBar|PopupMenu|ColorPicker\\w*)\\s*\\.\\s*new\\b", "a control that takes clicks or keys", "it reads a device past ctx.input; text and bars on screen are TLHud (P7)"],
	["\\baccept_devices\\b", "accept_devices", "the kernel decides when devices are read (P7)"],
	["(?m)^[ \\t]*func\\s+_process\\s*\\(", "_process", "it runs once per drawn picture, not once per tick: the game's code runs in _pack_tick (or _physics_process), 60 times a second (P7)"],
	["\\bget_(physics_)?process_delta_time\\b", "get_process_delta_time", "time is ctx.frame (60 per second) (P7)"],
	["\\b(create_tween|Tween|Tweener|AnimationPlayer|AnimationTree|SceneTreeTimer)\\b", "Tween/AnimationPlayer", "it runs on the engine's clock, not on the tick count; move things in _pack_tick (P7)"],
	["\\bTimer\\b", "Timer", "it runs on the engine's clock; count frames, or use the clock of TLRules (P7)"],
	["\\bget_world_3d\\b", "get_world_3d()", "the world belongs to every pack in it; ask TLLaws.surface_under or a TLTrigger (P7)"],
	["\\.\\s*holder\\b(?!\\s*\\()", ".holder", "the node above the pack is the kernel's; the pack lives under ctx.root (P7)"],
	["ctx\\s*\\.\\s*_\\w+|\\.\\s*(input|cameras)\\s*\\.\\s*_\\w+", "a private member of the kernel", "names that start with _ are the kernel's side of ctx (P7)"],
	["\\bTLContext\\s*\\.\\s*(current|enter|leave)\\b", "TLContext.current", "the pack being called is the kernel's business; a pack keeps the ctx it was given (P7)"],
	["\\b(get_nodes_in_group|get_first_node_in_group|get_node_count_in_group)\\b", "get_nodes_in_group", "a group spans every pack of the world; keep your own list (P7)"],
]

## [regex, primitive that exists for it, pattern label]
const BYPASS: Array = [
	["\\bRigidBody3D\\s*\\.\\s*new\\s*\\(", "TLBodies.make / TLBall", "RigidBody3D.new()"],
	["\\bCharacterBody3D\\s*\\.\\s*new\\s*\\(", "TLBiped", "CharacterBody3D.new()"],
	["\\bVehicleBody3D\\s*\\.\\s*new\\s*\\(", "TLVehicle", "VehicleBody3D.new()"],
	["\\bArea3D\\s*\\.\\s*new\\s*\\(", "TLBodies.trigger", "Area3D.new()"],
	["\\bCamera3D\\s*\\.\\s*new\\s*\\(", "TLCameras", "Camera3D.new()"],
	["\\bAudioStreamPlayer\\w*\\s*\\.\\s*new\\s*\\(", "TLAudio", "AudioStreamPlayer*.new()"],
	["\\bTimer\\s*\\.\\s*new\\s*\\(", "TLRules (clock in frames)", "Timer.new()"],
	["\\b[GC]PUParticles3D\\s*\\.\\s*new\\s*\\(", "TLVfx", "Particles3D.new()"],
	["\\.\\s*apply_(central_|torque_)?impulse\\s*\\(", "TLBodies.push / TLBall.shoot", "apply_impulse"],
	["\\.\\s*apply_(central_)?force\\s*\\(", "TLBodies.push / TLVehicle", "apply_force"],
	["\\bmove_and_slide\\s*\\(", "TLBiped", "move_and_slide"],
	["(?m)^[ \\t]*func\\s+_(unhandled_)?input\\s*\\(", "TLInput (ctx.input)", "_input handler"],
]
## WP5b (Director's decision of 2026-11-10): look and geometry made by hand. The kernel and the style give materials,
## light and environment (primitive `style`, counted in scripts/, gen/ and tests/); geometry comes from the kit or from
## TLBodies.make (primitive `kit`, counted in scripts/ and tests/ only: a generator under gen/ that builds geometry is
## counted once by `kit_parts_added`, never twice). A row with "match" as its fourth entry labels the hit by its own text.
const BYPASS_STYLE: Array = [
	["\\b(StandardMaterial3D|ShaderMaterial|ORMMaterial3D)\\s*\\.\\s*new\\s*\\(", "style", "", "match"],
	["\\b(DirectionalLight3D|OmniLight3D|SpotLight3D|WorldEnvironment|Environment)\\s*\\.\\s*new\\s*\\(", "style", "", "match"],
]
const BYPASS_GEOMETRY: Array = [
	["\\b(Box|Sphere|Cylinder|Capsule|Plane|Prism|Quad|Torus|Text|Point|Array|Immediate)Mesh\\s*\\.\\s*new\\s*\\(", "kit", "", "match"],
	["\\bMeshInstance3D\\s*\\.\\s*new\\s*\\(", "kit", "", "match"],
]
const BYPASS_RULES: Array = [
	["(?m)^[ \\t]*var\\s+_?(score|scores|clock|timer|time_left|period|periods|lap|laps)\\w*\\b", "TLRules",
		"hand-rolled score or clock"],
]

## capability -> regex of kernel names that need it
const CAPABILITY_USE: Dictionary = {
	"physics": "\\bTL(Bodies|Trigger|Laws|Contact|Damage)\\b",
	"input": "\\bTLInput\\b|\\.\\s*input\\b",
	"ui": "\\bTLHud\\b",
	"audio": "\\bTLAudio\\b",
	"vfx": "\\bTLVfx(Node)?\\b",
	"camera": "\\bTL(Cameras|ChaseCam|OrbitCam)\\b|\\.\\s*cameras\\b",
	"rules": "\\bTLRules\\b",
	"ai": "\\bTLSteer\\b",
	"spawn": "\\bTLSpawner\\b",
	"fracture": "\\bTLFracture\\b",
	"vehicle": "\\bTLVehicle\\b",
	"biped": "\\bTLBiped\\b",
	"ball": "\\bTLBall\\b",
	"kit": "\\bTLKit\\b|\\bTLRigs\\b",
	"style": "\\bTLStyle\\b",
}
const GEOMETRY_RE: String = "\\b(ArrayMesh|SurfaceTool|ImmediateMesh|MeshDataTool|\\w+Mesh\\s*\\.\\s*new|CSG\\w+|MeshInstance3D\\s*\\.\\s*new)\\b"


## Blanks comments and string contents; same length as the input, newlines kept.
static func strip(src: String) -> String:
	var out: PackedStringArray = PackedStringArray()
	var n: int = src.length()
	var i: int = 0
	var run_start: int = 0
	while i < n:
		var c: String = src[i]
		if c == "#":
			out.append(src.substr(run_start, i - run_start))
			var e: int = src.find("\n", i)
			if e < 0:
				e = n
			out.append(" ".repeat(e - i))
			i = e
			run_start = i
		elif c == "\"" or c == "'":
			var q: String = c
			if i + 2 < n and src[i + 1] == c and src[i + 2] == c:
				q = c + c + c
			out.append(src.substr(run_start, i - run_start))
			out.append(q)
			i += q.length()
			var body: PackedStringArray = PackedStringArray()
			var closed: bool = false
			while i < n:
				var d: String = src[i]
				if d == "\\" and i + 1 < n:
					body.append(" \n" if src[i + 1] == "\n" else "  ")
					i += 2
				elif d == c and (q.length() == 1 or (i + 2 < n and src[i + 1] == c and src[i + 2] == c)):
					closed = true
					break
				elif d == "\n":
					if q.length() == 1:
						break
					body.append("\n")
					i += 1
				else:
					body.append(" ")
					i += 1
			out.append("".join(body))
			if closed:
				out.append(q)
				i += q.length()
			run_start = i
		else:
			i += 1
	out.append(src.substr(run_start, n - run_start))
	return "".join(out)


static func _line_starts(text: String) -> PackedInt32Array:
	var starts: PackedInt32Array = PackedInt32Array([0])
	var at: int = text.find("\n")
	while at >= 0:
		starts.append(at + 1)
		at = text.find("\n", at + 1)
	return starts


static func _line_at(starts: PackedInt32Array, pos: int) -> int:
	var idx: int = starts.bsearch(pos, false)
	return idx


static func _list_files(dir: String, rel: String, out: Array) -> void:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return
	var names: Array = Array(d.get_files())
	names.sort()
	for f: String in names:
		out.append(rel + f)
	var dirs: Array = Array(d.get_directories())
	dirs.sort()
	for s: String in dirs:
		_list_files(dir + "/" + s, rel + s + "/", out)


static func _code_lines(code: String) -> int:
	var count: int = 0
	for line: String in code.split("\n"):
		if not line.strip_edges().is_empty():
			count += 1
	return count


## Returns {manifest, checks[], errors[], composability}. Never throws; a missing pack.json is a schema error.
static func run(pack_dir: String) -> Dictionary:
	var errors: Array = []
	var checks: Array = []
	var mres: Dictionary = Manifest.read(pack_dir)
	var m: Dictionary = mres["manifest"]
	errors.append_array(mres["errors"])
	checks.append({"id": "lint.schema", "ok": mres["ok"], "detail": _detail(mres["errors"], "manifest matches tl.pack/0.1")})

	# ---- layout
	var lay: Array = []
	var top: DirAccess = DirAccess.open(pack_dir)
	if top != null:
		for f: String in top.get_files():
			# README.md: what the pack shows, for the next author (WP4 brief: every seed carries one)
			if not ROOT_FILES.has(f) and not f.begins_with("."):
				lay.append({"kind": "layout", "file": f, "message": "unexpected file at the pack root (allowed: pack.json, README.md, item.json and the directories %s)" % ", ".join(PackedStringArray(TOP_LEVEL.slice(1)))})
		for s: String in top.get_directories():
			if not TOP_LEVEL.has(s) and not s.begins_with("."):
				lay.append({"kind": "layout", "file": s + "/", "message": "unexpected directory at the pack root"})
	for need: String in ["scripts", "tests"]:
		if not DirAccess.dir_exists_absolute(pack_dir + "/" + need):
			lay.append({"kind": "layout", "file": need + "/", "message": "required directory is missing"})
	var refs: Array = []
	if typeof(m.get("entry")) == TYPE_STRING:
		refs.append(["entry", m["entry"]])
	for key: String in ["assets", "tests"]:
		if typeof(m.get(key)) == TYPE_ARRAY:
			for p: Variant in m[key]:
				if typeof(p) == TYPE_STRING:
					refs.append([key, p])
	# a slider's file must be there (optional field `params`, PACK.md amendments of 2026-11-11)
	if typeof(m.get("params")) == TYPE_ARRAY:
		for p: Variant in m["params"]:
			if typeof(p) == TYPE_DICTIONARY and typeof((p as Dictionary).get("file")) == TYPE_STRING:
				refs.append(["params", p["file"]])
	for r: Array in refs:
		if str(r[1]).contains("..") or not FileAccess.file_exists(pack_dir + "/" + str(r[1])):
			lay.append({"kind": "layout", "file": str(r[1]), "message": "listed in '%s' but the file does not exist" % str(r[0])})
	var data_files: Array = []
	_list_files(pack_dir + "/data", "data/", data_files)
	var kit_kinds: Dictionary = {}          # N5a: kit part kind -> how many times the pack uses it (layouts and TLKit.build)
	var data_bytes: int = 0
	for f: String in data_files:
		if f.get_file().begins_with("."):
			continue
		if f.get_extension() != "json":
			lay.append({"kind": "layout", "file": f, "message": "data/ holds JSON only"})
			continue
		var text: String = FileAccess.get_file_as_string(pack_dir + "/" + f)
		data_bytes += text.to_utf8_buffer().size()
		var j: JSON = JSON.new()
		if j.parse(text) != OK:
			lay.append({"kind": "layout", "file": f, "line": j.get_error_line() + 1, "message": "not valid JSON: " + j.get_error_message()})
		elif typeof(j.data) == TYPE_DICTIONARY and str((j.data as Dictionary).get("schema", "")).begins_with("tl.layout/"):
			_count_kinds(j.data, kit_kinds)       # N5a: the kit parts a layout places
	var gd_files: Array = []
	for sd: String in SCRIPT_DIRS:
		var found: Array = []
		_list_files(pack_dir + "/" + sd, sd + "/", found)
		for f: String in found:
			if f.get_extension() == "gd":
				gd_files.append(f)
			elif sd != "examples" and f.get_extension() != "uid" and not f.get_file().begins_with("."):
				lay.append({"kind": "layout", "file": f, "message": "%s/ holds GDScript only" % sd})
	# N4: every file of the pack, hidden ones too. A script outside the four script directories (assets/, data/,
	# preview/, a dot directory, the root) is read by the fence like any other; a file that is neither a script
	# nor inert is refused, because the engine could run it and this check cannot read it.
	var reach: Array = []
	var all_files: Array = []
	list_all(pack_dir, "", all_files)
	for f: String in all_files:
		var cls: String = file_class(f)
		if cls == "script":
			if not gd_files.has(f):
				gd_files.append(f)
		elif cls == "other":
			reach.append({"kind": "fence", "file": f, "message": "a file of this type can carry code and lint cannot read it (a pack holds .gd scripts, and inert files: %s)" % ", ".join(PackedStringArray(INERT_EXT))})
	errors.append_array(lay)
	checks.append({"id": "lint.layout", "ok": lay.is_empty(), "detail": _detail(lay, "%d scripts, %d data files" % [gd_files.size(), data_files.size()])})

	# ---- per-file text checks
	var fence: Array = reach
	var node_re: RegEx = RegEx.create_from_string(NODE_PATH_CALLS)
	var caps_err: Array = []
	var size_err: Array = []
	var bypasses: Array = []
	var lines: Dictionary = {"scripts": 0, "gen": 0, "tests": 0}
	var kit_parts_added: int = 0
	var total_lines: int = 0
	var declared: Array = m.get("capabilities", []) if typeof(m.get("capabilities")) == TYPE_ARRAY else []
	var fence_re: Array = []
	for f: Array in FENCE:
		fence_re.append(RegEx.create_from_string(f[0]))
	var bypass_all: Array = BYPASS.duplicate()
	bypass_all.append_array(BYPASS_STYLE)
	var geometry_from: int = bypass_all.size()       # rows from here up to geometry_to are skipped under gen/
	bypass_all.append_array(BYPASS_GEOMETRY)
	var geometry_to: int = bypass_all.size()
	if declared.has("rules"):
		bypass_all.append_array(BYPASS_RULES)
	var bypass_re: Array = []
	for b: Array in bypass_all:
		bypass_re.append(RegEx.create_from_string(b[0]))
	var cap_re: Dictionary = {}
	for cap: String in CAPABILITY_USE.keys():
		cap_re[cap] = RegEx.create_from_string(CAPABILITY_USE[cap])
	var load_re: RegEx = RegEx.create_from_string("(?<![\\w])(load|preload)\\s*\\(\\s*")
	# N5a: figures, never findings. A pack that reads world coordinates breaks when it is not simulated at its own
	# origin (kernel/world/BENCH.md, test 5); the count tells the Foreman how far a pack is from being movable.
	var world_re: RegEx = RegEx.create_from_string("(?<![\\w])(global_position|global_transform|to_global\\s*\\(|look_at\\s*\\()")
	var kit_build_re: RegEx = RegEx.create_from_string("TLKit\\s*\\.\\s*build\\s*\\(\\s*\"([a-z0-9_]+)\"")
	var kit_call_re: RegEx = RegEx.create_from_string("TLKit\\s*\\.\\s*build\\s*\\(")
	var world_uses: Dictionary = {"global_position": 0, "global_transform": 0, "to_global": 0, "look_at": 0}
	var kit_build_calls: int = 0
	var geo_re: RegEx = RegEx.create_from_string(GEOMETRY_RE)
	var pack_res: String = ProjectSettings.localize_path(pack_dir)
	for rel: String in gd_files:
		var src: String = FileAccess.get_file_as_string(pack_dir + "/" + rel).replace("\r\n", "\n")
		var code: String = strip(src).replace("\\\n", " \n")    # N4: a line continuation is white space to the patterns
		var starts: PackedInt32Array = _line_starts(code)
		var nlines: int = starts.size() - (1 if src.ends_with("\n") else 0)
		var top_dir: String = rel.get_slice("/", 0)
		if lines.has(top_dir):
			lines[top_dir] = int(lines[top_dir]) + _code_lines(code)
		total_lines += nlines
		if nlines > MAX_SCRIPT_LINES:
			size_err.append({"kind": "size", "file": rel, "line": MAX_SCRIPT_LINES + 1, "message": "%d lines; one script may have at most %d" % [nlines, MAX_SCRIPT_LINES]})
		for k: int in fence_re.size():
			for hit: RegExMatch in (fence_re[k] as RegEx).search_all(code):
				var hint: String = FENCE[k][2]
				fence.append({"kind": "fence", "file": rel, "line": _line_at(starts, hit.get_start()),
					"message": "'%s' is outside the fence%s" % [FENCE[k][1], "" if hint.is_empty() else ": " + hint]})
		for hit: RegExMatch in load_re.search_all(code):
			var problem: String = _load_problem(src, code, hit.get_end(), pack_res, hit.get_string(1))
			if not problem.is_empty():
				fence.append({"kind": "fence", "file": rel, "line": _line_at(starts, hit.get_start()),
					"message": "%s( %s" % [hit.get_string(1), problem]})
		for hit: RegExMatch in node_re.search_all(code):
			var node_problem: String = _node_path_problem(src, code, hit.get_end(), hit.get_string().begins_with("$"))
			if not node_problem.is_empty():
				fence.append({"kind": "fence", "file": rel, "line": _line_at(starts, hit.get_start()),
					"message": "node path %s (N4)" % node_problem})
		for k: int in bypass_re.size():
			if top_dir == "gen" and k >= geometry_from and k < geometry_to:
				continue      # geometry built in a generator is the `kit_parts_added` figure, not also a bypass
			for hit: RegExMatch in (bypass_re[k] as RegEx).search_all(code):
				var pos: int = hit.get_start()
				while pos < code.length() and (code[pos] == " " or code[pos] == "\t" or code[pos] == "\n"):
					pos += 1
				var label: String = bypass_all[k][2]
				if (bypass_all[k] as Array).size() > 3 and str(bypass_all[k][3]) == "match":
					label = hit.get_string().replace(" ", "").replace("\t", "").replace("\n", "") + ")"
				bypasses.append({"primitive": bypass_all[k][1], "file": rel, "line": _line_at(starts, pos), "pattern": label})
		for cap: String in cap_re.keys():
			if declared.has(cap):
				continue
			var hit: RegExMatch = (cap_re[cap] as RegEx).search(code)
			if hit != null:
				caps_err.append({"kind": "capability", "file": rel, "line": _line_at(starts, hit.get_start()),
					"message": "uses '%s' but the manifest does not declare the capability '%s'" % [hit.get_string().strip_edges(), cap]})
		if top_dir == "gen" and geo_re.search(code) != null:
			kit_parts_added += 1
		for hit: RegExMatch in world_re.search_all(code):
			var wk: String = hit.get_string(1).replace("(", "").strip_edges()
			world_uses[wk] = int(world_uses[wk]) + 1
		kit_build_calls += kit_call_re.search_all(code).size()
		for hit: RegExMatch in kit_build_re.search_all(src):      # the kind is a string literal: read it from the source text
			kit_kinds[hit.get_string(1)] = int(kit_kinds.get(hit.get_string(1), 0)) + 1
	if total_lines > MAX_PACK_LINES:
		size_err.append({"kind": "size", "file": "scripts/", "message": "%d lines of GDScript in the pack; at most %d" % [total_lines, MAX_PACK_LINES]})
	if data_bytes > MAX_DATA_BYTES:
		size_err.append({"kind": "size", "file": "data/", "message": "%d bytes in data/; at most %d" % [data_bytes, MAX_DATA_BYTES]})
	errors.append_array(fence)
	errors.append_array(caps_err)
	errors.append_array(size_err)
	checks.append({"id": "lint.fence", "ok": fence.is_empty(), "detail": _detail(fence, "no fenced pattern in %d scripts" % gd_files.size())})
	checks.append({"id": "lint.capabilities", "ok": caps_err.is_empty(), "detail": _detail(caps_err, "every kernel capability used is declared")})
	checks.append({"id": "lint.size", "ok": size_err.is_empty(), "detail": _detail(size_err, "%d lines of GDScript, %d bytes of data" % [total_lines, data_bytes])})
	return {"manifest": m, "checks": checks, "errors": errors,
		"composability": {"gdscript_lines": lines, "kit_parts_added": kit_parts_added, "bypasses": bypasses,
			"kit_parts_used": _sum(kit_kinds), "kit_kinds_used": _sorted_keys(kit_kinds), "kit_build_calls": kit_build_calls,
			"world_coordinates": _sum(world_uses), "world_coordinates_by": world_uses}}


## N5a. Every object of a layout that names a kit part (`"kind": "<part>"`), counted by kind.
static func _count_kinds(v: Variant, into: Dictionary) -> void:
	if typeof(v) == TYPE_DICTIONARY:
		var d: Dictionary = v
		if typeof(d.get("kind")) == TYPE_STRING:
			into[str(d["kind"])] = int(into.get(str(d["kind"]), 0)) + 1
		for k: Variant in d.keys():
			_count_kinds(d[k], into)
	elif typeof(v) == TYPE_ARRAY:
		for item: Variant in (v as Array):
			_count_kinds(item, into)


static func _sum(d: Dictionary) -> int:
	var n: int = 0
	for k: Variant in d.keys():
		n += int(d[k])
	return n


static func _sorted_keys(d: Dictionary) -> Array:
	var keys: Array = d.keys()
	keys.sort()
	return keys


static func _detail(errs: Array, ok_text: String) -> String:
	if errs.is_empty():
		return ok_text
	var first: Dictionary = errs[0]
	var where: String = str(first.get("file", ""))
	if first.has("line"):
		where += ":" + str(first["line"])
	return "%d problem(s); first: %s %s" % [errs.size(), where, str(first["message"])]


## Every file under `dir`, hidden ones and dot directories included, as sorted relative paths.
static func list_all(dir: String, rel: String, out: Array) -> void:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return
	d.include_hidden = true
	d.include_navigational = false
	var names: Array = Array(d.get_files())
	names.sort()
	for f: String in names:
		out.append(rel + f)
	var dirs: Array = Array(d.get_directories())
	dirs.sort()
	for s: String in dirs:
		list_all(dir + "/" + s, rel + s + "/", out)


## "script", "inert", "ignored" or "other" (see INERT_EXT above). Decided by the file name alone.
static func file_class(rel: String) -> String:
	var fname: String = rel.get_file()
	var ext: String = fname.get_extension().to_lower() if fname.contains(".") else ""
	if IGNORED_NAMES.has(fname) or (IGNORED_EXT.has(ext) and not fname.begins_with(".")):
		return "ignored"
	if ext == "gd":
		return "script"
	if INERT_EXT.has(ext) and not fname.begins_with("."):
		return "inert"
	return "other"


## "" when the node path literal that starts at `at` stays inside the pack's own tree; otherwise the reason.
## A path that is not a literal cannot be judged by a text check and is let through (SHARE.md lists it).
static func _node_path_problem(src: String, code: String, at: int, dollar: bool = false) -> String:
	var i: int = at
	if i < code.length() and code[i] == "/":
		return "'$/...' is absolute: the pack lives under ctx.root"
	if i < code.length() and (code[i] == "&" or code[i] == "^"):
		i += 1
	if i >= code.length() or (code[i] != "\"" and code[i] != "'"):
		if dollar:
			return ""          # $Name/Child: a relative path written as names
		return "that is not a literal cannot be checked: write the path as one plain string"
	var e: int = code.find(code[i], i + 1)
	if e < 0:
		return "with an unterminated literal"
	var path: String = src.substr(i + 1, e - i - 1)
	var after: int = e + 1
	while after < code.length() and (code[after] == " " or code[after] == "\t" or code[after] == "\n"):
		after += 1
	if not dollar and after < code.length() and code[after] != ")" and code[after] != ",":
		return "built from pieces cannot be checked: write the path as one plain string"
	if path.begins_with("/"):
		return "'%s' is absolute: the pack lives under ctx.root" % path
	if path.contains(".."):
		return "'%s' climbs out with '..': the pack lives under ctx.root" % path
	return ""


## "" when the load/preload argument that starts at `at` is allowed; otherwise the reason.
static func _load_problem(src: String, code: String, at: int, pack_res: String, fn: String = "preload") -> String:
	var i: int = at
	if i < code.length() and (code[i] == "&" or code[i] == "^" or code[i] == "r"):
		i += 1
	if i >= code.length() or (code[i] != "\"" and code[i] != "'"):
		return "with a path that is not a literal: use ctx.load_script() for pack scripts"
	var q: String = code[i]
	var e: int = code.find(q, i + 1)
	if e < 0:
		return "with an unterminated literal"
	var path: String = src.substr(i + 1, e - i - 1)
	# N4: the literal must be the whole argument ("res://kits/" + anything was let through on its first half)
	var after: int = e + 1
	while after < code.length() and (code[after] == " " or code[after] == "\t" or code[after] == "\n"):
		after += 1
	if after < code.length() and code[after] != ")" and code[after] != ",":
		return "with a path built from pieces: only one plain literal can be checked"
	if path.contains(".."):
		return "of '%s': '..' is not allowed" % path
	for p: String in LOAD_PREFIXES:
		if path.begins_with(p):
			return ""
	if pack_res.begins_with("res://") and path.begins_with(pack_res + "/"):
		return ""
	if path.contains("://") or path.is_absolute_path():
		return "of '%s': only the pack itself, res://kits/, res://rigs/, res://style/ and res://kernel/api/ may be loaded" % path
	# N4: load() reads a relative path from res://, not from the pack (preload reads it beside the script)
	if fn == "load":
		return "of the relative path '%s': load() would read it from the engine's root; use ctx.load_script()" % path
	return ""
