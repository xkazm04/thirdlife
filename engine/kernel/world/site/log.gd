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

const BASE: Array = ["v", "seq", "ts", "job", "type"]
## Keys per event type (contracts/JOB.md and foreman/src/events.ts SPECS; `plan_set.card` added 2026-11-17).
const KEYS: Dictionary = {
	"job_created": ["sentence", "packId", "title"],
	"brief_set": ["brief", "estimate"],
	"brief_approved": ["by"],
	"plan_set": ["packages", "card"],
	"package_state": ["package", "state", "round", "cause", "detail"],
	"builder_run": ["package", "round", "adapter", "mode", "model", "outcome", "durationMs", "tokensIn", "tokensOut", "tokensCacheRead", "transcript"],
	"verify": ["package", "round", "level", "verb", "ok", "report", "exitCode", "after"],
	"merge": ["package", "files", "removed"],
	"note": ["package", "round", "text"],
	"change_requested": ["text", "package", "inbox"],
	"reopened": ["package", "reason"],
	"question": ["package", "text"],
	"answer": ["package", "text", "by", "inbox"],
	"milestone": ["milestone", "captures", "summary"],
	"comment": ["milestone", "text", "by"],
	"replan": ["reason", "added", "removed", "changed"],
	"budget": ["policy", "state", "reason"],
	"billing": ["adapter", "mode", "evidence"],
	"promoted": ["packId", "version", "dest"],
	"job_state": ["state", "reason"],
}

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
		var why: String = check_line(line)
		if not why.is_empty():
			error = "job.jsonl line %d: %s" % [events.size() + 1, why]
			break
		events.append(JSON.parse_string(line))
		added += 1
	read_bytes = at
	return added


static func check_line(line: String) -> String:
	var j: JSON = JSON.new()
	if j.parse(line) != OK or typeof(j.data) != TYPE_DICTIONARY:
		return "not a JSON object"
	var e: Dictionary = j.data
	var t: String = str(e.get("type", ""))
	if not KEYS.has(t):
		return "unknown event type '%s'" % t
	for k: Variant in e.keys():
		if not BASE.has(str(k)) and not (KEYS[t] as Array).has(str(k)):
			return "unknown key '%s' in a %s event" % [str(k), t]
	return ""


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
