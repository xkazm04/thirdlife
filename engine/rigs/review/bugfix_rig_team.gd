extends SceneTree
## Bugfix-37 Q30 (selftest block 330-bugfix-rig.sh): the review scene's jersey for the user args it is given
## (`-- --mode=skate --team=red` must be red; `-- --mode=skate` alone stays blue). Prints `RIGTEAM <top colour key>`.

func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var scene: Node = preload("res://rigs/review/review.gd").new()
	root.add_child(scene)
	var rig: TLRigNode = scene.get("rig")
	print("RIGTEAM %s" % String((rig.params.get("colors", {}) as Dictionary).get("top", "none")))
	scene.free()
	quit()
