extends RefCounted
## Modes as data (H3): data/modes/<id>.json, each overriding a small set of keys the pack already reads. Created by
## main.gd, no class_name. An unknown key in a mode file is an error at load, with the file and the key named.

const MODE_KEYS: Array = ["id", "label", "about", "rules", "skater", "shoot", "carry", "hits", "roster", "rink", "goals", "camera", "checks", "ai", "venue", "goalies", "goalie",
	"pickups", "abilities", "neon"]
## L5 crazy (21 Nov day): pickups on the ice (scripts/boosts.gd), abilities on F (scripts/abilities.gd), the neon arena
## (scripts/look.gd, scripts/fx/neon.gd). Absent = off: a mode without them plays and hashes as before.
const PICKUP_KEYS: Array = ["every_frames", "first_frames", "max_alive", "zones", "kinds", "take_margin"]
const PICKUP_KIND_KEYS: Array = ["kind", "weight"]
const PICKUP_KINDS: Array = ["speed", "precision", "big_puck", "heavy_puck", "shotgun", "hip_check", "shield", "slow_puck"]
const ABILITY_KEYS: Array = ["kind", "trigger", "charges", "cooldown_frames", "duration_frames", "magnitude"]
const ABILITY_KINDS: Array = ["shotgun", "hip_check", "shield", "slow_puck"]
const ABILITY_TRIGGERS: Array = ["mode", "pickup"]
const NEON_KEYS: Array = ["accent", "trails", "trim", "lines"]
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
	errs.append_array(check_crazy(m))
	return errs


## L5 crazy: a mode with pickups, abilities or the neon arena. It gets no keyless mode_<id> action (every declared action is
## in the input hash, so a base run must not see one): a person and a test reach it through the start panel.
func is_crazy(m: Dictionary) -> bool:
	return m.has("pickups") or m.has("abilities") or m.has("neon")


## L5 crazy: the shape of "pickups", "abilities" (a list) and "neon"; unknown keys and unknown kinds are errors.
func check_crazy(m: Dictionary) -> Array:
	var errs: Array = []
	if m.has("pickups"):
		if not (m["pickups"] is Dictionary):
			errs.append("'pickups' must be an object")
		else:
			var pk: Dictionary = m["pickups"]
			for k: String in pk.keys():
				if not PICKUP_KEYS.has(k):
					errs.append("unknown key 'pickups.%s' (keys: %s)" % [k, ", ".join(PackedStringArray(PICKUP_KEYS))])
			for z: Variant in pk.get("zones", []):
				if not (z is Array) or (z as Array).size() != 4:
					errs.append("'pickups.zones[]' must be [x0, z0, x1, z1]")
			for e: Variant in pk.get("kinds", []):
				if not (e is Dictionary):
					errs.append("'pickups.kinds[]' must be objects")
					continue
				for k: String in (e as Dictionary).keys():
					if not PICKUP_KIND_KEYS.has(k):
						errs.append("unknown key 'pickups.kinds[].%s'" % k)
				if not PICKUP_KINDS.has(str((e as Dictionary).get("kind", ""))):
					errs.append("unknown pickup kind '%s' (kinds: %s)" % [str((e as Dictionary).get("kind", "")), ", ".join(PackedStringArray(PICKUP_KINDS))])
	if m.has("abilities"):
		if not (m["abilities"] is Array):
			errs.append("'abilities' must be a list")
		else:
			var modes_n: int = 0
			for a: Variant in m["abilities"]:
				if not (a is Dictionary):
					errs.append("'abilities[]' must be objects")
					continue
				for k: String in (a as Dictionary).keys():
					if not ABILITY_KEYS.has(k):
						errs.append("unknown key 'abilities[].%s' (keys: %s)" % [k, ", ".join(PackedStringArray(ABILITY_KEYS))])
				if not ABILITY_KINDS.has(str((a as Dictionary).get("kind", ""))):
					errs.append("unknown ability kind '%s'" % str((a as Dictionary).get("kind", "")))
				var trig: String = str((a as Dictionary).get("trigger", ""))
				if not ABILITY_TRIGGERS.has(trig):
					errs.append("'abilities[].trigger' must be one of %s" % ", ".join(PackedStringArray(ABILITY_TRIGGERS)))
				if trig == "mode":
					modes_n += 1
				if trig == "pickup" and not m.has("pickups"):
					errs.append("an ability with trigger 'pickup' needs 'pickups' (it could never arrive)")
			if modes_n > 1:
				errs.append("at most one ability with trigger 'mode' (F is one key)")
	if m.has("neon"):
		if not (m["neon"] is Dictionary):
			errs.append("'neon' must be an object")
		else:
			for k: String in (m["neon"] as Dictionary).keys():
				if not NEON_KEYS.has(k):
					errs.append("unknown key 'neon.%s' (keys: %s)" % [k, ", ".join(PackedStringArray(NEON_KEYS))])
	return errs


func merged(m: Dictionary, base_tune: Dictionary) -> Dictionary:
	var t: Dictionary = base_tune.duplicate(true)
	for sec: String in MODE_SECTIONS + ["rules"]:
		if m.has(sec):
			(t[sec] as Dictionary).merge(m[sec], true)
	if m.has("roster"):
		t["roster"] = (m["roster"] as Array).duplicate(true)
	return t
