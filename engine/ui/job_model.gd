extends RefCounted
## N6: the model behind the designer panel. Reads one job directory (contracts/JOB.md, tl.job/1) into one Dictionary
## that the panel draws. Read only: nothing here writes into a job directory. It reads `job.jsonl` itself (the single
## source of truth) and tolerates a torn last line; `state.json` is only used by the selftest as a cross-check.

const LIVE_PHASES: PackedStringArray = ["designing", "planning", "running"]
const TERMINAL: PackedStringArray = ["done", "failed", "cancelled"]


## {ok, error, events: Array[Dictionary], torn: bool, bad_lines: int}
static func read_events(job_dir: String) -> Dictionary:
	var out: Dictionary = {"ok": false, "error": "", "events": [], "torn": false, "bad_lines": 0}
	var path: String = job_dir.path_join("job.jsonl")
	if not FileAccess.file_exists(path):
		out["error"] = "no job.jsonl"
		return out
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		out["error"] = "job.jsonl cannot be opened (error %d)" % FileAccess.get_open_error()
		return out
	var text: String = f.get_as_text()
	f.close()
	var lines: PackedStringArray = text.split("\n")
	var ends_clean: bool = text.ends_with("\n")
	var events: Array = []
	var json: JSON = JSON.new()
	for i: int in lines.size():
		var line: String = lines[i].strip_edges()
		if line.is_empty():
			continue
		var last: bool = i == lines.size() - 1
		var good: bool = json.parse(line) == OK and json.data is Dictionary
		if good and last and not ends_clean:
			# a complete-looking object without its newline is still being written: the writer appends line + "\n"
			good = (json.data as Dictionary).has("type") and (json.data as Dictionary).has("seq")
		if not good:
			if last:
				out["torn"] = true
			else:
				out["bad_lines"] = int(out["bad_lines"]) + 1
			continue
		events.append(json.data)
	out["events"] = events
	out["ok"] = true
	return out


static func ts_unix(ts: String) -> float:
	if ts.is_empty():
		return 0.0
	var base: float = float(Time.get_unix_time_from_datetime_string(ts.substr(0, 19)))
	var dot: int = ts.find(".")
	if dot > 0:
		base += float("0" + ts.substr(dot).trim_suffix("Z"))
	return base


static func _new_package(spec: Dictionary) -> Dictionary:
	return {
		"id": str(spec.get("id", "")), "title": str(spec.get("title", "")), "milestone": str(spec.get("milestone", "")),
		"deps": spec.get("deps", []), "state": "queued", "round": 1, "cause": "", "detail": "",
		"work_s": 0.0, "since": 0.0, "tokens_in": 0, "tokens_out": 0, "runs": 0,
	}


## Reads the whole job. `now` is unix seconds (the caller's clock), used for the time of what is still going on.
static func read_job(job_dir: String, now: float = -1.0) -> Dictionary:
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	var r: Dictionary = read_events(job_dir)
	var job: Dictionary = reduce(r["events"], now)
	job["dir"] = job_dir
	job["id"] = job_dir.get_file()
	job["ok"] = r["ok"]
	job["error"] = r["error"]
	job["torn"] = r["torn"]
	job["bad_lines"] = r["bad_lines"]
	if not bool(r["ok"]) or (r["events"] as Array).is_empty():
		job["phase"] = "unreadable"
		if str(job["error"]).is_empty():
			job["error"] = "job.jsonl holds no complete event yet"
	if str(job["title"]).is_empty():
		job["title"] = str(job["id"])
	job["lock_pid"] = read_lock(job_dir)
	job["params"] = []
	job["pack_dir"] = ""
	if not (job["promotions"] as Array).is_empty():
		var last: Dictionary = (job["promotions"] as Array).back()
		var dest: String = str(last.get("dest", ""))
		if dest.begins_with("promoted/"):
			job["pack_dir"] = job_dir.path_join(dest)
			job["params"] = read_params(job["pack_dir"])
	return job


## The pid in `foreman.lock`, 0 when there is no lock.
static func read_lock(job_dir: String) -> int:
	var p: String = job_dir.path_join("foreman.lock")
	if not FileAccess.file_exists(p):
		return 0
	var t: String = FileAccess.get_file_as_string(p).strip_edges()
	return int(t) if t.is_valid_int() else 0


