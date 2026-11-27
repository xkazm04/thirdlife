extends RefCounted
## M6 round 3, lane T (27 Nov 2026): the stamp tool's sharing, moved out of tools/stamp_tool.gd (its 600-line cap):
## the share code (Ctrl+C copies, Ctrl+V pastes: contracts/BUILD.md "Courses travel"), the .tlitem export (X) and the
## inbox import (I), the shipped starter courses (res://kernel/world/build/starters/*.json, read-only, listed first),
## and a placed course's run name (when the Home already has a run of that name the tool asks once: `run_clash`,
## `next_run`, `renamed`). Static; `t` is the stamp tool (its `host`, `stamps`, `current`, `reason`, `note`).

const StampFile := preload("res://kernel/world/build/stamp_file.gd")
const Check := preload("res://kernel/world/build/rules_check.gd")
const Bar := preload("res://kernel/world/build/command_bar.gd")
const STARTERS := "res://kernel/world/build/starters"


## The starter courses shipped with the game: stamp_file.gd `list` entries with "starter": true, sorted by slug.
static func starters() -> Array:
	var out := []
	for e: Dictionary in StampFile.list(STARTERS).stamps:
		var s := e.duplicate()
		s["starter"] = true
		out.append(s)
	return out


## Ctrl+C: the current stamp's share code to the clipboard (headless: `t.fake_clip`). Returns the code, or "".
static func copy(t: RefCounted) -> String:
	var d: Dictionary = t.call("stamp")
	if d.is_empty():
		t.set("reason", "choose a stamp to copy")
		return ""
	var code := StampFile.code_of(d)
	t.set("copied", code)
	if DisplayServer.get_name() == "headless":
		t.set("fake_clip", code)
	else:
		DisplayServer.clipboard_set(code)
	t.set("note", "copied: a code of %d characters" % code.length())
	var host: Node = t.get("host")
	print(JSON.stringify({"schema": "tl.view/1", "kind": "build_stamp", "copied": str(d.name), "chars": code.length(), "code": code if host.call("scripted") else ""}, "", false))
	return code


## Ctrl+V: a share code from the clipboard, read as a stamp file is, saved with the stamps and made current. Returns ""
## or why it was refused.
static func paste(t: RefCounted) -> String:
	var text: String = str(t.get("fake_clip")) if DisplayServer.get_name() == "headless" else DisplayServer.clipboard_get()
	var r: Dictionary = StampFile.from_code(text)
	var dir: String = t.call("stamps_dir")
	var w: Dictionary = {"ok": false, "reason": str(r.reason)}
	if bool(r.ok):
		w = StampFile.save(dir, r.stamp) if dir != "" else {"ok": false, "reason": "no Home file here"}
	if not bool(w.ok):
		t.set("reason", "paste refused: %s" % str(w.reason))
		return str(t.get("reason"))
	_made_current(t, str(w.path))
	t.set("reason", "")
	t.set("note", "pasted %s (%d zones, %d rules)" % [str(r.stamp.name), (r.stamp.get("zones", []) as Array).size(), (r.stamp.get("rules", []) as Array).size()])
	print(JSON.stringify({"schema": "tl.view/1", "kind": "build_stamp", "pasted": str(w.path), "chars": text.strip_edges().length()}, "", false))
	return ""


static func _made_current(t: RefCounted, path: String) -> void:
	t.call("refresh")
	var stamps: Array = t.get("stamps")
	for i: int in stamps.size():
		if str(stamps[i].path) == path:
			t.set("current", i)


## X: the current stamp as <stamps>/export/<slug>.tlitem. Returns its path, or "".
static func export_current(t: RefCounted) -> String:
	var i: int = t.get("current")
	var dir: String = t.call("stamps_dir")
	if i < 0 or dir == "":
		t.set("reason", "choose a stamp to export")
		return ""
	var path := dir.path_join("export").path_join(str((t.get("stamps") as Array)[i].slug) + ".tlitem")
	var r: Dictionary = StampFile.export_item(t.call("stamp"), path)
	t.set("reason", "" if bool(r.ok) else str(r.reason))
	if bool(r.ok):
		t.set("note", "exported %s" % path.get_file())
		print(JSON.stringify({"schema": "tl.view/1", "kind": "build_stamp", "exported": path, "bytes": int(r.bytes)}, "", false))
	return path if bool(r.ok) else ""


## I: every .tlitem in <stamps>/inbox: a good one becomes a stamp and leaves the inbox; a bad one stays and its reason
## is shown. Returns how many were imported.
static func import_inbox(t: RefCounted) -> int:
	var dir: String = t.call("stamps_dir")
	var da := DirAccess.open(dir.path_join("inbox")) if dir != "" else null
	if da == null:
		return 0
	var inbox := dir.path_join("inbox")
	var n := 0
	var names: Array = Array(da.get_files())
	names.sort()
	for f: String in names:
		if f.get_extension() != "tlitem":
			continue
		var r: Dictionary = StampFile.import_item(inbox.path_join(f))
		if bool(r.ok):
			var w: Dictionary = StampFile.save(dir, r.stamp)
			if bool(w.ok):
				DirAccess.remove_absolute(inbox.path_join(f))
				n += 1
				continue
			r.reason = w.reason
		t.set("reason", "%s: %s" % [f, str(r.reason)])
		print(JSON.stringify({"schema": "tl.view/1", "kind": "build_stamp", "refused": f, "reason": str(r.reason)}, "", false))
	if n > 0:
		t.set("note", "imported %d" % n)
		t.call("refresh")
	return n


