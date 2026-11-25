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
##                blue / orange, as written (capitals as the skin has them, at the start of a line and inside it). A colour word
##                that is not its team's colour in the cartridge ("Blue" on a red team: the base's words left in a user's
##                skin) is said as the team's own colour word ("Red"): a line never names a colour the person does not see.
##   team_plural  [bool, bool] (lane E1b, optional): the name is a plural ("Sharks") and the lines say "Sharks shoot!", "for
##                the Sharks". Absent: guessed from the name (its last word ends in a single s: "Glare Foxes", "Gulls").
##   levels       [[label, line] x 3]: the level row's words for rookie, pro, all_star, and the line under the row
##   commentary   "builtin" (thirdjam's three commentary banks, scripts/hud/commentary_lines.gd), "off", or a file in data/
##                ({"lines": [[id, event, kind, team, priority, cooldown_frames, text, duration_frames], ...]})
##   ability_names  (H2d, optional) the game's word for each trick of game.abilities by the core's kind ({"shotgun": "cannon"}: "F: CANNON  READY"); a kind left out keeps the core's id
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
	"ability_names": {},
}
const TYPES: Dictionary = {"schema": TYPE_STRING, "title": TYPE_STRING, "tagline": TYPE_STRING, "about": TYPE_ARRAY,
	"team_names": TYPE_ARRAY, "team_plural": TYPE_ARRAY, "levels": TYPE_ARRAY, "commentary": TYPE_STRING, "barks": TYPE_STRING, "ability_names": TYPE_DICTIONARY}
const ABILITY_KINDS: PackedStringArray = ["shotgun", "hip_check", "shield", "slow_puck"]   # the core's kinds (JamCartridge.h abilities)


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
			"ability_names":
				var bad: Array = (v as Dictionary).keys().filter(func(an: Variant) -> bool: return not (an is String and String(an) in ABILITY_KINDS and (v as Dictionary)[an] is String and String((v as Dictionary)[an]).strip_edges() != ""))
				if not bad.is_empty():
					problems.append("ability_names: %s (keys are the core's kinds %s, values words)" % [", ".join(PackedStringArray(bad.map(func(x: Variant) -> String: return str(x)))), ", ".join(ABILITY_KINDS)])
					continue
			"team_plural":
				if (v as Array).size() != 2 or not ((v as Array)[0] is bool and (v as Array)[1] is bool):
					problems.append("team_plural must be two booleans")
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
	if not s.has("team_plural"):                              # absent = guessed from the names (a key left out is not an error)
		s["team_plural"] = [plural_guess(String(s["team_names"][0])), plural_guess(String(s["team_names"][1]))]
	return s


## A team name read as a plural: its last word ends in one s ("Sharks", "Glare Foxes"; not "Blue", "Boss", "Ice Moss").
static func plural_guess(name: String) -> bool:
	var w: PackedStringArray = name.strip_edges().split(" ", false)
	if w.is_empty():
		return false
	var last: String = w[w.size() - 1].to_lower()
	return last.length() > 2 and last.ends_with("s") and not last.ends_with("ss") and not last.ends_with("us") and not last.ends_with("is")


## The colour words a team may be named by, and the hue (degrees) each covers; white, black and grey by lightness.
const COLOUR_WORDS: Array = [["Red", 0.0, 14.0], ["Orange", 14.0, 40.0], ["Gold", 40.0, 52.0], ["Yellow", 52.0, 68.0],
	["Green", 68.0, 160.0], ["Teal", 160.0, 195.0], ["Blue", 195.0, 255.0], ["Purple", 255.0, 290.0], ["Pink", 290.0, 345.0],
	["Red", 345.0, 361.0]]
const NEUTRAL_WORDS: Array = ["White", "Black", "Grey", "Gray"]


## The colour word a person reads a colour as ("#1D4ED8" Blue, "#E8651A" Orange, "#D83A34" Red, "#0FB5AE" Teal).
static func colour_word(c: Color) -> String:
	if c.s < 0.22:
		return "White" if c.v > 0.8 else ("Black" if c.v < 0.25 else "Grey")
	var hue: float = c.h * 360.0
	for row: Array in COLOUR_WORDS:
		if hue >= float(row[1]) and hue < float(row[2]):
			return String(row[0])
	return "Red"