## Pure: events in, the job picture out.
static func reduce(events: Array, now: float) -> Dictionary:
	var job: Dictionary = {
		"title": "", "sentence": "", "pack_id": "", "brief": {}, "estimate": {}, "approved_by": "",
		"order": [], "packages": {}, "plan_revisions": 0,
		"job_state": "", "job_reason": "", "budget_state": "", "budget_reason": "", "budget_policy": {},
		"notes": [], "questions": [], "milestones": [], "changes": [], "promotions": [], "replans": 0,
		"tokens_in": 0, "tokens_out": 0, "tokens_cache": 0, "builder_ms": 0, "builder_runs": 0,
		"first_ts": 0.0, "last_ts": 0.0, "n_events": events.size(), "last_seq": 0,
		"activity": "", "billing": "", "phase": "designing", "adapter": "",
		"done": 0, "total": 0, "elapsed_s": 0.0, "pause_kind": "", "fail_line": "", "unknown_types": [],
	}
	var pk: Dictionary = job["packages"]
	for e: Dictionary in events:
		var t: String = str(e.get("type", ""))
		var ts: float = ts_unix(str(e.get("ts", "")))
		if job["first_ts"] == 0.0:
			job["first_ts"] = ts
		job["last_ts"] = ts
		job["last_seq"] = int(e.get("seq", 0))
		var pid: String = str(e.get("package", ""))
		match t:
			"job_created":
				job["sentence"] = str(e.get("sentence", ""))
				job["title"] = str(e.get("title", ""))
				job["pack_id"] = str(e.get("packId", ""))
				job["activity"] = "the Designer is writing the brief"
			"billing":
				job["billing"] = "%s, %s" % [str(e.get("adapter", "")), str(e.get("mode", ""))]
				job["adapter"] = str(e.get("adapter", ""))
			"brief_set":
				job["brief"] = e.get("brief", {})
				job["estimate"] = e.get("estimate", {})
				job["activity"] = "the brief is ready: approve or discard it"
			"brief_approved":
				job["approved_by"] = str(e.get("by", ""))
				job["activity"] = "brief approved; the Planner cuts the game into packages"
			"plan_set":
				job["plan_revisions"] = int(job["plan_revisions"]) + 1
				var order: Array = []
				for spec: Dictionary in e.get("packages", []):
					var id: String = str(spec.get("id", ""))
					order.append(id)
					if pk.has(id):
						pk[id]["title"] = str(spec.get("title", ""))
						pk[id]["milestone"] = str(spec.get("milestone", ""))
						pk[id]["deps"] = spec.get("deps", [])
					else:
						pk[id] = _new_package(spec)
				for old: String in pk.keys():
					if not order.has(old):
						pk.erase(old)
				job["order"] = order
				job["activity"] = "plan of %d packages" % order.size()
			"package_state":
				if not pk.has(pid):
					pk[pid] = _new_package({"id": pid, "title": pid})
					(job["order"] as Array).append(pid)
				var p: Dictionary = pk[pid]
				var st: String = str(e.get("state", ""))
				var was_working: bool = p["state"] == "running" or p["state"] == "verifying"
				var works: bool = st == "running" or st == "verifying"
				if was_working and float(p["since"]) > 0.0:
					p["work_s"] = float(p["work_s"]) + maxf(0.0, ts - float(p["since"]))
					p["since"] = 0.0
				if works:
					p["since"] = ts
				p["state"] = st
				p["round"] = int(e.get("round", p["round"]))
				p["cause"] = str(e.get("cause", ""))
				p["detail"] = str(e.get("detail", ""))
				match st:
					"running": job["activity"] = "%s, round %d: the builder is at work" % [pid, int(p["round"])]
					"verifying": job["activity"] = "%s, round %d: checking the builder's work" % [pid, int(p["round"])]
					"promoted": job["activity"] = "%s: verified and merged" % pid
					"failed": job["activity"] = "%s failed: %s" % [pid, one_line(str(p["cause"]) + " " + str(p["detail"]), 90)]
					"blocked": job["activity"] = "%s is blocked: %s" % [pid, str(p["cause"])]
					"queued":
						if str(p["detail"]).begins_with("critic"):
							job["activity"] = "%s: the critic sends it back for one more round" % pid
						elif str(p["detail"]).begins_with("CHANGE REQUEST"):
							job["activity"] = "%s: re-opened for your change" % pid
			"builder_run":
				var tin: int = int(e.get("tokensIn", 0))
				var tout: int = int(e.get("tokensOut", 0))
				job["tokens_in"] = int(job["tokens_in"]) + tin
				job["tokens_out"] = int(job["tokens_out"]) + tout
				job["tokens_cache"] = int(job["tokens_cache"]) + int(e.get("tokensCacheRead", 0))
				job["builder_ms"] = int(job["builder_ms"]) + int(e.get("durationMs", 0))
				job["builder_runs"] = int(job["builder_runs"]) + 1
				if job["adapter"] == "":
					job["adapter"] = str(e.get("adapter", ""))
				if pk.has(pid):
					pk[pid]["tokens_in"] = int(pk[pid]["tokens_in"]) + tin
					pk[pid]["tokens_out"] = int(pk[pid]["tokens_out"]) + tout
					pk[pid]["runs"] = int(pk[pid]["runs"]) + 1
				if str(e.get("outcome", "ok")) != "ok":
					job["activity"] = "%s: the builder ended with %s" % [pid if not pid.is_empty() else "job", str(e.get("outcome", ""))]
			"verify":
				var who: String = pid if not pid.is_empty() else "whole pack"
				job["activity"] = "%s: %s %s" % [who, str(e.get("verb", "")), "passed" if bool(e.get("ok", false)) else "FAILED"]
			"merge":
				job["activity"] = "%s: %d files merged into the pack" % [pid, (e.get("files", []) as Array).size()]
			"note":
				(job["notes"] as Array).append({"package": pid, "round": int(e.get("round", 0)), "text": str(e.get("text", "")), "seq": int(e.get("seq", 0)),
					"own": str(e.get("text", "")).begins_with("[foreman] ")})
			"question":
				(job["questions"] as Array).append({"package": pid, "text": str(e.get("text", "")), "seq": int(e.get("seq", 0)), "open": true, "answer": "", "by": ""})
				job["activity"] = "%s asks a question" % pid
			"answer":
				var qs: Array = job["questions"]
				for i: int in range(qs.size() - 1, -1, -1):
					if qs[i]["package"] == pid and bool(qs[i]["open"]):
						qs[i]["open"] = false
						qs[i]["answer"] = str(e.get("text", ""))
						qs[i]["by"] = str(e.get("by", ""))
						break
				job["activity"] = "%s: question answered" % pid
			"milestone":
				(job["milestones"] as Array).append({"milestone": str(e.get("milestone", "")), "captures": e.get("captures", []), "summary": str(e.get("summary", "")), "seq": int(e.get("seq", 0))})
				job["activity"] = "milestone %s: %d pictures" % [str(e.get("milestone", "")), (e.get("captures", []) as Array).size()]
			"replan":
				job["replans"] = int(job["replans"]) + 1
				job["activity"] = "re-plan: %s" % one_line(str(e.get("reason", "")), 80)
			"budget":
				job["budget_state"] = str(e.get("state", ""))
				job["budget_reason"] = str(e.get("reason", ""))
				job["budget_policy"] = e.get("policy", {})
			"promoted":
				(job["promotions"] as Array).append({"packId": str(e.get("packId", "")), "version": str(e.get("version", "")), "dest": str(e.get("dest", "")), "seq": int(e.get("seq", 0))})
				job["activity"] = "pack %s promoted" % str(e.get("version", ""))
			"job_state":
				job["job_state"] = str(e.get("state", ""))
				job["job_reason"] = str(e.get("reason", ""))
				job["activity"] = one_line(str(e.get("reason", "")), 110)
			"change_requested":
				(job["changes"] as Array).append({"seq": int(e.get("seq", 0)), "text": str(e.get("text", "")), "package": pid, "owner": pid,
					"outcome": "in flight", "version": "", "ts": ts})
				job["activity"] = "change requested"
			"reopened":
				var reason: String = str(e.get("reason", ""))
				if reason.begins_with("change request (event "):
					var n: int = int(reason.substr(22).get_slice(")", 0))
					for c: Dictionary in job["changes"]:
						if int(c["seq"]) == n:
							c["owner"] = pid
				job["activity"] = "%s re-opened" % pid
			"comment":
				pass
			_:
				if not (job["unknown_types"] as Array).has(t):
					(job["unknown_types"] as Array).append(t)
	# outcomes of change requests: the next promotion after the request closes it
	var changes: Array = job["changes"]
	for i: int in changes.size():
		var c: Dictionary = changes[i]
		var until: int = int(changes[i + 1]["seq"]) if i + 1 < changes.size() else 1 << 30
		for e: Dictionary in events:
			var seq: int = int(e.get("seq", 0))
			if seq <= int(c["seq"]) or seq >= until:
				continue
			var t: String = str(e.get("type", ""))
			if t == "package_state" and str(e.get("state", "")) == "promoted" and str(e.get("detail", "")).contains("not made"):
				c["outcome"] = "not made"
			elif t == "promoted":
				c["version"] = str(e.get("version", ""))
				if c["outcome"] == "in flight":
					c["outcome"] = "made"
			elif t == "job_state" and str(e.get("state", "")) in ["failed", "cancelled"]:
				c["outcome"] = str(e.get("state", ""))
	# figures
	var done: int = 0
	for id: String in job["order"]:
		if pk.has(id):
			var p: Dictionary = pk[id]
			if p["state"] == "promoted":
				done += 1
			if float(p["since"]) > 0.0:
				p["work_s"] = float(p["work_s"]) + maxf(0.0, now - float(p["since"]))
	job["done"] = done
	job["total"] = (job["order"] as Array).size()
	# phase: what the list's chip says
	var js: String = job["job_state"]
	var phase: String = "designing"
	if js in TERMINAL:
		phase = js
	elif js == "paused":
		phase = "paused"
	elif js == "running":
		phase = "running"
	elif (job["brief"] as Dictionary).is_empty():
		phase = "designing"
	elif str(job["approved_by"]).is_empty():
		phase = "approve"
	else:
		phase = "planning"
	job["phase"] = phase
	if phase == "paused":
		var open_q: bool = false
		for q: Dictionary in job["questions"]:
			if bool(q["open"]):
				open_q = true
		if open_q:
			job["pause_kind"] = "question"
		elif job["budget_state"] == "paused" or str(job["job_reason"]).contains("budget") or str(job["job_reason"]).contains("rate"):
			job["pause_kind"] = "budget"
		else:
			job["pause_kind"] = "other"
	if phase == "failed" or phase == "cancelled":
		var line: String = str(job["job_reason"])
		for id: String in job["order"]:
			if pk.has(id) and pk[id]["state"] == "failed" and not str(pk[id]["cause"]).is_empty() and pk[id]["cause"] != "cancelled":
				line = "%s: %s. %s" % [id, str(pk[id]["cause"]).replace("_", " "), line]
				break
		job["fail_line"] = one_line(line, 160)
	var end: float = float(job["last_ts"]) if (phase in TERMINAL or phase == "approve" or phase == "paused") else now
	job["elapsed_s"] = maxf(0.0, end - float(job["first_ts"])) if float(job["first_ts"]) > 0.0 else 0.0
	return job


