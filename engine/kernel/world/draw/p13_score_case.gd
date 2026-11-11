extends SceneTree
## P13 selftest case `kit.score_bound` (tools/selftest.sh): a kit scoreboard bound to a score source shows the
## source's score, follows `score_changed`, and the draw layer leaves a bound board alone. Headless; prints one line
## `P13CASE ok|fail <detail>`.


class Source:
	extends RefCounted
	signal score_changed(side: String, score: int)
	var scores: Dictionary = {"blue": 0, "red": 0}

	func add(side: String) -> void:
		scores[side] = int(scores[side]) + 1
		score_changed.emit(side, int(scores[side]))


func _init() -> void:
	var board: Node3D = Node3D.new()
	board.set_meta(&"tl_kind", "scoreboard")
	root.add_child(board)
	var src: Source = Source.new()
	var face: MeshInstance3D = TLKitSite.bind_scoreboard(board, src)
	var why: Array = []
	if face == null or face.get_parent() != board:
		why.append("no face under the board")
	if str(face.get_meta(&"tl_shown", "")) != "0:0":
		why.append("start shows '%s', not 0:0" % str(face.get_meta(&"tl_shown", "")))
	src.add("blue")
	src.add("blue")
	src.add("red")
	if str(face.get_meta(&"tl_shown", "")) != "2:1":
		why.append("after 2 and 1 it shows '%s'" % str(face.get_meta(&"tl_shown", "")))
	if face.mesh == null:
		why.append("the face has no mesh")
	if not board.has_meta(&"tl_score_bound"):
		why.append("the board is not marked bound (the draw layer would lay its own face over it)")
	print("P13CASE %s %s" % ["ok" if why.is_empty() else "fail", "shows 2:1 after three goals" if why.is_empty() else "; ".join(why)])
	board.free()
	quit(0 if why.is_empty() else 1)
