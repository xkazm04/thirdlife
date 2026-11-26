extends RefCounted
## M4 (spark world-sandbox): the LLM command bar's calls log and its per-day cap (contracts/BUILD.md "The LLM command
## bar"). `<home>/llm_calls.jsonl` (the exe: %APPDATA%\ThirdLife\home\llm_calls.jsonl), one JSON line per event of a
## call, append-only; the LAST line of an id is that call's state (`tl ledger --home <dir>` reads it the same way):
##   {"id", "ts" (UTC, ISO 8601), "day" (the person's local date: the cap's day), "sentence",
##    "accepted": "pending" | true | false, "model"?, "tokensIn"?, "tokensOut"?, "durationMs"?, "ops"?, "applied"?,
##    "refused"?, "error"?}
## A call is counted against the cap when it is asked (its "pending" line). The cap is `llm_calls_per_day` in
## `<home>/settings.json` (`{"llm_calls_per_day": n}`, default 30; no schema string: none is declared for it; unknown keys are
## errors and leave the default in force, with the reason shown). The calendar day is used here and only here: a
## billing cap is the one place the contract allows it; the world's simulation still counts frames.

const LOG := "llm_calls.jsonl"
const SETTINGS := "settings.json"
const DEFAULT_CAP := 30
const ORDER := ["id", "ts", "day", "sentence", "accepted", "model", "tokensIn", "tokensOut", "durationMs", "ops", "applied", "refused", "error"]

var dir := ""                           # the Home's folder ("" = nothing is logged)
var cap := DEFAULT_CAP
var settings_error := ""
var today_override := ""                # a case's fixed day (YYYY-MM-DD); "" = the system's local date
var _n := 0
var _days := {}                         # call id -> its day (read once from the log, then kept as lines are written)


func _init(d := "") -> void:
	open(d)


func open(d: String) -> void:
	dir = d
	_days = {}
	for c: Dictionary in calls():
		_days[str(c.id)] = str(c.get("day", ""))
	cap = DEFAULT_CAP
	settings_error = ""
	if d.is_empty() or not FileAccess.file_exists(d.path_join(SETTINGS)):
		return
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(d.path_join(SETTINGS)))
	if typeof(j) != TYPE_DICTIONARY:
		settings_error = "settings.json is not a JSON object"
		return
	for k: Variant in j:
		if not (k in ["llm_calls_per_day"]):
			settings_error = "settings.json: unknown key '%s'" % str(k)
			return
	if (j as Dictionary).has("llm_calls_per_day"):
		var n: Variant = j.llm_calls_per_day
		if (typeof(n) != TYPE_FLOAT and typeof(n) != TYPE_INT) or float(n) != floorf(float(n)) or float(n) < 0.0:
			settings_error = "settings.json: llm_calls_per_day must be a whole number"
			return
		cap = int(n)


func today() -> String:
	return today_override if not today_override.is_empty() else Time.get_date_string_from_system(false)


## Every call's last line, by id, in the order first seen.
func calls() -> Array:
	var p := dir.path_join(LOG)
	if dir.is_empty() or not FileAccess.file_exists(p):
		return []
	var by := {}
	var order := []
	for line: String in FileAccess.get_file_as_string(p).split("\n", false):
		var j: Variant = JSON.parse_string(line)
		if typeof(j) != TYPE_DICTIONARY or not (j as Dictionary).has("id"):
			continue
		var id := str(j.id)
		if not by.has(id):
			order.append(id)
		by[id] = j
	return order.map(func(id: String) -> Dictionary: return by[id])


## The calls asked today (the cap's count).
func used_today() -> int:
	var t := today()
	return _days.values().filter(func(d: String) -> bool: return d == t).size()


## "" or why no more calls may be made today.
func refusal() -> String:
	var n := used_today()
	if n >= cap:
		return "%d of %d calls today: the day's cap is reached (llm_calls_per_day in %s)" % [n, cap, SETTINGS]
	return ""


## A new call's id: the day, the time and a counter (unique within the log).
func new_id() -> String:
	_n += 1
	return "%s-%d-%d" % [today(), int(Time.get_unix_time_from_system()), _n]


## Appends one line for call `id` (keys in ORDER; absent values omitted). Returns the line as written.
func write(id: String, fields: Dictionary) -> Dictionary:
	var rec := {}
	for k: String in ORDER:
		if k == "id":
			rec["id"] = id
		elif fields.has(k) and fields[k] != null:
			rec[k] = fields[k]
		elif k == "ts":
			rec["ts"] = Time.get_datetime_string_from_system(true) + "Z"
	_days[id] = str(rec.get("day", ""))
	if dir.is_empty():
		return rec
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var p := dir.path_join(LOG)
	var f := FileAccess.open(p, FileAccess.READ_WRITE) if FileAccess.file_exists(p) else FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		push_error("[command] cannot write %s" % p)
		return rec
	f.seek_end()
	f.store_string(JSON.stringify(rec, "", false) + "\n")
	f.close()
	return rec