## `params` of a promoted pack: [{name, file, path, min, max, step, label, value, ok, error}]
static func read_params(pack_dir: String) -> Array:
	var out: Array = []
	var man: Variant = read_json(pack_dir.path_join("pack.json"))
	if not (man is Dictionary) or not ((man as Dictionary).get("params", null) is Array):
		return out
	for raw: Variant in (man as Dictionary)["params"]:
		if not (raw is Dictionary):
			continue
		var p: Dictionary = (raw as Dictionary).duplicate()
		p["ok"] = false
		p["error"] = ""
		p["value"] = float(p.get("min", 0.0))
		var file: String = str(p.get("file", ""))
		if file.is_empty() or file.contains("..") or file.is_absolute_path():
			p["error"] = "bad file name"
		else:
			var data: Variant = read_json(pack_dir.path_join(file))
			if data == null:
				p["error"] = "%s cannot be read" % file
			else:
				var v: Variant = get_path_value(data, str(p.get("path", "")))
				if v is float or v is int:
					p["value"] = float(v)
					p["ok"] = true
				else:
					p["error"] = "no number at %s in %s" % [str(p.get("path", "")), file]
		out.append(p)
	return out


static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return json.data


static func get_path_value(data: Variant, dotted: String) -> Variant:
	var cur: Variant = data
	for key: String in dotted.split("."):
		if cur is Dictionary and (cur as Dictionary).has(key):
			cur = (cur as Dictionary)[key]
		elif cur is Array and key.is_valid_int() and int(key) >= 0 and int(key) < (cur as Array).size():
			cur = (cur as Array)[int(key)]
		else:
			return null
	return cur


