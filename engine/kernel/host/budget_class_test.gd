extends SceneTree
## The invariants' budget class (invariants.gd budget_class, K3 round 7): a village pack is held to the one-of-many p50, a
## dungeon with no village plot to the solo p50. Checks the engine's own boot files and a fixture with each case alone.
##   godot --headless --path engine --script res://kernel/host/budget_class_test.gd -- --scratch=<dir>
## Prints `PASS  budget class (n checks)` or `FAIL  budget class: <first failure>`; exit 0 / 1.

const Inv: GDScript = preload("res://kernel/host/invariants.gd")

var fails: Array = []
var n: int = 0


func _want(pack_dir: String, boot: String, cls: String, what: String) -> void:
	n += 1
	var got: Dictionary = Inv.budget_class(pack_dir, boot)
	if str(got["class"]) != cls:
		fails.append("%s: %s is %s (%s), want %s" % [what, pack_dir, got["class"], got["why"], cls])


func _init() -> void:
	var scratch: String = "user://budget_class_test"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--scratch="):
			scratch = a.substr(10)
	# the engine's own boot files
	_want("res://packs/hokej", "res://boot", "solo", "a dungeon with no village plot")
	_want(ProjectSettings.globalize_path("res://packs/hokej"), "res://boot", "solo", "the same, as an absolute path")
	_want("res://packs/parkour", "res://boot", "many", "a dungeon that also has a village plot")
	_want("res://packs/hockey", "res://boot", "many", "a dungeon that also has a village plot (ice_hockey_three_against)")
	_want("res://kernel/examples/ex_walker", "res://boot", "many", "a village plot only")
	_want("res://kernel/examples/bad_budget", "res://boot", "many", "neither")
	_want(OS.get_temp_dir().path_join("not_in_engine"), "res://boot", "many", "outside the engine's tree")
	# a fixture: each case alone
	var b: String = scratch.path_join("boot")
	DirAccess.make_dir_recursive_absolute(b)
	_write(b + "/games.json", {"games": [{"name": "solo_g", "from": "engine/packs/solo_x"}, {"name": "both_g", "from": "engine/packs/both_x"}, {"name": "plot_g", "from": "engine/packs/plot_x"}]})
	_write(b + "/village.json", {"plots": [{"id": "p1", "pack": "both_g"}, {"id": "p2", "pack": "plot_g"}]})
	_write(b + "/dungeons.json", {"dungeons": [{"pack": "packs/solo_x"}, {"pack": "packs/both_x"}, {"pack": "packs/unlisted_x"}]})
	_want("res://packs/solo_x", b, "solo", "fixture: dungeon, game, no plot")
	_want("res://packs/unlisted_x", b, "solo", "fixture: dungeon, not even a game of games.json")
	_want("res://packs/both_x", b, "many", "fixture: dungeon and plot")
	_want("res://packs/plot_x", b, "many", "fixture: plot only")
	_want("res://packs/none_x", b, "many", "fixture: neither")
	if fails.is_empty():
		print("PASS  budget class (%d checks)" % n)
		quit(0)
	else:
		print("FAIL  budget class: %s (%d of %d failed)" % [fails[0], fails.size(), n])
		quit(1)


func _write(path: String, data: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
