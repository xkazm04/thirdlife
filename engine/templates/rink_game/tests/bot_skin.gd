extends Node
## The game's skin (lane E1): data/skin.json read by scripts/hud/skin.gd (tl.rink.skin/1, unknown keys are errors) and
## reaching the screen: the front end's words, the commentator's team words, the banks. Headless (the screen draws nothing
## there), so it checks what the screen is built from:
##   - the pack's own skin.json reads clean (no problem) and every key is set;
##   - a skin with an unknown key, a wrong type and a bad level row is refused key by key (three problems, defaults stand);
##   - the team words: with the pack's names, thirdjam's "Blue shoots!" / "Clean win for orange." read in those names, as
##     written (lane E1b: no lower-casing), a colour word true to the cartridge's colour, plural names in the plural
##     ("Sharks shoot!", "for the Gulls", "are", "themselves"), "the blue line" left alone;
##   - the banks the skin names load: the commentator's (built-in, off or a data file) and the barks (a data file or off);
##   - the team colours are the cartridge's (data/match.json's cartridge): the skin carries none.

var GameSkin                 # scripts/hud/skin.gd, captions.gd (ctx.load_script: a test reaches the pack's scripts through ctx)
var Captions

var ctx
var done: bool = false
var fails: Array = []
var notes: Array = []


func _bot_setup(c) -> void:
	ctx = c
	GameSkin = ctx.load_script("scripts/hud/skin.gd")
	Captions = ctx.load_script("scripts/hud/captions.gd")


func _bot_tick(frame: int) -> void:
	if frame != 1:
		return
	var problems: Array = []
	var raw: Dictionary = ctx.read_json("skin.json")
	var s: Dictionary = GameSkin.validate(raw, problems)
	if not problems.is_empty():
		fails.append("the pack's skin.json: %s" % str(problems))
	for k: String in GameSkin.TYPES:
		if not s.has(k):
			fails.append("key %s not set" % k)
	var bad: Array = []
	GameSkin.validate({"schema": "tl.rink.skin/1", "colour": "#ff0000", "title": 7, "levels": [["ROOKIE"]]}, bad)
	if bad.size() != 3:
		fails.append("a bad skin gave %d problems, want 3: %s" % [bad.size(), str(bad)])
	var cart: Dictionary = ctx.read_json(String((ctx.read_json("match.json") as Dictionary).get("cartridge", "hockey.regular.cartridge.json")))
	var tw: Array = GameSkin.teams_of(s, cart["game"])
	var names: Array = tw[0]
	var a: String = GameSkin.team_words("Blue shoots!", names, tw[1])
	var b: String = GameSkin.team_words("Clean win for orange.", names, tw[1])
	var want_b: String = String(names[1]) + "."
	if names == GameSkin.DEFAULTS["team_names"]:
		want_b = want_b.to_lower()                       # thirdjam's own words stand as written in its bank
	if not a.begins_with(String(names[0])) or not b.ends_with(want_b):
		fails.append("team words: '%s', '%s' for %s" % [a, b, str(names)])
	# lane E1b: the grammar and the colours, pure (E5's jobs: "It's in, for blue!" when red scored; "glare foxes")
	var sg: Array = [["Sharks", "Gulls"], [true, true]]
	for c: Array in [["Blue shoots!", sg, "Sharks shoot!"], ["Clean win for orange.", sg, "Clean win for the Gulls."],
			["Orange is a skater short.", sg, "Gulls are a skater short."], ["Blue helps itself.", sg, "Sharks help themselves."],
			["Blue finishes the check.", sg, "Sharks finish the check."], ["Welcome to the rink: blue against orange, first period.", sg,
			"Welcome to the rink: the Sharks against the Gulls, first period."], ["Late to the blue line again.", sg, "Late to the blue line again."],
			["It's in, for blue!", [["Glare Foxes", "Slush Hounds"], [true, true]], "It's in, for the Glare Foxes!"],
			["It's in, for blue!", [["Red", "Blue"], [false, false]], "It's in, for Red!"]]:
		var got: String = GameSkin.team_words(String(c[0]), c[1][0], c[1][1])
		if got != String(c[2]):
			fails.append("team words: '%s' read '%s', want '%s'" % [c[0], got, c[2]])
	var pond: Array = GameSkin.teams_of({"team_names": ["Blue", "Orange"]}, {"teams": [{"colour_hex": "#D83A34"}, {"colour_hex": "#2F6BDE"}]})
	if pond[0] != ["Red", "Blue"]:
		fails.append("colour words for a red and a blue team: %s" % str(pond))
	var pirate: Array = GameSkin.teams_of(GameSkin.validate({"team_names": ["Sharks", "Gulls"]}, []), {"teams": [{"colour_hex": "#0FB5AE"}, {"colour_hex": "#F2B51D"}]})
	if pirate != [["Sharks", "Gulls"], [true, true]]:
		fails.append("Sharks and Gulls: %s" % str(pirate))
	var rows: Variant = GameSkin.commentary_rows(ctx, s)
	var cap = Captions.new(cart["game"], ctx.seed, rows, names)
	if String(s["commentary"]) != "off" and (cap.lines as Array).is_empty():
		fails.append("the commentary bank '%s' gave no lines" % String(s["commentary"]))
	var barks: Array = GameSkin.bark_rows(ctx, s)
	if String(s["barks"]) != "off" and barks.is_empty():
		fails.append("the bark bank '%s' gave no lines" % String(s["barks"]))
	var cols: Array = []
	for t: Dictionary in cart["game"]["teams"]:
		cols.append(String(t.get("colour_hex", "")))
	notes = ["title %s" % s["title"], "teams %s in %s" % [str(names), str(cols)], "commentary %s (%d lines)" % [s["commentary"], (cap.lines as Array).size()],
		"barks %s (%d lines)" % [s["barks"], barks.size()], "'%s' / '%s'" % [a, b]]
	done = true


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	return {"ok": done and fails.is_empty(), "summary": "; ".join(notes) + ("" if fails.is_empty() else " FAILS: " + "; ".join(fails)), "frames": ctx.frame}