## Writes one number into a pack's data file. The file is rewritten whole (keys keep their order, whole numbers are
## written without a fraction), through a temporary file, and read back. Returns "" or what went wrong.
static func write_param(pack_dir: String, param: Dictionary, value: float) -> String:
	var file: String = str(param.get("file", ""))
	if file.is_empty() or file.contains("..") or file.is_absolute_path():
		return "bad file name"
	var path: String = pack_dir.path_join(file)
	var data: Variant = read_json(path)
	if data == null:
		return "%s cannot be read as JSON" % file
	var keys: PackedStringArray = str(param.get("path", "")).split(".")
	var cur: Variant = data
	for i: int in keys.size():
		var key: String = keys[i]
		var last: bool = i == keys.size() - 1
		if cur is Dictionary and (cur as Dictionary).has(key):
			if last:
				(cur as Dictionary)[key] = value
			else:
				cur = (cur as Dictionary)[key]
		elif cur is Array and key.is_valid_int() and int(key) >= 0 and int(key) < (cur as Array).size():
			if last:
				(cur as Array)[int(key)] = value
			else:
				cur = (cur as Array)[int(key)]
		else:
			return "no value at %s" % str(param.get("path", ""))
	var text: String = to_json(data, 0) + "\n"
	var check: JSON = JSON.new()
	if check.parse(text) != OK:
		return "internal: the new text is not JSON"
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "%s cannot be written" % file
	f.store_string(text)
	f.close()
	var err: int = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		DirAccess.remove_absolute(tmp)
		return "%s cannot be replaced (error %d)" % [file, err]
	var back: Variant = get_path_value(read_json(path), str(param.get("path", "")))
	if not (back is float or back is int) or not is_equal_approx(float(back), value):
		return "the value read back differs"
	return ""


