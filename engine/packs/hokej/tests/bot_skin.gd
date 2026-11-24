extends Node
## The game's skin (lane E1): data/skin.json read by scripts/hud/skin.gd (tl.rink.skin/1, unknown keys are errors) and
## reaching the screen: the front end's words, the commentator's team words, the banks. Headless (the screen draws nothing
## there), so it checks what the screen is built from:
##   - the pack's own skin.json reads clean (no problem) and every key is set;
##   - a skin with an unknown key, a wrong type and a bad level row is refused key by key (three problems, defaults stand);
##   - the team words: with the pack's names, thirdjam's "Blue shoots!" / "Clean win for orange." read in those names;
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
	var names: Array = s["team_names"]
	var a: String = GameSkin.team_words("Blue shoots!", names)
	var b: String = GameSkin.team_words("Clean win for orange.", names)
	if not a.begins_with(String(names[0])) or not b.ends_with(String(names[1]).to_lower() + "."):
		fails.append("team words: '%s', '%s' for %s" % [a, b, str(names)])
	var cart: Dictionary = ctx.read_json(String((ctx.read_json("match.json") as Dictionary).get("cartridge", "hockey.regular.cartridge.json")))
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