static func _is_colour_word(name: String) -> bool:
	var n: String = name.strip_edges().to_lower()
	for row: Array in COLOUR_WORDS:
		if String(row[0]).to_lower() == n:
			return true
	for w: String in NEUTRAL_WORDS:
		if w.to_lower() == n:
			return true
	return false


## The teams as the person meets them: [[name 0, name 1], [plural 0, plural 1]]. The skin's names as written; a bare colour
## word that is not its team's colour in the cartridge (game.teams[].colour_hex) becomes that colour's word ("Blue" on a
## red team reads "Red"; E5 job 1 heard "It's in, for blue!" when red scored).
static func teams_of(s: Dictionary, game: Dictionary) -> Array:
	var names: Array = (s.get("team_names", DEFAULTS["team_names"]) as Array).duplicate()
	var plural: Array = (s.get("team_plural", [plural_guess(String(names[0])), plural_guess(String(names[1]))]) as Array).duplicate()
	var teams: Array = game.get("teams", [])
	for t: int in mini(2, teams.size()):
		var hex: String = String((teams[t] as Dictionary).get("colour_hex", ""))
		if hex == "" or not _is_colour_word(String(names[t])):
			continue
		var word: String = colour_word(Color(hex))
		if word.to_lower() != String(names[t]).strip_edges().to_lower():
			names[t] = word
			plural[t] = false
	return [names, plural]


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


## A line of thirdjam's bank in this skin's team words. thirdjam's "Blue" / "blue" / "Orange" / "orange" (a team: not "the
## blue line") become the team names as written. A plural name ([plural 0, plural 1]) takes "the" inside a sentence ("for
## the Sharks"), the verb after it in the plural ("Sharks shoot!", "the Gulls are a skater short") and "themselves" for
## "itself". With thirdjam's own names (Blue, Orange, singular) the line is unchanged.
static func team_words(text: String, names: Array, plural: Array = [false, false]) -> String:
	if names == DEFAULTS["team_names"] and not bool(plural[0]) and not bool(plural[1]):
		return text
	var re := RegEx.create_from_string("\\b(Blue|blue|Orange|orange)\\b(?! lines?\\b)")
	var stop := RegEx.create_from_string("[.!?]\\s*$")
	var verb := RegEx.create_from_string("^ ([a-z]+)\\b")
	var out: String = ""
	var at: int = 0
	var any_plural: bool = false
	for m: RegExMatch in re.search_all(text):
		var team: int = 0 if m.get_string(1).to_lower() == "blue" else 1
		var name: String = String(names[team])
		var pl: bool = bool(plural[team])
		var head: String = text.substr(0, m.get_start())
		var start: bool = head.strip_edges() == "" or stop.search(head) != null
		out += text.substr(at, m.get_start() - at)
		out += ("the " + name) if (pl and not start) else name
		at = m.get_end()
		if pl:
			any_plural = true
			var vm: RegExMatch = verb.search(text.substr(at))
			if vm != null:
				var w: String = vm.get_string(1)
				var pw: String = _plural_verb(w)
				if pw != w:
					out += " " + pw
					at += 1 + w.length()
	out += text.substr(at)
	if any_plural:
		out = RegEx.create_from_string("\\bitself\\b").sub(out, "themselves", true)
	return out


## The plural of a verb in the third person singular ("shoots" shoot, "finishes" finish, "is" are, "has" have); any other
## word as it stands ("on", "to", "playing").
static func _plural_verb(w: String) -> String:
	match w:
		"is": return "are"
		"was": return "were"
		"has": return "have"
		"does": return "do"
		"says": return "say"
	if w.length() > 3 and (w.ends_with("ches") or w.ends_with("shes") or w.ends_with("sses") or w.ends_with("xes") or w.ends_with("zes")):
		return w.substr(0, w.length() - 2)
	if w.length() > 2 and w.ends_with("s") and not w.ends_with("ss") and not w.ends_with("us") and not w.ends_with("is"):
		return w.substr(0, w.length() - 1)
	return w