## JSON text: two-space indent, key order kept, whole numbers without a fraction (Godot's own writer prints 5.0).
static func to_json(v: Variant, depth: int) -> String:
	var pad: String = "  ".repeat(depth + 1)
	var end_pad: String = "  ".repeat(depth)
	if v is Dictionary:
		var d: Dictionary = v
		if d.is_empty():
			return "{}"
		var parts: PackedStringArray = []
		for k: Variant in d.keys():
			parts.append(pad + JSON.stringify(str(k)) + ": " + to_json(d[k], depth + 1))
		return "{\n" + ",\n".join(parts) + "\n" + end_pad + "}"
	if v is Array:
		var a: Array = v
		if a.is_empty():
			return "[]"
		var flat: bool = true
		for x: Variant in a:
			if x is Dictionary or x is Array:
				flat = false
		var items: PackedStringArray = []
		for x: Variant in a:
			items.append(to_json(x, depth + 1))
		if flat:
			return "[" + ", ".join(items) + "]"
		for i: int in items.size():
			items[i] = pad + items[i]
		return "[\n" + ",\n".join(items) + "\n" + end_pad + "]"
	if v is float:
		var fl: float = v
		if is_finite(fl) and fl == floorf(fl) and absf(fl) < 1.0e15:
			return str(int(fl))
		return JSON.stringify(fl)
	return JSON.stringify(v)


## Job directories under a jobs root, newest first (by the first event's time, then by name).
static func list_job_dirs(root: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var d: DirAccess = DirAccess.open(root)
	if d == null:
		return out
	for name: String in d.get_directories():
		if name.begins_with("_") or name.begins_with("."):
			continue
		if FileAccess.file_exists(root.path_join(name).path_join("job.jsonl")):
			out.append(root.path_join(name))
	return out


# ---------------------------------------------------------------- text helpers shared with the panel

static func one_line(text: String, max_chars: int = 0) -> String:
	var t: String = text.replace("\r", "").replace("\n- ", " · ").replace("\n", " ").replace("\t", " ").replace("**", "").replace("`", "")
	while t.contains("  "):
		t = t.replace("  ", " ")
	t = t.strip_edges()
	if t.begins_with("- "):
		t = t.substr(2)
	if max_chars > 0 and t.length() > max_chars:
		t = t.substr(0, max_chars - 1).strip_edges() + "…"
	return t


static func fmt_tokens(n: int) -> String:
	if n <= 0:
		return "0"
	if n >= 1000000:
		return "%.2fM" % (float(n) / 1000000.0)
	if n >= 10000:
		return "%dk" % int(roundf(float(n) / 1000.0))
	if n >= 1000:
		return "%.1fk" % (float(n) / 1000.0)
	return str(n)


static func fmt_time(seconds: float) -> String:
	var s: int = int(seconds)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]


static func fmt_minutes(seconds: float) -> String:
	if seconds <= 0.0:
		return "–"
	if seconds < 60.0:
		return "%ds" % int(seconds)
	if seconds >= 6000.0:
		return "%d min" % int(seconds / 60.0)
	return "%.1f min" % (seconds / 60.0)
