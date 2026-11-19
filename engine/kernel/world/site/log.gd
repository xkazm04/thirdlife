extends RefCounted
## S1. A Foreman job's log (`<job>/job.jsonl`, contracts/JOB.md) read for the construction site: the lines, checked,
## and what the site shows after the first `n` of them. Reading only: nothing in a job directory is written.
## No global class name (kernel/world is preloaded by path).
##
##   var lg = SiteLog.new(); lg.feed(text)      # every whole line of `text` not read yet (a last line without its
##                                              # newline waits: a torn write is not read)
##   var view: Dictionary = SiteLog.fold(lg.events, n)
##
## `fold` -> {stage, title, packages: [{id, title, state, round, merged}], built, total, job_state, failed, promoted}
##   stage: "none" (no `job_created` yet), "pad" (created, no plan), "bays" (a plan, nothing merged yet), "building"
##   (some merged), "merged" (every package merged), "failed" (the job's last `job_state` is `failed` or `cancelled`
##   and nothing was promoted), "promoted" (a `promoted` event: the game arrived and stays, whatever a later change
##   request does; `failed` still says when the job's last state is a failure). `promoted` = the LAST promoted event: {packId, version, dest}.

const EventSchema = preload("res://kernel/world/site/event_schema.gd")

var events: Array = []          # the checked events, in order
var error: String = ""          # the first line that is not an event of the contract: reading stops there
var read_bytes: int = 0         # how much of the file has been taken (whole lines only)


## Takes the whole lines of `text` after `read_bytes` (`text` is the file from its start). Returns how many events
## were added. A line that breaks the contract stops the reading for good and is said in `error`.
func feed(text: String) -> int:
	if not error.is_empty():
		return 0
	var buf: PackedByteArray = text.to_utf8_buffer()
	var added: int = 0
	var at: int = read_bytes
	while at < buf.size():
		var nl: int = buf.find(10, at)
		if nl < 0:
			break                                   # a torn last line: not read yet
		var line: String = buf.slice(at, nl).get_string_from_utf8().strip_edges()
		at = nl + 1
		if line.is_empty():
			continue
		var parsed := JSON.new()
		var why := check_line(line, parsed)
		if why.is_empty() and parsed.data.seq != events.size() + 1:
			why = "expected seq %d" % [events.size() + 1]
		if why.is_empty() and not events.is_empty() and parsed.data.job != events[0].job:
			why = "job changed within the log"
		if not why.is_empty():
			error = "job.jsonl line %d: %s" % [events.size() + 1, why]
			break
		events.append(parsed.data)
		added += 1
	read_bytes = at
	return added


static func check_line(line: String, parsed: JSON = JSON.new()) -> String:
	if parsed.parse(line) != OK or not parsed.data is Dictionary:
		return "not a JSON object"
	return EventSchema.check(parsed.data)


## What the site shows after the first `n` events (all of them when n < 0). Pure: the same events give the same view.
static func fold(evs: Array, n: int = -1) -> Dictionary:
	var v: Dictionary = {"stage": "none", "title": "", "packages": [], "built": 0, "total": 0, "job_state": "", "failed": false, "promoted": {}}
	var by_id: Dictionary = {}
	var upto: int = evs.size() if n < 0 else mini(n, evs.size())
	for k: int in upto:
		var e: Dictionary = evs[k]
		match str(e.get("type", "")):
			"job_created":
				v["title"] = str(e.get("title", ""))
			"plan_set":
				var old: Dictionary = by_id
				by_id = {}
				var list: Array = []
				for p: Variant in e.get("packages", []):
					if typeof(p) != TYPE_DICTIONARY:
						continue
					var id: String = str((p as Dictionary).get("id", ""))
					var b: Dictionary = old.get(id, {"id": id, "state": "queued", "round": 1, "merged": false, "files": {}})
					b["title"] = str((p as Dictionary).get("title", id))
					by_id[id] = b
					list.append(b)
				v["packages"] = list
			"package_state":
				var b: Variant = by_id.get(str(e.get("package", "")), null)
				if b != null:
					(b as Dictionary)["state"] = str(e.get("state", ""))
					(b as Dictionary)["round"] = int(e.get("round", 1))
			"merge":
				# A package stands finished while it has merged files in pack/: `files` add, `removed` take away. The
				# Foreman's restore after a change that was not made (JOB.md 2026-11-17, foreman/src/unmade.ts) is
				# `merge` events with `files: []` and `removed`: a package whose files all go is not finished any more,
				# and one whose earlier files come back is finished as it was at the promotion.
				var b: Variant = by_id.get(str(e.get("package", "")), null)
				if b != null:
					var fs: Dictionary = (b as Dictionary)["files"]
					for f: Variant in (e.get("files", []) if typeof(e.get("files")) == TYPE_ARRAY else []):
						fs[str(f)] = true
					for f: Variant in (e.get("removed", []) if typeof(e.get("removed")) == TYPE_ARRAY else []):
						fs.erase(str(f))
					(b as Dictionary)["merged"] = not fs.is_empty()
			"job_state":
				v["job_state"] = str(e.get("state", ""))
			"promoted":
				v["promoted"] = {"packId": str(e.get("packId", "")), "version": str(e.get("version", "")), "dest": str(e.get("dest", ""))}
	var built: int = 0
	for b: Dictionary in v["packages"]:
		if bool(b["merged"]):
			built += 1
	v["built"] = built
	v["total"] = (v["packages"] as Array).size()
	v["failed"] = ["failed", "cancelled"].has(str(v["job_state"]))
	if upto == 0 or v["title"] == "" and v["total"] == 0:
		v["stage"] = "none" if upto == 0 else "pad"
	elif not (v["promoted"] as Dictionary).is_empty():
		v["stage"] = "promoted"                     # a game that arrived stays, whatever a later change does
	elif bool(v["failed"]):
		v["stage"] = "failed"
	elif int(v["total"]) == 0:
		v["stage"] = "pad"
	elif built == 0:
		v["stage"] = "bays"
	elif built < int(v["total"]):
		v["stage"] = "building"
	else:
		v["stage"] = "merged"
	return v