# ------------------------------------------------------------------ a placed course's run name
## The runs the Home's rules start (rules_layer.gd `rules`), as a set.
static func home_runs(build: RefCounted) -> Dictionary:
	var out := {}
	var rl: RefCounted = build.layer("rules") if build != null else null
	if rl == null:
		return out
	for n: int in rl.get("rules"):
		for e: Dictionary in rl.get("rules")[n].do:
			if str(e.do) == "start":
				out[str(e.run)] = true
	return out


## The first run name the `rule` ops in `ops` start that the Home already has, or "" (no clash: nothing to ask).
static func run_clash(build: RefCounted, ops: Array) -> String:
	var have := home_runs(build)
	for op: Variant in ops:
		if op is Dictionary and str((op as Dictionary).get("op", "")) == "rule":
			for e: Dictionary in (op as Dictionary).get("do", []):
				if str(e.get("do", "")) == "start" and have.has(str(e.run)):
					return str(e.run)
	return ""


## "<name> (n)" with the next n from 2 the Home has no run of, cut to fit 24 characters.
static func next_run(build: RefCounted, name: String) -> String:
	var have := home_runs(build)
	for n: int in range(2, 10000):
		var tail := " (%d)" % n
		var s := name.left(Check.NAME_MAX - tail.length()) + tail
		if not have.has(s):
			return s
	return name


## `ops` with every `start` effect naming run `old` renamed `new` (the rest untouched, deep copies).
static func renamed(ops: Array, old: String, new: String) -> Array:
	var out := []
	for op: Variant in ops:
		if op is Dictionary and str((op as Dictionary).get("op", "")) == "rule":
			var d: Dictionary = (op as Dictionary).duplicate(true)
			for e: Dictionary in d.get("do", []):
				if str(e.get("do", "")) == "start" and str(e.run) == old:
					e["run"] = new
			out.append(d)
		else:
			out.append(op)
	return out


## The run-name field (the tool's `run_bar`, made once): prefilled with the next free "<name> (n)", selected.
static func ask_run(t: RefCounted, clash: String) -> void:
	var host: Node = t.get("host")
	var bar: CanvasLayer = t.get("run_bar")
	if bar == null or not is_instance_valid(bar):
		bar = Bar.new()
		bar.name = "StampRun"
		host.add_child(bar)
		bar.submitted.connect(func(text: String) -> void: run_named(t, text, true))
		bar.cancelled.connect(func() -> void: run_named(t, "", false))
		t.set("run_bar", bar)
	bar.call("open", "This course's run is called %s, like one you have. Enter: its own run   Esc: share %s's best time" % [clash, clash],
		next_run(host.get("build"), clash), Check.NAME_MAX, "a name for this course's run")


## The field closed: Enter (`rename`) places the waiting course with run name `text` (empty: the proposed one), Esc
## with the shared name. Either way ONE batch (the tool's `_put`).
static func run_named(t: RefCounted, text: String, rename: bool) -> void:
	(t.get("run_bar") as CanvasLayer).call("close")
	t.set("_latched", true)
	var p: Dictionary = t.get("_placing")
	t.set("_placing", {})
	if p.is_empty():
		return
	var build: RefCounted = (t.get("host") as Node).get("build")
	var ops: Array = p.ops
	var clean := ""
	for ch: String in text.replace("
", " ").strip_edges():
		if Check.printable(ch, 1):
			clean += ch
	if rename:
		ops = renamed(ops, str(p.run), (clean if clean != "" else next_run(build, str(p.run))).left(Check.NAME_MAX))
	t.call("_put", ops, p.cell)
	t.set("note", "its own run" if rename else "shares the record of %s" % str(p.run))


## The stamp's zones where they would go, from dry run `r` (the rules layer's ghost; none when it has no zones).
static func zone_ghost(t: RefCounted, r: Dictionary) -> void:
	var host: Node = t.get("host")
	var g: Node3D = t.get("zghost")
	if g == null or not is_instance_valid(g):
		g = Node3D.new()
		g.name = "StampZones"
		host.add_child(g)
		t.set("zghost", g)
	for c: Node in g.get_children():
		g.remove_child(c)
		c.queue_free()
	var rl: RefCounted = (host.get("build") as RefCounted).call("layer", "rules")
	if rl != null and (t.call("stamp") as Dictionary).has("zones") and (r.get("scratch", {}) as Dictionary).has("rules"):
		var n: Node3D = rl.preview_node(r.scratch.rules)
		if n != null:
			g.add_child(n)
	g.visible = true
