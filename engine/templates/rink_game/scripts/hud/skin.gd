extends RefCounted
## The game's skin (lane E1, 24-25 Nov): every word and bank of the screen that belongs to one game and not to the base,
## read from data/skin.json (required; schema tl.rink.skin/1; unknown keys are errors, a key left out keeps the default below, which
## is hokej's: thirdjam's own words). The pitch, the rules, the teams and their COLOURS are the cartridge's (the one source
## of truth: game.teams[].colour_hex colours the figures, the HUD rings, plates, barks and markers); the skin names the
## teams in words only. data/match.json picks the cartridge (`cartridge`) and the level (`difficulty`).
##
##   schema       "tl.rink.skin/1"
##   title        the game's name on the title and on HOME's header ("HOKEJ")
##   tagline      the line under the title ("HOCKEY WITH THE WHISTLE TAKEN OUT.")
##   about        HOME's ONE MATCH lines, a list of strings
##   team_names   [team 0, team 1] in words ("Blue", "Orange"): the commentator's lines say these where thirdjam's bank says
##                blue / orange
##   levels       [[label, line] x 3]: the level row's words for rookie, pro, all_star, and the line under the row
##   commentary   "builtin" (thirdjam's three commentary banks, scripts/hud/commentary_lines.gd), "off", or a file in data/
##                ({"lines": [[id, event, kind, team, priority, cooldown_frames, text, duration_frames], ...]})
##   barks        a file in data/ with the skaters' barks ({"lines": [[id, situation, speaker, tone, text], ...]}: hokej's is
##                hud_barks.json, thirdjam's bank) or "off"

const SCHEMA: String = "tl.rink.skin/1"
const DEFAULTS: Dictionary = {
	"schema": SCHEMA,
	"title": "HOKEJ",
	"tagline": "HOCKEY WITH THE WHISTLE TAKEN OUT.",
	"about": ["Five-a-side hockey. WASD skates, the mouse is your stick.", "Hockey with the whistle taken out."],
	"team_names": ["Blue", "Orange"],
	"levels": [["ROOKIE", "New to hockey games? Start here: rookies are a step slower."], ["PRO", "Played one before? Pros hit as a habit."],
		["ALL-STAR", "The wall. All-stars hunt the puck. Beat pro first."]],
	"commentary": "builtin",
	"barks": "hud_barks.json",
}
const TYPES: Dictionary = {"schema": TYPE_STRING, "title": TYPE_STRING, "tagline": TYPE_STRING, "about": TYPE_ARRAY,
	"team_names": TYPE_ARRAY, "levels": TYPE_ARRAY, "commentary": TYPE_STRING, "barks": TYPE_STRING}


## The skin of the pack (data/skin.json), validated: the problems (unknown key, wrong type or shape) are pushed as errors (a run
## with them is not clean) and the default stands for that key. A bank file that is not in data/ is read_json's error.
static func of(ctx) -> Dictionary:
	var raw: Variant = ctx.read_json("skin.json")        # every game of the base has one (an absent file is an error of read_json)
	var problems: Array = []
	var s: Dictionary = validate(raw if raw is Dictionary else {}, problems)
	if raw != null and not (raw is Dictionary):
		problems.append("data/skin.json is not a JSON object")
	for p: String in problems:
		push_error("skin: " + p)
	return s


## Pure: `raw` checked against the schema; problems appended to `problems`; the defaults fill what is absent or wrong.
static func validate(raw: Dictionary, problems: Array) -> Dictionary:
	var s: Dictionary = DEFAULTS.duplicate(true)
	for k: Variant in raw.keys():
		if not TYPES.has(k):
			problems.append("unknown key '%s' (tl.rink.skin/1 has %s)" % [str(k), ", ".join(PackedStringArray(TYPES.keys()))])
			continue
		var v: Variant = raw[k]
		if typeof(v) != int(TYPES[k]):
			problems.append("'%s' has the wrong type" % str(k))
			continue
		match String(k):
			"schema":
				if String(v) != SCHEMA:
					problems.append("schema '%s' is not %s" % [String(v), SCHEMA])
					continue
			"team_names":
				if (v as Array).size() != 2 or not ((v as Array)[0] is String and (v as Array)[1] is String):
					problems.append("team_names must be two strings")
					continue
			"levels":
				var good: bool = (v as Array).size() == 3
				for row: Variant in v as Array:
					good = good and row is Array and (row as Array).size() == 2 and (row as Array)[0] is String and (row as Array)[1] is String
				if not good:
					problems.append("levels must be three [label, line] pairs")
					continue
			"about":
				for line: Variant in v as Array:
					if not (line is String):
						problems.append("about must be a list of strings")
						v = null
						break
				if v == null:
					continue
		s[k] = v
	return s


## The bank of the commentator's lines the skin names: thirdjam's (null: the built-in), none, or a data file's rows.
static func commentary_rows(ctx, s: Dictionary) -> Variant:
	match String(s["commentary"]):
		"builtin": return null
		"off": return []
	return (ctx.read_json(String(s["commentary"])) as Dictionary).get("lines", [])


## The skaters' barks the skin names (rows of the bank), [] when off.
static func bark_rows(ctx, s: Dictionary) -> Array:
	if String(s["barks"]) == "off":
		return []
	return (ctx.read_json(String(s["barks"])) as Dictionary).get("lines", [])


## A line of thirdjam's bank in this skin's team words: "Blue" / "blue" / "Orange" / "orange" become the team names (as they
## stand: capitalised at the start of a word that was, lower case where thirdjam wrote lower case). With the default names the
## line is unchanged.
static func team_words(text: String, names: Array) -> String:
	if names == DEFAULTS["team_names"]:
		return text
	var out: String = text
	var pairs: Array = [["Blue", String(names[0])], ["Orange", String(names[1])]]
	for p: Array in pairs:
		var w: String = p[0]
		var n: String = p[1]
		out = _swap(out, w, n)
		out = _swap(out, w.to_lower(), n.to_lower())
	return out


static func _swap(text: String, word: String, with: String) -> String:
	var re := RegEx.create_from_string("\\b" + word + "\\b")
	return re.sub(text, with, true)
