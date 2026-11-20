extends RefCounted
## Modes as data (H3): data/modes/<id>.json, each overriding a small set of keys the pack already reads. Created by
## main.gd, no class_name. An unknown key in a mode file is an error at load, with the file and the key named.

const MODE_KEYS: Array = ["id", "label", "about", "rules", "skater", "shoot", "carry", "hits", "roster", "rink", "goals", "camera", "checks", "ai", "venue", "goalies", "goalie"]
const MODE_SECTIONS: Array = ["skater", "shoot", "carry", "hits", "rink", "goals", "camera", "goalie"]
const VENUE_KEYS: Array = ["length", "width", "corner_r", "apron", "dress"]
const ROSTER_KEYS: Array = ["id", "team", "role", "spawn"]


const LEVEL_KEYS: Array = ["id", "label", "about", "ai", "goalie"]


## H5: a level file: id, label, about and "ai" keys that data/ai.json has (they apply to the opposing team only).
func check_level(m: Dictionary, lid: String, ai_base: Dictionary, goalie_base: Dictionary = {}) -> Array:
	var errs: Array = []
	for k: String in m.keys():
		if not LEVEL_KEYS.has(k):
			errs.append("unknown key '%s' (keys: %s)" % [k, ", ".join(PackedStringArray(LEVEL_KEYS))])
	if str(m.get("id", "")) != lid:
		errs.append("'id' must be '%s'" % lid)
	for k: String in (m.get("ai", {}) as Dictionary).keys():
		if not ai_base.has(k):
			errs.append("unknown key 'ai.%s'" % k)
	for k: String in (m.get("goalie", {}) as Dictionary).keys():
		if not goalie_base.has(k):
			errs.append("unknown key 'goalie.%s'" % k)       # L5: the red goalie's numbers at this level
	return errs


## A mode file: only known keys; a section's keys must be keys the pack already reads. -> errors (empty = valid).
func check(m: Dictionary, mid: String, base_tune: Dictionary, ai_base: Dictionary) -> Array:
	var errs: Array = []
	for k: String in m.keys():
		if not MODE_KEYS.has(k):
			errs.append("unknown key '%s' (keys: %s)" % [k, ", ".join(PackedStringArray(MODE_KEYS))])
	if str(m.get("id", "")) != mid:
		errs.append("'id' must be '%s'" % mid)
	for sec: String in MODE_SECTIONS:
		if m.has(sec):
			for k: String in (m[sec] as Dictionary).keys():
				if not (base_tune[sec] as Dictionary).has(k):
					errs.append("unknown key '%s.%s'" % [sec, k])
	if m.has("rules"):
		for k: String in (m["rules"] as Dictionary).keys():
			if not TLRules.KEYS.has(k) or k == "sides":
				errs.append("unknown key 'rules.%s'" % k)
	if m.has("ai"):
		for k: String in (m["ai"] as Dictionary).keys():
			if not ai_base.has(k):
				errs.append("unknown key 'ai.%s'" % k)
	if m.has("venue"):
		for k: String in (m["venue"] as Dictionary).keys():
			if not VENUE_KEYS.has(k):
				errs.append("unknown key 'venue.%s'" % k)
	if m.has("roster"):
		var has_b0: bool = false
		for e: Dictionary in m["roster"]:
			for k: String in e.keys():
				if not ROSTER_KEYS.has(k):
					errs.append("unknown key 'roster[].%s'" % k)
			has_b0 = has_b0 or str(e.get("id", "")) == "b0"
		if not has_b0:
			errs.append("the roster has no b0 (the player)")
	if m.has("checks") and typeof(m["checks"]) != TYPE_BOOL:
		errs.append("'checks' must be true or false")
	if m.has("goalies") and typeof(m["goalies"]) != TYPE_BOOL:
		errs.append("'goalies' must be true or false")
	return errs


func merged(m: Dictionary, base_tune: Dictionary) -> Dictionary:
	var t: Dictionary = base_tune.duplicate(true)
	for sec: String in MODE_SECTIONS + ["rules"]:
		if m.has(sec):
			(t[sec] as Dictionary).merge(m[sec], true)
	if m.has("roster"):
		t["roster"] = (m["roster"] as Array).duplicate(true)
	return t
