extends RefCounted
## M4 (spark world-sandbox): the command tool's test hook, TL_COMMAND_DEVICES="<when>:<kind>[:<arg>];..." for an
## unattended exe run with captures (as build_devices.gd is build mode's). `when` is a physics frame of build mode, or
## an anchor `ask<n>+<frames>`, `ghost<n>+<frames>`, `kept<n>+<frames>` (that many frames after the n-th ask sent,
## ghost shown, answer kept). Kinds:
##   say:<sentence>     Enter, the sentence typed, Enter (the bar at the cursor, as a person sends it)
##   accept, revert     Enter or Esc on the ghost shown
##   fix                R on the ghost shown (round 2: a fix ask when the space check found problems; prints command_fix)
##   settle             Enter on the last ghost: waits until no ask is pending (a fix) and a ghost is shown
##   capture:<abs file> the window's last drawn frame as a jpg (png when the name ends in .png)
##   state              a `command_state` line          quit   the window's close request (boot ends the world)
## Sentences may not hold ";". Nothing runs when the variable is unset.

var _tool: WeakRef                      # tools/command_tool.gd (weak: the tool holds this hook)
var plan: Array = []                    # [anchor, k, frames, kind, arg, done]
var _at := {}                           # "ghost2" -> the frame it happened


func _init(t: RefCounted, text: String) -> void:
	_tool = weakref(t)
	for part: String in text.split(";", false):
		var f := part.strip_edges().split(":", true, 2)
		if f.size() < 2:
			print("[command] TL_COMMAND_DEVICES: cannot read '%s'" % part)
			continue
		var when := f[0]
		var anchor := ""
		var k := 0
		var n := 0
		if when.is_valid_int():
			n = int(when)
		else:
			var plus := when.split("+")
			for a: String in ["ask", "ghost", "kept"]:
				if plus[0].begins_with(a) and plus[0].trim_prefix(a).is_valid_int() and plus.size() == 2 and plus[1].is_valid_int():
					anchor = a
					k = int(plus[0].trim_prefix(a))
					n = int(plus[1])
			if anchor.is_empty():
				print("[command] TL_COMMAND_DEVICES: cannot read the time '%s'" % when)
				continue
		plan.append([anchor, k, n, f[1], f[2] if f.size() > 2 else "", false])



func run(frame: int) -> void:
	var tool: RefCounted = _tool.get_ref()
	if plan.is_empty() or tool == null:
		return
	for a: String in ["ask", "ghost", "kept"]:
		var count := int(tool.get({"ask": "asked", "ghost": "ghosts", "kept": "kept"}[a]))
		if count > 0 and not _at.has(a + str(count)):
			_at[a + str(count)] = frame
	for e: Array in plan:
		if bool(e[5]):
			continue
		var due := int(e[2]) if str(e[0]).is_empty() else (int(_at[str(e[0]) + str(e[1])]) + int(e[2]) if _at.has(str(e[0]) + str(e[1])) else -1)
		if due < 0 or frame < due:
			continue
		e[5] = true
		if str(e[3]) == "settle" and (not (tool.get("pending") as Array).is_empty() or (tool.get("shown") as Dictionary).is_empty()):
			e[5] = false                  # settle waits for the last ghost: no ask pending (a fix) and one shown
			continue
		_do(tool, str(e[3]), str(e[4]), frame)


func _do(tool: RefCounted, kind: String, arg: String, frame: int) -> void:
	match kind:
		"say":
			tool.call("open_bar")
			var bar: CanvasLayer = tool.get("bar")
			if bar != null and bar.call("is_open"):
				bar.get("line").text = arg
				tool.call("_on_submitted", arg)
		"accept", "settle":
			tool.call("accept")
		"fix":
			print(JSON.stringify({"schema": "tl.view/1", "kind": "command_fix", "sent": str(tool.call("fix")), "frame": frame}, "", false))
		"revert":
			tool.call("revert")
		"capture":
			var img: Image = (tool.get("host") as Node).get_viewport().get_texture().get_image()
			var err := img.save_png(arg) if arg.ends_with(".png") else img.save_jpg(arg, 0.9)
			print(JSON.stringify({"schema": "tl.view/1", "kind": "command_capture", "file": arg, "ok": err == OK, "frame": frame}, "", false))
		"state":
			print(JSON.stringify({"schema": "tl.view/1", "kind": "command_state", "frame": frame, "status": tool.call("status"),
				"pending": (tool.get("pending") as Array).size(), "shown": not (tool.get("shown") as Dictionary).is_empty()}, "", false))
		"quit":
			# the window close request, as the close button sends it (boot ends the world cleanly; a bare tree quit
			# with the world running crashed the exe at exit, measured 26 Nov)
			(tool.get("host") as Node).get_tree().root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		_:
			print("[command] TL_COMMAND_DEVICES: unknown kind '%s'" % kind)
