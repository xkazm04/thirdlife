extends SceneTree
## Lane H2b (25 Nov): a commentary line with no voice is said as text only, never an error. A game's skin brings its own
## commentator's bank (data/<game>_commentary.json); thirdjam recorded voices for its own 415 lines only, so every line of
## the game's own was `push_error("rink audio: no voice for commentary line ...")` in a window: G1's Arsenal threw it in
## every version (the headless checks never draw a frame, where the booth speaks). Headless:
##   godot --headless --path engine --script res://cores/rink/audio/review/voice_none_case.gd
## The sound part takes three lines on three drawn frames: a voiced one of thirdjam's bank, one with no voice, the voiced one
## again. The line with no voice leaves a "voice_none" row and no "voice" row; both voiced ones are said. Prints
## `VOICENONE ok=true|false <detail>`; the selftest also fails on any ERROR line the run prints.

const Sound := preload("res://cores/rink/audio/rink_audio.gd")
const CART := "res://packs/hokej/data/hockey.regular.cartridge.json"


func _initialize() -> void:
	var cart: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CART))
	var s := Sound.new()
	var lines: Dictionary = s.voice_table.get("lines", {})
	var voiced: String = String(lines.keys()[0]) if not lines.is_empty() else ""
	var none: String = "harbour.made_up.01"                    # a game's own line: no voice was ever recorded for it
	s.begin(cart)
	s.booth(10, {"line_started": voiced}, 100, [])
	s.booth(110, {"line_started": none}, 200, [])
	s.booth(210, {"line_started": voiced}, 300, [])
	var kinds: Array = []
	for r: Array in s.rows:
		if String(r[1]) in ["voice", "voice_none"]:
			kinds.append("%d:%s:%s" % [int(r[0]), r[1], r[2]])
	var want: Array = ["10:voice:%s" % voiced, "110:voice_none:%s" % none, "210:voice:%s" % voiced]
	var ok: bool = voiced != "" and kinds == want
	s.end()
	print("VOICENONE ok=%s rows %s (want %s)" % [str(ok), ", ".join(kinds), ", ".join(want)])
	quit(0 if ok else 1)
